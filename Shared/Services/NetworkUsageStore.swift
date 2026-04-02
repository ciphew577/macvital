// MacVital/Services/NetworkUsageStore.swift
//
// Persistent network usage store.
//
// Responsibilities
//  - Persist per-interface cumulative totals (bytes/packets in/out) across app
//    relaunches AND system reboots.
//  - Detect kernel counter resets (reboot / interface reset) and treat the full
//    post-reset value as a delta so the monotonic cumulative total never
//    decreases.
//  - Maintain a rolling 1-minute-resolution sample table for the last 7 days
//    so the Network tab can render "today", "7 days", and "session" views.
//  - Batch writes on a dedicated background queue to avoid SSD wear and never
//    block the main thread.
//
// Storage: ~/Library/Application Support/MacVital/network_history.sqlite
// Engine:  SQLite3 via the C API (no external dependencies).

import Foundation
import SQLite3
import os.log

// SQLITE_TRANSIENT is a macro that doesn't bridge to Swift directly.
private let SQLITE_TRANSIENT_BINDING = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// A single observation captured from the NetworkReader for one interface.
struct NetworkUsageSample: Sendable {
    let interface: String
    let kernelTxBytes: UInt64
    let kernelRxBytes: UInt64
    let kernelTxPackets: UInt64
    let kernelRxPackets: UInt64
    let timestamp: Date
}

/// Cumulative monotonic totals for one interface, exposed to the UI layer.
struct NetworkInterfaceTotals: Sendable, Equatable {
    let interface: String
    let totalBytesIn: UInt64
    let totalBytesOut: UInt64
    let totalPacketsIn: UInt64
    let totalPacketsOut: UInt64
    let rebootCount: Int
    let firstSeen: Date
    let lastUpdated: Date
}

/// Aggregated totals over a time window.
struct NetworkUsageWindow: Sendable, Equatable {
    let bytesIn: UInt64
    let bytesOut: UInt64
    var totalBytes: UInt64 { bytesIn &+ bytesOut }

    static let zero = NetworkUsageWindow(bytesIn: 0, bytesOut: 0)
}

/// Per-interface breakdown across standard windows (today / 7d / 30d / session / all-time).
struct NetworkUsageSummary: Sendable {
    let interface: String
    let session: NetworkUsageWindow
    let today: NetworkUsageWindow
    let last7Days: NetworkUsageWindow
    let last30Days: NetworkUsageWindow
    let allTime: NetworkUsageWindow
}

/// Persistent store for network byte/packet counters.
///
/// Thread safety: all SQLite work happens on a dedicated serial queue. Public
/// API is safe to call from any thread; published snapshots are delivered on
/// the main actor.
final class NetworkUsageStore: @unchecked Sendable {

    // MARK: - Shared instance (lazy, safe to touch from any thread)

    static let shared = NetworkUsageStore()

    // MARK: - Internals

    private let log = Logger(subsystem: "com.macvital.app", category: "NetworkUsageStore")
    private let dbQueue = DispatchQueue(label: "com.macvital.networkusagestore", qos: .utility)
    private var db: OpaquePointer?
    private let dbURL: URL

    /// Cached monotonic totals per interface (kept hot so reads don't hit SQLite
    /// on every UI refresh). Only mutated inside dbQueue.
    private var totalsCache: [String: NetworkInterfaceTotals] = [:]

    /// Last absolute session totals seen via `record(interface:ssid:…)` for the
    /// per-(bsd, ssid) attribution path. Used to convert absolute session
    /// counters into deltas before aggregating into the sample buckets. Only
    /// mutated inside dbQueue.
    private var lastRecordSnapshot: [String: (bytesIn: UInt64, bytesOut: UInt64)] = [:]

    /// Session-start totals per interface, frozen at the moment the first
    /// sample for that interface is ingested in this process. Used so the UI
    /// can compute "this session" deltas independent of the rolling samples
    /// table. Only mutated inside dbQueue.
    private var sessionBaseline: [String: (bytesIn: UInt64, bytesOut: UInt64)] = [:]

    /// Pending (interface -> 1-minute bucket -> delta) aggregates, flushed every
    /// flushInterval seconds. Only mutated inside dbQueue.
    private var pendingSamples: [String: [Int64: PendingBucket]] = [:]
    private var lastFlush: Date = .distantPast

    /// How often pending samples are flushed to disk. 60s keeps writes rare
    /// while still giving fine-grained per-minute history for the Network tab.
    private let flushInterval: TimeInterval = 60

    /// How many days of per-minute samples to retain.
    private let retentionDays: Int = 7

    private struct PendingBucket {
        var bytesIn: UInt64 = 0
        var bytesOut: UInt64 = 0
        var packetsIn: UInt64 = 0
        var packetsOut: UInt64 = 0
    }

    // MARK: - Init

    private init() {
        let fm = FileManager.default
        let supportDir = (try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let dir = supportDir.appendingPathComponent("MacVital", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        self.dbURL = dir.appendingPathComponent("network_history.sqlite")

        dbQueue.async { [weak self] in
            self?.openAndMigrate()
            self?.loadCache()
            self?.pruneOldSamples()
        }
    }

    deinit {
        if let db { sqlite3_close(db) }
    }

    // MARK: - Public API

    /// Current database file path (for diagnostics / docs / tests).
    var storageURL: URL { dbURL }

    /// Ingest one batch of fresh kernel counter readings. Safe to call from any
    /// thread. Always returns immediately; DB work is queued.
    func ingest(_ samples: [NetworkUsageSample]) {
        guard !samples.isEmpty else { return }
        dbQueue.async { [weak self] in
            self?.applySamples(samples)
            self?.maybeFlushLocked()
        }
    }

    /// Per-(interface, SSID) attribution entry point used by the Network
    /// attribution agent. Passes *absolute session counters* for this bucket
    /// (NOT deltas) — the store computes deltas internally, aggregates them
    /// into the 1-minute buckets, and treats counter resets as bucket rotation.
    ///
    /// Contract preserved from the original stub in Shared/Services.
    func record(interface: String,
                ssid: String?,
                bytesIn: UInt64,
                bytesOut: UInt64,
                timestamp: Date = Date()) {
        let key = ssid.map { "\(interface)|\($0)" } ?? interface
        dbQueue.async { [weak self] in
            guard let self else { return }
            let last = self.lastRecordSnapshot[key]
            var dIn: UInt64 = 0
            var dOut: UInt64 = 0
            if let last {
                if bytesIn >= last.bytesIn {
                    dIn = bytesIn &- last.bytesIn
                } else {
                    // Counter went down → either ssid bucket rotated or a
                    // reboot happened. Treat the new absolute value as the
                    // delta (safe lower bound, never negative).
                    dIn = bytesIn
                }
                if bytesOut >= last.bytesOut {
                    dOut = bytesOut &- last.bytesOut
                } else {
                    dOut = bytesOut
                }
            }
            self.lastRecordSnapshot[key] = (bytesIn, bytesOut)

            if dIn > 0 || dOut > 0 {
                let bucket = Int64(timestamp.timeIntervalSince1970 / 60)
                var ifaceBuckets = self.pendingSamples[key] ?? [:]
                var entry = ifaceBuckets[bucket] ?? PendingBucket()
                entry.bytesIn &+= dIn
                entry.bytesOut &+= dOut
                ifaceBuckets[bucket] = entry
                self.pendingSamples[key] = ifaceBuckets
            }
            self.maybeFlushLocked()
        }
    }

    /// Force any pending buffered samples to disk. Call on app stop.
    func flush() {
        dbQueue.async { [weak self] in
            self?.flushLocked(force: true)
        }
    }

    /// Synchronously read the current monotonic totals cache. Returns a snapshot.
    func currentTotals() -> [NetworkInterfaceTotals] {
        dbQueue.sync { Array(totalsCache.values).sorted { $0.interface < $1.interface } }
    }

    /// Build a summary (session / today / 7d / 30d / all-time) per interface.
    /// This is safe to call from the main thread — it runs synchronously on the
    /// db queue but operations are cheap (indexed aggregates on a tiny table).
    func summarySnapshot(referenceDate: Date = Date()) -> [NetworkUsageSummary] {
        dbQueue.sync { buildSummaries(referenceDate: referenceDate) }
    }

    // MARK: - Open / migrate

    private func openAndMigrate() {
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        let rc = sqlite3_open_v2(dbURL.path, &handle, flags, nil)
        guard rc == SQLITE_OK, let handle else {
            log.error("Failed to open network_history.sqlite at \(self.dbURL.path, privacy: .public) rc=\(rc)")
            return
        }
        db = handle

        // Pragmas: WAL mode for crash-safe writes, NORMAL sync is a good tradeoff
        // for a local cache where losing the last minute on crash is acceptable.
        exec("PRAGMA journal_mode=WAL;")
        exec("PRAGMA synchronous=NORMAL;")
        exec("PRAGMA temp_store=MEMORY;")

        exec("""
            CREATE TABLE IF NOT EXISTS interface_totals (
                interface        TEXT PRIMARY KEY,
                total_bytes_in   INTEGER NOT NULL DEFAULT 0,
                total_bytes_out  INTEGER NOT NULL DEFAULT 0,
                total_pkts_in    INTEGER NOT NULL DEFAULT 0,
                total_pkts_out   INTEGER NOT NULL DEFAULT 0,
                last_kernel_rx   INTEGER NOT NULL DEFAULT 0,
                last_kernel_tx   INTEGER NOT NULL DEFAULT 0,
                last_kernel_pin  INTEGER NOT NULL DEFAULT 0,
                last_kernel_pout INTEGER NOT NULL DEFAULT 0,
                reboot_count     INTEGER NOT NULL DEFAULT 0,
                first_seen       REAL NOT NULL,
                last_updated     REAL NOT NULL
            );
        """)

        exec("""
            CREATE TABLE IF NOT EXISTS samples (
                interface      TEXT NOT NULL,
                bucket_minute  INTEGER NOT NULL,
                bytes_in       INTEGER NOT NULL DEFAULT 0,
                bytes_out      INTEGER NOT NULL DEFAULT 0,
                pkts_in        INTEGER NOT NULL DEFAULT 0,
                pkts_out       INTEGER NOT NULL DEFAULT 0,
                PRIMARY KEY (interface, bucket_minute)
            );
        """)

        exec("CREATE INDEX IF NOT EXISTS idx_samples_bucket ON samples(bucket_minute);")
    }

    private func exec(_ sql: String) {
        guard let db else { return }
        var err: UnsafeMutablePointer<Int8>?
        if sqlite3_exec(db, sql, nil, nil, &err) != SQLITE_OK {
            let msg = err.flatMap { String(cString: $0) } ?? "unknown"
            log.error("SQL error: \(msg, privacy: .public) SQL=\(sql, privacy: .public)")
            sqlite3_free(err)
        }
    }

    private func loadCache() {
        guard let db else { return }
        let sql = """
            SELECT interface, total_bytes_in, total_bytes_out, total_pkts_in, total_pkts_out,
                   reboot_count, first_seen, last_updated
            FROM interface_totals;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let ifCStr = sqlite3_column_text(stmt, 0) else { continue }
            let iface = String(cString: ifCStr)
            let totals = NetworkInterfaceTotals(
                interface: iface,
                totalBytesIn: UInt64(bitPattern: sqlite3_column_int64(stmt, 1)),
                totalBytesOut: UInt64(bitPattern: sqlite3_column_int64(stmt, 2)),
                totalPacketsIn: UInt64(bitPattern: sqlite3_column_int64(stmt, 3)),
                totalPacketsOut: UInt64(bitPattern: sqlite3_column_int64(stmt, 4)),
                rebootCount: Int(sqlite3_column_int64(stmt, 5)),
                firstSeen: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 6)),
                lastUpdated: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 7))
            )
            totalsCache[iface] = totals
        }
    }

    // MARK: - Ingest logic (runs on dbQueue)

    private func applySamples(_ samples: [NetworkUsageSample]) {
        guard let db else { return }

        for sample in samples {
            // Fetch last kernel snapshot for this interface. If none, start fresh.
            let lastRow = fetchLastSnapshot(interface: sample.interface)

            // Delta calculation — handle counter reset (reboot, interface wrap).
            //
            // Kernel interface counters reset on reboot and on some network state
            // changes (e.g. interface brought down). We detect reset when the new
            // kernel counter is *lower* than the last one we saw. In that case
            // the true delta since our last observation is unknowable, but the
            // counter now reads "bytes since last reset", which is a safe lower
            // bound to add to the cumulative total. This keeps the monotonic
            // running total strictly non-decreasing.
            var dTx: UInt64 = 0
            var dRx: UInt64 = 0
            var dPin: UInt64 = 0
            var dPout: UInt64 = 0
            var rebootBump = 0

            if let last = lastRow {
                if sample.kernelTxBytes >= last.lastKernelTx {
                    dTx = sample.kernelTxBytes &- last.lastKernelTx
                } else {
                    dTx = sample.kernelTxBytes
                    rebootBump = 1
                }
                if sample.kernelRxBytes >= last.lastKernelRx {
                    dRx = sample.kernelRxBytes &- last.lastKernelRx
                } else {
                    dRx = sample.kernelRxBytes
                    rebootBump = 1
                }
                if sample.kernelTxPackets >= last.lastKernelPktOut {
                    dPout = sample.kernelTxPackets &- last.lastKernelPktOut
                } else {
                    dPout = sample.kernelTxPackets
                }
                if sample.kernelRxPackets >= last.lastKernelPktIn {
                    dPin = sample.kernelRxPackets &- last.lastKernelPktIn
                } else {
                    dPin = sample.kernelRxPackets
                }
            } else {
                // First time we've ever seen this interface. We do NOT count the
                // pre-existing kernel counter as historical usage — we only start
                // counting from *now*. The initial snapshot row anchors the
                // baseline so the next ingest computes a proper delta.
                dTx = 0
                dRx = 0
                dPout = 0
                dPin = 0
            }

            // Update cumulative totals row.
            let now = sample.timestamp.timeIntervalSince1970
            let firstSeen = lastRow?.firstSeen ?? now

            let existing = totalsCache[sample.interface]
            let newTotals = NetworkInterfaceTotals(
                interface: sample.interface,
                totalBytesIn: (existing?.totalBytesIn ?? 0) &+ dRx,
                totalBytesOut: (existing?.totalBytesOut ?? 0) &+ dTx,
                totalPacketsIn: (existing?.totalPacketsIn ?? 0) &+ dPin,
                totalPacketsOut: (existing?.totalPacketsOut ?? 0) &+ dPout,
                rebootCount: (existing?.rebootCount ?? 0) + rebootBump,
                firstSeen: Date(timeIntervalSince1970: firstSeen),
                lastUpdated: sample.timestamp
            )
            totalsCache[sample.interface] = newTotals

            // Freeze session baseline the first time we see this iface this process.
            if sessionBaseline[sample.interface] == nil {
                sessionBaseline[sample.interface] = (
                    bytesIn: existing?.totalBytesIn ?? newTotals.totalBytesIn,
                    bytesOut: existing?.totalBytesOut ?? newTotals.totalBytesOut
                )
            }

            // Write the updated totals row immediately — this is cheap (UPSERT on
            // a tiny table), survives crashes, and is what keeps data across
            // relaunches.
            upsertTotals(newTotals, kernelSample: sample)

            // Bucket the delta into the pending 1-minute aggregate. We only
            // write samples rows on flush.
            if dTx > 0 || dRx > 0 || dPin > 0 || dPout > 0 {
                let bucket = Int64(sample.timestamp.timeIntervalSince1970 / 60)
                var ifaceBuckets = pendingSamples[sample.interface] ?? [:]
                var entry = ifaceBuckets[bucket] ?? PendingBucket()
                entry.bytesIn &+= dRx
                entry.bytesOut &+= dTx
                entry.packetsIn &+= dPin
                entry.packetsOut &+= dPout
                ifaceBuckets[bucket] = entry
                pendingSamples[sample.interface] = ifaceBuckets
            }
        }
        _ = db // silence warning if db only used in helpers
    }

    private struct LastSnapshot {
        let lastKernelRx: UInt64
        let lastKernelTx: UInt64
        let lastKernelPktIn: UInt64
        let lastKernelPktOut: UInt64
        let firstSeen: TimeInterval
    }

    private func fetchLastSnapshot(interface: String) -> LastSnapshot? {
        guard let db else { return nil }
        var stmt: OpaquePointer?
        let sql = """
            SELECT last_kernel_rx, last_kernel_tx, last_kernel_pin, last_kernel_pout, first_seen
            FROM interface_totals WHERE interface = ?;
        """
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, interface, -1, SQLITE_TRANSIENT_BINDING)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return LastSnapshot(
            lastKernelRx: UInt64(bitPattern: sqlite3_column_int64(stmt, 0)),
            lastKernelTx: UInt64(bitPattern: sqlite3_column_int64(stmt, 1)),
            lastKernelPktIn: UInt64(bitPattern: sqlite3_column_int64(stmt, 2)),
            lastKernelPktOut: UInt64(bitPattern: sqlite3_column_int64(stmt, 3)),
            firstSeen: sqlite3_column_double(stmt, 4)
        )
    }

    private func upsertTotals(_ totals: NetworkInterfaceTotals, kernelSample: NetworkUsageSample) {
        guard let db else { return }
        let sql = """
            INSERT INTO interface_totals (
                interface, total_bytes_in, total_bytes_out, total_pkts_in, total_pkts_out,
                last_kernel_rx, last_kernel_tx, last_kernel_pin, last_kernel_pout,
                reboot_count, first_seen, last_updated
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(interface) DO UPDATE SET
                total_bytes_in   = excluded.total_bytes_in,
                total_bytes_out  = excluded.total_bytes_out,
                total_pkts_in    = excluded.total_pkts_in,
                total_pkts_out   = excluded.total_pkts_out,
                last_kernel_rx   = excluded.last_kernel_rx,
                last_kernel_tx   = excluded.last_kernel_tx,
                last_kernel_pin  = excluded.last_kernel_pin,
                last_kernel_pout = excluded.last_kernel_pout,
                reboot_count     = excluded.reboot_count,
                last_updated     = excluded.last_updated;
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, totals.interface, -1, SQLITE_TRANSIENT_BINDING)
        sqlite3_bind_int64(stmt, 2, Int64(bitPattern: totals.totalBytesIn))
        sqlite3_bind_int64(stmt, 3, Int64(bitPattern: totals.totalBytesOut))
        sqlite3_bind_int64(stmt, 4, Int64(bitPattern: totals.totalPacketsIn))
        sqlite3_bind_int64(stmt, 5, Int64(bitPattern: totals.totalPacketsOut))
        sqlite3_bind_int64(stmt, 6, Int64(bitPattern: kernelSample.kernelRxBytes))
        sqlite3_bind_int64(stmt, 7, Int64(bitPattern: kernelSample.kernelTxBytes))
        sqlite3_bind_int64(stmt, 8, Int64(bitPattern: kernelSample.kernelRxPackets))
        sqlite3_bind_int64(stmt, 9, Int64(bitPattern: kernelSample.kernelTxPackets))
        sqlite3_bind_int64(stmt, 10, Int64(totals.rebootCount))
        sqlite3_bind_double(stmt, 11, totals.firstSeen.timeIntervalSince1970)
        sqlite3_bind_double(stmt, 12, totals.lastUpdated.timeIntervalSince1970)
        if sqlite3_step(stmt) != SQLITE_DONE {
            log.error("upsertTotals failed for \(totals.interface, privacy: .public)")
        }
    }

    // MARK: - Flush / prune

    private func maybeFlushLocked() {
        if Date().timeIntervalSince(lastFlush) >= flushInterval {
            flushLocked(force: false)
        }
    }

    private func flushLocked(force: Bool) {
        guard let db else { return }
        guard force || !pendingSamples.isEmpty else {
            lastFlush = Date()
            return
        }
        guard !pendingSamples.isEmpty else {
            lastFlush = Date()
            return
        }

        exec("BEGIN IMMEDIATE TRANSACTION;")

        let sql = """
            INSERT INTO samples (interface, bucket_minute, bytes_in, bytes_out, pkts_in, pkts_out)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(interface, bucket_minute) DO UPDATE SET
                bytes_in  = samples.bytes_in  + excluded.bytes_in,
                bytes_out = samples.bytes_out + excluded.bytes_out,
                pkts_in   = samples.pkts_in   + excluded.pkts_in,
                pkts_out  = samples.pkts_out  + excluded.pkts_out;
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            exec("ROLLBACK;")
            return
        }
        defer { sqlite3_finalize(stmt) }

        for (iface, buckets) in pendingSamples {
            for (bucket, agg) in buckets {
                sqlite3_reset(stmt)
                sqlite3_bind_text(stmt, 1, iface, -1, SQLITE_TRANSIENT_BINDING)
                sqlite3_bind_int64(stmt, 2, bucket)
                sqlite3_bind_int64(stmt, 3, Int64(bitPattern: agg.bytesIn))
                sqlite3_bind_int64(stmt, 4, Int64(bitPattern: agg.bytesOut))
                sqlite3_bind_int64(stmt, 5, Int64(bitPattern: agg.packetsIn))
                sqlite3_bind_int64(stmt, 6, Int64(bitPattern: agg.packetsOut))
                if sqlite3_step(stmt) != SQLITE_DONE {
                    log.error("samples insert failed for \(iface, privacy: .public)")
                }
            }
        }

        exec("COMMIT;")
        pendingSamples.removeAll(keepingCapacity: true)
        lastFlush = Date()
        pruneOldSamples()
    }

    private func pruneOldSamples() {
        guard let db else { return }
        let cutoff = Int64(Date().timeIntervalSince1970 / 60) - Int64(retentionDays * 24 * 60)
        var stmt: OpaquePointer?
        let sql = "DELETE FROM samples WHERE bucket_minute < ?;"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, cutoff)
        _ = sqlite3_step(stmt)
    }

    // MARK: - Summary queries

    private func buildSummaries(referenceDate: Date) -> [NetworkUsageSummary] {
        guard let db else { return [] }

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: referenceDate)
        let todayBucket = Int64(startOfToday.timeIntervalSince1970 / 60)
        let sevenDayBucket = Int64(referenceDate.addingTimeInterval(-7 * 86400).timeIntervalSince1970 / 60)
        let thirtyDayBucket = Int64(referenceDate.addingTimeInterval(-30 * 86400).timeIntervalSince1970 / 60)

        var summaries: [NetworkUsageSummary] = []

        for totals in totalsCache.values.sorted(by: { $0.interface < $1.interface }) {
            let iface = totals.interface
            let today = aggregate(interface: iface, sinceBucket: todayBucket)
            let last7 = aggregate(interface: iface, sinceBucket: sevenDayBucket)
            let last30 = aggregate(interface: iface, sinceBucket: thirtyDayBucket)

            let sessionBase = sessionBaseline[iface] ?? (bytesIn: totals.totalBytesIn, bytesOut: totals.totalBytesOut)
            let sessionWin = NetworkUsageWindow(
                bytesIn: totals.totalBytesIn >= sessionBase.bytesIn ? totals.totalBytesIn &- sessionBase.bytesIn : 0,
                bytesOut: totals.totalBytesOut >= sessionBase.bytesOut ? totals.totalBytesOut &- sessionBase.bytesOut : 0
            )
            let allTime = NetworkUsageWindow(
                bytesIn: totals.totalBytesIn,
                bytesOut: totals.totalBytesOut
            )

            summaries.append(NetworkUsageSummary(
                interface: iface,
                session: sessionWin,
                today: today,
                last7Days: last7,
                last30Days: last30,
                allTime: allTime
            ))
        }
        _ = db
        return summaries
    }

    private func aggregate(interface: String, sinceBucket: Int64) -> NetworkUsageWindow {
        guard let db else { return .zero }
        var stmt: OpaquePointer?
        let sql = """
            SELECT COALESCE(SUM(bytes_in), 0), COALESCE(SUM(bytes_out), 0)
            FROM samples
            WHERE interface = ? AND bucket_minute >= ?;
        """
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return .zero }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, interface, -1, SQLITE_TRANSIENT_BINDING)
        sqlite3_bind_int64(stmt, 2, sinceBucket)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return .zero }
        return NetworkUsageWindow(
            bytesIn: UInt64(bitPattern: sqlite3_column_int64(stmt, 0)),
            bytesOut: UInt64(bitPattern: sqlite3_column_int64(stmt, 1))
        )
    }
}

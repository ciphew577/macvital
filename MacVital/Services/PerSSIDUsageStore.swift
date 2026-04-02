// MacVital/Services/PerSSIDUsageStore.swift
//
// Per-network (per-SSID) lifetime usage tracker.
//
// Motivation
//   the user wants a cumulative byte counter per Wi-Fi network that:
//     - never auto-resets (not on relaunch, not on date rollover, not ever)
//     - only zeroes when he clicks a per-SSID reset button or a global reset
//     - persists across app restart, crash, sleep/wake, and reboot
//
// This is intentionally separate from `NetworkUsageStore` (Shared/Services),
// which is the SQLite-backed kernel-counter store that powers windowed views
// (today / 7d / 30d / session). That store CANNOT double as the lifetime
// tracker because:
//   1. It is keyed by BSD name (en0, en1, ...), not SSID.
//   2. It exposes "all-time" only as a monotonic-but-reboot-aware counter
//      tied to kernel counters, not to user-visible Wi-Fi network names.
//   3. Its retention/prune logic is sample-table specific; reset-per-SSID is
//      not part of its contract.
//
// Storage
//   JSON file at ~/Library/Application Support/MacVital/network_usage.json
//   Writes are debounced: after every recordDelta we schedule a flush 5s out;
//   subsequent deltas inside the window just slide the scheduled flush. Reset
//   operations flush synchronously so a user-visible action hits disk immediately.
//
// Thread safety
//   The public API is main-actor. Deltas from SystemMonitor arrive on the main
//   thread (published snapshot tick). Disk I/O runs off-main on a dedicated
//   serial queue.

import Foundation
import SwiftUI
import os.log

/// One SSID's lifetime usage bucket.
struct PerSSIDUsage: Codable, Identifiable, Equatable, Sendable {
    /// The SSID string itself is the stable identity. Unknown / hidden networks
    /// bucket under the sentinel defined in `PerSSIDUsageStore.unknownKey`.
    let id: String
    var bytesIn: UInt64
    var bytesOut: UInt64
    var firstSeen: Date
    var lastSeen: Date

    var totalBytes: UInt64 { bytesIn &+ bytesOut }
}

/// Persisted top-level envelope. Versioned so the schema can evolve without
/// wiping lifetime totals.
private struct PerSSIDUsageEnvelope: Codable {
    var version: Int
    var perSSID: [String: PerSSIDUsage]
    var lastSaved: Date

    static let currentVersion = 1
}

@Observable
@MainActor
final class PerSSIDUsageStore {

    // MARK: - Public sentinels

    /// SSID label used when CoreWLAN returns nil (no Location permission,
    /// hidden network, or not currently joined to a Wi-Fi network).
    static let unknownKey = "(unknown SSID, location not granted)"

    // MARK: - Published state

    /// Per-SSID lifetime buckets. Mutations go through the public API so
    /// persistence stays in sync.
    private(set) var perSSID: [String: PerSSIDUsage] = [:]

    /// True once the on-disk file has been loaded (or confirmed missing).
    /// Lets the UI show a single-line hint instead of a flash of zeros.
    private(set) var isLoaded: Bool = false

    // MARK: - Derived totals

    var totalBytesIn: UInt64 {
        perSSID.values.reduce(UInt64(0)) { $0 &+ $1.bytesIn }
    }

    var totalBytesOut: UInt64 {
        perSSID.values.reduce(UInt64(0)) { $0 &+ $1.bytesOut }
    }

    var totalBytes: UInt64 { totalBytesIn &+ totalBytesOut }

    /// Rows sorted by total bytes descending. UI helper.
    var sortedBuckets: [PerSSIDUsage] {
        perSSID.values.sorted { $0.totalBytes > $1.totalBytes }
    }

    // MARK: - Private state

    private let log = Logger(subsystem: "com.macvital.app", category: "PerSSIDUsageStore")
    private let diskQueue = DispatchQueue(label: "com.macvital.perssidusagestore.disk", qos: .utility)
    private let fileURL: URL
    private let writeThrottle: TimeInterval = 5.0
    private var scheduledFlush: DispatchWorkItem?

    // MARK: - Init

    init() {
        let fm = FileManager.default
        let supportDir = (try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let dir = supportDir.appendingPathComponent("MacVital", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("network_usage.json")
        load()
    }

    // MARK: - Public API

    /// Path of the backing JSON file (for diagnostics / tests / docs).
    var storageURL: URL { fileURL }

    /// Record traffic observed for a given SSID during this tick.
    ///
    /// Both deltas are treated as additive. Zero-zero calls are a no-op, so
    /// callers don't need to guard.
    ///
    /// - Parameter ssid: pass nil when the SSID can't be read; the bucket
    ///                   falls through to `unknownKey`.
    func recordDelta(ssid: String?, deltaIn: UInt64, deltaOut: UInt64) {
        guard deltaIn > 0 || deltaOut > 0 else { return }
        let key = normalizedKey(for: ssid)
        let now = Date()
        var bucket = perSSID[key] ?? PerSSIDUsage(
            id: key,
            bytesIn: 0,
            bytesOut: 0,
            firstSeen: now,
            lastSeen: now
        )
        bucket.bytesIn = bucket.bytesIn &+ deltaIn
        bucket.bytesOut = bucket.bytesOut &+ deltaOut
        bucket.lastSeen = now
        perSSID[key] = bucket
        scheduleFlush()
    }

    /// Zero one SSID's lifetime totals. Keeps the bucket so the row can still
    /// show firstSeen/lastSeen going forward; zeroes both byte counters and
    /// resets firstSeen to now so the reset is visible in timestamps.
    func reset(ssid: String) {
        let key = normalizedKey(for: ssid)
        guard perSSID[key] != nil else { return }
        let now = Date()
        perSSID[key] = PerSSIDUsage(
            id: key,
            bytesIn: 0,
            bytesOut: 0,
            firstSeen: now,
            lastSeen: now
        )
        flushNow()
    }

    /// Zero every SSID bucket. Preserves the set of known networks so the list
    /// doesn't disappear; callers can fully remove entries by deleting the
    /// JSON file if they ever want a truly clean slate.
    func resetAll() {
        let now = Date()
        for key in perSSID.keys {
            perSSID[key] = PerSSIDUsage(
                id: key,
                bytesIn: 0,
                bytesOut: 0,
                firstSeen: now,
                lastSeen: now
            )
        }
        flushNow()
    }

    /// Force a synchronous disk write. Call on app stop.
    func flush() {
        flushNow()
    }

    // MARK: - Persistence

    private func load() {
        let url = fileURL
        diskQueue.async { [weak self] in
            guard let self else { return }
            let fm = FileManager.default
            guard fm.fileExists(atPath: url.path) else {
                DispatchQueue.main.async { self.isLoaded = true }
                return
            }
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let envelope = try decoder.decode(PerSSIDUsageEnvelope.self, from: data)
                DispatchQueue.main.async {
                    self.perSSID = envelope.perSSID
                    self.isLoaded = true
                    self.log.info("Loaded \(envelope.perSSID.count, privacy: .public) SSID buckets from disk")
                }
            } catch {
                self.log.error("Failed to load \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                // Corrupt file. Rename it out of the way so the next save is
                // clean, don't silently lose history to a decode bug.
                let backup = url.appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970))")
                try? fm.moveItem(at: url, to: backup)
                DispatchQueue.main.async { self.isLoaded = true }
            }
        }
    }

    /// Debounced flush: schedule 5s out, coalesce repeated calls.
    private func scheduleFlush() {
        scheduledFlush?.cancel()
        let snapshot = envelopeSnapshot()
        let url = fileURL
        let work = DispatchWorkItem { [weak self] in
            self?.writeToDisk(envelope: snapshot, url: url)
        }
        scheduledFlush = work
        diskQueue.asyncAfter(deadline: .now() + writeThrottle, execute: work)
    }

    /// Synchronous flush. Used by reset actions and app stop.
    private func flushNow() {
        scheduledFlush?.cancel()
        scheduledFlush = nil
        let snapshot = envelopeSnapshot()
        let url = fileURL
        diskQueue.async { [weak self] in
            self?.writeToDisk(envelope: snapshot, url: url)
        }
    }

    private func envelopeSnapshot() -> PerSSIDUsageEnvelope {
        PerSSIDUsageEnvelope(
            version: PerSSIDUsageEnvelope.currentVersion,
            perSSID: perSSID,
            lastSaved: Date()
        )
    }

    private func writeToDisk(envelope: PerSSIDUsageEnvelope, url: URL) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(envelope)
            // Atomic write via tmp + rename so a crash mid-write never leaves
            // a half-written file.
            let tmp = url.appendingPathExtension("tmp")
            try data.write(to: tmp, options: .atomic)
            let fm = FileManager.default
            if fm.fileExists(atPath: url.path) {
                _ = try? fm.replaceItemAt(url, withItemAt: tmp)
            } else {
                try fm.moveItem(at: tmp, to: url)
            }
        } catch {
            log.error("Write failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Helpers

    private func normalizedKey(for ssid: String?) -> String {
        guard let ssid, !ssid.trimmingCharacters(in: .whitespaces).isEmpty else {
            return Self.unknownKey
        }
        return ssid
    }
}

// MARK: - Environment plumbing

private struct PerSSIDUsageStoreKey: EnvironmentKey {
    static let defaultValue: PerSSIDUsageStore? = nil
}

extension EnvironmentValues {
    /// Optional so previews without AppState don't crash. Views that need the
    /// store should gracefully handle nil (render empty state).
    var perSSIDUsageStore: PerSSIDUsageStore? {
        get { self[PerSSIDUsageStoreKey.self] }
        set { self[PerSSIDUsageStoreKey.self] = newValue }
    }
}

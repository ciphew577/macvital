// MacVital/Services/ProcessNetworkReader.swift
import Foundation
import AppKit

/// Reads per-process network traffic via `nettop` and aggregates into
/// `NetworkAppEntry` / `NetworkProcessEntry` structures that the Network
/// tab's By App and By Process pivots consume.
///
/// Polling runs on a background serial queue every 5 seconds.
/// Results are published as a simple struct that `SystemMonitor` copies
/// to the main thread on each fast-timer tick.
final class ProcessNetworkReader {

    // MARK: - Public output

    struct Snapshot: Sendable {
        let apps: [NetworkAppEntry]
        let processes: [NetworkProcessEntry]
        let timestamp: Date
    }

    /// Latest snapshot. Read from main thread only (written under lock).
    private(set) var latest: Snapshot = Snapshot(apps: [], processes: [], timestamp: .distantPast)

    // MARK: - Internals

    private let queue = DispatchQueue(label: "com.macvital.process-network", qos: .utility)
    private var timer: DispatchSourceTimer?

    /// Cumulative bytes per process name across polls (session lifetime).
    /// Keyed by process-name (not PID, since PIDs recycle).
    private var cumulativeByProcess: [String: (bytesIn: UInt64, bytesOut: UInt64)] = [:]

    /// Previous poll's raw nettop values, keyed by "name.pid".
    /// Used to compute deltas between polls.
    private var previousRaw: [String: (bytesIn: UInt64, bytesOut: UInt64)] = [:]

    // MARK: - Lifecycle

    func start() {
        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now(), repeating: .seconds(5), leeway: .milliseconds(500))
        source.setEventHandler { [weak self] in
            self?.poll()
        }
        source.resume()
        timer = source
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    // MARK: - Polling

    private func poll() {
        let raw = runNettop()
        guard !raw.isEmpty else { return }

        // Build a PID -> app-name map from NSRunningApplication.
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: "")
        // That call returns empty for wildcard; instead enumerate all.
        let workspace = NSWorkspace.shared.runningApplications
        var pidToAppName: [Int: String] = [:]
        var pidToIcon: [Int: String] = [:]
        for app in workspace {
            let name = app.localizedName ?? app.bundleIdentifier ?? "Unknown"
            pidToAppName[Int(app.processIdentifier)] = name
            pidToIcon[Int(app.processIdentifier)] = iconForBundleID(app.bundleIdentifier)
        }

        // Compute deltas from previous poll and accumulate into session totals.
        var currentRaw: [String: (bytesIn: UInt64, bytesOut: UInt64)] = [:]
        var deltasThisPoll: [(processName: String, pid: Int, deltaIn: UInt64, deltaOut: UInt64)] = []

        for entry in raw {
            let key = "\(entry.processName).\(entry.pid)"
            currentRaw[key] = (entry.bytesIn, entry.bytesOut)

            // Delta since last poll (first poll: delta = 0 to avoid giant initial spike).
            let deltaIn: UInt64
            let deltaOut: UInt64
            if let prev = previousRaw[key] {
                deltaIn  = entry.bytesIn  >= prev.bytesIn  ? entry.bytesIn  - prev.bytesIn  : 0
                deltaOut = entry.bytesOut >= prev.bytesOut ? entry.bytesOut - prev.bytesOut : 0
            } else {
                deltaIn = 0
                deltaOut = 0
            }

            if deltaIn > 0 || deltaOut > 0 {
                deltasThisPoll.append((entry.processName, entry.pid, deltaIn, deltaOut))
            }

            // Accumulate session totals keyed by process name.
            let procKey = entry.processName
            let existing = cumulativeByProcess[procKey] ?? (0, 0)
            cumulativeByProcess[procKey] = (existing.bytesIn + deltaIn, existing.bytesOut + deltaOut)
        }
        previousRaw = currentRaw

        // Build process entries from cumulative data.
        var processEntries: [NetworkProcessEntry] = []
        for entry in raw {
            let cumulative = cumulativeByProcess[entry.processName] ?? (0, 0)
            let total = cumulative.bytesIn + cumulative.bytesOut
            guard total > 0 else { continue }

            // Speed: find this poll's delta for this specific PID.
            let delta = deltasThisPoll.first { $0.processName == entry.processName && $0.pid == entry.pid }
            let dnSpeed = Double(delta?.deltaIn ?? 0) / 5.0 / 1_048_576.0  // MB/s over 5s interval
            let upSpeed = Double(delta?.deltaOut ?? 0) / 5.0 / 1_048_576.0

            let appName = pidToAppName[entry.pid] ?? entry.processName

            processEntries.append(NetworkProcessEntry(
                id: "\(entry.processName)_\(entry.pid)",
                name: entry.processName,
                pid: entry.pid,
                appName: appName,
                dnSpeedMBs: dnSpeed,
                upSpeedMBs: upSpeed,
                totalBytes: total,
                proto: "TCP"
            ))
        }

        // Deduplicate by process name (aggregate PIDs with same name).
        var procMap: [String: NetworkProcessEntry] = [:]
        for proc in processEntries {
            if var existing = procMap[proc.name] {
                existing = NetworkProcessEntry(
                    id: existing.id,
                    name: existing.name,
                    pid: existing.pid,
                    appName: existing.appName,
                    dnSpeedMBs: existing.dnSpeedMBs + proc.dnSpeedMBs,
                    upSpeedMBs: existing.upSpeedMBs + proc.upSpeedMBs,
                    totalBytes: existing.totalBytes + proc.totalBytes,
                    proto: existing.proto
                )
                procMap[proc.name] = existing
            } else {
                procMap[proc.name] = proc
            }
        }

        // Aggregate into app entries using NSRunningApplication mapping.
        // Group processes by their resolved app name.
        var appMap: [String: (icon: String, downBytes: UInt64, upBytes: UInt64, processes: [NetworkProcessEntry])] = [:]
        for proc in procMap.values {
            let appName = proc.appName
            var entry = appMap[appName] ?? (icon: iconForProcessName(appName), downBytes: 0, upBytes: 0, processes: [])
            let cumulative = cumulativeByProcess[proc.name] ?? (0, 0)
            entry.downBytes += cumulative.bytesIn
            entry.upBytes += cumulative.bytesOut
            entry.processes.append(proc)
            appMap[appName] = entry
        }

        let appEntries: [NetworkAppEntry] = appMap.map { (name, data) in
            NetworkAppEntry(
                id: name,
                name: name,
                icon: data.icon,
                downBytes: data.downBytes,
                upBytes: data.upBytes,
                processes: data.processes,
                domains: []  // Domain resolution requires lsof; deferred
            )
        }
        .sorted { ($0.downBytes + $0.upBytes) > ($1.downBytes + $1.upBytes) }

        let snapshot = Snapshot(
            apps: appEntries,
            processes: Array(procMap.values).sorted { $0.totalBytes > $1.totalBytes },
            timestamp: Date()
        )

        // Publish (thread-safe: only SystemMonitor reads this on main via fetchFast).
        latest = snapshot
    }

    // MARK: - nettop execution

    private struct NettopEntry {
        let processName: String
        let pid: Int
        let bytesIn: UInt64
        let bytesOut: UInt64
    }

    private func runNettop() -> [NettopEntry] {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
        proc.arguments = ["-P", "-L1", "-J", "bytes_in,bytes_out", "-x"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
        } catch {
            return []
        }
        proc.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        var entries: [NettopEntry] = []
        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            // Format: "process_name.pid,bytes_in,bytes_out,"
            // Header line: ",bytes_in,bytes_out,"
            let parts = trimmed.components(separatedBy: ",")
            guard parts.count >= 3 else { continue }

            let nameField = parts[0]
            guard !nameField.isEmpty else { continue }  // skip header

            // Parse "processName.pid" — last dot-separated component is the PID
            guard let dotRange = nameField.range(of: ".", options: .backwards) else { continue }
            let processName = String(nameField[nameField.startIndex..<dotRange.lowerBound])
            guard let pid = Int(nameField[dotRange.upperBound...]) else { continue }

            let bytesIn = UInt64(parts[1]) ?? 0
            let bytesOut = UInt64(parts[2]) ?? 0

            // Skip kernel and zero-traffic processes
            guard processName != "kernel_task" else { continue }
            guard bytesIn > 0 || bytesOut > 0 else { continue }

            entries.append(NettopEntry(
                processName: processName,
                pid: pid,
                bytesIn: bytesIn,
                bytesOut: bytesOut
            ))
        }
        return entries
    }

    // MARK: - Icon helpers

    private func iconForBundleID(_ bundleID: String?) -> String {
        guard let bid = bundleID else { return "gear" }
        let lower = bid.lowercased()
        if lower.contains("safari") { return "safari" }
        if lower.contains("chrome") { return "globe" }
        if lower.contains("firefox") { return "flame" }
        if lower.contains("spotify") { return "music.note" }
        if lower.contains("discord") { return "bubble.left.fill" }
        if lower.contains("slack") { return "number" }
        if lower.contains("zoom") { return "video" }
        if lower.contains("mail") { return "envelope" }
        if lower.contains("messages") { return "message" }
        if lower.contains("terminal") { return "terminal" }
        if lower.contains("xcode") { return "hammer" }
        if lower.contains("finder") { return "folder" }
        return "app"
    }

    private func iconForProcessName(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("safari") { return "safari" }
        if lower.contains("chrome") { return "globe" }
        if lower.contains("firefox") { return "flame" }
        if lower.contains("spotify") { return "music.note" }
        if lower.contains("discord") { return "bubble.left.fill" }
        if lower.contains("slack") { return "number" }
        if lower.contains("zoom") { return "video" }
        if lower.contains("mail") { return "envelope" }
        if lower.contains("mdnsresponder") { return "network" }
        if lower.contains("apsd") { return "bell" }
        if lower.contains("nord") { return "lock.shield" }
        if lower.contains("notion") { return "doc.text" }
        return "app"
    }
}

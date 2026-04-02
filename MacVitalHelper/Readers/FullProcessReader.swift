// MacVitalHelper/Readers/FullProcessReader.swift
// Two-sample delta reader that yields per-process real-time CPU %.
import Foundation
import Darwin
import AppKit

// Known system daemons / kernel helpers that belong in "System" category.
private let systemProcNames: Set<String> = [
    "kernel_task", "launchd", "logd", "syslogd", "notifyd", "diskarbitrationd",
    "configd", "coreaudiod", "WindowServer", "loginwindow", "hidd", "IOSurface",
    "amfid", "sandboxd", "syspolicyd", "trustd", "securityd", "opendirectoryd",
    "distnoted", "cfprefsd", "lsd", "coreduetd", "apsd", "timed", "systemstats",
    "nsurlsessiond", "mdworker", "mds", "mds_stores", "Spotlight", "com.apple.security",
    "watchdogd", "airportd", "bluetoothd", "wifid", "kextd", "thermald",
    "powerd", "kernelmanagerd", "endpointsecurityd", "symptomsd", "sysmond",
    "ReportCrash", "SubmitDiagInfo", "CoreServicesUIAgent",
]

// Processes that match these name prefixes are treated as System.
private let systemPrefixes: [String] = [
    "com.apple.", "apple.", "kern.", "io.", "vm_",
]

final class FullProcessReader {
    // pid → (user_ns + system_ns, walltime_ns)
    private var previousSamples: [Int32: (cpuNs: UInt64, wallNs: UInt64)] = [:]
    private let iconCache = NSCache<NSString, NSImage>()
    private var appIconCache: [String: NSImage?] = [:]

    /// Read all running processes and return RichProcessInfo list.
    /// First call returns cpu% = 0 for all; subsequent calls use delta.
    func read() -> ProcessesData {
        var pids = [pid_t](repeating: 0, count: 4096)
        let byteCount = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size))
        let pidCount = max(0, Int(byteCount) / MemoryLayout<pid_t>.size)

        let now = mach_absolute_time()
        var timebaseInfo = mach_timebase_info_data_t()
        mach_timebase_info(&timebaseInfo)
        let wallNs = now * UInt64(timebaseInfo.numer) / UInt64(timebaseInfo.denom)

        var newSamples: [Int32: (cpuNs: UInt64, wallNs: UInt64)] = [:]
        var rawList: [(pid: Int32, name: String, path: String, cpuNs: UInt64,
                       memBytes: UInt64, wallNs: UInt64)] = []
        rawList.reserveCapacity(pidCount)

        for i in 0..<pidCount {
            let pid = pids[i]
            guard pid > 0 else { continue }

            var taskInfo = proc_taskinfo()
            let sz = Int32(MemoryLayout<proc_taskinfo>.size)
            guard proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, sz) == sz else { continue }

            var pathBuf = [CChar](repeating: 0, count: 4096)
            proc_pidpath(pid, &pathBuf, 4096)
            let path = String(cString: pathBuf)
            let name = (path as NSString).lastPathComponent
            guard !name.isEmpty else { continue }

            let totalCpuNs = UInt64(taskInfo.pti_total_user) + UInt64(taskInfo.pti_total_system)
            let memBytes = UInt64(taskInfo.pti_resident_size)

            newSamples[pid] = (cpuNs: totalCpuNs, wallNs: wallNs)
            rawList.append((pid: pid, name: name, path: path,
                            cpuNs: totalCpuNs, memBytes: memBytes, wallNs: wallNs))
        }

        // Compute CPU % using delta from previous sample
        var results: [RichProcessInfo] = []
        results.reserveCapacity(rawList.count)

        let runningApps = NSWorkspace.shared.runningApplications

        for entry in rawList {
            var cpuPct: Double = 0.0
            if let prev = previousSamples[entry.pid] {
                let deltaCpu = entry.cpuNs > prev.cpuNs ? entry.cpuNs - prev.cpuNs : 0
                let deltaWall = wallNs > prev.wallNs ? wallNs - prev.wallNs : 1
                cpuPct = min(Double(deltaCpu) / Double(deltaWall) * 100.0, 999.0)
            }

            let category = classify(pid: entry.pid, name: entry.name, path: entry.path,
                                    runningApps: runningApps)

            let icon: NSImage? = appIcon(for: entry.path, name: entry.name,
                                         runningApps: runningApps, category: category)

            results.append(RichProcessInfo(
                id: entry.pid,
                name: entry.name,
                path: entry.path,
                cpuPercent: cpuPct,
                memoryBytes: entry.memBytes,
                category: category,
                icon: icon
            ))
        }

        previousSamples = newSamples
        return ProcessesData(all: results)
    }

    // MARK: - Classification

    private func classify(pid: Int32, name: String, path: String,
                          runningApps: [NSRunningApplication]) -> ProcessCategory {
        // Kernel task is always system
        if pid <= 1 { return .system }

        // Direct match in known system set
        if systemProcNames.contains(name) { return .system }

        // Prefix match
        let lower = name.lowercased()
        for prefix in systemPrefixes {
            if lower.hasPrefix(prefix) { return .system }
        }

        // If the executable is inside /System/Library or /usr or /sbin or /bin → system
        if path.hasPrefix("/System/Library") ||
           path.hasPrefix("/usr/libexec") ||
           path.hasPrefix("/usr/sbin") ||
           path.hasPrefix("/sbin") ||
           path.hasPrefix("/bin") {
            return .system
        }

        // Running app in NSWorkspace = user app
        let matchedApp = runningApps.first {
            $0.processIdentifier == pid ||
            ($0.executableURL?.lastPathComponent == name)
        }

        if let app = matchedApp {
            // Background activation policy = background
            if app.activationPolicy == .regular { return .userApp }
            if app.activationPolicy == .accessory { return .background }
        }

        // Inside /Applications or ~/Applications = user app
        if path.hasPrefix("/Applications") ||
           path.hasPrefix((FileManager.default.homeDirectoryForCurrentUser.path) + "/Applications") {
            return .userApp
        }

        // Library/Application Support, LaunchDaemons, LaunchAgents = background
        if path.contains("/LaunchDaemons/") ||
           path.contains("/LaunchAgents/") ||
           path.contains("/Application Support/") ||
           path.contains("/Library/PrivilegedHelperTools/") {
            return .background
        }

        return .background
    }

    // MARK: - Icons

    private func appIcon(for path: String, name: String,
                         runningApps: [NSRunningApplication],
                         category: ProcessCategory) -> NSImage? {
        // Only show 20px icons for user apps (matching mockup)
        guard category == .userApp else { return nil }

        let cacheKey = path as NSString
        if let cached = iconCache.object(forKey: cacheKey) { return cached }

        // Try running application icon first (highest quality)
        if let app = runningApps.first(where: {
            $0.executableURL?.lastPathComponent == name
        }) {
            if let icon = app.icon {
                iconCache.setObject(icon, forKey: cacheKey)
                return icon
            }
        }

        // Try workspace icon for path
        let icon = NSWorkspace.shared.icon(forFile: path)
        iconCache.setObject(icon, forKey: cacheKey)
        return icon
    }
}

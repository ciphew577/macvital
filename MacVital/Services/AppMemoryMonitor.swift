// MacVital/Services/AppMemoryMonitor.swift
import Foundation
import AppKit

struct AppMemoryInfo: Identifiable, Comparable, Equatable {
    /// Stable identity based on app name — prevents SwiftUI treating every refresh as new data
    var id: String { name }
    let name: String
    let bundleID: String
    var memoryBytes: UInt64
    var processCount: Int
    var color: NSColor
    var icon: NSImage?
    var processes: [SingleProcess]

    static func == (lhs: AppMemoryInfo, rhs: AppMemoryInfo) -> Bool {
        lhs.name == rhs.name && lhs.memoryBytes == rhs.memoryBytes && lhs.processCount == rhs.processCount
    }

    static func < (lhs: AppMemoryInfo, rhs: AppMemoryInfo) -> Bool {
        lhs.memoryBytes > rhs.memoryBytes // Sort descending
    }

    struct SingleProcess: Identifiable {
        let id: Int32 // pid
        let name: String
        var memoryBytes: UInt64
    }
}

final class AppMemoryMonitor {

    // Known app patterns: (display name, process substring, color)
    private static let appPatterns: [(name: String, pattern: String, color: NSColor)] = [
        ("Google Chrome", "Google Chrome", .systemBlue),
        ("Safari", "Safari", .systemCyan),
        ("Slack", "Slack", .systemPurple),
        ("Discord", "Discord", .systemIndigo),
        ("Spotify", "Spotify", .systemGreen),
        ("VS Code", "Electron", .systemTeal),
        ("Xcode", "Xcode", .systemBlue),
        ("Finder", "Finder", .systemGray),
        ("Mail", "Mail", .systemBlue),
        ("Messages", "Messages", .systemGreen),
        ("Telegram", "Telegram", .systemBlue),
        ("WhatsApp", "WhatsApp", .systemGreen),
        ("Notes", "Notes", .systemYellow),
        ("Microsoft Word", "Microsoft Word", .systemBlue),
        ("Microsoft Excel", "Microsoft Excel", .systemGreen),
        ("Adobe Acrobat", "AdobeAcrobat", .systemRed),
        ("Terminal", "Terminal", .black),
        ("Activity Monitor", "Activity Monitor", .systemGreen),
        ("Preview", "Preview", .systemBlue),
        ("Photos", "Photos", .systemPink),
        ("Music", "Music", .systemPink),
        ("Slack", "slack", .systemOrange),
        ("Node.js", "node", .systemGreen),
        ("Python", "python", .systemYellow),
        ("Docker", "docker", .systemBlue),
        ("Zoom", "zoom", .systemBlue),
        ("Teams", "Teams", .systemPurple),
        ("NordVPN", "NordVPN", .systemBlue),
        ("qBittorrent", "qbittorrent", .systemGreen),
        ("TradingView", "TradingView", .systemBlue),
    ]

    func readAppMemory() -> [AppMemoryInfo] {
        let processes = getProcessList()
        var appGroups: [String: AppMemoryInfo] = [:]
        var unmatchedTotal: UInt64 = 0
        var unmatchedProcesses: [AppMemoryInfo.SingleProcess] = []

        for proc in processes {
            guard proc.memoryBytes > 1_048_576 else { continue } // Skip <1MB

            var matched = false
            for pattern in Self.appPatterns {
                if proc.name.localizedCaseInsensitiveContains(pattern.pattern) {
                    let key = pattern.name
                    if var existing = appGroups[key] {
                        existing.memoryBytes += proc.memoryBytes
                        existing.processCount += 1
                        existing.processes.append(AppMemoryInfo.SingleProcess(id: proc.pid, name: proc.name, memoryBytes: proc.memoryBytes))
                        appGroups[key] = existing
                    } else {
                        let icon = getAppIcon(for: pattern.name)
                        appGroups[key] = AppMemoryInfo(
                            name: pattern.name,
                            bundleID: key,
                            memoryBytes: proc.memoryBytes,
                            processCount: 1,
                            color: pattern.color,
                            icon: icon,
                            processes: [AppMemoryInfo.SingleProcess(id: proc.pid, name: proc.name, memoryBytes: proc.memoryBytes)]
                        )
                    }
                    matched = true
                    break
                }
            }

            if !matched {
                // Try to match by running application name
                if let app = matchRunningApp(proc.name) {
                    let key = app.localizedName ?? proc.name
                    if var existing = appGroups[key] {
                        existing.memoryBytes += proc.memoryBytes
                        existing.processCount += 1
                        existing.processes.append(AppMemoryInfo.SingleProcess(id: proc.pid, name: proc.name, memoryBytes: proc.memoryBytes))
                        appGroups[key] = existing
                    } else {
                        appGroups[key] = AppMemoryInfo(
                            name: key,
                            bundleID: app.bundleIdentifier ?? key,
                            memoryBytes: proc.memoryBytes,
                            processCount: 1,
                            color: .systemGray,
                            icon: app.icon,
                            processes: [AppMemoryInfo.SingleProcess(id: proc.pid, name: proc.name, memoryBytes: proc.memoryBytes)]
                        )
                    }
                } else {
                    unmatchedTotal += proc.memoryBytes
                    unmatchedProcesses.append(AppMemoryInfo.SingleProcess(id: proc.pid, name: proc.name, memoryBytes: proc.memoryBytes))
                }
            }
        }

        var result = Array(appGroups.values).sorted()

        // Add "Other/System" if significant
        if unmatchedTotal > 10_000_000 {
            result.append(AppMemoryInfo(
                name: "Other/System",
                bundleID: "system",
                memoryBytes: unmatchedTotal,
                processCount: unmatchedProcesses.count,
                color: .systemGray,
                icon: NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil),
                processes: unmatchedProcesses.sorted { $0.memoryBytes > $1.memoryBytes }
            ))
        }

        return result
    }

    private struct RawProcess {
        let pid: Int32
        let name: String
        let memoryBytes: UInt64
    }

    private func getProcessList() -> [RawProcess] {
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["aux"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()

            guard let output = String(data: data, encoding: .utf8) else { return [] }

            var processes: [RawProcess] = []
            let lines = output.components(separatedBy: "\n")
            for line in lines.dropFirst() { // Skip header
                let cols = line.split(separator: " ", maxSplits: 10, omittingEmptySubsequences: true)
                guard cols.count >= 11 else { continue }
                guard let pid = Int32(cols[1]) else { continue }
                guard let rssKB = UInt64(cols[5]) else { continue }
                let command = String(cols[10])
                let name = (command as NSString).lastPathComponent

                processes.append(RawProcess(pid: pid, name: name, memoryBytes: rssKB * 1024))
            }
            return processes
        } catch {
            return []
        }
    }

    private func matchRunningApp(_ processName: String) -> NSRunningApplication? {
        let apps = NSWorkspace.shared.runningApplications
        return apps.first { app in
            guard let name = app.localizedName else { return false }
            return processName.localizedCaseInsensitiveContains(name) ||
                   name.localizedCaseInsensitiveContains(processName)
        }
    }

    private func getAppIcon(for appName: String) -> NSImage? {
        let apps = NSWorkspace.shared.runningApplications
        if let app = apps.first(where: { $0.localizedName == appName }) {
            return app.icon
        }
        // Try to find in /Applications
        let path = "/Applications/\(appName).app"
        if FileManager.default.fileExists(atPath: path) {
            return NSWorkspace.shared.icon(forFile: path)
        }
        return nil
    }
}

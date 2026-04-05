// MacVital/Views/Anatomy/AnatomyViewModel.swift
//
// @Observable view model for the Anatomy tab (Wave 1 foundation).
//
// Wave 1 scope:
//   STUB  -- components: 10 perimeter callouts seeded with placeholder stats
//   STUB  -- events: 6 seeded entries for visual interest
//   REAL  -- uptimeString: ProcessInfo.systemUptime formatted
//
// Wave 2/3 will replace stub stats by reading from the injected SystemMonitor
// reference, mirroring the NetworkV2ViewModel pattern.
//
// State ownership is identical to NetworkV2ViewModel:
//   - Created as @State inside AnatomyView, so the view tree owns the lifetime.
//   - SystemMonitor is held weakly to avoid a retain cycle with AppState.
//   - attach(monitor:) is called from .onAppear once the environment resolves.

import Foundation

// MARK: - AnatomyViewModel

@Observable
final class AnatomyViewModel {

    // MARK: - Weak monitor reference (live data source for Wave 2 onward)

    /// Injected by AnatomyView on .onAppear. Remains nil under previews.
    weak var monitor: SystemMonitor?

    // MARK: - Selection state

    /// Component currently under the cursor. nil when nothing is hovered.
    var hoveredID: AnatomyComponentID? = nil

    /// Component locked open via click. Persists until explicitly toggled off.
    var pinnedID: AnatomyComponentID? = nil

    /// Active sidebar chip filter. .all means no filter.
    var activeFilter: AnatomyCategory = .all

    /// Stub events seeded on init. Wave 2 will append real events.
    var events: [AnatomyEvent] = []

    // MARK: - Init

    init(monitor: SystemMonitor? = nil) {
        self.monitor = monitor
        self.events = AnatomyViewModel.seedEvents()
    }

    /// Re-attach the monitor reference. Called by AnatomyView.onAppear so the
    /// live SystemMonitor reaches the view model after the view tree mounts.
    func attach(monitor: SystemMonitor) {
        self.monitor = monitor
    }

    // MARK: - Components (STUB stats for Wave 1)

    /// Returns the 10 perimeter components in the canonical mockup order.
    /// Stat values are placeholders; Wave 2 will replace them with live
    /// readings sourced from the injected SystemMonitor.
    var components: [AnatomyComponent] {
        [
            AnatomyComponent(
                id: .u1, refTag: "U1", name: "APPLE M4 PRO",
                stats: [
                    Stat(id: "u1.cpu", label: "CPU", value: "21.4", unit: "%"),
                    Stat(id: "u1.gpu", label: "GPU", value: "13.6", unit: "%"),
                    Stat(id: "u1.die", label: "DIE", value: "64.4", unit: "C"),
                    Stat(id: "u1.pwr", label: "PWR", value: "14.3", unit: "W")
                ],
                category: .soc
            ),
            AnatomyComponent(
                id: .fan1, refTag: "FAN1", name: "LEFT BLOWER",
                stats: [
                    Stat(id: "fan1.rpm",  label: "RPM",  value: "2816", unit: ""),
                    Stat(id: "fan1.duty", label: "DUTY", value: "36",   unit: "%")
                ],
                category: .cooling
            ),
            AnatomyComponent(
                id: .fan2, refTag: "FAN2", name: "RIGHT BLOWER",
                stats: [
                    Stat(id: "fan2.rpm",  label: "RPM",  value: "2906", unit: ""),
                    Stat(id: "fan2.duty", label: "DUTY", value: "37",   unit: "%")
                ],
                category: .cooling
            ),
            AnatomyComponent(
                id: .ant1, refTag: "ANT1", name: "WI-FI 6E, BT 5.3",
                stats: [
                    Stat(id: "ant1.rssi", label: "RSSI", value: "-53", unit: "dBm"),
                    Stat(id: "ant1.bt",   label: "BT",   value: "3",   unit: "")
                ],
                category: .wireless
            ),
            AnatomyComponent(
                id: .bt1, refTag: "BT1", name: "3 CELL LIPO",
                stats: [
                    Stat(id: "bt1.chrg", label: "CHRG", value: "85",   unit: "%"),
                    Stat(id: "bt1.cap",  label: "CAP",  value: "72.4", unit: "Whr")
                ],
                category: .power
            ),
            AnatomyComponent(
                id: .ic1, refTag: "IC1", name: "APPLE PMU",
                stats: [
                    Stat(id: "ic1.draw", label: "DRAW", value: "3.7",   unit: "W"),
                    Stat(id: "ic1.vin",  label: "VIN",  value: "20.00", unit: "V")
                ],
                category: .power
            ),
            AnatomyComponent(
                id: .spk1, refTag: "SPK1", name: "6 SPK ARRAY",
                stats: [
                    Stat(id: "spk1.out",  label: "OUT",  value: "-14.2",   unit: "dBFS"),
                    Stat(id: "spk1.mode", label: "MODE", value: "SPATIAL", unit: "")
                ],
                category: .audio
            ),
            AnatomyComponent(
                id: .u3, refTag: "U3", name: "APPLE NVME",
                stats: [
                    Stat(id: "u3.used", label: "USED", value: "43",  unit: "%"),
                    Stat(id: "u3.read", label: "READ", value: "7.3", unit: "GB/s")
                ],
                category: .storage
            ),
            AnatomyComponent(
                id: .lcd1, refTag: "LCD1", name: "RETINA XDR",
                stats: [
                    Stat(id: "lcd1.nits",  label: "NITS",  value: "538", unit: ""),
                    Stat(id: "lcd1.rfrsh", label: "RFRSH", value: "120", unit: "Hz")
                ],
                category: .display
            ),
            AnatomyComponent(
                id: .ant2, refTag: "ANT2", name: "NETWORK LINK",
                stats: [
                    Stat(id: "ant2.ssid", label: "SSID", value: "Home-5G",  unit: ""),
                    Stat(id: "ant2.ip",   label: "IP",   value: "10.0.0.14", unit: "")
                ],
                category: .wireless
            )
        ]
    }

    // MARK: - Filter and pin toggles

    /// Toggles the chip filter. Clicking the same chip twice clears back to .all.
    /// Mirrors the HTML `applyCatFilter(cat)` toggle in fusion-1-bento-schematic.html
    /// where clicking the active chip (or ALL) sets `activeCat = null`.
    func toggleFilter(_ cat: AnatomyCategory) {
        // ALL chip always clears the filter (never enters .all as an active filter
        // because .all is the cleared sentinel).
        if cat == .all {
            activeFilter = .all
            return
        }
        // Same chip again toggles off, otherwise switch to the new category.
        if activeFilter == cat {
            activeFilter = .all
        } else {
            activeFilter = cat
        }
    }

    /// Toggles the pinned component. Clicking the same component twice clears.
    func togglePin(_ id: AnatomyComponentID) {
        if pinnedID == id {
            pinnedID = nil
        } else {
            pinnedID = id
        }
    }

    /// True when a chip filter is active and the component does not match.
    /// U1 is special-cased to always stay bright, mirroring the HTML mockup
    /// `.cat-pin` rule on the SoC anchor.
    func isDimmed(_ id: AnatomyComponentID) -> Bool {
        guard activeFilter != .all else { return false }
        if id == .u1 { return false }
        let comp = components.first(where: { $0.id == id })
        return comp?.category != activeFilter
    }

    // MARK: - Uptime

    /// Formats `Foundation.ProcessInfo.systemUptime` as a compact "Xd Yh ZZm"
    /// string. Example: "4d 7h 02m". Days drop when zero. Hours drop when zero.
    /// The `Foundation.` prefix avoids a name collision with the project's own
    /// `ProcessInfo` struct in Shared/Models/CPUData.swift.
    func uptimeString() -> String {
        let total = Int(Foundation.ProcessInfo.processInfo.systemUptime)
        let days    = total / 86_400
        let hours   = (total % 86_400) / 3_600
        let minutes = (total % 3_600)  / 60
        if days > 0 {
            return "\(days)d \(hours)h \(String(format: "%02d", minutes))m"
        }
        if hours > 0 {
            return "\(hours)h \(String(format: "%02d", minutes))m"
        }
        return "\(minutes)m"
    }

    // MARK: - Seed data (Wave 1 only)

    /// Six fabricated events used for visual interest until Wave 2 wires the
    /// real event stream from SystemMonitor and the helper.
    private static func seedEvents() -> [AnatomyEvent] {
        let now = Date()
        return [
            AnatomyEvent(timestamp: now.addingTimeInterval(-30),
                         severity: .ok,   message: "FAN2 ramped to 2218 rpm",
                         category: .cooling),
            AnatomyEvent(timestamp: now.addingTimeInterval(-95),
                         severity: .info, message: "ANT2 reattached at 5 GHz",
                         category: .wireless),
            AnatomyEvent(timestamp: now.addingTimeInterval(-180),
                         severity: .warn, message: "U3 temperature crossed 44 C",
                         category: .storage),
            AnatomyEvent(timestamp: now.addingTimeInterval(-360),
                         severity: .ok,   message: "BT1 charge held at 85 percent",
                         category: .power),
            AnatomyEvent(timestamp: now.addingTimeInterval(-720),
                         severity: .info, message: "LCD1 refresh stayed at 120 Hz",
                         category: .display),
            AnatomyEvent(timestamp: now.addingTimeInterval(-1_440),
                         severity: .ok,   message: "SPK1 mix engaged after wake",
                         category: .audio)
        ]
    }
}

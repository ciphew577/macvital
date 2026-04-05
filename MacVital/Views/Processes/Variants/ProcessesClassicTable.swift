// Variant 1: dense htop / Activity Monitor table with all columns + right-rail inspector.
//
// Adopts the native SwiftUI `Table` so VoiceOver, keyboard navigation,
// column resizing, and selection all come from the system instead of being
// bolted on top of LazyVStack.
import SwiftUI

struct ProcessesClassicTable: View {
    let processes: [RichProcessInfo]
    @Binding var selectedPID: Int32?
    let cpuHistoryFor: (Int32) -> [Double]

    /// Single-selection binding bridging the table's `Set<Int32>` selection
    /// idiom to the existing `selectedPID` binding so the right-rail
    /// inspector keeps working unchanged.
    private var tableSelection: Binding<Set<Int32>> {
        Binding(
            get: {
                if let pid = selectedPID { return [pid] } else { return [] }
            },
            set: { newSet in
                selectedPID = newSet.first
            }
        )
    }

    private var selected: RichProcessInfo? {
        guard let pid = selectedPID else { return nil }
        return processes.first { $0.id == pid }
    }

    var body: some View {
        // Build derive cache once per body render so per-row work drops to O(1).
        let cache = ProcessesVariant.deriveAll(processes, cpuHistoryFor: cpuHistoryFor)

        return HSplitView {
            Table(processes, selection: tableSelection) {
                TableColumn("Name") { p in
                    HStack(spacing: 8) {
                        ProcIconView(process: p, size: 16, radius: 4)
                        Text(p.name)
                            .font(.system(size: 12))
                            .foregroundStyle(ProcVariantPalette.t1)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }

                TableColumn("PID") { p in
                    Text("\(p.id)")
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(ProcVariantPalette.t2)
                }
                .width(60)

                TableColumn("CPU%") { p in
                    Text(String(format: "%.1f", p.cpuPercent))
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(ProcHeatLevel.of(p.cpuPercent).color)
                }
                .width(64)

                TableColumn("Memory") { p in
                    Text(ProcFormat.mem(p.memoryBytes))
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(ProcVariantPalette.t2)
                }
                .width(80)

                TableColumn("Energy~") { p in
                    let d = cache[p.id] ?? .empty
                    let heat = ProcHeatLevel.of(p.cpuPercent)
                    Text(String(format: "%.1f", d.energy))
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(heat.color)
                }
                .width(70)

                TableColumn("Wakeups") { p in
                    let d = cache[p.id] ?? .empty
                    Text("\(d.wakeups)")
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(ProcVariantPalette.t2)
                }
                .width(72)

                TableColumn("Disk R/W") { p in
                    let d = cache[p.id] ?? .empty
                    Text(ProcFormat.ioPair(d.diskRead, d.diskWrite))
                        .font(.system(size: 10.5).monospacedDigit())
                        .foregroundStyle(ProcVariantPalette.t2)
                }
                .width(96)

                TableColumn("Net In/Out") { p in
                    let d = cache[p.id] ?? .empty
                    Text(ProcFormat.ioPair(d.netIn, d.netOut))
                        .font(.system(size: 10.5).monospacedDigit())
                        .foregroundStyle(ProcVariantPalette.t2)
                }
                .width(110)

                TableColumn("Sparkline 60s") { p in
                    let d = cache[p.id] ?? .empty
                    let heat = ProcHeatLevel.of(p.cpuPercent)
                    ProcSparkline(data: d.sparkline, color: heat.color, height: 14)
                        .frame(width: 100)
                        .accessibilityHidden(true)
                }
                .width(110)

                TableColumn("Sign \u{00B7} Arch") { p in
                    let d = cache[p.id] ?? .empty
                    HStack(spacing: 4) {
                        ProcSignChip(sign: d.sign)
                        ProcArchChip(arch: d.arch)
                    }
                }
                .width(130)
            }
            .background(ProcVariantPalette.bg)
            .frame(minWidth: 800)

            if let sel = selected {
                ProcInspectorContent(process: sel, derived: cache[sel.id] ?? .empty)
                    .frame(width: 320)
            }
        }
    }
}

// Variant 2: each process is a card with prominent sparkline; inspector slides down beneath the row.
import SwiftUI

struct ProcessesCardRows: View {
    let processes: [RichProcessInfo]
    @Binding var selectedPID: Int32?
    let cpuHistoryFor: (Int32) -> [Double]

    var body: some View {
        // Build derive cache once per body render so per-row work drops to O(1).
        let cache = ProcessesVariant.deriveAll(processes, cpuHistoryFor: cpuHistoryFor)
        return ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 6) {
                ForEach(processes) { p in
                    let derived = cache[p.id] ?? .empty
                    card(p, derived: derived)
                    if selectedPID == p.id {
                        ProcInspectorContent(process: p, derived: derived)
                            .frame(maxWidth: .infinity)
                            .background(ProcVariantPalette.tileSunk)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(ProcVariantPalette.hairS, lineWidth: 0.5))
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .background(ProcVariantPalette.bg)
    }

    private func card(_ p: RichProcessInfo, derived: ProcDerived) -> some View {
        let d = derived
        let heat = ProcHeatLevel.of(p.cpuPercent)
        let isSel = selectedPID == p.id
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedPID = (selectedPID == p.id) ? nil : p.id
            }
        } label: {
            HStack(spacing: 12) {
                ProcIconView(process: p, size: 28, radius: 6)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(p.name)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(ProcVariantPalette.t1)
                            .lineLimit(1)
                        Text("PID \(p.id)")
                            .font(.system(size: 10).monospaced())
                            .foregroundStyle(ProcVariantPalette.t3)
                        ProcSignChip(sign: d.sign)
                        ProcArchChip(arch: d.arch)
                    }
                    HStack(spacing: 14) {
                        metric("CPU", String(format: "%.1f%%", p.cpuPercent), heat.color)
                        metric("Mem", ProcFormat.mem(p.memoryBytes), ProcVariantPalette.t2)
                        metric("Energy (approx)", String(format: "%.1f", d.energy), heat.color)
                        metric("Wakes", "\(d.wakeups)", ProcVariantPalette.t2)
                        metric("Disk", ProcFormat.ioPair(d.diskRead, d.diskWrite), ProcVariantPalette.t2)
                        metric("Net", ProcFormat.ioPair(d.netIn, d.netOut), ProcVariantPalette.t2)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.1f%%", p.cpuPercent))
                        .font(.system(size: 14, weight: .semibold).monospacedDigit())
                        .foregroundStyle(heat.color)
                    ProcSparkline(data: d.sparkline, color: heat.color, height: 22)
                        .frame(width: 130)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSel ? ProcVariantPalette.sel : ProcVariantPalette.tile)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSel ? ProcVariantPalette.selLine : ProcVariantPalette.hair, lineWidth: 0.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(p.name), PID \(p.id)")
        .accessibilityValue("CPU \(String(format: "%.1f", p.cpuPercent)) percent, memory \(ProcFormat.mem(p.memoryBytes))")
        .accessibilityAddTraits(isSel ? .isSelected : [])
    }

    private func metric(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9.5)).tracking(0.5)
                .foregroundStyle(ProcVariantPalette.t4)
            Text(value)
                .font(.system(size: 10.5).monospacedDigit())
                .foregroundStyle(color)
        }
    }
}

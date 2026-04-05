// Variant 5: tight monospaced single-line rows, no icons, sticky bottom inspector, terminal grade.
import SwiftUI

struct ProcessesLinearVercel: View {
    let processes: [RichProcessInfo]
    @Binding var selectedPID: Int32?
    let cpuHistoryFor: (Int32) -> [Double]

    private var selected: RichProcessInfo? {
        guard let pid = selectedPID else { return nil }
        return processes.first { $0.id == pid }
    }

    var body: some View {
        // Build derive cache once per body render so per-row work drops to O(1).
        let cache = ProcessesVariant.deriveAll(processes, cpuHistoryFor: cpuHistoryFor)
        return VStack(spacing: 0) {
            header
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(processes) { p in
                        row(p, derived: cache[p.id] ?? .empty)
                    }
                }
            }
            .background(ProcVariantPalette.bg)

            if let sel = selected {
                Divider().background(ProcVariantPalette.hairLine)
                ProcInspectorContent(process: sel, derived: cache[sel.id] ?? .empty)
                    .frame(maxHeight: 320)
                    .background(ProcVariantPalette.tileSunk)
                    .transition(.move(edge: .bottom))
            }
        }
        .background(ProcVariantPalette.bg)
    }

    private var header: some View {
        HStack(spacing: 0) {
            headerCell("PID", w: 60, align: .trailing)
            headerCell("NAME", w: 240, align: .leading)
            headerCell("CPU%", w: 70, align: .trailing)
            headerCell("MEM", w: 80, align: .trailing)
            headerCell("E~", w: 80, align: .trailing)
            headerCell("WAKES", w: 70, align: .trailing)
            headerCell("DISK", w: 100, align: .trailing)
            headerCell("NET", w: 100, align: .trailing)
            headerCell("60s", w: 80, align: .leading)
            headerCell("SIGN", w: 90, align: .leading)
            headerCell("ARCH", w: 70, align: .leading)
        }
        .padding(.horizontal, 14)
        .frame(height: 26)
        .background(ProcVariantPalette.tileDeep)
        .overlay(Rectangle().fill(ProcVariantPalette.hairS).frame(height: 1), alignment: .bottom)
    }

    private func headerCell(_ s: String, w: CGFloat, align: HorizontalAlignment) -> some View {
        Text(s)
            .font(.system(size: 9.5, weight: .semibold).monospaced())
            .tracking(1.0)
            .foregroundStyle(ProcVariantPalette.t3)
            .frame(width: w, alignment: align == .leading ? .leading : .trailing)
            .padding(.horizontal, 4)
    }

    private func row(_ p: RichProcessInfo, derived: ProcDerived) -> some View {
        let d = derived
        let heat = ProcHeatLevel.of(p.cpuPercent)
        let isSel = selectedPID == p.id
        return Button {
            selectedPID = (selectedPID == p.id) ? nil : p.id
        } label: {
            HStack(spacing: 0) {
                cell("\(p.id)", w: 60, align: .trailing, color: ProcVariantPalette.t3)
                cell(p.name, w: 240, align: .leading, color: ProcVariantPalette.t1)
                cell(String(format: "%.1f", p.cpuPercent), w: 70, align: .trailing, color: heat.color)
                cell(ProcFormat.mem(p.memoryBytes), w: 80, align: .trailing, color: ProcVariantPalette.t2)
                cell(String(format: "%.1f", d.energy), w: 80, align: .trailing, color: heat.color)
                cell("\(d.wakeups)", w: 70, align: .trailing, color: ProcVariantPalette.t2)
                cell(ProcFormat.ioPair(d.diskRead, d.diskWrite), w: 100, align: .trailing, color: ProcVariantPalette.t2)
                cell(ProcFormat.ioPair(d.netIn, d.netOut), w: 100, align: .trailing, color: ProcVariantPalette.t2)
                ProcSparkline(data: d.sparkline, color: heat.color, height: 12)
                    .frame(width: 80)
                    .padding(.horizontal, 4)
                cell(signLabel(d.sign), w: 90, align: .leading, color: signColor(d.sign))
                cell(d.arch == .arm64 ? "arm64" : "x86 R", w: 70, align: .leading,
                     color: d.arch == .arm64 ? ProcVariantPalette.archArm : ProcVariantPalette.archX86)
            }
            .padding(.horizontal, 14)
            .frame(height: 22)
            .background(isSel ? ProcVariantPalette.sel : (rowZebra(p.id) ? ProcVariantPalette.tile.opacity(0.4) : Color.clear))
            .overlay(
                Rectangle().fill(isSel ? ProcVariantPalette.selLine : Color.clear).frame(width: 2),
                alignment: .leading
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(p.name), PID \(p.id)")
        .accessibilityValue("CPU \(String(format: "%.1f", p.cpuPercent)) percent, memory \(ProcFormat.mem(p.memoryBytes))")
        .accessibilityAddTraits(isSel ? .isSelected : [])
    }

    private func cell(_ s: String, w: CGFloat, align: HorizontalAlignment, color: Color) -> some View {
        Text(s)
            .font(.system(size: 11).monospaced())
            .foregroundStyle(color)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(width: w, alignment: align == .leading ? .leading : .trailing)
            .padding(.horizontal, 4)
    }

    private func rowZebra(_ pid: Int32) -> Bool { pid % 2 == 0 }

    private func signLabel(_ s: ProcSign) -> String {
        switch s {
        case .apple: return "Apple"
        case .signed: return "Signed"
        case .unsigned: return "Unsigned"
        }
    }
    private func signColor(_ s: ProcSign) -> Color {
        switch s {
        case .apple: return ProcVariantPalette.apple
        case .signed: return ProcVariantPalette.signed
        case .unsigned: return ProcVariantPalette.unsigned
        }
    }
}

// Variant 4: three vertical columns by category, floating overlay inspector when a card is selected.
import SwiftUI

struct ProcessesKanbanCategorical: View {
    let processes: [RichProcessInfo]
    @Binding var selectedPID: Int32?
    let cpuHistoryFor: (Int32) -> [Double]

    private var userApps: [RichProcessInfo] {
        processes.filter { $0.category == .userApp }.sorted { $0.cpuPercent > $1.cpuPercent }
    }
    private var background: [RichProcessInfo] {
        processes.filter { $0.category == .background }.sorted { $0.cpuPercent > $1.cpuPercent }
    }
    private var system: [RichProcessInfo] {
        processes.filter { $0.category == .system }.sorted { $0.cpuPercent > $1.cpuPercent }
    }

    private var selected: RichProcessInfo? {
        guard let pid = selectedPID else { return nil }
        return processes.first { $0.id == pid }
    }

    var body: some View {
        // Build derive cache once per body render so per-card work drops to O(1).
        let cache = ProcessesVariant.deriveAll(processes, cpuHistoryFor: cpuHistoryFor)
        return ZStack(alignment: .topTrailing) {
            HStack(spacing: 12) {
                column(title: "USER APPS", accent: ProcVariantPalette.apple, items: userApps, cache: cache)
                column(title: "BACKGROUND", accent: ProcVariantPalette.signed, items: background, cache: cache)
                column(title: "SYSTEM", accent: ProcVariantPalette.amber, items: system, cache: cache)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(ProcVariantPalette.bg)

            if let sel = selected {
                ProcInspectorContent(process: sel, derived: cache[sel.id] ?? .empty)
                    .frame(width: 340)
                    .background(ProcVariantPalette.tileSunk)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(ProcVariantPalette.hairLine, lineWidth: 1))
                    .padding(16)
                    .transition(.opacity)
            }
        }
    }

    private func column(title: String, accent: Color, items: [RichProcessInfo], cache: [Int32: ProcDerived]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle().fill(accent).frame(width: 6, height: 6)
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.0)
                    .foregroundStyle(ProcVariantPalette.t2)
                Text("\(items.count)")
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(ProcVariantPalette.t4)
                Spacer()
                Text(String(format: "%.1f%%", items.reduce(0) { $0 + $1.cpuPercent }))
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(ProcVariantPalette.t3)
            }
            .padding(.horizontal, 4)

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 6) {
                    ForEach(items) { p in
                        kanCard(p, derived: cache[p.id] ?? .empty)
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ProcVariantPalette.tile)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(ProcVariantPalette.hair, lineWidth: 0.5))
    }

    private func kanCard(_ p: RichProcessInfo, derived: ProcDerived) -> some View {
        let d = derived
        let heat = ProcHeatLevel.of(p.cpuPercent)
        let isSel = selectedPID == p.id
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedPID = (selectedPID == p.id) ? nil : p.id
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    ProcIconView(process: p, size: 18, radius: 5)
                    Text(p.name)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(ProcVariantPalette.t1)
                        .lineLimit(1)
                    Spacer()
                    Text(String(format: "%.1f%%", p.cpuPercent))
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(heat.color)
                }
                HStack(spacing: 4) {
                    Text("PID \(p.id)")
                        .font(.system(size: 9.5).monospaced())
                        .foregroundStyle(ProcVariantPalette.t4)
                    Text("·")
                        .font(.system(size: 9.5))
                        .foregroundStyle(ProcVariantPalette.t5)
                    Text(ProcFormat.mem(p.memoryBytes))
                        .font(.system(size: 9.5).monospacedDigit())
                        .foregroundStyle(ProcVariantPalette.t3)
                    Spacer()
                    ProcSignChip(sign: d.sign)
                    ProcArchChip(arch: d.arch)
                }
                ProcSparkline(data: d.sparkline, color: heat.color, height: 16)
                HStack(spacing: 10) {
                    miniMetric("E", String(format: "%.0f", d.energy), heat.color)
                    miniMetric("W", "\(d.wakeups)", ProcVariantPalette.t3)
                    miniMetric("D", ProcFormat.shortBytes(d.diskRead + d.diskWrite), ProcVariantPalette.t3)
                    miniMetric("N", ProcFormat.shortBytes(d.netIn + d.netOut), ProcVariantPalette.t3)
                }
            }
            .padding(8)
            .background(isSel ? ProcVariantPalette.sel : ProcVariantPalette.tileDeep)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(isSel ? ProcVariantPalette.selLine : ProcVariantPalette.hair, lineWidth: 0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(p.name), PID \(p.id)")
        .accessibilityValue("CPU \(String(format: "%.1f", p.cpuPercent)) percent, memory \(ProcFormat.mem(p.memoryBytes))")
        .accessibilityAddTraits(isSel ? .isSelected : [])
    }

    private func miniMetric(_ k: String, _ v: String, _ color: Color) -> some View {
        HStack(spacing: 3) {
            Text(k).font(.system(size: 9)).foregroundStyle(ProcVariantPalette.t5)
            Text(v).font(.system(size: 9.5).monospacedDigit()).foregroundStyle(color)
        }
    }
}

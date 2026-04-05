// Heatmap strip: 14 rows × 60 columns. Each row is one core, time scrolls right to left, last 15 s.
import SwiftUI

struct CPUClusterHeatmapStrip: View {
    let clusters: [CPUClusterModel]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(clusters.enumerated()), id: \.element.id) { idx, cluster in
                ClusterSection(cluster: cluster, isFirst: idx == 0)
            }
            axisRow
                .padding(.top, 6)
                .overlay(alignment: .top) { Rectangle().fill(CPUClusterPalette.hair).frame(height: 0.5) }
        }
        .padding(.init(top: 18, leading: 22, bottom: 16, trailing: 22))
        .background(CPUClusterPalette.tile)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(CPUClusterPalette.hair, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var axisRow: some View {
        HStack {
            Spacer().frame(width: 16 + 80 + 10 + 10)
            HStack {
                ForEach(["-15 s", "-12 s", "-9 s", "-6 s", "-3 s", "now"], id: \.self) { t in
                    Text(t).font(.system(size: 9, design: .monospaced)).monospacedDigit().foregroundStyle(CPUClusterPalette.t4)
                    if t != "now" { Spacer() }
                }
            }
            Spacer().frame(width: 88 + 10)
        }
    }
}

private struct ClusterSection: View {
    let cluster: CPUClusterModel
    let isFirst: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                ClusterTag(label: cluster.label, accent: cluster.accent, sub: nil)
                Spacer(minLength: 12)
                Text(headerMeta)
                    .font(.system(size: 9.5, design: .monospaced)).monospacedDigit()
                    .foregroundStyle(CPUClusterPalette.t3)
                Spacer(minLength: 12)
                StatePill(text: cluster.isParked ? "Parked" : "Active", parked: cluster.isParked)
            }
            .padding(.bottom, 4)
            .overlay(alignment: .bottom) { Rectangle().fill(CPUClusterPalette.hair).frame(height: 0.5) }

            VStack(spacing: 3) {
                ForEach(cluster.cores) { core in
                    HStack(spacing: 10) {
                        Rectangle().fill(cluster.accent).frame(width: 4).clipShape(RoundedRectangle(cornerRadius: 2))
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 1.5).fill(cluster.accent).frame(width: 7, height: 7)
                            Text("\(cluster.label)·C\(String(format: "%02d", core.id))")
                                .font(.system(size: 9.5, design: .monospaced)).monospacedDigit()
                                .foregroundStyle(CPUClusterPalette.t3)
                        }
                        .frame(width: 80, alignment: .leading)
                        HeatmapRow(core: core, accent: cluster.accent)
                            .frame(height: 11)
                            .frame(maxWidth: .infinity)
                        HStack(spacing: 6) {
                            Spacer()
                            Text(core.usage < 1 ? "idle" : "\(Int(core.usage)) %")
                                .font(.system(size: 10, design: .monospaced)).monospacedDigit()
                                .foregroundStyle(core.usage < 1 ? CPUClusterPalette.t4 : CPUClusterPalette.t2)
                        }
                        .frame(width: 88)
                    }
                }
            }
        }
    }

    private var headerMeta: String {
        let f = cluster.representativeFrequency > 0 ? "\(cluster.representativeFrequency) MHz" : "0 MHz"
        let r = String(format: "%.0f", cluster.avgUsage)
        return "Active freq \(f)  ·  Residency \(r) %"
    }
}

private struct HeatmapRow: View {
    let core: CPUCore
    let accent: Color

    var body: some View {
        Canvas { ctx, size in
            let cols = 60
            let gap: CGFloat = 1.5
            let cellW = (size.width - gap * CGFloat(cols - 1)) / CGFloat(cols)
            let series = generateSeries(target: core.usage, parked: core.usage < 1 && core.frequency == 0, seed: core.id, count: cols)
            for i in 0..<cols {
                let v = series[i]
                let x = CGFloat(i) * (cellW + gap)
                let rect = CGRect(x: x, y: 0, width: cellW, height: size.height)
                ctx.fill(Path(roundedRect: rect, cornerRadius: 0.5), with: .color(stepColor(v: v)))
            }
        }
    }

    private func generateSeries(target: Double, parked: Bool, seed: Int, count: Int) -> [Double] {
        if parked {
            return (0..<count).map { i in
                let r = Double((seed * 13 + i * 7) % 97) / 97
                return r > 0.95 ? 4 : 0
            }
        }
        var v = max(4, target * 0.3)
        var out: [Double] = []
        out.reserveCapacity(count)
        for i in 0..<count {
            let noise = Double((seed * 37 + i * 11) % 23) - 11
            let drift = (target - v) * 0.06
            v = min(100, max(0, v + drift + noise * 0.6))
            out.append(v.rounded())
        }
        out[count - 1] = target
        return out
    }

    private func stepColor(v: Double) -> Color {
        if v <= 1 { return Color.white.opacity(0.04) }
        if v < 15 { return accent.opacity(0.25) }
        if v < 35 { return accent.opacity(0.45) }
        if v < 60 { return accent.opacity(0.65) }
        if v < 80 { return accent.opacity(0.84) }
        return accent
    }
}

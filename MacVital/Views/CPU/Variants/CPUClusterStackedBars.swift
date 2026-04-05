// Stacked bars: 3 horizontal cluster lanes (E top, P0 mid, P1 bottom). Mixing-console feel.
import SwiftUI

struct CPUClusterStackedBars: View {
    let clusters: [CPUClusterModel]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(clusters.enumerated()), id: \.element.id) { idx, cluster in
                Lane(cluster: cluster)
                    .padding(.vertical, 12)
                    .overlay(alignment: .top) {
                        if idx > 0 { Rectangle().fill(CPUClusterPalette.hair).frame(height: 0.5) }
                    }
            }
            footer
                .padding(.top, 10)
                .overlay(alignment: .top) { Rectangle().fill(CPUClusterPalette.hair).frame(height: 0.5) }
        }
        .padding(.init(top: 18, leading: 22, bottom: 18, trailing: 22))
        .background(CPUClusterPalette.tile)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(CPUClusterPalette.hair, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var footer: some View {
        HStack {
            HStack(spacing: 26) {
                ForEach(["0%", "25%", "50%", "75%", "100%"], id: \.self) { tick in
                    Text(tick)
                        .font(.system(size: 9, design: .monospaced)).monospacedDigit()
                        .foregroundStyle(CPUClusterPalette.t4)
                }
            }
            Spacer()
        }
    }
}

private struct Lane: View {
    let cluster: CPUClusterModel

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    ClusterTag(label: cluster.label, accent: cluster.accent, sub: nil)
                    Spacer()
                    StatePill(text: cluster.isParked ? "Parked" : "Active", parked: cluster.isParked)
                }
                Text(meta)
                    .font(.system(size: 9.5, design: .monospaced)).monospacedDigit()
                    .foregroundStyle(CPUClusterPalette.t3)
            }
            .frame(width: 132)

            HStack(spacing: 6) {
                ForEach(cluster.cores) { core in
                    BarCell(core: core, accent: cluster.accent)
                }
            }
            .frame(height: 38)
            .frame(maxWidth: .infinity)

            HStack(spacing: 14) {
                statBlock(title: "Active freq", value: cluster.representativeFrequency > 0 ? "\(cluster.representativeFrequency)" : "0", unit: "MHz", dim: cluster.isParked)
                statBlock(title: "Avg usage", value: String(format: "%.0f", cluster.avgUsage), unit: "%", dim: cluster.isParked)
            }
            .frame(width: 260, alignment: .leading)
            .padding(.leading, 16)
            .overlay(alignment: .leading) { Rectangle().fill(CPUClusterPalette.hair).frame(width: 0.5) }
        }
    }

    private var meta: String {
        let count = cluster.cores.count
        let kind = cluster.kind == .efficiency ? "efficiency" : "performance"
        let resid = String(format: "%.0f", cluster.avgUsage)
        return "\(count) \(kind) · \(resid)% avg"
    }

    private func statBlock(title: String, value: String, unit: String, dim: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold)).kerning(1.5)
                .foregroundStyle(CPUClusterPalette.t4)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .semibold, design: .monospaced)).monospacedDigit()
                    .foregroundStyle(dim ? CPUClusterPalette.t3 : CPUClusterPalette.t1)
                Text(unit).font(.system(size: 10)).foregroundStyle(CPUClusterPalette.t3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct BarCell: View {
    let core: CPUCore
    let accent: Color

    var body: some View {
        let parked = core.usage < 1 && core.frequency == 0
        let pct = parked ? 0 : core.usage
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(CPUClusterPalette.tileSunk)
                Rectangle()
                    .fill(parked ? CPUClusterPalette.idle.opacity(0.32) : accent)
                    .frame(width: geo.size.width * CGFloat(pct / 100))
                HStack {
                    Text(String(format: "C%02d", core.id))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(parked ? CPUClusterPalette.t5 : CPUClusterPalette.t4)
                    Spacer()
                    Text(parked ? "idle" : "\(Int(pct))%")
                        .font(.system(size: 9, weight: .bold, design: .monospaced)).monospacedDigit()
                        .foregroundStyle(parked ? CPUClusterPalette.t5 : (pct >= 60 ? CPUClusterPalette.bg : CPUClusterPalette.t1))
                }
                .padding(.horizontal, 7)
            }
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(CPUClusterPalette.hair, lineWidth: 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 3))
        }
    }
}

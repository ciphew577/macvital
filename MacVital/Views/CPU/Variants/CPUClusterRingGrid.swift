// Ring grid: 14 cells in 3 cluster boxes. Outer ring usage, inner ring cluster freq normalised.
import SwiftUI

struct CPUClusterRingGrid: View {
    let clusters: [CPUClusterModel]

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ForEach(clusters) { cluster in
                ClusterBox(cluster: cluster)
            }
        }
    }
}

private struct ClusterBox: View {
    let cluster: CPUClusterModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                ClusterTag(label: cluster.label, accent: cluster.accent, sub: subtitle)
                Spacer()
                StatePill(text: cluster.isParked ? "Parked" : "Active", parked: cluster.isParked)
            }
            .padding(.bottom, 10)
            .overlay(alignment: .bottom) { Rectangle().fill(CPUClusterPalette.hair).frame(height: 0.5) }

            statRow

            Rectangle()
                .fill(CPUClusterPalette.tileSunk)
                .frame(height: 3)
                .overlay(alignment: .leading) {
                    GeometryReader { geo in
                        Rectangle()
                            .fill(cluster.isParked ? CPUClusterPalette.idle : cluster.accent)
                            .frame(width: geo.size.width * dvfsFraction)
                    }
                    .frame(height: 3)
                }
                .clipShape(RoundedRectangle(cornerRadius: 2))

            ringGrid
        }
        .padding(.init(top: 16, leading: 18, bottom: 14, trailing: 18))
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(CPUClusterPalette.tile)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(CPUClusterPalette.hair, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var subtitle: String {
        switch cluster.kind {
        case .efficiency:   return "\(cluster.cores.count) efficiency cores"
        case .performance0, .performance1: return "\(cluster.cores.count) performance cores"
        }
    }

    private var dvfsFraction: CGFloat {
        let f = Double(cluster.representativeFrequency) / max(Double(cluster.maxFrequency), 1)
        return CGFloat(min(max(f, 0), 1))
    }

    private var statRow: some View {
        HStack(alignment: .top, spacing: 10) {
            statCell(title: "Active freq", value: cluster.representativeFrequency > 0 ? "\(cluster.representativeFrequency)" : "0", unit: "MHz", dim: cluster.isParked)
            statCell(title: "Usage", value: String(format: "%.0f", cluster.avgUsage), unit: "%", dim: cluster.isParked)
            statCell(title: "Cores", value: "\(cluster.cores.count)", unit: "", dim: false)
            statCell(title: "DVFS", value: String(format: "%.0f", dvfsFraction * 100), unit: "%", dim: cluster.isParked)
        }
    }

    private func statCell(title: String, value: String, unit: String, dim: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold)).kerning(1.5)
                .foregroundStyle(CPUClusterPalette.t4)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(dim ? CPUClusterPalette.t3 : CPUClusterPalette.t1)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 10))
                        .foregroundStyle(CPUClusterPalette.t3)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var ringGrid: some View {
        let cols = max(cluster.cores.count, 1)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: cols), spacing: 8) {
            ForEach(cluster.cores) { core in
                CoreRingCell(core: core, accent: cluster.accent, maxFrequency: cluster.maxFrequency)
            }
        }
    }
}

private struct CoreRingCell: View {
    let core: CPUCore
    let accent: Color
    let maxFrequency: UInt64

    var body: some View {
        let parked = core.usage < 1 && core.frequency == 0
        let pctFrac = parked ? 0 : core.usage / 100
        let freqFrac = parked ? 0 : max(Double(core.frequency) / max(Double(maxFrequency), 1), 0.04)
        return VStack(spacing: 4) {
            HStack {
                Text(String(format: "C%02d", core.id))
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(CPUClusterPalette.t4)
                Spacer()
            }
            ZStack {
                Circle().stroke(Color.white.opacity(0.06), lineWidth: 3).frame(width: 56, height: 56)
                Circle()
                    .trim(from: 0, to: CGFloat(pctFrac))
                    .stroke(parked ? CPUClusterPalette.idle : accent, style: StrokeStyle(lineWidth: 3, lineCap: .butt))
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))
                Circle().stroke(Color.white.opacity(0.05), lineWidth: 2).frame(width: 36, height: 36)
                Circle()
                    .trim(from: 0, to: CGFloat(freqFrac))
                    .stroke((parked ? CPUClusterPalette.idle : accent).opacity(parked ? 0.18 : 0.55), style: StrokeStyle(lineWidth: 2, lineCap: .butt))
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(-90))
            }
            Text(parked ? "idle" : "\(Int(core.usage))%")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(parked ? CPUClusterPalette.idle : CPUClusterPalette.t1)
        }
        .frame(maxWidth: .infinity)
        .padding(.init(top: 8, leading: 7, bottom: 7, trailing: 7))
        .background(CPUClusterPalette.tileDeep)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(CPUClusterPalette.hair, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct ClusterTag: View {
    let label: String
    let accent: Color
    let sub: String?
    init(label: String, accent: Color, sub: String? = nil) { self.label = label; self.accent = accent; self.sub = sub }
    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2).fill(accent).frame(width: 10, height: 10)
            Text(label.uppercased())
                .font(.system(size: 9.5, weight: .bold)).kerning(1.7)
                .foregroundStyle(CPUClusterPalette.t1)
            if let sub {
                Text("· " + sub)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(CPUClusterPalette.t4)
            }
        }
    }
}

struct StatePill: View {
    let text: String
    let parked: Bool
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(parked ? CPUClusterPalette.idle : CPUClusterPalette.ok).frame(width: 6, height: 6)
            Text(text.uppercased())
                .font(.system(size: 9, weight: .bold)).kerning(1.7)
                .foregroundStyle(parked ? CPUClusterPalette.t4 : CPUClusterPalette.t3)
        }
        .padding(.init(top: 3, leading: 8, bottom: 3, trailing: 8))
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(CPUClusterPalette.hairLine, lineWidth: 0.5))
    }
}

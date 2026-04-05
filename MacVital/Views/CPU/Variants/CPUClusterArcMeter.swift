// Arc meter: 3 240° arcs side by side, cluster freq normalised, per-core dots inside cluster panel.
import SwiftUI

struct CPUClusterArcMeter: View {
    let clusters: [CPUClusterModel]

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ForEach(clusters) { cluster in
                ClusterArcPanel(cluster: cluster)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct ClusterArcPanel: View {
    let cluster: CPUClusterModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                ClusterTag(label: "\(cluster.label)-cluster", accent: cluster.accent, sub: subTitle)
                Spacer()
                StatePill(text: cluster.isParked ? "Parked" : "Active", parked: cluster.isParked)
            }
            .padding(.bottom, 10)
            .overlay(alignment: .bottom) { Rectangle().fill(CPUClusterPalette.hair).frame(height: 0.5) }

            HStack(alignment: .center, spacing: 18) {
                ZStack {
                    ArcShape(progress: 1).stroke(Color.white.opacity(0.06), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    ArcShape(progress: arcFraction).stroke(cluster.isParked ? CPUClusterPalette.idle : cluster.accent, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    VStack(spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(freqValueText)
                                .font(.system(size: 36, weight: .semibold, design: .default)).monospacedDigit()
                                .foregroundStyle(cluster.isParked ? CPUClusterPalette.idle : CPUClusterPalette.t1)
                            Text("MHz").font(.system(size: 14)).foregroundStyle(CPUClusterPalette.t3)
                        }
                        Text("ACTIVE FREQ")
                            .font(.system(size: 9, weight: .bold)).kerning(2)
                            .foregroundStyle(CPUClusterPalette.t4)
                            .padding(.top, 2)
                        Text(footerText)
                            .font(.system(size: 10, design: .monospaced)).monospacedDigit()
                            .foregroundStyle(cluster.isParked ? CPUClusterPalette.idle : CPUClusterPalette.t3)
                    }
                }
                .frame(width: 200, height: 200)

                VStack(alignment: .leading, spacing: 0) {
                    statBlock("Avg usage", String(format: "%.0f", cluster.avgUsage), "%", dim: cluster.isParked)
                    Rectangle().fill(CPUClusterPalette.hair).frame(height: 0.5).padding(.vertical, 10)
                    statBlock("Cores", "\(cluster.cores.count)", "", dim: false)
                    Rectangle().fill(CPUClusterPalette.hair).frame(height: 0.5).padding(.vertical, 10)
                    statBlock("DVFS", String(format: "%.0f", arcFraction * 100), "%", dim: cluster.isParked)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 8) {
                ForEach(cluster.cores) { core in
                    CoreDot(core: core, accent: cluster.accent)
                }
                Spacer()
            }
            .padding(.top, 6)

            HStack {
                Text("DVFS-weighted · IOReport CPU Stats")
                    .font(.system(size: 9, design: .monospaced)).foregroundStyle(CPUClusterPalette.t4)
                Spacer()
                Text("Max \(cluster.maxFrequency) MHz")
                    .font(.system(size: 9, design: .monospaced)).monospacedDigit()
                    .foregroundStyle(CPUClusterPalette.t4)
            }
        }
        .padding(.init(top: 18, leading: 20, bottom: 18, trailing: 20))
        .background(CPUClusterPalette.tile)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(CPUClusterPalette.hair, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var subTitle: String {
        cluster.kind == .efficiency ? "\(cluster.cores.count) efficiency" : "\(cluster.cores.count) performance"
    }
    private var arcFraction: CGFloat {
        let f = cluster.isParked ? 0 : Double(cluster.representativeFrequency) / max(Double(cluster.maxFrequency), 1)
        return CGFloat(min(max(f, 0), 1))
    }
    private var freqValueText: String {
        cluster.isParked ? "0" : "\(cluster.representativeFrequency)"
    }
    private var footerText: String {
        cluster.isParked ? "parked" : String(format: "%.0f%% of max", arcFraction * 100)
    }

    private func statBlock(_ title: String, _ value: String, _ unit: String, dim: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold)).kerning(1.7)
                .foregroundStyle(CPUClusterPalette.t4)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 17, weight: .semibold, design: .monospaced)).monospacedDigit()
                    .foregroundStyle(dim ? CPUClusterPalette.t3 : CPUClusterPalette.t1)
                Text(unit).font(.system(size: 10)).foregroundStyle(CPUClusterPalette.t3)
            }
        }
    }
}

private struct ArcShape: Shape {
    let progress: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let radius = min(rect.width, rect.height) / 2 - 8
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let start: CGFloat = 150
        let end = start + 240 * max(min(progress, 1), 0)
        p.addArc(center: center, radius: radius, startAngle: .degrees(Double(start)), endAngle: .degrees(Double(end)), clockwise: false)
        return p
    }
}

private struct CoreDot: View {
    let core: CPUCore
    let accent: Color

    var body: some View {
        let parked = core.usage < 1 && core.frequency == 0
        let cls = bucket(core.usage, parked: parked)
        let bg: Color = {
            switch cls {
            case .parked: return CPUClusterPalette.idle.opacity(0.18)
            case .lo:     return blend(accent, CPUClusterPalette.tileSunk, frac: 0.20)
            case .md:     return blend(accent, CPUClusterPalette.tileSunk, frac: 0.50)
            case .hi:     return blend(accent, CPUClusterPalette.tileSunk, frac: 0.78)
            case .max:    return accent
            }
        }()
        let fg: Color = (cls == .hi || cls == .max) ? CPUClusterPalette.bg : (cls == .parked ? CPUClusterPalette.t5 : CPUClusterPalette.t1)
        return VStack(spacing: 3) {
            ZStack {
                Circle().fill(bg)
                Text(parked ? "·" : "\(Int(core.usage))")
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced)).monospacedDigit()
                    .foregroundStyle(fg)
            }
            .frame(width: 22, height: 22)
            .overlay(Circle().stroke(parked ? CPUClusterPalette.idle.opacity(0.4) : CPUClusterPalette.hair, lineWidth: 0.5))
            Text(String(format: "C%02d", core.id))
                .font(.system(size: 8, design: .monospaced)).monospacedDigit()
                .foregroundStyle(CPUClusterPalette.t4)
        }
    }

    private enum Bucket { case parked, lo, md, hi, max }
    private func bucket(_ pct: Double, parked: Bool) -> Bucket {
        if parked { return .parked }
        if pct < 15 { return .lo }
        if pct < 50 { return .md }
        if pct < 80 { return .hi }
        return .max
    }
    private func blend(_ a: Color, _ b: Color, frac: Double) -> Color {
        let nsA = NSColor(a); let nsB = NSColor(b)
        let f = CGFloat(frac); let g = 1 - f
        let cA = nsA.usingColorSpace(.deviceRGB) ?? nsA
        let cB = nsB.usingColorSpace(.deviceRGB) ?? nsB
        return Color(red: Double(cA.redComponent * f + cB.redComponent * g),
                     green: Double(cA.greenComponent * f + cB.greenComponent * g),
                     blue: Double(cA.blueComponent * f + cB.blueComponent * g))
    }
}

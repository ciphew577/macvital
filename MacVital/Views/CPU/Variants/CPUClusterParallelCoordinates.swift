// Parallel coordinates: multi-axis polyline. X = 14 cores in cluster order. Y = % usage. Cluster zone bands behind.
import SwiftUI

struct CPUClusterParallelCoordinates: View {
    let clusters: [CPUClusterModel]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 22) {
                ForEach(clusters) { cluster in
                    ClusterTag(label: cluster.label, accent: cluster.accent, sub: tagSub(cluster))
                }
                Spacer()
            }

            ZStack(alignment: .topLeading) {
                bands
                axisFrame
            }
            .frame(height: 280)
            .padding(.horizontal, 36)

            legend
                .padding(.top, 6)
                .overlay(alignment: .top) { Rectangle().fill(CPUClusterPalette.hair).frame(height: 0.5) }
        }
        .padding(.init(top: 18, leading: 22, bottom: 16, trailing: 22))
        .background(CPUClusterPalette.tile)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(CPUClusterPalette.hair, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func tagSub(_ cluster: CPUClusterModel) -> String {
        if cluster.isParked { return "\(cluster.cores.count) cores · parked" }
        return "\(cluster.cores.count) cores · \(cluster.representativeFrequency) MHz"
    }

    private var bands: some View {
        let totalCores = max(clusters.reduce(0) { $0 + $1.cores.count }, 1)
        return GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(clusters) { cluster in
                    let w = geo.size.width * CGFloat(cluster.cores.count) / CGFloat(totalCores)
                    ZStack(alignment: .topLeading) {
                        Rectangle().fill(cluster.accent.opacity(0.04))
                        VStack {
                            HStack {
                                Text("\(cluster.label) · \(cluster.isParked ? "parked" : "active")".uppercased())
                                    .font(.system(size: 9, weight: .bold)).kerning(2)
                                    .foregroundStyle(cluster.accent)
                                Spacer()
                                Text(bandState(cluster))
                                    .font(.system(size: 9, design: .monospaced)).monospacedDigit()
                                    .foregroundStyle(CPUClusterPalette.t4)
                            }
                            .padding(.horizontal, 12).padding(.top, 8)
                            Spacer()
                            HStack {
                                Text(bandFloor(cluster))
                                    .font(.system(size: 10, design: .monospaced)).monospacedDigit()
                                    .foregroundStyle(CPUClusterPalette.t2)
                                Spacer()
                            }
                            .padding(.horizontal, 12).padding(.bottom, 8)
                        }
                    }
                    .frame(width: w)
                    .overlay(alignment: .trailing) { Rectangle().fill(CPUClusterPalette.hair).frame(width: 0.5) }
                }
            }
        }
    }

    private func bandState(_ c: CPUClusterModel) -> String {
        c.isParked ? "0 MHz" : "\(c.representativeFrequency) MHz"
    }
    private func bandFloor(_ c: CPUClusterModel) -> String {
        "Avg " + String(format: "%.0f%%", c.avgUsage)
    }

    private var axisFrame: some View {
        ZStack {
            Canvas { ctx, size in
                drawGrid(ctx: ctx, size: size)
                drawTicks(ctx: ctx, size: size)
                drawUsagePolyline(ctx: ctx, size: size)
                drawFreqSegments(ctx: ctx, size: size)
                drawDots(ctx: ctx, size: size)
            }
            HStack {
                axisLabels(values: ["100", "75", "50", "25", "0"], align: .trailing)
                    .padding(.trailing, 6).offset(x: -36)
                Spacer()
                axisLabels(values: freqAxisLabels, align: .leading)
                    .padding(.leading, 6).offset(x: 36)
            }
            .allowsHitTesting(false)
        }
    }

    private var freqMaxMHz: Double {
        Double(clusters.map(\.maxFrequency).max() ?? 0)
    }

    private var freqAxisLabels: [String] {
        let m = freqMaxMHz
        guard m > 0 else { return ["0", "0", "0", "0", "0"] }
        return [1.0, 0.75, 0.5, 0.25, 0.0].map { frac in formatFreqTick(mhz: m * frac) }
    }

    private func formatFreqTick(mhz: Double) -> String {
        if mhz <= 0 { return "0" }
        let g = mhz / 1000
        if g >= 10 { return String(format: "%.0fG", g) }
        return String(format: "%.1fG", g)
    }

    private func axisLabels(values: [String], align: HorizontalAlignment) -> some View {
        VStack(alignment: align, spacing: 0) {
            ForEach(Array(values.enumerated()), id: \.offset) { idx, v in
                Text(v)
                    .font(.system(size: 9, design: .monospaced)).monospacedDigit()
                    .foregroundStyle(CPUClusterPalette.t4)
                if idx < values.count - 1 { Spacer() }
            }
        }
        .frame(width: 32)
    }

    private func drawGrid(ctx: GraphicsContext, size: CGSize) {
        let lineColor = GraphicsContext.Shading.color(Color.white.opacity(0.05))
        for f in [0.0, 0.25, 0.5, 0.75, 1.0] {
            let y = size.height * CGFloat(f)
            var p = Path()
            p.move(to: CGPoint(x: 0, y: y))
            p.addLine(to: CGPoint(x: size.width, y: y))
            ctx.stroke(p, with: lineColor, lineWidth: 0.5)
        }
    }

    private var orderedCores: [(CPUCore, Color)] {
        clusters.flatMap { c in c.cores.map { ($0, c.accent) } }
    }

    private func drawTicks(ctx: GraphicsContext, size: CGSize) {
        let cores = orderedCores
        guard !cores.isEmpty else { return }
        let n = cores.count
        for i in 0..<n {
            let x = (CGFloat(i) + 0.5) * (size.width / CGFloat(n))
            var p = Path()
            p.move(to: CGPoint(x: x, y: 0))
            p.addLine(to: CGPoint(x: x, y: size.height))
            ctx.stroke(p, with: .color(Color.white.opacity(0.04)), lineWidth: 0.5)
        }
    }

    private func drawUsagePolyline(ctx: GraphicsContext, size: CGSize) {
        let cores = orderedCores
        guard cores.count > 1 else { return }
        let n = cores.count
        var path = Path()
        for (i, pair) in cores.enumerated() {
            let x = (CGFloat(i) + 0.5) * (size.width / CGFloat(n))
            let y = size.height - CGFloat(pair.0.usage / 100) * size.height
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        ctx.stroke(path, with: .color(CPUClusterPalette.t1.opacity(0.92)), style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))
    }

    private func drawFreqSegments(ctx: GraphicsContext, size: CGSize) {
        let cores = orderedCores
        guard !cores.isEmpty else { return }
        let n = cores.count
        let freqMax: Double = max(freqMaxMHz, 1)
        var idx = 0
        for cluster in clusters {
            var path = Path()
            for (j, _) in cluster.cores.enumerated() {
                let i = idx + j
                let x = (CGFloat(i) + 0.5) * (size.width / CGFloat(n))
                let f = cluster.isParked ? 0 : Double(cluster.representativeFrequency) / freqMax
                let y = size.height - CGFloat(min(max(f, 0), 1)) * size.height
                if j == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            ctx.stroke(path, with: .color(cluster.accent), style: StrokeStyle(lineWidth: 1.4, dash: [4, 3]))
            idx += cluster.cores.count
        }
    }

    private func drawDots(ctx: GraphicsContext, size: CGSize) {
        let cores = orderedCores
        let n = cores.count
        for (i, pair) in cores.enumerated() {
            let x = (CGFloat(i) + 0.5) * (size.width / CGFloat(n))
            let parked = pair.0.usage < 1 && pair.0.frequency == 0
            let y = size.height - CGFloat(pair.0.usage / 100) * size.height
            let r: CGFloat = parked ? 3 : 4.5
            let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
            ctx.fill(Path(ellipseIn: rect), with: .color(parked ? CPUClusterPalette.idle : pair.1))
        }
    }

    private var legend: some View {
        HStack(spacing: 22) {
            legendItem(swatch: AnyView(Rectangle().fill(CPUClusterPalette.t1).frame(width: 14, height: 2)), text: "Per-core usage %")
            legendItem(swatch: AnyView(Rectangle().fill(CPUClusterPalette.p0Core).frame(width: 14, height: 2)), text: "Cluster freq (DVFS)")
            Spacer()
            legendItem(swatch: AnyView(Circle().fill(CPUClusterPalette.idle).frame(width: 8, height: 8)), text: "Parked core")
            legendItem(swatch: AnyView(Circle().fill(CPUClusterPalette.ok).frame(width: 8, height: 8)), text: "Active core")
        }
    }

    private func legendItem(swatch: AnyView, text: String) -> some View {
        HStack(spacing: 7) {
            swatch
            Text(text).font(.system(size: 10.5)).foregroundStyle(CPUClusterPalette.t2)
        }
    }
}

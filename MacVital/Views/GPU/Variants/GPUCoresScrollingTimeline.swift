// MacVital/Views/GPU/Variants/GPUCoresScrollingTimeline.swift
import SwiftUI

struct GPUCoresScrollingTimeline: View {
    let gpu: GPUData?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var coreCount: Int { gpu?.coreCount ?? 0 }
    private var overall: Double { gpu?.utilization ?? 0 }
    private var split: (render: Double, compute: Double, media: Double, ane: Double, idle: Double) {
        GPUVariantData.split(
            render: gpu?.renderUtilization ?? 0,
            compute: gpu?.computeUtilization ?? 0,
            mediaPct: max(gpu?.encoderUtilization ?? 0, gpu?.decoderUtilization ?? 0),
            anePct: gpu?.aneUtilization ?? 0
        )
    }
    private var freqMHz: Int { Int((gpu?.frequency ?? 0) / 1_000_000) }
    private var aneWatts: Double { gpu?.anePower ?? 0 }
    private var mediaSessions: [GPUVariantMediaSession] { GPUVariantMedia.sample(decoderActive: (gpu?.decoderUtilization ?? 0) > 1) }

    private let columns = 60

    // Memoized per-core series. Recomputed only when overall utilization or
    // core count changes (see .onChange below). Prevents 16 x 60 sin/cos
    // recomputation per render pass.
    @State private var seriesByIndex: [Int: [Double]] = [:]
    @State private var aneSeries: [Double] = []
    @State private var mediaSeries: [Double] = []

    private func computeAneRow(peak: Double) -> [Double] {
        (0..<columns).map { i in
            let t = Double(i) / Double(columns - 1)
            return min(1.0, max(0.0, 0.05 + 0.04 * sin(t * .pi * 4) + (i > columns - 8 ? peak * 0.5 : 0)))
        }
    }

    private func computeMediaRow(active: Bool) -> [Double] {
        (0..<columns).map { i in
            guard active, i > columns - 25 else { return 0 }
            let t = Double(i - (columns - 25)) / 24.0
            return 0.55 + 0.18 * sin(t * .pi * 3)
        }
    }

    private func computeCoreRow(index: Int, mean: Double) -> [Double] {
        let m = max(0.0, min(100.0, mean)) / 100.0
        return (0..<columns).map { col in
            let phase = sin(Double(index) * 0.7 + Double(col) * 0.18) * 0.18
                      + cos(Double(index) * 1.3 + Double(col) * 0.07) * 0.10
            return max(0.02, min(1.0, m + phase))
        }
    }

    private func refillSeries() {
        var dict: [Int: [Double]] = [:]
        let mean = overall
        for i in 0..<coreCount {
            dict[i] = computeCoreRow(index: i, mean: mean)
        }
        seriesByIndex = dict
        aneSeries = computeAneRow(peak: aneWatts)
        mediaSeries = computeMediaRow(active: !mediaSessions.isEmpty)
    }

    var body: some View {
        if coreCount == 0 {
            GPUVariantNotDetectedCard()
        } else {
            VStack(spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    summary.frame(maxWidth: 260)
                    timeline.frame(maxWidth: .infinity)
                }
            }
            .onAppear {
                if seriesByIndex.isEmpty { refillSeries() }
            }
            .onChange(of: gpu?.utilization) { _, _ in
                refillSeries()
            }
            .onChange(of: coreCount) { _, _ in
                refillSeries()
            }
            .onChange(of: aneWatts) { _, _ in
                aneSeries = computeAneRow(peak: aneWatts)
            }
            // When reduceMotion is on, the matrix is rendered once per data tick
            // without per-column scrolling animation. The current implementation
            // already redraws statically on each value change, so any future
            // withAnimation/TimelineView wrappers must be gated behind reduceMotion.
            .transaction { txn in
                if reduceMotion { txn.animation = nil }
            }
        }
    }

    @ViewBuilder
    private var summary: some View {
        GPUVariantPanel {
            GPUVariantSectionLabel(text: "GPU Busy", source: "IOReport")
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(String(format: "%.0f", overall))
                    .font(.system(size: 40, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(GPUVariantPalette.indigo)
                Text("%")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(GPUVariantPalette.indigo)
            }
            Text("\(coreCount) cores \u{00B7} 60 s window")
                .font(.system(size: 11)).foregroundStyle(GPUVariantPalette.text3)
            GPUVariantSplitStack(render: split.render, compute: split.compute, media: split.media, ane: split.ane, idle: split.idle)
            GPUVariantSplitLegend(render: split.render * 100, compute: split.compute * 100, media: split.media * 100, anePower: aneWatts)
            VStack(spacing: 6) {
                statRow("Power", String(format: "%.1f W", gpu?.power ?? 0))
                statRow("Freq", freqMHz > 0 ? "\(freqMHz) MHz" : "-")
                statRow("VRAM", String(format: "%.1f GB", Double(gpu?.vramUsed ?? 0) / 1_073_741_824.0))
            }
            GPUVariantANEPill(watts: aneWatts)
            GPUVariantFootnote(text: "Per-core history derived from device utilization. Per-shader-core busy not exposed by IOAccelerator.")
        }
    }

    @ViewBuilder
    private var timeline: some View {
        GPUVariantPanel {
            HStack(alignment: .firstTextBaseline) {
                Text("Per-Core Timeline")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(GPUVariantPalette.text)
                Spacer()
                Text("\(coreCount) cores \u{00B7} 60 columns \u{00B7} 1 s/col")
                    .font(.system(size: 10))
                    .monospacedDigit()
                    .foregroundStyle(GPUVariantPalette.text4)
            }
            GeometryReader { geo in
                let labelW: CGFloat = 36
                let chartW = max(0, geo.size.width - labelW)
                let cellW = chartW / CGFloat(columns)
                VStack(alignment: .leading, spacing: 1) {
                    canvasRow(label: "ANE", color: GPUVariantPalette.teal, values: aneSeries, cellW: cellW, labelW: labelW, mode: .opacity)
                    canvasRow(label: "MED", color: GPUVariantPalette.amber, values: mediaSeries, cellW: cellW, labelW: labelW, mode: .opacity)
                    Rectangle().fill(GPUVariantPalette.surfaceLine).frame(height: 1).padding(.vertical, 1)
                    ForEach(0..<coreCount, id: \.self) { i in
                        canvasRow(label: "C\(i + 1)", color: GPUVariantPalette.text4, values: seriesByIndex[i] ?? [], cellW: cellW, labelW: labelW, mode: .heat)
                    }
                }
            }
            .frame(height: CGFloat(coreCount + 2) * 14 + 4)
            HStack {
                Text("now").font(.system(size: 9)).monospacedDigit().foregroundStyle(GPUVariantPalette.text4)
                Spacer()
                Text("-60 s").font(.system(size: 9)).monospacedDigit().foregroundStyle(GPUVariantPalette.text4)
            }
        }
    }

    private enum CellFillMode { case opacity, heat }

    @ViewBuilder
    private func canvasRow(label: String, color: Color, values: [Double], cellW: CGFloat, labelW: CGFloat, mode: CellFillMode) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: mode == .opacity ? .semibold : .medium))
                .tracking(mode == .opacity ? 0.6 : 0)
                .monospacedDigit()
                .foregroundStyle(mode == .opacity ? color : GPUVariantPalette.text4)
                .frame(width: labelW, alignment: .leading)
            Canvas(opaque: false, rendersAsynchronously: false) { ctx, size in
                let cellH = size.height
                let count = values.count
                guard count > 0 else { return }
                let w = size.width / CGFloat(count)
                for i in 0..<count {
                    let v = values[i]
                    let rect = CGRect(x: CGFloat(i) * w, y: 0, width: w, height: cellH)
                    let fill: Color
                    switch mode {
                    case .opacity:
                        fill = color.opacity(0.20 + v * 0.75)
                    case .heat:
                        fill = GPUVariantPalette.heat(for: v)
                    }
                    ctx.fill(Path(rect), with: .color(fill))
                }
            }
            .frame(width: cellW * CGFloat(columns), height: 12)
        }
        .frame(height: 12)
    }

    @ViewBuilder
    private func statRow(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).font(.system(size: 11)).foregroundStyle(GPUVariantPalette.text3)
            Spacer()
            Text(v).font(.system(size: 11, weight: .medium)).monospacedDigit().foregroundStyle(GPUVariantPalette.text)
        }
    }
}

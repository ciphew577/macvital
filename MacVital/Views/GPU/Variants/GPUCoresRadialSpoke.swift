// MacVital/Views/GPU/Variants/GPUCoresRadialSpoke.swift
import SwiftUI

struct GPUCoresRadialSpoke: View {
    let gpu: GPUData?

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
    private var cores: [GPUVariantPerCore] { GPUVariantData.perCore(overall: overall, count: coreCount, baseFreq: max(800, freqMHz)) }
    private var aneWatts: Double { gpu?.anePower ?? 0 }
    private var mediaSessions: [GPUVariantMediaSession] { GPUVariantMedia.sample(decoderActive: (gpu?.decoderUtilization ?? 0) > 1) }

    var body: some View {
        if coreCount == 0 {
            GPUVariantNotDetectedCard()
        } else {
            VStack(spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    wheelPanel.frame(maxWidth: .infinity)
                    sidePanel.frame(maxWidth: 300)
                }
                HStack(alignment: .top, spacing: 12) {
                    anePanel
                    mediaPanel
                }
            }
        }
    }

    @ViewBuilder
    private var wheelPanel: some View {
        GPUVariantPanel {
            HStack(alignment: .firstTextBaseline) {
                Text("Per-Core Wheel")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(GPUVariantPalette.text)
                Spacer()
                Text("\(coreCount) cores \u{00B7} radial busy")
                    .font(.system(size: 10))
                    .monospacedDigit()
                    .foregroundStyle(GPUVariantPalette.text4)
            }
            ZStack {
                Canvas { ctx, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let outerR = min(size.width, size.height) / 2 - 8
                    let innerR = outerR * 0.42
                    let n = cores.count
                    let slice = (.pi * 2) / Double(n)
                    let gap = slice * 0.05
                    for c in cores {
                        let start = -.pi / 2 + Double(c.id) * slice + gap / 2
                        let end = start + slice - gap
                        let busyR = innerR + (outerR - innerR) * c.busy
                        var p = Path()
                        p.move(to: CGPoint(x: center.x + cos(start) * innerR, y: center.y + sin(start) * innerR))
                        p.addArc(center: center, radius: busyR, startAngle: .radians(start), endAngle: .radians(end), clockwise: false)
                        p.addLine(to: CGPoint(x: center.x + cos(end) * innerR, y: center.y + sin(end) * innerR))
                        p.addArc(center: center, radius: innerR, startAngle: .radians(end), endAngle: .radians(start), clockwise: true)
                        ctx.fill(p, with: .color(GPUVariantPalette.heat(for: c.busy)))
                    }
                    var ring = Path()
                    ring.addArc(center: center, radius: innerR, startAngle: .zero, endAngle: .radians(.pi * 2), clockwise: false)
                    ctx.stroke(ring, with: .color(GPUVariantPalette.surfaceLine), lineWidth: 1)
                    var outer = Path()
                    outer.addArc(center: center, radius: outerR, startAngle: .zero, endAngle: .radians(.pi * 2), clockwise: false)
                    ctx.stroke(outer, with: .color(GPUVariantPalette.surfaceLine), lineWidth: 1)
                }
                VStack(spacing: 2) {
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text(String(format: "%.0f", overall))
                            .font(.system(size: 36, weight: .heavy))
                            .monospacedDigit()
                            .foregroundStyle(GPUVariantPalette.indigo)
                        Text("%")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(GPUVariantPalette.indigo)
                    }
                    Text("BUSY")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(GPUVariantPalette.text3)
                }
            }
            .frame(height: 280)
            GPUVariantFootnote(text: "Spokes are derived from device utilization with deterministic per-core jitter. Per-core busy not exposed by IOAccelerator.")
        }
    }

    @ViewBuilder
    private var sidePanel: some View {
        GPUVariantPanel {
            GPUVariantSectionLabel(text: "GPU Summary", source: "IOReport")
            GPUVariantSplitStack(render: split.render, compute: split.compute, media: split.media, ane: split.ane, idle: split.idle)
            GPUVariantSplitLegend(render: split.render * 100, compute: split.compute * 100, media: split.media * 100, anePower: aneWatts)
            VStack(spacing: 6) {
                statRow("Power", String(format: "%.1f W", gpu?.power ?? 0))
                statRow("Freq avg", freqMHz > 0 ? "\(freqMHz) MHz" : "-")
                statRow("VRAM", String(format: "%.1f GB", Double(gpu?.vramUsed ?? 0) / 1_073_741_824.0))
                statRow("BW R/W", String(format: "%.0f / %.0f GB/s",
                    Double(gpu?.memReadBytesPerSec ?? 0) / 1_073_741_824.0,
                    Double(gpu?.memWriteBytesPerSec ?? 0) / 1_073_741_824.0))
            }
            sortedSpoke
        }
    }

    @ViewBuilder
    private var sortedSpoke: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("HOTTEST CORES")
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(GPUVariantPalette.text4)
            ForEach(cores.sorted(by: { $0.busy > $1.busy }).prefix(4)) { c in
                HStack(spacing: 8) {
                    Text("C\(c.id + 1)")
                        .font(.system(size: 10, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(GPUVariantPalette.text3)
                        .frame(width: 28, alignment: .leading)
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2).fill(GPUVariantPalette.idle).frame(height: 4)
                            RoundedRectangle(cornerRadius: 2).fill(GPUVariantPalette.heat(for: c.busy))
                                .frame(width: g.size.width * c.busy, height: 4)
                        }
                    }
                    .frame(height: 4)
                    Text(String(format: "%.0f%%", c.busy * 100))
                        .font(.system(size: 10, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(GPUVariantPalette.text)
                        .frame(width: 36, alignment: .trailing)
                }
            }
        }
    }

    @ViewBuilder
    private var anePanel: some View {
        GPUVariantPanel {
            GPUVariantSectionLabel(text: "Neural Engine", accent: GPUVariantPalette.teal, source: "IOReport \u{00B7} Energy Model")
            HStack {
                Text("Apple Neural Engine")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(GPUVariantPalette.text)
                Spacer()
                GPUVariantANEPill(watts: aneWatts)
            }
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(String(format: "%.2f", aneWatts))
                    .font(.system(size: 28, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(GPUVariantPalette.teal)
                Text("W")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(GPUVariantPalette.teal)
            }
            GPUVariantANESpark(samples: GPUVariantData.aneSpark(peakWatts: max(0.5, aneWatts)), peak: max(0.5, aneWatts))
            GPUVariantFootnote(text: "Threshold \u{2265} 0.30 W marks ACTIVE. Apple does not expose ANE busy %.")
        }
    }

    @ViewBuilder
    private var mediaPanel: some View {
        GPUVariantPanel {
            GPUVariantSectionLabel(text: "Media Engine", accent: GPUVariantPalette.amber, source: "VT \u{00B7} AppleAVD \u{00B7} AppleAVE")
            HStack {
                Text("Active sessions")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(GPUVariantPalette.text)
                Text("(\(mediaSessions.count) of 4)")
                    .font(.system(size: 11)).monospacedDigit().foregroundStyle(GPUVariantPalette.text4)
                Spacer()
            }
            VStack(alignment: .leading, spacing: 6) {
                ForEach(mediaSessions) { s in
                    HStack(spacing: 8) {
                        Text(s.codec)
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.6)
                            .foregroundStyle(GPUVariantPalette.slate)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(GPUVariantPalette.slate.opacity(0.18), in: RoundedRectangle(cornerRadius: 4))
                        Text(s.owner).font(.system(size: 12, weight: .medium)).foregroundStyle(GPUVariantPalette.text)
                        Text(s.detail).font(.system(size: 10)).monospacedDigit().foregroundStyle(GPUVariantPalette.text3)
                        Spacer()
                        Text(s.duration).font(.system(size: 11)).monospacedDigit().foregroundStyle(GPUVariantPalette.text3)
                    }
                }
                if mediaSessions.isEmpty {
                    Text("\u{2022} no active decoder session")
                        .font(.system(size: 11)).monospacedDigit().foregroundStyle(GPUVariantPalette.text4)
                }
                Text("\u{2022} ProRes engine occupancy not exposed")
                    .font(.system(size: 11)).monospacedDigit().foregroundStyle(GPUVariantPalette.text4)
            }
        }
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

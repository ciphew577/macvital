// MacVital/Views/GPU/Variants/GPUCoresHeatStrip.swift
import SwiftUI

struct GPUCoresHeatStrip: View {
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
    private var cores: [GPUVariantPerCore] {
        GPUVariantData.perCore(overall: overall, count: coreCount, baseFreq: max(800, freqMHz))
    }
    private var aneWatts: Double { gpu?.anePower ?? 0 }
    private var mediaSessions: [GPUVariantMediaSession] {
        GPUVariantMedia.sample(decoderActive: (gpu?.decoderUtilization ?? 0) > 1)
    }

    var body: some View {
        if coreCount == 0 {
            GPUVariantNotDetectedCard()
        } else {
            HStack(alignment: .top, spacing: 12) {
                summary
                    .frame(maxWidth: 240)
                heatStrip
                    .frame(maxWidth: .infinity)
                VStack(spacing: 12) {
                    anePanel
                    mediaPanel
                }
                .frame(maxWidth: 260)
            }
        }
    }

    @ViewBuilder
    private var summary: some View {
        GPUVariantPanel {
            GPUVariantSectionLabel(text: "GPU Busy Ratio", source: "IOReport \u{00B7} GPU Stats")
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(String(format: "%.0f", overall))
                    .font(.system(size: 44, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(GPUVariantPalette.indigo)
                Text("%")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(GPUVariantPalette.indigo)
            }
            Text("\(coreCount) cores \u{00B7} 1 s residency")
                .font(.system(size: 11))
                .foregroundStyle(GPUVariantPalette.text3)

            GPUVariantSplitStack(render: split.render, compute: split.compute, media: split.media, ane: split.ane, idle: split.idle)
            GPUVariantSplitLegend(render: split.render * 100, compute: split.compute * 100, media: split.media * 100, anePower: aneWatts)

            VStack(spacing: 6) {
                statRow("Power", String(format: "%.1f W", gpu?.power ?? 0))
                statRow("Freq avg", freqMHz > 0 ? "\(freqMHz) MHz" : "-")
                statRow("VRAM", String(format: "%.1f GB", Double(gpu?.vramUsed ?? 0) / 1_073_741_824.0))
            }
            GPUVariantFootnote(text: "Source: per-core residency derived from device utilization. IOAccelerator does not expose per-shader-core busy on this GPU.")
        }
    }

    @ViewBuilder
    private var heatStrip: some View {
        GPUVariantPanel {
            HStack(alignment: .firstTextBaseline) {
                Text("Per-Core Busy Residency")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(GPUVariantPalette.text)
                Spacer()
                Text("\(coreCount) cores \u{00B7} 250 ms sample")
                    .font(.system(size: 10))
                    .monospacedDigit()
                    .foregroundStyle(GPUVariantPalette.text4)
            }
            GeometryReader { geo in
                let gap: CGFloat = 4
                let totalGap = gap * CGFloat(max(0, cores.count - 1))
                let barW = max(6, (geo.size.width - totalGap) / CGFloat(cores.count))
                HStack(alignment: .bottom, spacing: gap) {
                    ForEach(cores) { c in
                        VStack(spacing: 4) {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(GPUVariantPalette.heat(for: c.busy))
                                .frame(width: barW, height: max(4, geo.size.height * c.busy))
                            Text("\(c.id + 1)")
                                .font(.system(size: 8, weight: .medium))
                                .monospacedDigit()
                                .foregroundStyle(GPUVariantPalette.text4)
                        }
                    }
                }
            }
            .frame(height: 220)
            ramp
        }
    }

    @ViewBuilder
    private var ramp: some View {
        HStack(spacing: 6) {
            Text("0%").font(.system(size: 9)).monospacedDigit().foregroundStyle(GPUVariantPalette.text4)
            HStack(spacing: 0) {
                ForEach(0..<GPUVariantPalette.heatRamp.count, id: \.self) { i in
                    Rectangle().fill(GPUVariantPalette.heatRamp[i]).frame(height: 6)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 3))
            Text("100%").font(.system(size: 9)).monospacedDigit().foregroundStyle(GPUVariantPalette.text4)
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
            HStack {
                Text("Threshold \u{2265} 0.30 W = ACTIVE").font(.system(size: 10)).monospacedDigit().foregroundStyle(GPUVariantPalette.text3)
                Spacer()
                Text("60 s rolling").font(.system(size: 10)).monospacedDigit().foregroundStyle(GPUVariantPalette.text4)
            }
            GPUVariantFootnote(text: "No utilisation %. Apple does not expose ANE busy. Watts only.")
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
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(GPUVariantPalette.text4)
                Spacer()
                if mediaSessions.isEmpty {
                    GPUVariantANEPill(watts: 0)
                } else {
                    HStack(spacing: 5) {
                        Circle().fill(GPUVariantPalette.amber).frame(width: 6, height: 6)
                        Text("ACTIVE").font(.system(size: 10, weight: .semibold)).tracking(0.8).foregroundStyle(GPUVariantPalette.amber)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(GPUVariantPalette.amber.opacity(0.10)))
                    .overlay(Capsule().strokeBorder(GPUVariantPalette.amber.opacity(0.30), lineWidth: 1))
                }
            }
            VStack(spacing: 8) {
                ForEach(mediaSessions) { s in mediaRow(s) }
                if mediaSessions.isEmpty {
                    Text("\u{2022} no active decoder session")
                        .font(.system(size: 11)).monospacedDigit().foregroundStyle(GPUVariantPalette.text4)
                }
                Text("\u{2022} no active encoder session")
                    .font(.system(size: 11)).monospacedDigit().foregroundStyle(GPUVariantPalette.text4)
                Text("\u{2022} ProRes engine occupancy not exposed")
                    .font(.system(size: 11)).monospacedDigit().foregroundStyle(GPUVariantPalette.text4)
            }
        }
    }

    @ViewBuilder
    private func mediaRow(_ s: GPUVariantMediaSession) -> some View {
        HStack(spacing: 10) {
            Text(s.codec)
                .font(.system(size: 9, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(GPUVariantPalette.slate)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(GPUVariantPalette.slate.opacity(0.18), in: RoundedRectangle(cornerRadius: 4))
            VStack(alignment: .leading, spacing: 2) {
                Text(s.owner).font(.system(size: 12, weight: .medium)).foregroundStyle(GPUVariantPalette.text)
                Text(s.detail).font(.system(size: 10)).monospacedDigit().foregroundStyle(GPUVariantPalette.text3)
            }
            Spacer()
            Text(s.duration).font(.system(size: 11)).monospacedDigit().foregroundStyle(GPUVariantPalette.text3)
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

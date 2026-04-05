// MacVital/Views/GPU/Variants/GPUCoresSummaryFirst.swift
import SwiftUI

struct GPUCoresSummaryFirst: View {
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
                heroPanel
                HStack(alignment: .top, spacing: 12) {
                    anePanel.frame(maxWidth: .infinity)
                    mediaPanel.frame(maxWidth: .infinity)
                }
                corePanel
            }
        }
    }

    @ViewBuilder
    private var heroPanel: some View {
        GPUVariantPanel {
            GPUVariantSectionLabel(text: "GPU Aggregate", source: "IOReport \u{00B7} GPU Stats")
            HStack(alignment: .lastTextBaseline, spacing: 12) {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(String(format: "%.0f", overall))
                        .font(.system(size: 64, weight: .heavy))
                        .monospacedDigit()
                        .kerning(-1)
                        .foregroundStyle(GPUVariantPalette.indigo)
                    Text("%")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(GPUVariantPalette.indigo)
                }
                Text("Overall busy across \(coreCount) shader cores")
                    .font(.system(size: 12))
                    .foregroundStyle(GPUVariantPalette.text3)
                    .padding(.bottom, 8)
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    statRow("Power", String(format: "%.1f W", gpu?.power ?? 0))
                    statRow("Freq avg", freqMHz > 0 ? "\(freqMHz) MHz" : "-")
                    statRow("VRAM", String(format: "%.1f GB", Double(gpu?.vramUsed ?? 0) / 1_073_741_824.0))
                    statRow("BW R/W", String(format: "%.0f / %.0f GB/s",
                        Double(gpu?.memReadBytesPerSec ?? 0) / 1_073_741_824.0,
                        Double(gpu?.memWriteBytesPerSec ?? 0) / 1_073_741_824.0))
                }
            }
            GPUVariantSplitStack(render: split.render, compute: split.compute, media: split.media, ane: split.ane, idle: split.idle, height: 12)
            GPUVariantSplitLegend(render: split.render * 100, compute: split.compute * 100, media: split.media * 100, anePower: aneWatts)
            GPUVariantFootnote(text: "Real busy ratio from IOAccelerator. Render and Compute splits derived from PerformanceStatistics.")
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
                    .font(.system(size: 36, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(GPUVariantPalette.teal)
                Text("W")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(GPUVariantPalette.teal)
            }
            GPUVariantANESpark(samples: GPUVariantData.aneSpark(peakWatts: max(0.5, aneWatts)), peak: max(0.5, aneWatts), height: 36)
            HStack {
                Text("Threshold \u{2265} 0.30 W = ACTIVE").font(.system(size: 10)).monospacedDigit().foregroundStyle(GPUVariantPalette.text3)
                Spacer()
                Text("60 s rolling").font(.system(size: 10)).monospacedDigit().foregroundStyle(GPUVariantPalette.text4)
            }
            GPUVariantFootnote(text: "Apple does not expose ANE busy %. Watts only.")
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
                if !mediaSessions.isEmpty {
                    HStack(spacing: 5) {
                        Circle().fill(GPUVariantPalette.amber).frame(width: 6, height: 6)
                        Text("ACTIVE").font(.system(size: 10, weight: .semibold)).tracking(0.8).foregroundStyle(GPUVariantPalette.amber)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(GPUVariantPalette.amber.opacity(0.10)))
                    .overlay(Capsule().strokeBorder(GPUVariantPalette.amber.opacity(0.30), lineWidth: 1))
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(mediaSessions) { s in
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
                if mediaSessions.isEmpty {
                    Text("\u{2022} no active decoder session").font(.system(size: 11)).monospacedDigit().foregroundStyle(GPUVariantPalette.text4)
                }
                Text("\u{2022} no active encoder session").font(.system(size: 11)).monospacedDigit().foregroundStyle(GPUVariantPalette.text4)
                Text("\u{2022} ProRes engine occupancy not exposed").font(.system(size: 11)).monospacedDigit().foregroundStyle(GPUVariantPalette.text4)
            }
        }
    }

    @ViewBuilder
    private var corePanel: some View {
        GPUVariantPanel {
            HStack(alignment: .firstTextBaseline) {
                Text("Per-Core Snapshot")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(GPUVariantPalette.text)
                Spacer()
                Text("\(coreCount) cores \u{00B7} approximation")
                    .font(.system(size: 10)).monospacedDigit().foregroundStyle(GPUVariantPalette.text4)
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
                            Text("C\(c.id + 1)")
                                .font(.system(size: 8, weight: .medium))
                                .monospacedDigit()
                                .foregroundStyle(GPUVariantPalette.text4)
                        }
                    }
                }
            }
            .frame(height: 100)
            GPUVariantFootnote(text: "Per-core busy is an approximation. IOAccelerator does not expose per-shader-core residency on this GPU.")
        }
    }

    @ViewBuilder
    private func statRow(_ k: String, _ v: String) -> some View {
        HStack(spacing: 8) {
            Text(k).font(.system(size: 10)).tracking(0.6).foregroundStyle(GPUVariantPalette.text4)
            Text(v).font(.system(size: 12, weight: .semibold)).monospacedDigit().foregroundStyle(GPUVariantPalette.text)
        }
    }
}

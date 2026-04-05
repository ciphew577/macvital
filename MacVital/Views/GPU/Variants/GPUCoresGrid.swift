// MacVital/Views/GPU/Variants/GPUCoresGrid.swift
import SwiftUI

struct GPUCoresGrid: View {
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
                top
                aneStrip
                mediaStrip
            }
        }
    }

    @ViewBuilder
    private var top: some View {
        HStack(alignment: .top, spacing: 12) {
            hero.frame(maxWidth: 320)
            grid.frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var hero: some View {
        GPUVariantPanel {
            GPUVariantSectionLabel(text: "GPU Busy", source: "IOReport")
            HStack(alignment: .lastTextBaseline) {
                HStack(alignment: .lastTextBaseline, spacing: 1) {
                    Text(String(format: "%.0f", overall))
                        .font(.system(size: 44, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(GPUVariantPalette.indigo)
                    Text("%")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(GPUVariantPalette.indigo)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    miniStat("Power", String(format: "%.1f W", gpu?.power ?? 0))
                    miniStat("Freq", freqMHz > 0 ? "\(freqMHz) MHz" : "-")
                    miniStat("VRAM", String(format: "%.1f GB", Double(gpu?.vramUsed ?? 0) / 1_073_741_824.0))
                }
            }
            GPUVariantSplitStack(render: split.render, compute: split.compute, media: split.media, ane: split.ane, idle: split.idle)
            GPUVariantSplitLegend(render: split.render * 100, compute: split.compute * 100, media: split.media * 100, anePower: aneWatts)
            GPUVariantFootnote(text: "Real busy ratio from IOAccelerator. Render and Compute split derived from PerformanceStatistics.")
        }
    }

    @ViewBuilder
    private var grid: some View {
        GPUVariantPanel {
            HStack(alignment: .firstTextBaseline) {
                Text("\(coreCount) GPU Cores")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(GPUVariantPalette.text)
                Spacer()
                Text("AGX shader cores \u{00B7} busy % \u{00B7} freq MHz")
                    .font(.system(size: 10))
                    .monospacedDigit()
                    .foregroundStyle(GPUVariantPalette.text4)
            }
            let cols = [GridItem(.adaptive(minimum: 92, maximum: 160), spacing: 8, alignment: .top)]
            LazyVGrid(columns: cols, spacing: 8) {
                ForEach(cores) { c in coreCard(c) }
            }
            GPUVariantFootnote(text: "Per-core busy not exposed by IOAccelerator. Values derived from device utilization with deterministic per-core jitter.")
        }
    }

    @ViewBuilder
    private func coreCard(_ c: GPUVariantPerCore) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("C\(c.id + 1)")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(GPUVariantPalette.text4)
                Spacer()
                Circle().fill(GPUVariantPalette.heat(for: c.busy)).frame(width: 6, height: 6)
            }
            Text(String(format: "%.0f%%", c.busy * 100))
                .font(.system(size: 18, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(GPUVariantPalette.text)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(GPUVariantPalette.idle).frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(GPUVariantPalette.heat(for: c.busy))
                        .frame(width: g.size.width * c.busy, height: 4)
                }
            }
            .frame(height: 4)
            Text("\(c.freqMHz) MHz")
                .font(.system(size: 10))
                .monospacedDigit()
                .foregroundStyle(GPUVariantPalette.text3)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GPUVariantPalette.bg)
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(GPUVariantPalette.surfaceLine, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var aneStrip: some View {
        GPUVariantPanel {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    GPUVariantSectionLabel(text: "Neural Engine", accent: GPUVariantPalette.teal, source: "IOReport \u{00B7} Energy Model")
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text(String(format: "%.2f", aneWatts))
                            .font(.system(size: 26, weight: .heavy))
                            .monospacedDigit()
                            .foregroundStyle(GPUVariantPalette.teal)
                        Text("W")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(GPUVariantPalette.teal)
                    }
                    Text("Threshold for Active state \u{2265} 0.30 W")
                        .font(.system(size: 11)).monospacedDigit().foregroundStyle(GPUVariantPalette.text3)
                    Text("No utilisation % exposed by Apple.")
                        .font(.system(size: 10)).foregroundStyle(GPUVariantPalette.text4)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    GPUVariantANEPill(watts: aneWatts)
                    GPUVariantANESpark(samples: GPUVariantData.aneSpark(peakWatts: max(0.5, aneWatts)), peak: max(0.5, aneWatts))
                        .frame(width: 200)
                }
            }
        }
    }

    @ViewBuilder
    private var mediaStrip: some View {
        GPUVariantPanel {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    GPUVariantSectionLabel(text: "Media Engine", accent: GPUVariantPalette.amber, source: "VT + AppleAVD/AVE")
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text("\(mediaSessions.count)")
                            .font(.system(size: 26, weight: .heavy))
                            .monospacedDigit()
                            .foregroundStyle(GPUVariantPalette.amber)
                        Text("/4")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(GPUVariantPalette.amber)
                    }
                    if let s = mediaSessions.first {
                        Text("\(s.owner) \u{00B7} \(s.detail) \u{00B7} \(s.duration)")
                            .font(.system(size: 11)).monospacedDigit().foregroundStyle(GPUVariantPalette.text3)
                    } else {
                        Text("Encoders idle. ProRes occupancy not exposed.")
                            .font(.system(size: 11)).foregroundStyle(GPUVariantPalette.text4)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
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
                    HStack(spacing: 5) {
                        Circle().fill(GPUVariantPalette.slate).frame(width: 6, height: 6)
                        Text("2 ENC IDLE").font(.system(size: 10, weight: .semibold)).tracking(0.8).foregroundStyle(GPUVariantPalette.slate)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(GPUVariantPalette.slate.opacity(0.10)))
                    .overlay(Capsule().strokeBorder(GPUVariantPalette.slate.opacity(0.30), lineWidth: 1))
                }
            }
        }
    }

    @ViewBuilder
    private func miniStat(_ k: String, _ v: String) -> some View {
        HStack(spacing: 6) {
            Text(k).font(.system(size: 10)).tracking(0.6).foregroundStyle(GPUVariantPalette.text4)
            Text(v).font(.system(size: 11, weight: .semibold)).monospacedDigit().foregroundStyle(GPUVariantPalette.text)
        }
    }
}

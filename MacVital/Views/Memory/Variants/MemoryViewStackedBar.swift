// MacVital/Views/Memory/Variants/MemoryViewStackedBar.swift
import SwiftUI

struct MemoryViewStackedBar: View {
    let memory: MemoryData

    private var composition: MemoryComposition { MemoryComposition(memory: memory) }

    var body: some View {
        ZStack {
            MemoryVariantPalette.canvas
            VStack(alignment: .leading, spacing: 18) {
                head
                bar
                legend
                twins
                Spacer(minLength: 0)
            }
            .padding(20)
        }
    }

    private var head: some View {
        HStack(alignment: .top, spacing: 18) {
            MemoryPressurePill(composition: composition)
            VStack(alignment: .leading, spacing: 2) {
                Text("MEMORY USED")
                    .font(.system(size: 9, weight: .semibold)).tracking(0.10)
                    .foregroundStyle(MemoryVariantPalette.textQuaternary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(formatBytesGB(memory.used))
                        .font(.system(size: 28, weight: .semibold, design: .monospaced))
                        .foregroundStyle(MemoryVariantPalette.textPrimary)
                    Text("GB").font(.system(size: 14)).foregroundStyle(MemoryVariantPalette.textTertiary)
                }
                Text("of \(formatBytesGB(memory.total)) GB physical  ·  \(formatBytesGB(composition.reclaimableBytes)) GB reclaimable")
                    .font(.system(size: 10)).foregroundStyle(MemoryVariantPalette.textTertiary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("APP FORMULA").font(.system(size: 9, weight: .semibold)).tracking(0.10)
                    .foregroundStyle(MemoryVariantPalette.textQuaternary)
                Text("internal − purgeable")
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(MemoryVariantPalette.textTertiary)
                Text("verified vs Activity Monitor")
                    .font(.system(size: 9)).foregroundStyle(MemoryVariantPalette.textQuaternary)
            }
        }
    }

    private var bar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("PHYSICAL MEMORY COMPOSITION")
                    .font(.system(size: 9, weight: .semibold)).tracking(0.10)
                    .foregroundStyle(MemoryVariantPalette.textQuaternary)
                Rectangle().fill(MemoryVariantPalette.hairline).frame(height: 0.5)
                Text("\(formatBytesGB(memory.total)) GB UMA")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(MemoryVariantPalette.textTertiary)
            }
            GeometryReader { geo in
                HStack(spacing: 1) {
                    seg(width: composition.fraction(composition.appBytes) * geo.size.width,
                        color: MemoryVariantPalette.app)
                    seg(width: composition.fraction(composition.wiredBytes) * geo.size.width,
                        color: MemoryVariantPalette.wired)
                    seg(width: composition.fraction(composition.compressedBytes) * geo.size.width,
                        color: MemoryVariantPalette.compressed)
                    seg(width: composition.fraction(composition.cacheBytes) * geo.size.width,
                        color: MemoryVariantPalette.cache)
                    seg(width: composition.fraction(composition.freeBytes) * geo.size.width,
                        color: MemoryVariantPalette.free, stroke: true)
                }
                .frame(height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .frame(height: 36)
        }
    }

    private func seg(width: CGFloat, color: Color, stroke: Bool = false) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: max(0, width), height: 36)
            .overlay(stroke ? Rectangle().stroke(MemoryVariantPalette.hairlineStrong, lineWidth: 0.5) : nil)
    }

    private var legend: some View {
        HStack(alignment: .top, spacing: 16) {
            legendCell("App memory", composition.appBytes, MemoryVariantPalette.app, "internal − purgeable")
            legendCell("Wired", composition.wiredBytes, MemoryVariantPalette.wired, "kernel + IOKit")
            legendCell("Compressed", composition.compressedBytes, MemoryVariantPalette.compressed, "compressor pages")
            legendCell("Cache files", composition.cacheBytes, MemoryVariantPalette.cache, "purgeable + external")
            legendCell("Free", composition.freeBytes, MemoryVariantPalette.free, "free − speculative")
        }
    }

    private func legendCell(_ name: String, _ bytes: UInt64, _ color: Color, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 10, height: 10)
                Text(name).font(.system(size: 11, weight: .semibold)).foregroundStyle(MemoryVariantPalette.textPrimary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(formatBytesGB(bytes)) GB")
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundStyle(MemoryVariantPalette.textPrimary)
                Text(String(format: "%.1f%%", composition.fraction(bytes) * 100))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(MemoryVariantPalette.textTertiary)
            }
            Text(sub).font(.system(size: 9)).foregroundStyle(MemoryVariantPalette.textQuaternary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var twins: some View {
        HStack(spacing: 12) {
            sparkCard(title: "Compressor activity",
                      value: "\(formatBytesGB(composition.compressedBytes)) GB",
                      color: MemoryVariantPalette.compressed,
                      sub: "compressor holds")
            sparkCard(title: "Swap rate",
                      value: composition.swapUsed > 0 ? "\(formatBytesGB(composition.swapUsed)) GB" : "0",
                      color: MemoryVariantPalette.swap,
                      sub: composition.swapUsed > 0 ? "residual" : "idle  ·  no page-outs")
            yieldCard
        }
    }

    private func sparkCard(title: String, value: String, color: Color, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title.uppercased()).font(.system(size: 9, weight: .semibold)).tracking(0.10)
                    .foregroundStyle(MemoryVariantPalette.textQuaternary)
                Spacer()
                Text(value).font(.system(size: 13, weight: .semibold, design: .monospaced)).foregroundStyle(color)
            }
            Rectangle().fill(MemoryVariantPalette.hairline).frame(height: 0.5)
            Text(sub).font(.system(size: 9)).foregroundStyle(MemoryVariantPalette.textTertiary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(MemoryVariantPalette.surface))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(MemoryVariantPalette.hairline, lineWidth: 0.5))
    }

    private var yieldCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("COMPRESSION YIELD").font(.system(size: 9, weight: .semibold)).tracking(0.10)
                    .foregroundStyle(MemoryVariantPalette.textQuaternary)
                Spacer()
                Text("2.8 : 1").font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(MemoryVariantPalette.app)
            }
            Text("Compressor stores \(formatBytesGB(composition.compressedBytes)) GB.")
                .font(.system(size: 10)).foregroundStyle(MemoryVariantPalette.textTertiary)
            Text("SWAP RESIDUAL  \(formatBytesGB(composition.swapUsed)) GB")
                .font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(0.08)
                .foregroundStyle(MemoryVariantPalette.swap)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(MemoryVariantPalette.surface))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(MemoryVariantPalette.hairline, lineWidth: 0.5))
    }
}

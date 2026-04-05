// MacVital/Views/Memory/Variants/MemoryViewCircuitBoard.swift
import SwiftUI

struct MemoryViewCircuitBoard: View {
    let memory: MemoryData

    private var composition: MemoryComposition { MemoryComposition(memory: memory) }

    var body: some View {
        ZStack {
            MemoryVariantPalette.canvas
            VStack(alignment: .leading, spacing: 14) {
                head
                board
                Spacer(minLength: 0)
            }
            .padding(20)
        }
    }

    private var head: some View {
        HStack(alignment: .top, spacing: 18) {
            MemoryPressurePill(composition: composition)
            VStack(alignment: .leading, spacing: 2) {
                Text("UNIFIED POOL").font(.system(size: 9, weight: .semibold)).tracking(0.10)
                    .foregroundStyle(MemoryVariantPalette.textQuaternary)
                Text("\(formatBytesGB(memory.total)) GB")
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .foregroundStyle(MemoryVariantPalette.textPrimary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("IN USE").font(.system(size: 9, weight: .semibold)).tracking(0.10)
                    .foregroundStyle(MemoryVariantPalette.textQuaternary)
                Text("\(formatBytesGB(memory.used)) GB")
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .foregroundStyle(MemoryVariantPalette.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("RECLAIMABLE").font(.system(size: 9, weight: .semibold)).tracking(0.10)
                    .foregroundStyle(MemoryVariantPalette.textQuaternary)
                Text("\(formatBytesGB(composition.reclaimableBytes)) GB")
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.green)
                Text("cache + free").font(.system(size: 9)).foregroundStyle(MemoryVariantPalette.textTertiary)
            }
        }
    }

    private var board: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("APPLE SILICON UMA  ·  PHYSICAL MEMORY MAP")
                    .font(.system(size: 9, weight: .semibold)).tracking(0.10)
                    .foregroundStyle(MemoryVariantPalette.textQuaternary)
                Rectangle().fill(MemoryVariantPalette.hairline).frame(height: 0.5)
                Text("16 KB pages  ·  vm_statistics64")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(MemoryVariantPalette.textTertiary)
            }
            HStack(alignment: .top, spacing: 12) {
                grid
                    .frame(maxWidth: .infinity)
                sideStrip
                    .frame(width: 200)
            }
        }
    }

    private var grid: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                block(tag: "Active", cap: "App memory",
                      bytes: composition.appBytes, sub: "internal − purgeable",
                      color: MemoryVariantPalette.app, span: 2)
                block(tag: "Pinned", cap: "Wired",
                      bytes: composition.wiredBytes, sub: "kernel + IOKit",
                      color: MemoryVariantPalette.wired, span: 1)
                block(tag: "2.8 : 1", cap: "Compressed",
                      bytes: composition.compressedBytes, sub: "compressor pages",
                      color: MemoryVariantPalette.compressed, span: 1)
                block(tag: nil, cap: "Cache files",
                      bytes: composition.cacheBytes, sub: "purgeable + external",
                      color: MemoryVariantPalette.cache, span: 1, dashed: true)
            }
            HStack(spacing: 10) {
                block(tag: nil, cap: "Free",
                      bytes: composition.freeBytes, sub: "free − speculative",
                      color: MemoryVariantPalette.free, span: 1, dashed: true, dim: true)
                block(tag: "Virtual gain", cap: "Compressor headroom",
                      bytes: composition.compressedBytes * 4, sub: "stored compressed",
                      color: MemoryVariantPalette.app, span: 2, accentNumber: true)
                block(tag: "Disk  ·  idle", cap: "Swap (off chip)",
                      bytes: composition.swapUsed, sub: "0 pg/s residual",
                      color: MemoryVariantPalette.swap, span: 2, swap: true,
                      swapTotal: composition.swapUsed + composition.swapFree)
            }
        }
    }

    @ViewBuilder
    private func block(tag: String?, cap: String, bytes: UInt64, sub: String,
                       color: Color, span: Int, dashed: Bool = false, dim: Bool = false,
                       accentNumber: Bool = false, swap: Bool = false, swapTotal: UInt64 = 0) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Rectangle().fill(color).frame(height: 3).clipShape(Capsule())
            }.frame(height: 3)
            if let tag {
                Text(tag.uppercased()).font(.system(size: 8, weight: .semibold)).tracking(0.10)
                    .foregroundStyle(color)
            }
            Text(cap).font(.system(size: 11, weight: .semibold)).foregroundStyle(MemoryVariantPalette.textPrimary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(formatBytesGB(bytes))
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundStyle(accentNumber ? color : (dim ? MemoryVariantPalette.textSecondary : MemoryVariantPalette.textPrimary))
                Text("GB").font(.system(size: 11)).foregroundStyle(MemoryVariantPalette.textTertiary)
                if swap, swapTotal > 0 {
                    Text("/ \(formatBytesGB(swapTotal)) GB").font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(MemoryVariantPalette.textTertiary)
                }
            }
            if !sub.isEmpty {
                Text(sub).font(.system(size: 9)).foregroundStyle(MemoryVariantPalette.textTertiary)
            }
            if span >= 2 || cap.contains("App memory") {
                Text(String(format: "%.1f %%", composition.fraction(bytes) * 100))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(MemoryVariantPalette.textQuaternary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        .frame(maxWidth: span == 1 ? 180 : .infinity)
        .background(RoundedRectangle(cornerRadius: 8).fill(MemoryVariantPalette.surface))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(style: StrokeStyle(lineWidth: 0.7, dash: dashed ? [3, 3] : []))
                .foregroundStyle(dashed ? color.opacity(0.55) : MemoryVariantPalette.hairline)
        )
    }

    private var sideStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            sideStat("Compressor act", "\(formatBytesGB(composition.compressedBytes, decimals: 2))", "GB held", color: MemoryVariantPalette.compressed)
            sideStat("Swap used", composition.swapUsed > 0 ? formatBytesGB(composition.swapUsed, decimals: 2) : "0", composition.swapUsed > 0 ? "GB" : "GB", color: MemoryVariantPalette.textSecondary)
            sideStat("Page size", "16", "KB", color: MemoryVariantPalette.textPrimary)
            sideStat("Tick", "2", "s", color: MemoryVariantPalette.textPrimary)
            Spacer(minLength: 0)
        }
    }

    private func sideStat(_ k: String, _ v: String, _ unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(k.uppercased()).font(.system(size: 9, weight: .semibold)).tracking(0.10)
                .foregroundStyle(MemoryVariantPalette.textQuaternary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(v).font(.system(size: 16, weight: .semibold, design: .monospaced)).foregroundStyle(color)
                Text(unit).font(.system(size: 9)).foregroundStyle(MemoryVariantPalette.textTertiary)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(MemoryVariantPalette.surface))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(MemoryVariantPalette.hairline, lineWidth: 0.5))
    }
}

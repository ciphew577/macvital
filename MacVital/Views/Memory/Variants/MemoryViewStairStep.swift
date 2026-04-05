// MacVital/Views/Memory/Variants/MemoryViewStairStep.swift
import SwiftUI

struct MemoryViewStairStep: View {
    let memory: MemoryData
    let appList: [AppMemoryInfo]

    private var composition: MemoryComposition { MemoryComposition(memory: memory) }

    private struct Column: Identifiable {
        let id: String
        let label: String
        let sub: String
        let bytes: UInt64
        let color: Color
        let bonus: String?
    }

    private var columns: [Column] {
        [
            Column(id: "free", label: "Free", sub: "free − speculative", bytes: composition.freeBytes, color: MemoryVariantPalette.free, bonus: nil),
            Column(id: "wired", label: "Wired", sub: "kernel + IOKit", bytes: composition.wiredBytes, color: MemoryVariantPalette.wired, bonus: nil),
            Column(id: "compressed", label: "Compressed", sub: "2.8 : 1 ratio", bytes: composition.compressedBytes, color: MemoryVariantPalette.compressed, bonus: "+ saves \(formatBytesGB(composition.compressedBytes * 4)) GB"),
            Column(id: "cache", label: "Cache files", sub: "reclaimable", bytes: composition.cacheBytes, color: MemoryVariantPalette.cache, bonus: nil),
            Column(id: "app", label: "App memory", sub: "internal − purgeable", bytes: composition.appBytes, color: MemoryVariantPalette.app, bonus: nil),
        ]
    }

    private var ceilingBytes: UInt64 {
        max(columns.map { $0.bytes }.max() ?? 1, UInt64(1_073_741_824))
    }

    var body: some View {
        ZStack {
            MemoryVariantPalette.canvas
            VStack(alignment: .leading, spacing: 16) {
                head
                stage
                rail
                Spacer(minLength: 0)
            }
            .padding(20)
        }
    }

    private var head: some View {
        HStack(alignment: .top, spacing: 14) {
            MemoryPressurePill(composition: composition)
            VStack(alignment: .leading, spacing: 2) {
                Text("USED").font(.system(size: 9, weight: .semibold)).tracking(0.10)
                    .foregroundStyle(MemoryVariantPalette.textQuaternary)
                Text("\(formatBytesGB(memory.used)) GB")
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .foregroundStyle(MemoryVariantPalette.textPrimary)
            }
            Spacer()
            calloutBadge(icon: "↓", text: "Compressor stores \(formatBytesGB(composition.compressedBytes)) GB  ·  ratio 2.8 : 1", color: MemoryVariantPalette.app)
            calloutBadge(icon: "~", text: "Swap \(formatBytesGB(composition.swapUsed)) GB residual  ·  0 pg/s", color: MemoryVariantPalette.swap)
        }
    }

    private func calloutBadge(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(icon).font(.system(size: 10, weight: .bold)).foregroundStyle(color)
                .frame(width: 16, height: 16)
                .background(RoundedRectangle(cornerRadius: 4).fill(color.opacity(0.10)))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(color.opacity(0.35), lineWidth: 0.5))
            Text(text).font(.system(size: 10)).foregroundStyle(MemoryVariantPalette.textSecondary)
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 6).fill(color.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(color.opacity(0.20), lineWidth: 0.5))
    }

    private var stage: some View {
        GeometryReader { geo in
            let arenaH: CGFloat = max(220, geo.size.height - 40)
            HStack(alignment: .bottom, spacing: 12) {
                axis(arenaH: arenaH)
                ForEach(columns) { col in
                    columnView(col, arenaH: arenaH)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: arenaH)
        }
        .frame(minHeight: 240)
    }

    private func axis(arenaH: CGFloat) -> some View {
        let ceilingGB = max(1.0, Double(ceilingBytes) / 1_073_741_824.0)
        let ticks = [1.0, 0.75, 0.5, 0.25, 0.0]
        return ZStack(alignment: .topLeading) {
            ForEach(ticks, id: \.self) { t in
                let labelGB = ceilingGB * t
                Text(String(format: "%.0f", labelGB))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(MemoryVariantPalette.textQuaternary)
                    .frame(width: 28, alignment: .trailing)
                    .offset(y: arenaH * (1 - t) - 6)
            }
        }
        .frame(width: 30, height: arenaH)
    }

    private func columnView(_ col: Column, arenaH: CGFloat) -> some View {
        VStack(spacing: 6) {
            ZStack(alignment: .bottom) {
                Rectangle().fill(Color.white.opacity(0.02))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                let frac = Double(col.bytes) / max(1.0, Double(ceilingBytes))
                let h = max(2, CGFloat(frac) * (arenaH - 40))
                VStack(spacing: 4) {
                    if let bonus = col.bonus {
                        Text(bonus)
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(MemoryVariantPalette.app)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(RoundedRectangle(cornerRadius: 4).fill(MemoryVariantPalette.app.opacity(0.10)))
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(MemoryVariantPalette.app.opacity(0.30), lineWidth: 0.5))
                    }
                    ZStack(alignment: .top) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(col.color)
                            .frame(height: h)
                        VStack(spacing: 2) {
                            Text(formatBytesGB(col.bytes))
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundStyle(MemoryVariantPalette.textPrimary)
                            Text(String(format: "%.1f %%", composition.fraction(col.bytes) * 100))
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(MemoryVariantPalette.textTertiary)
                        }
                        .padding(.top, 6)
                    }
                }
            }
            VStack(spacing: 1) {
                Text(col.label).font(.system(size: 11, weight: .semibold)).foregroundStyle(MemoryVariantPalette.textPrimary)
                Text(col.sub).font(.system(size: 9)).foregroundStyle(MemoryVariantPalette.textTertiary)
            }
        }
    }

    private var rail: some View {
        HStack(spacing: 8) {
            Text("TOP APPS").font(.system(size: 9, weight: .semibold)).tracking(0.10)
                .foregroundStyle(MemoryVariantPalette.textQuaternary)
            ForEach(appList.prefix(4)) { app in
                HStack(spacing: 5) {
                    Circle().fill(MemoryVariantPalette.app).frame(width: 6, height: 6)
                    Text(app.name).font(.system(size: 10)).foregroundStyle(MemoryVariantPalette.textSecondary)
                    Text("\(formatBytesGB(app.memoryBytes, decimals: 2)) GB")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(MemoryVariantPalette.textPrimary)
                }
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 999).fill(MemoryVariantPalette.surface))
                .overlay(RoundedRectangle(cornerRadius: 999).stroke(MemoryVariantPalette.hairline, lineWidth: 0.5))
            }
            Spacer()
            Text("SOURCE  phys_footprint")
                .font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(0.10)
                .foregroundStyle(MemoryVariantPalette.textQuaternary)
        }
    }
}

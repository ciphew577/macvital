// MacVital/Views/Memory/Variants/MemoryViewSunburst.swift
import SwiftUI

struct MemoryViewSunburst: View {
    let memory: MemoryData
    let appList: [AppMemoryInfo]
    let footprintBytes: UInt64

    private var composition: MemoryComposition { MemoryComposition(memory: memory) }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            MemoryVariantPalette.canvas
            VStack(spacing: 0) {
                head
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 10)
                Divider().background(MemoryVariantPalette.hairline)
                HStack(alignment: .top, spacing: 16) {
                    burst
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    sideStack
                        .frame(width: 240)
                }
                .padding(20)
            }
        }
    }

    private var head: some View {
        HStack(alignment: .center, spacing: 14) {
            MemoryPressurePill(composition: composition)
            VStack(alignment: .leading, spacing: 2) {
                Text("MEMORY USED")
                    .font(.system(size: 9, weight: .semibold)).tracking(0.10)
                    .foregroundStyle(MemoryVariantPalette.textQuaternary)
                Text("\(formatBytesGB(memory.used)) GB")
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .foregroundStyle(MemoryVariantPalette.textPrimary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("RECLAIMABLE")
                    .font(.system(size: 9, weight: .semibold)).tracking(0.10)
                    .foregroundStyle(MemoryVariantPalette.textQuaternary)
                Text("\(formatBytesGB(composition.reclaimableBytes)) GB")
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundStyle(MemoryVariantPalette.app)
            }
            Spacer()
            HStack(spacing: 6) {
                pill("App", composition.appBytes, MemoryVariantPalette.app)
                pill("Wired", composition.wiredBytes, MemoryVariantPalette.wired)
                pill("Compressed", composition.compressedBytes, MemoryVariantPalette.compressed)
                pill("Cache", composition.cacheBytes, MemoryVariantPalette.cache)
                pill("Swap", composition.swapUsed, MemoryVariantPalette.swap)
            }
        }
    }

    private func pill(_ label: String, _ bytes: UInt64, _ color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).font(.system(size: 10, weight: .medium)).foregroundStyle(MemoryVariantPalette.textSecondary)
            Text(formatBytesGB(bytes)).font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(MemoryVariantPalette.textPrimary)
        }
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 999).fill(MemoryVariantPalette.surface))
        .overlay(RoundedRectangle(cornerRadius: 999).stroke(MemoryVariantPalette.hairline, lineWidth: 0.5))
    }

    private var burst: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                SunburstShape(composition: composition, appList: appList)
                    .frame(width: side, height: side)
                VStack(spacing: 2) {
                    Text("USED").font(.system(size: 9, weight: .semibold)).tracking(0.10)
                        .foregroundStyle(MemoryVariantPalette.textQuaternary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(formatBytesGB(memory.used))
                            .font(.system(size: 30, weight: .semibold, design: .monospaced))
                            .foregroundStyle(MemoryVariantPalette.textPrimary)
                        Text("GB").font(.system(size: 12)).foregroundStyle(MemoryVariantPalette.textTertiary)
                    }
                    Text("of \(formatBytesGB(memory.total)) physical")
                        .font(.system(size: 10)).foregroundStyle(MemoryVariantPalette.textTertiary)
                    HStack(spacing: 14) {
                        VStack(spacing: 1) {
                            Text("FREE").font(.system(size: 8, weight: .semibold)).tracking(0.10)
                                .foregroundStyle(MemoryVariantPalette.textQuaternary)
                            Text(formatBytesGB(memory.free))
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(MemoryVariantPalette.textSecondary)
                        }
                        VStack(spacing: 1) {
                            Text("RECLAIM").font(.system(size: 8, weight: .semibold)).tracking(0.10)
                                .foregroundStyle(MemoryVariantPalette.textQuaternary)
                            Text(formatBytesGB(composition.cacheBytes))
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(MemoryVariantPalette.textSecondary)
                        }
                    }
                    .padding(.top, 6)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private var sideStack: some View {
        VStack(spacing: 10) {
            kard(title: "Compression yield", value: ratioString, valueColor: MemoryVariantPalette.app) {
                Text("Compressor holds \(formatBytesGB(composition.compressedBytes)) GB.")
                    .font(.system(size: 10)).foregroundStyle(MemoryVariantPalette.textTertiary)
            }
            kard(title: "Swap", value: "\(formatBytesGB(composition.swapUsed)) GB", valueColor: MemoryVariantPalette.swap) {
                VStack(alignment: .leading, spacing: 4) {
                    rowKV("Free", "\(formatBytesGB(composition.swapFree)) GB")
                    rowKV("Used", "\(formatBytesGB(composition.swapUsed)) GB")
                }
            }
            kard(title: "Footprint", value: "\(formatBytesGB(footprintBytes)) GB", valueColor: MemoryVariantPalette.textPrimary) {
                Text("Used + swap. Phys footprint signal.")
                    .font(.system(size: 10)).foregroundStyle(MemoryVariantPalette.textTertiary)
            }
            Spacer(minLength: 0)
        }
    }

    private func kard<C: View>(title: String, value: String, valueColor: Color, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .semibold)).tracking(0.10)
                    .foregroundStyle(MemoryVariantPalette.textQuaternary)
                Spacer()
                Text(value)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(valueColor)
            }
            content()
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(MemoryVariantPalette.surface))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(MemoryVariantPalette.hairline, lineWidth: 0.5))
    }

    private func rowKV(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).font(.system(size: 10)).foregroundStyle(MemoryVariantPalette.textTertiary)
            Spacer()
            Text(v).font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(MemoryVariantPalette.textPrimary)
        }
    }

    private var ratioString: String {
        // TODO: Replace 2.8 with kernel-reported live ratio (vm_stat compressor stats).
        // Hardcoded to match Stacked bar, Stair step, Circuit board, Pressure centric variants.
        guard composition.compressedBytes > 0 else { return "1.0 : 1" }
        return "2.8 : 1"
    }
}

private struct SunburstShape: View {
    let composition: MemoryComposition
    let appList: [AppMemoryInfo]

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: s / 2, y: s / 2)
            let outerR = s / 2 - 4
            let innerR = outerR * 0.62
            let holeR = outerR * 0.42
            ZStack {
                ForEach(0..<innerSegments.count, id: \.self) { i in
                    InnerArc(start: innerSegments[i].start, end: innerSegments[i].end,
                             inner: innerR, outer: outerR, center: center)
                        .fill(innerSegments[i].color)
                }
                ForEach(0..<outerSegments.count, id: \.self) { i in
                    InnerArc(start: outerSegments[i].start, end: outerSegments[i].end,
                             inner: holeR, outer: innerR - 2, center: center)
                        .fill(outerSegments[i].color)
                }
                Circle()
                    .stroke(MemoryVariantPalette.hairline, lineWidth: 0.5)
                    .frame(width: holeR * 2, height: holeR * 2)
                    .position(center)
            }
        }
    }

    private struct Seg { let start: Double; let end: Double; let color: Color }

    private var innerSegments: [Seg] {
        let parts: [(UInt64, Color)] = [
            (composition.appBytes, MemoryVariantPalette.app),
            (composition.wiredBytes, MemoryVariantPalette.wired),
            (composition.compressedBytes, MemoryVariantPalette.compressed),
            (composition.cacheBytes, MemoryVariantPalette.cache),
            (composition.freeBytes, MemoryVariantPalette.free),
        ]
        let total = max(1, parts.reduce(UInt64(0)) { $0 + $1.0 })
        var cursor: Double = -.pi / 2
        var out: [Seg] = []
        for (bytes, color) in parts where bytes > 0 {
            let span = Double(bytes) / Double(total) * (.pi * 2)
            out.append(Seg(start: cursor, end: cursor + span, color: color))
            cursor += span
        }
        return out
    }

    private var outerSegments: [Seg] {
        let totalApps = max(UInt64(1), appList.prefix(8).reduce(UInt64(0)) { $0 + $1.memoryBytes })
        let parts = appList.prefix(8).enumerated().map { idx, app -> (UInt64, Color) in
            let palette: [Color] = [
                MemoryVariantPalette.app.opacity(0.95),
                MemoryVariantPalette.app.opacity(0.78),
                MemoryVariantPalette.cache.opacity(0.85),
                MemoryVariantPalette.cache.opacity(0.65),
                MemoryVariantPalette.wired.opacity(0.80),
                MemoryVariantPalette.wired.opacity(0.60),
                MemoryVariantPalette.compressed.opacity(0.85),
                MemoryVariantPalette.compressed.opacity(0.65),
            ]
            return (app.memoryBytes, palette[idx % palette.count])
        }
        var cursor: Double = -.pi / 2
        var out: [Seg] = []
        for (bytes, color) in parts where bytes > 0 {
            let span = Double(bytes) / Double(totalApps) * (.pi * 2)
            out.append(Seg(start: cursor, end: cursor + span, color: color))
            cursor += span
        }
        return out
    }
}

private struct InnerArc: Shape {
    let start: Double
    let end: Double
    let inner: CGFloat
    let outer: CGFloat
    let center: CGPoint

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let s = Angle(radians: start)
        let e = Angle(radians: end)
        p.addArc(center: center, radius: outer, startAngle: s, endAngle: e, clockwise: false)
        p.addArc(center: center, radius: inner, startAngle: e, endAngle: s, clockwise: true)
        p.closeSubpath()
        return p
    }
}

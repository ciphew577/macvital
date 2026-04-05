// MacVital/Views/Memory/Variants/MemoryViewPressureCentric.swift
import SwiftUI

struct MemoryViewPressureCentric: View {
    let memory: MemoryData

    private var composition: MemoryComposition { MemoryComposition(memory: memory) }

    var body: some View {
        ZStack {
            MemoryVariantPalette.canvas
            HStack(alignment: .top, spacing: 16) {
                arcCard
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                rightStack
                    .frame(width: 320)
            }
            .padding(20)
        }
    }

    private var arcCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("MEMORY PRESSURE").font(.system(size: 9, weight: .semibold)).tracking(0.10)
                        .foregroundStyle(MemoryVariantPalette.textQuaternary)
                    Text("kern.memorystatus_vm_pressure_level = \(pressureLevelInt)")
                        .font(.system(size: 9, design: .monospaced)).foregroundStyle(MemoryVariantPalette.textTertiary)
                }
                Spacer()
                HStack(spacing: 6) {
                    Text("LAST 24 H").font(.system(size: 9, weight: .semibold)).tracking(0.10)
                        .foregroundStyle(MemoryVariantPalette.textQuaternary)
                    HStack(spacing: 3) {
                        Circle().fill(MV.accentSage).frame(width: 6, height: 6)
                        Circle().fill(MV.warning).opacity(0.5).frame(width: 6, height: 6)
                        Circle().fill(MV.critical).opacity(0.3).frame(width: 6, height: 6)
                    }
                }
            }
            ZStack {
                PressureArc(scalar: composition.pressureScalar)
                VStack(spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(composition.pressureScalar)")
                            .font(.system(size: 64, weight: .semibold, design: .monospaced))
                            .foregroundStyle(MemoryVariantPalette.textPrimary)
                        Text("/ 100").font(.system(size: 14)).foregroundStyle(MemoryVariantPalette.textTertiary)
                    }
                    Text(composition.pressureLabel.uppercased())
                        .font(.system(size: 11, weight: .semibold)).tracking(0.10)
                        .foregroundStyle(composition.pressureColor)
                    Text("scalar \(composition.pressureScalar)  ·  level \(pressureLevelInt)  ·  0 events 24 h")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(MemoryVariantPalette.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 280)
            HStack(spacing: 10) {
                threshold("WARNING", "scalar 50  ·  level 2", MV.warning)
                threshold("CRITICAL", "scalar 80  ·  level 4", MV.critical)
                threshold("LAST CRITICAL", "no events 24 h", MemoryVariantPalette.textPrimary)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 10).fill(MemoryVariantPalette.surface))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(MemoryVariantPalette.hairline, lineWidth: 0.5))
    }

    private func threshold(_ k: String, _ v: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(k).font(.system(size: 9, weight: .semibold)).tracking(0.10)
                .foregroundStyle(MemoryVariantPalette.textQuaternary)
            Text(v).font(.system(size: 10, design: .monospaced)).foregroundStyle(color)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.20)))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(MemoryVariantPalette.hairline, lineWidth: 0.5))
    }

    private var rightStack: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Spacer()
                Text("STATES").font(.system(size: 9, weight: .semibold)).tracking(0.10)
                    .foregroundStyle(MemoryVariantPalette.textQuaternary)
                stateChip("Normal", MV.accentSage)
                stateChip("Warning", MV.warning)
                stateChip("Critical", MV.critical)
            }
            callout(letter: "A", title: "App memory",
                    detail: String(format: "internal − purgeable  ·  %.1f %%", composition.fraction(composition.appBytes) * 100),
                    bytes: composition.appBytes, color: MemoryVariantPalette.app)
            callout(letter: "C", title: "Cache files",
                    detail: "reclaimable  ·  purgeable + external",
                    bytes: composition.cacheBytes, color: MemoryVariantPalette.cache)
            callout(letter: "Z", title: "Compressed",
                    detail: "ratio 2.8 : 1  ·  saves \(formatBytesGB(composition.compressedBytes * 4)) GB",
                    bytes: composition.compressedBytes, color: MemoryVariantPalette.compressed)
            callout(letter: "S", title: "Swap",
                    detail: "residual  ·  0 pg/s",
                    bytes: composition.swapUsed, color: MemoryVariantPalette.swap)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("USED / TOTAL").font(.system(size: 9, weight: .semibold)).tracking(0.10)
                        .foregroundStyle(MemoryVariantPalette.textQuaternary)
                    Spacer()
                    Text("\(formatBytesGB(memory.used)) / \(formatBytesGB(memory.total))")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(MemoryVariantPalette.textPrimary)
                }
                Text("Pressure is the signal. Used bytes is just bookkeeping. macOS holds high used numbers on purpose.")
                    .font(.system(size: 10)).foregroundStyle(MemoryVariantPalette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(MemoryVariantPalette.surface))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(MemoryVariantPalette.hairline, lineWidth: 0.5))
            Spacer(minLength: 0)
        }
    }

    private func stateChip(_ label: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).font(.system(size: 9, weight: .semibold)).tracking(0.04)
                .foregroundStyle(MemoryVariantPalette.textSecondary)
        }
        .padding(.horizontal, 6).padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 999).fill(color.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 999).stroke(color.opacity(0.25), lineWidth: 0.5))
    }

    private func callout(letter: String, title: String, detail: String, bytes: UInt64, color: Color) -> some View {
        HStack(spacing: 10) {
            Text(letter).font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: 6).fill(color.opacity(0.10)))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(color.opacity(0.35), lineWidth: 0.5))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(MemoryVariantPalette.textPrimary)
                Text(detail).font(.system(size: 9)).foregroundStyle(MemoryVariantPalette.textTertiary)
            }
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(formatBytesGB(bytes))
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundStyle(MemoryVariantPalette.textPrimary)
                Text("GB").font(.system(size: 10)).foregroundStyle(MemoryVariantPalette.textTertiary)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(MemoryVariantPalette.surface))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(MemoryVariantPalette.hairline, lineWidth: 0.5))
    }

    private var pressureLevelInt: Int {
        switch composition.pressureLevel {
        case .nominal: return 1
        case .warning: return 2
        case .critical: return 4
        }
    }
}

private struct PressureArc: View {
    let scalar: Int

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let center = CGPoint(x: w / 2, y: h * 0.92)
            let radius = min(w / 2 - 20, h - 40)
            ZStack {
                ArcStroke(start: 180, end: 180 + 180 * 0.5, color: MV.accentSage.opacity(0.55),
                          center: center, radius: radius)
                ArcStroke(start: 180 + 180 * 0.5, end: 180 + 180 * 0.8, color: MV.warning.opacity(0.55),
                          center: center, radius: radius)
                ArcStroke(start: 180 + 180 * 0.8, end: 360, color: MV.critical.opacity(0.55),
                          center: center, radius: radius)
                let frac = max(0, min(1, Double(scalar) / 100.0))
                let needleAngle = Angle(degrees: 180 + 180 * frac)
                Path { p in
                    p.move(to: center)
                    p.addLine(to: CGPoint(
                        x: center.x + cos(needleAngle.radians) * radius * 0.92,
                        y: center.y + sin(needleAngle.radians) * radius * 0.92
                    ))
                }
                .stroke(MemoryVariantPalette.textPrimary, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                Circle().fill(MemoryVariantPalette.textPrimary).frame(width: 8, height: 8).position(center)
                tick(label: "0", angleDeg: 180, center: center, radius: radius + 12)
                tick(label: "50", angleDeg: 270, center: center, radius: radius + 12)
                tick(label: "100", angleDeg: 360, center: center, radius: radius + 12)
            }
        }
    }

    @ViewBuilder
    private func tick(label: String, angleDeg: Double, center: CGPoint, radius: CGFloat) -> some View {
        let rad = angleDeg * .pi / 180
        Text(label).font(.system(size: 9, design: .monospaced))
            .foregroundStyle(MemoryVariantPalette.textTertiary)
            .position(x: center.x + cos(rad) * radius, y: center.y + sin(rad) * radius)
    }
}

private struct ArcStroke: View {
    let start: Double
    let end: Double
    let color: Color
    let center: CGPoint
    let radius: CGFloat

    var body: some View {
        Path { p in
            p.addArc(center: center,
                     radius: radius,
                     startAngle: .degrees(start),
                     endAngle: .degrees(end),
                     clockwise: false)
        }
        .stroke(color, style: StrokeStyle(lineWidth: 18, lineCap: .butt))
    }
}

// MacVital/Views/Memory/MemorySunburstChart.swift
import SwiftUI
import AppKit

// MARK: - Data Model for Sunburst

struct SunburstCategory {
    let id: String
    let label: String
    let color: Color
    let bytes: UInt64
    let slices: [SunburstSlice]
}

struct SunburstSlice: Identifiable {
    let id = UUID()
    let name: String
    let bytes: UInt64
    let color: Color
}

// MARK: - Sunburst Chart (Canvas-based, two-ring)

struct MemorySunburstChart: View {
    let categories: [SunburstCategory]
    let totalRAM: UInt64
    let swapUsed: UInt64
    let swapFree: UInt64
    let footprintBytes: UInt64

    @State private var hoveredSliceName: String? = nil
    @State private var hoveredSliceBytes: UInt64? = nil
    @State private var hoveredSliceColor: Color = Color(red: 1, green: 0.26, blue: 0.27)

    private let outerRadius: CGFloat = 240
    private let outerInnerRadius: CGFloat = 160
    private let innerInnerRadius: CGFloat = 90
    private let gapAngle: Double = 0.012

    private var totalBytes: UInt64 {
        categories.reduce(0) { $0 + $1.bytes }
    }

    private var usedBytes: UInt64 {
        categories.filter { $0.id != "free" }.reduce(0) { $0 + $1.bytes }
    }

    private var displayBytes: UInt64 {
        hoveredSliceBytes ?? usedBytes
    }

    private var displayColor: Color {
        hoveredSliceBytes != nil ? hoveredSliceColor : Color(red: 1, green: 0.26, blue: 0.27)
    }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let scale = size / 520

            ZStack {
                // Canvas: draw the sunburst
                Canvas { ctx, canvasSize in
                    let cx = canvasSize.width / 2
                    let cy = canvasSize.height / 2
                    let outerR = outerRadius * scale
                    let outerInnerR = outerInnerRadius * scale
                    let innerInnerR = innerInnerRadius * scale

                    // Background circle
                    let bgRect = CGRect(
                        x: cx - outerR - 2,
                        y: cy - outerR - 2,
                        width: (outerR + 2) * 2,
                        height: (outerR + 2) * 2
                    )
                    ctx.fill(Path(ellipseIn: bgRect), with: .color(Color(red: 0.094, green: 0.098, blue: 0.129)))

                    guard totalBytes > 0 else { return }

                    var currentAngle: Double = -.pi / 2

                    for cat in categories {
                        let catFrac = Double(cat.bytes) / Double(totalBytes)
                        let catSpan = catFrac * 2 * .pi - gapAngle
                        let catStart = currentAngle + gapAngle / 2
                        let catEnd = catStart + catSpan

                        // Inner ring slice
                        let innerPath = annularSectorPath(
                            cx: cx, cy: cy,
                            innerR: innerInnerR + 2,
                            outerR: outerInnerR - 2,
                            startAngle: catStart,
                            endAngle: catEnd
                        )
                        ctx.fill(innerPath, with: .color(cat.color))

                        // Outer ring — per-app slices
                        let catTotalSlices = cat.slices.reduce(0) { $0 + $1.bytes }
                        guard catTotalSlices > 0 else {
                            currentAngle += catFrac * 2 * .pi
                            continue
                        }

                        var appAngle = catStart
                        for slice in cat.slices {
                            let appFrac = Double(slice.bytes) / Double(catTotalSlices)
                            let appSpan = appFrac * catSpan - gapAngle * 0.4
                            let appStart = appAngle + gapAngle * 0.2
                            let appEnd = appStart + max(appSpan, 0)
                            appAngle += appFrac * catSpan

                            let outerPath = annularSectorPath(
                                cx: cx, cy: cy,
                                innerR: outerInnerR + 2,
                                outerR: outerR,
                                startAngle: appStart,
                                endAngle: appEnd
                            )

                            let isHovered = hoveredSliceName == slice.name + cat.id
                            let opacity: Double = isHovered ? 1.0 : 0.82
                            let sliceColor = isHovered
                                ? slice.color.opacity(opacity)
                                : slice.color.opacity(opacity)

                            ctx.fill(outerPath, with: .color(sliceColor))
                        }

                        currentAngle += catFrac * 2 * .pi
                    }

                    // Center hole — redraw over everything
                    let holeRect = CGRect(
                        x: cx - innerInnerR,
                        y: cy - innerInnerR,
                        width: innerInnerR * 2,
                        height: innerInnerR * 2
                    )
                    ctx.fill(Path(ellipseIn: holeRect), with: .color(Color(red: 0.094, green: 0.098, blue: 0.129)))

                    // Subtle ring border on hole
                    ctx.stroke(
                        Path(ellipseIn: holeRect.insetBy(dx: 1, dy: 1)),
                        with: .color(Color.white.opacity(0.04)),
                        lineWidth: 1
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Hover detection overlay
                Color.clear
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            handleHover(at: location, center: center, scale: scale)
                        case .ended:
                            hoveredSliceName = nil
                            hoveredSliceBytes = nil
                        }
                    }

                // Center text overlay
                VStack(spacing: 2) {
                    Image(systemName: "memorychip")
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(Color(white: 0.35))

                    Text(formatGB(displayBytes))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(displayColor)
                        .animation(.easeInOut(duration: 0.15), value: displayBytes)

                    Text("of \(formatGBRound(totalRAM)) RAM")
                        .font(.system(size: 13))
                        .foregroundStyle(Color(white: 0.85))

                    Text("FOOTPRINT  \(formatGB(footprintBytes))")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(white: 0.55))
                        .tracking(0.5)
                        .padding(.top, 2)
                }
                .frame(width: innerInnerRadius * 2 * scale - 8)
                .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Hover detection

    private func handleHover(at location: CGPoint, center: CGPoint, scale: CGFloat) {
        let outerR = outerRadius * scale
        let outerInnerR = outerInnerRadius * scale

        let dx = location.x - center.x
        let dy = location.y - center.y
        let distance = sqrt(dx * dx + dy * dy)

        guard distance >= outerInnerR && distance <= outerR else {
            if hoveredSliceName != nil {
                hoveredSliceName = nil
                hoveredSliceBytes = nil
            }
            return
        }

        var angle = atan2(dy, dx) // -pi to pi, 0 = right
        // Normalize to start at top (-pi/2)
        angle -= (-.pi / 2)
        if angle < 0 { angle += 2 * .pi }

        guard totalBytes > 0 else { return }

        var currentAngle: Double = 0 // normalized from top

        for cat in categories {
            let catFrac = Double(cat.bytes) / Double(totalBytes)
            let catSpan = catFrac * 2 * .pi - gapAngle
            let catStart = currentAngle + gapAngle / 2

            let catTotalSlices = cat.slices.reduce(0) { $0 + $1.bytes }
            var appAngle = catStart

            for slice in cat.slices {
                guard catTotalSlices > 0 else { continue }
                let appFrac = Double(slice.bytes) / Double(catTotalSlices)
                let appSpan = appFrac * catSpan - gapAngle * 0.4
                let appStart = appAngle + gapAngle * 0.2
                let appEnd = appStart + max(appSpan, 0)
                appAngle += appFrac * catSpan

                if angle >= appStart && angle <= appEnd {
                    let key = slice.name + cat.id
                    if hoveredSliceName != key {
                        hoveredSliceName = key
                        hoveredSliceBytes = slice.bytes
                        hoveredSliceColor = slice.color
                    }
                    return
                }
            }

            currentAngle += catFrac * 2 * .pi
        }

        hoveredSliceName = nil
        hoveredSliceBytes = nil
    }

    // MARK: - Path helpers

    private func annularSectorPath(
        cx: CGFloat, cy: CGFloat,
        innerR: CGFloat, outerR: CGFloat,
        startAngle: Double, endAngle: Double
    ) -> Path {
        guard endAngle > startAngle else { return Path() }
        var path = Path()
        let p1 = point(cx: cx, cy: cy, r: outerR, angle: startAngle)
        let p2 = point(cx: cx, cy: cy, r: outerR, angle: endAngle)
        let p3 = point(cx: cx, cy: cy, r: innerR, angle: endAngle)
        let p4 = point(cx: cx, cy: cy, r: innerR, angle: startAngle)
        let large = (endAngle - startAngle) > .pi

        path.move(to: p1)
        path.addArc(
            center: CGPoint(x: cx, y: cy),
            radius: outerR,
            startAngle: .radians(startAngle),
            endAngle: .radians(endAngle),
            clockwise: false
        )
        path.addLine(to: p3)
        path.addArc(
            center: CGPoint(x: cx, y: cy),
            radius: innerR,
            startAngle: .radians(endAngle),
            endAngle: .radians(startAngle),
            clockwise: true
        )
        path.closeSubpath()
        _ = large // suppress unused warning
        return path
    }

    private func point(cx: CGFloat, cy: CGFloat, r: CGFloat, angle: Double) -> CGPoint {
        CGPoint(x: cx + r * CGFloat(cos(angle)), y: cy + r * CGFloat(sin(angle)))
    }

    // MARK: - Formatting

    private func formatGB(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 {
            return String(format: "%.1f GB", gb)
        } else {
            let mb = Double(bytes) / 1_048_576
            return String(format: "%.0f MB", mb)
        }
    }

    private func formatGBRound(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        let rounded = (gb / 4).rounded() * 4 // round to nearest 4GB
        if rounded == rounded.rounded() {
            return "\(Int(rounded)) GB"
        }
        return String(format: "%.0f GB", rounded)
    }
}

// MARK: - Swap Ring View

struct MemorySwapRing: View {
    let swapUsed: UInt64
    let swapFree: UInt64

    private var total: UInt64 { swapUsed + swapFree }
    private var usedFraction: Double {
        guard total > 0 else { return 0 }
        return Double(swapUsed) / Double(total)
    }

    private var usedGB: String {
        let gb = Double(swapUsed) / 1_073_741_824
        if gb >= 0.1 {
            return String(format: "%.2f GB", gb)
        }
        let mb = Double(swapUsed) / 1_048_576
        return String(format: "%.0f MB", mb)
    }

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Color(white: 0.16), lineWidth: 16)

            // Used arc
            Circle()
                .trim(from: 0, to: usedFraction)
                .stroke(
                    Color(white: 0.41),
                    style: StrokeStyle(lineWidth: 16, lineCap: .butt)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: usedFraction)

            VStack(spacing: 1) {
                Text(usedGB)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color(white: 0.88))
                Text("Swap")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(white: 0.55))
            }
        }
        .frame(width: 120, height: 120)
    }
}

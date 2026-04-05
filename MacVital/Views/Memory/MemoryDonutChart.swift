// MacVital/Views/Memory/MemoryDonutChart.swift
import SwiftUI

struct MemoryDonutChart: View {
    let apps: [AppMemoryInfo]
    let totalUsed: UInt64
    let totalRAM: UInt64

    private var slices: [(app: AppMemoryInfo, startAngle: Double, endAngle: Double)] {
        guard totalUsed > 0 else { return [] }
        var current: Double = -90 // Start from top
        return apps.map { app in
            let fraction = Double(app.memoryBytes) / Double(totalUsed)
            let sweep = fraction * 360
            let start = current
            current += sweep
            return (app, start, current)
        }
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.white.opacity(0.04), lineWidth: 32)

            // App slices
            ForEach(Array(slices.enumerated()), id: \.offset) { _, slice in
                DonutSlice(
                    startAngle: .degrees(slice.startAngle),
                    endAngle: .degrees(slice.endAngle),
                    lineWidth: 32
                )
                .fill(Color(nsColor: slice.app.color))
                .opacity(0.85)
            }

            // Inner shadow for depth
            Circle()
                .stroke(Color.black.opacity(0.3), lineWidth: 2)
                .frame(width: 136, height: 136)

            // Center info
            VStack(spacing: 2) {
                Image(systemName: "memorychip")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                Text(ByteFormatter.format(totalUsed))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("of \(ByteFormatter.format(totalRAM))")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: 200, height: 200)
    }
}

struct DonutSlice: Shape {
    var startAngle: Angle
    var endAngle: Angle
    var lineWidth: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 - lineWidth / 2
        var path = Path()
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        return path.strokedPath(.init(lineWidth: lineWidth, lineCap: .butt))
    }
}

// Swap ring — smaller, red/green
struct SwapDonutView: View {
    let swapUsed: UInt64
    let swapFree: UInt64

    private var total: UInt64 { swapUsed + swapFree }
    private var usedFraction: Double {
        guard total > 0 else { return 0 }
        return Double(swapUsed) / Double(total)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.green.opacity(0.15), lineWidth: 12)

            Circle()
                .trim(from: 0, to: usedFraction)
                .stroke(
                    Color.red,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 1) {
                Text(ByteFormatter.format(swapUsed))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.red)
                Text("Swap")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 80, height: 80)
    }
}

// MacVital/Views/Shared/GaugeRingView.swift
import SwiftUI

struct GaugeRingView: View {
    let value: Double        // 0-100
    let label: String
    let icon: String         // SF Symbol name
    var size: CGFloat = 120
    var lineWidth: CGFloat = 10

    private var color: Color {
        if value >= 90 { return .green }
        if value >= 60 { return .orange }
        return .red
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: lineWidth)

                // Value ring
                Circle()
                    .trim(from: 0, to: CGFloat(min(value, 100)) / 100)
                    .stroke(
                        AngularGradient(
                            colors: [color.opacity(0.6), color],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360 * value / 100)
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.smooth(duration: 0.6), value: value)

                VStack(spacing: 2) {
                    Image(systemName: icon)
                        .font(.system(size: size * 0.18))
                        .foregroundStyle(color)
                    Text("\(Int(value))%")
                        .font(.system(size: size * 0.22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
            }
            .frame(width: size, height: size)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

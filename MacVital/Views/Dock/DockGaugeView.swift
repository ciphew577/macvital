// MacVital/Views/Dock/DockGaugeView.swift
// Gauge needle view rendered into the dock tile — shows live CPU temperature.

import SwiftUI

struct DockGaugeView: View {
    let temperature: Double  // Celsius
    let maxTemp: Double      // Scale max (default 110)

    private let bgColor = Color(red: 0.118, green: 0.133, blue: 0.157)       // #1e2228
    private let arcBg = Color(red: 0.165, green: 0.188, blue: 0.251)         // #2a3040
    private let teal = Color(red: 0.322, green: 0.698, blue: 0.675)          // #52b2ac
    private let amber = Color(red: 0.769, green: 0.584, blue: 0.416)         // #c4956a
    private let red = Color(red: 0.835, green: 0.420, blue: 0.420)           // #d56b6b

    private var fillColor: Color {
        if temperature < 50 { return teal }
        if temperature < 75 { return amber }
        return red
    }

    /// Fraction of gauge filled (0..1)
    private var fraction: Double {
        min(max(temperature / maxTemp, 0), 1)
    }

    // Arc spans from 210 degrees to 330 degrees (bottom-open, 240 degree sweep)
    private let startAngle: Double = 210
    private let sweepAngle: Double = 240

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height * 0.44)
            let radius = size.width * 0.36
            let arcWidth = size.width * 0.06

            // --- Background arc ---
            let bgArc = Path { p in
                p.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .degrees(startAngle),
                    endAngle: .degrees(startAngle + sweepAngle),
                    clockwise: false
                )
            }
            context.stroke(bgArc, with: .color(arcBg), lineWidth: arcWidth)

            // --- Filled arc ---
            let fillEnd = startAngle + sweepAngle * fraction
            let fillArc = Path { p in
                p.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .degrees(startAngle),
                    endAngle: .degrees(fillEnd),
                    clockwise: false
                )
            }
            context.stroke(
                fillArc,
                with: .color(fillColor),
                style: StrokeStyle(lineWidth: arcWidth, lineCap: .round)
            )

            // --- Tick marks ---
            let tickCount = 24
            for i in 0...tickCount {
                let tickFraction = Double(i) / Double(tickCount)
                let angle = startAngle + sweepAngle * tickFraction
                let rad = angle * .pi / 180
                let isMajor = i % 4 == 0
                let innerR = radius + arcWidth / 2 + (isMajor ? 2 : 3)
                let outerR = radius + arcWidth / 2 + (isMajor ? 8 : 5)

                var tick = Path()
                tick.move(to: CGPoint(
                    x: center.x + innerR * cos(rad),
                    y: center.y + innerR * sin(rad)
                ))
                tick.addLine(to: CGPoint(
                    x: center.x + outerR * cos(rad),
                    y: center.y + outerR * sin(rad)
                ))
                context.stroke(
                    tick,
                    with: .color(isMajor ? Color.gray.opacity(0.5) : Color.gray.opacity(0.25)),
                    lineWidth: isMajor ? 2 : 1
                )
            }

            // --- Needle ---
            let needleAngle = (startAngle + sweepAngle * fraction) * .pi / 180
            let needleLen = radius * 0.85
            let needleEnd = CGPoint(
                x: center.x + needleLen * cos(needleAngle),
                y: center.y + needleLen * sin(needleAngle)
            )
            var needle = Path()
            needle.move(to: center)
            needle.addLine(to: needleEnd)
            context.stroke(
                needle,
                with: .color(.white.opacity(0.9)),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
            )

            // --- Center dot ---
            let dotR: CGFloat = 4
            let dotRect = CGRect(
                x: center.x - dotR,
                y: center.y - dotR,
                width: dotR * 2,
                height: dotR * 2
            )
            context.fill(Path(ellipseIn: dotRect), with: .color(.white.opacity(0.8)))

            // --- Temperature text ---
            let tempStr = "\(Int(temperature))\u{00B0}C"
            let tempY = center.y + radius * 0.55
            context.draw(
                Text(tempStr)
                    .font(.system(size: size.width * 0.16, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9)),
                at: CGPoint(x: center.x, y: tempY),
                anchor: .center
            )

            // --- Label ---
            context.draw(
                Text("CPU")
                    .font(.system(size: size.width * 0.07, weight: .medium))
                    .foregroundColor(.gray),
                at: CGPoint(x: center.x, y: tempY + size.width * 0.12),
                anchor: .center
            )
        }
        .background(bgColor)
    }
}

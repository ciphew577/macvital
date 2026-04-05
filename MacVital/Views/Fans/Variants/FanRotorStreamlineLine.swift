// MacVital/Views/Fans/Variants/FanRotorStreamlineLine.swift
import SwiftUI

struct FanRotorStreamlineLine: View {
    let angle: Double
    let size: CGFloat
    let sage: Color

    var body: some View {
        let center = CGPoint(x: size/2, y: size/2)
        let scale: CGFloat = size / 220.0
        Canvas { ctx, _ in
            for i in 0..<5 {
                let bladeAngle = (Double(i) * 72.0 + angle) * .pi / 180
                ctx.drawLayer { inner in
                    inner.translateBy(x: center.x, y: center.y)
                    inner.rotate(by: .radians(bladeAngle))
                    inner.scaleBy(x: scale, y: scale)
                    let blade = Path { p in
                        p.move(to: CGPoint(x: 0, y: -4))
                        p.addCurve(to: CGPoint(x: 64, y: -22),
                                   control1: CGPoint(x: 18, y: -12),
                                   control2: CGPoint(x: 38, y: -22))
                        p.addLine(to: CGPoint(x: 70, y: -10))
                        p.addLine(to: CGPoint(x: 60, y: 2))
                        p.addCurve(to: CGPoint(x: 4, y: 2),
                                   control1: CGPoint(x: 40, y: 8),
                                   control2: CGPoint(x: 20, y: 6))
                        p.closeSubpath()
                    }
                    inner.stroke(blade,
                                 with: .color(sage.opacity(0.92)),
                                 style: StrokeStyle(lineWidth: 1.25, lineCap: .round, lineJoin: .round))
                    let chord = Path { p in
                        p.move(to: CGPoint(x: 20, y: -10))
                        p.addLine(to: CGPoint(x: 56, y: -12))
                    }
                    inner.stroke(chord,
                                 with: .color(sage.opacity(0.30)),
                                 style: StrokeStyle(lineWidth: 0.6, lineCap: .round))
                }
            }
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
    }
}

// MacVital/Views/Fans/Variants/FanRotorCustomCanvas.swift
import SwiftUI

struct FanRotorCustomCanvas: View {
    let angle: Double
    let size: CGFloat
    let sage: Color

    var body: some View {
        let center = CGPoint(x: size/2, y: size/2)
        let scale: CGFloat = size / 264.0
        Canvas { ctx, _ in
            for i in 0..<5 {
                let bladeAngle = (Double(i) * 72.0 + angle) * .pi / 180
                ctx.drawLayer { inner in
                    inner.translateBy(x: center.x, y: center.y)
                    inner.rotate(by: .radians(bladeAngle))
                    inner.scaleBy(x: scale, y: scale)
                    let wedge = Path { p in
                        p.move(to: CGPoint(x: 0, y: -8))
                        p.addCurve(to: CGPoint(x: 82, y: -40),
                                   control1: CGPoint(x: 22, y: -16),
                                   control2: CGPoint(x: 50, y: -34))
                        p.addCurve(to: CGPoint(x: 76, y: 10),
                                   control1: CGPoint(x: 90, y: -28),
                                   control2: CGPoint(x: 92, y: -10))
                        p.addCurve(to: CGPoint(x: 0, y: 10),
                                   control1: CGPoint(x: 54, y: 24),
                                   control2: CGPoint(x: 28, y: 20))
                        p.closeSubpath()
                    }
                    inner.fill(wedge, with: .color(sage.opacity(0.74)))
                    inner.stroke(wedge,
                                 with: .color(sage.opacity(0.22)),
                                 style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                    let leading = Path { p in
                        p.move(to: CGPoint(x: 0, y: -8))
                        p.addCurve(to: CGPoint(x: 82, y: -40),
                                   control1: CGPoint(x: 22, y: -16),
                                   control2: CGPoint(x: 50, y: -34))
                    }
                    inner.stroke(leading,
                                 with: .color(FanHeroPalette.sageHi.opacity(0.85)),
                                 style: StrokeStyle(lineWidth: 0.7, lineCap: .round))
                    let chord = Path { p in
                        p.move(to: CGPoint(x: 14, y: -8))
                        p.addCurve(to: CGPoint(x: 70, y: -18),
                                   control1: CGPoint(x: 36, y: -18),
                                   control2: CGPoint(x: 58, y: -22))
                    }
                    inner.stroke(chord,
                                 with: .color(FanHeroPalette.bg.opacity(0.30)),
                                 style: StrokeStyle(lineWidth: 0.6, lineCap: .round))
                }
            }
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
    }
}

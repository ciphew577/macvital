// MacVital/Views/Fans/Variants/FanRotorNZXTProduct.swift
import SwiftUI

struct FanRotorNZXTProduct: View {
    let angle: Double
    let size: CGFloat
    let sage: Color

    var body: some View {
        let center = CGPoint(x: size/2, y: size/2)
        let scale: CGFloat = size / 220.0
        Canvas { ctx, _ in
            for i in 0..<7 {
                let bladeAngle = (Double(i) * (360.0 / 7.0) + angle) * .pi / 180
                ctx.drawLayer { inner in
                    inner.translateBy(x: center.x, y: center.y)
                    inner.rotate(by: .radians(bladeAngle))
                    inner.scaleBy(x: scale, y: scale)
                    let body = Path { p in
                        p.move(to: CGPoint(x: 0, y: -10))
                        p.addCurve(to: CGPoint(x: 74, y: -28),
                                   control1: CGPoint(x: 26, y: -20),
                                   control2: CGPoint(x: 50, y: -30))
                        p.addCurve(to: CGPoint(x: 70, y: 10),
                                   control1: CGPoint(x: 80, y: -18),
                                   control2: CGPoint(x: 80, y: -2))
                        p.addCurve(to: CGPoint(x: 18, y: 10),
                                   control1: CGPoint(x: 56, y: 20),
                                   control2: CGPoint(x: 36, y: 16))
                        p.addCurve(to: CGPoint(x: 0, y: -10),
                                   control1: CGPoint(x: 8, y: 2),
                                   control2: CGPoint(x: 2, y: -4))
                        p.closeSubpath()
                    }
                    inner.fill(body, with: .color(sage.opacity(0.78)))
                    let edge = Path { p in
                        p.move(to: CGPoint(x: 0, y: -10))
                        p.addCurve(to: CGPoint(x: 74, y: -28),
                                   control1: CGPoint(x: 26, y: -20),
                                   control2: CGPoint(x: 50, y: -30))
                    }
                    inner.stroke(edge,
                                 with: .color(Color.white.opacity(0.18)),
                                 style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
                }
            }
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
    }
}

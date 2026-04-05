// MacVital/Views/Fans/Variants/FanRotorIconscoutFlat.swift
import SwiftUI

struct FanRotorIconscoutFlat: View {
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
                    let body = Path { p in
                        p.move(to: CGPoint(x: 0, y: 0))
                        p.addLine(to: CGPoint(x: 8, y: -6))
                        p.addQuadCurve(to: CGPoint(x: 60, y: -28), control: CGPoint(x: 30, y: -22))
                        p.addQuadCurve(to: CGPoint(x: 76, y: -4), control: CGPoint(x: 78, y: -22))
                        p.addQuadCurve(to: CGPoint(x: 42, y: 10), control: CGPoint(x: 66, y: 10))
                        p.addQuadCurve(to: CGPoint(x: 6, y: 4), control: CGPoint(x: 18, y: 8))
                        p.closeSubpath()
                    }
                    inner.fill(body, with: .color(sage.opacity(0.82)))
                    let highlight = Path { p in
                        p.move(to: CGPoint(x: 8, y: -6))
                        p.addQuadCurve(to: CGPoint(x: 60, y: -28), control: CGPoint(x: 30, y: -22))
                    }
                    inner.stroke(highlight,
                                 with: .color(Color.white.opacity(0.20)),
                                 style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
                }
            }
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
    }
}

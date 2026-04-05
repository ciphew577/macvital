// MacVital/Views/Fans/Variants/FanRotorAppleHIGFlat.swift
import SwiftUI

struct FanRotorAppleHIGFlat: View {
    let angle: Double
    let size: CGFloat

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
                    let path = Path { p in
                        p.move(to: CGPoint(x: 0, y: -6))
                        p.addQuadCurve(to: CGPoint(x: 52, y: -28), control: CGPoint(x: 24, y: -16))
                        p.addQuadCurve(to: CGPoint(x: 70, y: -2), control: CGPoint(x: 70, y: -22))
                        p.addQuadCurve(to: CGPoint(x: 36, y: 12), control: CGPoint(x: 60, y: 14))
                        p.addQuadCurve(to: CGPoint(x: 0, y: -6), control: CGPoint(x: 14, y: 8))
                        p.closeSubpath()
                    }
                    inner.stroke(
                        path,
                        with: .color(FanHeroPalette.text1.opacity(0.88)),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                    )
                }
            }
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
    }
}

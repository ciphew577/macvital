import SwiftUI

struct PowerFlowRadialSunburst: View {
    let model: PowerFlowModel

    private let innerR: CGFloat = 36
    private let midRInner: CGFloat = 60
    private let midROuter: CGFloat = 110
    private let outerRInner: CGFloat = 116
    private let outerROuter: CGFloat = 156

    var body: some View {
        GeometryReader { geo in
            let cx = geo.size.width / 2
            let cy = geo.size.height / 2
            let center = CGPoint(x: cx, y: cy)
            let dests = model.destinations.filter { $0.watts > 0.05 }
            let destTotal = max(dests.reduce(0) { $0 + $1.watts }, 0.0001)
            let socComps = model.socComponents.filter { $0.watts > 0.05 }
            let socSum = max(socComps.reduce(0) { $0 + $1.watts }, 0.0001)
            let socPresent = dests.contains(where: { $0.id == "soc" })
            let socStart = startAngle(forID: "soc", in: dests, total: destTotal)
            let socSpan = angularSpan(value: model.socTotal, total: destTotal)

            ZStack {
                Circle()
                    .fill(PowerFlowPalette.wall.opacity(0.85))
                    .frame(width: innerR * 2, height: innerR * 2)
                    .position(center)
                VStack(spacing: 1) {
                    Text("WALL")
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(Color.black.opacity(0.55))
                    Text(PowerFlowFormat.watts(model.wallTotal))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.black.opacity(0.85))
                        .monospacedDigit()
                }
                .position(center)

                ForEach(Array(dests.enumerated()), id: \.element.id) { _, d in
                    let span = angularSpan(value: d.watts, total: destTotal)
                    let start = startAngle(forID: d.id, in: dests, total: destTotal)
                    arcShape(center: center, innerR: midRInner, outerR: midROuter, start: start, span: span)
                        .fill(d.color.opacity(0.85))
                    arcLabel(center: center, radius: (midRInner + midROuter) / 2, start: start, span: span, label: d.label, watts: d.watts, signed: d.isSigned, charging: model.batteryIsCharging)
                }

                if socPresent {
                    ForEach(socComps) { c in
                        let subSpan = socSpan * CGFloat(c.watts / socSum)
                        let subStart = socStart + cumulativeOffset(forID: c.id, in: socComps, totalSpan: socSpan, total: socSum)
                        arcShape(center: center, innerR: outerRInner, outerR: outerROuter, start: subStart, span: subSpan)
                            .fill(c.color.opacity(0.80))
                        arcLabel(center: center, radius: outerROuter + 14, start: subStart, span: subSpan, label: c.label, watts: c.watts, signed: false, charging: false, small: true)
                    }
                }
            }
        }
        .frame(height: 380)
    }

    private func arcShape(center: CGPoint, innerR: CGFloat, outerR: CGFloat, start: Angle, span: Angle) -> Path {
        Path { p in
            let end = start + span
            p.addArc(center: center, radius: outerR, startAngle: start, endAngle: end, clockwise: false)
            p.addLine(to: CGPoint(x: center.x + innerR * cos(end.radians), y: center.y + innerR * sin(end.radians)))
            p.addArc(center: center, radius: innerR, startAngle: end, endAngle: start, clockwise: true)
            p.closeSubpath()
        }
    }

    private func arcLabel(center: CGPoint, radius: CGFloat, start: Angle, span: Angle, label: String, watts: Double, signed: Bool, charging: Bool, small: Bool = false) -> some View {
        let mid = start + span / 2
        let x = center.x + radius * cos(mid.radians)
        let y = center.y + radius * sin(mid.radians)
        let displayWatts = signed ? (charging ? -watts : watts) : watts
        return VStack(spacing: 1) {
            Text(label)
                .font(.system(size: small ? 8.5 : 9.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(small ? PowerFlowPalette.text2 : Color.black.opacity(0.70))
            Text(PowerFlowFormat.watts(displayWatts, signed: signed))
                .font(.system(size: small ? 8 : 9, weight: .bold, design: .monospaced))
                .foregroundStyle(small ? PowerFlowPalette.text3 : Color.black.opacity(0.85))
                .monospacedDigit()
        }
        .position(x: x, y: y)
    }

    private func startAngle(forID id: String, in items: [PowerFlowDestination], total: Double) -> Angle {
        var acc: Double = -.pi / 2
        for d in items {
            if d.id == id { return Angle(radians: acc) }
            acc += (d.watts / total) * 2 * .pi
        }
        return Angle(radians: acc)
    }

    private func angularSpan(value: Double, total: Double) -> Angle {
        Angle(radians: (value / max(total, 0.0001)) * 2 * .pi)
    }

    private func cumulativeOffset(forID id: String, in items: [PowerSoCComponent], totalSpan: Angle, total: Double) -> Angle {
        var acc: Double = 0
        for c in items {
            if c.id == id { return Angle(radians: acc) }
            acc += (c.watts / total) * totalSpan.radians
        }
        return Angle(radians: acc)
    }
}

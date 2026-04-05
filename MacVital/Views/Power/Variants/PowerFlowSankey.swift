import SwiftUI

struct PowerFlowSankey: View {
    let model: PowerFlowModel

    private let leftFraction: CGFloat = 0.18
    private let midFraction: CGFloat = 0.40
    private let socFraction: CGFloat = 0.62
    private let rightFraction: CGFloat = 0.92
    private let nodeWidth: CGFloat = 10
    private let gap: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let xWall = w * leftFraction
            let xMid = w * midFraction
            let xSoC = w * socFraction
            let xRight = w * rightFraction
            let wallTotal = max(model.wallTotal, 0.0001)
            let scale: CGFloat = (h - 24) / CGFloat(wallTotal)
            let dests = model.destinations
            let socComps = model.socComponents.filter { $0.watts > 0.05 }
            let socTotalForLayout = max(socComps.reduce(0) { $0 + $1.watts }, 0.0001)

            let destSegments = stackSegments(items: dests.map { ($0.id, $0.watts) }, scale: scale, top: 12, gap: gap)
            let socSubSegments = stackSegments(items: socComps.map { ($0.id, $0.watts) }, scale: (CGFloat(model.socTotal) * scale) / CGFloat(socTotalForLayout) * 1.0, top: destSegments["soc"]?.top ?? 12, gap: 2)

            ZStack {
                ForEach(dests) { d in
                    if let seg = destSegments[d.id], d.watts > 0.05 {
                        sankeyRibbon(
                            x1: xWall + nodeWidth,
                            y1Top: 12 + scaledOffset(forItem: d.id, items: dests.map { ($0.id, $0.watts) }, scale: scale, gap: gap),
                            y1Bot: 12 + scaledOffset(forItem: d.id, items: dests.map { ($0.id, $0.watts) }, scale: scale, gap: gap) + CGFloat(d.watts) * scale,
                            x2: xMid,
                            y2Top: seg.top,
                            y2Bot: seg.bottom,
                            color: d.color
                        )
                    }
                }
                if model.socTotal > 0.05, destSegments["soc"] != nil {
                    ForEach(socComps) { c in
                        if let sub = socSubSegments[c.id] {
                            sankeyRibbon(
                                x1: xSoC,
                                y1Top: sub.top,
                                y1Bot: sub.bottom,
                                x2: xRight - nodeWidth,
                                y2Top: sub.top,
                                y2Bot: sub.bottom,
                                color: c.color
                            )
                        }
                    }
                }

                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .fill(PowerFlowPalette.wall)
                        .frame(width: nodeWidth, height: max(h - 24, 1))
                        .position(x: xWall + nodeWidth / 2, y: h / 2)
                    Text("WALL")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(PowerFlowPalette.text2)
                        .rotationEffect(.degrees(-90))
                        .position(x: xWall - 14, y: h / 2)
                    Text(PowerFlowFormat.watts(model.wallTotal))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(PowerFlowPalette.text1)
                        .position(x: xWall + nodeWidth / 2, y: 6)
                }

                ForEach(dests) { d in
                    if let seg = destSegments[d.id], d.watts > 0.05 {
                        Rectangle()
                            .fill(d.color)
                            .frame(width: nodeWidth, height: max(seg.bottom - seg.top, 1))
                            .position(x: xMid + nodeWidth / 2, y: (seg.top + seg.bottom) / 2)
                        Text(d.label)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(PowerFlowPalette.text1)
                            .monospacedDigit()
                            .position(x: xMid + nodeWidth + 6 + 56, y: (seg.top + seg.bottom) / 2 - 6)
                            .frame(width: 120, alignment: .leading)
                        Text(PowerFlowFormat.watts(d.isSigned ? (model.batteryIsCharging ? -d.watts : d.watts) : d.watts, signed: d.isSigned))
                            .font(.system(size: 9.5, design: .monospaced))
                            .foregroundStyle(PowerFlowPalette.text2)
                            .monospacedDigit()
                            .position(x: xMid + nodeWidth + 6 + 56, y: (seg.top + seg.bottom) / 2 + 6)
                            .frame(width: 120, alignment: .leading)
                    }
                }

                if model.socTotal > 0.05, let socSeg = destSegments["soc"] {
                    Rectangle()
                        .fill(PowerFlowPalette.soc.opacity(0.65))
                        .frame(width: nodeWidth, height: max(socSeg.bottom - socSeg.top, 1))
                        .position(x: xSoC + nodeWidth / 2, y: (socSeg.top + socSeg.bottom) / 2)

                    ForEach(socComps) { c in
                        if let sub = socSubSegments[c.id] {
                            let yMid = (sub.top + sub.bottom) / 2
                            HStack(spacing: 6) {
                                Text(c.label)
                                    .font(.system(size: 9.5, design: .monospaced))
                                    .foregroundStyle(PowerFlowPalette.text2)
                                Text(PowerFlowFormat.watts(c.watts))
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(PowerFlowPalette.text3)
                                    .monospacedDigit()
                            }
                            .position(x: xRight + 38, y: yMid)
                        }
                    }
                }
            }
        }
        .frame(height: 360)
    }

    private func sankeyRibbon(x1: CGFloat, y1Top: CGFloat, y1Bot: CGFloat, x2: CGFloat, y2Top: CGFloat, y2Bot: CGFloat, color: Color) -> some View {
        let cx = (x1 + x2) / 2
        let path = Path { p in
            p.move(to: CGPoint(x: x1, y: y1Top))
            p.addCurve(to: CGPoint(x: x2, y: y2Top), control1: CGPoint(x: cx, y: y1Top), control2: CGPoint(x: cx, y: y2Top))
            p.addLine(to: CGPoint(x: x2, y: y2Bot))
            p.addCurve(to: CGPoint(x: x1, y: y1Bot), control1: CGPoint(x: cx, y: y2Bot), control2: CGPoint(x: cx, y: y1Bot))
            p.closeSubpath()
        }
        return path.fill(color.opacity(0.45))
    }

    private struct Segment { let top: CGFloat; let bottom: CGFloat }

    private func stackSegments(items: [(String, Double)], scale: CGFloat, top: CGFloat, gap: CGFloat) -> [String: Segment] {
        var result: [String: Segment] = [:]
        var y = top
        for (id, w) in items where w > 0.05 {
            let h = CGFloat(w) * scale
            result[id] = Segment(top: y, bottom: y + h)
            y += h + gap
        }
        return result
    }

    private func scaledOffset(forItem id: String, items: [(String, Double)], scale: CGFloat, gap: CGFloat) -> CGFloat {
        var y: CGFloat = 0
        for (k, w) in items where w > 0.05 {
            if k == id { return y }
            y += CGFloat(w) * scale + gap
        }
        return y
    }
}

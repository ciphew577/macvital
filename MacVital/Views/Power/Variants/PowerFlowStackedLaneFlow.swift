import SwiftUI

struct PowerFlowStackedLaneFlow: View {
    let model: PowerFlowModel

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let dests = model.destinations.filter { $0.watts > 0.05 }
            let total = max(dests.reduce(0) { $0 + $1.watts }, 0.0001)
            let leftWidth: CGFloat = 92
            let rightWidth: CGFloat = 110
            let laneArea = h - 24
            let scale: CGFloat = laneArea / CGFloat(total)
            let socComps = model.socComponents.filter { $0.watts > 0.05 }
            let socSum = max(socComps.reduce(0) { $0 + $1.watts }, 0.0001)
            let socY = laneTop(forID: "soc", in: dests, scale: scale, gap: 4) + 12
            let socHeight = CGFloat(model.socTotal) * scale

            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(PowerFlowPalette.wall.opacity(0.85))
                    .frame(width: leftWidth, height: max(h - 24, 1))
                    .offset(x: 0, y: 12)
                VStack(alignment: .leading, spacing: 4) {
                    Text("WALL").font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(1.0).foregroundStyle(Color.black.opacity(0.55))
                    Text(PowerFlowFormat.watts(model.wallTotal)).font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundStyle(Color.black.opacity(0.85)).monospacedDigit()
                }
                .padding(8)
                .offset(x: 0, y: 12)

                ForEach(dests) { d in
                    let yTop = laneTop(forID: d.id, in: dests, scale: scale, gap: 4) + 12
                    let lh = CGFloat(d.watts) * scale
                    let laneW = max(w - leftWidth - rightWidth, 1)
                    if d.id == "soc" {
                        let socMid = socY + socHeight / 2
                        Rectangle()
                            .fill(d.color.opacity(0.20))
                            .frame(width: laneW, height: max(lh, 1))
                            .offset(x: leftWidth, y: yTop)
                        Text(d.label.uppercased())
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .tracking(0.8)
                            .foregroundStyle(PowerFlowPalette.text2)
                            .position(x: leftWidth + 40, y: socMid)
                        ForEach(socComps) { c in
                            socSubLane(c: c, socSum: socSum, socHeight: socHeight, w: w, leftWidth: leftWidth, rightWidth: rightWidth, yTop: yTop)
                        }
                    } else {
                        Rectangle()
                            .fill(d.color.opacity(0.85))
                            .frame(width: laneW, height: max(lh, 1))
                            .offset(x: leftWidth, y: yTop)
                        let displayWatts = d.isSigned ? (model.batteryIsCharging ? -d.watts : d.watts) : d.watts
                        HStack {
                            Text(d.label.uppercased())
                                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                .tracking(0.8)
                                .foregroundStyle(Color.black.opacity(0.55))
                            Spacer()
                            Text(PowerFlowFormat.watts(displayWatts, signed: d.isSigned))
                                .font(.system(size: lh > 28 ? 12 : 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.black.opacity(0.85))
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 8)
                        .frame(width: laneW, height: max(lh, 1))
                        .offset(x: leftWidth, y: yTop)
                    }
                }
            }
        }
        .frame(height: 360)
    }

    private func laneTop(forID id: String, in items: [PowerFlowDestination], scale: CGFloat, gap: CGFloat) -> CGFloat {
        var y: CGFloat = 0
        for d in items where d.watts > 0.05 {
            if d.id == id { return y }
            y += CGFloat(d.watts) * scale + gap
        }
        return y
    }

    private func cumulativeSocOffset(forID id: String, in items: [PowerSoCComponent], total: Double) -> CGFloat {
        var acc: CGFloat = 0
        for c in items {
            if c.id == id { return acc }
            acc += CGFloat(c.watts / total)
        }
        return acc
    }

    @ViewBuilder
    private func socSubLane(c: PowerSoCComponent, socSum: Double, socHeight: CGFloat, w: CGFloat, leftWidth: CGFloat, rightWidth: CGFloat, yTop: CGFloat) -> some View {
        if c.watts > 0.05 {
            let subOffset = cumulativeSocOffset(forID: c.id, in: model.socComponents, total: socSum) * socHeight
            let subH: CGFloat = CGFloat(c.watts / socSum) * socHeight
            let blockX: CGFloat = leftWidth + 80
            let blockW: CGFloat = max(w - leftWidth - rightWidth - 80, 1)
            let labelW: CGFloat = max(w - leftWidth - rightWidth - 88, 1)
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(c.color.opacity(0.85))
                    .frame(width: blockW, height: max(subH, 1))
                HStack(spacing: 4) {
                    Text(c.label)
                        .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.black.opacity(0.65))
                    Spacer()
                    Text(PowerFlowFormat.watts(c.watts))
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.black.opacity(0.85))
                        .monospacedDigit()
                }
                .frame(width: labelW, height: max(subH, 1), alignment: .leading)
                .padding(.horizontal, 6)
            }
            .offset(x: blockX, y: yTop + subOffset)
        }
    }
}

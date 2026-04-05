// V4 polar chart, 7-axis radar showing current polygon plus 24h baseline ghost; throttle ring at 85 °C.
import SwiftUI

struct ThermalPolarChart: View {
    let lanes: [ThermalLane]
    let thermalState: ThermalState
    let speedLimit: Int

    private var radarLanes: [ThermalLane] { lanes.filter { $0.kind != .chassis } }
    private let yLow: Double = 30
    private let yHigh: Double = 100

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ThermalTopStrip(lanes: lanes, thermalState: thermalState, speedLimit: speedLimit)

            HStack(alignment: .top, spacing: 16) {
                polarStage
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                sidePanel
                    .frame(width: 320)
            }
        }
        .padding(20)
        .background(ThermalPalette.canvasBg)
    }

    private var polarStage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(ThermalPalette.stageBg)

            GeometryReader { geo in
                let size = min(geo.size.width, geo.size.height) - 24
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                let outerR = size / 2

                ZStack {
                    rings(center: center, outerR: outerR)
                    axes(center: center, outerR: outerR)
                    labels(center: center, outerR: outerR)
                    polygon(values: radarLanes.map(\.baseline24h), center: center, outerR: outerR, fill: Color.white.opacity(0.06), stroke: Color.white.opacity(0.30), dash: true)
                    polygon(values: radarLanes.map(\.current), center: center, outerR: outerR, fill: ThermalPalette.hot.opacity(0.20), stroke: ThermalPalette.hot, dash: false)
                    vertices(center: center, outerR: outerR)
                }
            }
        }
    }

    private func rings(center: CGPoint, outerR: CGFloat) -> some View {
        ZStack {
            ForEach([40.0, 55.0, 70.0, 85.0, 100.0], id: \.self) { t in
                let r = outerR * CGFloat((t - yLow) / (yHigh - yLow))
                Circle()
                    .stroke(t == 85 ? ThermalPalette.ember.opacity(0.45) : Color.white.opacity(0.06),
                            style: StrokeStyle(lineWidth: 1, dash: t == 85 ? [4, 3] : []))
                    .frame(width: r * 2, height: r * 2)
                    .position(center)
            }
        }
    }

    private func axes(center: CGPoint, outerR: CGFloat) -> some View {
        ZStack {
            ForEach(0..<radarLanes.count, id: \.self) { i in
                Path { p in
                    let pt = vertex(index: i, value: yHigh, center: center, outerR: outerR)
                    p.move(to: center)
                    p.addLine(to: pt)
                }
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
            }
        }
    }

    private func labels(center: CGPoint, outerR: CGFloat) -> some View {
        ZStack {
            ForEach(Array(radarLanes.enumerated()), id: \.element.id) { i, lane in
                let pt = vertex(index: i, value: yHigh + 8, center: center, outerR: outerR)
                Text(lane.kind.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ThermalPalette.text2)
                    .position(pt)
            }
        }
    }

    private func polygon(values: [Double], center: CGPoint, outerR: CGFloat, fill: Color, stroke: Color, dash: Bool) -> some View {
        Path { p in
            for (i, v) in values.enumerated() {
                let pt = vertex(index: i, value: v, center: center, outerR: outerR)
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()
        }
        .fill(fill)
        .overlay(
            Path { p in
                for (i, v) in values.enumerated() {
                    let pt = vertex(index: i, value: v, center: center, outerR: outerR)
                    if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                }
                p.closeSubpath()
            }
            .stroke(stroke, style: StrokeStyle(lineWidth: dash ? 1 : 2, dash: dash ? [3, 2] : []))
        )
    }

    private func vertices(center: CGPoint, outerR: CGFloat) -> some View {
        ZStack {
            ForEach(Array(radarLanes.enumerated()), id: \.element.id) { i, lane in
                let pt = vertex(index: i, value: lane.current, center: center, outerR: outerR)
                Circle()
                    .fill(lane.color)
                    .frame(width: 8, height: 8)
                    .overlay(Circle().stroke(ThermalPalette.canvasBg, lineWidth: 1.5))
                    .position(pt)
            }
        }
    }

    private func vertex(index: Int, value: Double, center: CGPoint, outerR: CGFloat) -> CGPoint {
        let n = max(radarLanes.count, 1)
        let angle = (Double(index) / Double(n)) * 2 * .pi - .pi / 2
        let frac = max(0, min(1, (value - yLow) / (yHigh - yLow)))
        let r = outerR * CGFloat(frac)
        return CGPoint(x: center.x + r * CGFloat(cos(angle)), y: center.y + r * CGFloat(sin(angle)))
    }

    private var sidePanel: some View {
        VStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 8) {
                Text("LEGEND")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(ThermalPalette.text3)
                legendRow(color: ThermalPalette.hot, text: "Current", solid: true)
                legendRow(color: ThermalPalette.text2.opacity(0.6), text: "24 h baseline ghost", solid: false)
                legendRow(color: ThermalPalette.ember, text: "Throttle ring 85 °C", solid: false)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(ThermalPalette.cardBg))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(ThermalPalette.hairline, lineWidth: 1))

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("LANE").frame(maxWidth: .infinity, alignment: .leading)
                    Text("CUR").frame(width: 50, alignment: .trailing)
                    Text("BASE").frame(width: 50, alignment: .trailing)
                    Text("ΔΔ").frame(width: 50, alignment: .trailing)
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(ThermalPalette.text3)
                .padding(.bottom, 6)

                ForEach(Array(lanes.enumerated()), id: \.element.id) { i, l in
                    HStack {
                        Text(l.kind.name)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(ThermalPalette.text2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(String(format: "%.0f", l.current))
                            .font(.system(size: 11.5, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(l.color)
                            .frame(width: 50, alignment: .trailing)
                        Text(String(format: "%.1f", l.baseline24h))
                            .font(.system(size: 11.5))
                            .monospacedDigit()
                            .foregroundStyle(ThermalPalette.text3)
                            .frame(width: 50, alignment: .trailing)
                        Text(thermalDeltaString(l.delta))
                            .font(.system(size: 11.5, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(l.delta >= 0 ? ThermalPalette.hot : ThermalPalette.cool)
                            .frame(width: 50, alignment: .trailing)
                    }
                    .padding(.vertical, 4)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(ThermalPalette.hairline).frame(height: 1)
                            .opacity(i < lanes.count - 1 ? 1 : 0)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(ThermalPalette.cardBg))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(ThermalPalette.hairline, lineWidth: 1))
        }
    }

    private func legendRow(color: Color, text: String, solid: Bool) -> some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(color)
                .frame(width: 28, height: 4)
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .opacity(solid ? 1 : 0.6)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(ThermalPalette.text2)
            Spacer()
        }
    }
}

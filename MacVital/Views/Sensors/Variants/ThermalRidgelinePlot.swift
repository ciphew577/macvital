// V3 ridgeline plot, 7 stacked sparklines, time scrolls right to left.
// Per-row ridgeFill auto-rescales lo..hi, so a single global threshold
// overlay would be misleading. Lane colour already encodes band state.
import SwiftUI

struct ThermalRidgelinePlot: View {
    let lanes: [ThermalLane]
    let thermalState: ThermalState
    let speedLimit: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ThermalTopStrip(lanes: lanes, thermalState: thermalState, speedLimit: speedLimit)

            stage
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            axis
                .padding(.leading, 100)
        }
        .padding(20)
        .background(ThermalPalette.canvasBg)
    }

    private var stage: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 10).fill(ThermalPalette.stageBg)

            VStack(spacing: 0) {
                ForEach(Array(lanes.enumerated()), id: \.element.id) { idx, lane in
                    ridgeRow(lane: lane, isLast: idx == lanes.count - 1)
                }
            }
            .padding(.leading, 100)
            .padding(.trailing, 18)
            .padding(.vertical, 14)
        }
    }

    private func ridgeRow(lane: ThermalLane, isLast: Bool) -> some View {
        HStack(spacing: 0) {
            ZStack {
                ThermalSparkline(data: lane.history, color: lane.color, lineWidth: 1.4)
                ridgeFill(data: lane.history, color: lane.color)
            }
            .frame(maxWidth: .infinity)

            Text(thermalTempString(lane.current))
                .font(.system(size: 13, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(lane.color)
                .padding(.leading, 6)
        }
        .frame(height: 50)
        .overlay(alignment: .leading) {
            VStack(alignment: .trailing, spacing: 1) {
                Text(lane.kind.name)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(ThermalPalette.text2)
                Text(lane.kind.subLabel.uppercased())
                    .font(.system(size: 9))
                    .foregroundStyle(ThermalPalette.text4)
            }
            .frame(width: 84, alignment: .trailing)
            .offset(x: -90)
        }
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(ThermalPalette.text4.opacity(0.15))
                    .frame(height: 1)
                    .opacity(0.5)
            }
        }
    }

    private func ridgeFill(data: [Double], color: Color) -> some View {
        GeometryReader { geo in
            if data.count >= 2 {
                let lo = data.min() ?? 0
                let hi = data.max() ?? 1
                let span = max(hi - lo, 1)
                Path { p in
                    p.move(to: CGPoint(x: 0, y: geo.size.height))
                    for (i, v) in data.enumerated() {
                        let x = geo.size.width * CGFloat(i) / CGFloat(data.count - 1)
                        let y = geo.size.height * (1 - CGFloat((v - lo) / span))
                        p.addLine(to: CGPoint(x: x, y: y))
                    }
                    p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                    p.closeSubpath()
                }
                .fill(color.opacity(0.10))
            }
        }
    }

    private var axis: some View {
        HStack {
            Text("60 S AGO").font(.system(size: 9.5)).foregroundStyle(ThermalPalette.text4)
            Spacer()
            Text("30 S").font(.system(size: 9.5)).foregroundStyle(ThermalPalette.text4)
            Spacer()
            Text("NOW").font(.system(size: 9.5)).foregroundStyle(ThermalPalette.text4)
        }
        .padding(.trailing, 60)
    }
}

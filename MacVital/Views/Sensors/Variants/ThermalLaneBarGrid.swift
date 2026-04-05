// V2 lane bar grid, seven horizontal rows: name, sparkline, current, max 24 h, 4-step band gauge.
import SwiftUI

struct ThermalLaneBarGrid: View {
    let lanes: [ThermalLane]
    let thermalState: ThermalState
    let speedLimit: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ThermalTopStrip(lanes: lanes, thermalState: thermalState, speedLimit: speedLimit)

            VStack(spacing: 6) {
                header
                ForEach(lanes) { lane in
                    laneRow(lane)
                }
            }
        }
        .padding(20)
        .background(ThermalPalette.canvasBg)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Text("LANE")
                .frame(width: 92, alignment: .leading)
            Text("60 S HISTORY")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("CURRENT").frame(width: 64, alignment: .trailing)
            Text("MAX 24 H").frame(width: 64, alignment: .trailing)
            Text("IDLE · LIGHT · HEAVY · THROTTLE")
                .frame(width: 220, alignment: .leading)
        }
        .font(.system(size: 9.5, weight: .bold))
        .foregroundStyle(ThermalPalette.text4)
        .padding(.horizontal, 14)
        .padding(.bottom, 4)
    }

    private func laneRow(_ lane: ThermalLane) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(lane.kind.name)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(ThermalPalette.text1)
                Text(lane.kind.subLabel.uppercased())
                    .font(.system(size: 9.5))
                    .foregroundStyle(ThermalPalette.text3)
            }
            .frame(width: 92, alignment: .leading)

            ThermalSparkline(data: lane.history, color: lane.color)
                .frame(height: 28)
                .frame(maxWidth: .infinity)

            Text(thermalTempString(lane.current))
                .font(.system(size: 17, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(lane.color)
                .frame(width: 64, alignment: .trailing)

            VStack(alignment: .trailing, spacing: 1) {
                Text("PEAK")
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(ThermalPalette.text4)
                Text(String(format: "%.1f", lane.peak24h))
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(ThermalPalette.text3)
            }
            .frame(width: 64, alignment: .trailing)

            ThermalBandGauge(band: lane.band)
                .frame(width: 220, height: 24)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 7).fill(ThermalPalette.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(ThermalPalette.hairline, lineWidth: 1))
    }
}

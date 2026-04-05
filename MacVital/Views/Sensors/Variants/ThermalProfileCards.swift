// V5 thermal profile cards, 4-by-2 grid of dense per-lane cards plus throttle summary tile.
import SwiftUI

struct ThermalProfileCards: View {
    let lanes: [ThermalLane]
    let thermalState: ThermalState
    let speedLimit: Int

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private var hottest: ThermalLane? {
        lanes.max(by: { $0.current < $1.current })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ThermalTopStrip(lanes: lanes, thermalState: thermalState, speedLimit: speedLimit)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(lanes) { lane in
                    laneCard(lane)
                }
                summaryCard
            }
            .frame(maxHeight: .infinity)
        }
        .padding(20)
        .background(ThermalPalette.canvasBg)
    }

    private func laneCard(_ lane: ThermalLane) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(lane.kind.name)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(ThermalPalette.text1)
                    Text(lane.kind.subLabel.uppercased())
                        .font(.system(size: 9))
                        .foregroundStyle(ThermalPalette.text4)
                }
                Spacer()
                ThermalSparkline(data: lane.history.suffix(20).map { $0 }, color: lane.color, lineWidth: 1.2)
                    .frame(width: 50, height: 22)
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(format: "%.0f", lane.current))
                    .font(.system(size: 26, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(lane.color)
                    .kerning(-0.6)
                Text("°C")
                    .font(.system(size: 12))
                    .foregroundStyle(ThermalPalette.text3)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("PEAK").font(.system(size: 8.5, weight: .semibold)).foregroundStyle(ThermalPalette.text4)
                    Text(String(format: "%.1f", lane.peak24h))
                        .font(.system(size: 10.5, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(ThermalPalette.text2)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text("ΔΔ").font(.system(size: 8.5, weight: .semibold)).foregroundStyle(ThermalPalette.text4)
                    Text(thermalDeltaString(lane.delta))
                        .font(.system(size: 10.5, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(lane.delta >= 0 ? ThermalPalette.hot : ThermalPalette.cool)
                }
                Spacer()
            }

            Spacer(minLength: 0)

            ThermalBandGauge(band: lane.band, dense: true)
                .frame(height: 18)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 8).fill(ThermalPalette.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(ThermalPalette.hairline, lineWidth: 1))
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("THROTTLE")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(ThermalPalette.hot)
            Text("\(100 - speedLimit) %")
                .font(.system(size: 22, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(ThermalPalette.hot)
                .kerning(-0.6)

            Spacer(minLength: 4)

            VStack(alignment: .leading, spacing: 4) {
                summaryLine("speed-limit \(speedLimit) %")
                if let h = hottest {
                    summaryLine("hottest \(h.kind.name) \(thermalTempString(h.current))")
                }
                summaryLine("state \(thermalState.rawValue.lowercased())")
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 8).fill(ThermalPalette.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(ThermalPalette.hot.opacity(0.30), lineWidth: 1))
    }

    private func summaryLine(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("·").font(.system(size: 12, weight: .bold)).foregroundStyle(ThermalPalette.hot)
            Text(text)
                .font(.system(size: 10.5))
                .foregroundStyle(ThermalPalette.text2)
        }
    }
}

import SwiftUI

struct PowerFlowRankList: View {
    let model: PowerFlowModel

    var body: some View {
        let dests = model.destinations.filter { $0.watts > 0.05 }
        let socComps = model.socComponents.filter { $0.watts > 0.05 }
        let combined = (dests.map { ($0.label, $0.watts, $0.color, $0.isSigned, false) }
                        + socComps.map { ("  " + $0.label, $0.watts, $0.color, false, true) })
            .sorted { $0.1 > $1.1 }
        let maxW = max(combined.map { $0.1 }.max() ?? 1, 0.0001)

        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("RANK")
                    .frame(width: 32, alignment: .leading)
                Text("CHANNEL")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("WATTS")
                    .frame(width: 70, alignment: .trailing)
                Text("SHARE")
                    .frame(width: 90, alignment: .trailing)
            }
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .tracking(1.0)
            .foregroundStyle(PowerFlowPalette.text3)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1) }

            ForEach(Array(combined.enumerated()), id: \.offset) { idx, row in
                HStack(spacing: 0) {
                    Text(String(format: "%02d", idx + 1))
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(PowerFlowPalette.text3)
                        .frame(width: 32, alignment: .leading)
                    HStack(spacing: 6) {
                        Rectangle()
                            .fill(row.2)
                            .frame(width: 3, height: 14)
                        Text(row.0)
                            .font(.system(size: 11, weight: row.4 ? .regular : .semibold, design: .monospaced))
                            .foregroundStyle(row.4 ? PowerFlowPalette.text2 : PowerFlowPalette.text1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    let displayWatts = row.3 ? (model.batteryIsCharging ? -row.1 : row.1) : row.1
                    Text(PowerFlowFormat.watts(displayWatts, signed: row.3))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(PowerFlowPalette.text1)
                        .monospacedDigit()
                        .frame(width: 70, alignment: .trailing)
                    GeometryReader { geo in
                        Rectangle()
                            .fill(row.2.opacity(0.75))
                            .frame(width: geo.size.width * CGFloat(row.1 / maxW), height: 4)
                            .offset(y: 5)
                    }
                    .frame(width: 90, height: 14)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.04)).frame(height: 1) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

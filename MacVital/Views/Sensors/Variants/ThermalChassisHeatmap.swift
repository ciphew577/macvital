// V1 chassis heatmap, top-down 14-inch MBP silhouette with discrete band overlays per zone.
import SwiftUI

struct ThermalChassisHeatmap: View {
    let lanes: [ThermalLane]
    let thermalState: ThermalState
    let speedLimit: Int

    private func lane(_ kind: ThermalLaneKind) -> ThermalLane? {
        lanes.first(where: { $0.kind == kind })
    }

    private var ranked: [ThermalLane] {
        lanes.sorted(by: { $0.current > $1.current })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ThermalTopStrip(lanes: lanes, thermalState: thermalState, speedLimit: speedLimit)

            HStack(alignment: .top, spacing: 16) {
                chassisStage
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                sidePanel
                    .frame(width: 280)
            }
        }
        .padding(20)
        .background(ThermalPalette.canvasBg)
    }

    private var chassisStage: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(ThermalPalette.stageBg)
                Canvas { ctx, size in
                    let body = CGRect(x: size.width * 0.04, y: size.height * 0.06,
                                      width: size.width * 0.92, height: size.height * 0.88)
                    let chassisPath = Path(roundedRect: body, cornerRadius: 22)
                    ctx.stroke(chassisPath, with: .color(.white.opacity(0.16)), lineWidth: 1.4)

                    let kbWell = CGRect(x: body.minX + body.width * 0.10,
                                        y: body.minY + body.height * 0.55,
                                        width: body.width * 0.80,
                                        height: body.height * 0.32)
                    ctx.fill(Path(roundedRect: kbWell, cornerRadius: 8), with: .color(.white.opacity(0.025)))
                    ctx.stroke(Path(roundedRect: kbWell, cornerRadius: 8), with: .color(.white.opacity(0.05)), lineWidth: 1)

                    let trackpad = CGRect(x: body.midX - body.width * 0.16,
                                          y: body.minY + body.height * 0.78,
                                          width: body.width * 0.32, height: body.height * 0.13)
                    ctx.fill(Path(roundedRect: trackpad, cornerRadius: 5), with: .color(.white.opacity(0.04)))
                    ctx.stroke(Path(roundedRect: trackpad, cornerRadius: 5), with: .color(.white.opacity(0.08)), lineWidth: 1)

                    let speakerL = CGRect(x: body.minX + body.width * 0.05, y: body.minY + body.height * 0.05, width: body.width * 0.16, height: 6)
                    let speakerR = CGRect(x: body.maxX - body.width * 0.21, y: body.minY + body.height * 0.05, width: body.width * 0.16, height: 6)
                    ctx.fill(Path(roundedRect: speakerL, cornerRadius: 3), with: .color(.white.opacity(0.05)))
                    ctx.fill(Path(roundedRect: speakerR, cornerRadius: 3), with: .color(.white.opacity(0.05)))
                }

                ForEach(ThermalLaneKind.allCases) { kind in
                    if kind != .chassis, let l = lane(kind) {
                        zoneOverlay(lane: l, frame: zoneFrame(kind: kind, in: CGSize(width: w, height: h)))
                    }
                }

                if let chassis = lane(.chassis) {
                    let body = CGRect(x: w * 0.04, y: h * 0.06, width: w * 0.92, height: h * 0.88)
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(chassis.color.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
                        .frame(width: body.width - 4, height: body.height - 4)
                        .position(x: body.midX, y: body.midY)
                    Text("CHASSIS skin avg \(thermalTempString(chassis.current))")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(chassis.color.opacity(0.65))
                        .position(x: body.minX + 90, y: body.maxY - 12)
                    Text("14 in MBP")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(ThermalPalette.text4)
                        .position(x: body.maxX - 40, y: body.maxY - 12)
                }
            }
        }
    }

    private func zoneFrame(kind: ThermalLaneKind, in size: CGSize) -> CGRect {
        let body = CGRect(x: size.width * 0.04, y: size.height * 0.06,
                          width: size.width * 0.92, height: size.height * 0.88)
        switch kind {
        case .pCPU:
            return CGRect(x: body.minX + body.width * 0.27, y: body.minY + body.height * 0.20,
                          width: body.width * 0.26, height: body.height * 0.18)
        case .eCPU:
            return CGRect(x: body.minX + body.width * 0.08, y: body.minY + body.height * 0.30,
                          width: body.width * 0.18, height: body.height * 0.14)
        case .gpu:
            return CGRect(x: body.minX + body.width * 0.55, y: body.minY + body.height * 0.20,
                          width: body.width * 0.25, height: body.height * 0.18)
        case .ane:
            return CGRect(x: body.minX + body.width * 0.78, y: body.minY + body.height * 0.32,
                          width: body.width * 0.16, height: body.height * 0.12)
        case .soc:
            return CGRect(x: body.midX - body.width * 0.07, y: body.minY + body.height * 0.40,
                          width: body.width * 0.14, height: body.height * 0.10)
        case .nand:
            return CGRect(x: body.minX + body.width * 0.18, y: body.minY + body.height * 0.55,
                          width: body.width * 0.16, height: body.height * 0.09)
        case .battery:
            return CGRect(x: body.minX + body.width * 0.10, y: body.minY + body.height * 0.66,
                          width: body.width * 0.80, height: body.height * 0.07)
        case .chassis:
            return body
        }
    }

    private func zoneOverlay(lane: ThermalLane, frame: CGRect) -> some View {
        let color = lane.color
        return ZStack {
            if lane.kind == .battery {
                RoundedRectangle(cornerRadius: 6)
                    .fill(color.opacity(0.20))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(color.opacity(0.50), lineWidth: 1))
                HStack {
                    Text(lane.kind.name.uppercased())
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(ThermalPalette.text1)
                    Spacer()
                    Text(thermalTempString(lane.current))
                        .font(.system(size: 11, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(ThermalPalette.text1)
                }
                .padding(.horizontal, 12)
            } else {
                Ellipse()
                    .fill(color.opacity(opacityFor(band: lane.band)))
                    .overlay(Ellipse().stroke(color.opacity(strokeFor(band: lane.band)), lineWidth: 1))
                VStack(spacing: 1) {
                    Text(lane.kind.name)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(ThermalPalette.text1)
                    Text(thermalTempString(lane.current))
                        .font(.system(size: 11, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(ThermalPalette.text1)
                }
            }
        }
        .frame(width: frame.width, height: frame.height)
        .position(x: frame.midX, y: frame.midY)
    }

    private func opacityFor(band: ThermalBand) -> Double {
        switch band {
        case .idle: return 0.18
        case .light: return 0.20
        case .heavy: return 0.26
        case .throttle: return 0.32
        }
    }

    private func strokeFor(band: ThermalBand) -> Double {
        switch band {
        case .idle: return 0.45
        case .light: return 0.50
        case .heavy: return 0.55
        case .throttle: return 0.65
        }
    }

    private var sidePanel: some View {
        VStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                Text("DISCRETE BANDS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(ThermalPalette.text3)
                legendRow(color: ThermalPalette.cool,  text: "Sage, idle",       range: "≤ 55 °C")
                legendRow(color: ThermalPalette.warm,  text: "Amber, light",     range: "55 to 70")
                legendRow(color: ThermalPalette.hot,   text: "Orange, heavy",    range: "70 to 85")
                legendRow(color: ThermalPalette.ember, text: "Ember, throttle",  range: "≥ 85")
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(ThermalPalette.cardBg))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(ThermalPalette.hairline, lineWidth: 1))

            VStack(alignment: .leading, spacing: 0) {
                Text("RANK, HOT TO COOL")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(ThermalPalette.text3)
                    .padding(.bottom, 8)

                ForEach(Array(ranked.enumerated()), id: \.element.id) { i, l in
                    HStack(spacing: 10) {
                        Text("\(i + 1)")
                            .font(.system(size: 10))
                            .monospacedDigit()
                            .foregroundStyle(ThermalPalette.text4)
                            .frame(width: 14, alignment: .trailing)
                        Text(l.kind.name)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ThermalPalette.text2)
                        Spacer()
                        Text(thermalTempString(l.current))
                            .font(.system(size: 12, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(l.color)
                        Text(thermalDeltaString(l.delta))
                            .font(.system(size: 10.5, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(l.delta >= 0 ? ThermalPalette.hot : ThermalPalette.cool)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(RoundedRectangle(cornerRadius: 3)
                                .fill((l.delta >= 0 ? ThermalPalette.hot : ThermalPalette.cool).opacity(0.14)))
                    }
                    .padding(.vertical, 6)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(ThermalPalette.hairline).frame(height: 1)
                            .opacity(i < ranked.count - 1 ? 1 : 0)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(ThermalPalette.cardBg))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(ThermalPalette.hairline, lineWidth: 1))
        }
    }

    private func legendRow(color: Color, text: String, range: String) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color.opacity(0.30))
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(color.opacity(0.55), lineWidth: 1))
                .frame(width: 18, height: 12)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(ThermalPalette.text2)
            Spacer()
            Text(range)
                .font(.system(size: 11))
                .monospacedDigit()
                .foregroundStyle(ThermalPalette.text3)
        }
    }
}

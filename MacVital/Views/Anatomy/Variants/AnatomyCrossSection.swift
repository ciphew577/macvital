// MacVital/Views/Anatomy/Variants/AnatomyCrossSection.swift

import SwiftUI

struct AnatomyCrossSection: View {

    @Bindable var viewModel: AnatomyViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var heatmapOn: Bool = false

    var body: some View {
        GeometryReader { geo in
            let scale = geo.size.width / AnatomyChassisGeometry.referenceWidth
            let scaledHeight = AnatomyChassisGeometry.referenceHeight * scale
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: MV.radius).fill(MV.tile)
                    .overlay(RoundedRectangle(cornerRadius: MV.radius).stroke(MV.hairline, lineWidth: 0.5))
                VStack(alignment: .leading, spacing: 0) {
                    masthead.frame(height: 44)
                        .overlay(Rectangle().fill(MV.hairline).frame(height: 0.5), alignment: .bottom)
                    canvas
                        .scaleEffect(scale, anchor: .topLeading)
                        .frame(width: geo.size.width, height: scaledHeight, alignment: .topLeading)
                        .clipped()
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private var masthead: some View {
        HStack(spacing: 14) {
            Text("DWG MV-A03 SECTION A-A")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1.6).foregroundStyle(MV.text4)
            Text("|").foregroundStyle(MV.text4.opacity(0.5))
            Text("Side profile cutaway. 3 horizontal layers from lid to base.")
                .font(.system(size: MV.FS.body)).foregroundStyle(MV.text2)
            Spacer()
            heatmapToggle
            ForEach(layers) { layer in
                HStack(spacing: 5) {
                    Rectangle().fill(layer.tint.opacity(0.6))
                        .frame(width: 10, height: 10)
                    Text(layer.label)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .tracking(1.2).foregroundStyle(MV.text2)
                }
            }
        }
        .padding(.horizontal, 28)
    }

    private var heatmapToggle: some View {
        Button { heatmapOn.toggle() } label: {
            HStack(spacing: 5) {
                Image(systemName: "thermometer")
                    .font(.system(size: 10, weight: .semibold))
                Text("HEATMAP")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(1.2)
            }
            .foregroundStyle(heatmapOn ? MV.text1 : MV.text3)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(heatmapOn ? AnatomyAccent.amber.opacity(0.16) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(heatmapOn ? AnatomyAccent.amber.opacity(0.55) : MV.hairline, lineWidth: 0.7)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Toggle thermal heatmap overlay")
    }

    private var canvas: some View {
        ZStack(alignment: .topLeading) {
            ForEach(layers) { layer in
                RoundedRectangle(cornerRadius: 6)
                    .fill(layer.tint.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(layer.tint.opacity(0.45), lineWidth: 1.0))
                    .frame(width: layer.rect.width, height: layer.rect.height)
                    .position(x: layer.rect.midX, y: layer.rect.midY)
                if heatmapOn {
                    let band = bandForLayer(layer.id)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(heatmapColor(band).opacity(heatmapOpacity(band)))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(heatmapColor(band).opacity(0.55), lineWidth: 0.7))
                        .frame(width: layer.rect.width, height: layer.rect.height)
                        .position(x: layer.rect.midX, y: layer.rect.midY)
                    Text(heatmapLabel(layer.id, band: band))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1.2).foregroundStyle(heatmapColor(band).opacity(0.95))
                        .position(x: layer.rect.maxX - 80, y: layer.rect.minY + 14)
                }
                Text(layer.title)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1.4).foregroundStyle(layer.tint.opacity(0.85))
                    .position(x: layer.rect.minX + 70, y: layer.rect.minY + 14)
            }
            ForEach(componentMarkers, id: \.id) { m in
                marker(m)
            }
            ForEach(traceList, id: \.id) { t in
                AnatomyTrace(points: t.points, kind: t.kind,
                             isHighlighted: highlightID == t.id,
                             isDimmed: dimmedIDSet.contains(t.id),
                             motionEnabled: !reduceMotion)
                    .frame(width: AnatomyChassisGeometry.referenceWidth,
                           height: AnatomyChassisGeometry.referenceHeight,
                           alignment: .topLeading)
            }
            hitSurface
            AnatomyTraceLegend(motionEnabled: !reduceMotion)
        }
        .frame(width: AnatomyChassisGeometry.referenceWidth,
               height: AnatomyChassisGeometry.referenceHeight,
               alignment: .topLeading)
    }

    @ViewBuilder
    private func marker(_ m: Marker) -> some View {
        let dim = dimmedIDSet.contains(m.id)
        let hl = highlightID == m.id
        ZStack {
            Circle()
                .fill(hl ? MV.accentSage.opacity(0.30) : m.tint.opacity(0.18))
                .frame(width: 26, height: 26)
            Circle()
                .stroke(hl ? MV.accentSage : m.tint.opacity(0.65), lineWidth: hl ? 1.4 : 1.0)
                .frame(width: 26, height: 26)
            Text(m.label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(0.5).foregroundStyle(MV.text1)
        }
        .opacity(dim ? 0.25 : 1.0)
        .position(m.point)
    }

    private var layers: [Layer] {
        let g = AnatomyChassisGeometry.chassisRect
        let topH: CGFloat = 130, midH: CGFloat = 200, botH: CGFloat = g.height - 130 - 200 - 12
        return [
            Layer(id: "lid", title: "LID ASSEMBLY",
                  rect: CGRect(x: g.minX + 12, y: g.minY + 12, width: g.width - 24, height: topH),
                  tint: cPurple, label: "DISPLAY"),
            Layer(id: "logic", title: "LOGIC BOARD",
                  rect: CGRect(x: g.minX + 12, y: g.minY + 12 + topH + 6, width: g.width - 24, height: midH),
                  tint: cBlue, label: "SoC + SSD + RF"),
            Layer(id: "base", title: "BASE ENCLOSURE",
                  rect: CGRect(x: g.minX + 12, y: g.minY + 12 + topH + midH + 12, width: g.width - 24, height: botH),
                  tint: cSage, label: "BATTERY + PMU")
        ]
    }

    private var componentMarkers: [Marker] {
        let g = AnatomyChassisGeometry.chassisRect
        let topY = g.minY + 12 + 65
        let midY = g.minY + 12 + 130 + 6 + 100
        let botY = g.minY + 12 + 130 + 200 + 12 + 70
        return [
            Marker(id: .lcd1, point: CGPoint(x: g.midX - 200, y: topY), tint: cPurple, label: "1"),
            Marker(id: .ant1, point: CGPoint(x: g.minX + 80, y: topY), tint: cBlue, label: "2"),
            Marker(id: .ant2, point: CGPoint(x: g.maxX - 80, y: topY), tint: cBlue, label: "3"),
            Marker(id: .u1, point: CGPoint(x: g.midX, y: midY), tint: cBlue, label: "4"),
            Marker(id: .u3, point: CGPoint(x: g.midX + 180, y: midY), tint: cBlue, label: "5"),
            Marker(id: .fan1, point: CGPoint(x: g.midX - 220, y: midY), tint: cAmber, label: "6"),
            Marker(id: .fan2, point: CGPoint(x: g.midX + 280, y: midY), tint: cAmber, label: "7"),
            Marker(id: .bt1, point: CGPoint(x: g.midX, y: botY), tint: cSage, label: "8"),
            Marker(id: .ic1, point: CGPoint(x: g.midX - 200, y: botY), tint: cSage, label: "9"),
            Marker(id: .spk1, point: CGPoint(x: g.midX + 220, y: botY), tint: cSage, label: "0")
        ]
    }

    private var traceList: [TraceLink] {
        componentMarkers.map { m in
            let blockX: CGFloat = m.point.x < AnatomyChassisGeometry.referenceWidth / 2 ? 164 : 1172
            let blockY = m.point.y
            return TraceLink(id: m.id, kind: traceKind(m.id),
                             points: [m.point, CGPoint(x: blockX, y: blockY)])
        }
    }
    private func traceKind(_ id: AnatomyComponentID) -> AnatomyTraceKind {
        switch id {
        case .fan1, .fan2: return .thermal
        case .ant1, .ant2: return .rf
        case .bt1, .ic1: return .power
        default: return .data
        }
    }

    @ViewBuilder
    private var hitSurface: some View {
        let zones = componentMarkers.map { m in
            (id: m.id, rect: CGRect(x: m.point.x - 18, y: m.point.y - 18, width: 36, height: 36))
        }
        Rectangle().fill(Color.clear).contentShape(Rectangle())
            .frame(width: AnatomyChassisGeometry.referenceWidth,
                   height: AnatomyChassisGeometry.referenceHeight)
            .onContinuousHover { phase in
                switch phase {
                case .active(let p):
                    let id = zones.first(where: { $0.rect.contains(p) })?.id
                    if id != viewModel.hoveredID { viewModel.hoveredID = id }
                case .ended:
                    viewModel.hoveredID = nil
                }
            }
            .gesture(SpatialTapGesture(coordinateSpace: .local).onEnded { v in
                if let id = zones.first(where: { $0.rect.contains(v.location) })?.id {
                    viewModel.togglePin(id)
                }
            })
    }

    private var highlightID: AnatomyComponentID? { viewModel.hoveredID ?? viewModel.pinnedID }
    private var dimmedIDSet: Set<AnatomyComponentID> {
        guard viewModel.activeFilter != .all else { return [] }
        // SoC (.u1) stays bright across every filter, it's the always-on root.
        return Set(AnatomyComponentID.allCases.filter { viewModel.isDimmed($0) })
            .subtracting([.u1])
    }

    private struct Layer: Identifiable { let id: String; let title: String; let rect: CGRect; let tint: Color; let label: String }
    private struct Marker { let id: AnatomyComponentID; let point: CGPoint; let tint: Color; let label: String }
    private struct TraceLink { let id: AnatomyComponentID; let kind: AnatomyTraceKind; let points: [CGPoint] }

    private var heatmapLanes: [ThermalLane] {
        let sensors = viewModel.monitor?.sensors?.sensors ?? []
        return ThermalLaneFolder.collapse(sensors: sensors, history: [])
    }
    private func lane(_ kind: ThermalLaneKind) -> ThermalLane? {
        heatmapLanes.first(where: { $0.kind == kind })
    }
    private func bandForLayer(_ layerID: String) -> ThermalBand {
        let kind: ThermalLaneKind = {
            switch layerID {
            case "lid":   return .chassis
            case "logic": return .soc
            case "base":  return .battery
            default:      return .chassis
            }
        }()
        return lane(kind)?.band ?? .idle
    }
    private func heatmapColor(_ band: ThermalBand) -> Color {
        switch band {
        case .idle:     return AnatomyAccent.sage
        case .light:    return AnatomyAccent.amber
        case .heavy:    return AnatomyAccent.amber
        case .throttle: return ThermalPalette.ember
        }
    }
    private func heatmapOpacity(_ band: ThermalBand) -> Double {
        switch band {
        case .idle:     return 0.04
        case .light:    return 0.10
        case .heavy:    return 0.16
        case .throttle: return 0.22
        }
    }
    private func heatmapLabel(_ layerID: String, band: ThermalBand) -> String {
        let kind: ThermalLaneKind = layerID == "lid" ? .chassis : (layerID == "logic" ? .soc : .battery)
        guard let l = lane(kind) else { return band.label.uppercased() }
        return "\(Int(l.current.rounded())) C  " + band.label.uppercased()
    }

    private var cAmber:  Color { AnatomyAccent.amber }
    private var cSage:   Color { AnatomyAccent.sage }
    private var cBlue:   Color { AnatomyAccent.blue }
    private var cPurple: Color { AnatomyAccent.purple }
}

#if DEBUG
#Preview("Cross Section") {
    AnatomyCrossSection(viewModel: AnatomyViewModel())
        .frame(width: 1_200, height: 600).background(MV.bg)
}
#endif

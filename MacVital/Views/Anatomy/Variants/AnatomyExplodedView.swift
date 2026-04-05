// MacVital/Views/Anatomy/Variants/AnatomyExplodedView.swift

import SwiftUI

struct AnatomyExplodedView: View {

    @Bindable var viewModel: AnatomyViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var explode: Bool = false
    @State private var jitterTick: Date = Date()
    @State private var liveStats: [AnatomyComponentID: [Stat]] = [:]
    private let tick = Timer.publish(every: 2.4, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            let scale = geo.size.width / AnatomyChassisGeometry.referenceWidth
            let scaledHeight = AnatomyChassisGeometry.referenceHeight * scale
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: MV.radius)
                    .fill(MV.tile)
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
        .onReceive(tick) { _ in jitterTick = Date(); applyJitter() }
        .onAppear { applyJitter() }
    }

    private var masthead: some View {
        HStack(spacing: 14) {
            Text("DWG MV-A02 EXPLODED")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(MV.text4)
            Text("|").foregroundStyle(MV.text4.opacity(0.5))
            Text("Components fly outward along radial vectors.")
                .font(.system(size: MV.FS.body))
                .foregroundStyle(MV.text2)
            Spacer()
            Button(explode ? "ASSEMBLE" : "EXPLODE") {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) { explode.toggle() }
            }
            .buttonStyle(.plain)
            .font(.system(size: 9, weight: .semibold, design: .monospaced))
            .tracking(1.4)
            .foregroundStyle(explode ? MV.accentSage : MV.text2)
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 999).fill(explode ? MV.accentSage.opacity(0.16) : MV.bg))
            .overlay(RoundedRectangle(cornerRadius: 999).stroke(explode ? MV.accentSage.opacity(0.32) : MV.hairlineStrong, lineWidth: 0.5))
        }
        .padding(.horizontal, 28)
    }

    private var canvas: some View {
        ZStack(alignment: .topLeading) {
            AnatomyChassisShape()
            ForEach(componentSpecs, id: \.id) { spec in
                explodedComponent(spec)
            }
            ForEach(traceSpecs, id: \.id) { spec in
                AnatomyTrace(points: spec.points, kind: spec.kind,
                             isHighlighted: highlightID == spec.id,
                             isDimmed: dimmedIDSet.contains(spec.id),
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
    private func explodedComponent(_ spec: ComponentSpec) -> some View {
        let dim = dimmedIDSet.contains(spec.id)
        let hl = highlightID == spec.id
        let offset = explode ? spec.radial : .zero
        let label = liveLabel(for: spec.id)
        ZStack {
            spec.shape
                .fill(spec.tint.opacity(hl ? 0.30 : 0.18))
            spec.shape
                .stroke(hl ? MV.accentSage : spec.tint.opacity(0.65), lineWidth: hl ? 1.4 : 1.0)
            Text(label)
                .font(.system(size: 7 * 1.32, weight: .semibold, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(MV.text2)
                .position(spec.labelAt)
        }
        .opacity(dim ? 0.25 : 1.0)
        .offset(x: offset.x, y: offset.y)
        .animation(.spring(response: 0.6, dampingFraction: 0.78), value: explode)
    }

    @ViewBuilder
    private var hitSurface: some View {
        let zones = hitZones
        Rectangle().fill(Color.clear).contentShape(Rectangle())
            .frame(width: AnatomyChassisGeometry.referenceWidth,
                   height: AnatomyChassisGeometry.referenceHeight)
            .onContinuousHover { phase in
                switch phase {
                case .active(let p):
                    let id = zones.first(where: { $0.path.cgPath.contains(p.applying(unexplode(for: $0.id))) })?.id
                    if id != viewModel.hoveredID { viewModel.hoveredID = id }
                case .ended:
                    viewModel.hoveredID = nil
                }
            }
            .gesture(SpatialTapGesture(coordinateSpace: .local).onEnded { v in
                if let id = zones.first(where: { $0.path.cgPath.contains(v.location.applying(unexplode(for: $0.id))) })?.id {
                    viewModel.togglePin(id)
                }
            })
    }

    private func unexplode(for id: AnatomyComponentID) -> CGAffineTransform {
        guard explode, let spec = componentSpecs.first(where: { $0.id == id }) else { return .identity }
        return CGAffineTransform(translationX: -spec.radial.x, y: -spec.radial.y)
    }

    private var componentSpecs: [ComponentSpec] {
        let cx: CGFloat = 668; let cy: CGFloat = 252
        func vec(_ from: CGPoint, mag: CGFloat) -> CGPoint {
            let dx = from.x - cx, dy = from.y - cy
            let len = max(1, sqrt(dx * dx + dy * dy))
            return CGPoint(x: dx / len * mag, y: dy / len * mag)
        }
        return [
            ComponentSpec(id: .u1, shape: AnatomyChassisPaths.u1Outer(), tint: cBlue,
                          radial: .zero, labelAt: AnatomyChassisGeometry.Anchor.u1, label: "U1 SOC"),
            ComponentSpec(id: .fan1, shape: AnatomyChassisPaths.fan1(), tint: cAmber,
                          radial: vec(AnatomyChassisGeometry.Anchor.fan1, mag: 90), labelAt: AnatomyChassisGeometry.Anchor.fan1, label: "FAN1"),
            ComponentSpec(id: .fan2, shape: AnatomyChassisPaths.fan2(), tint: cAmber,
                          radial: vec(AnatomyChassisGeometry.Anchor.fan2, mag: 90), labelAt: AnatomyChassisGeometry.Anchor.fan2, label: "FAN2"),
            ComponentSpec(id: .ant1, shape: AnatomyChassisPaths.ant1(), tint: cBlue,
                          radial: vec(AnatomyChassisGeometry.Anchor.ant1, mag: 110), labelAt: AnatomyChassisGeometry.Anchor.ant1, label: "ANT1"),
            ComponentSpec(id: .bt1, shape: bt1Combined(), tint: cSage,
                          radial: vec(AnatomyChassisGeometry.Anchor.bt1, mag: 100), labelAt: AnatomyChassisGeometry.Anchor.bt1, label: "BT1"),
            ComponentSpec(id: .ic1, shape: AnatomyChassisPaths.ic1(), tint: cSage,
                          radial: vec(AnatomyChassisGeometry.Anchor.ic1, mag: 110), labelAt: AnatomyChassisGeometry.Anchor.ic1, label: "PMU"),
            ComponentSpec(id: .spk1, shape: spk1Combined(), tint: cSage,
                          radial: vec(AnatomyChassisGeometry.Anchor.spk1, mag: 110), labelAt: AnatomyChassisGeometry.Anchor.spk1, label: "SPK1"),
            ComponentSpec(id: .u3, shape: AnatomyChassisPaths.u3(), tint: cBlue,
                          radial: vec(AnatomyChassisGeometry.Anchor.u3, mag: 100), labelAt: AnatomyChassisGeometry.Anchor.u3, label: "U3 SSD"),
            ComponentSpec(id: .lcd1, shape: AnatomyChassisPaths.lcd1(), tint: cPurple,
                          radial: vec(AnatomyChassisGeometry.Anchor.lcd1, mag: 110), labelAt: AnatomyChassisGeometry.Anchor.lcd1, label: "LCD1"),
            ComponentSpec(id: .ant2, shape: AnatomyChassisPaths.ant2(), tint: cBlue,
                          radial: vec(AnatomyChassisGeometry.Anchor.ant2, mag: 110), labelAt: AnatomyChassisGeometry.Anchor.ant2, label: "ANT2")
        ]
    }

    private func bt1Combined() -> Path {
        var p = Path(); for c in AnatomyChassisPaths.bt1Cells() { p.addPath(c) }; return p
    }
    private func spk1Combined() -> Path {
        var p = Path(); for b in AnatomyChassisPaths.spk1Bars() { p.addPath(b) }; return p
    }

    private var hitZones: [(id: AnatomyComponentID, path: Path)] {
        componentSpecs.map { ($0.id, $0.shape) }
    }

    private var traceSpecs: [TS] {
        [
            TS(id: .u1,   kind: .data,    points: [AnatomyChassisGeometry.Anchor.u1, CGPoint(x: 668, y: 44), CGPoint(x: 1172, y: 44)]),
            TS(id: .fan1, kind: .thermal, points: [AnatomyChassisGeometry.Anchor.fan1, CGPoint(x: 240, y: 114.7), CGPoint(x: 164, y: 110)]),
            TS(id: .fan2, kind: .thermal, points: [AnatomyChassisGeometry.Anchor.fan2, CGPoint(x: 1100, y: 114.7), CGPoint(x: 1172, y: 124)]),
            TS(id: .ant1, kind: .rf,      points: [AnatomyChassisGeometry.Anchor.ant1, CGPoint(x: 240, y: 14.4), CGPoint(x: 164, y: 35)]),
            TS(id: .bt1,  kind: .power,   points: [AnatomyChassisGeometry.Anchor.bt1, CGPoint(x: 240, y: 357.6), CGPoint(x: 164, y: 202)]),
            TS(id: .ic1,  kind: .power,   points: [AnatomyChassisGeometry.Anchor.ic1, CGPoint(x: 250, y: 299.5), CGPoint(x: 164, y: 294)]),
            TS(id: .spk1, kind: .data,    points: [AnatomyChassisGeometry.Anchor.spk1, CGPoint(x: 250, y: 183.4), CGPoint(x: 164, y: 390)]),
            TS(id: .u3,   kind: .data,    points: [AnatomyChassisGeometry.Anchor.u3, CGPoint(x: 1080, y: 220.3), CGPoint(x: 1172, y: 210)]),
            TS(id: .lcd1, kind: .data,    points: [AnatomyChassisGeometry.Anchor.lcd1, CGPoint(x: 1100, y: 104.2), CGPoint(x: 1172, y: 296)]),
            TS(id: .ant2, kind: .rf,      points: [AnatomyChassisGeometry.Anchor.ant2, CGPoint(x: 1110, y: 14.4), CGPoint(x: 1172, y: 382)])
        ]
    }

    private var highlightID: AnatomyComponentID? { viewModel.hoveredID ?? viewModel.pinnedID }
    private var dimmedIDSet: Set<AnatomyComponentID> {
        guard viewModel.activeFilter != .all else { return [] }
        // SoC (.u1) stays bright across every filter, it's the always-on root.
        return Set(AnatomyComponentID.allCases.filter { viewModel.isDimmed($0) })
            .subtracting([.u1])
    }

    private func liveLabel(for id: AnatomyComponentID) -> String {
        let comp = viewModel.components.first(where: { $0.id == id })
        return comp?.refTag ?? id.rawValue.uppercased()
    }

    private func applyJitter() {
        var next: [AnatomyComponentID: [Stat]] = [:]
        for c in viewModel.components { next[c.id] = c.stats.map(AnatomyHero.jitter(stat:)) }
        liveStats = next
    }

    private struct ComponentSpec {
        let id: AnatomyComponentID
        let shape: Path
        let tint: Color
        let radial: CGPoint
        let labelAt: CGPoint
        let label: String
    }
    private struct TS { let id: AnatomyComponentID; let kind: AnatomyTraceKind; let points: [CGPoint] }

    private var cAmber:  Color { AnatomyAccent.amber }
    private var cSage:   Color { AnatomyAccent.sage }
    private var cBlue:   Color { AnatomyAccent.blue }
    private var cPurple: Color { AnatomyAccent.purple }
}

#if DEBUG
#Preview("Exploded") {
    AnatomyExplodedView(viewModel: AnatomyViewModel())
        .frame(width: 1_200, height: 600).background(MV.bg)
}
#endif

// MacVital/Views/Anatomy/Variants/AnatomyWiringDiagram.swift

import SwiftUI

struct AnatomyWiringDiagram: View {

    @Bindable var viewModel: AnatomyViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            Text("DWG MV-A04 SCHEMATIC")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1.6).foregroundStyle(MV.text4)
            Text("|").foregroundStyle(MV.text4.opacity(0.5))
            Text("KiCad-style symbols, orthogonal nets, GND rail at base.")
                .font(.system(size: MV.FS.body)).foregroundStyle(MV.text2)
            Spacer()
        }
        .padding(.horizontal, 28)
    }

    private var canvas: some View {
        ZStack(alignment: .topLeading) {
            gridBackdrop
            ForEach(symbols, id: \.id) { s in symbolView(s) }
            ForEach(nets, id: \.id) { n in
                AnatomyTrace(points: n.points, kind: n.kind,
                             isHighlighted: highlightID == n.id,
                             isDimmed: dimmedIDSet.contains(n.id),
                             motionEnabled: !reduceMotion)
                    .frame(width: AnatomyChassisGeometry.referenceWidth,
                           height: AnatomyChassisGeometry.referenceHeight,
                           alignment: .topLeading)
            }
            gndRail
            hitSurface
            AnatomyTraceLegend(motionEnabled: !reduceMotion)
        }
        .frame(width: AnatomyChassisGeometry.referenceWidth,
               height: AnatomyChassisGeometry.referenceHeight,
               alignment: .topLeading)
    }

    private var gridBackdrop: some View {
        Canvas { ctx, _ in
            let pitch: CGFloat = 20
            var x: CGFloat = 0
            while x < AnatomyChassisGeometry.referenceWidth {
                var p = Path(); p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: AnatomyChassisGeometry.referenceHeight))
                ctx.stroke(p, with: .color(Color.white.opacity(0.025)), lineWidth: 0.5)
                x += pitch
            }
            var y: CGFloat = 0
            while y < AnatomyChassisGeometry.referenceHeight {
                var p = Path(); p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: AnatomyChassisGeometry.referenceWidth, y: y))
                ctx.stroke(p, with: .color(Color.white.opacity(0.025)), lineWidth: 0.5)
                y += pitch
            }
        }
        .frame(width: AnatomyChassisGeometry.referenceWidth, height: AnatomyChassisGeometry.referenceHeight)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func symbolView(_ s: Symbol) -> some View {
        let dim = dimmedIDSet.contains(s.id)
        let hl = highlightID == s.id
        let stroke = hl ? MV.accentSage : s.tint.opacity(0.7)
        ZStack {
            switch s.kind {
            case .ic:
                let r = CGRect(x: s.center.x - 60, y: s.center.y - 30, width: 120, height: 60)
                Rectangle().fill(s.tint.opacity(0.10))
                    .frame(width: r.width, height: r.height).position(x: r.midX, y: r.midY)
                Rectangle().stroke(stroke, lineWidth: hl ? 1.4 : 1.0)
                    .frame(width: r.width, height: r.height).position(x: r.midX, y: r.midY)
                ForEach(0..<4, id: \.self) { i in
                    Rectangle().fill(stroke).frame(width: 8, height: 0.5)
                        .position(x: r.minX - 4, y: r.minY + 12 + CGFloat(i) * 12)
                    Rectangle().fill(stroke).frame(width: 8, height: 0.5)
                        .position(x: r.maxX + 4, y: r.minY + 12 + CGFloat(i) * 12)
                }
            case .capacitor:
                Rectangle().fill(stroke).frame(width: 28, height: 1.0).position(s.center)
                Rectangle().fill(stroke).frame(width: 28, height: 1.0).position(x: s.center.x, y: s.center.y + 6)
            case .resistor:
                Rectangle().stroke(stroke, lineWidth: 1.0).frame(width: 36, height: 14).position(s.center)
            case .inductor:
                Canvas { ctx, _ in
                    var p = Path()
                    for i in 0..<4 {
                        let cx = s.center.x - 18 + CGFloat(i) * 12
                        p.addArc(center: CGPoint(x: cx, y: s.center.y), radius: 6, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
                    }
                    ctx.stroke(p, with: .color(stroke), lineWidth: 1.0)
                }
                .frame(width: 60, height: 14).position(s.center)
            case .battery:
                let r = CGRect(x: s.center.x - 48, y: s.center.y - 18, width: 96, height: 36)
                Rectangle().fill(s.tint.opacity(0.10))
                    .frame(width: r.width, height: r.height).position(x: r.midX, y: r.midY)
                Rectangle().stroke(stroke, lineWidth: hl ? 1.4 : 1.0)
                    .frame(width: r.width, height: r.height).position(x: r.midX, y: r.midY)
                let frac = batteryFraction
                Rectangle().fill(s.tint.opacity(0.5))
                    .frame(width: r.width * frac, height: r.height - 6)
                    .position(x: r.minX + r.width * frac / 2, y: r.midY)
            case .antenna:
                Canvas { ctx, _ in
                    var p = Path()
                    p.move(to: CGPoint(x: s.center.x, y: s.center.y + 14))
                    p.addLine(to: CGPoint(x: s.center.x, y: s.center.y - 6))
                    p.move(to: CGPoint(x: s.center.x - 10, y: s.center.y - 14))
                    p.addLine(to: CGPoint(x: s.center.x, y: s.center.y - 6))
                    p.addLine(to: CGPoint(x: s.center.x + 10, y: s.center.y - 14))
                    ctx.stroke(p, with: .color(stroke), lineWidth: 1.0)
                }
                .frame(width: 28, height: 32).position(s.center)
            }
            Text(s.label)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .tracking(0.6).foregroundStyle(MV.text2)
                .position(x: s.center.x, y: s.center.y + 38)
        }
        .opacity(dim ? 0.25 : 1.0)
    }

    private var gndRail: some View {
        Rectangle().fill(MV.text3.opacity(0.5))
            .frame(width: AnatomyChassisGeometry.referenceWidth - 80, height: 1.0)
            .position(x: AnatomyChassisGeometry.referenceWidth / 2,
                      y: AnatomyChassisGeometry.referenceHeight - 30)
            .overlay(
                Text("GND")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(1.2).foregroundStyle(MV.text3)
                    .position(x: 60, y: AnatomyChassisGeometry.referenceHeight - 30)
            )
            .allowsHitTesting(false)
    }

    private var symbols: [Symbol] {
        [
            Symbol(id: .u1,   center: CGPoint(x: 668, y: 220), tint: cBlue,   kind: .ic,        label: "U1 SoC"),
            Symbol(id: .u3,   center: CGPoint(x: 900, y: 220), tint: cBlue,   kind: .ic,        label: "U3 SSD"),
            Symbol(id: .ic1,  center: CGPoint(x: 420, y: 220), tint: cSage,   kind: .ic,        label: "IC1 PMU"),
            Symbol(id: .bt1,  center: CGPoint(x: 668, y: 380), tint: cSage,   kind: .battery,   label: "BT1"),
            Symbol(id: .fan1, center: CGPoint(x: 280, y: 120), tint: cAmber,  kind: .inductor,  label: "FAN1"),
            Symbol(id: .fan2, center: CGPoint(x: 1060, y: 120), tint: cAmber, kind: .inductor,  label: "FAN2"),
            Symbol(id: .ant1, center: CGPoint(x: 280, y: 320), tint: cBlue,   kind: .antenna,   label: "ANT1"),
            Symbol(id: .ant2, center: CGPoint(x: 1060, y: 320), tint: cBlue,  kind: .antenna,   label: "ANT2"),
            Symbol(id: .lcd1, center: CGPoint(x: 1180, y: 220), tint: cPurple, kind: .resistor, label: "LCD1"),
            Symbol(id: .spk1, center: CGPoint(x: 160, y: 220), tint: cSage,   kind: .capacitor, label: "SPK1")
        ]
    }

    private var nets: [Net] {
        symbols.map { s in
            let kind: AnatomyTraceKind = {
                switch s.id {
                case .fan1, .fan2: return .thermal
                case .ant1, .ant2: return .rf
                case .bt1, .ic1: return .power
                default: return .data
                }
            }()
            return Net(id: s.id, kind: kind,
                       points: [s.center,
                                CGPoint(x: s.center.x, y: AnatomyChassisGeometry.referenceHeight - 30)])
        }
    }

    @ViewBuilder
    private var hitSurface: some View {
        let zones = symbols.map { s -> (AnatomyComponentID, CGRect) in
            (s.id, CGRect(x: s.center.x - 60, y: s.center.y - 30, width: 120, height: 60))
        }
        Rectangle().fill(Color.clear).contentShape(Rectangle())
            .frame(width: AnatomyChassisGeometry.referenceWidth,
                   height: AnatomyChassisGeometry.referenceHeight)
            .onContinuousHover { phase in
                switch phase {
                case .active(let p):
                    let id = zones.first(where: { $0.1.contains(p) })?.0
                    if id != viewModel.hoveredID { viewModel.hoveredID = id }
                case .ended:
                    viewModel.hoveredID = nil
                }
            }
            .gesture(SpatialTapGesture(coordinateSpace: .local).onEnded { v in
                if let id = zones.first(where: { $0.1.contains(v.location) })?.0 {
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

    private var batteryFraction: CGFloat {
        guard let bt = viewModel.components.first(where: { $0.id == .bt1 }),
              let pct = bt.stats.first(where: { $0.label.uppercased() == "CHRG" })?.value,
              let v = Double(pct) else { return 0.85 }
        return CGFloat(max(0, min(1, v / 100.0)))
    }

    private enum Kind { case ic, capacitor, resistor, inductor, battery, antenna }
    private struct Symbol { let id: AnatomyComponentID; let center: CGPoint; let tint: Color; let kind: Kind; let label: String }
    private struct Net { let id: AnatomyComponentID; let kind: AnatomyTraceKind; let points: [CGPoint] }

    private var cAmber:  Color { AnatomyAccent.amber }
    private var cSage:   Color { AnatomyAccent.sage }
    private var cBlue:   Color { AnatomyAccent.blue }
    private var cPurple: Color { AnatomyAccent.purple }
}

#if DEBUG
#Preview("Wiring") {
    AnatomyWiringDiagram(viewModel: AnatomyViewModel())
        .frame(width: 1_200, height: 600).background(MV.bg)
}
#endif

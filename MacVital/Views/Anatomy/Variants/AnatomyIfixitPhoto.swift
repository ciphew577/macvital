// MacVital/Views/Anatomy/Variants/AnatomyIfixitPhoto.swift

import SwiftUI

struct AnatomyIfixitPhoto: View {

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
            Text("DWG MV-A05 TEARDOWN")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1.6).foregroundStyle(MV.text4)
            Text("|").foregroundStyle(MV.text4.opacity(0.5))
            Text("Flat top-down chassis. Numbered red callouts 1 through 10.")
                .font(.system(size: MV.FS.body)).foregroundStyle(MV.text2)
            Spacer()
        }
        .padding(.horizontal, 28)
    }

    private var canvas: some View {
        ZStack(alignment: .topLeading) {
            AnatomyChassisShape()
            AnatomyChassisInterior(
                highlightID: highlightID,
                dimmedIDs: dimmedIDSet,
                onHover: { id in viewModel.hoveredID = id },
                onTap: { id in viewModel.togglePin(id) }
            )
            .frame(width: AnatomyChassisGeometry.referenceWidth,
                   height: AnatomyChassisGeometry.referenceHeight,
                   alignment: .topLeading)
            ForEach(badges, id: \.id) { b in badgeView(b) }
            ForEach(traceList, id: \.id) { t in
                AnatomyTrace(points: t.points, kind: t.kind,
                             isHighlighted: highlightID == t.id,
                             isDimmed: dimmedIDSet.contains(t.id),
                             motionEnabled: !reduceMotion)
                    .frame(width: AnatomyChassisGeometry.referenceWidth,
                           height: AnatomyChassisGeometry.referenceHeight,
                           alignment: .topLeading)
            }
            AnatomyTraceLegend(motionEnabled: !reduceMotion)
        }
        .frame(width: AnatomyChassisGeometry.referenceWidth,
               height: AnatomyChassisGeometry.referenceHeight,
               alignment: .topLeading)
    }

    @ViewBuilder
    private func badgeView(_ b: Badge) -> some View {
        let dim = dimmedIDSet.contains(b.id)
        let hl = highlightID == b.id
        ZStack {
            Circle().fill(emberFill)
                .frame(width: 22, height: 22)
            Circle().stroke(hl ? MV.accentSage : ember, lineWidth: hl ? 1.4 : 1.0)
                .frame(width: 22, height: 22)
            Text("\(b.number)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(MV.text1)
        }
        .opacity(dim ? 0.25 : 1.0)
        .position(b.point)
        .allowsHitTesting(false)
    }

    private var badges: [Badge] {
        let order: [(AnatomyComponentID, CGPoint)] = [
            (.u1,   CGPoint(x: AnatomyChassisGeometry.Anchor.u1.x + 30,   y: AnatomyChassisGeometry.Anchor.u1.y - 30)),
            (.u3,   CGPoint(x: AnatomyChassisGeometry.Anchor.u3.x + 30,   y: AnatomyChassisGeometry.Anchor.u3.y - 30)),
            (.fan1, CGPoint(x: AnatomyChassisGeometry.Anchor.fan1.x + 60, y: AnatomyChassisGeometry.Anchor.fan1.y - 50)),
            (.fan2, CGPoint(x: AnatomyChassisGeometry.Anchor.fan2.x - 60, y: AnatomyChassisGeometry.Anchor.fan2.y - 50)),
            (.bt1,  CGPoint(x: AnatomyChassisGeometry.Anchor.bt1.x,       y: AnatomyChassisGeometry.Anchor.bt1.y - 50)),
            (.ic1,  CGPoint(x: AnatomyChassisGeometry.Anchor.ic1.x - 30,  y: AnatomyChassisGeometry.Anchor.ic1.y - 20)),
            (.spk1, CGPoint(x: AnatomyChassisGeometry.Anchor.spk1.x - 24, y: AnatomyChassisGeometry.Anchor.spk1.y)),
            (.lcd1, CGPoint(x: AnatomyChassisGeometry.Anchor.lcd1.x + 24, y: AnatomyChassisGeometry.Anchor.lcd1.y - 8)),
            (.ant1, CGPoint(x: AnatomyChassisGeometry.Anchor.ant1.x - 14, y: AnatomyChassisGeometry.Anchor.ant1.y + 18)),
            (.ant2, CGPoint(x: AnatomyChassisGeometry.Anchor.ant2.x + 14, y: AnatomyChassisGeometry.Anchor.ant2.y + 18))
        ]
        return order.enumerated().map { (i, pair) in
            Badge(id: pair.0, number: i + 1, point: pair.1)
        }
    }

    private var traceList: [TraceLink] {
        badges.map { b in
            let blockX: CGFloat = b.point.x < AnatomyChassisGeometry.referenceWidth / 2 ? 164 : 1172
            let blockY = max(20, min(AnatomyChassisGeometry.referenceHeight - 20, b.point.y))
            return TraceLink(id: b.id, kind: traceKind(b.id),
                             points: [b.point, CGPoint(x: blockX, y: blockY)])
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

    private var highlightID: AnatomyComponentID? { viewModel.hoveredID ?? viewModel.pinnedID }
    private var dimmedIDSet: Set<AnatomyComponentID> {
        guard viewModel.activeFilter != .all else { return [] }
        // SoC (.u1) stays bright across every filter, it's the always-on root.
        return Set(AnatomyComponentID.allCases.filter { viewModel.isDimmed($0) })
            .subtracting([.u1])
    }

    private struct Badge { let id: AnatomyComponentID; let number: Int; let point: CGPoint }
    private struct TraceLink { let id: AnatomyComponentID; let kind: AnatomyTraceKind; let points: [CGPoint] }

    // Intentional non-palette accent: iFixit-style red badge tone. Kept raw on
    // purpose so it stays distinct from AnatomyAccent / MV palette tokens.
    private var ember: Color { Color(red: 0.753, green: 0.314, blue: 0.227) }
    private var emberFill: Color { Color(red: 0.753, green: 0.314, blue: 0.227).opacity(0.22) }
}

#if DEBUG
#Preview("iFixit") {
    AnatomyIfixitPhoto(viewModel: AnatomyViewModel())
        .frame(width: 1_200, height: 600).background(MV.bg)
}
#endif

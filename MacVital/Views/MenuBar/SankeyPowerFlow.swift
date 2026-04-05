// MacVital/Views/MenuBar/SankeyPowerFlow.swift
//
// Hero "POWER FLOW" Sankey visualization. Three columns — Wall, Battery,
// Mac — connected by filled cubic-Bezier streams whose width is proportional
// to wattage (1 W = 3 px). All streams share the muted purple "power" hue
// (#b38cf7) because Sankey is the Power tile's dedicated hero.
//
// Rendering:
//   • SwiftUI Canvas — single pass, no per-path AnimatableData.
//   • TimelineView (.periodic, 30 Hz) drives a 2.4 s looping dashed flow
//     line on each stream. The timeline is ONLY mounted while the view
//     is visible — `onAppear` flips `isVisible = true`, `onDisappear`
//     flips it back and the animation collapses to a static snapshot.
//     This prevents the NSPopover teardown/rebuild cycle from stacking
//     animation ticks and repainting at display refresh.
//   • Layout mirrors v4-control-center-sankey.html viewBox 0 0 264 100:
//       Wall    col at x=8..34     (width 26)
//       Battery col at x=119..145  (width 26)
//       Mac     col at x=230..256  (width 26)
//     Node height 64 pt, y=18..82.
//   • Respects `accessibilityReduceMotion` — disables flow animation.

import SwiftUI

struct SankeyPowerFlow: View {
    /// Total wall input in watts.
    let wallWatts: Double
    /// Total Mac draw in watts.
    let macWatts: Double
    /// CPU draw.
    let cpuWatts: Double
    /// GPU draw.
    let gpuWatts: Double
    /// DRAM draw.
    let dramWatts: Double
    /// USB / peripheral draw.
    let usbWatts: Double
    /// Battery state of charge 0...1.
    let batteryFraction: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false
    /// Gates the flow-line TimelineView. NSPopover tears down / rebuilds
    /// the body aggressively; without this gate the timeline can keep
    /// ticking across rebuilds and pile up paint work.
    @State private var isVisible = false

    // Canvas logical coordinate space (mirrors SVG viewBox 264×100).
    private let logical = CGSize(width: 264, height: 100)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            head
            canvasLayer
                .frame(height: MVMenu.Geo.sankeyHeight)
        }
        .padding(EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 12))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(hovering ? MVMenu.tileHover : MVMenu.tile)
        .clipShape(RoundedRectangle(cornerRadius: MVMenu.Geo.tileRadius))
        .overlay(
            RoundedRectangle(cornerRadius: MVMenu.Geo.tileRadius)
                .strokeBorder(MVMenu.hair, lineWidth: 0.5)
        )
        .animation(.easeOut(duration: 0.14), value: hovering)
        .onHover { hovering = $0 }
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
    }

    // MARK: - Header eyebrow + readout

    private var head: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Power Flow".uppercased())
                .font(.system(size: MVMenu.FS.micro, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(MVMenu.textFaint)

            HStack(spacing: 4) {
                Text(String(format: "%.1f", wallWatts))
                    .foregroundStyle(MVMenu.text)
                Text("W in")
                    .foregroundStyle(MVMenu.textDim)
                Text("·")
                    .foregroundStyle(MVMenu.textDim)
                Text(String(format: "%.1f", macWatts))
                    .foregroundStyle(MVMenu.text)
                Text("W draw")
                    .foregroundStyle(MVMenu.textDim)
                let delta = wallWatts - macWatts
                Text(String(format: "%+.1f", delta))
                    .foregroundStyle(MVMenu.power)
            }
            .font(.system(size: MVMenu.FS.caption, weight: .medium, design: .monospaced))
        }
    }

    // MARK: - Canvas (streams + nodes) + animated dashed flow overlay

    private var canvasLayer: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / logical.width,
                            geo.size.height / logical.height)
            let offsetX = (geo.size.width - logical.width * scale) / 2
            let offsetY = (geo.size.height - logical.height * scale) / 2

            ZStack {
                // Static filled streams + nodes.
                Canvas { ctx, _ in
                    ctx.translateBy(x: offsetX, y: offsetY)
                    ctx.scaleBy(x: scale, y: scale)
                    drawStreams(ctx: &ctx)
                    drawNodes(ctx: &ctx)
                }

                // Animated dashed flow lines — drift along each stream
                // centerline. Only animate while the popover is visible
                // AND motion is allowed; otherwise collapse to a static
                // snapshot so the TimelineView isn't scheduled at all.
                if reduceMotion || !isVisible {
                    Canvas { ctx, _ in
                        ctx.translateBy(x: offsetX, y: offsetY)
                        ctx.scaleBy(x: scale, y: scale)
                        drawFlowLines(ctx: &ctx, phase: 0)
                    }
                } else {
                    // .periodic is explicitly bounded to 30 Hz and does
                    // not try to chase the display link the way
                    // .animation(minimumInterval:) does.
                    // Intel: 5 Hz, Apple Silicon: 30 Hz.
                    #if arch(x86_64)
                    let _sankeyFps = 1.0 / 5.0
                    #else
                    let _sankeyFps = 1.0 / 30.0
                    #endif
                    TimelineView(.periodic(from: .now, by: _sankeyFps)) { timeline in
                        Canvas { ctx, _ in
                            ctx.translateBy(x: offsetX, y: offsetY)
                            ctx.scaleBy(x: scale, y: scale)
                            // 2.4s full cycle → dash offset walks 0 → −28.
                            let t = timeline.date.timeIntervalSinceReferenceDate
                            let phase = CGFloat(t.truncatingRemainder(dividingBy: 2.4) / 2.4) * 28
                            drawFlowLines(ctx: &ctx, phase: -phase)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Stream geometry (matches the HTML viewBox math)

    // All coordinates are in the 264×100 logical space from the mockup.
    // Source column:  x 8..34    → stream exits at x=34
    // Battery column: x 119..145 → stream enters at 119, exits at 145
    // Mac column:     x 230..256 → stream enters at 230

    private func wallStreamPath() -> Path {
        // Wall → Battery (wall watts, scaled 1W = 3px, clamped).
        let w = clampedHeight(wallWatts * 3, max: 50)
        let topY: CGFloat = 51 - w / 2
        let botY: CGFloat = 51 + w / 2
        var p = Path()
        p.move(to: CGPoint(x: 34, y: topY))
        p.addCurve(
            to: CGPoint(x: 119, y: 25),
            control1: CGPoint(x: 76, y: topY),
            control2: CGPoint(x: 76, y: 25)
        )
        p.addLine(to: CGPoint(x: 119, y: 25 + w))
        p.addCurve(
            to: CGPoint(x: 34, y: botY),
            control1: CGPoint(x: 76, y: 25 + w),
            control2: CGPoint(x: 76, y: botY)
        )
        p.closeSubpath()
        return p
    }

    /// Returns (path, centerline) for a battery→sink stream stacked at yStart.
    private func sinkStream(watts: Double, yStart: CGFloat) -> (Path, Path, CGFloat) {
        let h = clampedHeight(watts * 3, max: 40)
        var p = Path()
        p.move(to: CGPoint(x: 145, y: yStart))
        p.addCurve(
            to: CGPoint(x: 230, y: yStart + 4),
            control1: CGPoint(x: 188, y: yStart),
            control2: CGPoint(x: 188, y: yStart + 4)
        )
        p.addLine(to: CGPoint(x: 230, y: yStart + 4 + h))
        p.addCurve(
            to: CGPoint(x: 145, y: yStart + h),
            control1: CGPoint(x: 188, y: yStart + 4 + h),
            control2: CGPoint(x: 188, y: yStart + h)
        )
        p.closeSubpath()

        // Centerline for dashed flow-line overlay.
        var mid = Path()
        let midY1 = yStart + h / 2
        let midY2 = yStart + 4 + h / 2
        mid.move(to: CGPoint(x: 145, y: midY1))
        mid.addCurve(
            to: CGPoint(x: 230, y: midY2),
            control1: CGPoint(x: 188, y: midY1),
            control2: CGPoint(x: 188, y: midY2)
        )
        return (p, mid, h)
    }

    private func drawStreams(ctx: inout GraphicsContext) {
        // Wall → battery — full flow, highest opacity.
        ctx.fill(wallStreamPath(), with: .color(MVMenu.power.opacity(0.50)))

        // Stack battery→sink streams top-to-bottom, total height ~55.
        var y: CGFloat = 25
        let pieces: [(Double, Double)] = [
            (cpuWatts,  0.52),
            (gpuWatts,  0.30),
            (dramWatts, 0.24),
            (usbWatts,  0.18)
        ]
        for (watts, opacity) in pieces where watts > 0 {
            let (path, _, h) = sinkStream(watts: watts, yStart: y)
            ctx.fill(path, with: .color(MVMenu.power.opacity(opacity)))
            y += h + 4
        }
    }

    private func drawFlowLines(ctx: inout GraphicsContext, phase: CGFloat) {
        let dash = StrokeStyle(
            lineWidth: 0.9,
            lineCap: .round,
            dash: [5, 9],
            dashPhase: phase
        )

        // Wall flow.
        var wallMid = Path()
        wallMid.move(to: CGPoint(x: 34, y: 51))
        wallMid.addCurve(
            to: CGPoint(x: 119, y: 52.5),
            control1: CGPoint(x: 76, y: 51),
            control2: CGPoint(x: 76, y: 52.5)
        )
        ctx.stroke(wallMid, with: .color(MVMenu.power.opacity(0.55)), style: dash)

        var y: CGFloat = 25
        let pieces: [(Double, CGFloat)] = [
            (cpuWatts, 0.55),
            (gpuWatts, 0.38),
            (dramWatts, 0.38),
            (usbWatts, 0.38)
        ]
        let thinDash = StrokeStyle(
            lineWidth: 0.55,
            lineCap: .round,
            dash: [5, 9],
            dashPhase: phase
        )
        for (idx, pair) in pieces.enumerated() where pair.0 > 0 {
            let (_, mid, h) = sinkStream(watts: pair.0, yStart: y)
            let style = idx == 0 ? dash : thinDash
            ctx.stroke(mid, with: .color(MVMenu.power.opacity(pair.1)), style: style)
            y += h + 4
        }
    }

    private func drawNodes(ctx: inout GraphicsContext) {
        // Wall
        drawNode(ctx: &ctx,
                 x: 8,
                 label: "Wall",
                 value: String(format: "%.1fW", wallWatts),
                 fillTop: 29,
                 fillBottom: 73)

        // Battery (fill proportional to SoC)
        let fillHeight = max(8, 64 * CGFloat(batteryFraction))
        let fillTop: CGFloat = 18 + (64 - fillHeight)
        drawNode(ctx: &ctx,
                 x: 119,
                 label: "Battery",
                 value: "\(Int(batteryFraction * 100))%",
                 fillTop: fillTop,
                 fillBottom: 82)

        // Mac (sink)
        drawNode(ctx: &ctx,
                 x: 230,
                 label: "Mac",
                 value: String(format: "%.1fW", macWatts),
                 fillTop: 29,
                 fillBottom: 84)
    }

    private func drawNode(
        ctx: inout GraphicsContext,
        x: CGFloat,
        label: String,
        value: String,
        fillTop: CGFloat,
        fillBottom: CGFloat
    ) {
        let frame = CGRect(x: x, y: 18, width: 26, height: 64)
        let framePath = Path(roundedRect: frame, cornerRadius: 3)
        ctx.fill(framePath, with: .color(Color.white.opacity(0.025)))
        ctx.stroke(framePath, with: .color(MVMenu.hairStrong), lineWidth: 1)

        let fill = CGRect(x: x, y: fillTop, width: 26, height: fillBottom - fillTop)
        let fillPath = Path(roundedRect: fill, cornerRadius: 2)
        ctx.fill(fillPath, with: .color(MVMenu.power.opacity(0.16)))
        ctx.stroke(fillPath, with: .color(MVMenu.power.opacity(0.55)), lineWidth: 0.8)

        // Top label
        ctx.draw(
            Text(label.uppercased())
                .font(.system(size: 7.5, weight: .regular))
                .foregroundColor(MVMenu.textFaint),
            at: CGPoint(x: x + 13, y: 12),
            anchor: .center
        )

        // Bottom value
        ctx.draw(
            Text(value)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(MVMenu.text),
            at: CGPoint(x: x + 13, y: 93),
            anchor: .center
        )
    }

    private func clampedHeight(_ raw: Double, max upper: Double) -> CGFloat {
        CGFloat(min(max(raw, 1), upper))
    }

    private var accessibilityText: String {
        "Power flow: \(Int(wallWatts)) watts in from wall, \(Int(macWatts)) watts draw. " +
        "CPU \(String(format: "%.1f", cpuWatts)), GPU \(String(format: "%.1f", gpuWatts)), " +
        "DRAM \(String(format: "%.1f", dramWatts)), USB \(String(format: "%.1f", usbWatts))."
    }
}

#Preview("Sankey") {
    SankeyPowerFlow(
        wallWatts: 14.8,
        macWatts: 14.4,
        cpuWatts: 10.9,
        gpuWatts: 2.1,
        dramWatts: 1.1,
        usbWatts: 0.3,
        batteryFraction: 0.87
    )
    .padding(16)
    .frame(width: MVMenu.Geo.popWidth)
    .background(MVMenu.popBg)
}

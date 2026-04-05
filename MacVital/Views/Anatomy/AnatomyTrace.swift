// MacVital/Views/Anatomy/AnatomyTrace.swift
//
// Animated polyline trace connecting a chassis anchor to a perimeter
// component block. Mirrors the four `.trace-*` CSS classes from the Fusion
// hero mockup and the `march-fwd` / `march-rev` keyframe animations.
//
// Source mockup: mockups/redesign-2026-04-23/anatomy/fusion-1-bento-schematic.html
//
// Approach:
//   - Path is built from a list of CGPoints (axis-aligned segments). The
//     HTML traces are all `M x y L x y L x y` style polylines, never curves.
//   - The dash march is driven by `TimelineView(.periodic)`, mirroring
//     SankeyPowerFlow.swift. We compute the dash phase from
//     `timeline.date.timeIntervalSinceReferenceDate` so the animation
//     survives view re-creation.
//   - SwiftUI's `Animation.linear(duration:).repeatForever` does NOT animate
//     `StrokeStyle.dashPhase` reliably across all macOS versions. Driving
//     the phase manually from a TimelineView is the existing project pattern
//     (see SankeyPowerFlow.swift) and is the chosen approach here.
//   - When `isHighlighted` is true the cycle compresses to 0.8s and opacity
//     jumps to 1.0. Idle uses the kind-specific duration (1.6 / 2.2 / 2.6
//     / 2.0 s) and opacity 0.45.
//
// Reduced motion: if the parent passes `motionEnabled: false` the trace
// renders as a static dashed line at idle opacity. The TimelineView is
// not scheduled at all in that branch.

import SwiftUI

// MARK: - Shared dash phase environment

/// Single 30Hz timer drives every AnatomyTrace via this Environment value.
/// Previously each trace owned its own TimelineView(.periodic, by: 1/30),
/// which meant 10+ independent 30Hz schedulers running concurrently. Now a
/// parent (e.g. AnatomyView) sets `.dashPhase` from one shared TimelineView
/// and every child reads it.
///
/// Value semantics: monotonically increasing seconds since reference date,
/// truncated to a manageable window. Each trace converts this base time
/// into its own kind-specific phase using its dash sum and cycle.
private struct DashPhaseEnvironmentKey: EnvironmentKey {
    static let defaultValue: Double = 0.0
}

extension EnvironmentValues {
    /// Shared monotonic time used to derive per-trace dash phase. Set this
    /// on the AnatomyView root from a single TimelineView. Default 0 keeps
    /// previews and standalone use sites static (no animation).
    var dashPhase: Double {
        get { self[DashPhaseEnvironmentKey.self] }
        set { self[DashPhaseEnvironmentKey.self] = newValue }
    }
}

/// Wrapper view to be used by the parent AnatomyView. Wraps content in a
/// single 30Hz TimelineView and injects `\.dashPhase` so all child traces
/// share one ticker.
///
/// AnatomyView (out of scope for this change) should adopt:
///
///     AnatomySharedDashPhase(motionEnabled: motionEnabled) {
///         // existing trace + chassis content
///     }
///
/// TODO(AnatomyView): wrap the existing chassis ZStack in
/// `AnatomySharedDashPhase` and remove the per-trace TimelineView path
/// once AnatomyView is updated. Until then, AnatomyTrace falls back to a
/// local TimelineView only when `\.dashPhase` is the default value of 0.
struct AnatomySharedDashPhase<Content: View>: View {
    let motionEnabled: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        if motionEnabled {
            // Intel hosts: throttle dash phase to 5 Hz (was 30 Hz).
            // Apple Silicon efficiency cores can absorb 30 Hz; Intel cannot.
            #if arch(x86_64)
            let _dashFps = 1.0 / 5.0
            #else
            let _dashFps = 1.0 / 30.0
            #endif
            TimelineView(.periodic(from: .now, by: _dashFps)) { timeline in
                content()
                    .environment(\.dashPhase, timeline.date.timeIntervalSinceReferenceDate)
            }
        } else {
            content()
                .environment(\.dashPhase, 0.0)
        }
    }
}

// MARK: - AnatomyTraceStyle

/// Per-kind dash pattern + base cycle duration. Pulled from the CSS
/// `.trace-*` selectors in the source mockup.
struct AnatomyTraceStyle {
    let dash: [CGFloat]
    let lineWidth: CGFloat
    let baseCycle: Double      // seconds, idle
    let highlightCycle: Double // seconds, hover or pin
    let direction: Direction

    enum Direction {
        case forward   // matches CSS keyframes `march-fwd`
        case reverse   // matches CSS keyframes `march-rev`
    }

    static func style(for kind: AnatomyTraceKind) -> AnatomyTraceStyle {
        switch kind {
        case .power:
            return .init(dash: [6, 5], lineWidth: 1.2,
                         baseCycle: 1.6, highlightCycle: 0.8, direction: .forward)
        case .data:
            return .init(dash: [5, 6], lineWidth: 1.0,
                         baseCycle: 2.2, highlightCycle: 0.8, direction: .reverse)
        case .thermal:
            return .init(dash: [4, 7], lineWidth: 1.0,
                         baseCycle: 2.6, highlightCycle: 0.8, direction: .forward)
        case .rf:
            return .init(dash: [3, 8], lineWidth: 1.0,
                         baseCycle: 2.0, highlightCycle: 0.8, direction: .forward)
        }
    }
}

// MARK: - AnatomyTrace

/// One animated trace polyline.
///
/// `points` is an ordered list of waypoints in the parent reference space
/// (1336 x 504). The view draws a piecewise straight line through them and
/// applies a dash march that loops along the path.
struct AnatomyTrace: View {

    /// Waypoints, anchor first and block-edge last.
    let points: [CGPoint]

    /// Power, data, thermal, or rf. Drives colour and dash spec.
    let kind: AnatomyTraceKind

    /// True when this trace's component is hovered or pinned. Brightens the
    /// stroke and shortens the cycle.
    let isHighlighted: Bool

    /// True when the trace should cross-dim because a category filter is on
    /// and this trace's component is not in the active category. Mirrors the
    /// HTML `.has-cat-filter` rule.
    let isDimmed: Bool

    /// When false, the dash phase freezes at zero. Used for previews and
    /// for the system-level reduce-motion accessibility setting.
    let motionEnabled: Bool

    @Environment(\.dashPhase) private var sharedDashPhase: Double

    init(points: [CGPoint],
         kind: AnatomyTraceKind,
         isHighlighted: Bool,
         isDimmed: Bool = false,
         motionEnabled: Bool = true) {
        self.points = points
        self.kind = kind
        self.isHighlighted = isHighlighted
        self.isDimmed = isDimmed
        self.motionEnabled = motionEnabled
    }

    var body: some View {
        let style = AnatomyTraceStyle.style(for: kind)
        let cycle = isHighlighted ? style.highlightCycle : style.baseCycle
        let dashSum = style.dash.reduce(0, +)

        Group {
            if motionEnabled && sharedDashPhase != 0 {
                // Shared 30Hz tick from AnatomySharedDashPhase. Each trace
                // computes its own kind-specific phase from one common time.
                let cyclePhase = sharedDashPhase.truncatingRemainder(dividingBy: cycle) / cycle
                let signed: CGFloat = style.direction == .forward
                    ? -CGFloat(cyclePhase) * dashSum
                    :  CGFloat(cyclePhase) * dashSum
                traceShape(dashPhase: signed, style: style)
            } else if motionEnabled {
                // Fallback: parent has not adopted AnatomySharedDashPhase yet.
                // Run a local TimelineView so motion still works, but this
                // path should be retired once AnatomyView wraps its content.
                // TODO(AnatomyView): remove this branch once parent wraps in
                // AnatomySharedDashPhase. Ten+ traces with their own 30Hz
                // schedulers is the perf hotspot this fix targets.
                // Intel hosts: throttle dash phase to 5 Hz (was 30 Hz).
            // Apple Silicon efficiency cores can absorb 30 Hz; Intel cannot.
                #if arch(x86_64)
                let _fbFps = 1.0 / 5.0
                #else
                let _fbFps = 1.0 / 30.0
                #endif
                TimelineView(.periodic(from: .now, by: _fbFps)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    let cyclePhase = t.truncatingRemainder(dividingBy: cycle) / cycle
                    let signed: CGFloat = style.direction == .forward
                        ? -CGFloat(cyclePhase) * dashSum
                        :  CGFloat(cyclePhase) * dashSum
                    traceShape(dashPhase: signed, style: style)
                }
            } else {
                // Reduced motion: static dashed line.
                traceShape(dashPhase: 0, style: style)
            }
        }
    }

    // MARK: - Shape rendering

    @ViewBuilder
    private func traceShape(dashPhase: CGFloat, style: AnatomyTraceStyle) -> some View {
        polyline()
            .stroke(
                kind.color,
                style: StrokeStyle(
                    lineWidth: isHighlighted ? style.lineWidth + 0.3 : style.lineWidth,
                    lineCap: .square,
                    lineJoin: .miter,
                    dash: style.dash,
                    dashPhase: dashPhase
                )
            )
            .opacity(opacity)
            .animation(.easeOut(duration: 0.15), value: isDimmed)
            .animation(.easeOut(duration: 0.15), value: isHighlighted)
            .allowsHitTesting(false)
    }

    private func polyline() -> Path {
        var p = Path()
        guard let first = points.first else { return p }
        p.move(to: first)
        for next in points.dropFirst() {
            p.addLine(to: next)
        }
        return p
    }

    private var opacity: Double {
        if isDimmed { return 0.18 }
        if isHighlighted { return 1.0 }
        return 0.45
    }
}

// MARK: - AnatomyTraceLegend

/// Legend block pinned to the bottom-left of the hero canvas. Renders four
/// short dashed strokes (Power / Data / Thermal / RF) labelled in mono.
/// Coordinates intentionally match the SVG `<g id="legend">` block so it
/// drops in at the same reference-space position.
struct AnatomyTraceLegend: View {

    let motionEnabled: Bool

    init(motionEnabled: Bool = true) {
        self.motionEnabled = motionEnabled
    }

    // Plate geometry (reference space).
    private let plateX: CGFloat = 14
    private let plateY: CGFloat = 424
    private let plateW: CGFloat = 162
    private let plateH: CGFloat = 72

    var body: some View {
        ZStack(alignment: .topLeading) {

            // Background plate.
            RoundedRectangle(cornerRadius: 6)
                .fill(MV.bg)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(MV.hairline, lineWidth: 0.6)
                )
                .frame(width: plateW, height: plateH)
                .position(x: plateX + plateW / 2, y: plateY + plateH / 2)

            // Title.
            Text("TRACES")
                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(MV.text3)
                .position(x: plateX + 20, y: plateY + 12)

            // Hairline under title.
            Rectangle()
                .fill(MV.hairline)
                .frame(width: plateW - 24, height: 0.5)
                .position(x: plateX + plateW / 2, y: plateY + 22)

            // 2x2 grid of kind rows.
            // Row 1: Power (left), Thermal (right).
            // Row 2: Data  (left), RF      (right).
            legendRow(kind: .power,   label: "POWER",   col: 0, row: 0)
            legendRow(kind: .thermal, label: "THERMAL", col: 1, row: 0)
            legendRow(kind: .data,    label: "DATA",    col: 0, row: 1)
            legendRow(kind: .rf,      label: "RF",      col: 1, row: 1)
        }
        .frame(width: AnatomyChassisGeometry.referenceWidth,
               height: AnatomyChassisGeometry.referenceHeight,
               alignment: .topLeading)
        .allowsHitTesting(false)
    }

    /// 2-column grid. col in {0,1}, row in {0,1}. Each cell: left-aligned
    /// 22pt colored dashed stroke, 6pt gap, label in mono uppercase.
    private func legendRow(kind: AnatomyTraceKind, label: String, col: Int, row: Int) -> some View {
        let cellW: CGFloat = (plateW - 24) / 2
        let cellOriginX = plateX + 12 + CGFloat(col) * cellW
        let cellY = plateY + 36 + CGFloat(row) * 18

        let strokeStart = cellOriginX
        let strokeEnd = cellOriginX + 22

        return ZStack(alignment: .topLeading) {
            // Colored dashed stroke sample (horizontal, 22pt wide).
            AnatomyTrace(
                points: [
                    CGPoint(x: strokeStart, y: cellY),
                    CGPoint(x: strokeEnd,   y: cellY)
                ],
                kind: kind,
                isHighlighted: false,
                motionEnabled: motionEnabled
            )
            .frame(width: AnatomyChassisGeometry.referenceWidth,
                   height: AnatomyChassisGeometry.referenceHeight,
                   alignment: .topLeading)

            // Label to the right of the stroke, leading-aligned.
            Text(label)
                .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(MV.text2)
                .fixedSize()
                .position(x: strokeEnd + 6 + labelHalfWidth(label), y: cellY + 1)
        }
        .allowsHitTesting(false)
    }

    /// Roughly half the rendered width of a mono 8.5pt label. Uses a
    /// 5.0pt per-glyph average which matches SF Mono Semibold at this size.
    private func labelHalfWidth(_ s: String) -> CGFloat {
        CGFloat(s.count) * 5.0 / 2.0
    }
}

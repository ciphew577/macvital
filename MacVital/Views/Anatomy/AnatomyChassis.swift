// MacVital/Views/Anatomy/AnatomyChassis.swift
//
// Pure SwiftUI Path rendering of the MacBook chassis for the Anatomy hero.
//
// Source mockup: mockups/redesign-2026-04-23/anatomy/fusion-1-bento-schematic.html
//
// Reference space is the SVG viewBox 1336 x 504. The HTML wraps the original
// 540 x 380 chassis (centred at 668, 252) in a scale of 1.32, giving
// effective bounds roughly x 311.6 to 1024.4, y 1.84 to 503.44. Every path
// in this file is pre-multiplied into that post-scale reference space so the
// parent can simply apply a uniform scale factor via GeometryReader.
//
// Visibility note: every interior component renders at LEAST a tinted fill
// plus its decorative sub-shapes (fan blades, NAND chips, IC pin ticks,
// speaker slot lines, antenna radiating lines, battery liquid bars, etc.)
// so the chassis interior actually looks alive at default zoom levels. The
// HTML uses very low opacities (0.06 to 0.22) which read fine on a wide
// SVG canvas but dissolve into nothing under SwiftUI rasterisation, so the
// fills here use slightly punchier values.

import SwiftUI

// MARK: - AnatomyChassisGeometry

/// Canonical coordinate space for every chassis and component shape.
/// Matches the SVG `viewBox="0 0 1336 504"` in the source mockup.
enum AnatomyChassisGeometry {

    static let referenceWidth: CGFloat = 1336
    static let referenceHeight: CGFloat = 504

    /// Post-scale chassis bounding rect in reference space.
    static let chassisRect: CGRect = CGRect(
        x: 311.6, y: 1.84, width: 712.8, height: 501.6
    )
    static let chassisCornerRadius: CGFloat = 18.48

    static let innerRect: CGRect = CGRect(
        x: 324.8, y: 15.04, width: 686.4, height: 475.2
    )
    static let innerCornerRadius: CGFloat = 13.2

    /// Anchor points called out in the mockup, post-scale.
    enum Anchor {
        static let u1  = CGPoint(x: 668.0,   y: 132.2)
        static let fan1 = CGPoint(x: 404.0,  y: 114.7)
        static let fan2 = CGPoint(x: 931.8,  y: 114.7)
        static let ant1 = CGPoint(x: 330.1,  y: 14.4)
        static let bt1  = CGPoint(x: 498.4,  y: 357.6)
        static let ic1  = CGPoint(x: 393.4,  y: 299.5)
        static let spk1 = CGPoint(x: 324.8,  y: 183.4)
        static let u3   = CGPoint(x: 842.2,  y: 220.3)
        static let lcd1 = CGPoint(x: 1024.4, y: 104.2)
        static let ant2 = CGPoint(x: 1005.9, y: 14.4)
    }

    enum BlockAnchor {
        static let u1   = CGPoint(x: 1172, y: 44)
        static let fan1 = CGPoint(x: 164,  y: 110)
        static let fan2 = CGPoint(x: 1172, y: 124)
        static let ant1 = CGPoint(x: 164,  y: 35)
        static let bt1  = CGPoint(x: 164,  y: 202)
        static let ic1  = CGPoint(x: 164,  y: 294)
        static let spk1 = CGPoint(x: 164,  y: 390)
        static let u3   = CGPoint(x: 1172, y: 210)
        static let lcd1 = CGPoint(x: 1172, y: 296)
        static let ant2 = CGPoint(x: 1172, y: 382)
    }
}

// MARK: - Component palette

/// Per-component HTML palette pulled from the mockup. Every chassis fill
/// here is drawn at higher opacity than the HTML defaults so the shapes
/// stay legible at SwiftUI rendering scale.
private enum CC {
    static let amber    = Color(red: 0.753, green: 0.565, blue: 0.251) // #C09040
    static let sage     = Color(red: 0.561, green: 0.682, blue: 0.600) // #8FAE99
    static let blue     = Color(red: 0.482, green: 0.584, blue: 0.753) // #7B95C0
    static let purple   = Color(red: 0.608, green: 0.541, blue: 0.769) // #9B8AC4
    static let teal     = Color(red: 0.482, green: 0.753, blue: 0.690) // #7BC0B0
    static let chassisFillTop = Color(white: 0.06).opacity(0.55)
}

// MARK: - Post-scale helper

/// Applies the HTML chassis transform `translate(-213.76, -80.64) scale(1.32)`.
private func ps(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
    CGPoint(x: x * 1.32 - 213.76, y: y * 1.32 - 80.64)
}

private func psRect(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) -> CGRect {
    let o = ps(x, y)
    return CGRect(x: o.x, y: o.y, width: w * 1.32, height: h * 1.32)
}

// MARK: - Shape paths for each chassis-side component

enum AnatomyChassisPaths {

    static func chassisOuter() -> Path {
        Path(roundedRect: AnatomyChassisGeometry.chassisRect,
             cornerRadius: AnatomyChassisGeometry.chassisCornerRadius)
    }

    static func chassisInner() -> Path {
        Path(roundedRect: AnatomyChassisGeometry.innerRect,
             cornerRadius: AnatomyChassisGeometry.innerCornerRadius)
    }

    static func hingeLine() -> Path {
        var p = Path()
        p.move(to: ps(398, 86))
        p.addLine(to: ps(938, 86))
        return p
    }

    static func trackpad() -> Path {
        let r = psRect(x: 588, y: 376, w: 160, h: 50)
        return Path(roundedRect: r, cornerRadius: 5 * 1.32)
    }

    static func keyboardZone() -> Path {
        let r = psRect(x: 418, y: 270, w: 500, h: 100)
        return Path(roundedRect: r, cornerRadius: 4 * 1.32)
    }

    static func centerMark() -> Path {
        let c = ps(668, 190)
        let r: CGFloat = 2 * 1.32
        return Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
    }

    // MARK: Component hit-target / outer paths

    static func u1Outer() -> Path {
        let r = psRect(x: 600, y: 172, w: 136, h: 80)
        return Path(roundedRect: r, cornerRadius: 5 * 1.32)
    }

    static func u1DieGrid() -> [Path] {
        [
            Path(roundedRect: psRect(x: 608, y: 180, w: 38, h: 32), cornerRadius: 2 * 1.32),
            Path(roundedRect: psRect(x: 608, y: 216, w: 38, h: 32), cornerRadius: 2 * 1.32),
            Path(roundedRect: psRect(x: 650, y: 180, w: 40, h: 68), cornerRadius: 2 * 1.32),
            Path(roundedRect: psRect(x: 694, y: 180, w: 38, h: 32), cornerRadius: 2 * 1.32),
            Path(roundedRect: psRect(x: 694, y: 216, w: 38, h: 32), cornerRadius: 2 * 1.32)
        ]
    }

    static func fan1() -> Path {
        let c = ps(468, 200)
        let r: CGFloat = 48 * 1.32
        return Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
    }
    static func fan2() -> Path {
        let c = ps(868, 200)
        let r: CGFloat = 48 * 1.32
        return Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
    }

    static func ant1() -> Path {
        let r = psRect(x: 408, y: 64, w: 14, h: 14)
        return Path(roundedRect: r, cornerRadius: 2 * 1.32)
    }
    static func ant2() -> Path {
        let r = psRect(x: 916, y: 64, w: 14, h: 14)
        return Path(roundedRect: r, cornerRadius: 2 * 1.32)
    }

    static func bt1Cells() -> [Path] {
        [
            Path(roundedRect: psRect(x: 448, y: 290, w: 148, h: 80), cornerRadius: 3 * 1.32),
            Path(roundedRect: psRect(x: 600, y: 290, w: 148, h: 80), cornerRadius: 3 * 1.32),
            Path(roundedRect: psRect(x: 752, y: 290, w: 148, h: 80), cornerRadius: 3 * 1.32)
        ]
    }
    static func bt1LiquidBars() -> [Path] {
        [
            Path(roundedRect: psRect(x: 452, y: 304, w: 140, h: 62), cornerRadius: 2 * 1.32),
            Path(roundedRect: psRect(x: 604, y: 304, w: 140, h: 62), cornerRadius: 2 * 1.32),
            Path(roundedRect: psRect(x: 756, y: 304, w: 140, h: 62), cornerRadius: 2 * 1.32)
        ]
    }

    static func ic1() -> Path {
        let r = psRect(x: 450, y: 278, w: 20, h: 20)
        return Path(roundedRect: r, cornerRadius: 3 * 1.32)
    }

    static func spk1Bars() -> [Path] {
        [
            Path(roundedRect: psRect(x: 406, y: 174, w: 14, h: 58), cornerRadius: 2 * 1.32),
            Path(roundedRect: psRect(x: 916, y: 174, w: 14, h: 58), cornerRadius: 2 * 1.32)
        ]
    }

    static func u3() -> Path {
        let r = psRect(x: 752, y: 172, w: 88, h: 50)
        return Path(roundedRect: r, cornerRadius: 3 * 1.32)
    }

    static func lcd1() -> Path {
        let r = psRect(x: 900, y: 130, w: 36, h: 20)
        return Path(roundedRect: r, cornerRadius: 3 * 1.32)
    }

    // MARK: - Sub-shape generators

    /// 7 fan blade arcs around `(cx, cy)` matching the HTML M, L, A path
    /// pattern. Each blade is a triangular slice from hub to outer arc.
    static func fanBlades(cx: CGFloat, cy: CGFloat) -> [Path] {
        let outer: CGFloat = 44
        // 7 evenly spaced angle pairs from the HTML, expressed as
        // (start_angle_deg, end_angle_deg) measured clockwise from 12 o'clock.
        let blades: [(CGFloat, CGFloat)] = [
            (350, 22),   // 12 -> 1
            (22, 73),
            (73, 124),
            (124, 175),
            (175, 226),
            (226, 277),
            (277, 350)
        ]
        return blades.map { pair in
            var p = Path()
            let center = ps(cx, cy)
            p.move(to: center)
            // Convert "angle from 12 o'clock clockwise" to standard math
            // (angle from 3 o'clock counter-clockwise).
            let a1 = (pair.0 - 90) * .pi / 180
            let a2 = (pair.1 - 90) * .pi / 180
            let r = outer * 1.32
            let p1 = CGPoint(x: center.x + r * cos(a1), y: center.y + r * sin(a1))
            p.addLine(to: p1)
            // Arc along outer ring to the next blade angle.
            p.addArc(center: center, radius: r,
                     startAngle: Angle(radians: a1),
                     endAngle: Angle(radians: a2),
                     clockwise: false)
            p.closeSubpath()
            return p
        }
    }

    /// Fan motor hub: outer ring r=12, centre dot r=2.
    static func fanHubRing(cx: CGFloat, cy: CGFloat) -> Path {
        let c = ps(cx, cy)
        let r: CGFloat = 12 * 1.32
        return Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
    }
    static func fanHubDot(cx: CGFloat, cy: CGFloat) -> Path {
        let c = ps(cx, cy)
        let r: CGFloat = 2 * 1.32
        return Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
    }

    /// SSD chip rects: 4 NAND chips (10x14) + 1 controller (16x10).
    static func ssdNandChips() -> [Path] {
        [
            Path(roundedRect: psRect(x: 758, y: 178, w: 10, h: 14), cornerRadius: 1 * 1.32),
            Path(roundedRect: psRect(x: 772, y: 178, w: 10, h: 14), cornerRadius: 1 * 1.32),
            Path(roundedRect: psRect(x: 758, y: 200, w: 10, h: 14), cornerRadius: 1 * 1.32),
            Path(roundedRect: psRect(x: 772, y: 200, w: 10, h: 14), cornerRadius: 1 * 1.32)
        ]
    }
    static func ssdControllerChip() -> Path {
        Path(roundedRect: psRect(x: 816, y: 180, w: 16, h: 10), cornerRadius: 1 * 1.32)
    }

    /// IC1 pin ticks: 4 per edge, 16 total.
    static func ic1Pins() -> [Path] {
        var paths: [Path] = []
        // Top edge: 4 ticks at x=454,458,462,466 from y=276 to 278
        for x in stride(from: CGFloat(454), through: 466, by: 4) {
            var p = Path(); p.move(to: ps(x, 276)); p.addLine(to: ps(x, 278)); paths.append(p)
        }
        // Bottom edge: 298 -> 300
        for x in stride(from: CGFloat(454), through: 466, by: 4) {
            var p = Path(); p.move(to: ps(x, 298)); p.addLine(to: ps(x, 300)); paths.append(p)
        }
        // Left edge: y=282..294, x=448..450
        for y in stride(from: CGFloat(282), through: 294, by: 4) {
            var p = Path(); p.move(to: ps(448, y)); p.addLine(to: ps(450, y)); paths.append(p)
        }
        // Right edge: y=282..294, x=470..472
        for y in stride(from: CGFloat(282), through: 294, by: 4) {
            var p = Path(); p.move(to: ps(470, y)); p.addLine(to: ps(472, y)); paths.append(p)
        }
        return paths
    }

    /// Left speaker slot lines: 8 horizontal slots at y=180,186,192...222.
    static func spk1LeftSlots() -> [Path] {
        var out: [Path] = []
        for y in stride(from: CGFloat(180), through: 222, by: 6) {
            var p = Path(); p.move(to: ps(408, y)); p.addLine(to: ps(418, y)); out.append(p)
        }
        return out
    }
    static func spk1RightSlots() -> [Path] {
        var out: [Path] = []
        for y in stride(from: CGFloat(180), through: 222, by: 6) {
            var p = Path(); p.move(to: ps(918, y)); p.addLine(to: ps(928, y)); out.append(p)
        }
        return out
    }

    /// Antenna 1 radiating lines from (410, 76).
    static func ant1Lines() -> [Path] {
        var p1 = Path(); p1.move(to: ps(410, 76)); p1.addLine(to: ps(416, 68))
        var p2 = Path(); p2.move(to: ps(410, 76)); p2.addLine(to: ps(420, 66))
        return [p1, p2]
    }
    static func ant1Dot() -> Path {
        let c = ps(410, 76)
        let r: CGFloat = 0.9 * 1.32
        return Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
    }
    static func ant2Lines() -> [Path] {
        var p1 = Path(); p1.move(to: ps(928, 76)); p1.addLine(to: ps(922, 68))
        var p2 = Path(); p2.move(to: ps(928, 76)); p2.addLine(to: ps(918, 66))
        return [p1, p2]
    }
    static func ant2Dot() -> Path {
        let c = ps(928, 76)
        let r: CGFloat = 0.9 * 1.32
        return Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
    }

    /// Display inner panel.
    static func lcd1InnerPanel() -> Path {
        Path(roundedRect: psRect(x: 903, y: 133, w: 30, h: 14), cornerRadius: 1 * 1.32)
    }
    /// Display reflection highlight.
    static func lcd1Reflection() -> Path {
        var p = Path()
        p.move(to: ps(904, 135))
        p.addLine(to: ps(932, 135))
        return p
    }

    /// Battery cell separator dashed lines.
    static func bt1Separators() -> [Path] {
        var p1 = Path(); p1.move(to: ps(598, 294)); p1.addLine(to: ps(598, 366))
        var p2 = Path(); p2.move(to: ps(750, 294)); p2.addLine(to: ps(750, 366))
        return [p1, p2]
    }
    /// "+" terminal at (905, 326).
    static func bt1PlusTerminal() -> [Path] {
        var h = Path(); h.move(to: ps(902, 326)); h.addLine(to: ps(908, 326))
        var v = Path(); v.move(to: ps(905, 323)); v.addLine(to: ps(905, 329))
        return [h, v]
    }
}

// MARK: - AnatomyChassisShape

/// The non-interactive chassis backdrop: outline, inner cutline, hinge,
/// trackpad, keyboard zone, centre mark, and static micro labels.
struct AnatomyChassisShape: View {

    var body: some View {
        ZStack {

            // Fill: tile-deep at 0.7 opacity per CSS `.chassis-fill`.
            AnatomyChassisPaths.chassisOuter()
                .fill(MV.bg.opacity(0.7))

            // Outer stroke.
            AnatomyChassisPaths.chassisOuter()
                .stroke(MV.hairlineStrong, lineWidth: 1.1)

            // Inner rect hairline.
            AnatomyChassisPaths.chassisInner()
                .stroke(MV.hairline, lineWidth: 0.6)

            // Hinge line.
            AnatomyChassisPaths.hingeLine()
                .stroke(MV.hairline, lineWidth: 0.6)

            // Trackpad outline.
            AnatomyChassisPaths.trackpad()
                .stroke(MV.hairline, lineWidth: 0.6)

            // Dashed keyboard zone.
            AnatomyChassisPaths.keyboardZone()
                .stroke(MV.hairline, style: StrokeStyle(lineWidth: 0.6, dash: [3, 4]))

            // Small centre mark circle.
            AnatomyChassisPaths.centerMark()
                .stroke(Color.white.opacity(0.10), lineWidth: 0.7)

            // Non-interactive micro labels inside the chassis.
            microLabels
        }
    }

    private var microLabels: some View {
        ZStack {
            chassisLabel("FAN L", at: ps(468, 178))
            chassisLabel("FAN R", at: ps(868, 178))
            chassisLabel("BATTERY 3 CELL", at: ps(668, 332))
            chassisLabel("U1 SoC", at: ps(668, 178))
        }
        .allowsHitTesting(false)
    }

    private func chassisLabel(_ text: String, at p: CGPoint) -> some View {
        Text(text)
            .font(.system(size: 8 * 1.32, design: .monospaced))
            .tracking(1.1)
            .foregroundStyle(MV.text4)
            .position(p)
    }
}

// MARK: - AnatomyChassisInterior

/// Draws all interior component shapes with VISIBLE fills + decoration so
/// every component reads at default zoom, not just thin hairlines.
///
/// Hit testing: every component drawn here is paired with a transparent
/// `Path`-shaped hit overlay drawn IN THE SAME ZStack at the SAME absolute
/// chassis reference coordinates. The hit overlay uses `.contentShape(path)`
/// so the hover/tap area matches the visible art's outline exactly, then
/// the parent `scaleEffect` in AnatomyHero scales art and hit zones in
/// lock-step. Multi-shape components (battery 3 cells, speaker 2 bars)
/// emit ONE hit overlay per visible sub-shape so empty chassis space never
/// triggers a hit.
struct AnatomyChassisInterior: View {

    let highlightID: AnatomyComponentID?
    let dimmedIDs: Set<AnatomyComponentID>
    let onHover: (AnatomyComponentID?) -> Void
    let onTap: (AnatomyComponentID) -> Void

    @State private var lastReportedID: AnatomyComponentID?

    var body: some View {
        ZStack {

            // Visible art layer. Non-interactive, so hit tests pass through
            // to the dedicated hit overlays below.
            visibleArt
                .allowsHitTesting(false)

            // Hit-target layer. Each overlay is a transparent fill of the
            // visible Path with .contentShape applied so SwiftUI hit-tests
            // against the actual visible geometry (not a bounding rect that
            // could drift under scaleEffect).
            hitOverlays
        }
        .animation(.easeOut(duration: 0.15), value: highlightID)
        .animation(.easeOut(duration: 0.15), value: dimmedIDs)
    }

    // MARK: - Visible art

    @ViewBuilder
    private var visibleArt: some View {
        ZStack {
            u1
                .opacity(dimmedIDs.contains(.u1) ? 0.25 : 1.0)
            fanGroup(.fan1, cx: 468, cy: 200)
                .opacity(dimmedIDs.contains(.fan1) ? 0.25 : 1.0)
            fanGroup(.fan2, cx: 868, cy: 200)
                .opacity(dimmedIDs.contains(.fan2) ? 0.25 : 1.0)
            antenna(.ant1)
                .opacity(dimmedIDs.contains(.ant1) ? 0.25 : 1.0)
            antenna(.ant2)
                .opacity(dimmedIDs.contains(.ant2) ? 0.25 : 1.0)
            batteryGroup
                .opacity(dimmedIDs.contains(.bt1) ? 0.25 : 1.0)
            pmuGroup
                .opacity(dimmedIDs.contains(.ic1) ? 0.25 : 1.0)
            speakerGroup
                .opacity(dimmedIDs.contains(.spk1) ? 0.25 : 1.0)
            ssdGroup
                .opacity(dimmedIDs.contains(.u3) ? 0.25 : 1.0)
            displayGroup
                .opacity(dimmedIDs.contains(.lcd1) ? 0.25 : 1.0)
        }
    }

    // MARK: - Hit overlays

    /// Single full-canvas hit surface. Uses `.onContinuousHover` which fires
    /// on every mouse move (not just enter/exit) and reports the cursor in
    /// the surface's local coord space. We look up which component path
    /// contains the point and call `onHover` exactly once on transition.
    /// This avoids the stacked-`.onHover` pitfall (stale entered state on
    /// non-key window, static cursor not firing) and is correct under the
    /// parent scaleEffect because the reported location is already in the
    /// surface's own coordinate system.
    @ViewBuilder
    private var hitOverlays: some View {
        let zones = hitZones
        Rectangle()
            .fill(Color.clear)
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let p):
                    let id = componentID(at: p, zones: zones)
                    if id != lastReportedID {
                        lastReportedID = id
                        onHover(id)
                    }
                case .ended:
                    if lastReportedID != nil {
                        lastReportedID = nil
                        onHover(nil)
                    }
                }
            }
            .gesture(
                SpatialTapGesture(coordinateSpace: .local)
                    .onEnded { value in
                        if let id = componentID(at: value.location, zones: zones) {
                            onTap(id)
                        }
                    }
            )
    }

    /// Ordered list of hit zones (topmost first). Small components are
    /// padded outward so they are not pixel-precise to grab. Multi-shape
    /// components appear once per sub-shape.
    private var hitZones: [(id: AnatomyComponentID, path: Path)] {
        var out: [(AnatomyComponentID, Path)] = []
        // Small components first so they beat larger ones when paths overlap.
        out.append((.lcd1, Path(AnatomyChassisPaths.lcd1().boundingRect.insetBy(dx: -4, dy: -4))))
        out.append((.ic1, Path(AnatomyChassisPaths.ic1().boundingRect.insetBy(dx: -4, dy: -4))))
        out.append((.ant1, Path(AnatomyChassisPaths.ant1().boundingRect.insetBy(dx: -6, dy: -6))))
        out.append((.ant2, Path(AnatomyChassisPaths.ant2().boundingRect.insetBy(dx: -6, dy: -6))))
        for bar in AnatomyChassisPaths.spk1Bars() {
            out.append((.spk1, Path(bar.boundingRect.insetBy(dx: -4, dy: -4))))
        }
        for cell in AnatomyChassisPaths.bt1Cells() {
            out.append((.bt1, cell))
        }
        out.append((.u3, AnatomyChassisPaths.u3()))
        out.append((.fan1, AnatomyChassisPaths.fan1()))
        out.append((.fan2, AnatomyChassisPaths.fan2()))
        out.append((.u1, AnatomyChassisPaths.u1Outer()))
        return out
    }

    /// Find the first hit zone whose path contains the point. Uses
    /// CGPath.contains which treats paths as filled regions.
    private func componentID(at point: CGPoint,
                             zones: [(id: AnatomyComponentID, path: Path)]) -> AnatomyComponentID? {
        for zone in zones where zone.path.cgPath.contains(point) {
            return zone.id
        }
        return nil
    }

    // MARK: U1 SoC

    @ViewBuilder
    private var u1: some View {
        // Outer rect: blue tinted fill + outline.
        AnatomyChassisPaths.u1Outer()
            .fill(CC.blue.opacity(highlightID == .u1 ? 0.18 : 0.10))
        AnatomyChassisPaths.u1Outer()
            .stroke(strokeColor(.u1, fallback: CC.blue.opacity(0.55)), lineWidth: strokeWidth(.u1))

        // Five die subregions with category-tinted dashed strokes + light fills.
        let grid = AnatomyChassisPaths.u1DieGrid()
        grid[0].fill(CC.blue.opacity(0.10))
        grid[0].stroke(CC.blue.opacity(0.45), style: StrokeStyle(lineWidth: 0.7, dash: [2, 2]))
        grid[1].fill(CC.blue.opacity(0.08))
        grid[1].stroke(CC.blue.opacity(0.30), style: StrokeStyle(lineWidth: 0.7, dash: [2, 2]))
        grid[2].fill(CC.purple.opacity(0.10))
        grid[2].stroke(CC.purple.opacity(0.40), style: StrokeStyle(lineWidth: 0.7, dash: [2, 2]))
        grid[3].fill(CC.teal.opacity(0.10))
        grid[3].stroke(CC.teal.opacity(0.40), style: StrokeStyle(lineWidth: 0.7, dash: [2, 2]))
        grid[4].fill(CC.teal.opacity(0.08))
        grid[4].stroke(CC.teal.opacity(0.30), style: StrokeStyle(lineWidth: 0.7, dash: [2, 2]))

        // Subregion mono labels.
        Group {
            Text("CPU-P").anatomyMicro(ps(627, 200), tint: CC.blue.opacity(0.75))
            Text("CPU-E").anatomyMicro(ps(627, 236), tint: CC.blue.opacity(0.65))
            Text("GPU").anatomyMicro(ps(670, 218),  tint: CC.purple.opacity(0.75))
            Text("NE").anatomyMicro(ps(713, 200),   tint: CC.teal.opacity(0.75))
            Text("ISP").anatomyMicro(ps(713, 236),  tint: CC.teal.opacity(0.65))
        }
        anchorDot(at: AnatomyChassisGeometry.Anchor.u1, size: 2.4 * 1.32)
    }

    // MARK: Fan

    @ViewBuilder
    private func fanGroup(_ id: AnatomyComponentID, cx: CGFloat, cy: CGFloat) -> some View {
        // Outer disc fill + ring stroke.
        let outer = id == .fan1 ? AnatomyChassisPaths.fan1() : AnatomyChassisPaths.fan2()
        outer.fill(CC.amber.opacity(highlightID == id ? 0.18 : 0.10))
        outer.stroke(strokeColor(id, fallback: CC.amber.opacity(0.55)), lineWidth: strokeWidth(id))

        // 7 fan blade arcs.
        ForEach(Array(AnatomyChassisPaths.fanBlades(cx: cx, cy: cy).enumerated()), id: \.offset) { _, blade in
            blade.fill(CC.amber.opacity(0.16))
            blade.stroke(CC.amber.opacity(0.45), lineWidth: 0.6)
        }

        // Motor hub.
        AnatomyChassisPaths.fanHubRing(cx: cx, cy: cy)
            .fill(CC.amber.opacity(0.30))
        AnatomyChassisPaths.fanHubRing(cx: cx, cy: cy)
            .stroke(CC.amber.opacity(0.70), lineWidth: 0.7)
        AnatomyChassisPaths.fanHubDot(cx: cx, cy: cy)
            .fill(CC.amber.opacity(0.85))

        let anchor = id == .fan1 ? AnatomyChassisGeometry.Anchor.fan1
                                 : AnatomyChassisGeometry.Anchor.fan2
        anchorDot(at: anchor, size: 2.4 * 1.32)
    }

    // MARK: Antenna

    @ViewBuilder
    private func antenna(_ id: AnatomyComponentID) -> some View {
        let pad = id == .ant1 ? AnatomyChassisPaths.ant1() : AnatomyChassisPaths.ant2()
        pad.fill(CC.blue.opacity(highlightID == id ? 0.30 : 0.18))
        pad.stroke(strokeColor(id, fallback: CC.blue.opacity(0.65)), lineWidth: strokeWidth(id))

        let lines = id == .ant1 ? AnatomyChassisPaths.ant1Lines() : AnatomyChassisPaths.ant2Lines()
        ForEach(Array(lines.enumerated()), id: \.offset) { idx, line in
            line.stroke(CC.blue.opacity(idx == 0 ? 0.75 : 0.55), lineWidth: 0.7)
        }

        let dot = id == .ant1 ? AnatomyChassisPaths.ant1Dot() : AnatomyChassisPaths.ant2Dot()
        dot.fill(CC.blue.opacity(0.90))

        let anchor = id == .ant1 ? AnatomyChassisGeometry.Anchor.ant1
                                 : AnatomyChassisGeometry.Anchor.ant2
        anchorDot(at: anchor, size: 2.0 * 1.32)
    }

    // MARK: Battery

    @ViewBuilder
    private var batteryGroup: some View {
        let cells = AnatomyChassisPaths.bt1Cells()
        let bars = AnatomyChassisPaths.bt1LiquidBars()
        let seps = AnatomyChassisPaths.bt1Separators()
        let plus = AnatomyChassisPaths.bt1PlusTerminal()

        ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
            cell.fill(CC.sage.opacity(highlightID == .bt1 ? 0.18 : 0.10))
            cell.stroke(strokeColor(.bt1, fallback: CC.sage.opacity(0.55)), lineWidth: strokeWidth(.bt1))
        }
        ForEach(Array(bars.enumerated()), id: \.offset) { _, bar in
            bar.fill(CC.sage.opacity(0.22))
            bar.stroke(CC.sage.opacity(0.40), lineWidth: 0.5)
        }
        ForEach(Array(seps.enumerated()), id: \.offset) { _, sep in
            sep.stroke(CC.sage.opacity(0.40), style: StrokeStyle(lineWidth: 0.6, dash: [2, 2]))
        }
        ForEach(Array(plus.enumerated()), id: \.offset) { _, p in
            p.stroke(CC.sage.opacity(0.85), lineWidth: 1.0)
        }

        anchorDot(at: AnatomyChassisGeometry.Anchor.bt1, size: 2.4 * 1.32)
    }

    // MARK: PMU

    @ViewBuilder
    private var pmuGroup: some View {
        AnatomyChassisPaths.ic1()
            .fill(CC.sage.opacity(highlightID == .ic1 ? 0.25 : 0.16))
        AnatomyChassisPaths.ic1()
            .stroke(strokeColor(.ic1, fallback: CC.sage.opacity(0.65)), lineWidth: strokeWidth(.ic1) * 0.9)

        ForEach(Array(AnatomyChassisPaths.ic1Pins().enumerated()), id: \.offset) { _, pin in
            pin.stroke(CC.sage.opacity(0.75), lineWidth: 0.6)
        }

        Text("PMU")
            .anatomyMicro(ps(460, 291), tint: CC.sage.opacity(0.95))

        anchorDot(at: AnatomyChassisGeometry.Anchor.ic1, size: 2.0 * 1.32)
    }

    // MARK: Speaker

    @ViewBuilder
    private var speakerGroup: some View {
        let bars = AnatomyChassisPaths.spk1Bars()
        ForEach(Array(bars.enumerated()), id: \.offset) { _, bar in
            bar.fill(CC.sage.opacity(highlightID == .spk1 ? 0.22 : 0.14))
            bar.stroke(strokeColor(.spk1, fallback: CC.sage.opacity(0.60)), lineWidth: strokeWidth(.spk1) * 0.9)
        }
        ForEach(Array(AnatomyChassisPaths.spk1LeftSlots().enumerated()), id: \.offset) { _, slot in
            slot.stroke(CC.sage.opacity(0.65), lineWidth: 0.6)
        }
        ForEach(Array(AnatomyChassisPaths.spk1RightSlots().enumerated()), id: \.offset) { _, slot in
            slot.stroke(CC.sage.opacity(0.65), lineWidth: 0.6)
        }
        anchorDot(at: AnatomyChassisGeometry.Anchor.spk1, size: 2.0 * 1.32)
    }

    // MARK: SSD

    @ViewBuilder
    private var ssdGroup: some View {
        AnatomyChassisPaths.u3()
            .fill(CC.blue.opacity(highlightID == .u3 ? 0.18 : 0.10))
        AnatomyChassisPaths.u3()
            .stroke(strokeColor(.u3, fallback: CC.blue.opacity(0.60)), lineWidth: strokeWidth(.u3))

        ForEach(Array(AnatomyChassisPaths.ssdNandChips().enumerated()), id: \.offset) { idx, chip in
            chip.fill(CC.blue.opacity(idx < 2 ? 0.26 : 0.20))
            chip.stroke(CC.blue.opacity(idx < 2 ? 0.65 : 0.50), lineWidth: 0.6)
        }
        AnatomyChassisPaths.ssdControllerChip()
            .fill(CC.blue.opacity(0.32))
        AnatomyChassisPaths.ssdControllerChip()
            .stroke(CC.blue.opacity(0.75), lineWidth: 0.6)

        Text("CTRL")
            .font(.system(size: 5 * 1.32, design: .monospaced))
            .tracking(0.5)
            .foregroundStyle(CC.blue.opacity(0.75))
            .position(ps(824, 208))
        Text("SSD")
            .anatomyMicro(ps(796, 221), tint: CC.blue.opacity(0.85))

        anchorDot(at: AnatomyChassisGeometry.Anchor.u3, size: 2.4 * 1.32)
    }

    // MARK: Display

    @ViewBuilder
    private var displayGroup: some View {
        AnatomyChassisPaths.lcd1()
            .fill(CC.purple.opacity(highlightID == .lcd1 ? 0.22 : 0.14))
        AnatomyChassisPaths.lcd1()
            .stroke(strokeColor(.lcd1, fallback: CC.purple.opacity(0.65)), lineWidth: strokeWidth(.lcd1) * 0.9)

        AnatomyChassisPaths.lcd1InnerPanel()
            .fill(CC.purple.opacity(0.22))
        AnatomyChassisPaths.lcd1InnerPanel()
            .stroke(CC.purple.opacity(0.40), lineWidth: 0.5)

        AnatomyChassisPaths.lcd1Reflection()
            .stroke(Color.white.opacity(0.22), lineWidth: 0.6)

        Text("DISP")
            .anatomyMicro(ps(918, 143), tint: CC.purple.opacity(0.85))

        anchorDot(at: AnatomyChassisGeometry.Anchor.lcd1, size: 2.4 * 1.32)
    }

    // MARK: - Shared helpers

    private func strokeColor(_ id: AnatomyComponentID, fallback: Color) -> Color {
        highlightID == id ? MV.accentSage : fallback
    }

    private func strokeWidth(_ id: AnatomyComponentID) -> CGFloat {
        highlightID == id ? 1.4 : 0.9
    }

    private func anchorDot(at p: CGPoint, size: CGFloat) -> some View {
        Circle()
            .fill(MV.text4)
            .frame(width: size, height: size)
            .position(p)
    }
}

// MARK: - AnatomyChassis entry view

struct AnatomyChassis: View {

    let highlightID: AnatomyComponentID?
    let dimmedIDs: Set<AnatomyComponentID>
    let onHover: (AnatomyComponentID?) -> Void
    let onTap: (AnatomyComponentID) -> Void

    var body: some View {
        ZStack {
            AnatomyChassisShape()
            AnatomyChassisInterior(
                highlightID: highlightID,
                dimmedIDs: dimmedIDs,
                onHover: onHover,
                onTap: onTap
            )
        }
        .frame(width: AnatomyChassisGeometry.referenceWidth,
               height: AnatomyChassisGeometry.referenceHeight,
               alignment: .topLeading)
    }
}

// MARK: - Text micro-label helper

private extension Text {
    func anatomyMicro(_ p: CGPoint, tint: Color) -> some View {
        self
            .font(.system(size: 7 * 1.32, design: .monospaced))
            .tracking(0.6)
            .foregroundStyle(tint)
            .position(p)
    }
}

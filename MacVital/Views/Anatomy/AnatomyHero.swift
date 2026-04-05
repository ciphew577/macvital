// MacVital/Views/Anatomy/AnatomyHero.swift
//
// The Anatomy hero tile assembly. Layers, in z order:
//
//   1. Tile chrome (background, hairline border).
//   2. Masthead row (DWG ID + headline + 3 right-aligned stats).
//   3. Subtle dot grid clipped to the chassis bounds.
//   4. AnatomyChassis (visual + interior shapes + chassis hit targets).
//   5. 10 animated AnatomyTrace polylines.
//   6. 10 perimeter AnatomyComponentBlock views (5 left + 5 right).
//   7. AnatomyTraceLegend (bottom-left of canvas).
//
// Coordinate system:
//   Everything inside the canvas lives in the canonical 1336 x 504
//   reference space. A single GeometryReader applies a uniform scale to
//   match the available width while preserving aspect ratio. This keeps
//   chassis, blocks, and traces in lock-step.
//
// Interactivity:
//   - Hover or click on either a perimeter block OR a chassis interior
//     shape lights the matching trace and the corresponding partner.
//   - viewModel owns hoveredID and pinnedID. Both inputs route through it.
//   - Click toggles the pinned ID. Click outside the hero (handled in
//     AnatomyView) clears the pin.
//
// Live data:
//   - A 2.4 second Timer publisher publishes ticks. On each tick we apply
//     bounded jitter (0.4% on CPU, 30 RPM on fans, etc.) to the local
//     `liveStats` snapshot. Ranges are tight per spec.
//   - Wave 4 will replace this with a live SystemMonitor read.

import SwiftUI
import Combine

// MARK: - AnatomyHero

struct AnatomyHero: View {

    /// Drives hover, pin, and filter dim. Owned by AnatomyView.
    @Bindable var viewModel: AnatomyViewModel

    /// macOS reduce-motion accessibility flag. Drives trace animation gating.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Local jitter timer. Mirrors the HTML 2.4 second tick.
    @State private var jitterTick: Date = Date()

    /// Per-tick perturbed stat snapshot keyed by component ID. Resets each
    /// tick. The base values come from the view model so chip filters and
    /// the seed data still drive the unhovered look.
    @State private var liveStats: [AnatomyComponentID: [Stat]] = [:]

    /// Headline aggregate stats shown in the masthead row.
    @State private var systemDrawWatts: Double = 18.4
    @State private var peakTempC: Int = 74

    /// 2.4s publisher matching the HTML cadence.
    private let tickPublisher = Timer.publish(every: 2.4, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            let scale = geo.size.width / AnatomyChassisGeometry.referenceWidth
            let scaledHeight = AnatomyChassisGeometry.referenceHeight * scale

            ZStack(alignment: .topLeading) {

                // 1. Tile background.
                RoundedRectangle(cornerRadius: MV.radius)
                    .fill(MV.tile)
                    .overlay(
                        RoundedRectangle(cornerRadius: MV.radius)
                            .stroke(MV.hairline, lineWidth: 0.5)
                    )

                // Vertical stack: masthead, then scaled canvas.
                VStack(alignment: .leading, spacing: 0) {

                    // 2. Masthead row.
                    masthead
                        .frame(height: 44)
                        .frame(maxWidth: .infinity)
                        .overlay(
                            Rectangle()
                                .fill(MV.hairline)
                                .frame(height: 0.5),
                            alignment: .bottom
                        )

                    // 3 to 7. Scaled canvas.
                    canvas
                        .scaleEffect(scale, anchor: .topLeading)
                        .frame(width: geo.size.width,
                               height: scaledHeight,
                               alignment: .topLeading)
                        .clipped()
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onReceive(tickPublisher) { date in
            jitterTick = date
            applyJitter()
        }
        .onAppear {
            applyJitter()
        }
    }

    // MARK: - Masthead

    private var masthead: some View {
        HStack(alignment: .center, spacing: 0) {

            // Left: DWG id + headline.
            HStack(alignment: .center, spacing: 10) {
                Text("DWG MV-A01")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(MV.text4)
                Text("|")
                    .font(.system(size: 10))
                    .foregroundStyle(MV.text4.opacity(0.5))
                Text("System anatomy. Top-down chassis with live telemetry.")
                    .font(.system(size: MV.FS.body))
                    .foregroundStyle(MV.text2)
            }

            Spacer()

            // Right: 3 stats.
            HStack(alignment: .center, spacing: 20) {
                mhStat(label: "System Draw", value: String(format: "%.1f W", systemDrawWatts))
                mhDivider
                mhStat(label: "Peak Temp", value: "\(peakTempC) C")
                mhDivider
                mhStat(label: "Uptime", value: viewModel.uptimeString())
            }
        }
        .padding(.horizontal, 28)
    }

    private func mhStat(label: String, value: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(1.3)
                .foregroundStyle(MV.text4)
            Text(value)
                .font(.system(size: MV.FS.value, weight: .semibold, design: .monospaced))
                .foregroundStyle(MV.text1)
        }
    }

    private var mhDivider: some View {
        Rectangle()
            .fill(MV.hairlineStrong)
            .frame(width: 0.5, height: 22)
    }

    // MARK: - Canvas (1336 x 504 reference space)

    private var canvas: some View {
        ZStack(alignment: .topLeading) {

            // 3. Subtle dot grid, clipped to chassis bounds.
            DotGridLayer()
                .frame(width: AnatomyChassisGeometry.referenceWidth,
                       height: AnatomyChassisGeometry.referenceHeight,
                       alignment: .topLeading)
                .allowsHitTesting(false)

            // 4. Chassis (backdrop + interior + hit targets).
            AnatomyChassis(
                highlightID: highlightID,
                dimmedIDs: dimmedIDSet,
                onHover: { id in
                    if let id { viewModel.hoveredID = id }
                    else { viewModel.hoveredID = nil }
                },
                onTap: { id in
                    viewModel.togglePin(id)
                }
            )
            .frame(width: AnatomyChassisGeometry.referenceWidth,
                   height: AnatomyChassisGeometry.referenceHeight,
                   alignment: .topLeading)

            // 5. 10 traces.
            tracesLayer

            // 6. 10 perimeter blocks.
            blocksLayer

            // 7. Legend.
            AnatomyTraceLegend(motionEnabled: !reduceMotion)
        }
        .frame(width: AnatomyChassisGeometry.referenceWidth,
               height: AnatomyChassisGeometry.referenceHeight,
               alignment: .topLeading)
    }

    // MARK: - Traces layer

    private var tracesLayer: some View {
        ZStack(alignment: .topLeading) {
            ForEach(traceSpecs, id: \.id) { spec in
                AnatomyTrace(
                    points: spec.points,
                    kind: spec.kind,
                    isHighlighted: highlightID == spec.id,
                    isDimmed: dimmedIDSet.contains(spec.id),
                    motionEnabled: !reduceMotion
                )
                .frame(width: AnatomyChassisGeometry.referenceWidth,
                       height: AnatomyChassisGeometry.referenceHeight,
                       alignment: .topLeading)
            }
        }
        .frame(width: AnatomyChassisGeometry.referenceWidth,
               height: AnatomyChassisGeometry.referenceHeight,
               alignment: .topLeading)
        .allowsHitTesting(false)
    }

    // MARK: - Blocks layer

    private var blocksLayer: some View {
        ZStack(alignment: .topLeading) {
            ForEach(blockSpecs, id: \.id) { spec in
                let component = liveComponent(for: spec.id)
                AnatomyComponentBlock(
                    component: component,
                    isHighlighted: highlightID == spec.id,
                    isPinned: viewModel.pinnedID == spec.id,
                    isDimmed: dimmedIDSet.contains(spec.id),
                    onHoverChanged: { hovering in
                        if hovering { viewModel.hoveredID = spec.id }
                        else if viewModel.hoveredID == spec.id { viewModel.hoveredID = nil }
                    },
                    onTap: {
                        viewModel.togglePin(spec.id)
                    }
                )
                .frame(width: 150, height: spec.height, alignment: .topLeading)
                .position(x: spec.origin.x + 75,
                          y: spec.origin.y + spec.height / 2)
            }
        }
        .frame(width: AnatomyChassisGeometry.referenceWidth,
               height: AnatomyChassisGeometry.referenceHeight,
               alignment: .topLeading)
    }

    // MARK: - Derived state

    /// Hovered first; falls back to pinned. Drives trace + chassis emphasis.
    private var highlightID: AnatomyComponentID? {
        viewModel.hoveredID ?? viewModel.pinnedID
    }

    /// Set of component IDs that should dim under the active filter.
    private var dimmedIDSet: Set<AnatomyComponentID> {
        guard viewModel.activeFilter != .all else { return [] }
        return Set(AnatomyComponentID.allCases.filter { viewModel.isDimmed($0) })
    }

    /// Builds the live (jittered) component for rendering. Falls back to
    /// the view model values when no jitter is recorded yet.
    private func liveComponent(for id: AnatomyComponentID) -> AnatomyComponent {
        let base = viewModel.components.first(where: { $0.id == id })
            ?? AnatomyComponent(id: id, refTag: id.rawValue.uppercased(),
                                name: "", stats: [], category: id.category)
        if let stats = liveStats[id] {
            return AnatomyComponent(
                id: base.id,
                refTag: base.refTag,
                name: base.name,
                stats: stats,
                category: base.category
            )
        }
        return base
    }

    // MARK: - Live data jitter

    /// Apply tight bounded jitter to each component's stats. Mirrors the
    /// HTML rnd / rndInt helpers but with even tighter ranges.
    private func applyJitter() {
        var next: [AnatomyComponentID: [Stat]] = [:]
        for component in viewModel.components {
            next[component.id] = component.stats.map { stat in
                AnatomyHero.jitter(stat: stat)
            }
        }
        liveStats = next

        // Headline aggregates: keep within +/- 0.3 W and +/- 1 C respectively.
        systemDrawWatts = AnatomyHero.bounded(systemDrawWatts, jitter: 0.3, min: 12.0, max: 28.0)
        let nextTemp = peakTempC + Int.random(in: -1...1)
        peakTempC = max(58, min(86, nextTemp))
    }

    /// Returns a copy of `stat` with its numeric value perturbed within a
    /// stat-class-appropriate band. Non-numeric values (SSID, IP, MODE)
    /// pass through untouched.
    static func jitter(stat: Stat) -> Stat {
        guard let raw = Double(stat.value.replacingOccurrences(of: ",", with: "")) else {
            return stat
        }
        let band = jitterBand(forLabel: stat.label, unit: stat.unit, base: raw)
        let next = bounded(raw, jitter: band, min: -200, max: 1_000_000)
        let formatted = formatJittered(next, like: stat.value)
        return Stat(id: stat.id, label: stat.label, value: formatted, unit: stat.unit)
    }

    private static func jitterBand(forLabel label: String, unit: String, base: Double) -> Double {
        switch label.uppercased() {
        case "CPU", "GPU", "PWR": return 0.4
        case "DIE", "TEMP":       return 0.3
        case "RPM":               return 30
        case "DUTY":              return 1
        case "RSSI":              return 1
        case "BT":                return 0
        case "CHRG", "CAP":       return 0
        case "DRAW":              return 0.1
        case "VIN":               return 0.05
        case "OUT":               return 0.6
        case "USED":              return 0
        case "READ":              return 0.15
        case "NITS":              return 8
        case "RFRSH":             return 0
        default:
            // Fallback: 1 percent of base, capped at 5.
            return min(5, max(0.1, abs(base) * 0.01))
        }
    }

    private static func bounded(_ base: Double, jitter band: Double, min low: Double, max high: Double) -> Double {
        let delta = Double.random(in: -band...band)
        return Swift.max(low, Swift.min(high, base + delta))
    }

    /// Reformats a perturbed value to match the source string's precision.
    /// "21.4" → 1 decimal. "2816" → integer. "2,816" → integer with comma.
    private static func formatJittered(_ value: Double, like template: String) -> String {
        let rounded = template.contains(".")
        let decimalPart = template.split(separator: ".").last ?? ""
        let decimals = rounded ? decimalPart.count : 0

        if decimals > 0 {
            return String(format: "%.\(decimals)f", value)
        }
        let intVal = Int(value.rounded())
        if template.contains(",") {
            let nf = NumberFormatter()
            nf.numberStyle = .decimal
            nf.groupingSeparator = ","
            return nf.string(from: NSNumber(value: intVal)) ?? "\(intVal)"
        }
        return "\(intVal)"
    }

    // MARK: - Trace specs

    private var traceSpecs: [TraceSpec] {
        [
            // U1 SoC: chassis (668, 132.2) → top, then right to block (1172, 44).
            TraceSpec(id: .u1, kind: .data, points: [
                CGPoint(x: 668, y: 132.2),
                CGPoint(x: 668, y: 44),
                CGPoint(x: 1172, y: 44)
            ]),
            TraceSpec(id: .fan1, kind: .thermal, points: [
                CGPoint(x: 404, y: 114.7),
                CGPoint(x: 240, y: 114.7),
                CGPoint(x: 240, y: 110),
                CGPoint(x: 164, y: 110)
            ]),
            TraceSpec(id: .fan2, kind: .thermal, points: [
                CGPoint(x: 931.8, y: 114.7),
                CGPoint(x: 1100, y: 114.7),
                CGPoint(x: 1100, y: 124),
                CGPoint(x: 1172, y: 124)
            ]),
            TraceSpec(id: .ant1, kind: .rf, points: [
                CGPoint(x: 330.1, y: 14.4),
                CGPoint(x: 240, y: 14.4),
                CGPoint(x: 240, y: 35),
                CGPoint(x: 164, y: 35)
            ]),
            TraceSpec(id: .bt1, kind: .power, points: [
                CGPoint(x: 498.4, y: 357.6),
                CGPoint(x: 240, y: 357.6),
                CGPoint(x: 240, y: 202),
                CGPoint(x: 164, y: 202)
            ]),
            TraceSpec(id: .ic1, kind: .power, points: [
                CGPoint(x: 393.4, y: 299.5),
                CGPoint(x: 250, y: 299.5),
                CGPoint(x: 250, y: 294),
                CGPoint(x: 164, y: 294)
            ]),
            TraceSpec(id: .spk1, kind: .data, points: [
                CGPoint(x: 324.8, y: 183.4),
                CGPoint(x: 250, y: 183.4),
                CGPoint(x: 250, y: 390),
                CGPoint(x: 164, y: 390)
            ]),
            TraceSpec(id: .u3, kind: .data, points: [
                CGPoint(x: 842.2, y: 220.3),
                CGPoint(x: 1080, y: 220.3),
                CGPoint(x: 1080, y: 210),
                CGPoint(x: 1172, y: 210)
            ]),
            TraceSpec(id: .lcd1, kind: .data, points: [
                CGPoint(x: 1024.4, y: 104.2),
                CGPoint(x: 1100, y: 104.2),
                CGPoint(x: 1100, y: 296),
                CGPoint(x: 1172, y: 296)
            ]),
            TraceSpec(id: .ant2, kind: .rf, points: [
                CGPoint(x: 1005.9, y: 14.4),
                CGPoint(x: 1110, y: 14.4),
                CGPoint(x: 1110, y: 382),
                CGPoint(x: 1172, y: 382)
            ])
        ]
    }

    // MARK: - Block specs (perimeter positions)

    /// Block origins in reference space. Heights vary by stat row count.
    private var blockSpecs: [BlockSpec] {
        [
            // Left column, x = 14.
            BlockSpec(id: .ant1, origin: CGPoint(x: 14,   y: 18),  height: 34),
            BlockSpec(id: .fan1, origin: CGPoint(x: 14,   y: 78),  height: 64),
            BlockSpec(id: .bt1,  origin: CGPoint(x: 14,   y: 170), height: 64),
            BlockSpec(id: .ic1,  origin: CGPoint(x: 14,   y: 262), height: 64),
            BlockSpec(id: .spk1, origin: CGPoint(x: 14,   y: 362), height: 56),

            // Right column, x = 1172.
            BlockSpec(id: .u1,   origin: CGPoint(x: 1172, y: 10),  height: 68),
            BlockSpec(id: .fan2, origin: CGPoint(x: 1172, y: 92),  height: 64),
            BlockSpec(id: .u3,   origin: CGPoint(x: 1172, y: 178), height: 64),
            BlockSpec(id: .lcd1, origin: CGPoint(x: 1172, y: 264), height: 64),
            BlockSpec(id: .ant2, origin: CGPoint(x: 1172, y: 350), height: 64)
        ]
    }
}

// MARK: - TraceSpec

private struct TraceSpec {
    let id: AnatomyComponentID
    let kind: AnatomyTraceKind
    let points: [CGPoint]
}

// MARK: - BlockSpec

private struct BlockSpec {
    let id: AnatomyComponentID
    let origin: CGPoint   // top-left in reference space
    let height: CGFloat
}

// MARK: - AnatomyComponentBlock (perimeter callout)

private struct AnatomyComponentBlock: View {

    let component: AnatomyComponent
    let isHighlighted: Bool
    let isPinned: Bool
    let isDimmed: Bool
    let onHoverChanged: (Bool) -> Void
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            ZStack(alignment: .topLeading) {

                // Background plate.
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHighlighted || isPinned ? MV.tileHover : MV.tile)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(borderColor, lineWidth: borderWidth)
                    )

                // Pin accent strip on the left edge.
                if isPinned {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(MV.accentSage)
                        .frame(width: 3)
                        .padding(.vertical, 2)
                }

                // Header + stats.
                VStack(alignment: .leading, spacing: 6) {
                    header
                    Rectangle()
                        .fill(MV.hairline)
                        .frame(height: 0.6)
                        .padding(.horizontal, 0)
                    statsRows
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .shadow(color: (isHighlighted || isPinned)
                    ? MV.accentSage.opacity(0.18)
                    : .clear,
                    radius: 6, x: 0, y: 0)
            .opacity(isDimmed ? 0.25 : 1.0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            onHoverChanged(hovering)
        }
        .accessibilityLabel(component.name)
        .accessibilityHint(isPinned ? "Unpin component" : "Pin component for inspection")
        .accessibilityAddTraits(isPinned ? .isSelected : [])
        .animation(.easeOut(duration: 0.15), value: isDimmed)
        .animation(.easeOut(duration: 0.12), value: isHighlighted)
        .animation(.easeOut(duration: 0.12), value: isPinned)
    }

    private var borderColor: Color {
        isHighlighted || isPinned ? MV.accentSage : MV.hairlineStrong
    }

    private var borderWidth: CGFloat {
        isHighlighted || isPinned ? 1.3 : 0.8
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(component.refTag)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1.3)
                .foregroundStyle((isHighlighted || isPinned) ? MV.accentSage : MV.accentSage.opacity(0.85))
            Text(component.name.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(MV.text2)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var statsRows: some View {
        // Two-column layout when there are 4 stats; otherwise stacked rows.
        if component.stats.count == 4 {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 12) {
                    statRow(component.stats[0])
                    statRow(component.stats[1])
                }
                HStack(spacing: 12) {
                    statRow(component.stats[2])
                    statRow(component.stats[3])
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 3) {
                ForEach(component.stats) { stat in
                    statRow(stat)
                }
            }
        }
    }

    private func statRow(_ stat: Stat) -> some View {
        HStack(spacing: 4) {
            Text(stat.label.uppercased())
                .font(.system(size: 9, weight: .regular, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(MV.text3)
            Text(stat.value)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(MV.text1)
            if !stat.unit.isEmpty {
                Text(stat.unit)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(MV.text3)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - DotGridLayer (subtle backdrop, clipped to chassis bounds)

/// Renders a 22pt dot grid pattern restricted to the chassis bounding box.
/// The pitch matches the SVG `<pattern id="dot-grid">` block.
private struct DotGridLayer: View {

    var body: some View {
        Canvas { ctx, size in
            // Clip to the post-scale chassis rounded rect.
            let chassisRect = AnatomyChassisGeometry.chassisRect
            let radius = AnatomyChassisGeometry.chassisCornerRadius
            let clipPath = Path(roundedRect: chassisRect, cornerRadius: radius)
            ctx.clip(to: clipPath)

            // 22pt grid, 0.55pt dot at each cell centre.
            let pitch: CGFloat = 22
            let dotRadius: CGFloat = 0.55
            let dotColor = Color(white: 0.91).opacity(0.07)

            var y = chassisRect.minY + 11
            while y < chassisRect.maxY {
                var x = chassisRect.minX + 11
                while x < chassisRect.maxX {
                    let circle = Path(ellipseIn: CGRect(
                        x: x - dotRadius,
                        y: y - dotRadius,
                        width: 2 * dotRadius,
                        height: 2 * dotRadius
                    ))
                    ctx.fill(circle, with: .color(dotColor))
                    x += pitch
                }
                y += pitch
            }
            _ = size
        }
        .frame(width: AnatomyChassisGeometry.referenceWidth,
               height: AnatomyChassisGeometry.referenceHeight,
               alignment: .topLeading)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("AnatomyHero") {
    let vm = AnatomyViewModel()
    return AnatomyHero(viewModel: vm)
        .frame(width: 1_200, height: 600)
        .padding(20)
        .background(MV.bg)
}
#endif

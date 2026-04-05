// MacVital/Views/Shared/SettingsView.swift
//
// Top-level settings screen, accessible from the sidebar.
// Tab variants section uses visual thumbnail tile rows (5 per tab) bound to
// the same @AppStorage keys the live tab views read.

import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {

                // Appearance section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Appearance")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 20)

                    HStack(alignment: .center, spacing: 12) {
                        Text("Palette")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(width: 60, alignment: .leading)
                        PalettePickerDense(store: appState.paletteStore)
                    }
                    .padding(.horizontal, 20)
                }

                Divider()

                // Menu Bar Icon section
                MenuBarIconPicker()

                Divider()

                // Per-module menu bar widgets (Stats-style multi-widget system)
                MenuBarSettingsView()

                Divider()

                // Tab variant pickers, one per tab. Bound to the same
                // AppStorage keys the live tab views read on each render.
                SettingsTabVariantsSection()

                Divider()

                // Placeholder for future settings sections
                VStack(alignment: .leading, spacing: 4) {
                    Text("More Settings")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Additional preferences, polling interval, notifications, dock tile, coming soon.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Tab variants section
//
// Visual thumbnail tile rows. Each row: tab name on the left, then five
// 92x64 mini-thumbnail tiles. Click swaps the variant and updates the
// matching @AppStorage key. Selected tile gets an accent (sage) border.

private struct SettingsTabVariantsSection: View {

    @AppStorage("com.macvital.overview.variant")    private var overviewRaw: Int    = OverviewVariant.editorial.rawValue
    @AppStorage("com.macvital.cpu.variant")         private var cpuRaw: Int        = CPUVariant.ringGrid.rawValue
    @AppStorage("com.macvital.memory.variant")      private var memoryRaw: Int     = MemoryVariant.sunburst.rawValue
    @AppStorage("com.macvital.storage.variant")     private var storageRaw: Int    = StorageVariant.threeCellRow.rawValue
    @AppStorage("com.macvital.power.variant")       private var powerRaw: Int      = PowerVariant.sankey.rawValue
    @AppStorage("com.macvital.thermal.variant")     private var thermalRaw: Int    = ThermalVariant.chassisHeatmap.rawValue
    @AppStorage("com.macvital.fans.variant")        private var fansRaw: Int       = FanVariant.customCanvas.rawValue
    @AppStorage("com.macvital.gpu.variant")         private var gpuRaw: Int        = GPUVariant.heatStrip.rawValue
    @AppStorage("com.macvital.networkv2.variant")   private var networkV2Raw: Int  = NetworkV2Variant.segmentedPivot.rawValue
    @AppStorage("com.macvital.anatomy.variant")     private var anatomyRaw: Int    = AnatomyVariant.bentoSchematic.rawValue
    @AppStorage("com.macvital.processes.variant")   private var processesRaw: Int  = ProcessesVariant.classicTable.rawValue
    @AppStorage("com.macvital.report.variant")      private var reportRaw: Int     = ReportVariant.editorial.rawValue

    private static let cpuOrder: [CPUVariant] = [
        .ringGrid, .stackedBars, .heatmapStrip, .parallelCoordinates, .arcMeter
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tab variants")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.horizontal, 20)

            Text("Switches the live visual treatment for each tab. Click a tile to apply.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.bottom, 4)

            VStack(spacing: 0) {
                tileRow(label: "Overview", variants: OverviewVariant.allCases, selected: overviewRaw,
                        labelFor: { $0.displayName }, valueFor: { $0.rawValue }) { v in overviewRaw = v.rawValue } thumbFor: { v in
                    AnyView(VT.OverviewThumb(variant: v))
                }
                rowDivider
                tileRow(label: "CPU",
                        variants: Self.cpuOrder,
                        selected: cpuRaw,
                        labelFor: { $0.displayName },
                        valueFor: { $0.rawValue }) { v in cpuRaw = v.rawValue } thumbFor: { v in
                    AnyView(VT.CPUThumb(variant: v))
                }
                rowDivider
                tileRow(label: "Memory", variants: MemoryVariant.allCases, selected: memoryRaw,
                        labelFor: { $0.label }, valueFor: { $0.rawValue }) { v in memoryRaw = v.rawValue } thumbFor: { v in
                    AnyView(VT.MemoryThumb(variant: v))
                }
                rowDivider
                tileRow(label: "Storage", variants: StorageVariant.allCases, selected: storageRaw,
                        labelFor: { $0.title }, valueFor: { $0.rawValue }) { v in storageRaw = v.rawValue } thumbFor: { v in
                    AnyView(VT.StorageThumb(variant: v))
                }
                rowDivider
                tileRow(label: "Power", variants: PowerVariant.allCases, selected: powerRaw,
                        labelFor: { $0.label }, valueFor: { $0.rawValue }) { v in powerRaw = v.rawValue } thumbFor: { v in
                    AnyView(VT.PowerThumb(variant: v))
                }
                rowDivider
                tileRow(label: "Thermal", variants: ThermalVariant.allCases, selected: thermalRaw,
                        labelFor: { $0.displayName }, valueFor: { $0.rawValue }) { v in thermalRaw = v.rawValue } thumbFor: { v in
                    AnyView(VT.ThermalThumb(variant: v))
                }
                rowDivider
                tileRow(label: "Fans", variants: FanVariant.allCases, selected: fansRaw,
                        labelFor: { $0.label }, valueFor: { $0.rawValue }) { v in fansRaw = v.rawValue } thumbFor: { v in
                    AnyView(VT.FanThumb(variant: v))
                }
                rowDivider
                tileRow(label: "GPU", variants: GPUVariant.allCases, selected: gpuRaw,
                        labelFor: { $0.displayName }, valueFor: { $0.rawValue }) { v in gpuRaw = v.rawValue } thumbFor: { v in
                    AnyView(VT.GPUThumb(variant: v))
                }
                rowDivider
                tileRow(label: "Network", variants: NetworkV2Variant.allCases, selected: networkV2Raw,
                        labelFor: { $0.label }, valueFor: { $0.rawValue }) { v in networkV2Raw = v.rawValue } thumbFor: { v in
                    AnyView(VT.NetworkV2Thumb(variant: v))
                }
                rowDivider
                tileRow(label: "Anatomy", variants: AnatomyVariant.allCases, selected: anatomyRaw,
                        labelFor: { $0.displayName }, valueFor: { $0.rawValue }) { v in anatomyRaw = v.rawValue } thumbFor: { v in
                    AnyView(VT.AnatomyThumb(variant: v))
                }
                rowDivider
                tileRow(label: "Processes", variants: ProcessesVariant.allCases, selected: processesRaw,
                        labelFor: { $0.label }, valueFor: { $0.rawValue }) { v in processesRaw = v.rawValue } thumbFor: { v in
                    AnyView(VT.ProcessesThumb(variant: v))
                }
                rowDivider
                tileRow(label: "Report", variants: ReportVariant.allCases, selected: reportRaw,
                        labelFor: { $0.displayName }, valueFor: { $0.rawValue }) { v in reportRaw = v.rawValue } thumbFor: { v in
                    AnyView(VT.ReportThumb(variant: v))
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func tileRow<V, T: Equatable>(
        label: String,
        variants: [V],
        selected: T,
        labelFor: @escaping (V) -> String,
        valueFor: @escaping (V) -> T,
        onPick: @escaping (V) -> Void,
        thumbFor: @escaping (V) -> AnyView
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)
                .padding(.top, 6)
            HStack(alignment: .top, spacing: 8) {
                ForEach(Array(variants.enumerated()), id: \.offset) { _, v in
                    VariantTile(
                        title: labelFor(v),
                        tabName: label,
                        isSelected: valueFor(v) == selected,
                        thumb: { thumbFor(v) },
                        action: { onPick(v) }
                    )
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.06))
            .frame(height: 1)
    }
}

// MARK: - Tile shell

private struct VariantTile: View {
    let title: String
    let tabName: String
    let isSelected: Bool
    let thumb: () -> AnyView
    let action: () -> Void

    @State private var hover = false

    var body: some View {
        VStack(spacing: 4) {
            Button(action: action) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(MV.tile)
                    thumb()
                        .padding(6)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(
                            isSelected ? MV.accentSage : (hover ? MV.text2.opacity(0.45) : MV.text2.opacity(0.18)),
                            lineWidth: isSelected ? 1.5 : 1
                        )
                }
                .frame(width: 92, height: 64)
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .onHover { hover = $0 }
            .accessibilityLabel("\(title) variant for \(tabName)")
            .accessibilityValue(isSelected ? "selected" : "not selected")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            Text(title.uppercased())
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .tracking(0.4)
                .lineLimit(1)
                .foregroundStyle(isSelected ? MV.accentSage : MV.text3)
                .frame(width: 92, alignment: .center)
        }
    }
}

// MARK: - Variant Thumbnail namespace
//
// All 65 mini-views live here. Each is iconographic, ~80x52pt drawing area
// (after the 6pt tile padding). Flat MacPulse, no glow/glass/gradient.

private enum VT {

    // Shared geometry helpers
    static let W: CGFloat = 80
    static let H: CGFloat = 52

    // MARK: Overview

    struct OverviewThumb: View {
        let variant: OverviewVariant
        var body: some View {
            switch variant {
            case .editorial:
                VStack(alignment: .leading, spacing: 3) {
                    Text("Aa")
                        .font(.system(size: 24, weight: .bold, design: .serif))
                        .foregroundStyle(MV.text1)
                    Rectangle().fill(MV.text3).frame(height: 1)
                    Rectangle().fill(MV.text3).frame(width: 50, height: 1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            case .instrument:
                ZStack {
                    Circle().trim(from: 0.05, to: 0.7)
                        .stroke(MV.accentSage, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 36, height: 36)
                    Text("87")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(MV.text1)
                }
            case .bentoMosaic:
                Grid(horizontalSpacing: 2, verticalSpacing: 2) {
                    GridRow {
                        Rectangle().fill(MV.tile).overlay(Rectangle().strokeBorder(MV.text3.opacity(0.4), lineWidth: 0.5))
                        Rectangle().fill(MV.tile).overlay(Rectangle().strokeBorder(MV.text3.opacity(0.4), lineWidth: 0.5))
                        Rectangle().fill(MV.accentSage.opacity(0.5)).overlay(Rectangle().strokeBorder(MV.text3.opacity(0.4), lineWidth: 0.5))
                    }
                    GridRow {
                        Rectangle().fill(MV.accentSage.opacity(0.3)).overlay(Rectangle().strokeBorder(MV.text3.opacity(0.4), lineWidth: 0.5))
                        Rectangle().fill(MV.tile).overlay(Rectangle().strokeBorder(MV.text3.opacity(0.4), lineWidth: 0.5))
                        Rectangle().fill(MV.tile).overlay(Rectangle().strokeBorder(MV.text3.opacity(0.4), lineWidth: 0.5))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .narrativeFirst:
                VStack(alignment: .leading, spacing: 6) {
                    Rectangle().fill(MV.text2).frame(height: 1.2)
                    Rectangle().fill(MV.text2).frame(width: 60, height: 1.2)
                    HStack(spacing: 6) {
                        Circle().fill(MV.accentSage).frame(width: 4, height: 4)
                        Circle().fill(MV.warning).frame(width: 4, height: 4)
                        Circle().fill(MV.text3).frame(width: 4, height: 4)
                        Circle().fill(MV.text3).frame(width: 4, height: 4)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            case .statusBar:
                HStack(spacing: 1) {
                    Rectangle().fill(MV.accentSage).frame(width: 24)
                    Rectangle().fill(MV.warning).frame(width: 10)
                    Rectangle().fill(MV.text3).frame(width: 14)
                    Rectangle().fill(MV.text3.opacity(0.4))
                }
                .frame(height: 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
    }

    // MARK: CPU

    struct CPUThumb: View {
        let variant: CPUVariant
        var body: some View {
            switch variant {
            case .ringGrid:
                // 4 + 5 + 5 dots
                VStack(spacing: 3) {
                    HStack(spacing: 3) {
                        ForEach(0..<4, id: \.self) { _ in dot(MV.text2) }
                    }
                    HStack(spacing: 3) {
                        ForEach(0..<5, id: \.self) { _ in dot(MV.accentSage) }
                    }
                    HStack(spacing: 3) {
                        ForEach(0..<5, id: \.self) { _ in dot(MV.accentSage) }
                    }
                }
            case .stackedBars:
                VStack(spacing: 5) {
                    bar(filled: 0.55, color: MV.text2)
                    bar(filled: 0.78, color: MV.accentSage)
                    bar(filled: 0.42, color: MV.accentSage)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            case .heatmapStrip:
                Grid(horizontalSpacing: 1, verticalSpacing: 1) {
                    ForEach(0..<8, id: \.self) { row in
                        GridRow {
                            ForEach(0..<14, id: \.self) { col in
                                let intensity = (sin(Double(row * 14 + col) * 0.7) + 1) * 0.5
                                Rectangle().fill(MV.accentSage.opacity(0.18 + intensity * 0.65))
                            }
                        }
                    }
                }
            case .parallelCoordinates:
                ZStack {
                    polyline([0.2, 0.6, 0.4, 0.8, 0.5], color: MV.accentSage)
                    polyline([0.5, 0.3, 0.7, 0.5, 0.8], color: MV.warning)
                    polyline([0.7, 0.5, 0.3, 0.6, 0.4], color: MV.text3)
                }
            case .arcMeter:
                HStack(spacing: 6) {
                    arcMeter(progress: 0.55, color: MV.text2)
                    arcMeter(progress: 0.78, color: MV.accentSage)
                    arcMeter(progress: 0.40, color: MV.accentSage)
                }
            }
        }

        private func dot(_ c: Color) -> some View {
            Circle().fill(c).frame(width: 6, height: 6)
        }
        private func bar(filled: CGFloat, color: Color) -> some View {
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1).fill(MV.text3.opacity(0.2))
                    RoundedRectangle(cornerRadius: 1).fill(color).frame(width: g.size.width * filled)
                }
            }
            .frame(height: 5)
        }
        private func polyline(_ values: [CGFloat], color: Color) -> some View {
            GeometryReader { g in
                Path { p in
                    let step = g.size.width / CGFloat(values.count - 1)
                    for (i, v) in values.enumerated() {
                        let pt = CGPoint(x: CGFloat(i) * step, y: g.size.height * (1 - v))
                        if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
            }
        }
        private func arcMeter(progress: CGFloat, color: Color) -> some View {
            ZStack {
                Circle().trim(from: 0.15, to: 0.85)
                    .stroke(MV.text3.opacity(0.25), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                Circle().trim(from: 0.15, to: 0.15 + 0.7 * progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
            .rotationEffect(.degrees(90))
            .frame(width: 22, height: 22)
        }
    }

    // MARK: Memory (USER FAVOURITE, keep crisp)

    struct MemoryThumb: View {
        let variant: MemoryVariant
        var body: some View {
            switch variant {
            case .sunburst:
                ZStack {
                    Circle().trim(from: 0, to: 0.62)
                        .stroke(MV.accentSage, style: StrokeStyle(lineWidth: 5, lineCap: .butt))
                        .frame(width: 38, height: 38)
                        .rotationEffect(.degrees(-90))
                    Circle().trim(from: 0, to: 0.84)
                        .stroke(MV.text2, style: StrokeStyle(lineWidth: 3, lineCap: .butt))
                        .frame(width: 26, height: 26)
                        .rotationEffect(.degrees(-90))
                    Circle().fill(MV.tile).frame(width: 14, height: 14)
                }
            case .stackedBar:
                HStack(spacing: 1) {
                    Rectangle().fill(MV.accentSage).frame(width: 30)
                    Rectangle().fill(MV.text2).frame(width: 14)
                    Rectangle().fill(MV.warning).frame(width: 8)
                    Rectangle().fill(MV.text3.opacity(0.35))
                }
                .frame(height: 18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .clipShape(RoundedRectangle(cornerRadius: 2))
            case .stairStep:
                HStack(alignment: .bottom, spacing: 3) {
                    column(0.30, MV.text2)
                    column(0.50, MV.text2)
                    column(0.68, MV.accentSage)
                    column(0.82, MV.accentSage)
                    column(0.95, MV.warning)
                }
            case .circuitBoard:
                ZStack {
                    HStack(spacing: 4) {
                        ForEach(0..<5, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(i == 4 ? MV.warning : MV.accentSage.opacity(0.7))
                                .frame(width: 8, height: 18)
                        }
                    }
                    Rectangle().fill(MV.text3.opacity(0.3)).frame(height: 0.6)
                }
            case .pressureCentric:
                ZStack {
                    // Discrete arc segments: green 0-50, amber 50-80, red 80-100
                    // Active arc spans trim 0.1...0.9 (sweep = 0.8 of full circle)
                    // Segment splits at 0.5 (50%) and 0.8 (80%) of the active sweep
                    let activeStart: CGFloat = 0.1
                    let activeEnd: CGFloat = 0.9
                    let sweep = activeEnd - activeStart // 0.8
                    let split1 = activeStart + sweep * 0.50 // green/amber boundary
                    let split2 = activeStart + sweep * 0.80 // amber/red boundary
                    Circle().trim(from: activeStart, to: split1)
                        .stroke(MV.accentSage,
                                style: StrokeStyle(lineWidth: 4, lineCap: .butt))
                        .frame(width: 38, height: 38)
                        .rotationEffect(.degrees(126))
                    Circle().trim(from: split1, to: split2)
                        .stroke(MV.warning,
                                style: StrokeStyle(lineWidth: 4, lineCap: .butt))
                        .frame(width: 38, height: 38)
                        .rotationEffect(.degrees(126))
                    Circle().trim(from: split2, to: activeEnd)
                        .stroke(MV.critical,
                                style: StrokeStyle(lineWidth: 4, lineCap: .butt))
                        .frame(width: 38, height: 38)
                        .rotationEffect(.degrees(126))
                    Text("62")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(MV.text1)
                }
            }
        }

        private func column(_ frac: CGFloat, _ color: Color) -> some View {
            RoundedRectangle(cornerRadius: 1)
                .fill(color)
                .frame(width: 9, height: 38 * frac)
        }
    }

    // MARK: Storage

    struct StorageThumb: View {
        let variant: StorageVariant
        var body: some View {
            switch variant {
            case .threeCellRow:
                HStack(spacing: 3) {
                    cell(0.55, MV.accentSage)
                    cell(0.32, MV.text2)
                    cell(0.18, MV.warning)
                }
            case .nestedBars:
                VStack(alignment: .leading, spacing: 4) {
                    nestedBar(outer: 0.85, inner: 0.6, c1: MV.text2, c2: MV.accentSage)
                    nestedBar(outer: 0.70, inner: 0.45, c1: MV.text2, c2: MV.accentSage)
                    nestedBar(outer: 0.50, inner: 0.30, c1: MV.text2, c2: MV.warning)
                }
            case .stairCards:
                HStack(alignment: .bottom, spacing: 3) {
                    stairCard(0.40, MV.text2)
                    stairCard(0.62, MV.accentSage)
                    stairCard(0.85, MV.warning)
                }
            case .numberLine:
                ZStack {
                    Rectangle().fill(MV.text3.opacity(0.3)).frame(height: 1)
                    HStack {
                        ForEach(0..<5, id: \.self) { i in
                            VStack(spacing: 1) {
                                Rectangle().fill(MV.text2).frame(width: 1, height: 5)
                                Circle().fill(i == 2 ? MV.accentSage : MV.text3).frame(width: 4, height: 4)
                            }
                            if i < 4 { Spacer() }
                        }
                    }
                }
            case .nestedCircles:
                ZStack {
                    Circle().stroke(MV.text2, lineWidth: 1).frame(width: 38, height: 38)
                    Circle().stroke(MV.accentSage, lineWidth: 1.4).frame(width: 26, height: 26)
                    Circle().fill(MV.warning).frame(width: 12, height: 12)
                }
            }
        }

        private func cell(_ frac: CGFloat, _ color: Color) -> some View {
            VStack(spacing: 2) {
                Rectangle().fill(color).frame(height: 30 * frac)
                Rectangle().fill(MV.text3.opacity(0.18)).frame(height: 30 * (1 - frac))
            }
            .clipShape(RoundedRectangle(cornerRadius: 1))
        }
        private func nestedBar(outer: CGFloat, inner: CGFloat, c1: Color, c2: Color) -> some View {
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1).fill(MV.text3.opacity(0.2))
                    RoundedRectangle(cornerRadius: 1).fill(c1).frame(width: g.size.width * outer)
                    RoundedRectangle(cornerRadius: 1).fill(c2).frame(width: g.size.width * inner)
                }
            }
            .frame(height: 7)
        }
        private func stairCard(_ frac: CGFloat, _ color: Color) -> some View {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 16, height: 38 * frac)
        }
    }

    // MARK: Power

    struct PowerThumb: View {
        let variant: PowerVariant
        var body: some View {
            switch variant {
            case .editorial:
                RoundedRectangle(cornerRadius: 4).stroke(MV.text2, lineWidth: 1)
                    .padding(2)
            case .sankey:
                Canvas { ctx, size in
                    let colors: [Color] = [MV.accentSage, MV.warning, MV.text2]
                    for (i, color) in colors.enumerated() {
                        var path = Path()
                        let yL = CGFloat(10 + i * 14)
                        let yR = CGFloat(8 + i * 16)
                        path.move(to: CGPoint(x: 0, y: yL))
                        path.addCurve(
                            to: CGPoint(x: size.width, y: yR),
                            control1: CGPoint(x: size.width * 0.4, y: yL),
                            control2: CGPoint(x: size.width * 0.6, y: yR)
                        )
                        ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    }
                }
            case .treemap:
                Grid(horizontalSpacing: 2, verticalSpacing: 2) {
                    GridRow {
                        Rectangle().fill(MV.accentSage).gridCellColumns(2)
                        Rectangle().fill(MV.text2)
                    }
                    GridRow {
                        Rectangle().fill(MV.warning)
                        Rectangle().fill(MV.text2.opacity(0.6))
                        Rectangle().fill(MV.text3)
                    }
                }
            case .radialSunburst:
                ZStack {
                    Circle().stroke(MV.accentSage, lineWidth: 3).frame(width: 38, height: 38)
                    Circle().stroke(MV.warning, lineWidth: 2).frame(width: 28, height: 28)
                    Circle().stroke(MV.text2, lineWidth: 2).frame(width: 18, height: 18)
                    Circle().fill(MV.tile).frame(width: 10, height: 10)
                }
            case .stackedLaneFlow:
                VStack(spacing: 3) {
                    laneRow(filled: 0.85, color: MV.accentSage)
                    laneRow(filled: 0.55, color: MV.warning)
                    laneRow(filled: 0.32, color: MV.text2)
                    laneRow(filled: 0.18, color: MV.text3)
                }
            case .rankList:
                VStack(alignment: .leading, spacing: 3) {
                    rankRow(0.95, MV.accentSage)
                    rankRow(0.70, MV.text2)
                    rankRow(0.50, MV.warning)
                    rankRow(0.32, MV.text3)
                }
            }
        }

        private func laneRow(filled: CGFloat, color: Color) -> some View {
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1).fill(MV.text3.opacity(0.18))
                    RoundedRectangle(cornerRadius: 1).fill(color).frame(width: g.size.width * filled)
                }
            }
            .frame(height: 6)
        }
        private func rankRow(_ frac: CGFloat, _ color: Color) -> some View {
            HStack(spacing: 4) {
                Circle().fill(MV.text3).frame(width: 4, height: 4)
                RoundedRectangle(cornerRadius: 1).fill(color).frame(width: 70 * frac, height: 5)
            }
        }
    }

    // MARK: Thermal

    struct ThermalThumb: View {
        let variant: ThermalVariant
        var body: some View {
            switch variant {
            case .editorial:
                RoundedRectangle(cornerRadius: 4).stroke(MV.text2, lineWidth: 1)
                    .padding(2)
            case .chassisHeatmap:
                ZStack {
                    RoundedRectangle(cornerRadius: 4).stroke(MV.text2, lineWidth: 1)
                    HStack(spacing: 0) {
                        Rectangle().fill(MV.warning.opacity(0.5)).frame(width: 24)
                        Rectangle().fill(MV.critical.opacity(0.55)).frame(width: 18)
                        Rectangle().fill(MV.warning.opacity(0.35))
                        Rectangle().fill(MV.accentSage.opacity(0.45)).frame(width: 12)
                    }
                    .padding(2)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                .padding(2)
            case .laneBarGrid:
                VStack(spacing: 2) {
                    ForEach(0..<7, id: \.self) { i in
                        let fracs: [CGFloat] = [0.85, 0.7, 0.6, 0.5, 0.4, 0.32, 0.22]
                        GeometryReader { g in
                            ZStack(alignment: .leading) {
                                Rectangle().fill(MV.text3.opacity(0.15))
                                Rectangle().fill(i < 2 ? MV.warning : (i < 4 ? MV.accentSage : MV.text2))
                                    .frame(width: g.size.width * fracs[i])
                            }
                        }
                        .frame(height: 4)
                    }
                }
            case .ridgelinePlot:
                VStack(spacing: 1) {
                    ForEach(0..<7, id: \.self) { i in
                        sparkline(seed: i)
                            .frame(height: 5)
                    }
                }
            case .polarChart:
                Canvas { ctx, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let radius: CGFloat = min(size.width, size.height) / 2 - 4
                    var web = Path()
                    for ring in stride(from: 0.33 as CGFloat, through: 1.0, by: 0.33) {
                        var ringPath = Path()
                        for i in 0..<7 {
                            let a = Double(i) * (.pi * 2 / 7) - .pi / 2
                            let pt = CGPoint(x: center.x + cos(a) * radius * ring, y: center.y + sin(a) * radius * ring)
                            if i == 0 { ringPath.move(to: pt) } else { ringPath.addLine(to: pt) }
                        }
                        ringPath.closeSubpath()
                        web.addPath(ringPath)
                    }
                    ctx.stroke(web, with: .color(MV.text3.opacity(0.3)), lineWidth: 0.5)

                    var poly = Path()
                    let values: [CGFloat] = [0.8, 0.6, 0.7, 0.5, 0.4, 0.6, 0.55]
                    for i in 0..<7 {
                        let a = Double(i) * (.pi * 2 / 7) - .pi / 2
                        let r = radius * values[i]
                        let pt = CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r)
                        if i == 0 { poly.move(to: pt) } else { poly.addLine(to: pt) }
                    }
                    poly.closeSubpath()
                    ctx.stroke(poly, with: .color(MV.accentSage), lineWidth: 1.2)
                }
            case .profileCards:
                Grid(horizontalSpacing: 2, verticalSpacing: 2) {
                    ForEach(0..<2, id: \.self) { _ in
                        GridRow {
                            ForEach(0..<4, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(MV.text2.opacity(0.25))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 1.5).strokeBorder(MV.text3.opacity(0.4), lineWidth: 0.5)
                                    )
                            }
                        }
                    }
                }
            }
        }

        private func sparkline(seed: Int) -> some View {
            GeometryReader { g in
                Path { p in
                    let count = 12
                    let step = g.size.width / CGFloat(count - 1)
                    for i in 0..<count {
                        let v = (sin(Double(i + seed) * 0.9) + 1) * 0.5
                        let pt = CGPoint(x: CGFloat(i) * step, y: g.size.height * (1 - CGFloat(v)))
                        if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                    }
                }
                .stroke(seed < 2 ? MV.warning : (seed < 4 ? MV.accentSage : MV.text2),
                        style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
            }
        }
    }

    // MARK: Fans

    struct FanThumb: View {
        let variant: FanVariant
        var body: some View {
            switch variant {
            case .appleHIGFlat:
                Canvas { ctx, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let r: CGFloat = min(size.width, size.height) / 2 - 4
                    for i in 0..<5 {
                        let angle = Double(i) * (.pi * 2 / 5)
                        var p = Path()
                        p.move(to: center)
                        p.addLine(to: CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r))
                        ctx.stroke(p, with: .color(MV.text2), lineWidth: 1.2)
                    }
                    ctx.stroke(Path(ellipseIn: CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)),
                               with: .color(MV.accentSage), lineWidth: 1)
                }
            case .nzxtProduct:
                Canvas { ctx, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let r: CGFloat = min(size.width, size.height) / 2 - 3
                    for i in 0..<7 {
                        let a0 = Double(i) * (.pi * 2 / 7)
                        var p = Path()
                        p.move(to: center)
                        p.addQuadCurve(
                            to: CGPoint(x: center.x + cos(a0) * r, y: center.y + sin(a0) * r),
                            control: CGPoint(x: center.x + cos(a0 - 0.4) * r * 0.7, y: center.y + sin(a0 - 0.4) * r * 0.7)
                        )
                        p.addLine(to: center)
                        p.closeSubpath()
                        ctx.fill(p, with: .color(MV.accentSage.opacity(0.6 + Double(i % 2) * 0.2)))
                    }
                    ctx.fill(Path(ellipseIn: CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)),
                             with: .color(MV.tile))
                    ctx.stroke(Path(ellipseIn: CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)),
                               with: .color(MV.text2), lineWidth: 0.8)
                }
            case .iconscoutFlat:
                Canvas { ctx, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let r: CGFloat = min(size.width, size.height) / 2 - 3
                    for i in 0..<5 {
                        let a = Double(i) * (.pi * 2 / 5)
                        let tip = CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r)
                        var p = Path()
                        p.move(to: center)
                        p.addQuadCurve(
                            to: tip,
                            control: CGPoint(x: center.x + cos(a - 0.6) * r * 0.6, y: center.y + sin(a - 0.6) * r * 0.6)
                        )
                        p.addQuadCurve(
                            to: center,
                            control: CGPoint(x: center.x + cos(a + 0.6) * r * 0.6, y: center.y + sin(a + 0.6) * r * 0.6)
                        )
                        ctx.fill(p, with: .color(MV.accentSage))
                    }
                    ctx.fill(Path(ellipseIn: CGRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6)),
                             with: .color(MV.text1))
                }
            case .streamlineLine:
                Canvas { ctx, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let r: CGFloat = min(size.width, size.height) / 2 - 3
                    var p = Path()
                    for i in 0..<5 {
                        let a = Double(i) * (.pi * 2 / 5)
                        p.move(to: center)
                        p.addQuadCurve(
                            to: CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r),
                            control: CGPoint(x: center.x + cos(a - 0.5) * r * 0.7, y: center.y + sin(a - 0.5) * r * 0.7)
                        )
                    }
                    ctx.stroke(p, with: .color(MV.text2), lineWidth: 1)
                    ctx.stroke(Path(ellipseIn: CGRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6)),
                               with: .color(MV.accentSage), lineWidth: 0.8)
                }
            case .customCanvas:
                Canvas { ctx, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let r: CGFloat = min(size.width, size.height) / 2 - 3
                    for i in 0..<5 {
                        let a = Double(i) * (.pi * 2 / 5)
                        let tip = CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r)
                        let c1 = CGPoint(x: center.x + cos(a - 0.7) * r * 0.5, y: center.y + sin(a - 0.7) * r * 0.5)
                        let c2 = CGPoint(x: center.x + cos(a + 0.2) * r * 0.85, y: center.y + sin(a + 0.2) * r * 0.85)
                        var p = Path()
                        p.move(to: center)
                        p.addCurve(to: tip, control1: c1, control2: c2)
                        let c3 = CGPoint(x: center.x + cos(a + 0.7) * r * 0.5, y: center.y + sin(a + 0.7) * r * 0.5)
                        p.addCurve(to: center, control1: c2, control2: c3)
                        ctx.fill(p, with: .color(i == 0 ? MV.accentSage : MV.text2.opacity(0.7)))
                    }
                    ctx.fill(Path(ellipseIn: CGRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6)),
                             with: .color(MV.warning))
                }
            }
        }
    }

    // MARK: GPU

    struct GPUThumb: View {
        let variant: GPUVariant
        var body: some View {
            switch variant {
            case .heatStrip:
                HStack(alignment: .center, spacing: 1) {
                    ForEach(0..<16, id: \.self) { i in
                        let intensity = (sin(Double(i) * 0.6) + 1) * 0.5
                        RoundedRectangle(cornerRadius: 0.5)
                            .fill(MV.accentSage.opacity(0.25 + intensity * 0.7))
                            .frame(width: 3, height: 30)
                    }
                }
            case .coreGrid:
                Grid(horizontalSpacing: 2, verticalSpacing: 2) {
                    ForEach(0..<4, id: \.self) { row in
                        GridRow {
                            ForEach(0..<4, id: \.self) { col in
                                let v: Double = Double((row * 4 + col) % 5) / 4.0
                                Rectangle().fill(MV.accentSage.opacity(0.25 + v * 0.6))
                            }
                        }
                    }
                }
            case .radialSpoke:
                Canvas { ctx, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let r: CGFloat = min(size.width, size.height) / 2 - 3
                    for i in 0..<16 {
                        let a0 = Double(i) * (.pi * 2 / 16)
                        let a1 = a0 + (.pi * 2 / 16) - 0.04
                        var p = Path()
                        p.move(to: center)
                        p.addArc(center: center, radius: r, startAngle: .radians(a0), endAngle: .radians(a1), clockwise: false)
                        p.closeSubpath()
                        let intensity = (sin(Double(i) * 0.5) + 1) * 0.5
                        ctx.fill(p, with: .color(MV.accentSage.opacity(0.3 + intensity * 0.6)))
                    }
                }
            case .scrollingTimeline:
                VStack(spacing: 1) {
                    ForEach(0..<16, id: \.self) { i in
                        GeometryReader { g in
                            HStack(spacing: 0) {
                                ForEach(0..<10, id: \.self) { j in
                                    let v = (sin(Double(i * 10 + j) * 0.4) + 1) * 0.5
                                    Rectangle().fill(MV.accentSage.opacity(0.2 + v * 0.55))
                                }
                            }
                            .frame(width: g.size.width)
                        }
                        .frame(height: 1.6)
                    }
                }
            case .summaryFirst:
                HStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 2).fill(MV.accentSage).frame(width: 36)
                    VStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 1.5).fill(MV.text2)
                        RoundedRectangle(cornerRadius: 1.5).fill(MV.warning)
                    }
                }
            }
        }
    }

    // MARK: Network

    struct NetworkV2Thumb: View {
        let variant: NetworkV2Variant
        var body: some View {
            switch variant {
            case .segmentedPivot:
                HStack(spacing: 0) {
                    pill("APP", filled: true)
                    pill("PROC", filled: false)
                    pill("NET", filled: false)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            case .leftRailTabs:
                HStack(alignment: .top, spacing: 5) {
                    VStack(spacing: 5) {
                        ForEach(0..<5, id: \.self) { i in
                            Circle().fill(i == 0 ? MV.accentSage : MV.text3).frame(width: 5, height: 5)
                        }
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Rectangle().fill(MV.text2).frame(width: 36, height: 1)
                        Rectangle().fill(MV.text2).frame(width: 28, height: 1)
                        Rectangle().fill(MV.text3).frame(width: 32, height: 1)
                    }
                    Spacer(minLength: 0)
                }
            case .chipCloud:
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 3) {
                        chip("APP", true)
                        chip("PROC", false)
                    }
                    HStack(spacing: 3) {
                        chip("NET", false)
                        chip("DOM", false)
                        chip("PORT", false)
                    }
                }
            case .breadcrumbDrilldown:
                HStack(spacing: 3) {
                    crumb("BY")
                    Text(">").font(.system(size: 7, weight: .semibold, design: .monospaced))
                        .foregroundStyle(MV.text3)
                    crumb("APP")
                    Text(">").font(.system(size: 7, weight: .semibold, design: .monospaced))
                        .foregroundStyle(MV.text3)
                    crumb("LIVE")
                }
            case .splitPane:
                HStack(spacing: 3) {
                    VStack(spacing: 3) {
                        Rectangle().fill(MV.accentSage.opacity(0.4)).frame(height: 4)
                        Rectangle().fill(MV.text2.opacity(0.3)).frame(height: 4)
                        Rectangle().fill(MV.text2.opacity(0.3)).frame(height: 4)
                        Rectangle().fill(MV.text2.opacity(0.3)).frame(height: 4)
                    }
                    .frame(width: 28)
                    Rectangle().fill(MV.text3.opacity(0.4)).frame(width: 0.5)
                    Rectangle().fill(MV.text2.opacity(0.18))
                        .overlay(Rectangle().strokeBorder(MV.text3.opacity(0.4), lineWidth: 0.5))
                }
            }
        }

        private func pill(_ text: String, filled: Bool) -> some View {
            Text(text)
                .font(.system(size: 7, weight: .semibold, design: .monospaced))
                .foregroundStyle(filled ? MV.text1 : MV.text3)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(
                    Rectangle().fill(filled ? MV.accentSage.opacity(0.55) : Color.clear)
                )
                .overlay(Rectangle().strokeBorder(MV.text3.opacity(0.4), lineWidth: 0.5))
        }
        private func chip(_ text: String, _ active: Bool) -> some View {
            Text(text)
                .font(.system(size: 7, weight: .semibold, design: .monospaced))
                .foregroundStyle(active ? MV.text1 : MV.text2)
                .padding(.horizontal, 4)
                .padding(.vertical, 1.5)
                .background(
                    Capsule().fill(active ? MV.accentSage.opacity(0.55) : MV.text3.opacity(0.15))
                )
        }
        private func crumb(_ text: String) -> some View {
            Text(text)
                .font(.system(size: 7, weight: .semibold, design: .monospaced))
                .foregroundStyle(MV.text2)
        }
    }

    // MARK: Anatomy

    struct AnatomyThumb: View {
        let variant: AnatomyVariant
        var body: some View {
            switch variant {
            case .bentoSchematic:
                ZStack {
                    RoundedRectangle(cornerRadius: 4).strokeBorder(MV.text2, lineWidth: 0.8)
                    Grid(horizontalSpacing: 1.5, verticalSpacing: 1.5) {
                        GridRow {
                            Rectangle().fill(MV.accentSage.opacity(0.5))
                            Rectangle().fill(MV.text2.opacity(0.35))
                        }
                        GridRow {
                            Rectangle().fill(MV.text2.opacity(0.35))
                            Rectangle().fill(MV.warning.opacity(0.5))
                        }
                    }
                    .padding(4)
                }
            case .explodedView:
                ZStack {
                    RoundedRectangle(cornerRadius: 3).strokeBorder(MV.text2, lineWidth: 0.6)
                        .frame(width: 36, height: 24)
                    RoundedRectangle(cornerRadius: 1).fill(MV.accentSage.opacity(0.55))
                        .frame(width: 16, height: 8)
                        .offset(x: -22, y: -14)
                    RoundedRectangle(cornerRadius: 1).fill(MV.warning.opacity(0.55))
                        .frame(width: 14, height: 8)
                        .offset(x: 22, y: -14)
                    RoundedRectangle(cornerRadius: 1).fill(MV.text2.opacity(0.45))
                        .frame(width: 14, height: 8)
                        .offset(x: -22, y: 14)
                    RoundedRectangle(cornerRadius: 1).fill(MV.text2.opacity(0.45))
                        .frame(width: 16, height: 8)
                        .offset(x: 22, y: 14)
                }
            case .crossSection:
                VStack(spacing: 2) {
                    Rectangle().fill(MV.accentSage.opacity(0.5)).frame(height: 9)
                    Rectangle().fill(MV.text2.opacity(0.45)).frame(height: 9)
                    Rectangle().fill(MV.warning.opacity(0.45)).frame(height: 9)
                }
                .clipShape(RoundedRectangle(cornerRadius: 2))
            case .wiringDiagram:
                Canvas { ctx, size in
                    let mid = size.height / 2
                    var line = Path()
                    line.move(to: CGPoint(x: 0, y: mid))
                    line.addLine(to: CGPoint(x: size.width, y: mid))
                    ctx.stroke(line, with: .color(MV.text2), lineWidth: 0.6)
                    // Capacitor (two parallel bars)
                    var cap = Path()
                    cap.move(to: CGPoint(x: size.width * 0.15, y: mid - 6))
                    cap.addLine(to: CGPoint(x: size.width * 0.15, y: mid + 6))
                    cap.move(to: CGPoint(x: size.width * 0.22, y: mid - 6))
                    cap.addLine(to: CGPoint(x: size.width * 0.22, y: mid + 6))
                    ctx.stroke(cap, with: .color(MV.text1), lineWidth: 1)
                    // IC (square box)
                    let icRect = CGRect(x: size.width * 0.42, y: mid - 7, width: 14, height: 14)
                    ctx.stroke(Path(roundedRect: icRect, cornerRadius: 1), with: .color(MV.accentSage), lineWidth: 1)
                    // Resistor (zigzag)
                    var zig = Path()
                    let zStart = size.width * 0.7
                    zig.move(to: CGPoint(x: zStart, y: mid))
                    let pts: [(CGFloat, CGFloat)] = [(2, -4), (2, 4), (2, -4), (2, 4), (2, 0)]
                    var x = zStart
                    for (dx, dy) in pts {
                        x += dx
                        zig.addLine(to: CGPoint(x: x, y: mid + dy))
                    }
                    ctx.stroke(zig, with: .color(MV.warning), lineWidth: 1)
                }
            case .ifixitPhoto:
                ZStack {
                    RoundedRectangle(cornerRadius: 3).strokeBorder(MV.text2, lineWidth: 0.8)
                        .frame(width: 56, height: 36)
                    badgeCallouts
                }
            }
        }

        private var badgeCallouts: some View {
            let positions: [(CGFloat, CGFloat, String)] = [
                (-22, -10, "1"), (-6, 8, "2"), (8, -10, "3"), (22, 6, "4"), (0, -2, "5")
            ]
            return ZStack {
                ForEach(0..<positions.count, id: \.self) { i in
                    let t = positions[i]
                    ZStack {
                        Circle().fill(MV.critical).frame(width: 9, height: 9)
                        Text(t.2)
                            .font(.system(size: 6, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .offset(x: t.0, y: t.1)
                }
            }
        }
    }

    // MARK: Processes

    struct ProcessesThumb: View {
        let variant: ProcessesVariant
        var body: some View {
            switch variant {
            case .classicTable:
                VStack(spacing: 1) {
                    ForEach(0..<8, id: \.self) { i in
                        HStack(spacing: 2) {
                            Rectangle().fill(MV.text2.opacity(0.5)).frame(width: 22, height: 2)
                            Rectangle().fill(MV.text3.opacity(0.4)).frame(width: 14, height: 2)
                            Rectangle().fill(MV.text3.opacity(0.3)).frame(width: 10, height: 2)
                            Spacer(minLength: 0)
                            Rectangle().fill(i == 0 ? MV.accentSage : MV.text3.opacity(0.4)).frame(width: 8, height: 2)
                        }
                    }
                }
            case .cardRows:
                VStack(spacing: 3) {
                    ForEach(0..<4, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(MV.text2.opacity(0.18))
                            .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(MV.text3.opacity(0.4), lineWidth: 0.5))
                            .frame(height: 8)
                            .overlay(alignment: .leading) {
                                Circle().fill(i == 0 ? MV.accentSage : MV.text3).frame(width: 4, height: 4).padding(.leading, 3)
                            }
                    }
                }
            case .treeGrouped:
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.down").font(.system(size: 6))
                            .foregroundStyle(MV.text2)
                        Rectangle().fill(MV.text2).frame(width: 36, height: 1.5)
                    }
                    ForEach(0..<3, id: \.self) { _ in
                        Rectangle().fill(MV.text3.opacity(0.5)).frame(width: 30, height: 1.5)
                            .padding(.leading, 8)
                    }
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.right").font(.system(size: 6))
                            .foregroundStyle(MV.text2)
                        Rectangle().fill(MV.text2).frame(width: 30, height: 1.5)
                    }
                }
            case .kanbanCategorical:
                HStack(alignment: .top, spacing: 2) {
                    ForEach(0..<3, id: \.self) { col in
                        VStack(spacing: 2) {
                            Rectangle().fill(col == 0 ? MV.accentSage : (col == 1 ? MV.warning : MV.text3))
                                .frame(height: 1.5)
                            ForEach(0..<3, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(MV.text2.opacity(0.18))
                                    .frame(height: 7)
                            }
                        }
                    }
                }
            case .linearVercel:
                VStack(spacing: 1.5) {
                    ForEach(0..<10, id: \.self) { i in
                        HStack(spacing: 3) {
                            Rectangle().fill(i == 0 ? MV.accentSage : MV.text3).frame(width: 14, height: 1.4)
                            Rectangle().fill(MV.text2.opacity(0.5)).frame(width: 26, height: 1.4)
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }
    }

    // MARK: Report

    struct ReportThumb: View {
        let variant: ReportVariant
        var body: some View {
            switch variant {
            case .editorial:
                VStack(alignment: .leading, spacing: 3) {
                    Text("Aa")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundStyle(MV.text1)
                    Rectangle().fill(MV.text2).frame(height: 1)
                    HStack(alignment: .top, spacing: 4) {
                        VStack(spacing: 1.5) {
                            Rectangle().fill(MV.text3).frame(height: 1)
                            Rectangle().fill(MV.text3).frame(height: 1)
                            Rectangle().fill(MV.text3).frame(width: 22, height: 1)
                        }
                        VStack(spacing: 1.5) {
                            Rectangle().fill(MV.text3).frame(height: 1)
                            Rectangle().fill(MV.text3).frame(height: 1)
                            Rectangle().fill(MV.text3).frame(width: 18, height: 1)
                        }
                    }
                }
            case .dashboard:
                VStack(spacing: 3) {
                    HStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(i == 0 ? MV.accentSage.opacity(0.45) : MV.text2.opacity(0.25))
                                .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(MV.text3.opacity(0.4), lineWidth: 0.5))
                                .frame(height: 16)
                        }
                    }
                    Rectangle().fill(MV.text3.opacity(0.18)).frame(height: 8)
                }
            case .appleHealth:
                Grid(horizontalSpacing: 4, verticalSpacing: 4) {
                    GridRow {
                        Circle().fill(MV.accentSage.opacity(0.7)).frame(width: 16, height: 16)
                        Circle().fill(MV.warning.opacity(0.7)).frame(width: 16, height: 16)
                        Circle().fill(MV.text2.opacity(0.5)).frame(width: 16, height: 16)
                    }
                    GridRow {
                        Circle().fill(MV.text2.opacity(0.5)).frame(width: 16, height: 16)
                        Circle().fill(MV.accentSage.opacity(0.7)).frame(width: 16, height: 16)
                        Circle().fill(MV.critical.opacity(0.6)).frame(width: 16, height: 16)
                    }
                }
            case .terminal:
                VStack(alignment: .leading, spacing: 2.5) {
                    line(prefix: "$", text: "macvital report", color: MV.accentSage)
                    line(prefix: ">", text: "scanning...", color: MV.text2)
                    line(prefix: ">", text: "mem 62%", color: MV.text2)
                    line(prefix: ">", text: "ok", color: MV.accentSage)
                }
            case .newspaperFold:
                HStack(alignment: .top, spacing: 4) {
                    VStack(alignment: .leading, spacing: 1.5) {
                        Rectangle().fill(MV.text2).frame(height: 1.2)
                        Rectangle().fill(MV.text3).frame(height: 1)
                        Rectangle().fill(MV.text3).frame(height: 1)
                        Rectangle().fill(MV.text3).frame(width: 24, height: 1)
                    }
                    Rectangle().fill(MV.text3.opacity(0.5)).frame(width: 0.5)
                    VStack(alignment: .leading, spacing: 1.5) {
                        Rectangle().fill(MV.text2).frame(height: 1.2)
                        Rectangle().fill(MV.text3).frame(height: 1)
                        Rectangle().fill(MV.text3).frame(height: 1)
                        Rectangle().fill(MV.text3).frame(width: 20, height: 1)
                    }
                }
            }
        }

        private func line(prefix: String, text: String, color: Color) -> some View {
            HStack(spacing: 3) {
                Text(prefix)
                    .font(.system(size: 7, weight: .semibold, design: .monospaced))
                    .foregroundStyle(color)
                Text(text)
                    .font(.system(size: 7, weight: .regular, design: .monospaced))
                    .foregroundStyle(MV.text2)
                Spacer(minLength: 0)
            }
        }
    }
}


// MacVital/Views/Anatomy/AnatomyView.swift
//
// Top-level shell for the Anatomy tab (Wave 1, foundation only).
//
// Wave 1 scope:
//   - Sidebar / hero / bottom rail are placeholder tile rectangles.
//   - Real chip stack, schematic, and card rail land in Wave 2 / 3.
//   - View defaults to the Graphite palette while it is on screen, but only
//     when the user has not made an explicit palette choice via Settings.
//
// State ownership mirrors NetworkViewV2:
//   - viewModel is created as @State so the view tree owns its lifetime.
//   - SystemMonitor is injected on .onAppear via attach(monitor:).

import SwiftUI

// MARK: - AnatomyView

struct AnatomyView: View {

    @Environment(AppState.self) private var appState

    @State private var viewModel = AnatomyViewModel()

    @AppStorage(AnatomyVariant.storageKey) private var variantRaw: Int = AnatomyVariant.bentoSchematic.rawValue

    /// Snapshot of the palette tokens active before this view applied Graphite.
    /// Captured on .onAppear and restored on .onDisappear so leaving the tab
    /// hands the global palette back to whatever the rest of the app expects.
    @State private var priorPalette: MVPaletteTokens? = nil

    /// True only when this view applied a palette override on appear and so
    /// owns the responsibility to restore on disappear.
    @State private var didApplyOverride = false

    var body: some View {
        HStack(spacing: 0) {

            // 1. Sidebar column (fixed 280pt). Chip filters + events feed.
            AnatomySidebar(viewModel: viewModel)
                .frame(width: 280)

            // 2. Main column. Masthead at the top (52pt), hero schematic
            //    in the middle (flexes), bottom rail at the foot (220pt).
            VStack(spacing: 0) {
                mastheadPlaceholder
                    .frame(height: 52)

                heroForVariant
                    .frame(maxHeight: .infinity)

                AnatomyBottomRail(viewModel: viewModel)
                    .frame(height: 220)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MV.bg)
        .onAppear {
            viewModel.attach(monitor: appState.monitor)
            applyGraphiteIfDefault()
        }
        .onDisappear {
            restorePriorPaletteIfNeeded()
        }
    }

    // MARK: - Hero variant switch

    @ViewBuilder
    private var heroForVariant: some View {
        let variant = AnatomyVariant(rawValue: variantRaw) ?? .bentoSchematic
        switch variant {
        case .bentoSchematic: AnatomyBentoSchematic(viewModel: viewModel)
        case .explodedView:   AnatomyExplodedView(viewModel: viewModel)
        case .crossSection:   AnatomyCrossSection(viewModel: viewModel)
        case .wiringDiagram:  AnatomyWiringDiagram(viewModel: viewModel)
        case .ifixitPhoto:    AnatomyIfixitPhoto(viewModel: viewModel)
        }
    }

    // MARK: - Masthead row

    private var mastheadPlaceholder: some View {
        HStack(alignment: .center) {
            Text("ANATOMY")
                .font(.system(size: MV.FS.micro, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(MV.text3)
            Spacer()
            Text("Uptime \(viewModel.uptimeString())")
                .font(.system(size: MV.FS.caption))
                .foregroundStyle(MV.text2)
                .monospacedDigit()
        }
        .padding(.horizontal, MV.S.s4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(MV.tile.opacity(0.6))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(MV.hairline),
            alignment: .bottom
        )
    }

    // MARK: - Palette override (scoped to this view's lifetime)

    /// Applies the Graphite palette only if the user has not explicitly
    /// chosen a palette via Settings. The explicit choice is detected by the
    /// presence of the persisted UserDefaults key MVPaletteStore writes to.
    private func applyGraphiteIfDefault() {
        guard !didApplyOverride else { return }
        let key = "com.macvital.palette"
        let userPicked = UserDefaults.standard.string(forKey: key) != nil
        guard !userPicked else { return }

        priorPalette = MV.current
        MV.setPalette(MVPaletteTokens.tokens(for: .graphite))
        didApplyOverride = true
    }

    /// Restores the palette captured on appear. Safe to call even when no
    /// override was applied, because didApplyOverride gates the restore.
    private func restorePriorPaletteIfNeeded() {
        guard didApplyOverride, let prior = priorPalette else { return }
        MV.setPalette(prior)
        didApplyOverride = false
        priorPalette = nil
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Anatomy") {
    AnatomyView()
        .environment(AppState())
        .frame(width: 1_100, height: 800)
}
#endif

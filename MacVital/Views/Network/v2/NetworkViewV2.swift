// MacVital/Views/Network/v2/NetworkViewV2.swift
//
// Top-level shell for the Network V2 redesign (variant-f-fusion, 2026-04-23).
//
// Composes masthead band, six spark cards, big chart, pivot bar, column
// header, and panes grid. Each section is owned by its own file or agent.
//
// State ownership:
//   viewModel      -- provided by data-stubs agent (NetworkV2ViewModel)
//   selectedPivot  -- provided by pivot agent (NetworkPanePivot)
//   selectedRange  -- provided by data agent (NetworkTimeRange)
//   focusedCard    -- provided by cards agent (NetworkSparkCard)
//
// This file must not define those types. It declares them and lets the
// linker resolve them from the other files in the same module target.

import SwiftUI
import AppKit

// MARK: - NetworkViewV2

struct NetworkViewV2: View {

    @Environment(AppState.self) private var appState

    // Cross-section state shared between sub-views.
    @State private var viewModel = NetworkV2ViewModel()
    @State private var selectedPivot: NetworkPanePivot = .interface
    @State private var selectedRange: NetworkTimeRange = .sevenDays
    @State private var focusedCard: NetworkSparkCard = .downloadNow

    @AppStorage(NetworkV2VariantStorageKey.key) private var variantRaw: Int = 0
    private var variant: NetworkV2Variant { NetworkV2Variant(rawValue: variantRaw) ?? .segmentedPivot }

    var body: some View {
        VStack(spacing: 0) {

            // 1. Masthead: 40pt tall, fixed height, no resize handle.
            NetworkMasthead(
                selectedRange: $selectedRange,
                liveDownBps: viewModel.liveDownBps,
                liveUpBps: viewModel.liveUpBps
            )

            // 2. Six spark cards row: resizable vertical.
            // FIXME: ResizableContainer pending, wrap with .resizable once defined.
            NetworkSparkCardsRow(
                focused: $focusedCard,
                metrics: viewModel.cardMetrics(for: selectedRange)
            )
            // .resizable(id: "v2.cards", default: 168, min: 96, max: 240)

            // 3. Big chart band: resizable vertical.
            // FIXME: ResizableContainer pending, wrap with .resizable once defined.
            NetworkBigChart(
                series: viewModel.chartSeries(for: selectedRange, focused: focusedCard),
                focused: focusedCard
            )
            // .resizable(id: "v2.chart", default: 200, min: 120, max: 460)

            variantPicker

            // 4 + 5. Variant-specific pivot chrome + pane area.
            variantArea
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MV.bg)
        .environment(\.perSSIDUsageStore, appState.perSSIDUsageStore)
        .task {
            // Inject the live monitor so the ViewModel can read real data.
            // Using .task (not .onAppear) so re-mount also re-attaches and the
            // VM does not show mock data for a render after the view is rebuilt.
            viewModel.attach(monitor: appState.monitor)
        }
    }

    // MARK: - Variant switching

    @ViewBuilder
    private var variantArea: some View {
        switch variant {
        case .segmentedPivot:      NetworkV2SegmentedPivot(pivot: $selectedPivot)
        case .leftRailTabs:        NetworkV2LeftRailTabs(pivot: $selectedPivot)
        case .chipCloud:           NetworkV2ChipCloud(pivot: $selectedPivot)
        case .breadcrumbDrilldown: NetworkV2BreadcrumbDrilldown(pivot: $selectedPivot)
        case .splitPane:           NetworkV2SplitPane(pivot: $selectedPivot)
        }
    }

    private var variantPicker: some View {
        HStack(spacing: 6) {
            Text("VARIANT")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(MV.text4)
            ForEach(NetworkV2Variant.allCases) { v in
                Button {
                    variantRaw = v.rawValue
                } label: {
                    Text(v.shortLabel)
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(variant == v ? MV.text1 : MV.text3)
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(variant == v ? MV.accentSage.opacity(0.16) : MV.bg)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(variant == v ? MV.accentSage.opacity(0.5) : MV.hairlineStrong, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .help(v.label)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(MV.tile)
        .overlay(alignment: .bottom) { Rectangle().fill(MV.hairline).frame(height: 1) }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Network V2") {
    NetworkViewV2()
        .environment(AppState())
        .frame(width: 1_100, height: 800)
}
#endif

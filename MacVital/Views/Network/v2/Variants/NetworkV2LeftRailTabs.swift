// Variant 2: vertical left rail of pivot tabs beside the lifetime pane.

import SwiftUI

struct NetworkV2LeftRailTabs: View {
    @Binding var pivot: NetworkPanePivot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            rail
            Rectangle().fill(MV.hairline).frame(width: 1)
            mainArea
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MV.bg)
    }

    private var rail: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PIVOT")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(MV.text4)
                .padding(.horizontal, 12)
                .padding(.top, 14)
                .padding(.bottom, 4)

            ForEach(NetworkPanePivot.allCases) { item in
                railButton(item)
            }
            Spacer()
        }
        .frame(width: 156)
        .background(MV.tile)
    }

    private func railButton(_ item: NetworkPanePivot) -> some View {
        let isActive = pivot == item
        return Button {
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.18)) { pivot = item }
        } label: {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(isActive ? MV.accentSage : Color.clear)
                    .frame(width: 3)
                Text(item.shortLabel.uppercased())
                    .font(.system(size: 11, weight: isActive ? .semibold : .medium))
                    .tracking(0.8)
                    .foregroundStyle(isActive ? MV.text1 : MV.text3)
                Spacer()
            }
            .frame(height: 30)
            .background(isActive ? MV.accentSage.opacity(0.10) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var mainArea: some View {
        if pivot == .network {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    NetworkPaneLifetime().frame(minHeight: 320)
                    NetworkV2AppBreakdown()
                }
            }
        } else {
            NetworkV2PivotPlaceholder(pivot: pivot)
        }
    }
}

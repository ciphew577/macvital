// Variant 1: iOS-style segmented pivot above the lifetime pane.

import SwiftUI

struct NetworkV2SegmentedPivot: View {
    @Binding var pivot: NetworkPanePivot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            segmented
            Rectangle().fill(MV.hairline).frame(height: 1)
            if pivot == .network {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        NetworkPaneLifetime()
                            .frame(minHeight: 320)
                        NetworkV2AppBreakdown()
                    }
                }
            } else {
                NetworkV2PivotPlaceholder(pivot: pivot)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MV.bg)
    }

    private var segmented: some View {
        HStack(spacing: 0) {
            ForEach(NetworkPanePivot.allCases) { item in
                segmentButton(item)
            }
        }
        .padding(4)
        .background(MV.bg)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(MV.hairlineStrong, lineWidth: 1)
        )
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(MV.tile)
    }

    private func segmentButton(_ item: NetworkPanePivot) -> some View {
        let isActive = pivot == item
        return Button {
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.18)) { pivot = item }
        } label: {
            Text(item.shortLabel.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(isActive ? MV.text1 : MV.text3)
                .frame(maxWidth: .infinity)
                .frame(height: 26)
                .background(isActive ? MV.accentSage.opacity(0.18) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(
                    isActive
                        ? RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(MV.accentSage.opacity(0.45), lineWidth: 1)
                        : nil
                )
        }
        .buttonStyle(.plain)
    }
}

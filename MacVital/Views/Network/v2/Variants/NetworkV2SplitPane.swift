// Variant 5: left rail of 5 pivot buttons; right side splits horizontally into lifetime + breakdown.

import SwiftUI

struct NetworkV2SplitPane: View {
    @Binding var pivot: NetworkPanePivot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            railColumn
            Rectangle().fill(MV.hairline).frame(width: 1)
            rightSide
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MV.bg)
    }

    private var railColumn: some View {
        VStack(spacing: 6) {
            Text("PIVOT")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(MV.text4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.top, 14)
                .padding(.bottom, 4)

            ForEach(NetworkPanePivot.allCases) { p in
                railIconButton(p)
            }
            Spacer()
        }
        .frame(width: 132)
        .background(MV.tile)
    }

    private func railIconButton(_ item: NetworkPanePivot) -> some View {
        let isActive = pivot == item
        return Button {
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.18)) { pivot = item }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon(for: item))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isActive ? MV.accentSage : MV.text3)
                    .frame(width: 18)
                Text(item.shortLabel.uppercased())
                    .font(.system(size: 10, weight: isActive ? .semibold : .medium))
                    .tracking(0.8)
                    .foregroundStyle(isActive ? MV.text1 : MV.text3)
                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(isActive ? MV.accentSage.opacity(0.12) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
    }

    private func icon(for item: NetworkPanePivot) -> String {
        switch item {
        case .interface: return "cable.connector"
        case .network:   return "wifi"
        case .app:       return "app.dashed"
        case .process:   return "cpu"
        case .domain:    return "globe"
        }
    }

    @ViewBuilder
    private var rightSide: some View {
        if pivot == .network {
            HStack(spacing: 0) {
                NetworkPaneLifetime()
                    .frame(minWidth: 360, maxWidth: .infinity)
                Rectangle().fill(MV.hairline).frame(width: 1)
                ScrollView(.vertical, showsIndicators: false) {
                    NetworkV2AppBreakdown()
                }
                .frame(width: 360)
            }
        } else {
            NetworkV2PivotPlaceholder(pivot: pivot)
        }
    }
}

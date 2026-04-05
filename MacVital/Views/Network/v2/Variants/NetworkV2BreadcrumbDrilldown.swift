// Variant 4: breadcrumb drilldown from Interface to Network to App-by-SSID.

import SwiftUI

struct NetworkV2BreadcrumbDrilldown: View {
    @Binding var pivot: NetworkPanePivot
    @State private var drillSSID: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.perSSIDUsageStore) private var store

    private static let noNetworksPlaceholder = "(no networks tracked yet)"

    private var topSSIDName: String {
        guard let store, let top = store.sortedBuckets.first else {
            return Self.noNetworksPlaceholder
        }
        if top.id == PerSSIDUsageStore.unknownKey { return "Unknown network" }
        return top.id
    }

    var body: some View {
        VStack(spacing: 0) {
            breadcrumbBar
            Rectangle().fill(MV.hairline).frame(height: 1)
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MV.bg)
        .onChange(of: store?.sortedBuckets.count ?? 0) { _, newCount in
            if newCount == 0 { drillSSID = nil }
        }
        .onChange(of: drillSSID) { _, newValue in
            if newValue == Self.noNetworksPlaceholder { drillSSID = nil }
        }
    }

    private var breadcrumbBar: some View {
        HStack(spacing: 6) {
            crumbButton(label: "ALL INTERFACES", target: .interface, leaf: false)
            crumbSeparator
            crumbButton(label: "BY NETWORK", target: .network, leaf: drillSSID == nil)
            if let ssid = drillSSID {
                crumbSeparator
                Text(ssid.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(MV.text1)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(MV.accentSage.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                Spacer()
                Button("BACK") { withAnimation(reduceMotion ? nil : .smooth(duration: 0.2)) { drillSSID = nil } }
                    .buttonStyle(.plain)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(MV.text3)
            } else {
                Spacer()
                pivotMiniSwitch
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(MV.tile)
    }

    private func crumbButton(label: String, target: NetworkPanePivot, leaf: Bool) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.18)) {
                pivot = target
                if target != .network { drillSSID = nil }
            }
        } label: {
            Text(label)
                .font(.system(size: 10, weight: leaf ? .semibold : .medium))
                .tracking(0.8)
                .foregroundStyle(leaf ? MV.text1 : MV.text3)
                .padding(.horizontal, 8)
                .frame(height: 24)
                .background(leaf ? MV.accentSage.opacity(0.10) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }

    private var crumbSeparator: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(MV.text4)
    }

    private var pivotMiniSwitch: some View {
        HStack(spacing: 0) {
            ForEach(NetworkPanePivot.allCases) { p in
                Button {
                    withAnimation(reduceMotion ? nil : .smooth(duration: 0.18)) { pivot = p }
                } label: {
                    Text(p.shortLabel.uppercased())
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(pivot == p ? MV.text1 : MV.text4)
                        .padding(.horizontal, 7)
                        .frame(height: 22)
                        .background(pivot == p ? MV.accentSage.opacity(0.12) : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
        .background(MV.bg)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(MV.hairlineStrong, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var content: some View {
        if pivot == .network {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    if drillSSID == nil {
                        NetworkPaneLifetime()
                            .frame(minHeight: 320)
                            .overlay(alignment: .topTrailing) { drillHint }
                        NetworkV2AppBreakdown()
                    } else if drillSSID != Self.noNetworksPlaceholder {
                        NetworkV2AppBreakdown()
                    }
                }
            }
        } else {
            NetworkV2PivotPlaceholder(pivot: pivot)
        }
    }

    private var drillHint: some View {
        HStack(spacing: 6) {
            Button {
                withAnimation(reduceMotion ? nil : .smooth(duration: 0.2)) {
                    drillSSID = topSSIDName
                }
            } label: {
                Text("DRILL INTO TOP NETWORK")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(MV.accentSage)
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(MV.accentSage.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(MV.accentSage.opacity(0.45), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(topSSIDName == Self.noNetworksPlaceholder)
            .opacity(topSSIDName == Self.noNetworksPlaceholder ? 0.5 : 1)

            previewBadge
        }
        .padding(12)
    }

    private var previewBadge: some View {
        Text("PREVIEW, not wired")
            .font(.system(size: 8, weight: .bold))
            .tracking(0.6)
            .foregroundStyle(MV.warning)
            .padding(.horizontal, 6)
            .frame(height: 18)
            .background(MV.warning.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(MV.warning.opacity(0.45), lineWidth: 1)
            )
    }
}

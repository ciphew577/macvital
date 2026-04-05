// Variant 3: filterable, multi-select chip cloud for the pivot dimension plus quick filters.

import SwiftUI

struct NetworkV2ChipCloud: View {
    @Binding var pivot: NetworkPanePivot
    @State private var activeFilters: Set<String> = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let quickFilters: [(group: String, value: String, amber: Bool)] = [
        ("SSID", "Home Wi-Fi 6E",  false),
        ("SSID", "IGA_Guest",        false),
        ("SSID", "Unknown",          true),
        ("APP",  "Safari",           false),
        ("APP",  "Slack",           false),
        ("APP",  "Spotify",          false)
    ]

    var body: some View {
        VStack(spacing: 0) {
            chipBand
            Rectangle().fill(MV.hairline).frame(height: 1)
            if pivot == .network {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        if !activeFilters.isEmpty { activeFilterBanner }
                        NetworkPaneLifetime().frame(minHeight: 320)
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

    private var chipBand: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("PIVOT")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(MV.text4)
                Spacer()
                if !activeFilters.isEmpty {
                    Button("CLEAR FILTERS") { activeFilters.removeAll() }
                        .font(.system(size: 9, weight: .semibold))
                        .buttonStyle(.plain)
                        .foregroundStyle(MV.warning)
                }
            }
            FlowLayout(spacing: 6) {
                ForEach(NetworkPanePivot.allCases) { p in
                    pivotChip(p)
                }
            }
            HStack(spacing: 6) {
                Text("QUICK FILTERS")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(MV.text4)
                previewBadge
                Spacer()
            }
            FlowLayout(spacing: 6) {
                ForEach(quickFilters, id: \.value) { f in
                    filterChip(group: f.group, value: f.value, amber: f.amber)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(MV.tile)
    }

    private func pivotChip(_ item: NetworkPanePivot) -> some View {
        let isActive = pivot == item
        return Button {
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.18)) { pivot = item }
        } label: {
            HStack(spacing: 6) {
                Text("BY")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(MV.text4)
                Text(item.shortLabel.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isActive ? MV.text1 : MV.text3)
            }
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(isActive ? MV.accentSage.opacity(0.16) : MV.bg)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isActive ? MV.accentSage.opacity(0.55) : MV.hairlineStrong, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func filterChip(group: String, value: String, amber: Bool) -> some View {
        let key = "\(group):\(value)"
        let isOn = activeFilters.contains(key)
        let activeColor = amber ? MV.warning : MV.accentSage
        return Button {
            if isOn { activeFilters.remove(key) } else { activeFilters.insert(key) }
        } label: {
            HStack(spacing: 6) {
                Text(group)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(isOn ? activeColor.opacity(0.7) : MV.text4)
                Text(value)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isOn ? activeColor : MV.text2)
                if isOn {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(activeColor)
                }
            }
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(isOn ? activeColor.opacity(0.10) : MV.bg)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isOn ? activeColor.opacity(0.5) : MV.hairlineStrong, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var previewBadge: some View {
        Text("PREVIEW, not wired")
            .font(.system(size: 8, weight: .bold))
            .tracking(0.6)
            .foregroundStyle(MV.warning)
            .padding(.horizontal, 6)
            .frame(height: 16)
            .background(MV.warning.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(MV.warning.opacity(0.45), lineWidth: 1)
            )
    }

    private var activeFilterBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(MV.accentSage)
            Text("\(activeFilters.count) filter\(activeFilters.count == 1 ? "" : "s") applied")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(MV.text2)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(MV.accentSage.opacity(0.08))
        .overlay(alignment: .bottom) {
            Rectangle().fill(MV.hairline).frame(height: 1)
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 800
        var lineWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var lineHeight: CGFloat = 0
        for sv in subviews {
            let s = sv.sizeThatFits(.unspecified)
            if lineWidth + s.width > maxWidth, lineWidth > 0 {
                totalHeight += lineHeight + spacing
                lineWidth = 0
                lineHeight = 0
            }
            lineWidth += s.width + spacing
            lineHeight = max(lineHeight, s.height)
        }
        totalHeight += lineHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0
        for sv in subviews {
            let s = sv.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            sv.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            lineHeight = max(lineHeight, s.height)
        }
    }
}

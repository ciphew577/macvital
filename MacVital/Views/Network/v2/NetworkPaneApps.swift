// MacVital/Views/Network/v2/NetworkPaneApps.swift
//
// TOP APPS pane, 42pt rows, dual mini bars (down/up), cross-hover dim, pin chip.
// Consumes AppTrafficRow. Hover/pin state flows from NetworkPanesGrid.
// Matches variant-f-fusion.html § f-pane-apps row design.

import SwiftUI

struct NetworkPaneApps: View {

    let apps: [AppTrafficRow]
    let sort: NetworkSort

    // Hover state owned here, siblings read it from parent
    @Binding var hoveredApp: String?

    // Sibling hover state (read-only, used for dimming)
    let hoveredConnection: String?
    let hoveredDomain: String?

    // Global pin binding (shared across all three panes)
    @Binding var pinnedTarget: PinTarget?

    // IDs of apps that are related to the current hover/pin in sibling panes
    let relatedAppIDs: Set<String>

    let isPivotFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            paneHeader
            colHeader
            rowList
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(pivotAccent)
        .opacity(pivotOpacity)
    }

    // MARK: - Header

    private var paneHeader: some View {
        HStack(spacing: MV.S.s2) {
            Text("TOP APPS")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(MV.text3)

            countBadge

            if let pinned = pinnedAppID {
                pinChip(label: apps.first(where: { $0.id == pinned })?.name ?? pinned) {
                    pinnedTarget = nil
                }
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(MV.tile)
        .overlay(alignment: .bottom) {
            Rectangle().fill(MV.hairline).frame(height: 1)
        }
    }

    private var countBadge: some View {
        Text("\(apps.count) apps")
            .font(.system(size: 9, weight: .semibold).monospacedDigit())
            .foregroundStyle(MV.accentSage)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(MV.accentSage.opacity(0.13))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(MV.accentSage.opacity(0.55), lineWidth: 1)
            )
    }

    private func pinChip(label: String, onClear: @escaping () -> Void) -> some View {
        Button(action: onClear) {
            HStack(spacing: 4) {
                Text(label)
                    .lineLimit(1)
                Text("x")
                    .opacity(0.7)
            }
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(MV.warning)
            .padding(.horizontal, 7)
            .padding(.vertical, 1)
            .background(MV.warning.opacity(0.13))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(MV.warning.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Column header

    private var colHeader: some View {
        HStack(spacing: 0) {
            Text("APP")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("DOWN / UP")
                .frame(width: 122, alignment: .leading)
                .padding(.leading, 8)
            Text("TOTAL")
                .frame(width: 62, alignment: .trailing)
        }
        .font(.system(size: 8.5, weight: .semibold))
        .tracking(1.0)
        .foregroundStyle(MV.text4)
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .background(MV.bg)
        .overlay(alignment: .bottom) {
            Rectangle().fill(MV.hairline).frame(height: 1)
        }
    }

    // MARK: - Row list

    private var rowList: some View {
        let sorted = sortedApps
        let maxDown = sorted.map(\.downBytes).max() ?? 1
        let maxUp   = sorted.map(\.upBytes).max() ?? 1

        return ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(sorted) { row in
                    AppRowView(
                        row: row,
                        maxDown: maxDown,
                        maxUp: maxUp,
                        isPinned: pinnedTarget == .app(row.id),
                        isDimmed: isDimmed(row.id),
                        onHoverChange: { hovering in
                            hoveredApp = hovering ? row.id : nil
                        },
                        onTap: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                if pinnedTarget == .app(row.id) {
                                    pinnedTarget = nil
                                } else {
                                    pinnedTarget = .app(row.id)
                                }
                            }
                        }
                    )
                    Rectangle().fill(MV.hairline).frame(height: 1)
                }
            }
        }
        .background(MV.bg)
    }

    // MARK: - Sorting

    private var sortedApps: [AppTrafficRow] {
        let asc = sort.ascending
        switch sort.key {
        case .download:
            return apps.sorted { asc ? $0.downBytes < $1.downBytes : $0.downBytes > $1.downBytes }
        case .upload:
            return apps.sorted { asc ? $0.upBytes < $1.upBytes : $0.upBytes > $1.upBytes }
        case .total:
            return apps.sorted { asc
                ? ($0.downBytes + $0.upBytes) < ($1.downBytes + $1.upBytes)
                : ($0.downBytes + $0.upBytes) > ($1.downBytes + $1.upBytes)
            }
        case .name:
            return apps.sorted { asc ? $0.name < $1.name : $0.name > $1.name }
        default:
            // Fallback: most active first (natural sort for this pane)
            return apps.sorted { ($0.downBytes + $0.upBytes) > ($1.downBytes + $1.upBytes) }
        }
    }

    // MARK: - Dim logic
    // A row is dimmed when:
    // 1. There is an active hover or pin in a sibling pane (so relatedAppIDs is non-empty)
    // 2. AND this row's id is NOT in the related set
    // Pin always wins, if pinned, hover in this pane is ignored.

    private func isDimmed(_ id: String) -> Bool {
        // If nothing is hovered or pinned in sibling panes, no dimming
        let siblingIsActive = hoveredConnection != nil || hoveredDomain != nil || pinnedTarget != nil
        guard siblingIsActive, !relatedAppIDs.isEmpty else { return false }
        return !relatedAppIDs.contains(id)
    }

    // MARK: - Pivot accent (1pt sage hairline when this pane is focused)

    private var pivotAccent: some View {
        Group {
            if isPivotFocused {
                RoundedRectangle(cornerRadius: 0)
                    .strokeBorder(MV.accentSage.opacity(0.35), lineWidth: 1)
            }
        }
    }

    private var pivotOpacity: Double {
        isPivotFocused ? 1.0 : (pivotDimmed ? 0.80 : 1.0)
    }

    // Pane dims when another pane is pivot-focused (not this one)
    private var pivotDimmed: Bool { !isPivotFocused }

    // MARK: - Helpers

    private var pinnedAppID: String? {
        if case .app(let id) = pinnedTarget { return id }
        return nil
    }
}

// MARK: - AppRowView

private struct AppRowView: View {

    let row: AppTrafficRow
    let maxDown: UInt64
    let maxUp: UInt64
    let isPinned: Bool
    let isDimmed: Bool
    let onHoverChange: (Bool) -> Void
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 0) {
                // Real macOS app icon via AppIconResolver. Falls back to generic
                // app glyph when the bundle ID isn't installed locally.
                Image(nsImage: AppIconResolver.shared.icon(
                    forBundleID: row.id,
                    size: CGSize(width: 24, height: 24)
                ))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .padding(.trailing, 8)

                // Name + subtitle
                VStack(alignment: .leading, spacing: 1) {
                    Text(row.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(MV.text1)
                        .lineLimit(1)
                    Text(row.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(MV.text3)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Dual mini bars
                VStack(spacing: 3) {
                    miniBand(fraction: fraction(row.downBytes, max: maxDown), color: MV.accentSage, label: formatBytes(row.downBytes))
                    miniBand(fraction: fraction(row.upBytes,   max: maxUp),   color: MV.warning,    label: formatBytes(row.upBytes))
                }
                .frame(width: 122)
                .padding(.leading, 8)

                // Total
                Text(formatBytes(row.downBytes + row.upBytes))
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                    .foregroundStyle(MV.text1)
                    .frame(width: 62, alignment: .trailing)
            }
            .padding(.horizontal, 14)
            .frame(height: 42)
            .background(rowBackground)
            .overlay(alignment: .leading) { pinAccent }
            .opacity(isDimmed ? 0.35 : 1.0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
            onHoverChange(hovering)
        }
        .accessibilityLabel(row.name)
        .accessibilityValue("Down \(formatBytes(row.downBytes)), up \(formatBytes(row.upBytes)), total \(formatBytes(row.downBytes + row.upBytes))")
        .accessibilityAddTraits(isPinned ? .isSelected : [])
        .animation(.easeInOut(duration: 0.26), value: isDimmed)
    }

    private var rowBackground: Color {
        if isPinned  { return MV.accentSage.opacity(0.12) }
        if isHovered { return MV.accentSage.opacity(0.08) }
        return MV.tile
    }

    // 4pt left accent block shown when pinned
    private var pinAccent: some View {
        Group {
            if isPinned {
                Rectangle()
                    .fill(MV.accentSage)
                    .frame(width: 4)
            }
        }
    }

    private func miniBand(fraction: Double, color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.055))
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 3)
            Text(label)
                .font(.system(size: 9).monospacedDigit())
                .foregroundStyle(MV.text3)
                .frame(width: 34, alignment: .trailing)
        }
    }

    private func fraction(_ value: UInt64, max: UInt64) -> Double {
        guard max > 0 else { return 0 }
        return min(1.0, Double(value) / Double(max))
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let kb = Double(bytes) / 1024
        let mb = kb / 1024
        let gb = mb / 1024
        if gb >= 1  { return String(format: "%.1f G", gb) }
        if mb >= 1  { return String(format: "%.1f M", mb) }
        if kb >= 1  { return String(format: "%.0f K", kb) }
        return "\(bytes) B"
    }
}

// MARK: - Preview

#Preview("NetworkPaneApps") {
    struct Wrapper: View {
        @State private var hovered: String?   = nil
        @State private var pinned: PinTarget? = nil

        var body: some View {
            NetworkPaneApps(
                apps: PreviewData.apps,
                sort: NetworkSort(key: .download, ascending: false),
                hoveredApp: $hovered,
                hoveredConnection: nil,
                hoveredDomain: nil,
                pinnedTarget: $pinned,
                relatedAppIDs: [],
                isPivotFocused: true
            )
            .frame(width: 380, height: 440)
            .background(MV.bg)
        }
    }
    return Wrapper()
}

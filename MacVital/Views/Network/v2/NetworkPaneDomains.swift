// MacVital/Views/Network/v2/NetworkPaneDomains.swift
//
// TOP DOMAINS pane, 42pt rows, rank index / domain glyph, domain + IP, bytes + first-seen.
// Consumes DomainTrafficRow. Hover/pin state flows from NetworkPanesGrid.
// Matches variant-f-fusion.html § f-pane-dom row design.

import SwiftUI

struct NetworkPaneDomains: View {

    let domains: [DomainTrafficRow]
    let sort: NetworkSort

    @Binding var hoveredDomain: String?

    let hoveredApp: String?
    let hoveredConnection: String?

    @Binding var pinnedTarget: PinTarget?

    let relatedDomainIDs: Set<String>

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
            Text("TOP DOMAINS")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(MV.text3)

            countBadge

            if let pinned = pinnedDomainID {
                let label = domains.first(where: { $0.id == pinned })?.domain ?? pinned
                pinChip(label: label) {
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
        Text("\(domains.count) domains")
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
                Text(label).lineLimit(1)
                Text("x").opacity(0.7)
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
            // Rank spacer
            Color.clear.frame(width: 27)

            Text("DOMAIN")
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("BYTES")
                .frame(width: 68, alignment: .trailing)

            Text("FIRST SEEN")
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
        let sorted = sortedDomains

        return ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(Array(sorted.enumerated()), id: \.element.id) { index, row in
                    DomainRowView(
                        row: row,
                        rank: index + 1,
                        isPinned: pinnedTarget == .domain(row.id),
                        isDimmed: isDimmed(row.id),
                        onHoverChange: { hovering in
                            hoveredDomain = hovering ? row.id : nil
                        },
                        onTap: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                if pinnedTarget == .domain(row.id) {
                                    pinnedTarget = nil
                                } else {
                                    pinnedTarget = .domain(row.id)
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

    private var sortedDomains: [DomainTrafficRow] {
        let asc = sort.ascending
        switch sort.key {
        case .download, .upload, .total, .down, .up:
            return domains.sorted { asc ? $0.totalBytes < $1.totalBytes : $0.totalBytes > $1.totalBytes }
        case .name:
            return domains.sorted { asc ? $0.domain < $1.domain : $0.domain > $1.domain }
        case .firstSeen:
            return domains.sorted { asc ? $0.firstSeen < $1.firstSeen : $0.firstSeen > $1.firstSeen }
        default:
            // Natural sort: highest total bytes first
            return domains.sorted { $0.totalBytes > $1.totalBytes }
        }
    }

    // MARK: - Dim logic

    private func isDimmed(_ id: String) -> Bool {
        let siblingIsActive = hoveredApp != nil || hoveredConnection != nil || pinnedTarget != nil
        guard siblingIsActive, !relatedDomainIDs.isEmpty else { return false }
        return !relatedDomainIDs.contains(id)
    }

    // MARK: - Pivot accent

    private var pivotAccent: some View {
        Group {
            if isPivotFocused {
                RoundedRectangle(cornerRadius: 0)
                    .strokeBorder(MV.accentSage.opacity(0.35), lineWidth: 1)
            }
        }
    }

    private var pivotOpacity: Double { isPivotFocused ? 1.0 : 0.80 }

    // MARK: - Helpers

    private var pinnedDomainID: String? {
        if case .domain(let id) = pinnedTarget { return id }
        return nil
    }
}

// MARK: - DomainRowView

private struct DomainRowView: View {

    let row: DomainTrafficRow
    let rank: Int
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
                // Rank glyph: numbers 1-9 as text, or domain initial in a sage circle
                rankGlyph
                    .frame(width: 18)
                    .padding(.trailing, 9)

                // Domain + resolved IP
                VStack(alignment: .leading, spacing: 1) {
                    Text(row.domain)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(MV.text1)
                        .lineLimit(1)
                    Text(row.resolvedIP)
                        .font(.system(size: 9).monospaced())
                        .foregroundStyle(MV.text4)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Total bytes
                Text(formatBytes(row.totalBytes))
                    .font(.system(size: 10.5, weight: .semibold).monospacedDigit())
                    .foregroundStyle(MV.text2)
                    .frame(width: 68, alignment: .trailing)

                // First seen relative
                VStack(alignment: .trailing, spacing: 1) {
                    Text(relativeTime(row.firstSeen))
                        .font(.system(size: 9).monospacedDigit())
                        .foregroundStyle(MV.text3)
                }
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
        .accessibilityLabel("Domain \(row.domain), rank \(rank)")
        .accessibilityValue("Resolved IP \(row.resolvedIP), total \(formatBytes(row.totalBytes))")
        .accessibilityAddTraits(isPinned ? .isSelected : [])
        .animation(.easeInOut(duration: 0.26), value: isDimmed)
    }

    // Ranks 1-9 as styled numbers; 10+ as a domain initial circle
    private var rankGlyph: some View {
        Group {
            if rank <= 9 {
                Text("\(rank)")
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(rank <= 3 ? MV.accentSage : MV.text3)
                    .frame(width: 18, alignment: .trailing)
            } else {
                ZStack {
                    Circle()
                        .fill(MV.accentSage.opacity(0.15))
                        .frame(width: 18, height: 18)
                    Text(String(row.domain.prefix(1)).uppercased())
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(MV.accentSage)
                }
            }
        }
    }

    private var rowBackground: Color {
        if isPinned  { return MV.accentSage.opacity(0.12) }
        if isHovered { return MV.accentSage.opacity(0.08) }
        return MV.tile
    }

    private var pinAccent: some View {
        Group {
            if isPinned {
                Rectangle()
                    .fill(MV.accentSage)
                    .frame(width: 4)
            }
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let kb = Double(bytes) / 1024
        let mb = kb / 1024
        let gb = mb / 1024
        if gb >= 1  { return String(format: "%.1f GB", gb) }
        if mb >= 1  { return String(format: "%.1f MB", mb) }
        if kb >= 1  { return String(format: "%.0f KB", kb) }
        return "\(bytes) B"
    }

    private func relativeTime(_ date: Date) -> String {
        let interval = -date.timeIntervalSinceNow
        let minutes = Int(interval / 60)
        let hours   = minutes / 60
        if hours >= 1   { return "\(hours)h ago" }
        if minutes >= 1 { return "\(minutes)m ago" }
        return "just now"
    }
}

// MARK: - Preview

#Preview("NetworkPaneDomains") {
    struct Wrapper: View {
        @State private var hovered: String?   = nil
        @State private var pinned: PinTarget? = nil

        var body: some View {
            NetworkPaneDomains(
                domains: PreviewData.domains,
                sort: NetworkSort(key: .download, ascending: false),
                hoveredDomain: $hovered,
                hoveredApp: nil,
                hoveredConnection: nil,
                pinnedTarget: $pinned,
                relatedDomainIDs: [],
                isPivotFocused: false
            )
            .frame(width: 380, height: 440)
            .background(MV.bg)
        }
    }
    return Wrapper()
}

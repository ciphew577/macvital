// MacVital/Views/Network/v2/NetworkPaneConnections.swift
//
// LIVE CONNECTIONS pane, 42pt rows, socket pair, process + PID, live Bps indicator.
// Consumes ConnectionRow. Hover/pin state flows from NetworkPanesGrid.
// Matches variant-f-fusion.html § f-pane-conn row design.

import SwiftUI

struct NetworkPaneConnections: View {

    let connections: [ConnectionRow]
    let sort: NetworkSort

    @Binding var hoveredConnection: String?

    let hoveredApp: String?
    let hoveredDomain: String?

    @Binding var pinnedTarget: PinTarget?

    let relatedConnectionIDs: Set<String>

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
            Text("LIVE CONNECTIONS")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(MV.text3)

            countBadge

            if let pinned = pinnedConnectionID {
                let label = connections.first(where: { $0.id == pinned })?.processName ?? pinned
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
        Text("\(connections.count) sockets")
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
            // Alert dot spacer
            Color.clear.frame(width: 27)

            Text("SOCKET")
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("PROCESS")
                .frame(width: 90, alignment: .leading)

            Text("SPEED")
                .frame(width: 68, alignment: .trailing)
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
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(sortedConnections) { row in
                    ConnectionRowView(
                        row: row,
                        isPinned: pinnedTarget == .connection(row.id),
                        isDimmed: isDimmed(row.id),
                        onHoverChange: { hovering in
                            hoveredConnection = hovering ? row.id : nil
                        },
                        onTap: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                if pinnedTarget == .connection(row.id) {
                                    pinnedTarget = nil
                                } else {
                                    pinnedTarget = .connection(row.id)
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

    private var sortedConnections: [ConnectionRow] {
        let asc = sort.ascending
        switch sort.key {
        case .download, .upload, .downPerSec, .upPerSec:
            return connections.sorted { asc ? $0.currentBps < $1.currentBps : $0.currentBps > $1.currentBps }
        case .name:
            return connections.sorted { asc ? $0.processName < $1.processName : $0.processName > $1.processName }
        default:
            // Natural sort: highest Bps first
            return connections.sorted { $0.currentBps > $1.currentBps }
        }
    }

    // MARK: - Dim logic

    private func isDimmed(_ id: String) -> Bool {
        let siblingIsActive = hoveredApp != nil || hoveredDomain != nil || pinnedTarget != nil
        guard siblingIsActive, !relatedConnectionIDs.isEmpty else { return false }
        return !relatedConnectionIDs.contains(id)
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

    private var pinnedConnectionID: String? {
        if case .connection(let id) = pinnedTarget { return id }
        return nil
    }
}

// MARK: - ConnectionRowView

private struct ConnectionRowView: View {

    let row: ConnectionRow
    let isPinned: Bool
    let isDimmed: Bool
    let onHoverChange: (Bool) -> Void
    let onTap: () -> Void

    @State private var isHovered = false
    @State private var pulseTick = false

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 0) {
                // Alert dot (amber when high throughput, otherwise invisible)
                Circle()
                    .fill(row.currentBps > 500_000 ? MV.warning : Color.clear)
                    .frame(width: 5, height: 5)
                    .padding(.trailing, 6)
                    .frame(width: 11)

                // Socket block
                VStack(alignment: .leading, spacing: 1) {
                    // Socket pair
                    HStack(spacing: 0) {
                        Text(row.localSocket)
                            .foregroundStyle(MV.text3)
                        Text(" \u{2192} ")
                            .foregroundStyle(MV.text4)
                        Text(row.remoteSocket)
                            .foregroundStyle(MV.text2)
                    }
                    .font(.system(size: 10, weight: .medium).monospaced())
                    .lineLimit(1)

                    // Resolved domain (if available)
                    if let domain = row.domain {
                        Text(domain)
                            .font(.system(size: 9.5).monospaced())
                            .foregroundStyle(MV.accentSage)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Process + PID
                VStack(alignment: .leading, spacing: 1) {
                    Text(row.processName)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(MV.text2)
                        .lineLimit(1)
                    Text("pid \(row.pid)")
                        .font(.system(size: 9).monospacedDigit())
                        .foregroundStyle(MV.text4)
                }
                .frame(width: 90, alignment: .leading)

                // Speed + live indicator
                VStack(alignment: .trailing, spacing: 1) {
                    Text(formatBps(row.currentBps))
                        .font(.system(size: 13, weight: .medium).monospacedDigit())
                        .foregroundStyle(row.currentBps > 0 ? MV.accentSage : MV.text3)

                    HStack(spacing: 3) {
                        Circle()
                            .fill(MV.text3)
                            .frame(width: 4, height: 4)
                            .opacity(pulseTick ? 1.0 : 0.35)
                            .animation(
                                .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                                value: pulseTick
                            )
                        Text("live")
                            .font(.system(size: 9))
                            .foregroundStyle(MV.text3)
                    }
                }
                .frame(width: 68, alignment: .trailing)
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
        .accessibilityLabel("Connection \(row.processName), PID \(row.pid)")
        .accessibilityValue("\(row.localSocket) to \(row.remoteSocket)\(row.domain.map { ", domain \($0)" } ?? ""), \(formatBps(row.currentBps))")
        .accessibilityAddTraits(isPinned ? .isSelected : [])
        .animation(.easeInOut(duration: 0.26), value: isDimmed)
        .onAppear { pulseTick = true }
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

    private func formatBps(_ bps: UInt64) -> String {
        let kb = Double(bps) / 1024
        let mb = kb / 1024
        if mb >= 1  { return String(format: "%.1f M/s", mb) }
        if kb >= 1  { return String(format: "%.0f K/s", kb) }
        return "\(bps) B/s"
    }
}

// MARK: - Preview

#Preview("NetworkPaneConnections") {
    struct Wrapper: View {
        @State private var hovered: String?   = nil
        @State private var pinned: PinTarget? = nil

        var body: some View {
            NetworkPaneConnections(
                connections: PreviewData.connections,
                sort: NetworkSort(key: .download, ascending: false),
                hoveredConnection: $hovered,
                hoveredApp: nil,
                hoveredDomain: nil,
                pinnedTarget: $pinned,
                relatedConnectionIDs: [],
                isPivotFocused: false
            )
            .frame(width: 380, height: 440)
            .background(MV.bg)
        }
    }
    return Wrapper()
}

// MacVital/Views/Network/v2/NetworkColumnHeader.swift
//
// Adaptive column header row for the Network pane.
// Columns swap when pivot changes with .opacity transition (0.24s).
// Each label is a sort trigger. Active sort key shows in MV.accentSage + arrow glyph.
// Height: 28pt. Matches mockups/redesign-2026-04-23/network/variant-f-fusion.html § 5.

import SwiftUI

// MARK: - Column descriptor

private struct ColSpec: Identifiable {
    let id: NetworkSortKeyV2
    let label: String
    let minWidth: CGFloat
    let flexible: Bool

    init(_ key: NetworkSortKeyV2, minWidth: CGFloat, flexible: Bool = false) {
        self.id       = key
        self.label    = key.label
        self.minWidth = minWidth
        self.flexible = flexible
    }
}

// MARK: - Column sets per pivot

private extension NetworkPanePivot {

    // Widths chosen to match pixel proportions from the HTML mockup at 1400px total.
    // The 1400px viewport uses a three-pane fusion layout; for the unified header row
    // we map the full-width spec below. One flexible column per pivot absorbs spare width.

    var columns: [ColSpec] {
        switch self {
        case .interface:
            return [
                ColSpec(.name,      minWidth: 160, flexible: true),
                ColSpec(.status,    minWidth: 72),
                ColSpec(.download,  minWidth: 88),
                ColSpec(.upload,    minWidth: 88),
                ColSpec(.total,     minWidth: 80),
                ColSpec(.sessions,  minWidth: 72),
                ColSpec(.peak,      minWidth: 80),
                ColSpec(.lastSeen,  minWidth: 88),
                ColSpec(.share,     minWidth: 56),
            ]
        case .app:
            return [
                ColSpec(.name,      minWidth: 180, flexible: true),
                ColSpec(.pid,       minWidth: 56),
                ColSpec(.download,  minWidth: 88),
                ColSpec(.upload,    minWidth: 88),
                ColSpec(.total,     minWidth: 80),
                ColSpec(.conns,     minWidth: 64),
                ColSpec(.firstSeen, minWidth: 88),
                ColSpec(.share,     minWidth: 56),
            ]
        case .process:
            return [
                ColSpec(.name,      minWidth: 160, flexible: true),
                ColSpec(.pid,       minWidth: 56),
                ColSpec(.downPerSec,minWidth: 72),
                ColSpec(.upPerSec,  minWidth: 72),
                ColSpec(.totalDown, minWidth: 88),
                ColSpec(.totalUp,   minWidth: 80),
                ColSpec(.sockets,   minWidth: 64),
                ColSpec(.cpu,       minWidth: 56),
                ColSpec(.share,     minWidth: 56),
            ]
        case .domain:
            return [
                ColSpec(.name,      minWidth: 200, flexible: true),
                ColSpec(.resolvedIP,minWidth: 120),
                ColSpec(.down,      minWidth: 80),
                ColSpec(.up,        minWidth: 80),
                ColSpec(.firstSeen, minWidth: 88),
                ColSpec(.lastSeen,  minWidth: 88),
                ColSpec(.share,     minWidth: 56),
            ]
        case .network:
            // The Lifetime pane (NetworkPaneLifetime) renders its own header.
            // This entry is required for switch exhaustiveness; the unified
            // column header is not used in the network pivot.
            return [
                ColSpec(.name,      minWidth: 200, flexible: true),
                ColSpec(.firstSeen, minWidth: 88),
                ColSpec(.lastSeen,  minWidth: 88),
                ColSpec(.download,  minWidth: 88),
                ColSpec(.upload,    minWidth: 88),
                ColSpec(.total,     minWidth: 80),
            ]
        }
    }
}

// MARK: - Column header row

struct NetworkColumnHeader: View {
    let pivot: NetworkPanePivot
    @Binding var sort: NetworkSort

    var body: some View {
        HStack(spacing: 0) {
            ForEach(pivot.columns) { col in
                headerCell(col)
            }
        }
        .padding(.horizontal, MV.S.s4)
        .frame(height: 28)
        .background(MV.tile)
        .overlay(alignment: .bottom) { hairline }
        .transition(.opacity)
        .animation(.smooth(duration: 0.24), value: pivot)
    }

    // MARK: Single cell

    private func headerCell(_ col: ColSpec) -> some View {
        let isActive = sort.key == col.id

        return Button {
            if sort.key == col.id {
                sort.ascending.toggle()
            } else {
                sort = NetworkSort(key: col.id, ascending: false)
            }
        } label: {
            HStack(spacing: 4) {
                Text(col.label)
                    .font(.system(size: MV.FS.micro, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(isActive ? MV.accentSage : MV.text3)
                    .lineLimit(1)

                if isActive {
                    Text(sort.ascending ? "↑" : "↓")
                        .font(.system(size: MV.FS.micro, weight: .semibold))
                        .foregroundStyle(MV.accentSage)
                }
            }
            .frame(
                minWidth: col.minWidth,
                maxWidth: col.flexible ? .infinity : col.minWidth,
                alignment: .leading
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(col.label.capitalized)
    }

    // MARK: Hairline

    private var hairline: some View {
        Rectangle().fill(MV.hairline).frame(height: 1)
    }
}

// MARK: - Preview

#Preview("NetworkColumnHeader") {
    struct Wrapper: View {
        @State private var pivot: NetworkPanePivot = .interface
        @State private var sort  = NetworkSort()

        var body: some View {
            VStack(spacing: 0) {
                // Pivot switcher for interactive testing
                HStack(spacing: 8) {
                    ForEach(NetworkPanePivot.allCases) { p in
                        Button(p.shortLabel) {
                            withAnimation(.smooth(duration: 0.24)) { pivot = p }
                        }
                        .font(.system(size: MV.FS.caption))
                        .foregroundStyle(pivot == p ? MV.accentSage : MV.text3)
                        .buttonStyle(.plain)
                    }
                }
                .padding(MV.S.s3)
                .background(MV.bg)

                NetworkColumnHeader(pivot: pivot, sort: $sort)
                    .frame(width: 900)

                // Current sort readout
                Text("Sort: \(sort.key.label)  \(sort.ascending ? "asc" : "desc")")
                    .font(.system(size: MV.FS.caption))
                    .foregroundStyle(MV.text3)
                    .padding(MV.S.s3)
                    .background(MV.bg)
            }
            .background(MV.bg)
        }
    }
    return Wrapper()
}


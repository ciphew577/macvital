// MacVital/Views/Network/v2/NetworkPivotBar.swift
//
// Pivot bar (segment control + search field + sort chip) for the Network pane.
// Height: 44pt. MV token palette. No hardcoded font sizes except MV.FS.micro (10pt).
// Matches mockups/redesign-2026-04-23/network/variant-f-fusion.html § 4 PIVOT + FILTER BAR.

import SwiftUI

// MARK: - Pivot enum

enum NetworkPanePivot: String, CaseIterable, Identifiable {
    case interface = "By Interface"
    case network   = "By Network"
    case app       = "By App"
    case process   = "By Process"
    case domain    = "By Domain"

    var id: String { rawValue }

    /// Short label used inside the segment button.
    var shortLabel: String {
        switch self {
        case .interface: return "Interface"
        case .network:   return "Network"
        case .app:       return "App"
        case .process:   return "Process"
        case .domain:    return "Domain"
        }
    }
}

// MARK: - Sort key enum

enum NetworkSortKeyV2: String, CaseIterable {
    case name, status, download, upload, total
    case sessions, peak, lastSeen, share
    // app-specific
    case pid, conns, firstSeen
    // process-specific
    case downPerSec, upPerSec, totalDown, totalUp, sockets, cpu
    // domain-specific
    case resolvedIP, down, up

    var label: String {
        switch self {
        case .name:       return "NAME"
        case .status:     return "STATUS"
        case .download:   return "DOWNLOAD"
        case .upload:     return "UPLOAD"
        case .total:      return "TOTAL"
        case .sessions:   return "SESSIONS"
        case .peak:       return "PEAK"
        case .lastSeen:   return "LAST SEEN"
        case .share:      return "SHARE"
        case .pid:        return "PID"
        case .conns:      return "CONNS"
        case .firstSeen:  return "FIRST SEEN"
        case .downPerSec: return "DOWN/s"
        case .upPerSec:   return "UP/s"
        case .totalDown:  return "TOTAL DOWN"
        case .totalUp:    return "TOTAL UP"
        case .sockets:    return "SOCKETS"
        case .cpu:        return "CPU"
        case .resolvedIP: return "RESOLVED IP"
        case .down:       return "DOWN"
        case .up:         return "UP"
        }
    }
}

// MARK: - Sort state

struct NetworkSort: Equatable {
    var key: NetworkSortKeyV2 = .download
    var ascending: Bool = false
}

// MARK: - Pivot bar

struct NetworkPivotBar: View {
    @Binding var pivot: NetworkPanePivot
    @Binding var searchText: String
    @Binding var sort: NetworkSort

    var body: some View {
        HStack(spacing: MV.S.s2) {
            segmentControl
            searchField
            sortChip
        }
        .padding(.horizontal, MV.S.s4)
        .frame(height: 44)
        .background(MV.tile)
        .overlay(alignment: .top)    { hairline }
        .overlay(alignment: .bottom) { hairline }
    }

    // MARK: Segment control

    private var segmentControl: some View {
        HStack(spacing: 0) {
            ForEach(NetworkPanePivot.allCases) { item in
                segButton(item)
                    .overlay(alignment: .trailing) {
                        if item != NetworkPanePivot.allCases.last {
                            Rectangle()
                                .fill(MV.hairline)
                                .frame(width: 1)
                        }
                    }
            }
        }
        .background(MV.bg)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(MV.hairlineStrong, lineWidth: 1)
        )
    }

    private func segButton(_ item: NetworkPanePivot) -> some View {
        let isActive = pivot == item
        return Button {
            withAnimation(.smooth(duration: 0.2)) { pivot = item }
        } label: {
            Text(item.shortLabel.uppercased())
                .font(.system(size: MV.FS.micro, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(isActive ? MV.accentSage : MV.text3)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(
                    isActive
                        ? MV.accentSage.opacity(0.10)
                        : Color.clear
                )
                .overlay(
                    isActive
                        ? RoundedRectangle(cornerRadius: 0)
                            .strokeBorder(MV.accentSage.opacity(0.55), lineWidth: 1)
                        : nil
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: Search field

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: MV.FS.micro))
                .foregroundStyle(MV.text3)
            TextField("Search...", text: $searchText)
                .font(.system(size: MV.FS.body))
                .foregroundStyle(MV.text2)
                .textFieldStyle(.plain)
                .tint(MV.accentSage)
        }
        .padding(.horizontal, 10)
        .frame(width: 240, height: 26)
        .background(MV.bg)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(MV.hairlineStrong, lineWidth: 1)
        )
    }

    // MARK: Sort chip

    private var sortChip: some View {
        Button {
            sort.ascending.toggle()
        } label: {
            HStack(spacing: 5) {
                Text("SORT: \(sort.key.label) \(sort.ascending ? "↑" : "↓")")
                    .font(.system(size: MV.FS.micro, weight: .medium))
                    .tracking(0.6)
                    .foregroundStyle(MV.text3)
            }
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(MV.bg)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(MV.hairlineStrong, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    // MARK: Hairline

    private var hairline: some View {
        Rectangle().fill(MV.hairline).frame(height: 1)
    }
}

// MARK: - Preview

#Preview("NetworkPivotBar") {
    struct Wrapper: View {
        @State private var pivot: NetworkPanePivot = .interface
        @State private var search = ""
        @State private var sort   = NetworkSort()

        var body: some View {
            NetworkPivotBar(pivot: $pivot, searchText: $search, sort: $sort)
                .frame(width: 900)
                .background(MV.bg)
        }
    }
    return Wrapper()
}

// MacVital/Views/Network/v2/NetworkPaneLifetime.swift
//
// Lifetime per-SSID usage pane. Rendered by NetworkViewV2 when the pivot is
// set to `.network`. Replaces the three-pane APPS / CONNECTIONS / DOMAINS grid
// with a single scrollable list focused on cumulative bytes per Wi-Fi network.
//
// UX decision: Option A from the spec, a new pivot segment rather than a
// sub-toggle inside the BY INTERFACE tab. Reason: the interface tab shows
// every BSD adapter (utun, bridge0, awdl0 ...) and would look cluttered if
// the per-SSID rollup were folded in. Promoting to its own pivot gives the
// feature a clean grand-total banner and per-row Reset buttons without
// compromising the interface pane's current utility.
//
// Data contract:
//   - `PerSSIDUsageStore` in the environment owns buckets + persistence.
//   - `SystemMonitor.attributePerSSIDDeltas` feeds the store each 2s tick.
//   - This view is read-only for byte data and mutates only via reset actions.
//
// Visual language: mirrors NetworkPaneApps row layout (dual mini bars, total
// on the right, monospaced digits) so the two panes feel like siblings. The
// grand-total row at the top echoes the masthead's "TODAY" card.

import SwiftUI

struct NetworkPaneLifetime: View {

    @Environment(\.perSSIDUsageStore) private var store

    @State private var pendingReset: PendingReset?

    /// Either a single-SSID reset or a global reset waiting for confirmation.
    private enum PendingReset: Identifiable {
        case single(ssid: String)
        case all

        var id: String {
            switch self {
            case .single(let ssid): return "single.\(ssid)"
            case .all:              return "all"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            grandTotalBanner
            columnHeader
            rowList
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MV.bg)
        .alert(
            alertTitle,
            isPresented: alertBinding,
            presenting: pendingReset,
            actions: { pending in
                Button("Cancel", role: .cancel) { pendingReset = nil }
                Button("Reset", role: .destructive) {
                    switch pending {
                    case .single(let ssid): store?.reset(ssid: ssid)
                    case .all:              store?.resetAll()
                    }
                    pendingReset = nil
                }
            },
            message: { pending in
                switch pending {
                case .single:
                    Text("This cannot be undone.")
                case .all:
                    Text("This zeroes the lifetime total for every Wi-Fi network. This cannot be undone.")
                }
            }
        )
    }

    // MARK: - Alert plumbing

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { pendingReset != nil },
            set: { newValue in
                if !newValue { pendingReset = nil }
            }
        )
    }

    private var alertTitle: String {
        switch pendingReset {
        case .single(let ssid): return "Reset usage for \(displayName(for: ssid))?"
        case .all:              return "Reset usage for every network?"
        case .none:             return ""
        }
    }

    // MARK: - Grand total banner

    private var grandTotalBanner: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("TOTAL ALL NETWORKS")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(MV.text3)

                HStack(spacing: 10) {
                    valueBlock(label: "DOWN", bytes: store?.totalBytesIn ?? 0, color: MV.accentSage)
                    valueBlock(label: "UP",   bytes: store?.totalBytesOut ?? 0, color: MV.warning)
                    valueBlock(label: "TOTAL",bytes: (store?.totalBytes ?? 0), color: MV.text1)
                }
            }

            Spacer()

            if let hint = permissionHint {
                Text(hint)
                    .font(.system(size: 10))
                    .foregroundStyle(MV.warning)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 220, alignment: .trailing)
            }

            resetAllButton
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(MV.tile)
        .overlay(alignment: .bottom) {
            Rectangle().fill(MV.hairline).frame(height: 1)
        }
    }

    private func valueBlock(label: String, bytes: UInt64, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 8.5, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(MV.text4)
            Text(formatBytes(bytes))
                .font(.system(size: 16, weight: .semibold).monospacedDigit())
                .foregroundStyle(color)
        }
    }

    private var resetAllButton: some View {
        Button {
            // Only arm the prompt when there is something to reset.
            guard let store, !store.perSSID.isEmpty else { return }
            pendingReset = .all
        } label: {
            Text("RESET ALL")
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(MV.warning)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(MV.warning.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(MV.warning.opacity(0.45), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .opacity((store?.perSSID.isEmpty ?? true) ? 0.35 : 1.0)
        .help("Reset lifetime totals for every network")
    }

    // MARK: - Column header

    private var columnHeader: some View {
        HStack(spacing: 0) {
            Text("NETWORK")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("DOWN / UP")
                .frame(width: 122, alignment: .leading)
                .padding(.leading, 8)
            Text("TOTAL")
                .frame(width: 62, alignment: .trailing)
            Text("")
                .frame(width: 54, alignment: .trailing)
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
        let rows = sortedRows
        let maxDown = rows.map(\.bytesIn).max() ?? 1
        let maxUp   = rows.map(\.bytesOut).max() ?? 1

        return Group {
            if rows.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(rows) { row in
                            LifetimeRowView(
                                row: row,
                                maxDown: maxDown,
                                maxUp: maxUp,
                                displayName: displayName(for: row.id),
                                onResetTap: {
                                    pendingReset = .single(ssid: row.id)
                                }
                            )
                            Rectangle().fill(MV.hairline).frame(height: 1)
                        }
                    }
                }
                .background(MV.bg)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(MV.text3)
            Text("No lifetime data yet")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(MV.text2)
            Text("Traffic will start accumulating once this Mac is connected to Wi-Fi.")
                .font(.system(size: 11))
                .foregroundStyle(MV.text3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Derived data

    private var sortedRows: [PerSSIDUsage] {
        store?.sortedBuckets ?? []
    }

    /// If the unknown bucket has traffic, hint the user about Location permission.
    /// macOS 14+ returns nil for CoreWLAN SSID unless Location Services is on.
    private var permissionHint: String? {
        guard let store else { return nil }
        let unknown = store.perSSID[PerSSIDUsageStore.unknownKey]
        guard let bucket = unknown, bucket.totalBytes > 0 else { return nil }
        return "Some traffic is unlabelled. Grant Location access in System Settings so SSIDs can be read."
    }

    /// Replaces the technical sentinel with a short human label.
    private func displayName(for key: String) -> String {
        key == PerSSIDUsageStore.unknownKey ? "Unknown network" : key
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let b = Double(bytes)
        if b < 1_000          { return "\(bytes) B" }
        if b < 1_000_000      { return String(format: "%.1f KB", b / 1_000) }
        if b < 1_000_000_000  { return String(format: "%.1f MB", b / 1_000_000) }
        return String(format: "%.2f GB", b / 1_000_000_000)
    }
}

// MARK: - Row view

private struct LifetimeRowView: View {

    let row: PerSSIDUsage
    let maxDown: UInt64
    let maxUp: UInt64
    let displayName: String
    let onResetTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 0) {
            iconBlock
                .padding(.trailing, 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(displayName)
                    .font(.system(size: 13, weight: .medium, design: isUnknown ? .monospaced : .default))
                    .foregroundStyle(MV.text1)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(MV.text3)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 3) {
                miniBand(fraction: fraction(row.bytesIn, max: maxDown), color: MV.accentSage, label: shortBytes(row.bytesIn))
                miniBand(fraction: fraction(row.bytesOut, max: maxUp),  color: MV.warning,    label: shortBytes(row.bytesOut))
            }
            .frame(width: 122)
            .padding(.leading, 8)

            Text(shortBytes(row.totalBytes))
                .font(.system(size: 13, weight: .medium).monospacedDigit())
                .foregroundStyle(MV.text1)
                .frame(width: 62, alignment: .trailing)

            resetButton
                .frame(width: 54, alignment: .trailing)
                .padding(.leading, 4)
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(isHovered ? MV.accentSage.opacity(0.06) : MV.tile)
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
    }

    private var isUnknown: Bool { row.id == PerSSIDUsageStore.unknownKey }

    private var iconBlock: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(isUnknown ? MV.warning.opacity(0.14) : MV.accentSage.opacity(0.14))
                .frame(width: 24, height: 24)
            Image(systemName: isUnknown ? "wifi.exclamationmark" : "wifi")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isUnknown ? MV.warning : MV.accentSage)
        }
    }

    private var subtitle: String {
        let first = Self.dateFormatter.string(from: row.firstSeen)
        let last  = Self.dateFormatter.string(from: row.lastSeen)
        return "first \(first)  ·  last \(last)"
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM yy"
        return f
    }()

    private var resetButton: some View {
        Button(action: onResetTap) {
            Text("RESET")
                .font(.system(size: 8.5, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(MV.warning)
                .padding(.horizontal, 7)
                .frame(height: 22)
                .background(MV.warning.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(MV.warning.opacity(0.35), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .opacity(isHovered ? 1.0 : 0.35)
        .help("Reset lifetime usage for this network")
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

    private func shortBytes(_ bytes: UInt64) -> String {
        let b = Double(bytes)
        if b < 1_000          { return "\(bytes) B" }
        if b < 1_000_000      { return String(format: "%.0f K", b / 1_000) }
        if b < 1_000_000_000  { return String(format: "%.1f M", b / 1_000_000) }
        return String(format: "%.1f G", b / 1_000_000_000)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("NetworkPaneLifetime") {
    let store = PerSSIDUsageStore()
    store.recordDelta(ssid: "Home Wi-Fi 6 GHz", deltaIn: 84_300_000_000, deltaOut: 5_100_000_000)
    store.recordDelta(ssid: "IGA_Clarinda_Guest",   deltaIn:  4_200_000_000, deltaOut:   320_000_000)
    store.recordDelta(ssid: "Starbucks WiFi",        deltaIn:     880_000_000, deltaOut:    42_000_000)
    store.recordDelta(ssid: nil,                     deltaIn:      12_500_000, deltaOut:     1_800_000)
    return NetworkPaneLifetime()
        .environment(\.perSSIDUsageStore, store)
        .frame(width: 1_100, height: 480)
        .background(MV.bg)
}
#endif

// Variant selector + shared placeholder/breakdown helpers for NETWORK V2 (mockup 2026-04-25).

import SwiftUI

enum NetworkV2Variant: Int, CaseIterable, Identifiable {
    case segmentedPivot      = 0
    case leftRailTabs        = 1
    case chipCloud           = 2
    case breadcrumbDrilldown = 3
    case splitPane           = 4

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .segmentedPivot:      return "Segmented Pivot"
        case .leftRailTabs:        return "Left Rail Tabs"
        case .chipCloud:           return "Chip Cloud"
        case .breadcrumbDrilldown: return "Breadcrumb Drilldown"
        case .splitPane:           return "Split Pane"
        }
    }

    var shortLabel: String {
        switch self {
        case .segmentedPivot:      return "SEG"
        case .leftRailTabs:        return "RAIL"
        case .chipCloud:           return "CHIP"
        case .breadcrumbDrilldown: return "DRILL"
        case .splitPane:           return "SPLIT"
        }
    }
}

enum NetworkV2VariantStorageKey {
    static let key = "com.macvital.networkv2.variant"
}

struct NetworkV2PivotPlaceholder: View {
    let pivot: NetworkPanePivot

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "hourglass")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(MV.text3)
            Text("BY \(pivot.shortLabel.uppercased())")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(MV.text2)
            Text("This pivot is wired to the legacy panes grid. Use the BY NETWORK pivot to see the per-SSID lifetime view.")
                .font(.system(size: 11))
                .foregroundStyle(MV.text3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .background(MV.bg)
    }
}

struct NetworkV2AppBreakdown: View {
    private let apps: [(String, String, UInt64, UInt64)] = [
        ("Safari",            "com.apple.Safari",          12_300_000_000, 480_000_000),
        ("Slack",            "com.tinyspeck.slackmacgap",       4_120_000_000, 96_000_000),
        ("Spotify",           "com.spotify.client",         1_840_000_000, 22_000_000),
        ("System Update",     "com.apple.softwareupdate",   2_240_000_000, 18_000_000),
        ("Mail",              "com.apple.mail",                240_000_000, 84_000_000)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Rectangle().fill(MV.hairline).frame(height: 1)
            ForEach(apps, id: \.1) { row in
                appRow(name: row.0, bundle: row.1, down: row.2, up: row.3)
                Rectangle().fill(MV.hairline).frame(height: 1)
            }
        }
        .background(MV.tile)
    }

    private var header: some View {
        HStack(spacing: 0) {
            Text("APP BREAKDOWN, ACTIVE NETWORK")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(MV.text3)
            Spacer()
            Text("DOWN / UP / TOTAL")
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(MV.text4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func appRow(name: String, bundle: String, down: UInt64, up: UInt64) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(MV.accentSage.opacity(0.14))
                    .frame(width: 22, height: 22)
                Image(systemName: "app.dashed")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(MV.accentSage)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(MV.text1)
                Text(bundle)
                    .font(.system(size: 9.5).monospacedDigit())
                    .foregroundStyle(MV.text4)
            }
            Spacer()
            Text(formatBytes(down))
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(MV.accentSage)
                .frame(width: 60, alignment: .trailing)
            Text(formatBytes(up))
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(MV.warning)
                .frame(width: 60, alignment: .trailing)
            Text(formatBytes(down &+ up))
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(MV.text1)
                .frame(width: 70, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let b = Double(bytes)
        if b < 1_000_000      { return String(format: "%.0f K", b / 1_000) }
        if b < 1_000_000_000  { return String(format: "%.1f M", b / 1_000_000) }
        return String(format: "%.2f G", b / 1_000_000_000)
    }
}

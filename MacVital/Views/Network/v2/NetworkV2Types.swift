// MacVital/Views/Network/v2/NetworkV2Types.swift
//
// Canonical type definitions consumed by every other V2 file.
// NO SwiftUI or AppKit imports. Foundation only.
//
// Merge note: on merge, remove the placeholder type blocks from:
//   - NetworkBigChart.swift  (NetworkSample, NetworkChartSeries, NetworkSparkCard)
//   - NetworkPanesGrid.swift (AppTrafficRow, ConnectionRow, DomainTrafficRow)
//   - NetworkSparkCards.swift (NetworkSparkCard enum)
//   - NetworkMasthead.swift  (private _PreviewTimeRange stub inside #if DEBUG)
// Then verify the module compiles before deleting those lines.

import Foundation

// MARK: - Time range

/// The five selectable time windows shown in the masthead chip row.
enum NetworkTimeRange: String, CaseIterable, Identifiable, Sendable {
    case session    = "Session"
    case today      = "Today"
    case sevenDays  = "7D"
    case thirtyDays = "30D"
    case allTime    = "All"

    var id: String { rawValue }

    /// Short display label used in RangeChip buttons.
    var label: String { rawValue }
}

// Spark-card enum is declared in NetworkSparkCards.swift as `NetworkSparkCard`
// (the view-layer name). Both ViewModel and MockData already reference that
// canonical name.

// MARK: - Card delta

/// Directional delta annotation shown in the footer of each spark card.
enum CardDelta: Sendable, Equatable {
    /// Traffic is higher vs the comparison window. Display in sage.
    case up(percent: Int)
    /// Traffic is lower vs the comparison window. Display in terracotta.
    case down(percent: Int)
    /// No meaningful change. Display in text3.
    case stable

    /// String passed to `DeltaBadge.delta` in NetworkSparkCards.swift.
    var display: String {
        switch self {
        case .up(let pct):   return "+\(pct)%"
        case .down(let pct): return "-\(pct)%"
        case .stable:        return "stable"
        }
    }
}

// Card metric payload is declared in NetworkSparkCards.swift as
// `NetworkSparkCardMetrics`. ViewModel and MockData both return that name.

// MARK: - Chart types

/// Single bandwidth sample used by NetworkBigChart.
/// NOTE: NetworkBigChart.swift declares a placeholder `NetworkSample` and
/// `NetworkChartSeries`. On merge, remove those placeholder structs and keep
/// the definitions here.
struct NetworkSample: Identifiable, Hashable, Sendable {
    let id: UUID
    let timestamp: Date
    let bytesPerSec: UInt64

    init(timestamp: Date, bytesPerSec: UInt64) {
        self.id = UUID()
        self.timestamp = timestamp
        self.bytesPerSec = bytesPerSec
    }
}

/// Paired download/upload sample arrays passed to NetworkBigChart.
struct NetworkChartSeries: Sendable {
    /// Download samples, oldest first.
    let down: [NetworkSample]
    /// Upload samples, oldest first.
    let up: [NetworkSample]

    // NetworkBigChart.swift uses `downPoints` and `upPoints` field names on
    // its local placeholder struct. The chart agent will update its field
    // references to `down` / `up` on merge. Both are intentionally
    // named to match this canonical definition.
}

// MARK: - Pane row types

/// One row in the TOP APPS pane.
/// NOTE: NetworkPanesGrid.swift has its own identical stub. Remove it on merge.
struct AppTrafficRow: Identifiable, Hashable, Sendable {
    /// Bundle identifier, e.g. "com.tinyspeck.slackmacgap".
    let id: String
    let name: String
    /// Descriptive subtitle shown under the app name, e.g. "Slack Desktop".
    let subtitle: String
    /// SF Symbol name used as a proxy icon until NSWorkspace icon loading lands.
    let iconSystemName: String
    let downBytes: UInt64
    let upBytes: UInt64

    var totalBytes: UInt64 { downBytes &+ upBytes }
}

/// One row in the LIVE CONNECTIONS pane.
/// NOTE: NetworkPanesGrid.swift has its own identical stub. Remove it on merge.
struct ConnectionRow: Identifiable, Hashable, Sendable {
    /// Unique key, format "pid-localPort-remotePort".
    let id: String
    let localSocket: String
    let remoteSocket: String
    let processName: String
    let pid: Int
    /// Instantaneous bytes per second for this socket pair.
    let currentBps: UInt64
    /// Reverse-DNS domain if known, nil otherwise.
    let domain: String?
    let appBundleId: String?
}

/// One row in the TOP DOMAINS pane.
/// NOTE: NetworkPanesGrid.swift has its own identical stub. Remove it on merge.
struct DomainTrafficRow: Identifiable, Hashable, Sendable {
    /// The domain string itself serves as the unique key.
    let id: String
    let domain: String
    let resolvedIP: String
    let totalBytes: UInt64
    let firstSeen: Date
    let appBundleIds: [String]
}

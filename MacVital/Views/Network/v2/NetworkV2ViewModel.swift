// MacVital/Views/Network/v2/NetworkV2ViewModel.swift
//
// @Observable ViewModel for the Network V2 tab.
//
// Data sources:
//   REAL  - SystemMonitor.network       (live bps, 60-sample history arrays)
//   REAL  - SystemMonitor.networkUsageSummaries  (session / today / 7d / 30d / all-time)
//   REAL  - topApps / currentRows(.interface)  mapped from NetworkUsageSummary
//   STUB  - currentRows(.app/.process)  (nettop-via-helper not yet built)
//   STUB  - liveConnections  (proc_pidfdinfo enumeration not yet built)
//   STUB  - topDomains       (NEDNSProxyProvider not yet built)
//
// The ViewModel is created as @State inside NetworkViewV2, so it is owned by
// the view tree. No singleton, no global state.

import Foundation

// MARK: - NetworkV2ViewModel

@Observable
final class NetworkV2ViewModel {

    // MARK: - Search and sort (binding targets for NetworkPivotBar)

    var searchText: String = ""
    var sort: NetworkSort = NetworkSort()

    // MARK: - Weak reference to the monitor

    /// Injected by NetworkViewV2 on .onAppear or at init via DI.
    /// The ViewModel reads from this reference on every live property access.
    /// Nil while the view is not yet connected (previews, unit tests).
    private weak var monitor: SystemMonitor?

    // MARK: - Init

    init(monitor: SystemMonitor? = nil) {
        self.monitor = monitor
    }

    /// Re-attach the monitor reference. Called by NetworkViewV2.onAppear so
    /// the live SystemMonitor reaches the ViewModel after view tree mount.
    func attach(monitor: SystemMonitor) {
        self.monitor = monitor
    }

    // MARK: - Live throughput (REAL)

    /// Current download bytes per second, sourced from SystemMonitor.network.
    var liveDownBps: Double {
        guard let network = monitor?.network else { return 0 }
        return Double(network.totalRxBytesPerSec)
    }

    /// Current upload bytes per second, sourced from SystemMonitor.network.
    var liveUpBps: Double {
        guard let network = monitor?.network else { return 0 }
        return Double(network.totalTxBytesPerSec)
    }

    // MARK: - Card metrics (REAL for live/session/today; STUB for peak/latency)

    /// Returns one NetworkSparkCardMetrics per card key.
    /// Called by NetworkSparkCardsRow via `viewModel.cardMetrics(for:)`.
    func cardMetrics(for range: NetworkTimeRange) -> [NetworkSparkCard: NetworkSparkCardMetrics] {
        // Fall back to mock data when monitor is not connected (previews, unit tests).
        guard let monitor else {
            return NetworkV2Mocks.cardMetrics(for: range)
        }

        let network    = monitor.network
        let summaries  = monitor.networkUsageSummaries
        let downHistory = monitor.networkDownHistory
        let upHistory   = monitor.networkUpHistory

        // Aggregate summaries across all interfaces.
        let sessionIn  = summaries.reduce(UInt64(0)) { $0 &+ $1.session.bytesIn }
        let sessionOut = summaries.reduce(UInt64(0)) { $0 &+ $1.session.bytesOut }
        let todayIn    = summaries.reduce(UInt64(0)) { $0 &+ $1.today.bytesIn }
        let todayOut   = summaries.reduce(UInt64(0)) { $0 &+ $1.today.bytesOut }
        let sevenIn    = summaries.reduce(UInt64(0)) { $0 &+ $1.last7Days.bytesIn }
        let sevenOut   = summaries.reduce(UInt64(0)) { $0 &+ $1.last7Days.bytesOut }
        let thirtyIn   = summaries.reduce(UInt64(0)) { $0 &+ $1.last30Days.bytesIn }
        let thirtyOut  = summaries.reduce(UInt64(0)) { $0 &+ $1.last30Days.bytesOut }
        let allIn      = summaries.reduce(UInt64(0)) { $0 &+ $1.allTime.bytesIn }
        let allOut     = summaries.reduce(UInt64(0)) { $0 &+ $1.allTime.bytesOut }

        // Sparkline data: last 40 samples from the history arrays (or less if short).
        let downSpark = tailSpark(downHistory, count: 40)
        let upSpark   = tailSpark(upHistory, count: 40)

        // Active interface description for sub-captions.
        let ifaceLabel = primaryInterfaceLabel(network: network)

        // Download NOW (REAL)
        let dlNow   = network.map { Double($0.totalRxBytesPerSec) } ?? 0
        let ulNow   = network.map { Double($0.totalTxBytesPerSec) } ?? 0
        let (dlVal, dlUnit) = formatBps(dlNow)
        let (ulVal, ulUnit) = formatBps(ulNow)

        // Windowed totals selection
        let (windowIn, windowOut): (UInt64, UInt64)
        let windowLabel: String
        switch range {
        case .session:
            windowIn = sessionIn; windowOut = sessionOut; windowLabel = "since launch"
        case .today:
            windowIn = todayIn; windowOut = todayOut; windowLabel = "today total"
        case .sevenDays:
            windowIn = sevenIn; windowOut = sevenOut; windowLabel = "7-day total"
        case .thirtyDays:
            windowIn = thirtyIn; windowOut = thirtyOut; windowLabel = "30-day total"
        case .allTime:
            windowIn = allIn; windowOut = allOut; windowLabel = "all-time total"
        }

        // Session card shows combined in+out
        let sessionTotal = sessionIn &+ sessionOut
        let (sessVal, sessUnit) = formatBytes(sessionTotal)

        // Today/window card shows combined
        let windowTotal = windowIn &+ windowOut
        let (winVal, winUnit) = formatBytes(windowTotal)

        return [
            // REAL: live sample from SystemMonitor.network
            .downloadNow: NetworkSparkCardMetrics(
                displayValue: dlVal,
                displayUnit:  dlUnit,
                subCaption:   ifaceLabel,
                sparkData:    downSpark,
                delta:        deltaBadge(history: downHistory)
            ),
            // REAL: live sample from SystemMonitor.network
            .uploadNow: NetworkSparkCardMetrics(
                displayValue: ulVal,
                displayUnit:  ulUnit,
                subCaption:   ifaceLabel,
                sparkData:    upSpark,
                delta:        deltaBadge(history: upHistory)
            ),
            // REAL: session total from NetworkUsageSummary
            .session: NetworkSparkCardMetrics(
                displayValue: sessVal,
                displayUnit:  sessUnit,
                subCaption:   "since launch",
                sparkData:    rampSpark(downHistory, count: 40),
                delta:        "stable"
            ),
            // REAL: window total from NetworkUsageSummary
            .today: NetworkSparkCardMetrics(
                displayValue: winVal,
                displayUnit:  winUnit,
                subCaption:   windowLabel,
                sparkData:    rampSpark(downHistory, count: 40),
                delta:        "stable"
            ),
            // STUB: peak detection requires persistent sample DB query
            .peak24h: NetworkSparkCardMetrics(
                displayValue: "--",
                displayUnit:  "MB/s",
                subCaption:   "last 24h",
                sparkData:    downSpark,
                delta:        "stable"
            ),
            // STUB: latency requires ICMP / TCP probe not yet wired
            .latency: NetworkSparkCardMetrics(
                displayValue: "--",
                displayUnit:  "ms",
                subCaption:   "60s avg",
                sparkData:    Array(repeating: 0.0, count: 40),
                delta:        "stable"
            ),
        ]
    }

    // MARK: - Chart series (REAL for down/up history; fills to 360 samples with zeros)

    /// Returns a NetworkChartSeries for the big chart, driven by SystemMonitor history.
    /// When monitor is not available, returns the mock series.
    func chartSeries(for range: NetworkTimeRange, focused: NetworkSparkCard) -> NetworkChartSeries {
        guard let monitor else {
            return NetworkV2Mocks.chartSeries(for: range)
        }

        let downHistory = monitor.networkDownHistory  // [UInt64], up to 60 elements at 2s
        let upHistory   = monitor.networkUpHistory

        // Build samples from the tail of the history arrays.
        // SystemMonitor samples at 2s. We extend backwards with zeros to reach 360 points
        // so the chart has a full 60-min window at 10s resolution.
        let now = Date()
        let intervalSeconds: Double = 2.0

        var downSamples: [NetworkSample] = []
        var upSamples:   [NetworkSample] = []

        let needed = 360
        let available = min(downHistory.count, needed)
        let padCount = needed - available

        // Pad leading zeros for samples older than the monitor history.
        for i in 0..<padCount {
            let offset = Double(i - padCount) * intervalSeconds
            let t = now.addingTimeInterval(offset - Double(available) * intervalSeconds)
            downSamples.append(NetworkSample(timestamp: t, bytesPerSec: 0))
            upSamples.append(NetworkSample(timestamp: t, bytesPerSec: 0))
        }

        // Append real samples.
        let startIndex = max(0, downHistory.count - available)
        for (i, idx) in (startIndex..<downHistory.count).enumerated() {
            let offset = Double(i - available + 1) * intervalSeconds
            let t = now.addingTimeInterval(offset)
            downSamples.append(NetworkSample(timestamp: t, bytesPerSec: downHistory[idx]))
            let upVal = idx < upHistory.count ? upHistory[idx] : 0
            upSamples.append(NetworkSample(timestamp: t, bytesPerSec: upVal))
        }

        return NetworkChartSeries(down: downSamples, up: upSamples)
    }

    // MARK: - Pivot-aware row source

    /// Returns the correct row list for the active pivot and time range.
    /// BY INTERFACE is wired to real data from NetworkUsageSummary.
    /// BY APP / PROCESS / DOMAIN remain stubs pending nettop / NEDNSProxyProvider work.
    func currentRows(pivot: NetworkPanePivot, range: NetworkTimeRange) -> [AppTrafficRow] {
        switch pivot {
        case .interface: return interfaceRows(for: range)
        case .network:   return []   // rendered by NetworkPaneLifetime, not the panes grid
        case .app, .process, .domain: return NetworkV2Mocks.apps    // STUB
        }
    }

    // MARK: - BY INTERFACE, real data

    /// Maps each NetworkUsageSummary to an AppTrafficRow and sorts by total bytes
    /// descending so the most-active interface (e.g. Wi-Fi at 85 GB) leads the list.
    ///
    /// Name and subtitle are enriched from NetworkInterfaceInfo when available;
    /// falls back to BSD name alone when the info array is absent (e.g. previews).
    private func interfaceRows(for range: NetworkTimeRange) -> [AppTrafficRow] {
        guard let monitor else {
            // Previews / unit tests: return mock data so the pane is not blank.
            return NetworkV2Mocks.apps
        }

        let summaries = monitor.networkUsageSummaries
        guard !summaries.isEmpty else { return [] }

        // Build a lookup from BSD name → NetworkInterfaceInfo for label enrichment.
        let infoByBsd: [String: NetworkInterfaceInfo] = {
            var map: [String: NetworkInterfaceInfo] = [:]
            for info in monitor.network?.interfaceInfos ?? [] {
                // Keep the most-recently-active bucket if multiple entries share a bsdName.
                if let existing = map[info.bsdName] {
                    if info.lastSeen > existing.lastSeen { map[info.bsdName] = info }
                } else {
                    map[info.bsdName] = info
                }
            }
            return map
        }()

        let rows: [AppTrafficRow] = summaries.map { summary in
            let info = infoByBsd[summary.interface]
            let window = windowFor(summary: summary, range: range)
            return AppTrafficRow(
                id: summary.interface,
                name: nameFor(bsd: summary.interface, info: info),
                subtitle: subtitleFor(info: info),
                iconSystemName: info?.type.sfSymbol ?? "network",
                downBytes: window.bytesIn,
                upBytes: window.bytesOut
            )
        }
        // Active (highest total) interface first; stable sort within equal totals.
        return rows.sorted { $0.totalBytes > $1.totalBytes }
    }

    /// Selects the correct NetworkUsageWindow from a summary based on the time range.
    private func windowFor(summary: NetworkUsageSummary, range: NetworkTimeRange) -> NetworkUsageWindow {
        switch range {
        case .session:    return summary.session
        case .today:      return summary.today
        case .sevenDays:  return summary.last7Days
        case .thirtyDays: return summary.last30Days
        case .allTime:    return summary.allTime
        }
    }

    /// Human-readable interface name. Uses NetworkInterfaceInfo.displayName when
    /// available (e.g. "Wi-Fi", "Ethernet"), with SSID appended for Wi-Fi rows.
    private func nameFor(bsd: String, info: NetworkInterfaceInfo?) -> String {
        guard let info else { return bsd }
        if let ssid = info.currentSSID, !ssid.isEmpty {
            return ssid                // e.g. "Home Wi-Fi 6 GHz"
        }
        return info.displayName        // e.g. "Ethernet", "iPhone USB"
    }

    /// Subtitle shown beneath the interface name in the row.
    /// Shows IP + signal strength for Wi-Fi; IP + link speed for wired; "Inactive" if down.
    private func subtitleFor(info: NetworkInterfaceInfo?) -> String {
        guard let info else { return "" }
        guard info.isActive else { return "Inactive" }
        var parts: [String] = []
        if !info.ipv4Address.isEmpty, info.ipv4Address != "0.0.0.0" {
            parts.append(info.ipv4Address)
        }
        if let band = info.wifiBand, !band.isEmpty {
            parts.append(band)
        }
        if let dbm = info.wifiSignalDBm {
            parts.append("\(dbm) dBm")
        } else if let mbps = info.linkSpeedMbps, mbps > 0 {
            parts.append("\(mbps) Mbps")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Stub collections

    // STUB: will be replaced by nettop-via-helper integration
    // (see reference_macvital_network_impl.md, Pillar 1: BY APP, 2-3 weeks)
    // NOTE: NetworkViewV2 should call currentRows(pivot:range:) instead of topApps
    // so that pivot selection routes BY INTERFACE to real data automatically.
    var topApps: [AppTrafficRow] {
        NetworkV2Mocks.apps
    }

    // STUB: will be replaced by nettop-via-helper integration
    // (see reference_macvital_network_impl.md, Pillar 2: BY PROCESS, +1 week)
    var liveConnections: [ConnectionRow] {
        NetworkV2Mocks.connections
    }

    // STUB: will be replaced by NEDNSProxyProvider integration
    // (see reference_macvital_network_impl.md, Pillar 3: BY DOMAIN, 4-6 weeks)
    var topDomains: [DomainTrafficRow] {
        NetworkV2Mocks.domains
    }

    // MARK: - Private helpers

    /// Extracts the last `count` history samples as normalised Double values
    /// suitable for a sparkline (raw bytes-per-sec, not normalised to 0..1;
    /// the CardSparkline view normalises internally).
    private func tailSpark(_ history: [UInt64], count: Int) -> [Double] {
        let slice = history.suffix(count)
        let padded = Array(repeating: 0.0, count: max(0, count - slice.count))
            + slice.map { Double($0) }
        return padded
    }

    /// Returns a ramp sparkline by cumulative-summing the last `count` history
    /// samples, approximating a "cumulative bytes" shape for session/today cards.
    private func rampSpark(_ history: [UInt64], count: Int) -> [Double] {
        let tail = history.suffix(count)
        var cumulative: Double = 0
        var result: [Double] = []
        for v in tail {
            cumulative += Double(v)
            result.append(cumulative)
        }
        // Pad front with zeros if fewer samples available.
        let padCount = max(0, count - result.count)
        return Array(repeating: 0.0, count: padCount) + result
    }

    /// Computes a simple +/-/stable delta badge string by comparing the most
    /// recent 10 samples against the previous 10.
    private func deltaBadge(history: [UInt64]) -> String {
        guard history.count >= 20 else { return "stable" }
        let recent = history.suffix(10).reduce(0, &+)
        let prior  = history.dropLast(10).suffix(10).reduce(0, &+)
        guard prior > 0 else { return "stable" }
        let ratio = Double(recent) / Double(prior)
        if ratio > 1.08 {
            let pct = Int((ratio - 1) * 100)
            return "+\(pct)%"
        } else if ratio < 0.92 {
            let pct = Int((1 - ratio) * 100)
            return "-\(pct)%"
        }
        return "stable"
    }

    /// Returns a human-readable label for the primary active network interface.
    private func primaryInterfaceLabel(network: NetworkData?) -> String {
        guard let interfaces = network?.interfaces, !interfaces.isEmpty else {
            return "no interface"
        }
        // Prefer the Wi-Fi interface (en0), then the first with nonzero traffic.
        let wifi = interfaces.first(where: { $0.name == "en0" && ($0.rxBytesPerSec > 0 || $0.txBytesPerSec > 0) })
        let active = wifi ?? interfaces.first(where: { $0.rxBytesPerSec > 0 || $0.txBytesPerSec > 0 })
        guard let iface = active else { return "idle" }
        if let ssid = iface.wifiSSID, !ssid.isEmpty {
            let band = iface.wifiBand ?? "Wi-Fi"
            return "\(iface.name) · \(band) \(ssid)"
        }
        return "\(iface.name) · \(iface.linkSpeed)"
    }

    /// Formats bytes-per-second into a (value, unit) pair.
    private func formatBps(_ bps: Double) -> (String, String) {
        switch bps {
        case ..<1_000:
            return (String(format: "%.0f", bps), "B/s")
        case ..<1_000_000:
            return (String(format: "%.1f", bps / 1_000), "KB/s")
        case ..<1_000_000_000:
            return (String(format: "%.2f", bps / 1_000_000), "MB/s")
        default:
            return (String(format: "%.2f", bps / 1_000_000_000), "GB/s")
        }
    }

    /// Formats a byte count into a (value, unit) pair using SI prefixes.
    private func formatBytes(_ bytes: UInt64) -> (String, String) {
        let d = Double(bytes)
        switch d {
        case ..<1_000:
            return (String(format: "%.0f", d), "B")
        case ..<1_000_000:
            return (String(format: "%.1f", d / 1_000), "KB")
        case ..<1_000_000_000:
            return (String(format: "%.1f", d / 1_000_000), "MB")
        case ..<1_000_000_000_000:
            return (String(format: "%.2f", d / 1_000_000_000), "GB")
        default:
            return (String(format: "%.2f", d / 1_000_000_000_000), "TB")
        }
    }
}

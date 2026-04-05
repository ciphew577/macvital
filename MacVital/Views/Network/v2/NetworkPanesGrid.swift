// MacVital/Views/Network/v2/NetworkPanesGrid.swift
//
// Three-pane bottom section: TOP APPS | LIVE CONNECTIONS | TOP DOMAINS
// Cross-hover dimming, single global pin, pivot prominence, search + sort wiring.
// Matches mockups/redesign-2026-04-23/network/variant-f-fusion.html § 6 THREE-PANE GRID.

import SwiftUI

// Row types (AppTrafficRow, ConnectionRow, DomainTrafficRow) live in
// NetworkV2Types.swift. Identical shapes, no local declarations needed.

// MARK: - Pin state (single global across all panes)

enum PinTarget: Equatable {
    case app(String)
    case connection(String)
    case domain(String)
}

// MARK: - NetworkPanesGrid

struct NetworkPanesGrid: View {

    let pivot: NetworkPanePivot
    let apps: [AppTrafficRow]
    let connections: [ConnectionRow]
    let domains: [DomainTrafficRow]
    let search: String
    let sort: NetworkSort

    // Cross-pane hover state, the hovered item id scoped to its pane
    @State private var hoveredApp: String?        = nil
    @State private var hoveredConnection: String? = nil
    @State private var hoveredDomain: String?     = nil

    // Single global pin, at most one row pinned across all three panes
    @State private var pinnedTarget: PinTarget?   = nil

    var body: some View {
        HStack(spacing: 0) {
            NetworkPaneApps(
                apps: filteredApps,
                sort: sort,
                hoveredApp: $hoveredApp,
                hoveredConnection: hoveredConnection,
                hoveredDomain: hoveredDomain,
                pinnedTarget: $pinnedTarget,
                relatedAppIDs: relatedAppIDsForHover,
                isPivotFocused: pivot == .app
            )

            divider

            NetworkPaneConnections(
                connections: filteredConnections,
                sort: sort,
                hoveredConnection: $hoveredConnection,
                hoveredApp: hoveredApp,
                hoveredDomain: hoveredDomain,
                pinnedTarget: $pinnedTarget,
                relatedConnectionIDs: relatedConnectionIDsForHover,
                isPivotFocused: pivot == .process
            )

            divider

            NetworkPaneDomains(
                domains: filteredDomains,
                sort: sort,
                hoveredDomain: $hoveredDomain,
                hoveredApp: hoveredApp,
                hoveredConnection: hoveredConnection,
                pinnedTarget: $pinnedTarget,
                relatedDomainIDs: relatedDomainIDsForHover,
                isPivotFocused: pivot == .domain
            )
        }
        .background(MV.bg)
    }

    // MARK: - Divider

    private var divider: some View {
        Rectangle()
            .fill(MV.hairline)
            .frame(width: 1)
    }

    // MARK: - Search filters

    private var filteredApps: [AppTrafficRow] {
        guard !search.isEmpty else { return apps }
        let q = search.lowercased()
        return apps.filter {
            $0.name.lowercased().contains(q) ||
            $0.subtitle.lowercased().contains(q) ||
            $0.id.lowercased().contains(q)
        }
    }

    private var filteredConnections: [ConnectionRow] {
        guard !search.isEmpty else { return connections }
        let q = search.lowercased()
        return connections.filter {
            $0.processName.lowercased().contains(q) ||
            $0.localSocket.lowercased().contains(q) ||
            $0.remoteSocket.lowercased().contains(q) ||
            ($0.domain?.lowercased().contains(q) ?? false)
        }
    }

    private var filteredDomains: [DomainTrafficRow] {
        guard !search.isEmpty else { return domains }
        let q = search.lowercased()
        return domains.filter {
            $0.domain.lowercased().contains(q) ||
            $0.resolvedIP.lowercased().contains(q)
        }
    }

    // MARK: - Cross-relationship helpers
    // Relationship logic: given the active hover or pin in any pane, return
    // the set of related IDs for each of the other two panes. These ID sets
    // are passed into each pane so rows NOT in the set can be dimmed.

    /// App IDs related to whatever is currently hovered (in conn or domain panes)
    private var relatedAppIDsForHover: Set<String> {
        if let pin = pinnedTarget { return relatedAppIDs(for: pin) }
        if let id = hoveredConnection {
            guard let conn = connections.first(where: { $0.id == id }),
                  let bundleId = conn.appBundleId else { return [] }
            return [bundleId]
        }
        if let id = hoveredDomain {
            guard let dom = domains.first(where: { $0.id == id }) else { return [] }
            return Set(dom.appBundleIds)
        }
        return []
    }

    /// Connection IDs related to whatever is currently hovered (in app or domain panes)
    private var relatedConnectionIDsForHover: Set<String> {
        if let pin = pinnedTarget { return relatedConnectionIDs(for: pin) }
        if let id = hoveredApp {
            return Set(connections.filter { $0.appBundleId == id }.map(\.id))
        }
        if let id = hoveredDomain {
            guard let dom = domains.first(where: { $0.id == id }) else { return [] }
            return Set(connections.filter { $0.domain == dom.domain }.map(\.id))
        }
        return []
    }

    /// Domain IDs related to whatever is currently hovered (in app or conn panes)
    private var relatedDomainIDsForHover: Set<String> {
        if let pin = pinnedTarget { return relatedDomainIDs(for: pin) }
        if let id = hoveredApp {
            return Set(domains.filter { $0.appBundleIds.contains(id) }.map(\.id))
        }
        if let id = hoveredConnection {
            guard let conn = connections.first(where: { $0.id == id }),
                  let domainName = conn.domain else { return [] }
            return Set(domains.filter { $0.domain == domainName }.map(\.id))
        }
        return []
    }

    // Pin-based relationship lookups (same logic, using pinned item)

    private func relatedAppIDs(for pin: PinTarget) -> Set<String> {
        switch pin {
        case .app(let id):        return [id]
        case .connection(let id):
            guard let conn = connections.first(where: { $0.id == id }),
                  let bundleId = conn.appBundleId else { return [] }
            return [bundleId]
        case .domain(let id):
            guard let dom = domains.first(where: { $0.id == id }) else { return [] }
            return Set(dom.appBundleIds)
        }
    }

    private func relatedConnectionIDs(for pin: PinTarget) -> Set<String> {
        switch pin {
        case .app(let id):
            return Set(connections.filter { $0.appBundleId == id }.map(\.id))
        case .connection(let id): return [id]
        case .domain(let id):
            guard let dom = domains.first(where: { $0.id == id }) else { return [] }
            return Set(connections.filter { $0.domain == dom.domain }.map(\.id))
        }
    }

    private func relatedDomainIDs(for pin: PinTarget) -> Set<String> {
        switch pin {
        case .app(let id):
            return Set(domains.filter { $0.appBundleIds.contains(id) }.map(\.id))
        case .connection(let id):
            guard let conn = connections.first(where: { $0.id == id }),
                  let domainName = conn.domain else { return [] }
            return Set(domains.filter { $0.domain == domainName }.map(\.id))
        case .domain(let id): return [id]
        }
    }
}

// MARK: - Preview

#Preview("NetworkPanesGrid") {
    NetworkPanesGrid(
        pivot: .app,
        apps: PreviewData.apps,
        connections: PreviewData.connections,
        domains: PreviewData.domains,
        search: "",
        sort: NetworkSort(key: .download, ascending: false)
    )
    .frame(width: 1100, height: 340)
    .background(MV.bg)
}

// MARK: - Preview data

enum PreviewData {
    static let apps: [AppTrafficRow] = [
        .init(id: "com.tinyspeck.slackmacgap",   name: "Slack",    subtitle: "Slack Desktop",   iconSystemName: "app.fill",             downBytes: 52_400_000, upBytes: 3_100_000),
        .init(id: "com.apple.Safari",       name: "Safari",    subtitle: "Apple WebKit",        iconSystemName: "safari.fill",          downBytes: 38_200_000, upBytes: 4_200_000),
        .init(id: "com.spotify.client",     name: "Spotify",   subtitle: "Streaming",           iconSystemName: "music.note",           downBytes: 22_800_000, upBytes:   450_000),
        .init(id: "com.tinyspeck.slackmacgap", name: "Slack",  subtitle: "Workspace comms",     iconSystemName: "message.fill",         downBytes: 11_300_000, upBytes: 2_100_000),
        .init(id: "com.figma.Desktop",      name: "Figma",     subtitle: "Design",              iconSystemName: "pencil.and.scribble",  downBytes:  8_900_000, upBytes: 1_800_000),
        .init(id: "com.zoom.xos",           name: "Zoom",      subtitle: "Video conferencing",  iconSystemName: "video.fill",           downBytes:  6_400_000, upBytes: 5_600_000),
        .init(id: "com.apple.mail",         name: "Mail",      subtitle: "Apple Mail",          iconSystemName: "envelope.fill",        downBytes:  4_100_000, upBytes:   980_000),
        .init(id: "com.docker.docker",      name: "Docker",    subtitle: "Container runtime",   iconSystemName: "shippingbox.fill",     downBytes:  2_800_000, upBytes:   640_000),
        .init(id: "com.apple.dt.Xcode",     name: "Xcode",     subtitle: "Apple Developer",     iconSystemName: "hammer.fill",          downBytes:  1_600_000, upBytes:   220_000),
        .init(id: "com.github.GitHubDesktop", name: "GitHub",  subtitle: "Version control",     iconSystemName: "arrow.triangle.branch", downBytes: 890_000, upBytes:   180_000),
    ]

    static let connections: [ConnectionRow] = [
        .init(id: "54321-443", localSocket: ":54321", remoteSocket: "52.84.150.3:443",   processName: "Slack",  pid: 1234, currentBps: 2_400_000, domain: "app.slack.com",    appBundleId: "com.tinyspeck.slackmacgap"),
        .init(id: "54322-443", localSocket: ":54322", remoteSocket: "17.253.144.10:443", processName: "Safari",  pid: 4021, currentBps: 1_800_000, domain: "www.apple.com",         appBundleId: "com.apple.Safari"),
        .init(id: "54323-443", localSocket: ":54323", remoteSocket: "35.186.224.24:443", processName: "Spotify", pid: 2219, currentBps: 1_200_000, domain: "spclient.wg.spotify.com", appBundleId: "com.spotify.client"),
        .init(id: "54324-80",  localSocket: ":54324", remoteSocket: "104.16.85.20:80",   processName: "Safari",  pid: 4021, currentBps:   750_000, domain: "cdn.cloudflare.com",    appBundleId: "com.apple.Safari"),
        .init(id: "54325-443", localSocket: ":54325", remoteSocket: "54.240.196.0:443",  processName: "Slack",   pid: 3312, currentBps:   620_000, domain: "slack-edge.com",         appBundleId: "com.tinyspeck.slackmacgap"),
        .init(id: "54326-443", localSocket: ":54326", remoteSocket: "18.165.36.18:443",  processName: "Zoom",    pid: 5501, currentBps:   480_000, domain: "zoom.us",                appBundleId: "com.zoom.xos"),
        .init(id: "54327-443", localSocket: ":54327", remoteSocket: "172.217.5.36:443",  processName: "Mail",    pid: 612,  currentBps:   310_000, domain: "smtp.gmail.com",         appBundleId: "com.apple.mail"),
        .init(id: "54328-443", localSocket: ":54328", remoteSocket: "140.82.121.4:443",  processName: "GitHub",  pid: 7702, currentBps:   190_000, domain: "github.com",             appBundleId: "com.github.GitHubDesktop"),
        .init(id: "54329-53",  localSocket: ":54329", remoteSocket: "1.1.1.1:53",        processName: "mDNSResponder", pid: 88, currentBps: 4_200, domain: nil,                     appBundleId: nil),
        .init(id: "54330-443", localSocket: ":54330", remoteSocket: "52.84.150.9:443",   processName: "Slack",  pid: 1234, currentBps:   88_000, domain: "app.slack.com",     appBundleId: "com.tinyspeck.slackmacgap"),
    ]

    static let domains: [DomainTrafficRow] = [
        .init(id: "app.slack.com",      domain: "app.slack.com",       resolvedIP: "52.84.150.0/24",  totalBytes: 52_400_000, firstSeen: Date().addingTimeInterval(-3600 * 2), appBundleIds: ["com.tinyspeck.slackmacgap"]),
        .init(id: "spclient.wg.spotify.com", domain: "spclient.wg.spotify.com", resolvedIP: "35.186.224.0/24", totalBytes: 22_800_000, firstSeen: Date().addingTimeInterval(-3600 * 5), appBundleIds: ["com.spotify.client"]),
        .init(id: "www.apple.com",          domain: "www.apple.com",            resolvedIP: "17.253.144.0/24", totalBytes: 18_100_000, firstSeen: Date().addingTimeInterval(-3600 * 1), appBundleIds: ["com.apple.Safari", "com.apple.mail"]),
        .init(id: "slack-edge.com",         domain: "slack-edge.com",           resolvedIP: "54.240.196.0/24", totalBytes: 11_300_000, firstSeen: Date().addingTimeInterval(-7200),      appBundleIds: ["com.tinyspeck.slackmacgap"]),
        .init(id: "cdn.cloudflare.com",     domain: "cdn.cloudflare.com",       resolvedIP: "104.16.85.0/24",  totalBytes:  8_200_000, firstSeen: Date().addingTimeInterval(-900),        appBundleIds: ["com.apple.Safari"]),
        .init(id: "zoom.us",                domain: "zoom.us",                  resolvedIP: "18.165.36.0/24",  totalBytes:  6_400_000, firstSeen: Date().addingTimeInterval(-1800),       appBundleIds: ["com.zoom.xos"]),
        .init(id: "smtp.gmail.com",         domain: "smtp.gmail.com",           resolvedIP: "172.217.5.0/24",  totalBytes:  4_100_000, firstSeen: Date().addingTimeInterval(-5400),       appBundleIds: ["com.apple.mail"]),
        .init(id: "github.com",             domain: "github.com",               resolvedIP: "140.82.121.0/24", totalBytes:  2_900_000, firstSeen: Date().addingTimeInterval(-600),         appBundleIds: ["com.github.GitHubDesktop"]),
        .init(id: "registry.docker.io",     domain: "registry.docker.io",       resolvedIP: "34.226.22.0/24",  totalBytes:  2_800_000, firstSeen: Date().addingTimeInterval(-10800),      appBundleIds: ["com.docker.docker"]),
        .init(id: "objects.githubusercontent.com", domain: "objects.githubusercontent.com", resolvedIP: "185.199.108.0/24", totalBytes: 1_600_000, firstSeen: Date().addingTimeInterval(-1200), appBundleIds: ["com.apple.dt.Xcode", "com.github.GitHubDesktop"]),
    ]
}

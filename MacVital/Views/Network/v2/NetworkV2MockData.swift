// MacVital/Views/Network/v2/NetworkV2MockData.swift
//
// Static seed data used in #Preview blocks and stub collections across all V2
// views. All timestamps are relative to Date() so previews stay visually current.
// No SwiftUI or AppKit imports. Foundation only.

import Foundation

// MARK: - NetworkV2Mocks

enum NetworkV2Mocks {

    // MARK: - Apps (10 rows, BY APP pane)

    /// Realistic app traffic rows ordered by descending total bytes.
    static let apps: [AppTrafficRow] = [
        AppTrafficRow(
            id: "com.tinyspeck.slackmacgap",
            name: "Slack",
            subtitle: "Slack Desktop",
            iconSystemName: "sparkles",
            downBytes: 15_200_000_000,
            upBytes: 1_800_000_000
        ),
        AppTrafficRow(
            id: "com.apple.Safari",
            name: "Safari",
            subtitle: "Apple Browser",
            iconSystemName: "safari",
            downBytes: 8_400_000_000,
            upBytes: 620_000_000
        ),
        AppTrafficRow(
            id: "com.brave.Browser",
            name: "Brave",
            subtitle: "Brave Browser",
            iconSystemName: "globe",
            downBytes: 5_100_000_000,
            upBytes: 380_000_000
        ),
        AppTrafficRow(
            id: "com.spotify.client",
            name: "Spotify",
            subtitle: "Music Streaming",
            iconSystemName: "music.note",
            downBytes: 3_200_000_000,
            upBytes: 42_000_000
        ),
        AppTrafficRow(
            id: "us.zoom.xos",
            name: "Zoom",
            subtitle: "Video Conferencing",
            iconSystemName: "video",
            downBytes: 2_750_000_000,
            upBytes: 1_100_000_000
        ),
        AppTrafficRow(
            id: "ru.keepcoder.Telegram",
            name: "Telegram",
            subtitle: "Messaging",
            iconSystemName: "paperplane",
            downBytes: 1_980_000_000,
            upBytes: 210_000_000
        ),
        AppTrafficRow(
            id: "com.docker.docker",
            name: "Docker",
            subtitle: "Container Engine",
            iconSystemName: "shippingbox",
            downBytes: 1_400_000_000,
            upBytes: 88_000_000
        ),
        AppTrafficRow(
            id: "net.whatsapp.WhatsApp",
            name: "WhatsApp",
            subtitle: "Messaging",
            iconSystemName: "message",
            downBytes: 820_000_000,
            upBytes: 155_000_000
        ),
        AppTrafficRow(
            id: "com.macpaw.CleanMyMac4",
            name: "CleanMyMac",
            subtitle: "MacPaw",
            iconSystemName: "sparkle.magnifyingglass",
            downBytes: 560_000_000,
            upBytes: 22_000_000
        ),
        AppTrafficRow(
            id: "com.apple.dt.Xcode",
            name: "Xcode",
            subtitle: "Apple Developer Tools",
            iconSystemName: "hammer",
            downBytes: 400_000_000,
            upBytes: 35_000_000
        ),
    ]

    // MARK: - Connections (15 rows, LIVE CONNECTIONS pane)

    /// Realistic live socket rows. PIDs are plausible but not real.
    static let connections: [ConnectionRow] = {
        let now = Date()
        return [
            ConnectionRow(
                id: "9821-52134-443",
                localSocket:  "192.168.1.105:52134",
                remoteSocket: "162.159.133.234:443",
                processName:  "Slack",
                pid: 9821,
                currentBps: 5_120_000,
                domain: "app.slack.com",
                appBundleId: "com.tinyspeck.slackmacgap"
            ),
            ConnectionRow(
                id: "9821-52200-443",
                localSocket:  "192.168.1.105:52200",
                remoteSocket: "162.159.135.42:443",
                processName:  "Slack",
                pid: 9821,
                currentBps: 2_840_000,
                domain: "app.slack.com",
                appBundleId: "com.tinyspeck.slackmacgap"
            ),
            ConnectionRow(
                id: "4422-50311-443",
                localSocket:  "192.168.1.105:50311",
                remoteSocket: "17.253.144.10:443",
                processName:  "Safari",
                pid: 4422,
                currentBps: 1_900_000,
                domain: "*.apple.com",
                appBundleId: "com.apple.Safari"
            ),
            ConnectionRow(
                id: "7741-54002-443",
                localSocket:  "192.168.1.105:54002",
                remoteSocket: "35.186.224.25:443",
                processName:  "Zoom",
                pid: 7741,
                currentBps: 1_650_000,
                domain: "*.zoom.us",
                appBundleId: "us.zoom.xos"
            ),
            ConnectionRow(
                id: "5510-49901-443",
                localSocket:  "192.168.1.105:49901",
                remoteSocket: "35.186.224.8:443",
                processName:  "Zoom",
                pid: 7741,
                currentBps: 680_000,
                domain: "*.zoom.us",
                appBundleId: "us.zoom.xos"
            ),
            ConnectionRow(
                id: "3318-51200-4070",
                localSocket:  "192.168.1.105:51200",
                remoteSocket: "149.154.167.50:4070",
                processName:  "Telegram",
                pid: 3318,
                currentBps: 540_000,
                domain: "cdn.telegram.org",
                appBundleId: "ru.keepcoder.Telegram"
            ),
            ConnectionRow(
                id: "6603-53100-443",
                localSocket:  "192.168.1.105:53100",
                remoteSocket: "104.199.65.124:443",
                processName:  "Docker",
                pid: 6603,
                currentBps: 420_000,
                domain: "*.docker.io",
                appBundleId: "com.docker.docker"
            ),
            ConnectionRow(
                id: "8812-50044-443",
                localSocket:  "192.168.1.105:50044",
                remoteSocket: "151.101.193.140:443",
                processName:  "Brave",
                pid: 8812,
                currentBps: 380_000,
                domain: "*.github.com",
                appBundleId: "com.brave.Browser"
            ),
            ConnectionRow(
                id: "4422-50912-443",
                localSocket:  "192.168.1.105:50912",
                remoteSocket: "17.110.232.14:443",
                processName:  "Safari",
                pid: 4422,
                currentBps: 320_000,
                domain: "*.icloud.com",
                appBundleId: "com.apple.Safari"
            ),
            ConnectionRow(
                id: "2200-55001-443",
                localSocket:  "192.168.1.105:55001",
                remoteSocket: "35.157.104.211:443",
                processName:  "Spotify",
                pid: 2200,
                currentBps: 280_000,
                domain: "open.spotify.com",
                appBundleId: "com.spotify.client"
            ),
            ConnectionRow(
                id: "3318-51300-443",
                localSocket:  "192.168.1.105:51300",
                remoteSocket: "149.154.175.55:443",
                processName:  "WhatsApp",
                pid: 5501,
                currentBps: 210_000,
                domain: "*.whatsapp.net",
                appBundleId: "net.whatsapp.WhatsApp"
            ),
            ConnectionRow(
                id: "6603-53200-443",
                localSocket:  "192.168.1.105:53200",
                remoteSocket: "54.165.49.82:443",
                processName:  "Docker",
                pid: 6603,
                currentBps: 185_000,
                domain: "*.docker.io",
                appBundleId: "com.docker.docker"
            ),
            ConnectionRow(
                id: "9821-52300-443",
                localSocket:  "192.168.1.105:52300",
                remoteSocket: "34.95.0.12:443",
                processName:  "Slack",
                pid: 9821,
                currentBps: 160_000,
                domain: "*.slack.com",
                appBundleId: "com.tinyspeck.slackmacgap"
            ),
            ConnectionRow(
                id: "1100-49501-443",
                localSocket:  "192.168.1.105:49501",
                remoteSocket: "142.250.80.110:443",
                processName:  "Brave",
                pid: 8812,
                currentBps: 130_000,
                domain: "*.googleusercontent.com",
                appBundleId: "com.brave.Browser"
            ),
            ConnectionRow(
                id: "7200-48800-443",
                localSocket:  "192.168.1.105:48800",
                remoteSocket: "17.57.146.132:443",
                processName:  "Xcode",
                pid: 7200,
                currentBps: 100_000,
                domain: "developer.apple.com",
                appBundleId: "com.apple.dt.Xcode"
            ),
        ]
    }()

    // MARK: - Domains (12 rows, TOP DOMAINS pane)

    static let domains: [DomainTrafficRow] = {
        let base = Date()
        let hourAgo = base.addingTimeInterval(-3600)
        let dayAgo  = base.addingTimeInterval(-86400)
        return [
            DomainTrafficRow(
                id: "app.slack.com",
                domain: "app.slack.com",
                resolvedIP: "162.159.133.234",
                totalBytes: 9_800_000_000,
                firstSeen: dayAgo,
                appBundleIds: ["com.tinyspeck.slackmacgap"]
            ),
            DomainTrafficRow(
                id: "*.icloud.com",
                domain: "*.icloud.com",
                resolvedIP: "17.110.232.14",
                totalBytes: 6_200_000_000,
                firstSeen: dayAgo,
                appBundleIds: ["com.apple.Safari", "com.apple.dt.Xcode"]
            ),
            DomainTrafficRow(
                id: "open.spotify.com",
                domain: "open.spotify.com",
                resolvedIP: "35.157.104.211",
                totalBytes: 3_100_000_000,
                firstSeen: dayAgo,
                appBundleIds: ["com.spotify.client"]
            ),
            DomainTrafficRow(
                id: "*.github.com",
                domain: "*.github.com",
                resolvedIP: "140.82.121.4",
                totalBytes: 2_450_000_000,
                firstSeen: dayAgo,
                appBundleIds: ["com.brave.Browser", "com.apple.dt.Xcode"]
            ),
            DomainTrafficRow(
                id: "cdn.telegram.org",
                domain: "cdn.telegram.org",
                resolvedIP: "149.154.167.50",
                totalBytes: 1_980_000_000,
                firstSeen: hourAgo,
                appBundleIds: ["ru.keepcoder.Telegram"]
            ),
            DomainTrafficRow(
                id: "*.zoom.us",
                domain: "*.zoom.us",
                resolvedIP: "35.186.224.25",
                totalBytes: 1_750_000_000,
                firstSeen: hourAgo,
                appBundleIds: ["us.zoom.xos"]
            ),
            DomainTrafficRow(
                id: "*.docker.io",
                domain: "*.docker.io",
                resolvedIP: "54.165.49.82",
                totalBytes: 1_380_000_000,
                firstSeen: dayAgo,
                appBundleIds: ["com.docker.docker"]
            ),
            DomainTrafficRow(
                id: "*.apple.com",
                domain: "*.apple.com",
                resolvedIP: "17.253.144.10",
                totalBytes: 980_000_000,
                firstSeen: dayAgo,
                appBundleIds: ["com.apple.Safari", "com.apple.dt.Xcode"]
            ),
            DomainTrafficRow(
                id: "*.googleusercontent.com",
                domain: "*.googleusercontent.com",
                resolvedIP: "142.250.80.110",
                totalBytes: 720_000_000,
                firstSeen: dayAgo,
                appBundleIds: ["com.brave.Browser"]
            ),
            DomainTrafficRow(
                id: "*.whatsapp.net",
                domain: "*.whatsapp.net",
                resolvedIP: "149.154.175.55",
                totalBytes: 520_000_000,
                firstSeen: dayAgo,
                appBundleIds: ["net.whatsapp.WhatsApp"]
            ),
            DomainTrafficRow(
                id: "*.macpaw.com",
                domain: "*.macpaw.com",
                resolvedIP: "104.21.48.1",
                totalBytes: 320_000_000,
                firstSeen: dayAgo,
                appBundleIds: ["com.macpaw.CleanMyMac4"]
            ),
            DomainTrafficRow(
                id: "developer.apple.com",
                domain: "developer.apple.com",
                resolvedIP: "17.57.146.132",
                totalBytes: 180_000_000,
                firstSeen: hourAgo,
                appBundleIds: ["com.apple.dt.Xcode"]
            ),
        ]
    }()

    // MARK: - Card metrics

    /// Returns realistic card metric structs for a given time range.
    /// Values are statically differentiated per range to make previews
    /// informative without requiring real SystemMonitor data.
    static func cardMetrics(for range: NetworkTimeRange) -> [NetworkSparkCard: NetworkSparkCardMetrics] {
        switch range {
        case .session:
            return sessionMetrics
        case .today:
            return todayMetrics
        case .sevenDays:
            return sevenDayMetrics
        case .thirtyDays:
            return thirtyDayMetrics
        case .allTime:
            return allTimeMetrics
        }
    }

    // MARK: Session metrics (last ~2 hours)

    private static let sessionMetrics: [NetworkSparkCard: NetworkSparkCardMetrics] = [
        .downloadNow: NetworkSparkCardMetrics(
            displayValue: "4.52",
            displayUnit:  "MB/s",
            subCaption:   "en0 · Wi-Fi 6 GHz",
            sparkData:    spikeSpark(base: 3.0, peak: 5.5, count: 40),
            delta:        "+12%"
        ),
        .uploadNow: NetworkSparkCardMetrics(
            displayValue: "0.31",
            displayUnit:  "MB/s",
            subCaption:   "en0 · Wi-Fi 6 GHz",
            sparkData:    noisySpark(base: 0.25, noise: 0.12, count: 40),
            delta:        "-5%"
        ),
        .session: NetworkSparkCardMetrics(
            displayValue: "842",
            displayUnit:  "MB",
            subCaption:   "since launch",
            sparkData:    rampSpark(from: 0, to: 842, count: 40),
            delta:        "stable"
        ),
        .today: NetworkSparkCardMetrics(
            displayValue: "3.1",
            displayUnit:  "GB",
            subCaption:   "today total",
            sparkData:    rampSpark(from: 0.1, to: 3.1, count: 40),
            delta:        "+8%"
        ),
        .peak24h: NetworkSparkCardMetrics(
            displayValue: "18.4",
            displayUnit:  "MB/s",
            subCaption:   "at 11:32 AM",
            sparkData:    burstSpark(peakAt: 0.55, count: 40),
            delta:        "+3%"
        ),
        .latency: NetworkSparkCardMetrics(
            displayValue: "12",
            displayUnit:  "ms",
            subCaption:   "60s avg · 8.8.8.8",
            sparkData:    noisySpark(base: 12, noise: 3, count: 40),
            delta:        "stable"
        ),
    ]

    // MARK: Today metrics

    private static let todayMetrics: [NetworkSparkCard: NetworkSparkCardMetrics] = [
        .downloadNow: NetworkSparkCardMetrics(
            displayValue: "4.52",
            displayUnit:  "MB/s",
            subCaption:   "en0 · Wi-Fi 6 GHz",
            sparkData:    spikeSpark(base: 3.0, peak: 5.5, count: 40),
            delta:        "+12%"
        ),
        .uploadNow: NetworkSparkCardMetrics(
            displayValue: "0.31",
            displayUnit:  "MB/s",
            subCaption:   "en0 · Wi-Fi 6 GHz",
            sparkData:    noisySpark(base: 0.25, noise: 0.12, count: 40),
            delta:        "-5%"
        ),
        .session: NetworkSparkCardMetrics(
            displayValue: "842",
            displayUnit:  "MB",
            subCaption:   "since launch",
            sparkData:    rampSpark(from: 0, to: 842, count: 40),
            delta:        "stable"
        ),
        .today: NetworkSparkCardMetrics(
            displayValue: "3.1",
            displayUnit:  "GB",
            subCaption:   "today total",
            sparkData:    rampSpark(from: 0.2, to: 3.1, count: 40),
            delta:        "+8%"
        ),
        .peak24h: NetworkSparkCardMetrics(
            displayValue: "18.4",
            displayUnit:  "MB/s",
            subCaption:   "at 11:32 AM",
            sparkData:    burstSpark(peakAt: 0.55, count: 40),
            delta:        "+3%"
        ),
        .latency: NetworkSparkCardMetrics(
            displayValue: "14",
            displayUnit:  "ms",
            subCaption:   "60s avg · 8.8.8.8",
            sparkData:    noisySpark(base: 14, noise: 4, count: 40),
            delta:        "stable"
        ),
    ]

    // MARK: 7-day metrics

    private static let sevenDayMetrics: [NetworkSparkCard: NetworkSparkCardMetrics] = [
        .downloadNow: NetworkSparkCardMetrics(
            displayValue: "4.52",
            displayUnit:  "MB/s",
            subCaption:   "en0 · Wi-Fi 6 GHz",
            sparkData:    spikeSpark(base: 2.5, peak: 6.0, count: 40),
            delta:        "+12%"
        ),
        .uploadNow: NetworkSparkCardMetrics(
            displayValue: "0.31",
            displayUnit:  "MB/s",
            subCaption:   "en0 · Wi-Fi 6 GHz",
            sparkData:    noisySpark(base: 0.28, noise: 0.15, count: 40),
            delta:        "-5%"
        ),
        .session: NetworkSparkCardMetrics(
            displayValue: "842",
            displayUnit:  "MB",
            subCaption:   "since launch",
            sparkData:    rampSpark(from: 0, to: 842, count: 40),
            delta:        "stable"
        ),
        .today: NetworkSparkCardMetrics(
            displayValue: "18.7",
            displayUnit:  "GB",
            subCaption:   "7-day total",
            sparkData:    rampSpark(from: 1.0, to: 18.7, count: 40),
            delta:        "+22%"
        ),
        .peak24h: NetworkSparkCardMetrics(
            displayValue: "18.4",
            displayUnit:  "MB/s",
            subCaption:   "at 11:32 AM",
            sparkData:    burstSpark(peakAt: 0.62, count: 40),
            delta:        "+3%"
        ),
        .latency: NetworkSparkCardMetrics(
            displayValue: "11",
            displayUnit:  "ms",
            subCaption:   "60s avg · 8.8.8.8",
            sparkData:    noisySpark(base: 11, noise: 3, count: 40),
            delta:        "stable"
        ),
    ]

    // MARK: 30-day metrics

    private static let thirtyDayMetrics: [NetworkSparkCard: NetworkSparkCardMetrics] = [
        .downloadNow: NetworkSparkCardMetrics(
            displayValue: "4.52",
            displayUnit:  "MB/s",
            subCaption:   "en0 · Wi-Fi 6 GHz",
            sparkData:    spikeSpark(base: 2.0, peak: 7.0, count: 40),
            delta:        "+12%"
        ),
        .uploadNow: NetworkSparkCardMetrics(
            displayValue: "0.31",
            displayUnit:  "MB/s",
            subCaption:   "en0 · Wi-Fi 6 GHz",
            sparkData:    noisySpark(base: 0.30, noise: 0.18, count: 40),
            delta:        "-5%"
        ),
        .session: NetworkSparkCardMetrics(
            displayValue: "842",
            displayUnit:  "MB",
            subCaption:   "since launch",
            sparkData:    rampSpark(from: 0, to: 842, count: 40),
            delta:        "stable"
        ),
        .today: NetworkSparkCardMetrics(
            displayValue: "71.2",
            displayUnit:  "GB",
            subCaption:   "30-day total",
            sparkData:    rampSpark(from: 2.0, to: 71.2, count: 40),
            delta:        "-4%"
        ),
        .peak24h: NetworkSparkCardMetrics(
            displayValue: "22.1",
            displayUnit:  "MB/s",
            subCaption:   "3 days ago",
            sparkData:    burstSpark(peakAt: 0.40, count: 40),
            delta:        "+8%"
        ),
        .latency: NetworkSparkCardMetrics(
            displayValue: "13",
            displayUnit:  "ms",
            subCaption:   "60s avg · 8.8.8.8",
            sparkData:    noisySpark(base: 13, noise: 5, count: 40),
            delta:        "stable"
        ),
    ]

    // MARK: All-time metrics

    private static let allTimeMetrics: [NetworkSparkCard: NetworkSparkCardMetrics] = [
        .downloadNow: NetworkSparkCardMetrics(
            displayValue: "4.52",
            displayUnit:  "MB/s",
            subCaption:   "en0 · Wi-Fi 6 GHz",
            sparkData:    spikeSpark(base: 1.5, peak: 8.0, count: 40),
            delta:        "+12%"
        ),
        .uploadNow: NetworkSparkCardMetrics(
            displayValue: "0.31",
            displayUnit:  "MB/s",
            subCaption:   "en0 · Wi-Fi 6 GHz",
            sparkData:    noisySpark(base: 0.32, noise: 0.20, count: 40),
            delta:        "-5%"
        ),
        .session: NetworkSparkCardMetrics(
            displayValue: "842",
            displayUnit:  "MB",
            subCaption:   "since launch",
            sparkData:    rampSpark(from: 0, to: 842, count: 40),
            delta:        "stable"
        ),
        .today: NetworkSparkCardMetrics(
            displayValue: "284",
            displayUnit:  "GB",
            subCaption:   "all-time total",
            sparkData:    rampSpark(from: 10, to: 284, count: 40),
            delta:        "stable"
        ),
        .peak24h: NetworkSparkCardMetrics(
            displayValue: "26.8",
            displayUnit:  "MB/s",
            subCaption:   "historical peak",
            sparkData:    burstSpark(peakAt: 0.30, count: 40),
            delta:        "+15%"
        ),
        .latency: NetworkSparkCardMetrics(
            displayValue: "12",
            displayUnit:  "ms",
            subCaption:   "60s avg · 8.8.8.8",
            sparkData:    noisySpark(base: 12, noise: 4, count: 40),
            delta:        "stable"
        ),
    ]

    // MARK: - Chart series

    /// Produces 360 samples at 10-second intervals (60-minute window) with a
    /// realistic burst-quiet-burst pattern. The upload series is proportionally
    /// smaller.
    static func chartSeries(for range: NetworkTimeRange) -> NetworkChartSeries {
        let sampleCount = 360
        let intervalSeconds: Double = 10
        let now = Date()

        var downSamples: [NetworkSample] = []
        var upSamples: [NetworkSample]   = []

        // Seeded deterministic noise so different ranges look distinct.
        let rangeSeed: Double
        switch range {
        case .session:    rangeSeed = 1.0
        case .today:      rangeSeed = 1.2
        case .sevenDays:  rangeSeed = 1.4
        case .thirtyDays: rangeSeed = 1.6
        case .allTime:    rangeSeed = 1.8
        }

        for i in 0..<sampleCount {
            let t = now.addingTimeInterval(Double(i - (sampleCount - 1)) * intervalSeconds)

            // Base download: 3 MB/s with two burst windows and quiet troughs
            let phase = Double(i) / Double(sampleCount - 1)
            let burstA = burstAmplitude(phase: phase, center: 0.25, width: 0.12)
            let burstB = burstAmplitude(phase: phase, center: 0.72, width: 0.08)
            let quietTrough = 1.0 - smoothStep(0.45, 0.55, phase) * 0.6
            let baseDown: Double = 3_000_000 * rangeSeed
            let noise = pseudoNoise(seed: Double(i) * 1.618 + rangeSeed)
            let dlBps = UInt64(baseDown * (1.0 + burstA * 2.8 + burstB * 1.6) * quietTrough * (0.85 + noise * 0.30))

            // Upload: roughly 1/8 of download
            let ulNoise = pseudoNoise(seed: Double(i) * 2.718 + rangeSeed)
            let ulBps = UInt64(baseDown / 8 * (0.8 + ulNoise * 0.4))

            downSamples.append(NetworkSample(timestamp: t, bytesPerSec: dlBps))
            upSamples.append(NetworkSample(timestamp: t, bytesPerSec: ulBps))
        }

        return NetworkChartSeries(down: downSamples, up: upSamples)
    }

    // MARK: - Private spark shape helpers

    /// Returns 40 doubles with a spike shape near the right side.
    private static func spikeSpark(base: Double, peak: Double, count: Int) -> [Double] {
        (0..<count).map { i in
            let phase = Double(i) / Double(count - 1)
            let spike = burstAmplitude(phase: phase, center: 0.78, width: 0.14)
            let noise = pseudoNoise(seed: Double(i) * 1.1)
            return base * (0.85 + noise * 0.3) + (peak - base) * spike
        }
    }

    /// Returns count doubles oscillating around base with added noise.
    private static func noisySpark(base: Double, noise: Double, count: Int) -> [Double] {
        (0..<count).map { i in
            let n = pseudoNoise(seed: Double(i) * 2.3)
            return max(0, base + (n - 0.5) * noise * 2)
        }
    }

    /// Returns count doubles that ramp linearly from `from` to `to`.
    private static func rampSpark(from start: Double, to end: Double, count: Int) -> [Double] {
        (0..<count).map { i in
            let phase = Double(i) / Double(max(count - 1, 1))
            let noise = pseudoNoise(seed: Double(i) * 0.9)
            return start + (end - start) * phase + (end - start) * 0.04 * (noise - 0.5)
        }
    }

    /// Returns count doubles with a single burst peak positioned at `peakAt` (0..1 fraction).
    private static func burstSpark(peakAt: Double, count: Int) -> [Double] {
        (0..<count).map { i in
            let phase = Double(i) / Double(count - 1)
            let burst = burstAmplitude(phase: phase, center: peakAt, width: 0.18)
            let noise  = pseudoNoise(seed: Double(i) * 1.7)
            return 1.0 + burst * 8.0 + noise * 0.5
        }
    }

    // MARK: - Math helpers (no stdlib random: deterministic for previews)

    /// Smooth bump centred at `center` with half-width `width`. Returns 0..1.
    private static func burstAmplitude(phase: Double, center: Double, width: Double) -> Double {
        let d = abs(phase - center) / max(width, 0.001)
        guard d < 1 else { return 0 }
        return smoothStep(1.0, 0.0, d)
    }

    /// Hermite smooth-step t in [a, b] -> 0..1.
    private static func smoothStep(_ a: Double, _ b: Double, _ t: Double) -> Double {
        let x = max(0, min(1, (t - a) / (b - a)))
        return x * x * (3 - 2 * x)
    }

    /// Deterministic pseudo-random value in 0..1 from a seed (no state).
    private static func pseudoNoise(seed: Double) -> Double {
        let s = sin(seed * 127.1 + 311.7) * 43758.5453
        return s - floor(s)
    }
}

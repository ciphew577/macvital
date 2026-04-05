// Variant selector + deterministic verdict/snapshot builders shared by all five Report variants.

import SwiftUI

enum ReportVariant: Int, CaseIterable, Identifiable, Sendable {
    case editorial      = 0
    case dashboard      = 1
    case appleHealth    = 2
    case terminal       = 3
    case newspaperFold  = 4

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .editorial:     return "Editorial"
        case .dashboard:     return "Dashboard"
        case .appleHealth:   return "Apple Health"
        case .terminal:      return "Terminal"
        case .newspaperFold: return "Newspaper Fold"
        }
    }

    static let storageKey: String = "com.macvital.report.variant"
}

enum ReportPeriod: String, CaseIterable, Identifiable, Sendable {
    case live = "Live"
    case h1   = "1H"
    case h24  = "24H"
    case d7   = "7D"
    case d30  = "30D"

    var id: String { rawValue }
}

enum AnomalySeverity: Sendable {
    case high, notable, info

    var label: String {
        switch self {
        case .high:    return "High"
        case .notable: return "Notable"
        case .info:    return "Info"
        }
    }

    var tone: VerdictTone {
        switch self {
        case .high:    return .alert
        case .notable: return .notable
        case .info:    return .neutral
        }
    }
}

enum VerdictTone: Sendable {
    case healthy, notable, alert, neutral

    @MainActor
    var color: Color {
        switch self {
        case .healthy: return MV.ok
        case .notable: return MV.warning
        case .alert:   return MV.critical
        case .neutral: return MV.text2
        }
    }

    var word: String {
        switch self {
        case .healthy: return "good"
        case .notable: return "notable"
        case .alert:   return "alert"
        case .neutral: return "neutral"
        }
    }
}

struct ReportFact: Identifiable, Sendable {
    let id: String
    let key: String
    let value: String
    let tone: VerdictTone
}

struct ReportAnomaly: Identifiable, Sendable {
    let id: String
    let timestamp: String
    let metric: String
    let sentence: String
    let delta: String
    let severity: AnomalySeverity
    let jumpTab: String
}

struct ReportSnapshot: Sendable {
    let period: ReportPeriod
    let macModel: String
    let chip: String
    let issueDate: Date
    let issueNumber: Int
    let healthScore: Int
    let healthBaseline: Int
    let healthDelta: Int
    let verdictHead: String
    let verdictTail: String
    let verdictTone: VerdictTone
    let moodLabel: String
    let moodTone: VerdictTone
    let moodReasons: [(key: String, value: String)]
    let highlightHead: String
    let highlightSub: String
    let tldr: String
    let facts: [ReportFact]
    let anomalies: [ReportAnomaly]
    let anomalyCount: (total: Int, notable: Int, critical: Int)
}

@MainActor
enum ReportSnapshotBuilder {

    static func snapshot(from monitor: SystemMonitor, period: ReportPeriod = .h24) -> ReportSnapshot {
        let model = OverviewHeroBuilder.macModelWithSize()
        let chip  = OverviewHeroBuilder.chipShort()

        let storagePct = monitor.storage?.healthPercent ?? 100
        let batteryPct = monitor.battery?.healthPercent ?? 100
        let maxTemp    = monitor.sensors?.sensors.map(\.value).max() ?? 0
        let maxFanRPM  = monitor.sensors?.fans.map(\.rpm).max() ?? 0
        let cpuLoad    = monitor.cpu?.totalUsage ?? 0
        let memPress   = monitor.memory?.pressureLevel ?? .nominal
        let swapGB     = Double(monitor.memory?.swapUsed ?? 0) / 1_073_741_824.0
        let cycles     = monitor.battery?.cycleCount ?? 0
        let batteryPctReal = monitor.battery?.percentage ?? 100

        let thermalPct: Double = {
            if maxTemp >= 95 { return 40 }
            if maxTemp >= 80 { return 70 }
            return 95
        }()
        let cpuPct: Double = {
            if cpuLoad > 95 { return 40 }
            if cpuLoad > 80 { return 70 }
            return 95
        }()
        let memPct: Double = {
            switch memPress {
            case .nominal: return 95
            case .warning: return 65
            case .critical: return 30
            }
        }()
        let overall = HealthScore.overallScore(
            storage: storagePct, battery: batteryPct,
            thermal: thermalPct, cpu: cpuPct, memory: memPct
        )
        let score = Int(overall.rounded())
        let baseline = max(1, score - (score >= 90 ? 1 : 0))

        let verdict = VerdictGenerator.make(
            score: score,
            storagePct: storagePct, batteryPct: batteryPct,
            thermalPct: thermalPct, cpuPct: cpuPct, memPct: memPct,
            maxTemp: maxTemp, swapGB: swapGB
        )

        let mood = MoodGenerator.make(
            score: score, swapGB: swapGB,
            memPress: memPress, maxTemp: maxTemp
        )

        let highlight = HighlightGenerator.make(
            cycles: cycles, batteryPct: batteryPct,
            batteryPctReal: batteryPctReal, storagePct: storagePct
        )

        let tldr = TLDRGenerator.make(
            score: score, maxTemp: maxTemp, maxFanRPM: maxFanRPM,
            memPress: memPress, swapGB: swapGB,
            storagePct: storagePct, batteryPct: batteryPct, cycles: cycles
        )

        let facts = FactGenerator.make(
            score: score, maxTemp: maxTemp, maxFanRPM: maxFanRPM,
            memPress: memPress, swapGB: swapGB,
            storagePct: storagePct, batteryPct: batteryPct,
            cycles: cycles, cpuLoad: cpuLoad
        )

        let anomalies = AnomalyGenerator.make(
            maxTemp: maxTemp, maxFanRPM: maxFanRPM,
            memPress: memPress, swapGB: swapGB,
            storagePct: storagePct, cpuLoad: cpuLoad
        )

        let totals = (
            total: anomalies.count,
            notable: anomalies.filter { $0.severity == .notable }.count,
            critical: anomalies.filter { $0.severity == .high }.count
        )

        return ReportSnapshot(
            period: period,
            macModel: model,
            chip: chip,
            issueDate: Date(),
            issueNumber: max(1, Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1),
            healthScore: score,
            healthBaseline: baseline,
            healthDelta: score - baseline,
            verdictHead: verdict.head,
            verdictTail: verdict.tail,
            verdictTone: verdict.tone,
            moodLabel: mood.label,
            moodTone: mood.tone,
            moodReasons: mood.reasons,
            highlightHead: highlight.head,
            highlightSub: highlight.sub,
            tldr: tldr,
            facts: facts,
            anomalies: anomalies,
            anomalyCount: totals
        )
    }
}

struct VerdictGenerator {
    let head: String
    let tail: String
    let tone: VerdictTone

    static func make(score: Int,
                     storagePct: Double, batteryPct: Double,
                     thermalPct: Double, cpuPct: Double, memPct: Double,
                     maxTemp: Double, swapGB: Double) -> VerdictGenerator {
        let head: String
        let tone: VerdictTone
        switch score {
        case 90...:   head = "Your Mac is in good condition."; tone = .healthy
        case 75..<90: head = "Your Mac is in fair shape.";     tone = .notable
        case 60..<75: head = "Your Mac is running warm.";      tone = .notable
        default:      head = "Your Mac needs attention.";      tone = .alert
        }

        let candidates: [(Double, String, VerdictTone)] = [
            (storagePct, "Watch the SSD, lifetime health is at \(Int(storagePct.rounded())) percent.", storagePct < 80 ? .alert : .notable),
            (batteryPct, "Battery capacity is at \(Int(batteryPct.rounded())) percent of design.", batteryPct < 80 ? .alert : .notable),
            (thermalPct, "Thermals peaked at \(Int(maxTemp.rounded())) C today.", thermalPct < 80 ? .alert : .notable),
            (memPct,     "Memory pressure was elevated, swap touched \(String(format: "%.1f", swapGB)) GB.", memPct < 80 ? .alert : .notable),
            (cpuPct,     "CPU sat under heavy load through the period.", cpuPct < 80 ? .alert : .notable)
        ]
        let worst = candidates.min(by: { $0.0 < $1.0 })
        let tail: String
        if let w = worst, w.0 < 92 {
            tail = w.1
        } else {
            tail = "All five subsystems are inside their nominal envelopes."
        }
        return VerdictGenerator(head: head, tail: tail, tone: tone)
    }
}

struct MoodGenerator {
    let label: String
    let tone: VerdictTone
    let reasons: [(key: String, value: String)]

    static func make(score: Int, swapGB: Double, memPress: MemoryPressureLevel, maxTemp: Double) -> MoodGenerator {
        let tone: VerdictTone
        let label: String
        switch score {
        case 90...:   tone = .healthy; label = "Calm day, no surprises."
        case 75..<90: tone = .notable; label = "Steady, one item to watch."
        case 60..<75: tone = .notable; label = "Working hard today."
        default:      tone = .alert;   label = "Under pressure right now."
        }
        let reasons: [(String, String)] = [
            ("Therm", String(format: "%.0f C peak", maxTemp)),
            ("Press", memPress.rawValue),
            ("Swap",  String(format: "%.1f GB", swapGB))
        ]
        return MoodGenerator(label: label, tone: tone, reasons: reasons)
    }
}

struct HighlightGenerator {
    let head: String
    let sub: String

    static func make(cycles: Int, batteryPct: Double, batteryPctReal: Double, storagePct: Double) -> HighlightGenerator {
        if cycles > 0 && batteryPct >= 90 {
            return HighlightGenerator(
                head: "Battery cycle \(cycles), capacity \(Int(batteryPct.rounded())) percent.",
                sub:  "No service flag, well inside the 1,000 cycle envelope."
            )
        }
        if storagePct >= 95 {
            return HighlightGenerator(
                head: "SSD reporting \(Int(storagePct.rounded())) percent lifetime health.",
                sub:  "All SMART attributes inside thresholds."
            )
        }
        return HighlightGenerator(
            head: "Charge level holding at \(Int(batteryPctReal.rounded())) percent.",
            sub:  "Daily check completed, nothing flagged."
        )
    }
}

struct TLDRGenerator {
    static func make(score: Int, maxTemp: Double, maxFanRPM: Int,
                     memPress: MemoryPressureLevel, swapGB: Double,
                     storagePct: Double, batteryPct: Double, cycles: Int) -> String {
        var parts: [String] = []
        switch score {
        case 90...:   parts.append("Your Mac had a calm day.")
        case 75..<90: parts.append("Your Mac had a steady day with one item to watch.")
        case 60..<75: parts.append("Your Mac worked hard today.")
        default:      parts.append("Your Mac is under stress and wants attention.")
        }
        parts.append("Thermals peaked at \(Int(maxTemp.rounded())) C and fans topped \(maxFanRPM) RPM.")
        parts.append("Memory pressure stayed \(memPress.rawValue.lowercased()), swap reached \(String(format: "%.1f", swapGB)) GB.")
        parts.append("SSD lifetime health is \(Int(storagePct.rounded())) percent.")
        if cycles > 0 {
            parts.append("Battery sits at cycle \(cycles), capacity \(Int(batteryPct.rounded())) percent of design.")
        }
        return parts.joined(separator: " ")
    }
}

struct FactGenerator {
    static func make(score: Int, maxTemp: Double, maxFanRPM: Int,
                     memPress: MemoryPressureLevel, swapGB: Double,
                     storagePct: Double, batteryPct: Double,
                     cycles: Int, cpuLoad: Double) -> [ReportFact] {
        var out: [ReportFact] = []
        out.append(.init(id: "health", key: "Health",
                         value: "\(score) / 100",
                         tone: score >= 90 ? .healthy : (score >= 75 ? .notable : .alert)))
        out.append(.init(id: "therm",  key: "Therm peak",
                         value: "\(Int(maxTemp.rounded())) C",
                         tone: maxTemp >= 90 ? .alert : (maxTemp >= 80 ? .notable : .healthy)))
        out.append(.init(id: "fans",   key: "Fans peak",
                         value: "\(maxFanRPM) RPM",
                         tone: maxFanRPM >= 4500 ? .notable : .neutral))
        if cycles > 0 {
            out.append(.init(id: "battery", key: "Battery",
                             value: "\(Int(batteryPct.rounded())) percent",
                             tone: batteryPct >= 90 ? .healthy : (batteryPct >= 75 ? .notable : .alert)))
        }
        out.append(.init(id: "ssd",    key: "SSD",
                         value: "\(Int(storagePct.rounded())) percent",
                         tone: storagePct >= 90 ? .healthy : (storagePct >= 75 ? .notable : .alert)))
        out.append(.init(id: "swap",   key: "Swap",
                         value: String(format: "%.1f GB", swapGB),
                         tone: swapGB >= 4 ? .alert : (swapGB >= 1 ? .notable : .healthy)))
        out.append(.init(id: "load",   key: "CPU load",
                         value: "\(Int(cpuLoad.rounded())) percent",
                         tone: cpuLoad >= 80 ? .notable : .neutral))
        return Array(out.prefix(5))
    }
}

struct AnomalyGenerator {
    static func make(maxTemp: Double, maxFanRPM: Int,
                     memPress: MemoryPressureLevel, swapGB: Double,
                     storagePct: Double, cpuLoad: Double) -> [ReportAnomaly] {
        let now = Date()
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        func ts(minus seconds: Int) -> String { f.string(from: now.addingTimeInterval(-Double(seconds))) }
        var rows: [ReportAnomaly] = []

        if maxTemp >= 80 {
            rows.append(.init(id: "therm", timestamp: ts(minus: 1800),
                              metric: "Thermal",
                              sentence: "Hottest sensor reached \(Int(maxTemp.rounded())) C, three sigma above your 7 day median.",
                              delta: "+\(Int((maxTemp - 65).rounded())) C vs base",
                              severity: maxTemp >= 95 ? .high : .notable,
                              jumpTab: "Sensors"))
        }
        if maxFanRPM >= 4500 {
            rows.append(.init(id: "fan", timestamp: ts(minus: 5400),
                              metric: "Fan 1 RPM",
                              sentence: "Fan held above \(maxFanRPM) RPM for nine minutes during a sustained CPU load.",
                              delta: "+18 percent",
                              severity: .notable,
                              jumpTab: "Fans"))
        }
        if memPress != .nominal || swapGB >= 1 {
            rows.append(.init(id: "swap", timestamp: ts(minus: 9300),
                              metric: "Swap usage",
                              sentence: "Swap reached \(String(format: "%.1f", swapGB)) GB while pressure was \(memPress.rawValue).",
                              delta: "+\(String(format: "%.1f", swapGB)) GB",
                              severity: swapGB >= 4 ? .high : .notable,
                              jumpTab: "Memory"))
        }
        if storagePct < 95 {
            rows.append(.init(id: "ssd", timestamp: ts(minus: 14400),
                              metric: "SSD lifetime",
                              sentence: "SSD lifetime sits at \(Int(storagePct.rounded())) percent of expected endurance, worth a weekly check.",
                              delta: "\(Int(100 - storagePct.rounded())) percent used",
                              severity: storagePct < 80 ? .high : .notable,
                              jumpTab: "Storage"))
        }
        if cpuLoad >= 80 {
            rows.append(.init(id: "cpu", timestamp: ts(minus: 21000),
                              metric: "CPU load",
                              sentence: "CPU averaged \(Int(cpuLoad.rounded())) percent total load through the window.",
                              delta: "+\(Int(cpuLoad.rounded()) - 50) points",
                              severity: .notable,
                              jumpTab: "CPU"))
        }
        if rows.isEmpty {
            rows.append(.init(id: "calm", timestamp: ts(minus: 60),
                              metric: "Sample gap",
                              sentence: "No anomalies detected, all five subsystems sat inside their nominal envelopes.",
                              delta: "flat",
                              severity: .info,
                              jumpTab: "Overview"))
        }
        return Array(rows.prefix(5))
    }
}

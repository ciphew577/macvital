// Hero variant selector + shared snapshot builder used by all five hero variants.

import SwiftUI

enum OverviewVariant: Int, CaseIterable, Identifiable, Sendable {
    case editorial      = 0
    case instrument     = 1
    case bentoMosaic    = 2
    case narrativeFirst = 3
    case statusBar      = 4

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .editorial:      return "Editorial"
        case .instrument:     return "Instrument"
        case .bentoMosaic:    return "Bento Mosaic"
        case .narrativeFirst: return "Narrative First"
        case .statusBar:      return "Status Bar"
        }
    }

    static let storageKey: String = "com.macvital.overview.variant"

    @MainActor
    static var current: OverviewVariant {
        get {
            let raw = UserDefaults.standard.integer(forKey: storageKey)
            return OverviewVariant(rawValue: raw) ?? .editorial
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: storageKey)
        }
    }
}

struct OverviewHeroPip: Identifiable, Sendable {
    enum Tone: Sendable { case ok, warn, crit, neutral }
    let id: String
    let label: String
    let value: Int
    let tone: Tone
    let sub: String
}

struct OverviewHeroSnapshot: Sendable {
    let score: Int
    let scoreLabel: String
    let scoreTone: OverviewHeroPip.Tone
    let pips: [OverviewHeroPip]
    let machineLine: String
    let chipLine: String
    let uptimeLine: String
    let throttleEvents: Int
    let sparkData: [Double]
}

@MainActor
enum OverviewHeroBuilder {

    static func snapshot(from monitor: SystemMonitor) -> OverviewHeroSnapshot {
        let storagePct = monitor.storage?.healthPercent ?? 100
        let batteryPct = monitor.battery?.healthPercent ?? 100

        let thermalPct: Double = {
            guard let s = monitor.sensors else { return 95 }
            let t = s.sensors.map(\.value).max() ?? 0
            if t >= 95 { return 40 }
            if t >= 80 { return 70 }
            return 95
        }()

        let cpuPct: Double = {
            guard let cpu = monitor.cpu else { return 95 }
            if cpu.totalUsage > 95 { return 40 }
            if cpu.totalUsage > 80 { return 70 }
            return 95
        }()

        let memPct: Double = {
            guard let mem = monitor.memory else { return 95 }
            switch mem.pressureLevel {
            case .nominal:  return 95
            case .warning:  return 65
            case .critical: return 30
            }
        }()

        let overall = HealthScore.overallScore(
            storage: storagePct, battery: batteryPct, thermal: thermalPct,
            cpu: cpuPct, memory: memPct
        )

        let label: String
        switch overall {
        case 90...:    label = "Excellent"
        case 75..<90:  label = "Good"
        case 60..<75:  label = "Fair"
        default:       label = "Needs attention"
        }

        let scoreTone: OverviewHeroPip.Tone = {
            switch overall {
            case 90...:   return .ok
            case 60..<90: return .neutral
            default:      return .warn
            }
        }()

        let storageSub: String = {
            guard let v = monitor.storage?.volumes.first else { return "reading volumes" }
            let freeGB = Double(v.freeBytes) / 1_073_741_824.0
            let totGB  = Double(v.totalBytes) / 1_073_741_824.0
            return String(format: "%.0f GB free · %.0f GB", freeGB, totGB)
        }()

        let batterySub: String = {
            guard let b = monitor.battery else { return "no battery" }
            return "\(Int(b.percentage.rounded()))% · \(b.cycleCount) cycles"
        }()

        let thermalSub: String = {
            guard let s = monitor.sensors else { return "reading sensors" }
            let hottest = s.sensors.max(by: { $0.value < $1.value })
            let fanMax = s.fans.map(\.rpm).max() ?? 0
            if let h = hottest {
                return "\(h.name) \(Int(h.value.rounded()))°C · fans \(fanMax)"
            }
            return "fans \(fanMax) RPM"
        }()

        let cpuSub: String = {
            guard let cpu = monitor.cpu else { return "reading cpu" }
            let p = cpu.cores.filter { $0.clusterType == .performance }
            let e = cpu.cores.filter { $0.clusterType == .efficiency }
            let pAvg = p.isEmpty ? 0 : p.map(\.usage).reduce(0, +) / Double(p.count)
            let eAvg = e.isEmpty ? 0 : e.map(\.usage).reduce(0, +) / Double(e.count)
            return String(format: "%.0f%% load · P %.0f / E %.0f",
                          cpu.totalUsage, pAvg, eAvg)
        }()

        let memSub: String = {
            guard let mem = monitor.memory else { return "reading memory" }
            let used = Double(mem.used) / 1_073_741_824.0
            let tot  = Double(mem.total) / 1_073_741_824.0
            let swap = Double(mem.swapUsed) / 1_073_741_824.0
            return String(format: "%.1f / %.0f GB · swap %.1f", used, tot, swap)
        }()

        let pips: [OverviewHeroPip] = [
            .init(id: "storage", label: "Storage", value: Int(storagePct.rounded()),
                  tone: tone(storagePct), sub: storageSub),
            .init(id: "battery", label: "Battery", value: Int(batteryPct.rounded()),
                  tone: tone(batteryPct), sub: batterySub),
            .init(id: "thermal", label: "Thermal", value: Int(thermalPct.rounded()),
                  tone: tone(thermalPct), sub: thermalSub),
            .init(id: "cpu",     label: "CPU",     value: Int(cpuPct.rounded()),
                  tone: tone(cpuPct), sub: cpuSub),
            .init(id: "memory",  label: "Memory",  value: Int(memPct.rounded()),
                  tone: tone(memPct), sub: memSub)
        ]

        return OverviewHeroSnapshot(
            score: Int(overall.rounded()),
            scoreLabel: label,
            scoreTone: scoreTone,
            pips: pips,
            machineLine: macModelWithSize(),
            chipLine: chipShort(),
            uptimeLine: uptimeShort(),
            throttleEvents: 0,
            sparkData: monitor.cpuHistory.count >= 2
                ? monitor.cpuHistory
                : [2, 2.2, 2.1, 2.4, 2.2, 2.5, 2.3, 2.6, 2.4, 2.7, 2.5, 2.8]
        )
    }

    private static func tone(_ pct: Double) -> OverviewHeroPip.Tone {
        if pct >= 90 { return .ok }
        if pct >= 75 { return .neutral }
        if pct >= 60 { return .warn }
        return .crit
    }

    static func color(for tone: OverviewHeroPip.Tone) -> Color {
        switch tone {
        case .ok:      return MV.ok
        case .neutral: return MV.text2
        case .warn:    return MV.warning
        case .crit:    return MV.critical
        }
    }

    static func macModelWithSize() -> String {
        var buf = [CChar](repeating: 0, count: 256)
        var size = 256
        sysctlbyname("hw.model", &buf, &size, nil, 0)
        let raw = String(cString: buf)
        let base: String = {
            if raw.starts(with: "MacBookPro") { return "MacBook Pro" }
            if raw.starts(with: "MacBookAir") { return "MacBook Air" }
            if raw.starts(with: "Macmini")    { return "Mac mini" }
            if raw.starts(with: "iMac")       { return "iMac" }
            if raw.starts(with: "MacPro")     { return "Mac Pro" }
            if raw.starts(with: "MacStudio")  { return "Mac Studio" }
            return raw.isEmpty ? "Mac" : raw
        }()
        if base == "MacBook Pro" || base == "MacBook Air" {
            let w = NSScreen.main?.frame.width ?? 0
            if w >= 3000 { return "\(base) 16\"" }
            if w >= 2000 { return "\(base) 14\"" }
            if w >= 1700 { return "\(base) 13\"" }
        }
        return base
    }

    static func chipShort() -> String {
        var buf = [CChar](repeating: 0, count: 256)
        var size = 256
        sysctlbyname("machdep.cpu.brand_string", &buf, &size, nil, 0)
        var c = String(cString: buf).trimmingCharacters(in: .whitespaces)
        if c.isEmpty { return "Apple Silicon" }
        if !c.hasPrefix("Apple") { c = "Apple " + c }
        if let open = c.firstIndex(of: "(") {
            c = String(c[..<open]).trimmingCharacters(in: .whitespaces)
        }
        return c
    }

    static func uptimeShort() -> String {
        let s = Foundation.ProcessInfo.processInfo.systemUptime
        let d = Int(s / 86_400)
        let h = Int(s.truncatingRemainder(dividingBy: 86_400) / 3_600)
        let m = Int(s.truncatingRemainder(dividingBy: 3_600) / 60)
        if d > 0 { return "up \(d)d \(h)h" }
        if h > 0 { return "up \(h)h \(m)m" }
        return "up \(m)m"
    }
}

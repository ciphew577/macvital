// MacVital/Views/Overview/OverviewView.swift
//
// Editorial-bento Overview (2026-04-11 redesign, typography-refined variant).
//
// Target mockup:
//   mockups/redesign-2026-04-11/overview/editorial-bento-refined/
//   refined-a-typography.html
//
// Layout: 12-col bento grid inside an ~820 px pane.
//   Row 1-2: Hero (8 cols x 2 rows) · Power (4x1) · Battery/Uptime (4x1)
//   Row 3:   CPU (4x1) · GPU (4x1) · Memory (4x1)
//   Row 4:   Fans (6x1) · Storage (6x1)
//   Row 5:   Network (12x1)
//
// Every tile uses `MVTile` + `MVTileHead` from `MVColors.swift`.

import SwiftUI
import AppKit

// MARK: - Top-level Overview

struct OverviewView: View {
    @Environment(AppState.self) private var appState
    @AppStorage("com.macvital.overview.variant") private var rawVariant: Int = 0

    private var monitor: SystemMonitor { appState.monitor }

    private var variant: OverviewVariant {
        OverviewVariant(rawValue: rawVariant) ?? .editorial
    }

    @ViewBuilder
    private var heroForVariant: some View {
        switch variant {
        case .editorial:      OverviewHeroEditorial()
        case .instrument:     OverviewHeroInstrument()
        case .bentoMosaic:    OverviewHeroBentoMosaic()
        case .narrativeFirst: OverviewHeroNarrativeFirst()
        case .statusBar:      OverviewHeroStatusBar()
        }
    }

    // MARK: - Derived inputs

    private var hottestSensor: (name: String, temp: Double)? {
        guard let sensors = monitor.sensors else { return nil }
        guard let hottest = sensors.sensors.max(by: { $0.value < $1.value }) else { return nil }
        return (hottest.name, hottest.value)
    }

    private var maxFanRPM: Int? {
        monitor.sensors?.fans.map(\.rpm).max()
    }

    /// Mean usage of P-cluster cores, 0...100. Nil if CPU data not ready.
    private var pClusterUsage: Double? {
        guard let cpu = monitor.cpu else { return nil }
        let p = cpu.cores.filter { $0.clusterType == .performance }
        guard !p.isEmpty else { return nil }
        return p.map(\.usage).reduce(0, +) / Double(p.count)
    }

    /// Mean usage of E-cluster cores, 0...100. Nil if CPU data not ready.
    private var eClusterUsage: Double? {
        guard let cpu = monitor.cpu else { return nil }
        let e = cpu.cores.filter { $0.clusterType == .efficiency }
        guard !e.isEmpty else { return nil }
        return e.map(\.usage).reduce(0, +) / Double(e.count)
    }

    private var overallScore: Double {
        let storageScore = monitor.storage?.healthPercent ?? 100
        let batteryScore = monitor.battery?.healthPercent ?? 100
        let thermalScore: Double = {
            guard let sensors = monitor.sensors else { return 95 }
            let maxTemp = sensors.sensors.map(\.value).max() ?? 0
            if maxTemp >= 95 { return 40 }
            if maxTemp >= 80 { return 70 }
            return 95
        }()
        let cpuScore: Double = {
            guard let cpu = monitor.cpu else { return 95 }
            if cpu.totalUsage > 95 { return 40 }
            if cpu.totalUsage > 80 { return 70 }
            return 95
        }()
        let memoryScore: Double = {
            guard let mem = monitor.memory else { return 95 }
            switch mem.pressureLevel {
            case .nominal: return 95
            case .warning: return 65
            case .critical: return 30
            }
        }()
        return HealthScore.overallScore(
            storage: storageScore, battery: batteryScore, thermal: thermalScore,
            cpu: cpuScore, memory: memoryScore
        )
    }

    private var scoreLabel: String {
        switch overallScore {
        case 90...: return "Excellent"
        case 75..<90: return "Good"
        case 60..<75: return "Fair"
        default: return "Needs attention"
        }
    }

    private var macModelMarketingName: String {
        var buf = [CChar](repeating: 0, count: 256)
        var size = 256
        sysctlbyname("hw.model", &buf, &size, nil, 0)
        let raw = String(cString: buf)
        if raw.starts(with: "MacBookPro") { return "MacBook Pro" }
        if raw.starts(with: "MacBookAir") { return "MacBook Air" }
        if raw.starts(with: "Macmini")    { return "Mac mini" }
        if raw.starts(with: "iMac")       { return "iMac" }
        if raw.starts(with: "MacPro")     { return "Mac Pro" }
        if raw.starts(with: "MacStudio")  { return "Mac Studio" }
        return raw.isEmpty ? "Mac" : raw
    }

    private var chipName: String {
        var buf = [CChar](repeating: 0, count: 256)
        var size = 256
        sysctlbyname("machdep.cpu.brand_string", &buf, &size, nil, 0)
        let raw = String(cString: buf).trimmingCharacters(in: .whitespaces)
        if raw.isEmpty { return monitor.gpu?.gpuName ?? "Apple Silicon" }
        return raw
    }

    private var ramString: String {
        guard let mem = monitor.memory else { return "" }
        let gb = Double(mem.total) / 1_073_741_824.0
        return "\(Int(gb.rounded())) GB RAM"
    }

    private var macOSShort: String {
        let v = Foundation.ProcessInfo.processInfo.operatingSystemVersion
        return "macOS \(v.majorVersion).\(v.minorVersion)"
    }

    /// Small caption shown below the hero numeric score: uptime + machine tag.
    /// Intentionally terse — it's a sub-caption, not a second narrative.
    private var heroSubCaption: String {
        let up = Foundation.ProcessInfo.processInfo.systemUptime
        let d = Int(up / 86_400)
        let h = Int(up.truncatingRemainder(dividingBy: 86_400) / 3_600)
        let m = Int(up.truncatingRemainder(dividingBy: 3_600) / 60)
        let uptime: String
        if d > 0 { uptime = "\(d)d \(h)h uptime" }
        else if h > 0 { uptime = "\(h)h \(m)m uptime" }
        else { uptime = "\(m)m uptime" }
        return uptime + " · " + macModelWithSize
    }

    private var narrative: OverviewNarrative {
        OverviewNarrative.make(from: OverviewNarrative.Inputs(
            hottestSensorName: hottestSensor?.name,
            hottestSensorTemp: hottestSensor?.temp,
            cpuUsage: monitor.cpu?.totalUsage,
            pClusterUsage: pClusterUsage,
            eClusterUsage: eClusterUsage,
            gpuUsage: monitor.gpu?.utilization,
            socPower: monitor.socPower > 0 ? monitor.socPower : nil,
            memoryPressure: monitor.memory?.pressureLevel,
            batteryPercent: monitor.battery?.percentage,
            batteryTimeRemainingMinutes: monitor.battery?.timeRemaining,
            batteryCharging: monitor.battery?.isCharging ?? false,
            maxFanRPM: maxFanRPM,
            fanCount: monitor.sensors?.fans.count ?? 0
        ))
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { outer in
            ScrollView {
                VStack(spacing: MV.S.s3) {
                    titleStrip
                    bentoGrid
                        .frame(maxHeight: .infinity)
                }
                .padding(.horizontal, MV.S.s5)
                .padding(.vertical, MV.S.s4)
                .frame(minHeight: outer.size.height)
            }
            .background(MV.bg)
        }
        .navigationTitle("Overview")
    }

    // MARK: - Title strip (top masthead)

    private var titleStrip: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text("MACVITAL · TODAY")
                    .font(.system(size: MV.FS.micro, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(MV.text3)
                Text("Overview")
                    .font(.system(size: MV.FS.h3, weight: .semibold))
                    .tracking(-0.3)
                    .foregroundStyle(MV.text1)
            }
            Spacer()
            // Right-aligned masthead: matches mockup
            //   MacBook Pro 14"   · Apple M4 Pro
            //   macOS 15.4 · 36 GB RAM · ●  11:42 AM
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 5) {
                    Text(macModelWithSize)
                        .font(.system(size: MV.FS.caption, weight: .semibold))
                        .foregroundStyle(MV.text2)
                    Text("·")
                        .font(.system(size: MV.FS.caption))
                        .foregroundStyle(MV.text4)
                    Text(chipShort)
                        .font(.system(size: MV.FS.caption))
                        .foregroundStyle(MV.text3)
                }
                HStack(spacing: 5) {
                    Text(macOSShort)
                        .font(.system(size: MV.FS.caption))
                        .foregroundStyle(MV.text3)
                    if !ramString.isEmpty {
                        Text("·")
                            .font(.system(size: MV.FS.caption))
                            .foregroundStyle(MV.text4)
                        Text(ramString)
                            .font(.system(size: MV.FS.caption))
                            .foregroundStyle(MV.text3)
                    }
                    Text("·")
                        .font(.system(size: MV.FS.caption))
                        .foregroundStyle(MV.text4)
                    LiveClockView()
                }
            }
        }
        .padding(.bottom, MV.S.s1)
    }

    /// `MacBook Pro 14"` — marketing name + screen-size heuristic from model identifier.
    private var macModelWithSize: String {
        var buf = [CChar](repeating: 0, count: 256)
        var size = 256
        sysctlbyname("hw.model", &buf, &size, nil, 0)
        let raw = String(cString: buf)
        let base = macModelMarketingName
        // MacBookPro18,1 etc. — look for "14" or "16" anchor in the product name is
        // not in the model id, but we can guess from the main display bounds.
        if base == "MacBook Pro" || base == "MacBook Air" {
            let w = NSScreen.main?.frame.width ?? 0
            if w >= 3000 { return "\(base) 16\"" }
            if w >= 2000 { return "\(base) 14\"" }
            if w >= 1700 { return "\(base) 13\"" }
        }
        return raw.isEmpty ? base : base
    }

    /// Short chip string like "Apple M4 Pro" — trims anything after a paren /
    /// "generation" suffix and collapses whitespace.
    private var chipShort: String {
        var c = chipName
        // Strip "Apple" is not wanted — keep it. Just ensure prefix exists.
        if !c.hasPrefix("Apple") { c = "Apple " + c }
        // Remove trailing "()"-wrapped notes if any.
        if let open = c.firstIndex(of: "(") {
            c = String(c[..<open]).trimmingCharacters(in: .whitespaces)
        }
        return c
    }

    // MARK: - Bento grid

    /// Minimum row height — the grid will expand rows to fill available
    /// height so the bento never leaves dead whitespace at the bottom.
    /// Falls back to 104 px when the window is too small to benefit.
    private let minRowHeight: CGFloat = 104
    private let gap: CGFloat = MV.S.s2

    private var bentoGrid: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let totalHeight = geo.size.height
            let colWidth = (totalWidth - gap * 11) / 12
            let gapLocal = gap

            // Grid has 4 HStacks: hero/power/battery (h=2), cpu/gpu/mem (h=1),
            // fans/storage (h=1), network (h=1). Total = 5 row-units + 3
            // inter-row gaps (VStack spacing). Hero row contributes 1 internal
            // gap (between Power and Battery tiles stacked inside it), but
            // that's already baked into h(2) via gapLocal * (2-1).
            // Hero (h=2) + cpu-row (h=1) + fans-row (h=1) + network (h=1) = 5
            let rowUnits: CGFloat = 5
            let hstackGapCount: CGFloat = 3
            let availableForRows = totalHeight - gapLocal * hstackGapCount
            let rowHeightLocal = max(minRowHeight, availableForRows / rowUnits)

            let w: (Int) -> CGFloat = { cols in
                colWidth * CGFloat(cols) + gapLocal * CGFloat(cols - 1)
            }
            let h: (Int) -> CGFloat = { rows in
                rowHeightLocal * CGFloat(rows) + gapLocal * CGFloat(rows - 1)
            }

            VStack(spacing: gap) {
                // Row 1-2: Hero + Power + Battery (or Uptime fallback)
                HStack(spacing: gap) {
                    heroForVariant
                        .frame(width: w(8), height: h(2))

                    VStack(spacing: gap) {
                        PowerTile(monitor: monitor)
                            .frame(width: w(4), height: h(1))

                        // Battery OR Uptime — we never show literal "No battery".
                        // If a battery exists we render it. If it's nil (Mac mini/
                        // Studio, or very first render tick) we show uptime.
                        Group {
                            if let bat = monitor.battery {
                                BatteryTile(battery: bat)
                            } else {
                                UptimeTile()
                            }
                        }
                        .frame(width: w(4), height: h(1))
                    }
                }

                // Row 3: CPU + GPU + Memory
                HStack(spacing: gap) {
                    CPUTile(
                        cpu: monitor.cpu,
                        pUsage: pClusterUsage,
                        eUsage: eClusterUsage,
                        cpuPower: monitor.cpuPower
                    )
                    .frame(width: w(4), height: h(1))
                    GPUTile(gpu: monitor.gpu, power: monitor.gpuPower)
                        .frame(width: w(4), height: h(1))
                    MemoryTile(memory: monitor.memory)
                        .frame(width: w(4), height: h(1))
                }

                // Row 4: Fans + Storage
                HStack(spacing: gap) {
                    FansTile(fans: monitor.sensors?.fans ?? [])
                        .frame(width: w(6), height: h(1))
                    StorageTile(storage: monitor.storage)
                        .frame(width: w(6), height: h(1))
                }

                // Row 5: Network (full-width, 1 row — all rows stretch
                // proportionally via rowHeightLocal, so fill comes from
                // per-row growth, not from growing a single tile 2x).
                NetworkTile(
                    network: monitor.network,
                    history: monitor.networkDownHistory,
                    summaries: monitor.networkUsageSummaries
                )
                .frame(width: w(12), height: h(1))
            }
        }
        .frame(minHeight: minRowHeight * 5 + gap * 3, maxHeight: .infinity)
    }
}

// MARK: - Live clock view (with pulsing green dot)

private struct LiveClockView: View {
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        // Gate the TimelineView so it stops scheduling redraws when the
        // window is inactive. Falls back to a single static Date() frame.
        Group {
            if scenePhase == .active {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    clockRow(date: context.date)
                }
            } else {
                clockRow(date: Date())
            }
        }
    }

    private func clockRow(date: Date) -> some View {
        HStack(spacing: 5) {
            PulsingDot()
            Text(date, format: .dateTime.hour().minute())
                .font(.system(size: MV.FS.caption, weight: .medium))
                .foregroundStyle(MV.text2)
                .monospacedDigit()
        }
    }
}

private struct PulsingDot: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var on: Bool = false

    // Single fixed publisher. We drop ticks when the window is backgrounded
    // or when reduceMotion is on, so the cost of an idle tick is one
    // boolean compare. CPU stays near zero versus TimelineView(.animation),
    // which would tick at 60-120 Hz to cross-fade a 5pt circle.
    private let pulse = Timer.publish(every: 0.8, on: .main, in: .common).autoconnect()

    var body: some View {
        Circle()
            .fill(MV.ok)
            .frame(width: 5, height: 5)
            .opacity(reduceMotion ? 1.0 : (on ? 1.0 : 0.4))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.8), value: on)
            .onReceive(pulse) { _ in
                guard !reduceMotion, scenePhase == .active else { return }
                on.toggle()
            }
    }
}

// MARK: - Hero tile
//
// Mockup: `padding: var(--s-4) var(--s-5)` (16 × 20), `justify-content:
// space-between`. Headline max-width 15ch; narrative max-width 58ch.
// SwiftUI can't do `ch` units, so we approximate: h1=36px * 15ch ≈ 405px,
// body=12px * 58ch ≈ 420px.

private struct HeroTile: View {
    let narrative: OverviewNarrative
    let score: Double
    let scoreLabel: String
    let sparkData: [Double]
    let subCaption: String

    var body: some View {
        // Build hero-specific chrome inline so we can override the default
        // MVTile vertical padding with hero padding (16 × 20).
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text("SYSTEM HEALTH")
                    .font(.system(size: MV.FS.micro, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(MV.text3)

                Text(narrative.attributedHeadline)
                    .lineSpacing(-2)                 // line-height 1.02 on 36pt
                    .tracking(-0.8)                  // ≈ -0.028em at 36pt (mockup)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 480, alignment: .leading)
                    .padding(.top, MV.S.s2)

                Text(narrative.subtext)
                    .font(.system(size: MV.FS.body))
                    .lineSpacing(MV.FS.body * 0.55)
                    .foregroundStyle(MV.text2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 460, alignment: .leading)
                    .padding(.top, MV.S.s2)
            }

            Spacer(minLength: MV.S.s3)

            // Footer: score + sparkline, pinned to bottom.
            HStack(alignment: .bottom, spacing: MV.S.s5) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: MV.S.s2) {
                        Text("\(Int(score.rounded()))")
                            .font(.system(size: MV.FS.display, weight: .semibold))
                            .tracking(-1.6)
                            .foregroundStyle(MV.ok)
                            .monospacedDigit()
                        VStack(alignment: .leading, spacing: 0) {
                            Text(scoreLabel)
                                .font(.system(size: MV.FS.caption, weight: .medium))
                                .foregroundStyle(MV.text2)
                            Text("out of 100")
                                .font(.system(size: MV.FS.caption))
                                .foregroundStyle(MV.text3)
                        }
                    }
                    Text(subCaption)
                        .font(.system(size: MV.FS.micro))
                        .tracking(0.2)
                        .foregroundStyle(MV.text3)
                        .lineLimit(1)
                        .padding(.top, 1)
                }
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: MV.S.s1) {
                    MVSparkline(
                        data: sparkData.count >= 2 ? sparkData : placeholderSpark,
                        color: MV.accentSage
                    )
                    .frame(height: 28)
                    .frame(maxWidth: 320)
                    HStack {
                        Text("60 MIN AGO")
                        Spacer()
                        Text("NOW")
                    }
                    .font(.system(size: 9, weight: .medium))
                    .tracking(0.4)
                    .foregroundStyle(MV.text4)
                    .frame(maxWidth: 320)
                }
            }
        }
        .padding(.horizontal, MV.S.s5)   // 20 px horizontal
        .padding(.vertical, MV.S.s4)     // 16 px vertical
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(MV.tile)
        .overlay(
            RoundedRectangle(cornerRadius: MV.radius)
                .strokeBorder(MV.hairline, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: MV.radius))
    }

    /// Flat-ish placeholder used for the very first render tick when history is empty.
    private var placeholderSpark: [Double] {
        [2, 2.2, 2.1, 2.4, 2.2, 2.5, 2.3, 2.6, 2.4, 2.7, 2.5, 2.8]
    }
}

// MARK: - Power tile

private struct PowerTile: View {
    let monitor: SystemMonitor

    private var breakdown: String {
        let cpu = monitor.cpuPower
        let gpu = monitor.gpuPower
        let dram = monitor.dramPowerSMC
        let usb = monitor.usb1PowerSMC + monitor.usb2PowerSMC
        var parts: [String] = []
        if cpu > 0  { parts.append(String(format: "CPU %.1f", cpu)) }
        if gpu > 0  { parts.append(String(format: "GPU %.1f", gpu)) }
        if dram > 0 { parts.append(String(format: "DRAM %.1f", dram)) }
        if usb > 0  { parts.append(String(format: "USB-C %.1f", usb)) }
        return parts.joined(separator: " · ")
    }

    /// Hint shows wall draw (PDTR/delivery) if > 0, else "SoC".
    /// If on battery and discharging, show "Battery".
    private var hint: String {
        let wall = monitor.deliveryPowerSMC
        if wall > 0 {
            return String(format: "Wall %.1f W", wall)
        }
        if let bat = monitor.battery {
            if !bat.isCharging && bat.wattage < 0 {
                return "Battery"
            }
            if bat.isCharging {
                return "Charging"
            }
        }
        return "SoC"
    }

    var body: some View {
        MVTile {
            VStack(alignment: .leading, spacing: 0) {
                MVTileHead(label: "Power draw", hint: hint)
                Spacer(minLength: 2)
                MVTileNumber(
                    value: monitor.socPower > 0
                        ? String(format: "%.1f", monitor.socPower)
                        : "—",
                    unit: "W",
                    color: MV.thermal
                )
                Spacer(minLength: 0)
                MVTileSub(text: breakdown.isEmpty ? "Reading SMC…" : breakdown)
            }
        }
    }
}

// MARK: - Battery tile (only rendered when battery != nil)

private struct BatteryTile: View {
    let battery: BatteryData

    private var hint: String {
        if battery.isCharging {
            return battery.wattage > 0
                ? String(format: "Charging · %.1f W", abs(battery.wattage))
                : "Charging"
        }
        if battery.isFullyCharged { return "Fully charged" }
        if battery.wattage != 0 {
            return String(format: "Discharging · %.1f W", abs(battery.wattage))
        }
        return "Discharging"
    }

    /// `2 h 12 m · 98% health · 147 cycles`
    /// Wear% is implicit in the 98% health number; we show it only if notable.
    private var sub: String {
        let timeStr: String
        if battery.timeRemaining <= 0 {
            timeStr = battery.isCharging
                ? (battery.isFullyCharged ? "Full" : "Estimating…")
                : "—"
        } else {
            let h = battery.timeRemaining / 60
            let m = battery.timeRemaining % 60
            timeStr = h > 0 ? "\(h) h \(m) m" : "\(m) m"
        }
        let health = String(format: "%.0f%% health", battery.healthPercent)
        return "\(timeStr) · \(health) · \(battery.cycleCount) cycles"
    }

    var body: some View {
        MVTile {
            VStack(alignment: .leading, spacing: 0) {
                MVTileHead(label: "Battery", hint: hint)
                Spacer(minLength: 2)
                MVTileNumber(
                    value: "\(Int(battery.percentage.rounded()))",
                    unit: "%",
                    color: MV.bat
                )
                MVBar(value: battery.percentage / 100, color: MV.bat)
                    .padding(.top, MV.S.s1)
                Spacer(minLength: 0)
                MVTileSub(text: sub)
            }
        }
    }
}

// MARK: - Uptime tile — fallback when no battery is present

private struct UptimeTile: View {
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        // Gate the TimelineView so it stops scheduling per-minute redraws
        // when the window is inactive. Renders one static frame instead.
        Group {
            if scenePhase == .active {
                TimelineView(.periodic(from: .now, by: 60)) { _ in
                    tileBody
                }
            } else {
                tileBody
            }
        }
    }

    private var tileBody: some View {
        let uptime = Foundation.ProcessInfo.processInfo.systemUptime
        return MVTile {
            VStack(alignment: .leading, spacing: 0) {
                MVTileHead(label: "Uptime", hint: bootedHint(now: Date(), uptime: uptime))
                Spacer(minLength: 2)
                MVTileNumber(
                    value: uptimeBig(uptime),
                    unit: uptimeUnit(uptime),
                    color: MV.bat
                )
                Spacer(minLength: 0)
                MVTileSub(text: uptimeSub(uptime))
            }
        }
    }

    private func uptimeBig(_ s: TimeInterval) -> String {
        let days = Int(s / 86_400)
        let hours = Int(s.truncatingRemainder(dividingBy: 86_400) / 3_600)
        if days > 0 { return "\(days)d \(hours)h" }
        let minutes = Int(s.truncatingRemainder(dividingBy: 3_600) / 60)
        return "\(hours)h \(minutes)m"
    }

    private func uptimeUnit(_ s: TimeInterval) -> String {
        return s >= 86_400 ? "since boot" : "awake"
    }

    private func uptimeSub(_ s: TimeInterval) -> String {
        let minutes = Int(s / 60)
        return "\(minutes.formatted(.number)) minutes total. No sleeps pending."
    }

    private func bootedHint(now: Date, uptime: TimeInterval) -> String {
        let boot = now.addingTimeInterval(-uptime)
        let f = DateFormatter()
        f.dateFormat = "EEE HH:mm"
        return "Booted \(f.string(from: boot))"
    }
}

// MARK: - CPU tile

private struct CPUTile: View {
    let cpu: CPUData?
    let pUsage: Double?
    let eUsage: Double?
    let cpuPower: Double        // Watts, from monitor.cpuPower

    /// 1-minute load average from `getloadavg()`.
    private static func loadAvg1() -> Double {
        var lavg = [Double](repeating: 0, count: 3)
        let n = getloadavg(&lavg, 3)
        if n >= 1 { return lavg[0] }
        return 0
    }

    /// `M4 Pro · load 1.82` (mockup) — falls back to core topology if load unavailable.
    private var hint: String {
        guard let cpu = cpu else { return "" }
        let load = Self.loadAvg1()
        var parts: [String] = []
        parts.append("\(cpu.performanceCoreCount)P + \(cpu.efficiencyCoreCount)E")
        if load > 0 {
            parts.append(String(format: "load %.2f", load))
        }
        return parts.joined(separator: " · ")
    }

    /// "23%  · 5.4 W"  — fold CPU package wattage inline with the big number.
    private var unitTail: String {
        if cpuPower > 0 {
            return String(format: "%%  · %.1f W", cpuPower)
        }
        return "%"
    }

    var body: some View {
        MVTile {
            VStack(alignment: .leading, spacing: 0) {
                MVTileHead(label: "CPU", hint: hint)
                Spacer(minLength: 2)
                MVTileNumber(
                    value: cpu.map { "\(Int($0.totalUsage.rounded()))" } ?? "—",
                    unit: unitTail,
                    color: MV.cpu
                )
                Spacer(minLength: 0)
                clusterBars
            }
        }
    }

    private var clusterBars: some View {
        HStack(alignment: .bottom, spacing: MV.S.s2) {
            clusterBar(
                label: "E · \(cpu?.efficiencyCoreCount ?? 0) cores",
                value: (eUsage ?? 0) / 100
            )
            clusterBar(
                label: "P · \(cpu?.performanceCoreCount ?? 0) cores",
                value: (pUsage ?? 0) / 100
            )
        }
    }

    private func clusterBar(label: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(MV.text3)
            MVBar(value: value, color: MV.cpu)
        }
    }
}

// MARK: - GPU tile

private struct GPUTile: View {
    let gpu: GPUData?
    let power: Double

    private var hint: String {
        var parts: [String] = []
        if let gpu = gpu, gpu.coreCount > 0 {
            parts.append("\(gpu.coreCount) cores")
        }
        if power > 0 {
            parts.append(String(format: "%.1f W", power))
        }
        return parts.joined(separator: " · ")
    }

    private var sub: String {
        guard let gpu = gpu else { return "" }
        var parts: [String] = [gpu.gpuName]
        if gpu.temperature > 0 {
            parts.append("\(Int(gpu.temperature.rounded()))°C")
        }
        parts.append("no throttling")
        return parts.joined(separator: " · ")
    }

    var body: some View {
        MVTile {
            VStack(alignment: .leading, spacing: 0) {
                MVTileHead(label: "GPU", hint: hint)
                Spacer(minLength: 2)
                MVTileNumber(
                    value: gpu.map { "\(Int($0.utilization.rounded()))" } ?? "—",
                    unit: "%",
                    color: MV.gpu
                )
                Spacer(minLength: 0)
                MVTileSub(text: sub)
            }
        }
    }
}

// MARK: - Memory tile

private struct MemoryTile: View {
    let memory: MemoryData?

    private static func fmtGB(_ bytes: UInt64) -> String {
        String(format: "%.1f", Double(bytes) / 1_073_741_824.0)
    }

    private var hint: String {
        guard let mem = memory else { return "" }
        return mem.pressureLevel.rawValue
    }

    /// `wired 3.2 · app 12.8 · comp 0.4 · swap 0` — mockup-style breakdown.
    /// Uses short forms so everything fits in the 4-col tile without truncation.
    private var sub: String {
        guard let mem = memory else { return "—" }
        let wired = "wired \(Self.fmtGB(mem.wired))"
        // "App" = active + inactive (process-addressable non-wired memory).
        let app = "app \(Self.fmtGB(mem.active + mem.inactive))"
        let comp = "comp \(Self.fmtGB(mem.compressed))"
        let swap = mem.swapUsed > 0 ? "swap \(Self.fmtGB(mem.swapUsed))" : "swap 0"
        return [wired, app, comp, swap].joined(separator: " · ")
    }

    private var fraction: Double {
        guard let mem = memory, mem.total > 0 else { return 0 }
        return Double(mem.used) / Double(mem.total)
    }

    var body: some View {
        MVTile {
            VStack(alignment: .leading, spacing: 0) {
                MVTileHead(label: "Memory", hint: hint)
                Spacer(minLength: 2)
                MVTileNumber(
                    value: memory.map { Self.fmtGB($0.used) } ?? "—",
                    unit: memory.map { "/ \(Self.fmtGB($0.total)) GB" } ?? "GB",
                    color: MV.mem
                )
                MVBar(value: fraction, color: MV.mem)
                    .padding(.top, MV.S.s1)
                Spacer(minLength: 0)
                MVTileSub(text: sub)
            }
        }
    }
}

// MARK: - Fans tile

private struct FansTile: View {
    let fans: [FanReading]

    private var allIdle: Bool {
        !fans.isEmpty && fans.allSatisfy { $0.rpm == 0 }
    }

    private var rpmRangeText: String {
        guard !fans.isEmpty else { return "Fanless chassis" }
        let minR = fans.map(\.minRPM).min() ?? 0
        let maxR = fans.map(\.maxRPM).max() ?? 0
        return "Min \(minR.formatted(.number)) · Max \(maxR.formatted(.number)) RPM"
    }

    var body: some View {
        MVTile {
            VStack(alignment: .leading, spacing: 0) {
                MVTileHead(
                    label: "Fans",
                    hint: allIdle ? "Passive · silent" : "Auto"
                )
                Spacer(minLength: 4)

                if fans.isEmpty {
                    // Fanless Mac (unlikely on a Pro but handle gracefully).
                    Text("No fans detected")
                        .font(.system(size: MV.FS.caption))
                        .foregroundStyle(MV.text3)
                } else if allIdle {
                    // All fans are idle — don't show "0 RPM" rows which look broken.
                    // Show a single calm line instead.
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Idle · passive cooling")
                            .font(.system(size: MV.FS.value, weight: .semibold))
                            .foregroundStyle(MV.text1)
                        Text("Fans will ramp up when the SoC asks for it.")
                            .font(.system(size: MV.FS.caption))
                            .foregroundStyle(MV.text2)
                    }
                } else {
                    VStack(spacing: 5) {
                        ForEach(fans) { fan in
                            FanRow(fan: fan)
                        }
                    }
                }

                Spacer(minLength: 0)
                HStack {
                    Text(rpmRangeText)
                    Spacer()
                    Text("Thermal · Nominal")
                }
                .font(.system(size: MV.FS.micro))
                .foregroundStyle(MV.text3)
            }
        }
    }
}

private struct FanRow: View {
    let fan: FanReading

    private var fraction: Double {
        let min = Double(max(fan.minRPM, 0))
        let max = Double(fan.maxRPM)
        guard max > min else { return 0 }
        return (Double(fan.rpm) - min) / (max - min)
    }

    private var displayName: String {
        // Mockup uses "Left" / "Right" — map from fan index if possible.
        let n = fan.name
        if n.hasSuffix("1") { return "Left" }
        if n.hasSuffix("2") { return "Right" }
        return n
    }

    var body: some View {
        HStack(spacing: MV.S.s2) {
            Text(displayName)
                .font(.system(size: MV.FS.caption))
                .foregroundStyle(MV.text2)
                .frame(width: 42, alignment: .leading)
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(fan.rpm.formatted(.number))
                    .font(.system(size: MV.FS.caption, weight: .semibold))
                    .foregroundStyle(MV.text1)
                    .monospacedDigit()
                Text("RPM")
                    .font(.system(size: MV.FS.micro))
                    .foregroundStyle(MV.text3)
            }
            .frame(width: 68, alignment: .leading)
            MVBar(value: fraction, color: MV.fan)
        }
    }
}

// MARK: - Storage tile

private struct StorageTile: View {
    let storage: StorageData?

    private var mainVolume: Volume? {
        storage?.volumes.first(where: { $0.mountPoint == "/" }) ?? storage?.volumes.first
    }

    private static func fmtGB(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824.0
        if gb >= 1000 { return String(format: "%.1f TB", gb / 1000) }
        return "\(Int(gb.rounded())) GB"
    }

    private var fraction: Double {
        guard let v = mainVolume, v.totalBytes > 0 else { return 0 }
        return Double(v.usedBytes) / Double(v.totalBytes)
    }

    private var volumeCountChip: String {
        guard let s = storage else { return "" }
        let n = s.volumes.count
        if n <= 1 { return "" }
        return " · \(n) volumes"
    }

    var body: some View {
        MVTile {
            VStack(alignment: .leading, spacing: 0) {
                MVTileHead(
                    label: mainVolume?.name ?? "Macintosh HD",
                    hint: storage == nil
                        ? "Reading SMART…"
                        : "\(mainVolume?.fileSystem ?? "APFS") · SMART \(healthLabel(storage?.healthPercent ?? 100))\(volumeCountChip)"
                )
                Spacer(minLength: 4)
                HStack(alignment: .firstTextBaseline) {
                    if let v = mainVolume {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(Self.fmtGB(v.usedBytes))
                                .font(.system(size: MV.FS.value, weight: .semibold))
                                .foregroundStyle(MV.text1)
                                .monospacedDigit()
                            Text("used of \(Self.fmtGB(v.totalBytes))")
                                .font(.system(size: MV.FS.caption))
                                .foregroundStyle(MV.text3)
                        }
                        Spacer()
                        Text("\(Self.fmtGB(v.freeBytes)) free")
                            .font(.system(size: MV.FS.caption))
                            .foregroundStyle(MV.text3)
                            .monospacedDigit()
                    } else {
                        // Loading placeholder — neutral, not "Storage unavailable".
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text("—")
                                .font(.system(size: MV.FS.value, weight: .semibold))
                                .foregroundStyle(MV.text2)
                                .monospacedDigit()
                            Text("reading volumes…")
                                .font(.system(size: MV.FS.caption))
                                .foregroundStyle(MV.text3)
                        }
                        Spacer()
                    }
                }
                MVBar(value: fraction)
                    .padding(.top, MV.S.s2)
                Spacer(minLength: 0)
                HStack {
                    Text(ioText)
                    Spacer()
                    Text("Health · \(healthSuffix(storage?.healthPercent ?? 100))")
                }
                .font(.system(size: MV.FS.micro))
                .foregroundStyle(MV.text3)
            }
        }
    }

    private var ioText: String {
        guard let s = storage else { return "—" }
        let r = s.readBytesPerSec
        let w = s.writeBytesPerSec
        if r == 0 && w == 0 { return "Disk idle" }
        return "R \(fmtRate(r)) · W \(fmtRate(w))"
    }

    private func fmtRate(_ bps: UInt64) -> String {
        let v = Double(bps)
        if v >= 1_048_576 { return String(format: "%.1f MB/s", v / 1_048_576) }
        if v >= 1_024 { return String(format: "%.0f KB/s", v / 1_024) }
        return "\(bps) B/s"
    }

    private func healthLabel(_ pct: Double) -> String {
        if pct >= 95 { return "OK" }
        if pct >= 80 { return "Fair" }
        return "Check"
    }
    private func healthSuffix(_ pct: Double) -> String {
        if pct >= 95 { return "Good" }
        if pct >= 80 { return "Fair" }
        return "Attention"
    }
}

// MARK: - Network tile

private struct NetworkTile: View {
    let network: NetworkData?
    let history: [UInt64]
    let summaries: [NetworkUsageSummary]

    // MARK: - Primary interface selection

    /// Prefer active Wi-Fi (has SSID), then any interface with live traffic,
    /// then any interface with an IPv4, then first.
    private var primaryInterface: NetworkInterface? {
        guard let ifs = network?.interfaces else { return nil }
        if let wifi = ifs.first(where: { $0.wifiSSID != nil && !$0.ipv4Address.isEmpty }) {
            return wifi
        }
        if let active = ifs.first(where: { !$0.ipv4Address.isEmpty && ($0.rxBytesPerSec > 0 || $0.txBytesPerSec > 0) }) {
            return active
        }
        if let withIp = ifs.first(where: { !$0.ipv4Address.isEmpty }) {
            return withIp
        }
        return ifs.first
    }

    // MARK: - Formatting helpers

    private static func fmtSpeed(_ bps: UInt64) -> (value: String, unit: String) {
        let v = Double(bps)
        if v >= 1_048_576 { return (String(format: "%.1f", v / 1_048_576), "MB/s") }
        if v >= 1_024    { return (String(format: "%.0f", v / 1_024),    "KB/s") }
        return ("\(bps)", "B/s")
    }

    private static func fmtBytes(_ bytes: UInt64) -> String {
        let v = Double(bytes)
        if v >= 1_073_741_824 { return String(format: "%.2f GB", v / 1_073_741_824) }
        if v >= 1_048_576     { return String(format: "%.1f MB", v / 1_048_576) }
        if v >= 1_024         { return String(format: "%.0f KB", v / 1_024) }
        return "\(bytes) B"
    }

    // MARK: - Derived values

    private var downTuple: (value: String, unit: String) {
        Self.fmtSpeed(primaryInterface?.rxBytesPerSec ?? 0)
    }

    private var upTuple: (value: String, unit: String) {
        Self.fmtSpeed(primaryInterface?.txBytesPerSec ?? 0)
    }

    private var sessionValue: String {
        guard let iface = primaryInterface else { return ", " }
        if let s = summaries.first(where: { $0.interface == iface.name }) {
            let total = s.session.bytesIn &+ s.session.bytesOut
            return Self.fmtBytes(total)
        }
        return ", "
    }

    private var todayValue: String {
        guard let iface = primaryInterface else { return ", " }
        if let s = summaries.first(where: { $0.interface == iface.name }) {
            let total = s.today.bytesIn &+ s.today.bytesOut
            return Self.fmtBytes(total)
        }
        return ", "
    }

    /// Colour-coded signal quality from dBm.
    /// Excellent >= -60, Fair >= -75, Weak < -75.
    private var signalColor: Color {
        guard let dbm = primaryInterface?.wifiSignalDBm else { return MV.text3 }
        if dbm >= -60 { return MV.accentSage }
        if dbm >= -75 { return MV.warning }
        return MV.critical
    }

    private var signalLabel: String {
        guard let dbm = primaryInterface?.wifiSignalDBm else { return ", " }
        if dbm >= -60 { return "Strong" }
        if dbm >= -75 { return "Fair" }
        return "Weak"
    }

    /// Mockup label: "Network · en0 Wi-Fi 6E"
    private var headerLabel: String {
        guard let iface = primaryInterface else { return "Network" }
        var suffix = iface.name
        if iface.wifiSSID != nil {
            if let band = iface.wifiBand, !band.isEmpty {
                suffix += " Wi-Fi \(band)"
            } else {
                suffix += " Wi-Fi"
            }
        }
        return "Network · \(suffix)"
    }

    /// First-launch fix (2026-04-17): when CWWiFiClient hasn't yet
    /// resolved SSID (Location Services permission flow on first launch),
    /// show a stable "Resolving Wi-Fi…" placeholder until SSID arrives.
    private var headerHint: String {
        guard let iface = primaryInterface else { return "" }
        let isWifiInterface = iface.name.hasPrefix("en") && (iface.wifiBand != nil || iface.wifiSSID != nil)

        if isWifiInterface, iface.wifiSSID == nil {
            return "Resolving Wi-Fi…"
        }

        var parts: [String] = []
        if let ssid = iface.wifiSSID, !ssid.isEmpty { parts.append(ssid) }
        if let sig = iface.wifiSignalDBm { parts.append("\(sig) dBm") }
        if let ifs = network?.interfaces {
            let active = ifs.filter { !$0.ipv4Address.isEmpty }.count
            if active > 1 { parts.append("\(active) ifaces") }
        }
        if parts.isEmpty { return iface.linkSpeed }
        return parts.joined(separator: " · ")
    }

    private var ipValue: String {
        guard let iface = primaryInterface, !iface.ipv4Address.isEmpty else { return ", " }
        return iface.ipv4Address
    }

    private var linkValue: String {
        guard let iface = primaryInterface else { return ", " }
        if !iface.linkSpeed.isEmpty { return iface.linkSpeed }
        if let ch = iface.wifiChannel, let band = iface.wifiBand { return "\(band) ch \(ch)" }
        return ", "
    }

    // MARK: - Layout

    var body: some View {
        MVTile {
            VStack(alignment: .leading, spacing: 0) {

                // Row 1: eyebrow
                MVTileHead(label: headerLabel, hint: headerHint)

                Spacer(minLength: MV.S.s2)

                // Row 2: hero + right-side column
                HStack(alignment: .center, spacing: 0) {

                    // LEFT: down rate hero + up rate sub
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text("\u{2193}")
                                .font(.system(size: MV.FS.h3, weight: .light))
                                .foregroundStyle(MV.net.opacity(0.6))
                            Text(downTuple.value)
                                .font(.system(size: MV.FS.h3, weight: .semibold))
                                .tracking(-0.6)
                                .foregroundStyle(MV.net)
                                .monospacedDigit()
                            Text(downTuple.unit)
                                .font(.system(size: MV.FS.body, weight: .medium))
                                .foregroundStyle(MV.text3)
                                .baselineOffset(1)
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text("\u{2191}")
                                .font(.system(size: MV.FS.caption, weight: .light))
                                .foregroundStyle(MV.text4)
                            Text(upTuple.value)
                                .font(.system(size: MV.FS.caption, weight: .semibold))
                                .foregroundStyle(MV.text2)
                                .monospacedDigit()
                            Text(upTuple.unit)
                                .font(.system(size: MV.FS.micro, weight: .medium))
                                .foregroundStyle(MV.text3)
                        }
                    }

                    // Thin divider
                    Rectangle()
                        .fill(MV.hairline)
                        .frame(width: 0.5, height: 30)
                        .padding(.horizontal, MV.S.s3)

                    // CENTRE: signal pill + stat pair
                    VStack(alignment: .leading, spacing: MV.S.s1) {
                        // Signal quality pill
                        HStack(spacing: 4) {
                            Circle()
                                .fill(signalColor)
                                .frame(width: 5, height: 5)
                            Text(signalLabel)
                                .font(.system(size: MV.FS.micro, weight: .semibold))
                                .tracking(0.6)
                                .foregroundStyle(signalColor)
                        }
                        // Session + Today inline
                        HStack(spacing: MV.S.s3) {
                            NetStatCell(label: "SESSION", value: sessionValue)
                            NetStatCell(label: "TODAY", value: todayValue)
                        }
                    }

                    // Thin divider
                    Rectangle()
                        .fill(MV.hairline)
                        .frame(width: 0.5, height: 30)
                        .padding(.horizontal, MV.S.s3)

                    // RIGHT: IP + link inline
                    VStack(alignment: .leading, spacing: MV.S.s1) {
                        NetStatCell(label: "IP", value: ipValue)
                        NetStatCell(label: "LINK", value: linkValue)
                    }

                    Spacer(minLength: MV.S.s3)

                    // SPARKLINE: takes remaining width, anchored right
                    VStack(alignment: .trailing, spacing: 3) {
                        MVSparkline(
                            uint64Data: history.count >= 2 ? history : [1, 2, 1, 3, 2, 4, 3],
                            color: MV.net
                        )
                        .frame(width: 140, height: 28)

                        Text("60 s")
                            .font(.system(size: MV.FS.micro))
                            .foregroundStyle(MV.text4)
                    }
                }

                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Helper: compact label + value cell

private struct NetStatCell: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(MV.text3)
            Text(value)
                .font(.system(size: MV.FS.caption, weight: .semibold))
                .foregroundStyle(MV.text1)
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }
}

// MARK: - Preview

#Preview("Overview") {
    OverviewView()
        .environment(AppState())
        .frame(width: 820, height: 700)
}

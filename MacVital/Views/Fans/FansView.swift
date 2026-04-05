// MacVital/Views/Fans/FansView.swift
import SwiftUI
import Charts
import Combine
import IOKit
import IOKit.ps

// MARK: - Fan Mode

enum FanMode: String, Codable {
    case system, manual, autoBoost, min, mid, max
}

// MARK: - Auto Boost Rule

struct FanBoostRule: Identifiable, Codable {
    let id: UUID
    var fanTarget: String     // e.g. "Fan 1+2", "Fan 1", "Fan 2"
    var speedPct: Int         // 0 to 100
    var sensor: String        // e.g. "CPU Die"
    var thresholdC: Int       // degrees C

    init(id: UUID = UUID(), fanTarget: String, speedPct: Int, sensor: String, thresholdC: Int) {
        self.id = id
        self.fanTarget = fanTarget
        self.speedPct = speedPct
        self.sensor = sensor
        self.thresholdC = thresholdC
    }
}

// MARK: - Fan Op Result (XPC feedback displayed inline)

struct FanOpResult {
    let success: Bool
    let message: String
}

// MARK: - Fan State (per-fan local override settings)

struct FanControlState: Codable {
    var mode: FanMode = .autoBoost
    var manualRPM: Double = 3000
    var boostRules: [FanBoostRule] = [
        FanBoostRule(fanTarget: "Fan 1+2", speedPct: 50, sensor: "CPU Die", thresholdC: 60),
        FanBoostRule(fanTarget: "Fan 1+2", speedPct: 75, sensor: "CPU Die", thresholdC: 70),
        FanBoostRule(fanTarget: "Fan 1+2", speedPct: 100, sensor: "CPU Die", thresholdC: 80),
    ]
    /// Last XPC operation result, shown as inline status badge. Not persisted.
    var lastResult: FanOpResult? = nil
    /// Whether an XPC fan-control call is in progress. Not persisted.
    var isBusy: Bool = false

    // Persist only the user-meaningful fields. Runtime status (lastResult, isBusy)
    // is intentionally excluded from Codable.
    private enum CodingKeys: String, CodingKey {
        case mode, manualRPM, boostRules
    }
}

// MARK: - RPM History Point

private struct RPMPoint: Identifiable {
    var id: Int { index }
    let index: Int
    let rpm: Double
    let fanIndex: Int
}

// MARK: - Fan Curve Control Point

private struct CurvePoint: Identifiable, Codable {
    var id: UUID = UUID()
    var temperature: Double   // 0 to 100 deg C (x-axis)
    var fanSpeed: Double      // 0 to 100 % (y-axis)
}

// MARK: - Fan Profile Settings (per power source: AC vs Battery)
// Persisted to UserDefaults under key `com.macvital.fans.profileSettings`.
// One instance per profile id ("ac", "bat"), held in FansView.profileSettings dict.

fileprivate struct FanProfileSettings: Codable {
    var fanStates: [FanControlState]
    var curvePoints: [CurvePoint]
    var activePreset: String
}

// Defaults referenced by FansView when no persisted settings exist or decode fails.
// AC profile: balanced preset (current original defaults).
// Battery profile: silent preset (lower curve), all fans on .system mode initially.

fileprivate let defaultFanStatesAC: [FanControlState] = [
    FanControlState(mode: .system, manualRPM: 3000),
    FanControlState(mode: .system, manualRPM: 3000),
    FanControlState(mode: .system, manualRPM: 3000),
    FanControlState(mode: .system, manualRPM: 3000),
]

fileprivate let defaultFanStatesBat: [FanControlState] = [
    FanControlState(mode: .system, manualRPM: 3000),
    FanControlState(mode: .system, manualRPM: 3000),
    FanControlState(mode: .system, manualRPM: 3000),
    FanControlState(mode: .system, manualRPM: 3000),
]

fileprivate let defaultCurvePointsAC: [CurvePoint] = [
    CurvePoint(temperature: 30,  fanSpeed: 8),
    CurvePoint(temperature: 45,  fanSpeed: 18),
    CurvePoint(temperature: 60,  fanSpeed: 35),
    CurvePoint(temperature: 75,  fanSpeed: 58),
    CurvePoint(temperature: 100, fanSpeed: 80),
]

fileprivate let defaultCurvePointsBatQuiet: [CurvePoint] = [
    CurvePoint(temperature: 30,  fanSpeed: 5),
    CurvePoint(temperature: 45,  fanSpeed: 12),
    CurvePoint(temperature: 60,  fanSpeed: 22),
    CurvePoint(temperature: 75,  fanSpeed: 38),
    CurvePoint(temperature: 100, fanSpeed: 55),
]

// MARK: - Sensor Group Model

private struct SensorGroup: Identifiable {
    let id: String
    let label: String
    let icon: String
    let color: Color
    var isExpanded: Bool
    var sensors: [SensorReading]
}

// MARK: - Colors from HTML mockup

private enum FansColors {
    static let bg  = Color(red: 0.11, green: 0.11, blue: 0.118)        // #1C1C1E
    static let bg2 = Color(red: 0.173, green: 0.173, blue: 0.18)       // #2C2C2E
    static let bg3 = Color(red: 0.227, green: 0.227, blue: 0.235)      // #3A3A3C
    static let text  = Color.white.opacity(0.85)
    static let text2 = Color.white.opacity(0.55)
    static let text3 = Color.white.opacity(0.35)
    static let separator = Color.white.opacity(0.08)
    // Exact hex colors from HTML :root variables
    static let blue   = Color(red: 0.039, green: 0.518, blue: 1.0)     // #0A84FF
    static let green  = Color(red: 0.196, green: 0.843, blue: 0.294)   // #32D74B
    static let orange = Color(red: 1.0, green: 0.624, blue: 0.039)     // #FF9F0A
    static let red    = Color(red: 1.0, green: 0.271, blue: 0.227)     // #FF453A
    static let yellow = Color(red: 1.0, green: 0.839, blue: 0.039)     // #FFD60A
}

// MARK: - Main FansView

struct FansView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Per-profile fan control settings (AC vs Battery).
    // Replaces the previous trio of @State (fanStates, curvePoints, activePreset).
    // Reads/writes go through computed Bindings below; persistence in didSet via UserDefaults.
    @State private var profileSettings: [String: FanProfileSettings] = FansView.loadProfileSettings()

    // RPM history (last 60 points, one per second, per fan)
    @State private var rpmHistory: [[RPMPoint]] = [[], []]
    @State private var historyTimer: Timer?
    @State private var boostTimer: Timer?   // fires every 5 s to evaluate Auto Boost rules
    @State private var historyIndex: Int = 0

    // (Removed: no more mock RPMs, chart shows real data or zeros)

    @State private var draggingPoint: UUID? = nil

    // Sensor groups (collapsible)
    @State private var sensorGroups: [SensorGroup] = Self.buildDefaultGroups()
    @State private var linkedFans: Bool = false
    @State private var profile: String = "ac"  // "ac" | "bat"

    // Power source watcher (polls every 2s to keep `profile` in sync with AC/Battery).
    // Polling chosen over IOPSNotificationCreateRunLoopSource for reliability per spec.
    @State private var powerSourceObserver: AnyCancellable?

    // Spinning fan animation — track start time for TimelineView-based rotation
    @State private var fanSpinStartDate: Date = Date()

    // Fan curve canvas visibility — pause animation when off-screen
    @State private var curveCanvasActive: Bool = false

    // Track tab visibility, pause all animations when tab is hidden
    @State private var isVisible: Bool = false

    @AppStorage("com.macvital.fans.variant") private var fanVariantRaw: Int = FanVariant.customCanvas.rawValue

    private var sensorData: SensorData? { appState.monitor.sensors }

    // MARK: - Placeholder data for when SMC helper is not installed (shows em-dashes, not fake numbers)

    private static let placeholderFans: [FanReading] = [
        FanReading(name: "Fan 1", rpm: 0, minRPM: 0, maxRPM: 0),
        FanReading(name: "Fan 2", rpm: 0, minRPM: 0, maxRPM: 0),
    ]

    // MARK: - Computed helpers (with mock fallback)

    private var fans: [FanReading] {
        sensorData?.fans ?? []
    }

    private var allTempSensors: [SensorReading] {
        sensorData?.sensors.filter { $0.unit == "°C" } ?? []
    }

    private func rpmColor(for fan: FanReading) -> Color {
        let pct = Double(fan.rpm) / max(Double(fan.maxRPM), 1)
        if pct < 0.55 { return FansColors.green }
        if pct < 0.78 { return FansColors.orange }
        return FansColors.red
    }

    private func tempColor(_ t: Double) -> Color {
        if t < 60 { return FansColors.green }
        if t < 80 { return FansColors.orange }
        return FansColors.red
    }

    private var peakTemp: Double {
        allTempSensors.map(\.value).max() ?? 0
    }

    private var displayFans: [FanReading] {
        fans.isEmpty ? Self.placeholderFans : fans
    }

    // MARK: - Profile-keyed Bindings
    // These read/write through `profileSettings[profile]` so the rest of the body
    // can keep using `fanStates`, `curvePoints`, `activePreset` (now via .wrappedValue).
    // Persists to UserDefaults whenever the underlying dict changes.

    private static let profileSettingsKey = "com.macvital.fans.profileSettings"

    /// Returns a non-nil settings struct for the given profile id, falling back to
    /// AC defaults if the dict somehow lacks the key (defensive).
    private func settings(for profileID: String) -> FanProfileSettings {
        if let s = profileSettings[profileID] { return s }
        return profileID == "bat"
            ? FanProfileSettings(fanStates: defaultFanStatesBat,
                                 curvePoints: defaultCurvePointsBatQuiet,
                                 activePreset: "silent")
            : FanProfileSettings(fanStates: defaultFanStatesAC,
                                 curvePoints: defaultCurvePointsAC,
                                 activePreset: "balanced")
    }

    private var fanStates: Binding<[FanControlState]> {
        Binding(
            get: { self.settings(for: self.profile).fanStates },
            set: { newValue in
                var s = self.settings(for: self.profile)
                s.fanStates = newValue
                self.profileSettings[self.profile] = s
                Self.persistProfileSettings(self.profileSettings)
            }
        )
    }

    private var curvePoints: Binding<[CurvePoint]> {
        Binding(
            get: { self.settings(for: self.profile).curvePoints },
            set: { newValue in
                var s = self.settings(for: self.profile)
                s.curvePoints = newValue
                self.profileSettings[self.profile] = s
                Self.persistProfileSettings(self.profileSettings)
            }
        )
    }

    private var activePreset: Binding<String> {
        Binding(
            get: { self.settings(for: self.profile).activePreset },
            set: { newValue in
                var s = self.settings(for: self.profile)
                s.activePreset = newValue
                self.profileSettings[self.profile] = s
                Self.persistProfileSettings(self.profileSettings)
            }
        )
    }

    /// Decode persisted profile settings from UserDefaults. On any failure, return the
    /// canonical defaults (AC = balanced, Battery = silent + .system mode on all fans).
    private static func loadProfileSettings() -> [String: FanProfileSettings] {
        let defaults: [String: FanProfileSettings] = [
            "ac":  FanProfileSettings(fanStates: defaultFanStatesAC,
                                      curvePoints: defaultCurvePointsAC,
                                      activePreset: "balanced"),
            "bat": FanProfileSettings(fanStates: defaultFanStatesBat,
                                      curvePoints: defaultCurvePointsBatQuiet,
                                      activePreset: "silent"),
        ]
        guard let data = UserDefaults.standard.data(forKey: profileSettingsKey) else {
            return defaults
        }
        do {
            let decoded = try JSONDecoder().decode([String: FanProfileSettings].self, from: data)
            // Make sure both required keys exist; merge defaults for any missing.
            var merged = defaults
            for (k, v) in decoded { merged[k] = v }
            return merged
        } catch {
            return defaults
        }
    }

    private static func persistProfileSettings(_ settings: [String: FanProfileSettings]) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: profileSettingsKey)
    }

    /// IOKit power source detection. Returns "ac" when on the wall, "bat" when on battery.
    /// Defaults to "ac" on any failure (e.g. desktop Macs without battery).
    private func currentPowerSource() -> String {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else { return "ac" }
        guard let type = IOPSGetProvidingPowerSourceType(blob)?.takeUnretainedValue() else { return "ac" }
        let s = type as String
        return s == kIOPSACPowerValue ? "ac" : "bat"
    }

    // MARK: - Body

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 0) {
                // -- Profile bar --
                profileBar

                // -- "LIVE FAN STATUS" label --
                liveFanStatusLabel

                // -- Hero: spinning fan icons --
                heroSection

                // -- Main split: sensors left (42%), fan controls right (58%) --
                GeometryReader { geo in
                    HStack(alignment: .top, spacing: 0) {
                        leftSensorsPanel
                            .frame(width: geo.size.width * 0.42)

                        Rectangle()
                            .fill(FansColors.separator)
                            .frame(width: 1)

                        rightFanPanel
                            .frame(width: geo.size.width * 0.58 - 1)
                    }
                }
                .frame(minHeight: 500)

                // -- Fan curve editor --
                fanCurveEditor

                // -- Thermal strip (6 sensor tiles + PEAK) --
                thermalStripSection

                // -- Warning bar (yellow tint + Reset All to Auto) --
                warningBar

                // -- Helper status bar --
                helperStatusBar
            }
        }
        .scrollIndicators(.visible)
        .navigationTitle("Fans")
        .onAppear {
            isVisible = true
            // Auto-switch profile to the actual power source (silent, no badge for v1).
            profile = currentPowerSource()
            syncSensorGroups()
            syncFanStatesFromData()
            startTimers()
            startPowerSourceObserver()
        }
        .onDisappear {
            isVisible = false
            stopTimers()
            stopPowerSourceObserver()
        }
        .onChange(of: sensorData?.sensors.count) { _, _ in
            syncSensorGroups()
        }
    }

    // MARK: - Profile Bar
    // HTML: .profile-bar — 32px high, bg2, border-bottom separator

    private var profileBar: some View {
        HStack(spacing: 0) {
            // Power Adapter tab
            profileTabButton(id: "ac", label: "Power Adapter", systemIcon: "bolt.circle")
            // Battery tab
            profileTabButton(id: "bat", label: "Battery", systemIcon: "battery.75percent")

            Spacer()

            // Link fans toggle button
            // HTML: .link-fans-btn — 22px height, border, 11px font
            Button {
                linkedFans.toggle()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: linkedFans ? "link.circle.fill" : "plus")
                        .font(.system(size: 10))
                    Text(linkedFans ? "Fans Linked" : "Link Fans")
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 12)
                .frame(height: 22)
                .background(
                    linkedFans
                        ? FansColors.blue.opacity(0.10)
                        : Color.white.opacity(0.07),
                    in: RoundedRectangle(cornerRadius: 5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(
                            linkedFans
                                ? FansColors.blue.opacity(0.3)
                                : FansColors.separator,
                            lineWidth: 1
                        )
                )
                .foregroundStyle(linkedFans ? FansColors.blue : FansColors.text2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .frame(height: 32)
        .background(FansColors.bg2)
        .overlay(alignment: .bottom) {
            Rectangle().fill(FansColors.separator).frame(height: 1)
        }
    }

    private func profileTabButton(id: String, label: String, systemIcon: String) -> some View {
        Button {
            profile = id
        } label: {
            HStack(spacing: 5) {
                Image(systemName: systemIcon)
                    .font(.system(size: 10))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 14)
            .frame(height: 24)
            .background(
                profile == id
                    ? Color.white.opacity(0.09)
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: 5)
            )
            .foregroundStyle(
                profile == id ? FansColors.text : FansColors.text2
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Hero Section (Spinning Fans)
    // HTML: .hero — padding 20px 24px 16px, bg, border-bottom separator
    // Two fan units centered with 64px gap, 1px vertical divider 140px tall

    // MARK: - Live Fan Status Label
    // Separated so it renders as its own visible row above the hero

    private var liveFanStatusLabel: some View {
        // HTML: .hero-label — inside .hero div, margin-bottom 12px
        // Rendered as a separate element above heroSection but visually contiguous
        HStack {
            Text("LIVE FAN STATUS")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(FansColors.text3)  // HTML: .hero-label uses text3
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)   // HTML: .hero padding-top is 20px
        .padding(.bottom, 12) // HTML: .hero-label margin-bottom 12px
        .background(FansColors.bg)
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            FanVariantPicker(selection: Binding(
                get: { FanVariant(rawValue: fanVariantRaw) ?? .customCanvas },
                set: { fanVariantRaw = $0.rawValue }
            ))
            ForEach(Array(displayFans.enumerated()), id: \.offset) { idx, fan in
                FanHeroCard(
                    variant: FanVariant(rawValue: fanVariantRaw) ?? .customCanvas,
                    data: heroData(for: fan, index: idx),
                    isVisible: isVisible,
                    startDate: fanSpinStartDate
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .background(FansColors.bg)
        .overlay(alignment: .bottom) {
            Rectangle().fill(FansColors.separator).frame(height: 1)
        }
    }

    private func heroData(for fan: FanReading, index: Int) -> FanHeroData {
        let states = fanStates.wrappedValue
        let stateIdx = min(index, max(states.count - 1, 0))
        let state = states.indices.contains(stateIdx) ? states[stateIdx] : FanControlState()
        let target = fan.targetRPM > 0 ? fan.targetRPM : Int(state.manualRPM)
        let history = (rpmHistory.indices.contains(index) ? rpmHistory[index] : []).map { $0.rpm }
        let hottest = allTempSensors.max(by: { $0.value < $1.value })
        let driverSensor = hottest.map { "\($0.name) (\($0.key))" } ?? "P-Cluster Die (Tp09)"
        let driverTemp = hottest?.value ?? peakTemp
        let mode: String
        switch state.mode {
        case .system:    mode = "System"
        case .manual:    mode = "Manual"
        case .autoBoost: mode = "Auto Boost"
        case .min, .mid, .max: mode = "Manual"
        }
        let onCurve = abs(fan.rpm - target) < max(target / 20, 100)
        return FanHeroData(
            fanIndex: index,
            displayName: fan.name,
            smcKeyHint: "F\(index)ID / F\(index)Tg / F\(index)Ac",
            currentRPM: fan.rpm,
            targetRPM: max(target, fan.minRPM),
            minRPM: fan.minRPM,
            maxRPM: max(fan.maxRPM, fan.minRPM + 1),
            rpmHistory: history,
            driverSensor: driverSensor,
            driverTempC: driverTemp,
            modeLabel: mode,
            onCurve: onCurve
        )
    }

    private func fanHeroUnit(fan: FanReading, index: Int) -> some View {
        let color = fan.rpm == 0 ? Color(white: 0.4) : rpmColor(for: fan)
        let dba = estimatedDBA(rpm: fan.rpm, maxRPM: fan.maxRPM)
        return VStack(alignment: .center, spacing: 10) {
            // Fan name label
            // HTML: .fan-name-label — 10px, 600, 0.07em, uppercase, text3
            Text(fan.name.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.9)
                .foregroundStyle(FansColors.text3)

            // 100x100 spinning fan SVG
            // HTML: .fan-svg-wrap — 100x100, outer circle r=48, inner r=42, 7 blades, hub r=7 + r=3
            ZStack {
                // Outer ring
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 1.5)
                    .frame(width: 96, height: 96)

                // Inner circle fill
                Circle()
                    .fill(FansColors.bg)
                    .stroke(Color.white.opacity(0.04), lineWidth: 1)
                    .frame(width: 84, height: 84)

                // Spinning blades via TimelineView + Canvas
                // Honor Reduce Motion: pause rotation when accessibility flag is set.
                TimelineView(.animation(minimumInterval: nil, paused: !isVisible || fan.rpm == 0 || reduceMotion)) { context in
                    let elapsed = context.date.timeIntervalSince(fanSpinStartDate)
                    // Compute degsPerSec INSIDE the TimelineView so it updates with live RPM
                    let currentDegsPerSec = Double(fan.rpm) / 60.0 * 360.0 // RPM → degrees per second
                    let angle = fan.rpm > 0 ? (elapsed * currentDegsPerSec).truncatingRemainder(dividingBy: 360) : 0
                    Canvas { ctx, size in
                        let center = CGPoint(x: size.width / 2, y: size.height / 2)
                        let bladeCount = 7
                        for i in 0..<bladeCount {
                            let bladeAngle = (Double(i) / Double(bladeCount)) * .pi * 2 + Angle.degrees(angle).radians
                            ctx.drawLayer { inner in
                                inner.translateBy(x: center.x, y: center.y)
                                inner.rotate(by: Angle(radians: bladeAngle))
                                // Blade path matching HTML SVG:
                                // M50,50 C43,39 35,30 42,20 C49,10 59,19 57.5,30 C56,39 53,44 50,50
                                // Translated to center-origin, scaled for 80px canvas
                                let path = Path { p in
                                    p.move(to: .zero)
                                    p.addCurve(
                                        to: CGPoint(x: -6.4, y: -24),
                                        control1: CGPoint(x: -5.6, y: -8.8),
                                        control2: CGPoint(x: -12, y: -16)
                                    )
                                    p.addCurve(
                                        to: CGPoint(x: 6, y: -16),
                                        control1: CGPoint(x: -0.8, y: -32),
                                        control2: CGPoint(x: 7.2, y: -24.8)
                                    )
                                    p.addCurve(
                                        to: .zero,
                                        control1: CGPoint(x: 4.8, y: -8.8),
                                        control2: CGPoint(x: 2.4, y: -4.8)
                                    )
                                    p.closeSubpath()
                                }
                                inner.fill(path, with: .color(color.opacity(0.88)))
                            }
                        }
                    }
                }
                .frame(width: 80, height: 80)

                // Tick marks around edge (8 at 45-degree intervals)
                // HTML: 8 lines from (50,3) to (50,9) at 0,45,90...315 degrees, opacity 0.15
                Canvas { ctx, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    for i in 0..<8 {
                        let angle = Double(i) * .pi / 4
                        ctx.drawLayer { inner in
                            inner.translateBy(x: center.x, y: center.y)
                            inner.rotate(by: Angle(radians: angle))
                            var tick = Path()
                            tick.move(to: CGPoint(x: 0, y: -37.6))    // r=48 equivalent scaled
                            tick.addLine(to: CGPoint(x: 0, y: -32.8)) // 6px long
                            inner.stroke(tick, with: .color(.white.opacity(0.15)), lineWidth: 0.8)
                        }
                    }
                }
                .frame(width: 96, height: 96)
                .allowsHitTesting(false)

                // Hub center
                Circle()
                    .fill(FansColors.bg)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    .frame(width: 14, height: 14)

                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 6, height: 6)
            }
            .frame(width: 100, height: 100)

            // RPM display
            // HTML: .fan-rpm-number — 32px, 300, tabular-nums, -0.02em tracking
            VStack(spacing: 2) {
                Text(fan.rpm > 0 ? formatRPM(fan.rpm) : "\u{2014}")
                    .font(.system(size: 32, weight: .light))
                    .monospacedDigit()
                    .tracking(-0.5)
                    .foregroundStyle(color)
                    .animation(.easeInOut(duration: 0.4), value: color)

                // HTML: .fan-rpm-sub — 10px, text3, margin-top 2px
                Text("of \(formatRPM(fan.maxRPM)) RPM max")
                    .font(.system(size: 10))
                    .foregroundStyle(FansColors.text3)
            }

            // Noise badge
            // HTML: .noise-badge — capsule, 11px font-weight 600, border separator
            HStack(spacing: 5) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                Text(fan.rpm > 0 ? "~\(dba) dBA" : "\u{2014}")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(FansColors.text2)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.05), in: Capsule())
            .overlay(Capsule().strokeBorder(FansColors.separator, lineWidth: 1))
        }
    }

    // MARK: - Left Sensors Panel (42% width)
    // HTML: .left-panel — 42%, border-right separator, flex-column

    private var leftSensorsPanel: some View {
        VStack(spacing: 0) {
            // Panel header
            // HTML: .panel-header — 10px 16px 8px padding, border-bottom, flex between
            HStack {
                Text("TEMPERATURE SENSORS")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.0)
                    .foregroundStyle(FansColors.text2)

                Spacer()

                // HTML: .sensor-count-badge — 9px, 700, blue bg, blue border
                Text("\(allTempSensors.count) SENSORS")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.7)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(FansColors.blue.opacity(0.14), in: RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(FansColors.blue.opacity(0.22), lineWidth: 1)
                    )
                    .foregroundStyle(FansColors.blue)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .overlay(alignment: .bottom) {
                Rectangle().fill(FansColors.separator).frame(height: 1)
            }

            // Sensor groups — own scroll area so expanding 145 CPU sensors
            // doesn't push the entire page down
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach($sensorGroups) { $group in
                        let sensors = sensorsForGroup(group)
                        if !sensors.isEmpty {
                            SensorGroupSection(
                                group: $group,
                                sensors: sensors,
                                tempColor: tempColor
                            )
                        }
                    }
                }
            }
            .frame(maxHeight: 500)
        }
    }

    // MARK: - Right Fan Control Panel (58% width)
    // HTML: .right-panel — flex:1, flex-column, overflow hidden

    private var rightFanPanel: some View {
        VStack(spacing: 0) {
            // Fan control sections — renders inline, outer ScrollView handles scrolling
            LazyVStack(spacing: 0) {
                ForEach(Array(displayFans.enumerated()), id: \.offset) { idx, fan in
                    FanControlSection(
                        fan: fan,
                        state: binding(forFan: idx),
                        fanIndex: idx,
                        xpc: appState.xpc,
                        isHelperInstalled: appState.isHelperInstalled,
                        smcReader: appState.monitor.smcReader,
                        onModeChange: { mode in
                            if linkedFans {
                                var states = fanStates.wrappedValue
                                for i in 0..<states.count { states[i].mode = mode }
                                fanStates.wrappedValue = states
                            }
                        }
                    )
                }
            }

            // RPM History chart — fixed at bottom of right panel
            // HTML: .chart-panel — height 108px, border-top, flex-shrink 0
            rpmHistoryChart
                .frame(height: 108)
                .overlay(alignment: .top) {
                    Rectangle().fill(FansColors.separator).frame(height: 1)
                }
        }
    }

    private func binding(forFan idx: Int) -> Binding<FanControlState> {
        Binding(
            get: {
                let states = fanStates.wrappedValue
                return states[min(idx, states.count - 1)]
            },
            set: { newVal in
                var states = fanStates.wrappedValue
                let safeIdx = min(idx, states.count - 1)
                states[safeIdx] = newVal
                fanStates.wrappedValue = states
            }
        )
    }

    // MARK: - RPM History Chart
    // HTML: .chart-panel — 108px height, canvas chart, legend header

    private var rpmHistoryChart: some View {
        VStack(spacing: 0) {
            // Header
            // HTML: .chart-header — flex, gap 12, margin-bottom 5
            HStack(spacing: 12) {
                Text("RPM HISTORY")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.0)
                    .foregroundStyle(FansColors.text3)

                // Legend: Fan 1 blue line
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(FansColors.blue)
                        .frame(width: 16, height: 2)
                    Text("Fan 1")
                        .font(.system(size: 10))
                        .foregroundStyle(FansColors.text2)
                }

                // Legend: Fan 2 orange line
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(FansColors.orange)
                        .frame(width: 16, height: 2)
                    Text("Fan 2")
                        .font(.system(size: 10))
                        .foregroundStyle(FansColors.text2)
                }

                Spacer()

                // HTML: .chart-time — margin-left auto
                Text("60s window")
                    .font(.system(size: 10))
                    .foregroundStyle(FansColors.text3)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 5)

            // Chart using Swift Charts — AreaMark + LineMark
            let allPoints = rpmHistory.flatMap { $0 }
            Chart(allPoints) { pt in
                AreaMark(
                    x: .value("Time", pt.index),
                    y: .value("RPM", pt.rpm)
                )
                .foregroundStyle(by: .value("Fan", "Fan \(pt.fanIndex + 1)"))
                .opacity(0.15)
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Time", pt.index),
                    y: .value("RPM", pt.rpm)
                )
                .foregroundStyle(by: .value("Fan", "Fan \(pt.fanIndex + 1)"))
                .lineStyle(StrokeStyle(lineWidth: 1.5))
                .interpolationMethod(.catmullRom)
            }
            .chartForegroundStyleScale([
                "Fan 1": FansColors.blue,
                "Fan 2": FansColors.orange,
            ])
            .chartXScale(domain: 0...59)
            .chartYScale(domain: 0...10000)
            .chartXAxis {
                AxisMarks(values: [0, 15, 30, 45, 59]) { val in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.05))
                    AxisValueLabel {
                        if let v = val.as(Int.self) {
                            Text(v == 59 ? "now" : "-\(59 - v)s")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.white.opacity(0.20))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(values: [0, 3300, 6600, 10000]) { v in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.05))
                    AxisValueLabel {
                        if let val = v.as(Int.self) {
                            Text("\(val / 100 * 100)")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.white.opacity(0.22))
                        }
                    }
                }
            }
            .chartLegend(.hidden)
            .chartBackground { _ in
                RoundedRectangle(cornerRadius: 5)
                    .fill(FansColors.bg)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(FansColors.bg)
    }

    // MARK: - Fan Curve Editor
    // HTML: .curve-section — border-top separator, padding 16px 20px, bg

    private var fanCurveEditor: some View {
        VStack(spacing: 0) {
            // Top row: label + preset buttons
            // HTML: .curve-top-row — flex between, margin-bottom 12
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("FAN CURVE EDITOR")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.0)
                        .foregroundStyle(FansColors.text3)
                    Text("Drag control points to customize the fan response curve")
                        .font(.system(size: 12))
                        .foregroundStyle(FansColors.text2)
                }

                Spacer()

                // HTML: .curve-presets — gap 6
                HStack(spacing: 6) {
                    presetButton("Silent", id: "silent") { applyPreset("silent") }
                    presetButton("Balanced", id: "balanced") { applyPreset("balanced") }
                    presetButton("Performance", id: "performance") { applyPreset("performance") }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Canvas curve editor
            // HTML: #curveCanvas, 100% width, 220px height, crosshair cursor, radius 8
            FanCurveCanvas(
                points: curvePoints,
                draggingPoint: $draggingPoint,
                currentTemp: peakTemp,
                activePreset: activePreset.wrappedValue,
                isActive: isVisible && curveCanvasActive
            )
            .frame(height: 220)
            .padding(.horizontal, 20)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .onAppear { curveCanvasActive = true }
            .onDisappear { curveCanvasActive = false }

            // HTML: .curve-hint — 10px, text3, center, margin-top 8
            Text("Drag the white control points  \u{00B7}  Vertical line = current temperature  \u{00B7}  Shaded band = hysteresis zone  \u{00B7}  Dashed lines = inactive presets")
                .font(.system(size: 10))
                .foregroundStyle(FansColors.text3)
                .multilineTextAlignment(.center)
                .padding(.vertical, 8)
        }
        .background(FansColors.bg)
        .overlay(alignment: .top) {
            Rectangle().fill(FansColors.separator).frame(height: 1)
        }
    }

    private func presetButton(_ label: String, id: String, action: @escaping () -> Void) -> some View {
        // HTML: .preset-btn, 5px 13px pad, radius 6, 11px 600, border separator, bg2
        let isActive = activePreset.wrappedValue == id
        return Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 13)
                .padding(.vertical, 5)
                .background(
                    isActive ? FansColors.bg3 : FansColors.bg2,
                    in: RoundedRectangle(cornerRadius: 6)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(
                            isActive
                                ? Color.white.opacity(0.18)
                                : FansColors.separator,
                            lineWidth: 1
                        )
                )
                .foregroundStyle(
                    isActive ? FansColors.text : FansColors.text2
                )
        }
        .buttonStyle(.plain)
    }

    private func applyPreset(_ preset: String) {
        activePreset.wrappedValue = preset
        withAnimation(.easeInOut(duration: 0.35)) {
            switch preset {
            case "silent":
                curvePoints.wrappedValue = [
                    CurvePoint(temperature: 30,  fanSpeed: 5),
                    CurvePoint(temperature: 45,  fanSpeed: 12),
                    CurvePoint(temperature: 60,  fanSpeed: 22),
                    CurvePoint(temperature: 75,  fanSpeed: 38),
                    CurvePoint(temperature: 100, fanSpeed: 55),
                ]
            case "performance":
                curvePoints.wrappedValue = [
                    CurvePoint(temperature: 30,  fanSpeed: 20),
                    CurvePoint(temperature: 45,  fanSpeed: 40),
                    CurvePoint(temperature: 60,  fanSpeed: 62),
                    CurvePoint(temperature: 75,  fanSpeed: 82),
                    CurvePoint(temperature: 100, fanSpeed: 100),
                ]
            default: // balanced
                curvePoints.wrappedValue = [
                    CurvePoint(temperature: 30,  fanSpeed: 8),
                    CurvePoint(temperature: 45,  fanSpeed: 18),
                    CurvePoint(temperature: 60,  fanSpeed: 35),
                    CurvePoint(temperature: 75,  fanSpeed: 58),
                    CurvePoint(temperature: 100, fanSpeed: 80),
                ]
            }
        }
    }

    // MARK: - Thermal Strip + Warning Bar
    // HTML: .thermal-section — border-top separator, bg

    private var thermalStripSection: some View {
        VStack(spacing: 0) {
            // Thermal strip
            // HTML: .thermal-strip — padding 10px 20px, flex, border-bottom separator
            HStack(spacing: 0) {
                // 6 key sensor tiles
                // HTML: cpu_die, gpu_die, nand_die, bat_cell1, ambient, wifi
                let thermalSensors: [(label: String, key: String)] = [
                    ("CPU Die",  "TC0D"),
                    ("GPU Die",  "Tg0D"),
                    ("SSD",      "TH0a"),
                    ("Battery",  "TB0T"),
                    ("Ambient",  "TA0P"),
                    ("WiFi",     "TW0P"),
                ]

                ForEach(Array(thermalSensors.enumerated()), id: \.offset) { idx, item in
                    let sensor = allTempSensors.first(where: { $0.key == item.key })
                    let val = sensor?.value ?? 0
                    let color = val > 0 ? tempColor(val) : Color(white: 0.3)

                    if idx > 0 {
                        Rectangle()
                            .fill(FansColors.separator)
                            .frame(width: 1)
                    }

                    // HTML: .thermal-sensor — flex, gap 7, padding 5px 14px, flex:1
                    HStack(spacing: 7) {
                        Circle()
                            .fill(color)
                            .frame(width: 8, height: 8)

                        VStack(alignment: .leading, spacing: 2) {
                            // HTML: .thermal-val — 13px, 700, tabular-nums
                            Text(val > 0 ? "\(Int(val))\u{00B0}C" : "\u{2014}")
                                .font(.system(size: 13, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(FansColors.text)
                            // HTML: .thermal-lbl — 9px, text3, uppercase, 0.05em
                            Text(item.label.uppercased())
                                .font(.system(size: 9))
                                .tracking(0.5)
                                .foregroundStyle(FansColors.text3)
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity)
                }

                // Peak badge
                // HTML: .peak-badge — red bg/border, padding 5px 12px, margin-left 16
                if peakTemp > 0 {
                    HStack(spacing: 6) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("PEAK")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(0.7)
                                .foregroundStyle(FansColors.red)
                            Text("\(Int(peakTemp))\u{00B0}C")
                                .font(.system(size: 14, weight: .heavy))
                                .monospacedDigit()
                                .foregroundStyle(FansColors.red)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(FansColors.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(FansColors.red.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.leading, 16)
                    .fixedSize()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(FansColors.bg)
            .overlay(alignment: .top) {
                // HTML: .thermal-section has border-top separator
                Rectangle().fill(FansColors.separator).frame(height: 1)
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(FansColors.separator).frame(height: 1)
            }

        }
    }

    // MARK: - Warning Bar
    // HTML: .warning-bar — padding 10px 20px, yellow 0.04 bg, yellow 0.10 top border

    private var warningBar: some View {
        HStack(spacing: 12) {
            Text("\u{26A0}")
                .font(.system(size: 12))

            Text("Manual control can cause overheating if set too low. Fans return to auto if app quits.")
                .font(.system(size: 11))
                .foregroundStyle(FansColors.yellow.opacity(0.75))

            Spacer()

            // HTML: .reset-btn, 6px 16px pad, radius 7, bg2, 12px 600
            Button("Reset All to Auto") {
                var states = fanStates.wrappedValue
                for i in 0..<states.count {
                    states[i].mode = .system
                    states[i].lastResult = nil
                    states[i].isBusy = false
                }
                fanStates.wrappedValue = states
                Task.detached {
                    let (ok, msg) = appState.monitor.smcReader?.resetAllFans() ?? (false, "No SMC")
                    await MainActor.run {
                        let display = ok ? "All fans reset to auto" : (msg ?? "Reset failed")
                        var states2 = fanStates.wrappedValue
                        for i in 0..<states2.count {
                            states2[i].lastResult = FanOpResult(success: ok, message: display)
                        }
                        fanStates.wrappedValue = states2
                    }
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(FansColors.bg2, in: RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(FansColors.separator, lineWidth: 1)
            )
            .foregroundStyle(FansColors.text)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(FansColors.yellow.opacity(0.04))
        .overlay(alignment: .top) {
            Rectangle().fill(FansColors.yellow.opacity(0.10)).frame(height: 1)
        }
    }

    // MARK: - Helper Status Bar

    @ViewBuilder
    private var helperStatusBar: some View {
        if appState.isHelperInstalled {
            HStack(spacing: 8) {
                Circle()
                    .fill(FansColors.green)
                    .frame(width: 7, height: 7)
                Text("Helper Active")
                    .font(.system(size: 11))
                    .foregroundStyle(FansColors.green.opacity(0.85))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(FansColors.bg2)
            .overlay(alignment: .top) {
                Rectangle().fill(FansColors.separator).frame(height: 1)
            }
        } else {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(FansColors.orange)

                Text("SMC helper not installed — showing mock data")
                    .font(.system(size: 11))
                    .foregroundStyle(FansColors.orange.opacity(0.85))

                Spacer()

                Button("Install Helper") {
                    appState.showHelperInstallPrompt = true
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(FansColors.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(FansColors.orange.opacity(0.30), lineWidth: 1)
                )
                .foregroundStyle(FansColors.orange)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(FansColors.orange.opacity(0.04))
            .overlay(alignment: .top) {
                Rectangle().fill(FansColors.orange.opacity(0.15)).frame(height: 1)
            }
        }
    }

    // MARK: - Sensor Grouping Helpers

    private static func buildDefaultGroups() -> [SensorGroup] {
        [
            SensorGroup(id: "cpu",        label: "CPU",          icon: "cpu",                color: .blue,   isExpanded: true,  sensors: []),
            SensorGroup(id: "gpu",        label: "GPU",          icon: "display",            color: .purple, isExpanded: true,  sensors: []),
            SensorGroup(id: "socdie",     label: "SoC Die",      icon: "cpu.fill",           color: .pink,   isExpanded: false, sensors: []),
            SensorGroup(id: "power",      label: "Power/DRAM",   icon: "bolt.circle",        color: .brown,  isExpanded: false, sensors: []),
            SensorGroup(id: "video",      label: "Video Engine",  icon: "play.rectangle",    color: .gray,   isExpanded: false, sensors: []),
            SensorGroup(id: "ssd",        label: "SSD",          icon: "internaldrive",      color: .cyan,   isExpanded: false, sensors: []),
            SensorGroup(id: "battery",    label: "Battery",      icon: "battery.75percent",  color: .green,  isExpanded: false, sensors: []),
            SensorGroup(id: "memory",     label: "Memory",       icon: "memorychip",         color: .teal,   isExpanded: false, sensors: []),
            SensorGroup(id: "ambient",    label: "Ambient",      icon: "thermometer.medium", color: .mint,   isExpanded: false, sensors: []),
            SensorGroup(id: "skin",       label: "Surface",      icon: "hand.raised",        color: .indigo, isExpanded: false, sensors: []),
            SensorGroup(id: "tb",         label: "Thunderbolt",  icon: "bolt.fill",          color: .yellow, isExpanded: false, sensors: []),
            SensorGroup(id: "wifi",       label: "WiFi",         icon: "wifi",               color: .orange, isExpanded: false, sensors: []),
            SensorGroup(id: "charger",    label: "Charger",      icon: "powerplug.fill",     color: .red,    isExpanded: false, sensors: []),
        ]
    }

    private func sensorsForGroup(_ group: SensorGroup) -> [SensorReading] {
        let temps = allTempSensors
        switch group.id {
        case "cpu":
            return temps.filter { $0.category == .cpuTemperature || $0.key.hasPrefix("TC") || $0.key.hasPrefix("Tp") || $0.key.hasPrefix("Te") || $0.key.hasPrefix("TfC") || $0.key.hasPrefix("TS0P") || $0.key.hasPrefix("TSCP") }
        case "gpu":
            return temps.filter { $0.category == .gpuTemperature || $0.key.hasPrefix("Tg") || $0.key.hasPrefix("TG") || $0.key.hasPrefix("TSG") }
        case "socdie":
            return temps.filter { $0.key.hasPrefix("TD") }
        case "power":
            return temps.filter { $0.key.hasPrefix("TPD") || $0.key.hasPrefix("TPM") || $0.key.hasPrefix("TPS") || $0.key.hasPrefix("TRD") || $0.key.hasPrefix("TUD") || $0.key.hasPrefix("TMV") }
        case "video":
            return temps.filter { $0.key.hasPrefix("TV") }
        case "ssd":
            return temps.filter { $0.category == .driveTemperature || $0.key.hasPrefix("TH") || $0.name.lowercased().contains("nand") || $0.name.lowercased().contains("ssd") }
        case "battery":
            return temps.filter { $0.category == .batteryTemperature || $0.key.hasPrefix("TB") }
        case "memory":
            return temps.filter { $0.key.hasPrefix("Tm") || $0.name.lowercased().contains("memory") }
        case "ambient":
            return temps.filter { $0.category == .ambientTemperature || $0.key.hasPrefix("TA") || $0.key.hasPrefix("Ta") || $0.name.lowercased().contains("ambient") }
        case "skin":
            return temps.filter { $0.category == .skinTemperature || $0.key.hasPrefix("Ts") || $0.name.lowercased().contains("palm") || $0.name.lowercased().contains("wrist") }
        case "tb":
            return temps.filter { $0.key.hasPrefix("Tt") || $0.name.lowercased().contains("thunderbolt") || $0.name.lowercased().contains("tb ") }
        case "wifi":
            return temps.filter { $0.key.hasPrefix("TW") || $0.name.lowercased().contains("wifi") || $0.name.lowercased().contains("wireless") }
        case "charger":
            return temps.filter { $0.key.hasPrefix("TF") || $0.name.lowercased().contains("charger") || $0.name.lowercased().contains("pd controller") }
        default:
            return []
        }
    }

    private func syncSensorGroups() {
        for i in sensorGroups.indices {
            sensorGroups[i].sensors = sensorsForGroup(sensorGroups[i])
        }
    }

    // MARK: - Timers

    private func startTimers() {
        // Prevent duplicate timers if onAppear fires multiple times
        stopTimers()
        fanSpinStartDate = Date()

        // Seed RPM history
        let fanCount = max(fans.count, 2)
        while rpmHistory.count < fanCount { rpmHistory.append([]) }
        for i in 0..<fanCount {
            if rpmHistory[i].isEmpty {
                let baseRPM = fans[safe: i].map { Double($0.rpm) } ?? 0
                rpmHistory[i] = (0..<60).map { idx in
                    RPMPoint(index: idx, rpm: baseRPM + Double.random(in: -200...200), fanIndex: i)
                }
            }
        }

        // 2s timer: update RPM history
        historyTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            let currentFans = displayFans
            historyIndex = (historyIndex + 1) % 60

            for i in 0..<currentFans.count {
                while rpmHistory.count <= i { rpmHistory.append([]) }
                let rpm = Double(currentFans[i].rpm)
                if rpmHistory[i].count > 59 {
                    rpmHistory[i].removeFirst()
                }
                let nextIndex = (rpmHistory[i].last?.index ?? -1) + 1
                rpmHistory[i].append(RPMPoint(index: nextIndex, rpm: rpm, fanIndex: i))
            }
        }
        RunLoop.main.add(historyTimer!, forMode: .common)

        // 5s timer: evaluate Auto Boost rules and issue XPC fan-speed commands
        boostTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            guard appState.isHelperInstalled else { return }
            evaluateAutoBoostRules()
        }
        RunLoop.main.add(boostTimer!, forMode: .common)
    }

    private func stopTimers() {
        historyTimer?.invalidate()
        historyTimer = nil
        boostTimer?.invalidate()
        boostTimer = nil
    }

    // MARK: - Power Source Observer
    // Simple 2s poll of IOPSCopyPowerSourcesInfo, chosen over IOPS notification
    // CFRunLoopSource for reliability (spec preference: reliable over clever).

    private func startPowerSourceObserver() {
        stopPowerSourceObserver()
        powerSourceObserver = Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                let live = currentPowerSource()
                if live != profile {
                    profile = live
                }
            }
    }

    private func stopPowerSourceObserver() {
        powerSourceObserver?.cancel()
        powerSourceObserver = nil
    }

    // MARK: - Auto Boost Engine

    /// Evaluate each fan's Auto Boost rules against current sensor readings and
    /// issue setFanSpeed XPC calls when a threshold is exceeded.
    private func evaluateAutoBoostRules() {
        let sensors = allTempSensors
        let currentFans = displayFans
        let states = fanStates.wrappedValue

        for (fanIdx, fan) in currentFans.enumerated() {
            guard fanIdx < states.count, states[fanIdx].mode == .autoBoost else { continue }
            let rules = states[fanIdx].boostRules

            // Find the highest applicable rule (highest speedPct whose threshold is exceeded)
            var targetPct: Int? = nil
            for rule in rules.sorted(by: { $0.speedPct > $1.speedPct }) {
                // Match sensor by name (case-insensitive prefix)
                let matchName = rule.sensor.lowercased()
                let sensorValue: Double?
                if matchName == "any sensor" {
                    sensorValue = sensors.map(\.value).max()
                } else {
                    sensorValue = sensors.first(where: {
                        $0.name.lowercased().hasPrefix(String(matchName.prefix(6)))
                    })?.value
                }
                guard let temp = sensorValue else { continue }

                // Check which fans this rule targets
                let targetsFan: Bool
                switch rule.fanTarget {
                case "Fan 1+2": targetsFan = true
                case "Fan 1":   targetsFan = fanIdx == 0
                case "Fan 2":   targetsFan = fanIdx == 1
                default:        targetsFan = true
                }
                guard targetsFan else { continue }

                if temp >= Double(rule.thresholdC) {
                    targetPct = rule.speedPct
                    break   // highest matching rule wins
                }
            }

            // Apply the computed speed (or reset to auto if no rule fires)
            if let pct = targetPct {
                let rpm = fan.minRPM + Int(Double(fan.maxRPM - fan.minRPM) * Double(pct) / 100.0)
                var mutableStates = fanStates.wrappedValue
                if fanIdx < mutableStates.count {
                    mutableStates[fanIdx].isBusy = true
                    fanStates.wrappedValue = mutableStates
                }
                Task {
                    let (ok, err) = await appState.xpc.setFanSpeed(fanIndex: fanIdx, rpm: rpm)
                    var latest = fanStates.wrappedValue
                    if fanIdx < latest.count {
                        latest[fanIdx].isBusy = false
                        latest[fanIdx].lastResult = FanOpResult(
                            success: ok,
                            message: ok
                                ? "Boost \(pct)% \u{2192} \(rpm) RPM"
                                : (err ?? "Boost failed")
                        )
                        fanStates.wrappedValue = latest
                    }
                }
            } else {
                // No rule firing, ensure fan is in auto
                Task { _ = await appState.xpc.resetFan(fanIndex: fanIdx) }
            }
        }
    }

    // MARK: - Fan State Sync

    /// Sync per-fan control states from real fan readings (clamps manualRPM into valid range).
    /// Also ensures fanStates covers all displayFans (including mock fallback).
    /// Applies to BOTH profiles so switching AC to Battery never lands on a too-short array.
    private func syncFanStatesFromData() {
        let currentFans = displayFans
        var dict = profileSettings
        var changed = false
        for profileID in ["ac", "bat"] {
            var s = dict[profileID] ?? settings(for: profileID)
            // Ensure fanStates has entries for every display fan (including mock)
            while s.fanStates.count < currentFans.count {
                s.fanStates.append(FanControlState())
                changed = true
            }
            // Clamp existing manualRPM into each fan's valid range
            for (i, fan) in currentFans.enumerated() {
                guard fan.maxRPM > fan.minRPM, i < s.fanStates.count else { continue }
                let clamped = s.fanStates[i].manualRPM.clamped(to: Double(fan.minRPM)...Double(fan.maxRPM))
                if s.fanStates[i].manualRPM != clamped {
                    s.fanStates[i].manualRPM = clamped
                    changed = true
                }
            }
            dict[profileID] = s
        }
        if changed {
            profileSettings = dict
            Self.persistProfileSettings(dict)
        }
    }

    // MARK: - Utilities

    private static let rpmFormatter: NumberFormatter = {
        let n = NumberFormatter()
        n.numberStyle = .decimal
        return n
    }()

    private func formatRPM(_ rpm: Int) -> String {
        Self.rpmFormatter.string(from: rpm as NSNumber) ?? "\(rpm)"
    }

    private func estimatedDBA(rpm: Int, maxRPM: Int) -> Int {
        // HTML: 30 + (rpm / maxRPM) * 35
        return Int(30 + (Double(rpm) / max(Double(maxRPM), 1)) * 35)
    }
}

// MARK: - Sensor Group Section (collapsible)
// HTML: .sensor-group-header + .sensor-group-body

private struct SensorGroupSection: View {
    @Binding var group: SensorGroup
    let sensors: [SensorReading]
    let tempColor: (Double) -> Color

    private var peakTemp: Double {
        sensors.map(\.value).max() ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            // Group header
            // HTML: .sensor-group-header — flex, gap 7, padding 6px 16px 5px, bg 0.025
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    group.isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 7) {
                    // Chevron
                    // HTML: .group-chevron — 10x10, rotates 90deg when open
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(FansColors.text3)
                        .frame(width: 10, height: 10)
                        .rotationEffect(.degrees(group.isExpanded ? 90 : 0))

                    // Group name
                    // HTML: .group-name — 10px, 700, 0.07em, uppercase, text3
                    Text(group.label.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.9)
                        .foregroundStyle(FansColors.text3)

                    Spacer()

                    // Sensor count badge
                    // HTML: .group-count — 9px, 600, bg 0.06, padding 1px 5px, radius 3
                    if !sensors.isEmpty {
                        Text("\(sensors.count)")
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 3))
                            .foregroundStyle(FansColors.text3)

                        // Peak temp
                        // HTML: .group-peak-temp — 10px, tabular-nums, 600
                        if peakTemp > 0 {
                            Text("\(Int(peakTemp))\u{00B0}C")
                                .font(.system(size: 10, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(tempColor(peakTemp))
                        }
                    } else {
                        Text("No data")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.white.opacity(0.25))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 5)
                .background(Color.white.opacity(0.025))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // HTML: border-top + border-bottom 1px solid 0.05
            .overlay(alignment: .top) {
                Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1)
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1)
            }

            // Expanded body: column headers + sensor rows
            if group.isExpanded && !sensors.isEmpty {
                VStack(spacing: 0) {
                    // Column headers
                    // HTML: .temp-col-headers — grid 1fr 48px 56px 44px, 9px 600 uppercase text3
                    HStack(spacing: 0) {
                        Text("SENSOR")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("TEMP")
                            .frame(width: 48, alignment: .trailing)
                        Text("BAR")
                            .frame(width: 56, alignment: .leading)
                            .padding(.leading, 4)
                        Text("TREND")
                            .frame(width: 44, alignment: .trailing)
                    }
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.7)
                    .foregroundStyle(FansColors.text3)
                    .textCase(.uppercase)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.015))
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Color.white.opacity(0.04)).frame(height: 1)
                    }

                    ForEach(sensors) { sensor in
                        SensorRow(sensor: sensor, tempColor: tempColor)
                    }
                }
            } else if group.isExpanded && sensors.isEmpty {
                Text("No sensors in this group")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.25))
                    .padding(.vertical, 8)
                    .padding(.leading, 32)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Sensor Row
// HTML: .temp-row — grid 1fr 48px 56px 44px, padding 5px 16px

private struct SensorRow: View {
    let sensor: SensorReading
    let tempColor: (Double) -> Color

    /// Tooltip text derived from SMCReader's appleSiliconTempKeys lookup
    private var tooltipText: String {
        SMCReader.appleSiliconTempKeys.first(where: { $0.key == sensor.key })?.name ?? sensor.name
    }

    var body: some View {
        HStack(spacing: 0) {
            // Name + SMC key
            // HTML: .sensor-name-wrap — flex, gap 7
            HStack(spacing: 7) {
                // Status dot — 6px
                Circle()
                    .fill(tempColor(sensor.value))
                    .frame(width: 6, height: 6)

                VStack(alignment: .leading, spacing: 1) {
                    // HTML: .sensor-name — 11px, text
                    HStack(spacing: 4) {
                        Text(sensor.name)
                            .font(.system(size: 11))
                            .foregroundStyle(FansColors.text)
                            .lineLimit(1)
                        Image(systemName: "info.circle")
                            .font(.system(size: 9))
                            .foregroundStyle(FansColors.text3)
                            .help(tooltipText)
                    }
                    // HTML: .sensor-sub — 9px, text3, monospace
                    Text(sensor.key)
                        .font(.system(size: 9, design: .monospaced))
                        .tracking(0.1)
                        .foregroundStyle(FansColors.text3)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Current value
            // HTML: .temp-val — 11px, 500, tabular-nums, right aligned
            Text("\(Int(sensor.value))\u{00B0}C")
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(tempColor(sensor.value))
                .frame(width: 48, alignment: .trailing)

            // Temperature bar with peak marker
            // HTML: .temp-bar-cell — 56px area
            ZStack(alignment: .leading) {
                // Track — 3px height, radius 2
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 3)

                // Fill bar
                GeometryReader { barGeo in
                    let pct = min(sensor.value / 105.0, 1.0)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(tempColor(sensor.value))
                        .frame(width: max(3, barGeo.size.width * pct), height: 3)

                    // Peak marker — 2px wide, 7px tall
                    let peakPct = min(sensor.maxRecorded / 105.0, 1.0)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color.white.opacity(0.45))
                        .frame(width: 2, height: 7)
                        .offset(x: barGeo.size.width * peakPct - 1, y: -2)
                }
                .frame(height: 3)
            }
            .frame(width: 52)
            .padding(.leading, 4)

            // Sparkline placeholder (small colored line)
            // HTML: .temp-spark — 38x16 canvas sparkline
            FanSensorSparkline(value: sensor.value, maxRecorded: sensor.maxRecorded, color: tempColor(sensor.value))
                .frame(width: 38, height: 16)
                .frame(width: 44, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 5)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.03)).frame(height: 1)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Sparkline View (mini trend line)

private struct FanSensorSparkline: View {
    let value: Double
    let maxRecorded: Double
    let color: Color

    var body: some View {
        Canvas { ctx, size in
            // Draw a small representative sparkline with some variance around the current value
            let points = 10
            let baseVal = value
            var path = Path()
            let minV = max(baseVal - 8, 0)
            let maxV = baseVal + 8
            let range = max(maxV - minV, 1)

            for i in 0..<points {
                let x = CGFloat(i) / CGFloat(points - 1) * size.width
                // Simple deterministic wave pattern
                let offset = sin(Double(i) * 0.8 + baseVal * 0.1) * 4
                let v = baseVal + offset
                let y = size.height - ((v - minV) / range) * size.height
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            ctx.stroke(path, with: .color(color), lineWidth: 1.2)
        }
    }
}

// MARK: - Fan Control Section
// HTML: .fan-section — padding 14px 18px 12px, border-bottom separator

private struct FanControlSection: View {
    let fan: FanReading
    @Binding var state: FanControlState
    let fanIndex: Int
    let xpc: XPCClient
    let isHelperInstalled: Bool
    let smcReader: SMCReader?
    let onModeChange: (FanMode) -> Void

    // Fan control availability is determined by the helper daemon via SMC probing.
    // On Apple Silicon, the Ftst unlock sequence enables writes that were previously
    // blocked. The helper reports `manualControlSupported` in readFanData().

    private var rpmPercent: Double {
        guard fan.maxRPM > fan.minRPM else { return 0 }
        return Double(fan.rpm - fan.minRPM) / Double(fan.maxRPM - fan.minRPM)
    }

    private func rpmColor() -> Color {
        let pct = Double(fan.rpm) / max(Double(fan.maxRPM), 1)
        if pct < 0.55 { return FansColors.green }
        if pct < 0.78 { return FansColors.orange }
        return FansColors.red
    }

    private func applyManualRPM() {
        guard state.mode == .manual else { return }
        let rpm = Int(state.manualRPM)
        state.isBusy = true

        // SMC writes require root on Apple Silicon — always use the privileged
        // XPC helper (runs as root) rather than the app-process SMCReader.
        Task {
            let (ok, err) = await xpc.setFanSpeed(fanIndex: fanIndex, rpm: rpm)
            state.isBusy = false
            state.lastResult = FanOpResult(
                success: ok,
                message: ok ? "Fan \(fanIndex + 1) \u{2192} \(rpm) RPM" : (err ?? "Failed")
            )
        }
    }

    private func applyMode(_ mode: FanMode) {
        state.isBusy = true

        // SMC writes require root on Apple Silicon — always use the privileged
        // XPC helper rather than the app-process SMCReader.
        Task {
            let (ok, err): (Bool, String?)
            switch mode {
            case .system, .autoBoost:
                (ok, err) = await xpc.resetFan(fanIndex: fanIndex)
            case .manual:
                (ok, err) = await xpc.setFanSpeed(fanIndex: fanIndex, rpm: Int(state.manualRPM))
            case .min:
                let minRPM = fan.minRPM
                (ok, err) = await xpc.setFanSpeed(fanIndex: fanIndex, rpm: minRPM)
                if ok { state.manualRPM = Double(minRPM) }
            case .mid:
                let midRPM = (fan.minRPM + fan.maxRPM) / 2
                (ok, err) = await xpc.setFanSpeed(fanIndex: fanIndex, rpm: midRPM)
                if ok { state.manualRPM = Double(midRPM) }
            case .max:
                let maxRPM = fan.maxRPM
                (ok, err) = await xpc.setFanSpeed(fanIndex: fanIndex, rpm: maxRPM)
                if ok { state.manualRPM = Double(maxRPM) }
            }
            state.isBusy = false
            if !ok {
                state.lastResult = FanOpResult(success: false, message: err ?? "XPC error")
            } else {
                let label: String
                switch mode {
                case .min: label = "Fan \(fanIndex + 1) \u{2192} Min (\(fan.minRPM) RPM)"
                case .mid: label = "Fan \(fanIndex + 1) \u{2192} Mid (\((fan.minRPM + fan.maxRPM) / 2) RPM)"
                case .max: label = "Fan \(fanIndex + 1) \u{2192} Max (\(fan.maxRPM) RPM)"
                default: label = ""
                }
                state.lastResult = label.isEmpty ? nil : FanOpResult(success: true, message: label)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: Fan name + RPM + %
            // HTML: .fan-section-header — flex, baseline, gap 8, margin-bottom 10
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                // HTML: .fan-label — 10px 600 0.08em uppercase text2
                Text(fan.name.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.0)
                    .foregroundStyle(FansColors.text2)

                // HTML: .fan-rpm-big-sec — 26px 300 tabular-nums -0.02em
                Text(fan.rpm > 0
                     ? NumberFormatter.localizedString(from: fan.rpm as NSNumber, number: .decimal)
                     : "\u{2014}")
                    .font(.system(size: 26, weight: .light))
                    .monospacedDigit()
                    .tracking(-0.5)
                    .foregroundStyle(FansColors.text)

                // HTML: .fan-rpm-unit — 11px text2
                Text("RPM")
                    .font(.system(size: 11))
                    .foregroundStyle(FansColors.text2)

                Spacer()

                // HTML: .fan-rpm-pct — 11px text2 right
                Text(fan.rpm > 0 ? String(format: "%.0f%%", rpmPercent * 100) : "\u{2014}")
                    .font(.system(size: 11))
                    .foregroundStyle(FansColors.text2)
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // RPM range bar
            // HTML: .rpm-bar-wrap
            VStack(spacing: 3) {
                // Labels: min / current / max
                HStack {
                    Text(formatRPM(fan.minRPM))
                        .font(.system(size: 10))
                        .monospacedDigit()
                        .foregroundStyle(FansColors.text3)
                    Spacer()
                    Text(fan.rpm > 0 ? "\(formatRPM(fan.rpm)) RPM" : "\u{2014}")
                        .font(.system(size: 10))
                        .monospacedDigit()
                        .foregroundStyle(FansColors.text3)
                    Spacer()
                    Text(formatRPM(fan.maxRPM))
                        .font(.system(size: 10))
                        .monospacedDigit()
                        .foregroundStyle(FansColors.text3)
                }

                // Gradient bar
                // HTML: .rpm-bar-track — 6px, radius 3, overflow hidden
                // HTML: .rpm-bar-fill — gradient green->green->yellow->orange->red
                GeometryReader { barGeo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(rpmColor().opacity(0.85))
                            .frame(width: max(8, CGFloat(rpmPercent) * barGeo.size.width), height: 6)
                            .animation(.smooth(duration: 0.5), value: rpmPercent)
                    }
                }
                .frame(height: 6)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 10)

            // Mode selector (segmented)
            HStack(spacing: 0) {
                modeButton("System",     mode: .system)
                modeButton("Manual",     mode: .manual)
                modeButton("Auto Boost", mode: .autoBoost)
                modeButton("Min",        mode: .min)
                modeButton("Mid",        mode: .mid)
                modeButton("Max",        mode: .max)
            }
            .padding(2)
            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(FansColors.separator, lineWidth: 1)
            )
            .fixedSize()
            .padding(.horizontal, 18)
            .padding(.bottom, 10)

            // Conditional panel
            Group {
                switch state.mode {
                case .system:
                    systemModeNote
                case .manual:
                    manualPanel
                case .autoBoost:
                    autoBoostRuleTable
                case .min:
                    presetModeNote(preset: .min)
                case .mid:
                    presetModeNote(preset: .mid)
                case .max:
                    presetModeNote(preset: .max)
                }
            }
            .padding(.bottom, 12)
        }
        // HTML: .fan-section — border-bottom separator
        .overlay(alignment: .bottom) {
            Rectangle().fill(FansColors.separator).frame(height: 1)
        }
    }

    private static let rpmFormatter: NumberFormatter = {
        let n = NumberFormatter()
        n.numberStyle = .decimal
        return n
    }()

    private func formatRPM(_ rpm: Int) -> String {
        Self.rpmFormatter.string(from: rpm as NSNumber) ?? "\(rpm)"
    }

    // HTML: .mode-btn — 24px height, padding 0 12px, radius 4, 11px 500
    private func modeButton(_ label: String, mode: FanMode) -> some View {
        Button {
            state.mode = mode
            onModeChange(mode)
            applyMode(mode)
        } label: {
            HStack(spacing: 5) {
                // Radio circle
                // HTML: .mode-radio — 8x8, border 1.5px, inner 4px dot when active
                ZStack {
                    Circle()
                        .stroke(
                            state.mode == mode ? FansColors.blue : Color.white.opacity(0.4),
                            lineWidth: 1.5
                        )
                        .frame(width: 8, height: 8)
                    if state.mode == mode {
                        Circle()
                            .fill(FansColors.blue)
                            .frame(width: 4, height: 4)
                    }
                }
                .opacity(state.mode == mode ? 1 : 0.6)

                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 12)
            .frame(height: 24)
            .background(
                state.mode == mode
                    ? Color.white.opacity(0.12)
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: 4)
            )
            .foregroundStyle(
                state.mode == mode ? FansColors.text : FansColors.text2
            )
        }
        .buttonStyle(.plain)
    }

    private func presetModeNote(preset: FanMode) -> some View {
        let rpm: Int
        let label: String
        let icon: String
        let color: Color
        switch preset {
        case .min:
            rpm = fan.minRPM; label = "minimum"; icon = "wind"; color = FansColors.blue
        case .mid:
            rpm = (fan.minRPM + fan.maxRPM) / 2; label = "mid"; icon = "gauge.with.dots.needle.50percent"; color = FansColors.orange
        default:
            rpm = fan.maxRPM; label = "maximum"; icon = "flame.fill"; color = FansColors.red
        }

        return HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(fan.name) locked to \(label) speed (\(formatRPM(rpm)) RPM)")
                    .font(.system(size: 11))
                    .foregroundStyle(FansColors.text2)
                if let result = state.lastResult, result.success {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(FansColors.green)
                        Text(result.message)
                            .font(.system(size: 10))
                            .foregroundStyle(FansColors.text3)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 7))
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(FansColors.separator, lineWidth: 1)
        )
        .padding(.horizontal, 18)
    }

    // HTML: .system-mode-note — padding 8px 12px, bg 0.03, border separator, radius 7, 11px text2
    private var systemModeNote: some View {
        HStack(spacing: 7) {
            Image(systemName: "info.circle")
                .font(.system(size: 13))
                .foregroundStyle(FansColors.text3)
            Text("macOS controls fan speed automatically. \(fan.name) follows system thermal policy.")
                .font(.system(size: 11))
                .foregroundStyle(FansColors.text2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 7))
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(FansColors.separator, lineWidth: 1)
        )
        .padding(.horizontal, 18)
    }

    // HTML: .manual-panel — padding 10px 12px, bg2, border separator, radius 7
    private var manualPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            // HTML: .manual-label-row — flex between
            HStack {
                Text("Target Speed")
                    .font(.system(size: 11))
                    .foregroundStyle(FansColors.text2)
                Spacer()
                // HTML: .manual-val — 13px, 500, tabular-nums, text
                Text("\(formatRPM(Int(state.manualRPM))) RPM")
                    .font(.system(size: 13, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(FansColors.text)
            }

            Slider(
                value: $state.manualRPM,
                in: Double(max(fan.minRPM, 1))...Double(max(fan.maxRPM, max(fan.minRPM, 1) + 100)),
                step: 100
            ) { editing in
                if !editing { applyManualRPM() }
            }
            .tint(FansColors.blue)
            .disabled(state.isBusy)

            // HTML: .slider-endpoints — flex between, 10px text3
            HStack {
                Text("\(formatRPM(fan.minRPM)) RPM (min)")
                    .font(.system(size: 10))
                    .monospacedDigit()
                    .foregroundStyle(FansColors.text3)
                Spacer()
                Text("\(formatRPM(fan.maxRPM)) RPM (max)")
                    .font(.system(size: 10))
                    .monospacedDigit()
                    .foregroundStyle(FansColors.text3)
            }

            // XPC status badge
            if let result = state.lastResult {
                HStack(spacing: 5) {
                    Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(result.success ? FansColors.green : FansColors.red)
                    Text(result.message)
                        .font(.system(size: 10))
                        .foregroundStyle(result.success ? FansColors.green.opacity(0.9) : FansColors.red.opacity(0.9))
                        .lineLimit(1)
                    Spacer()
                }
            } else if state.isBusy {
                HStack(spacing: 5) {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 14, height: 14)
                    Text("Applying\u{2026}")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.45))
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(FansColors.bg2, in: RoundedRectangle(cornerRadius: 7))
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(FansColors.separator, lineWidth: 1)
        )
        .padding(.horizontal, 18)
    }

    // MARK: - Auto Boost Rule Table
    // HTML: .auto-boost-panel — rule-table-header grid 86px 58px 1fr 82px 24px

    private var autoBoostRuleTable: some View {
        VStack(spacing: 0) {
            // Column headers
            HStack(spacing: 0) {
                Text("FAN")
                    .frame(width: 86, alignment: .leading)
                Text("SPEED%")
                    .frame(width: 58, alignment: .leading)
                Text("SENSOR")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("WHEN ABOVE")
                    .frame(width: 82, alignment: .leading)
                Spacer().frame(width: 24)
            }
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.7)
            .foregroundStyle(FansColors.text3)
            .textCase(.uppercase)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .overlay(alignment: .bottom) {
                Rectangle().fill(FansColors.separator).frame(height: 1)
            }

            // Rule rows
            ForEach($state.boostRules) { $rule in
                RuleRow(rule: $rule) {
                    state.boostRules.removeAll { $0.id == rule.id }
                }
            }

            // Add Rule button
            // HTML: .add-rule-row — padding 8px 8px 4px
            HStack {
                Button {
                    state.boostRules.append(
                        FanBoostRule(fanTarget: "Fan 1+2", speedPct: 50, sensor: "CPU Die", thresholdC: 70)
                    )
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Add Rule")
                            .font(.system(size: 11))
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 22)
                    .background(FansColors.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(FansColors.blue.opacity(0.25), lineWidth: 1)
                    )
                    .foregroundStyle(FansColors.blue)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 4)
        }
        .background(Color.white.opacity(0.02), in: RoundedRectangle(cornerRadius: 7))
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(FansColors.separator, lineWidth: 1)
        )
        .padding(.horizontal, 18)
    }
}

// MARK: - Rule Row
// HTML: .rule-row — grid 86px 58px 1fr 82px 24px, padding 5px 0 5px 8px

private struct RuleRow: View {
    @Binding var rule: FanBoostRule
    let onDelete: () -> Void

    private let fanTargetOptions = ["Fan 1", "Fan 2", "Fan 1+2"]
    private let sensorOptions    = ["CPU Die", "CPU Proximity", "GPU Die", "Battery", "Ambient", "NAND Die", "Any Sensor"]

    var body: some View {
        HStack(spacing: 4) {
            // Fan target picker
            Picker("", selection: $rule.fanTarget) {
                ForEach(fanTargetOptions, id: \.self) { Text($0).tag($0) }
            }
            .labelsHidden()
            .font(.system(size: 11))
            .frame(width: 78)
            .fixedSize()

            // Speed % field
            HStack(spacing: 2) {
                TextField("", value: $rule.speedPct, format: .number)
                    .font(.system(size: 11, design: .monospaced))
                    .multilineTextAlignment(.trailing)
                    .frame(width: 30)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
                    .foregroundStyle(FansColors.text)
                Text("%")
                    .font(.system(size: 10))
                    .foregroundStyle(FansColors.text3)
            }
            .frame(width: 54, alignment: .leading)

            // Sensor picker
            Picker("", selection: $rule.sensor) {
                ForEach(sensorOptions, id: \.self) { Text($0).tag($0) }
            }
            .labelsHidden()
            .font(.system(size: 11))
            .frame(maxWidth: .infinity)

            // Threshold field
            HStack(spacing: 2) {
                TextField("", value: $rule.thresholdC, format: .number)
                    .font(.system(size: 11, design: .monospaced))
                    .multilineTextAlignment(.trailing)
                    .frame(width: 36)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
                    .foregroundStyle(FansColors.text)
                Text("\u{00B0}C")
                    .font(.system(size: 10))
                    .foregroundStyle(FansColors.text3)
            }
            .frame(width: 62, alignment: .leading)

            // Delete button
            // HTML: .rule-del-btn — 18x18 circle, red bg 0.15, red text
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 18, height: 18)
                    .background(FansColors.red.opacity(0.15), in: Circle())
                    .foregroundStyle(FansColors.red)
            }
            .buttonStyle(.plain)
            .opacity(0.55)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.04)).frame(height: 1)
        }
    }
}

// MARK: - Fan Curve Canvas
// HTML: #curveCanvas — full width, 220px, crosshair, radius 8
// Features: bezier curve, 6 draggable points, hysteresis band, live temp cursor, ghost presets

private struct FanCurveCanvas: View {
    @Binding var points: [CurvePoint]
    @Binding var draggingPoint: UUID?
    let currentTemp: Double
    let activePreset: String
    var isActive: Bool = true

    private let chartPad = EdgeInsets(top: 24, leading: 50, bottom: 36, trailing: 20)

    // HTML preset values for ghost curves
    private let presets: [(key: String, pts: [[Double]], color: Color, dash: [CGFloat])] = [
        ("silent",      [[30, 5], [45, 12], [60, 22], [75, 38], [100, 55]],
         Color.white.opacity(0.18), [4, 4]),
        ("balanced",    [[30, 8], [45, 18], [60, 35], [75, 58], [100, 80]],
         FansColors.blue.opacity(0.22), [3, 3]),
        ("performance", [[30, 20], [45, 40], [60, 62], [75, 82], [100, 100]],
         FansColors.red.opacity(0.22), [3, 3]),
    ]

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: nil, paused: !isActive)) { timeline in
                let elapsed = timeline.date.timeIntervalSinceReferenceDate
                let pulsePhase = elapsed * 2.0   // ~2 cycles/sec
                let pulse = 0.5 + 0.5 * sin(pulsePhase)

                ZStack {
                    Canvas { ctx, size in
                        let pad = chartPad
                        let chartW = size.width - pad.leading - pad.trailing
                        let chartH = size.height - pad.top - pad.bottom

                        func tempToX(_ t: Double) -> CGFloat {
                            pad.leading + CGFloat((t - 30) / 70) * chartW
                        }
                        func speedToY(_ s: Double) -> CGFloat {
                            pad.top + CGFloat(1 - s / 100) * chartH
                        }

                        // Background
                        ctx.fill(
                            Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 8),
                            with: .color(FansColors.bg)
                        )

                        // Grid lines
                        // HTML: vertical at 30,40,50,...,100 and horizontal at 0,25,50,75,100
                        for t in stride(from: 30.0, through: 100.0, by: 10.0) {
                            let x = tempToX(t)
                            var path = Path()
                            path.move(to: CGPoint(x: x, y: pad.top))
                            path.addLine(to: CGPoint(x: x, y: size.height - pad.bottom))
                            ctx.stroke(path, with: .color(.white.opacity(0.05)), lineWidth: 1)
                        }
                        for s in stride(from: 0.0, through: 100.0, by: 25.0) {
                            let y = speedToY(s)
                            var path = Path()
                            path.move(to: CGPoint(x: pad.leading, y: y))
                            path.addLine(to: CGPoint(x: size.width - pad.trailing, y: y))
                            ctx.stroke(path, with: .color(.white.opacity(0.05)), lineWidth: 1)
                        }

                        // Axis labels — Temperature (bottom)
                        for t in stride(from: 30.0, through: 100.0, by: 10.0) {
                            let x = tempToX(t)
                            ctx.draw(
                                Text("\(Int(t))\u{00B0}")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.white.opacity(0.28)),
                                at: CGPoint(x: x, y: size.height - 8)
                            )
                        }
                        // Speed (left)
                        for s in stride(from: 0.0, through: 100.0, by: 25.0) {
                            let y = speedToY(s)
                            ctx.draw(
                                Text("\(Int(s))%")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.white.opacity(0.28)),
                                at: CGPoint(x: pad.leading - 18, y: y)
                            )
                        }

                        // Axis titles
                        ctx.draw(
                            Text("Temperature (\u{00B0}C)")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.white.opacity(0.20)),
                            at: CGPoint(x: size.width / 2, y: size.height - 1)
                        )
                        // Vertical axis title: "Fan Speed (%)" rotated -90deg on left side
                        ctx.drawLayer { inner in
                            inner.translateBy(x: 12, y: size.height / 2)
                            inner.rotate(by: Angle(degrees: -90))
                            inner.draw(
                                Text("Fan Speed (%)")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Color.white.opacity(0.20)),
                                at: .zero
                            )
                        }

                        // Ghost preset curves (dashed) — skip active preset
                        for preset in presets {
                            if preset.key == activePreset { continue }
                            let presetPts = preset.pts
                            ctx.drawLayer { inner in
                                var gPath = Path()
                                gPath.move(to: CGPoint(x: tempToX(presetPts[0][0]), y: speedToY(presetPts[0][1])))
                                for i in 1..<presetPts.count {
                                    let x0 = tempToX(presetPts[i-1][0])
                                    let y0 = speedToY(presetPts[i-1][1])
                                    let x1 = tempToX(presetPts[i][0])
                                    let y1 = speedToY(presetPts[i][1])
                                    gPath.addCurve(
                                        to: CGPoint(x: x1, y: y1),
                                        control1: CGPoint(x: (x0 + x1) / 2, y: y0),
                                        control2: CGPoint(x: (x0 + x1) / 2, y: y1)
                                    )
                                }
                                inner.stroke(
                                    gPath,
                                    with: .color(preset.color),
                                    style: StrokeStyle(lineWidth: 1.5, dash: preset.dash)
                                )
                            }
                        }

                        // Hysteresis band
                        let sortedPts = points.sorted { $0.temperature < $1.temperature }
                        guard !sortedPts.isEmpty else { return }
                        let hysteresis: CGFloat = 3
                        let shift = CGFloat(hysteresis / 70) * chartW

                        var bandPath = Path()
                        bandPath.move(to: CGPoint(x: tempToX(sortedPts[0].temperature) - shift, y: speedToY(sortedPts[0].fanSpeed)))
                        for i in 1..<sortedPts.count {
                            let x0 = tempToX(sortedPts[i-1].temperature) - shift
                            let y0 = speedToY(sortedPts[i-1].fanSpeed)
                            let x1 = tempToX(sortedPts[i].temperature) - shift
                            let y1 = speedToY(sortedPts[i].fanSpeed)
                            bandPath.addCurve(to: CGPoint(x: x1, y: y1),
                                              control1: CGPoint(x: (x0+x1)/2, y: y0),
                                              control2: CGPoint(x: (x0+x1)/2, y: y1))
                        }
                        for i in stride(from: sortedPts.count - 1, through: 0, by: -1) {
                            let x1 = tempToX(sortedPts[i].temperature) + shift
                            let y1 = speedToY(sortedPts[i].fanSpeed)
                            if i == sortedPts.count - 1 {
                                bandPath.addLine(to: CGPoint(x: x1, y: y1))
                            } else {
                                let x0 = tempToX(sortedPts[i+1].temperature) + shift
                                let y0 = speedToY(sortedPts[i+1].fanSpeed)
                                bandPath.addCurve(to: CGPoint(x: x1, y: y1),
                                                  control1: CGPoint(x: (x0+x1)/2, y: y0),
                                                  control2: CGPoint(x: (x0+x1)/2, y: y1))
                            }
                        }
                        bandPath.closeSubpath()
                        ctx.fill(bandPath, with: .color(FansColors.blue.opacity(0.07)))

                        // Main curve area fill
                        var curvePath = Path()
                        curvePath.move(to: CGPoint(x: tempToX(sortedPts[0].temperature), y: speedToY(sortedPts[0].fanSpeed)))
                        for i in 1..<sortedPts.count {
                            let x0 = tempToX(sortedPts[i-1].temperature)
                            let y0 = speedToY(sortedPts[i-1].fanSpeed)
                            let x1 = tempToX(sortedPts[i].temperature)
                            let y1 = speedToY(sortedPts[i].fanSpeed)
                            curvePath.addCurve(to: CGPoint(x: x1, y: y1),
                                               control1: CGPoint(x: (x0+x1)/2, y: y0),
                                               control2: CGPoint(x: (x0+x1)/2, y: y1))
                        }

                        if let lastPt = sortedPts.last, let firstPt = sortedPts.first {
                            var fillPath = curvePath
                            fillPath.addLine(to: CGPoint(x: tempToX(lastPt.temperature), y: size.height - pad.bottom))
                            fillPath.addLine(to: CGPoint(x: tempToX(firstPt.temperature), y: size.height - pad.bottom))
                            fillPath.closeSubpath()
                            ctx.fill(
                                fillPath,
                                with: .color(FansColors.blue.opacity(0.10))
                            )
                        }

                        ctx.stroke(
                            curvePath,
                            with: .color(FansColors.blue.opacity(0.90)),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                        )

                        // Control points glow + label
                        for pt in sortedPts {
                            let x = tempToX(pt.temperature)
                            let y = speedToY(pt.fanSpeed)
                            let isDragging = pt.id == draggingPoint

                            var glowPath = Path()
                            glowPath.addEllipse(in: CGRect(x: x - 10, y: y - 10, width: 20, height: 20))
                            ctx.fill(glowPath, with: .color(isDragging ? FansColors.blue.opacity(0.30) : FansColors.blue.opacity(0.12)))

                            var dotPath = Path()
                            dotPath.addEllipse(in: CGRect(x: x - 5, y: y - 5, width: 10, height: 10))
                            ctx.fill(dotPath, with: .color(isDragging ? FansColors.blue : Color.white.opacity(0.85)))
                            ctx.stroke(dotPath, with: .color(.white.opacity(0.30)), lineWidth: 1)

                            ctx.draw(
                                Text("\(Int(pt.fanSpeed))%")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Color.white.opacity(0.45)),
                                at: CGPoint(x: x, y: y - 13)
                            )
                        }

                        // Live temperature cursor — dashed green line + pulsing glow ring + dot + triangle marker
                        let curTemp = max(30, min(100, currentTemp))
                        let cursorX = tempToX(curTemp)
                        let curSpeed = getCurveSpeedAt(curTemp, pts: sortedPts)
                        let cursorY = speedToY(curSpeed)

                        // Vertical dashed line
                        var vLine = Path()
                        vLine.move(to: CGPoint(x: cursorX, y: pad.top))
                        vLine.addLine(to: CGPoint(x: cursorX, y: size.height - pad.bottom))
                        ctx.stroke(vLine, with: .color(FansColors.green.opacity(0.50)),
                                   style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))

                        // Horizontal guide line
                        var hLine = Path()
                        hLine.move(to: CGPoint(x: pad.leading, y: cursorY))
                        hLine.addLine(to: CGPoint(x: cursorX, y: cursorY))
                        ctx.stroke(hLine, with: .color(FansColors.green.opacity(0.25)), lineWidth: 1)

                        // Pulsing glow ring: radius 6..10, opacity 0.12..0.26
                        let glowR = CGFloat(6 + pulse * 4)
                        var glowRing = Path()
                        glowRing.addEllipse(in: CGRect(x: cursorX - glowR, y: cursorY - glowR,
                                                       width: glowR * 2, height: glowR * 2))
                        ctx.fill(glowRing, with: .color(FansColors.green.opacity(0.12 + pulse * 0.14)))

                        // Green dot
                        var greenDot = Path()
                        greenDot.addEllipse(in: CGRect(x: cursorX - 4, y: cursorY - 4, width: 8, height: 8))
                        ctx.fill(greenDot, with: .color(FansColors.green))

                        // Label
                        ctx.draw(
                            Text("\(Int(curTemp))\u{00B0}C / \(Int(curSpeed))%")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(FansColors.green.opacity(0.85)),
                            at: CGPoint(x: cursorX + 40, y: cursorY - 6),
                            anchor: .leading
                        )

                        // Triangle marker (▲) below cursor on temperature axis
                        ctx.draw(
                            Text("▲")
                                .font(.system(size: 9))
                                .foregroundStyle(FansColors.green.opacity(0.60)),
                            at: CGPoint(x: cursorX, y: size.height - pad.bottom + 10)
                        )
                    }

                    // Draggable control points as SwiftUI overlay
                    ForEach($points) { $pt in
                        let pos = pointToScreen(pt, size: geo.size)
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 24, height: 24)
                            .position(pos)
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { val in
                                        draggingPoint = pt.id
                                        let newPt = screenToPoint(val.location, size: geo.size)
                                        pt.temperature = max(30, min(100, newPt.temperature))
                                        pt.fanSpeed    = max(0, min(100, newPt.fanSpeed))
                                    }
                                    .onEnded { _ in
                                        draggingPoint = nil
                                        points.sort { $0.temperature < $1.temperature }
                                    }
                            )
                    }
                }
            }
        }
        .background(FansColors.bg, in: RoundedRectangle(cornerRadius: 8))
    }

    private func pointToScreen(_ pt: CurvePoint, size: CGSize) -> CGPoint {
        let pad = chartPad
        let chartW = size.width - pad.leading - pad.trailing
        let chartH = size.height - pad.top - pad.bottom
        let x = pad.leading + CGFloat((pt.temperature - 30) / 70) * chartW
        let y = pad.top + CGFloat(1 - pt.fanSpeed / 100) * chartH
        return CGPoint(x: x, y: y)
    }

    private func screenToPoint(_ pos: CGPoint, size: CGSize) -> CurvePoint {
        let pad = chartPad
        let chartW = size.width - pad.leading - pad.trailing
        let chartH = size.height - pad.top - pad.bottom
        let t = 30 + ((pos.x - pad.leading) / chartW) * 70
        let s = (1 - (pos.y - pad.top) / chartH) * 100
        return CurvePoint(temperature: t, fanSpeed: s)
    }

    private func getCurveSpeedAt(_ temp: Double, pts: [CurvePoint]) -> Double {
        if pts.isEmpty { return 50 }
        if temp <= pts[0].temperature { return pts[0].fanSpeed }
        if temp >= pts[pts.count - 1].temperature { return pts[pts.count - 1].fanSpeed }
        for i in 0..<pts.count - 1 {
            if temp >= pts[i].temperature && temp <= pts[i + 1].temperature {
                let t = (temp - pts[i].temperature) / (pts[i + 1].temperature - pts[i].temperature)
                return pts[i].fanSpeed + t * (pts[i + 1].fanSpeed - pts[i].fanSpeed)
            }
        }
        return 50
    }
}

// MARK: - Collection safe subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}

// MARK: - Comparable clamped helper

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}


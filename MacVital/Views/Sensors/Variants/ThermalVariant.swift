// Thermal variant selector + shared 7-lane model, palette, history, and pill / speed-limit helpers.
import SwiftUI
import IOKit
import IOKit.pwr_mgt

enum ThermalVariant: Int, CaseIterable, Identifiable {
    case editorial = 5
    case chassisHeatmap = 0
    case laneBarGrid = 1
    case ridgelinePlot = 2
    case polarChart = 3
    case profileCards = 4

    var id: Int { rawValue }

    static let storageKey = "com.macvital.thermal.variant"

    var displayName: String {
        switch self {
        case .editorial:      return "Editorial"
        case .chassisHeatmap: return "Chassis heatmap"
        case .laneBarGrid:    return "Lane bar grid"
        case .ridgelinePlot:  return "Ridgeline plot"
        case .polarChart:     return "Polar chart"
        case .profileCards:   return "Profile cards"
        }
    }
}

enum ThermalLaneKind: Int, CaseIterable, Identifiable {
    case pCPU
    case eCPU
    case gpu
    case ane
    case soc
    case nand
    case battery
    case chassis

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .pCPU:    return "P-CPU"
        case .eCPU:    return "E-CPU"
        case .gpu:     return "GPU"
        case .ane:     return "ANE"
        case .soc:     return "SoC fabric"
        case .nand:    return "NAND"
        case .battery: return "Battery"
        case .chassis: return "Chassis"
        }
    }

    var subLabel: String {
        switch self {
        case .pCPU:    return "pACC MTR"
        case .eCPU:    return "eACC MTR"
        case .gpu:     return "GPU MTR"
        case .ane:     return "ANE MTR"
        case .soc:     return "SOC MTR"
        case .nand:    return "NAND CH0"
        case .battery: return "BATTERY"
        case .chassis: return "skin avg"
        }
    }
}

enum ThermalBand: Int {
    case idle, light, heavy, throttle

    var label: String {
        switch self {
        case .idle:     return "Idle"
        case .light:    return "Light"
        case .heavy:    return "Heavy"
        case .throttle: return "Throttle"
        }
    }
}

enum ThermalPalette {
    static let canvasBg   = Color(red: 0.137, green: 0.137, blue: 0.145)
    static let stageBg    = Color(red: 0.122, green: 0.122, blue: 0.129)
    static let cardBg     = Color(red: 0.165, green: 0.165, blue: 0.176)
    static let hairline   = Color.white.opacity(0.05)
    static let hairlineSt = Color.white.opacity(0.10)
    static let text1      = Color(white: 0.96)
    static let text2      = Color.white.opacity(0.78)
    static let text3      = Color.white.opacity(0.45)
    static let text4      = Color.white.opacity(0.30)
    static let cool       = Color(red: 0.188, green: 0.820, blue: 0.345)
    static let warm       = Color(red: 1.000, green: 0.839, blue: 0.039)
    static let hot        = Color(red: 1.000, green: 0.624, blue: 0.039)
    static let ember      = Color(red: 1.000, green: 0.271, blue: 0.227)

    static func bandColor(_ band: ThermalBand) -> Color {
        switch band {
        case .idle: return cool
        case .light: return warm
        case .heavy: return hot
        case .throttle: return ember
        }
    }
}

struct ThermalLane: Identifiable {
    let kind: ThermalLaneKind
    let current: Double
    let peak24h: Double
    let baseline24h: Double
    let history: [Double]

    var id: Int { kind.rawValue }
    var delta: Double { current - baseline24h }

    var band: ThermalBand {
        if current < 55 { return .idle }
        if current < 70 { return .light }
        if current < 85 { return .heavy }
        return .throttle
    }

    var color: Color { ThermalPalette.bandColor(band) }
}

enum ThermalLaneFolder {
    // Per-lane sane physical bounds. SMC occasionally returns garbage
    // (zero, negative, or absurdly high values) on M-series macs and on
    // sleep/wake cycles. Clamp before any UI consumes the reading.
    private static func validRange(for kind: ThermalLaneKind) -> ClosedRange<Double> {
        switch kind {
        case .pCPU, .eCPU, .gpu, .soc, .ane, .nand: return 0...120
        case .battery: return 0...65
        case .chassis: return 0...50
        }
    }

    private static var lastValid: [ThermalLaneKind: Double] = [:]

    /// Clamp a reading to its sane range. If out of range, fall back to the
    /// previous valid reading for that lane, otherwise zero.
    private static func clamp(_ value: Double, kind: ThermalLaneKind) -> Double {
        let range = validRange(for: kind)
        if value.isFinite && range.contains(value) {
            lastValid[kind] = value
            return value
        }
        return lastValid[kind] ?? 0
    }

    static func collapse(sensors: [SensorReading], history: [Double]) -> [ThermalLane] {
        let cpu = sensors.filter { $0.category == .cpuTemperature }
        let pCPUVals = cpu.filter { $0.name.lowercased().contains("p-") || $0.name.lowercased().contains("performance") || $0.key.hasPrefix("Tp") || $0.key.hasPrefix("pACC") }
        let eCPUVals = cpu.filter { $0.name.lowercased().contains("e-") || $0.name.lowercased().contains("efficiency") || $0.key.hasPrefix("Te") || $0.key.hasPrefix("eACC") }
        let pCPU = pickMax(pCPUVals.isEmpty ? cpu : pCPUVals)
        let eCPU = pickMax(eCPUVals.isEmpty ? cpu.filter { c in !pCPUVals.contains(where: { p in p.key == c.key }) } : eCPUVals)
        let gpu = pickMax(sensors.filter { $0.category == .gpuTemperature })
        let battery = pickMax(sensors.filter { $0.category == .batteryTemperature })
        let nand = pickMax(sensors.filter { $0.category == .driveTemperature })
        let skin = pickMax(sensors.filter { $0.category == .skinTemperature || $0.category == .ambientTemperature })
        let socKeys = ["SOC", "fabric", "ANE", "Tg", "TgFD"]
        let socVals = sensors.filter { s in socKeys.contains { s.key.contains($0) || s.name.contains($0) } && s.category != .gpuTemperature }
        let soc = pickMax(socVals.isEmpty ? sensors.filter { $0.unit == "°C" } : socVals)
        let aneVals = sensors.filter { $0.name.uppercased().contains("ANE") || $0.key.uppercased().contains("ANE") }
        let ane = pickMax(aneVals.isEmpty ? cpu : aneVals)

        return ThermalLaneKind.allCases.map { kind in
            let raw: Double = {
                switch kind {
                case .pCPU:    return pCPU
                case .eCPU:    return eCPU
                case .gpu:     return gpu
                case .ane:     return ane
                case .soc:     return soc
                case .nand:    return nand
                case .battery: return battery
                case .chassis: return skin
                }
            }()
            let value = clamp(raw, kind: kind)
            let rangeMax = validRange(for: kind).upperBound
            let lanePeak = min(rangeMax, max(value, value + 3))
            let laneBase = max(0, value - laneOffset(kind: kind))
            let trace = laneHistory(kind: kind, current: value, base: history)
            return ThermalLane(kind: kind, current: value, peak24h: lanePeak, baseline24h: laneBase, history: trace)
        }
    }

    private static func pickMax(_ list: [SensorReading]) -> Double {
        list.map(\.value).max() ?? 0
    }

    private static func laneOffset(kind: ThermalLaneKind) -> Double {
        switch kind {
        case .pCPU: return 6.4
        case .gpu:  return 3.1
        case .soc:  return 2.8
        case .nand: return 1.0
        case .eCPU: return 0.4
        case .ane:  return 1.2
        case .battery: return 0.5
        case .chassis: return 1.8
        }
    }

    private static func laneHistory(kind: ThermalLaneKind, current: Double, base: [Double]) -> [Double] {
        let tail = base.suffix(60)
        guard !tail.isEmpty else { return Array(repeating: current, count: 60) }
        let mean = tail.reduce(0, +) / Double(tail.count)
        let scale: Double = mean > 0 ? current / mean : 1
        let pinned: Double = {
            switch kind {
            case .pCPU: return 1.00
            case .gpu:  return 0.78
            case .soc:  return 0.74
            case .nand: return 0.59
            case .eCPU: return 0.57
            case .ane:  return 0.49
            case .battery: return 0.36
            case .chassis: return 0.42
            }
        }()
        return tail.map { v in v * scale * pinned + current * (1 - pinned) }
    }
}

enum ThermalState: String {
    case nominal = "Nominal"
    case fair = "Fair"
    case serious = "Serious"
    case critical = "Critical"

    static func current() -> ThermalState {
        switch Foundation.ProcessInfo.processInfo.thermalState {
        case .nominal: return .nominal
        case .fair:    return .fair
        case .serious: return .serious
        case .critical: return .critical
        @unknown default: return .nominal
        }
    }

    var color: Color {
        switch self {
        case .nominal:  return ThermalPalette.cool
        case .fair:     return ThermalPalette.warm
        case .serious:  return ThermalPalette.hot
        case .critical: return ThermalPalette.ember
        }
    }
}

enum ThermalSpeedLimit {
    static func read() -> Int {
        var dictRef: Unmanaged<CFDictionary>?
        let status = IOPMCopyCPUPowerStatus(&dictRef)
        guard status == kIOReturnSuccess,
              let d = dictRef?.takeRetainedValue() as? [String: Any],
              let v = d["CPU_Speed_Limit"] as? Int
        else { return 100 }
        return v
    }
}

func thermalTempString(_ value: Double) -> String {
    String(format: "%.0f °C", value)
}

func thermalTempStringPrecise(_ value: Double) -> String {
    String(format: "%.1f °C", value)
}

func thermalDeltaString(_ value: Double) -> String {
    let sign = value >= 0 ? "+" : "−"
    return String(format: "%@%.1f", sign, abs(value))
}

struct ThermalTopStrip: View {
    let lanes: [ThermalLane]
    let thermalState: ThermalState
    let speedLimit: Int

    private var hottest: ThermalLane? {
        lanes.max(by: { $0.current < $1.current })
    }

    var body: some View {
        HStack(spacing: 14) {
            statePill
            speedLimitCard
            hottestCard
        }
    }

    private var statePill: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text("THERMAL").font(.system(size: 9, weight: .semibold)).foregroundStyle(ThermalPalette.text3)
                Text("STATE").font(.system(size: 9, weight: .semibold)).foregroundStyle(ThermalPalette.text3)
            }
            .frame(width: 60, alignment: .leading)

            HStack(spacing: 3) {
                ForEach([ThermalState.nominal, .fair, .serious, .critical], id: \.rawValue) { state in
                    let on = state == thermalState
                    HStack(spacing: 5) {
                        if on {
                            Circle().fill(state.color).frame(width: 5, height: 5)
                        }
                        Text(state.rawValue.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(on ? state.color : ThermalPalette.text4)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(on ? state.color.opacity(0.16) : Color.white.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(on ? state.color.opacity(0.42) : Color.white.opacity(0.04), lineWidth: 1)
                    )
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(ThermalPalette.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(ThermalPalette.hairline, lineWidth: 1))
    }

    private var speedLimitCard: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text("CPU SPEED").font(.system(size: 9, weight: .semibold)).foregroundStyle(ThermalPalette.text3)
                Text("LIMIT").font(.system(size: 9, weight: .semibold)).foregroundStyle(ThermalPalette.text3)
            }
            .frame(width: 60, alignment: .leading)

            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("\(speedLimit)")
                    .font(.system(size: 20, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(ThermalPalette.warm)
                Text("%")
                    .font(.system(size: 11))
                    .foregroundStyle(ThermalPalette.warm.opacity(0.6))
            }
            .frame(width: 56, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.07))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(ThermalPalette.warm)
                        .frame(width: geo.size.width * CGFloat(speedLimit) / 100)
                    Rectangle()
                        .fill(Color.white.opacity(0.30))
                        .frame(width: 1)
                        .offset(x: geo.size.width * 0.80)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(ThermalPalette.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(ThermalPalette.hairline, lineWidth: 1))
    }

    private var hottestCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text("HOTTEST").font(.system(size: 9, weight: .semibold)).foregroundStyle(ThermalPalette.text3)
                Text("RIGHT NOW").font(.system(size: 9, weight: .semibold)).foregroundStyle(ThermalPalette.text3)
            }
            .frame(width: 70, alignment: .leading)

            if let h = hottest {
                Text(h.kind.name)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(ThermalPalette.text1)
                Text(thermalTempString(h.current))
                    .font(.system(size: 16, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(h.color)
                Spacer(minLength: 4)
                Text(String(format: "vs base %.1f", h.baseline24h))
                    .font(.system(size: 10))
                    .monospacedDigit()
                    .foregroundStyle(ThermalPalette.text3)
                Text(thermalDeltaString(h.delta))
                    .font(.system(size: 10.5, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(h.color)
                    .padding(.horizontal, 5).padding(.vertical, 1.5)
                    .background(RoundedRectangle(cornerRadius: 3).fill(h.color.opacity(0.16)))
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(ThermalPalette.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(ThermalPalette.hairline, lineWidth: 1))
    }
}

struct ThermalSparkline: View {
    let data: [Double]
    let color: Color
    var lineWidth: CGFloat = 1.5

    var body: some View {
        GeometryReader { geo in
            let pts = data
            if pts.count >= 2 {
                let lo = pts.min() ?? 0
                let hi = pts.max() ?? 1
                let span = max(hi - lo, 1)
                Path { p in
                    for (i, v) in pts.enumerated() {
                        let x = geo.size.width * CGFloat(i) / CGFloat(pts.count - 1)
                        let y = geo.size.height * (1 - CGFloat((v - lo) / span))
                        if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                        else { p.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

struct ThermalBandGauge: View {
    let band: ThermalBand
    var dense: Bool = false

    var body: some View {
        HStack(spacing: 1) {
            ForEach([ThermalBand.idle, .light, .heavy, .throttle], id: \.rawValue) { b in
                let lit = b == band
                let color = ThermalPalette.bandColor(b)
                ZStack {
                    Rectangle()
                        .fill(lit ? color.opacity(0.30) : Color.white.opacity(0.04))
                    Text(b.label.uppercased())
                        .font(.system(size: dense ? 8 : 9, weight: .semibold))
                        .foregroundStyle(lit ? color : ThermalPalette.text4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: dense ? 3 : 4))
    }
}


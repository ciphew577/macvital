// MacVital/Views/Fans/Variants/FanVariant.swift
import SwiftUI

enum FanVariant: Int, CaseIterable, Identifiable {
    case appleHIGFlat = 0
    case nzxtProduct = 1
    case iconscoutFlat = 2
    case streamlineLine = 3
    case customCanvas = 4

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .appleHIGFlat:   return "Apple HIG Flat"
        case .nzxtProduct:    return "NZXT Product"
        case .iconscoutFlat:  return "Iconscout Flat"
        case .streamlineLine: return "Streamline Line"
        case .customCanvas:   return "Custom Canvas"
        }
    }

    var tagNumber: String {
        String(format: "%02d", rawValue + 1)
    }
}

struct FanHeroPalette {
    static let bg          = Color(red: 0.047, green: 0.051, blue: 0.063)
    static let tile        = Color(red: 0.086, green: 0.090, blue: 0.102)
    static let tileH       = Color(red: 0.102, green: 0.106, blue: 0.118)
    static let tileDeep    = Color(red: 0.071, green: 0.075, blue: 0.086)
    static let hair        = Color.white.opacity(0.055)
    static let hairS       = Color.white.opacity(0.10)
    static let hairLine    = Color.white.opacity(0.16)
    static let text1       = Color(red: 0.910, green: 0.902, blue: 0.890)
    static let text2       = Color(red: 0.910, green: 0.902, blue: 0.890).opacity(0.62)
    static let text3       = Color(red: 0.910, green: 0.902, blue: 0.890).opacity(0.40)
    static let text4       = Color(red: 0.910, green: 0.902, blue: 0.890).opacity(0.22)
    static let sage        = Color(red: 0.561, green: 0.682, blue: 0.600)
    static let sageHi      = Color(red: 0.659, green: 0.776, blue: 0.694)
    static let sageSoft    = Color(red: 0.561, green: 0.682, blue: 0.600).opacity(0.18)
    static let sageDeep    = Color(red: 0.561, green: 0.682, blue: 0.600).opacity(0.32)
    static let amber       = Color(red: 0.753, green: 0.565, blue: 0.251)
    static let amberSoft   = Color(red: 0.753, green: 0.565, blue: 0.251).opacity(0.16)
    static let amberDeep   = Color(red: 0.753, green: 0.565, blue: 0.251).opacity(0.32)
    static let ember       = Color(red: 0.753, green: 0.314, blue: 0.227)
    static let emberSoft   = Color(red: 0.753, green: 0.314, blue: 0.227).opacity(0.16)
}

struct FanHeroData {
    let fanIndex: Int
    let displayName: String
    let smcKeyHint: String
    let currentRPM: Int
    let targetRPM: Int
    let minRPM: Int
    let maxRPM: Int
    let rpmHistory: [Double]
    let driverSensor: String
    let driverTempC: Double
    let modeLabel: String
    let onCurve: Bool

    var fraction: Double {
        guard maxRPM > minRPM else { return 0 }
        let f = Double(currentRPM - minRPM) / Double(maxRPM - minRPM)
        return max(0, min(1, f))
    }

    var deltaRPM: Int { currentRPM - targetRPM }

    var estimatedDBA: Int {
        Int(30 + (Double(currentRPM) / max(Double(maxRPM), 1)) * 35)
    }

    var statusColor: Color {
        let pct = Double(currentRPM) / max(Double(maxRPM), 1)
        if pct < 0.55 { return FanHeroPalette.sage }
        if pct < 0.78 { return FanHeroPalette.amber }
        return FanHeroPalette.ember
    }
}

struct FanHeroCard: View {
    let variant: FanVariant
    let data: FanHeroData
    let isVisible: Bool
    let startDate: Date

    var body: some View {
        let featured = variant == .customCanvas
        HStack(alignment: .top, spacing: 22) {
            VStack(spacing: featured ? 0 : 2) {
                FanRotorView(
                    variant: variant,
                    data: data,
                    isVisible: isVisible,
                    startDate: startDate,
                    size: featured ? 264 : 220
                )
                if variant == .nzxtProduct {
                    Text(fvFormatRPM(data.currentRPM))
                        .font(.system(size: 30, weight: .light, design: .monospaced))
                        .monospacedDigit()
                        .tracking(-0.3)
                        .foregroundStyle(FanHeroPalette.text1)
                        .padding(.top, 6)
                    Text("RPM ACTUAL")
                        .font(.system(size: 9, weight: .regular))
                        .tracking(1.4)
                        .foregroundStyle(FanHeroPalette.text4)
                        .padding(.top, 2)
                }
            }
            .frame(width: featured ? 320 : 264, alignment: .center)

            FanHeroRight(data: data, featured: featured)
        }
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: featured ? 420 : 400)
        .background(featured ? FanHeroPalette.tileH : FanHeroPalette.tile)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(FanHeroPalette.hair, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .topTrailing) {
            FanVariantTag(variant: variant, featured: featured)
                .padding(.top, 14)
                .padding(.trailing, 16)
        }
    }
}

struct FanRotorView: View {
    let variant: FanVariant
    let data: FanHeroData
    let isVisible: Bool
    let startDate: Date
    let size: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private var isPaused: Bool {
        reduceMotion
            || scenePhase != .active
            || data.currentRPM == 0
            || !isVisible
    }

    var body: some View {
        // 30Hz is half the previous 60Hz target and remains visually smooth
        // for a rotating fan rotor. Pauses whenever the rotor is offscreen,
        // the scene is inactive, the user has reduceMotion enabled, or RPM
        // is zero.
        // Intel: 5 Hz, Apple Silicon: 30 Hz.
        #if arch(x86_64)
        let _fanFps = 1.0/5.0
        #else
        let _fanFps = 1.0/30.0
        #endif
        TimelineView(.animation(minimumInterval: _fanFps, paused: isPaused)) { ctx in
            let angle = isPaused ? lastAngle : currentAngle(at: ctx.date)
            ZStack {
                FanRotorBackdrop(variant: variant, data: data, size: size)
                    .equatable()
                rotor(angle: angle)
                FanRotorHub(variant: variant, size: size)
                    .equatable()
                if variant != .nzxtProduct {
                    FanRotorCenterReadout(data: data, size: size)
                }
            }
            .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
    }

    /// When paused we hold a deterministic angle so the rotor doesn't
    /// snap. Cheap to compute and avoids needing extra @State.
    private var lastAngle: Double {
        currentAngle(at: startDate)
    }

    @ViewBuilder
    private func rotor(angle: Double) -> some View {
        switch variant {
        case .appleHIGFlat:   FanRotorAppleHIGFlat(angle: angle, size: size)
        case .nzxtProduct:    FanRotorNZXTProduct(angle: angle, size: size, sage: data.statusColor)
        case .iconscoutFlat:  FanRotorIconscoutFlat(angle: angle, size: size, sage: data.statusColor)
        case .streamlineLine: FanRotorStreamlineLine(angle: angle, size: size, sage: data.statusColor)
        case .customCanvas:   FanRotorCustomCanvas(angle: angle, size: size, sage: data.statusColor)
        }
    }

    private func currentAngle(at date: Date) -> Double {
        let elapsed = date.timeIntervalSince(startDate)
        let visualCapHz = 4.0
        let frac = data.fraction
        let hz = max(0.10, frac * visualCapHz)
        let degsPerSec = hz * 360.0
        return (elapsed * degsPerSec).truncatingRemainder(dividingBy: 360)
    }
}

struct FanRotorBackdrop: View, Equatable {
    let variant: FanVariant
    let data: FanHeroData
    let size: CGFloat

    static func == (lhs: FanRotorBackdrop, rhs: FanRotorBackdrop) -> Bool {
        lhs.variant == rhs.variant
            && lhs.size == rhs.size
            && lhs.data.fraction == rhs.data.fraction
            && lhs.data.minRPM == rhs.data.minRPM
            && lhs.data.maxRPM == rhs.data.maxRPM
    }

    var body: some View {
        ZStack {
            if variant == .nzxtProduct {
                Circle()
                    .strokeBorder(FanHeroPalette.hairS, lineWidth: 1.2)
                    .padding(size * 0.05)
                Circle()
                    .strokeBorder(Color.white.opacity(0.05), lineWidth: 0.5)
                    .padding(size * 0.085)
            }
            if variant == .streamlineLine {
                Circle()
                    .strokeBorder(
                        FanHeroPalette.sage.opacity(0.16),
                        style: StrokeStyle(lineWidth: 0.5, dash: [2, 4])
                    )
                    .padding(size * 0.16)
            } else {
                Circle()
                    .strokeBorder(Color.white.opacity(0.04), lineWidth: 0.5)
                    .padding(size * 0.16)
            }
            FanTargetArc(data: data, size: size, variant: variant)
        }
    }
}

struct FanTargetArc: View {
    let data: FanHeroData
    let size: CGFloat
    let variant: FanVariant

    var body: some View {
        let lineWidth: CGFloat = variant == .streamlineLine ? 2 : (variant == .appleHIGFlat ? 2.5 : 3)
        let ringInset: CGFloat = variant == .customCanvas ? 10 : 14
        let radius = (size / 2) - ringInset
        let startDeg: Double = 135
        let sweepFull: Double = 270
        let sweepActive = sweepFull * data.fraction
        let endDeg = startDeg + sweepActive
        ZStack {
            Path { p in
                p.addArc(
                    center: CGPoint(x: size/2, y: size/2),
                    radius: radius,
                    startAngle: .degrees(startDeg),
                    endAngle: .degrees(startDeg + sweepFull),
                    clockwise: false
                )
            }
            .stroke(Color.white.opacity(variant == .streamlineLine ? 0.07 : 0.06),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            if data.fraction > 0.001 {
                Path { p in
                    p.addArc(
                        center: CGPoint(x: size/2, y: size/2),
                        radius: radius,
                        startAngle: .degrees(startDeg),
                        endAngle: .degrees(endDeg),
                        clockwise: false
                    )
                }
                .stroke(FanHeroPalette.sage,
                        style: StrokeStyle(lineWidth: lineWidth + (variant == .customCanvas ? 0.2 : 0), lineCap: .round))
            }

            FanTargetEndpoint(centerSize: size, radius: radius, endDeg: endDeg, variant: variant, fraction: data.fraction)
            FanArcMinMaxLabels(size: size, radius: radius, data: data)
        }
    }
}

struct FanTargetEndpoint: View {
    let centerSize: CGFloat
    let radius: CGFloat
    let endDeg: Double
    let variant: FanVariant
    let fraction: Double

    var body: some View {
        let rad = endDeg * .pi / 180
        let cx = centerSize/2 + cos(rad) * radius
        let cy = centerSize/2 + sin(rad) * radius
        ZStack {
            if variant == .customCanvas || variant == .streamlineLine {
                Circle()
                    .strokeBorder(FanHeroPalette.sage.opacity(0.55), lineWidth: 0.8)
                    .frame(width: 16, height: 16)
                    .position(x: cx, y: cy)
            }
            Circle()
                .fill(FanHeroPalette.sage)
                .frame(width: variant == .customCanvas ? 8 : (variant == .streamlineLine ? 5.6 : 7))
                .position(x: cx, y: cy)
        }
        .opacity(fraction > 0.001 ? 1 : 0)
    }
}

struct FanArcMinMaxLabels: View {
    let size: CGFloat
    let radius: CGFloat
    let data: FanHeroData

    var body: some View {
        let leftRad = 135.0 * .pi / 180
        let rightRad = 45.0 * .pi / 180
        let lx = size/2 + cos(leftRad) * (radius + 8)
        let ly = size/2 + sin(leftRad) * (radius + 8)
        let rx = size/2 + cos(rightRad) * (radius + 8)
        let ry = size/2 + sin(rightRad) * (radius + 8)
        ZStack {
            Text(fvFormatKRPM(data.minRPM))
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.9)
                .foregroundStyle(FanHeroPalette.text3)
                .position(x: lx, y: ly + 12)
            Text(fvFormatKRPM(data.maxRPM))
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.9)
                .foregroundStyle(FanHeroPalette.text3)
                .position(x: rx, y: ry + 12)
        }
    }
}

struct FanRotorHub: View, Equatable {
    let variant: FanVariant
    let size: CGFloat

    static func == (lhs: FanRotorHub, rhs: FanRotorHub) -> Bool {
        lhs.variant == rhs.variant && lhs.size == rhs.size
    }

    var body: some View {
        let center = CGPoint(x: size/2, y: size/2)
        ZStack {
            switch variant {
            case .appleHIGFlat:
                Circle().fill(FanHeroPalette.tile).frame(width: 22, height: 22).position(center)
                Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 1).frame(width: 22, height: 22).position(center)
                Circle().fill(FanHeroPalette.text1.opacity(0.55)).frame(width: 4, height: 4).position(center)
            case .nzxtProduct:
                Circle().fill(FanHeroPalette.bg).frame(width: 44, height: 44).position(center)
                Circle().fill(FanHeroPalette.tile).frame(width: 40, height: 40).position(center)
                Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 0.8).frame(width: 40, height: 40).position(center)
                Circle().fill(FanHeroPalette.tileH).frame(width: 28, height: 28).position(center)
                Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5).frame(width: 28, height: 28).position(center)
                ForEach(0..<4) { i in
                    let dx: CGFloat = (i == 0 || i == 2) ? -10 : 10
                    let dy: CGFloat = (i < 2) ? -10 : 10
                    Circle().fill(Color.white.opacity(0.30)).frame(width: 2.4, height: 2.4)
                        .position(x: center.x + dx, y: center.y + dy)
                }
                Circle().fill(FanHeroPalette.sage).frame(width: 4, height: 4).position(center)
            case .iconscoutFlat:
                Circle().fill(FanHeroPalette.bg).frame(width: 26, height: 26).position(center)
                Circle().fill(FanHeroPalette.tile).frame(width: 22, height: 22).position(center)
                Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 0.8).frame(width: 22, height: 22).position(center)
                Circle().fill(FanHeroPalette.sage).frame(width: 6, height: 6).position(center)
            case .streamlineLine:
                Circle().strokeBorder(FanHeroPalette.sage.opacity(0.55), lineWidth: 1).frame(width: 18, height: 18).position(center)
                Rectangle().fill(FanHeroPalette.sage.opacity(0.45)).frame(width: 14, height: 0.6).position(center)
                Rectangle().fill(FanHeroPalette.sage.opacity(0.45)).frame(width: 0.6, height: 14).position(center)
                Circle().fill(FanHeroPalette.sage).frame(width: 3.2, height: 3.2).position(center)
            case .customCanvas:
                Circle().fill(FanHeroPalette.bg).frame(width: 34, height: 34).position(center)
                Circle().fill(FanHeroPalette.tile).frame(width: 31, height: 31).position(center)
                Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 1).frame(width: 26, height: 26).position(center)
                Circle().fill(FanHeroPalette.tileH).frame(width: 14, height: 14).position(center)
                Circle().strokeBorder(Color.white.opacity(0.24), lineWidth: 0.9).frame(width: 14, height: 14).position(center)
                Circle().fill(FanHeroPalette.sage).frame(width: 4, height: 4).position(center)
            }
        }
    }
}

struct FanRotorCenterReadout: View {
    let data: FanHeroData
    let size: CGFloat

    var body: some View {
        VStack(spacing: 4) {
            Text(fvFormatRPM(data.currentRPM))
                .font(.system(size: size > 240 ? 36 : 30, weight: .light, design: .monospaced))
                .monospacedDigit()
                .tracking(-0.4)
                .foregroundStyle(FanHeroPalette.text1)
            Text("RPM ACTUAL")
                .font(.system(size: 9, weight: .regular))
                .tracking(1.4)
                .foregroundStyle(FanHeroPalette.text4)
        }
        .allowsHitTesting(false)
    }
}

struct FanVariantPicker: View {
    @Binding var selection: FanVariant

    var body: some View {
        HStack(spacing: 6) {
            Text("ROTOR VARIANT")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.6)
                .foregroundStyle(FanHeroPalette.text4)
                .padding(.trailing, 4)
            ForEach(FanVariant.allCases) { v in
                Button {
                    selection = v
                } label: {
                    HStack(spacing: 6) {
                        Text(v.tagNumber)
                            .font(.system(size: 9, weight: .regular, design: .monospaced))
                        Text(v.label)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .foregroundStyle(selection == v ? FanHeroPalette.text1 : FanHeroPalette.text3)
                    .background(
                        Capsule().fill(selection == v ? FanHeroPalette.sageSoft : Color.clear)
                    )
                    .overlay(
                        Capsule().strokeBorder(
                            selection == v ? FanHeroPalette.sageDeep : FanHeroPalette.hairLine,
                            lineWidth: 0.5
                        )
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }
}

struct FanVariantTag: View {
    let variant: FanVariant
    let featured: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(variant.tagNumber)
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundStyle(featured ? FanHeroPalette.sage : FanHeroPalette.text1)
                .frame(width: 20, height: 20)
                .background(
                    Circle().fill(featured ? FanHeroPalette.sageSoft : Color.clear)
                )
                .overlay(
                    Circle().strokeBorder(featured ? FanHeroPalette.sageDeep : FanHeroPalette.hairLine, lineWidth: 0.5)
                )
            Text(variant.label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(1.6)
                .foregroundStyle(FanHeroPalette.text3)
        }
    }
}

struct FanHeroRight: View {
    let data: FanHeroData
    let featured: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            FanHeroHeader(data: data)
            FanHeroStatRow(data: data, featured: featured)
            FanHeroDriver(data: data)
            Spacer(minLength: 0)
            FanHeroFooter(data: data)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.top, 4)
    }
}

struct FanHeroHeader: View {
    let data: FanHeroData

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("FAN \(data.fanIndex)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(FanHeroPalette.sage)
                Text(data.displayName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(FanHeroPalette.text1)
                Text(data.smcKeyHint)
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(FanHeroPalette.text4)
                    .padding(.top, 3)
            }
            Spacer()
            FanHeroBadge(onCurve: data.onCurve)
        }
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(FanHeroPalette.hair).frame(height: 0.5)
        }
    }
}

struct FanHeroBadge: View {
    let onCurve: Bool

    var body: some View {
        let tint = onCurve ? FanHeroPalette.sage : FanHeroPalette.amber
        let bg = onCurve ? FanHeroPalette.sageSoft : FanHeroPalette.amberSoft
        let border = onCurve ? FanHeroPalette.sageDeep : FanHeroPalette.amberDeep
        HStack(spacing: 6) {
            Circle().fill(tint).frame(width: 5, height: 5)
            Text(onCurve ? "ON CURVE" : "TRACKING")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(bg))
        .overlay(Capsule().strokeBorder(border, lineWidth: 0.5))
    }
}

struct FanHeroStatRow: View {
    let data: FanHeroData
    let featured: Bool

    var body: some View {
        let columns: [GridItem] = featured
            ? Array(repeating: GridItem(.flexible(), spacing: 14), count: 4)
            : Array(repeating: GridItem(.flexible(), spacing: 14), count: 3)
        LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
            FanHeroStat(label: "TARGET",
                        value: fvFormatRPM(data.targetRPM),
                        unit: "RPM",
                        sub: "Curve output \(Int(data.fraction * 100))%")
            if featured {
                FanHeroStat(label: "DELTA",
                            value: fvSignedRPM(data.deltaRPM),
                            unit: "RPM",
                            sub: deltaSub(data))
            }
            FanHeroStat(label: "MIN / MAX",
                        value: "\(fvFormatKRPM(data.minRPM))/\(fvFormatKRPM(data.maxRPM))",
                        unit: "",
                        sub: featured ? "F\(data.fanIndex)Mn / F\(data.fanIndex)Mx" : "Firmware")
            FanHeroStat(label: "EST DBA",
                        value: "\(data.estimatedDBA)",
                        unit: "dBA",
                        sub: "Library floor")
        }
    }

    private func deltaSub(_ d: FanHeroData) -> String {
        let pct = d.targetRPM > 0 ? Double(d.deltaRPM) / Double(d.targetRPM) * 100 : 0
        let sign = d.deltaRPM >= 0 ? "over" : "under"
        return String(format: "%.1f%% %@, normal lag", abs(pct), sign)
    }
}

struct FanHeroStat: View {
    let label: String
    let value: String
    let unit: String
    let sub: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(FanHeroPalette.text4)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 17, weight: .medium, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(FanHeroPalette.text1)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(FanHeroPalette.text3)
                }
            }
            Text(sub)
                .font(.system(size: 10))
                .foregroundStyle(FanHeroPalette.text3)
        }
    }
}

struct FanHeroDriver: View {
    let data: FanHeroData

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("DRIVER")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.6)
                .foregroundStyle(FanHeroPalette.ember)
                .padding(.top, 2)
            HStack(spacing: 0) {
                Text("Responding to ")
                Text(data.driverSensor)
                    .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(FanHeroPalette.ember)
                Text(" at ")
                Text(String(format: "%.0f C", data.driverTempC))
                    .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(FanHeroPalette.ember)
                Text(".")
            }
            .font(.system(size: 11.5))
            .foregroundStyle(FanHeroPalette.text1)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 12)
        .background(FanHeroPalette.tileDeep)
        .overlay(alignment: .leading) {
            Rectangle().fill(FanHeroPalette.ember).frame(width: 2)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(FanHeroPalette.hair, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct FanHeroFooter: View {
    let data: FanHeroData

    var body: some View {
        HStack(spacing: 10) {
            FanHeroModeChip(active: data.modeLabel)
            FanHeroSparkline(history: data.rpmHistory)
        }
    }
}

struct FanHeroModeChip: View {
    let active: String
    private let modes = ["System", "Manual", "Curve", "Auto Boost"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(modes, id: \.self) { m in
                Text(m.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.0)
                    .foregroundStyle(m == active ? FanHeroPalette.text1 : FanHeroPalette.text3)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(m == active ? FanHeroPalette.sageSoft : Color.clear)
                    )
            }
        }
        .padding(2)
        .overlay(Capsule().strokeBorder(FanHeroPalette.hairLine, lineWidth: 0.5))
        .clipShape(Capsule())
    }
}

struct FanHeroSparkline: View {
    let history: [Double]

    var body: some View {
        HStack(spacing: 10) {
            Text("60s")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(FanHeroPalette.text4)
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let pts = sparkPoints(in: CGSize(width: w, height: h))
                ZStack {
                    if pts.count >= 2 {
                        Path { p in
                            p.move(to: pts[0])
                            for q in pts.dropFirst() { p.addLine(to: q) }
                        }
                        .stroke(FanHeroPalette.sage,
                                style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                        if let last = pts.last {
                            Circle().fill(FanHeroPalette.sage).frame(width: 4, height: 4).position(last)
                        }
                    }
                }
            }
            .frame(height: 24)
            Text(deltaLabel())
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundStyle(FanHeroPalette.text2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(FanHeroPalette.tileDeep)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(FanHeroPalette.hair, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .frame(maxWidth: .infinity)
    }

    private func sparkPoints(in size: CGSize) -> [CGPoint] {
        guard history.count >= 2 else { return [] }
        let lo = history.min() ?? 0
        let hi = history.max() ?? 1
        let span = max(hi - lo, 1)
        let stepX = size.width / CGFloat(history.count - 1)
        return history.enumerated().map { idx, v in
            let nx = CGFloat(idx) * stepX
            let ny = size.height - CGFloat((v - lo) / span) * size.height
            return CGPoint(x: nx, y: max(2, min(size.height - 2, ny)))
        }
    }

    private func deltaLabel() -> String {
        guard let first = history.first, let last = history.last else { return "0" }
        let d = Int(last - first)
        return d >= 0 ? "+\(d)" : "\(d)"
    }
}

func fvFormatRPM(_ rpm: Int) -> String {
    let nf = NumberFormatter()
    nf.numberStyle = .decimal
    return nf.string(from: NSNumber(value: rpm)) ?? "\(rpm)"
}

func fvFormatKRPM(_ rpm: Int) -> String {
    if rpm >= 1000 {
        let v = Double(rpm) / 1000.0
        return String(format: "%.1fK", v)
    }
    return "\(rpm)"
}

func fvSignedRPM(_ value: Int) -> String {
    value >= 0 ? "+\(value)" : "\(value)"
}

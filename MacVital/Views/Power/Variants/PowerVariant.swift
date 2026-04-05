import SwiftUI

enum PowerVariant: Int, CaseIterable, Identifiable {
    case editorial = 5
    case sankey = 0
    case treemap = 1
    case radialSunburst = 2
    case stackedLaneFlow = 3
    case rankList = 4

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .editorial:        return "Editorial"
        case .sankey:           return "Sankey"
        case .treemap:          return "Treemap"
        case .radialSunburst:   return "Radial sunburst"
        case .stackedLaneFlow:  return "Stacked lanes"
        case .rankList:         return "Rank list"
        }
    }

    var shortLabel: String {
        switch self {
        case .editorial:        return "EDITORIAL"
        case .sankey:           return "SANKEY"
        case .treemap:          return "TREEMAP"
        case .radialSunburst:   return "SUNBURST"
        case .stackedLaneFlow:  return "LANES"
        case .rankList:         return "RANK"
        }
    }
}

enum PowerFlowPalette {
    static let bg          = Color(red: 0x16/255, green: 0x17/255, blue: 0x1A/255)
    static let bgDeep      = Color(red: 0x12/255, green: 0x13/255, blue: 0x16/255)
    static let stroke      = Color.white.opacity(0.06)
    static let text1       = Color(red: 0xE8/255, green: 0xE6/255, blue: 0xE3/255)
    static let text2       = Color.white.opacity(0.55)
    static let text3       = Color.white.opacity(0.32)

    static let wall        = Color(red: 0x8F/255, green: 0xAE/255, blue: 0x99/255)
    static let soc         = Color(red: 0x7B/255, green: 0x95/255, blue: 0xC0/255)
    static let cpu         = Color(red: 0x7B/255, green: 0x95/255, blue: 0xC0/255)
    static let gpu         = Color(red: 0x9B/255, green: 0x8A/255, blue: 0xC4/255)
    static let dram        = Color(red: 0x7B/255, green: 0xC0/255, blue: 0xB0/255)
    static let ane         = Color(red: 0xC0/255, green: 0x90/255, blue: 0x40/255)
    static let media       = Color(red: 0xB6/255, green: 0xA0/255, blue: 0x7A/255)
    static let isp         = Color(red: 0xA8/255, green: 0x9A/255, blue: 0x7A/255)
    static let tb          = Color(red: 0x6E/255, green: 0x8A/255, blue: 0xA8/255)
    static let fabric      = Color(red: 0x6E/255, green: 0x9A/255, blue: 0x8E/255)
    static let display     = Color(red: 0xC7/255, green: 0xB9/255, blue: 0x8A/255)
    static let uncore      = Color(red: 0x8E/255, green: 0x8C/255, blue: 0x92/255)
    static let backlight   = Color(red: 0xC7/255, green: 0xB9/255, blue: 0x8A/255)
    static let usb         = Color(red: 0x6E/255, green: 0x8A/255, blue: 0xA8/255)
    static let fan         = Color(red: 0x8E/255, green: 0x8C/255, blue: 0x92/255)
    static let battery     = Color(red: 0x8F/255, green: 0xAE/255, blue: 0x99/255)
    static let amber       = Color(red: 0xC0/255, green: 0x90/255, blue: 0x40/255)
    static let slate1      = Color(red: 0x6E/255, green: 0x77/255, blue: 0x85/255)
    static let slate2      = Color(red: 0x7B/255, green: 0x85/255, blue: 0x93/255)
    static let slate3      = Color(red: 0x8E/255, green: 0x97/255, blue: 0xA4/255)
}

struct PowerFlowDestination: Identifiable, Equatable {
    let id: String
    let label: String
    let watts: Double
    let color: Color
    let isSigned: Bool
}

struct PowerSoCComponent: Identifiable, Equatable {
    let id: String
    let label: String
    let watts: Double
    let color: Color
}

struct PowerFlowModel: Equatable {
    let wallTotal: Double
    let socTotal: Double
    let backlight: Double
    let battery: Double
    let batteryIsCharging: Bool
    let usb: Double
    let fans: Double
    let cpu: Double
    let gpu: Double
    let dram: Double
    let ane: Double
    let media: Double
    let isp: Double
    let tb: Double
    let fabric: Double
    let displaySoC: Double
    let uncore: Double

    var destinations: [PowerFlowDestination] {
        [
            PowerFlowDestination(id: "soc", label: "SoC Package", watts: socTotal, color: PowerFlowPalette.soc, isSigned: false),
            PowerFlowDestination(id: "back", label: "Backlight", watts: backlight, color: PowerFlowPalette.backlight, isSigned: false),
            PowerFlowDestination(id: "batt", label: batteryIsCharging ? "Battery (chrg)" : "Battery (disch)", watts: abs(battery), color: batteryIsCharging ? PowerFlowPalette.amber : PowerFlowPalette.battery, isSigned: true),
            PowerFlowDestination(id: "usb", label: "USB-C", watts: usb, color: PowerFlowPalette.usb, isSigned: false),
            PowerFlowDestination(id: "fan", label: "Fans", watts: fans, color: PowerFlowPalette.fan, isSigned: false),
        ]
    }

    var socComponents: [PowerSoCComponent] {
        [
            PowerSoCComponent(id: "cpu",     label: "CPU",     watts: cpu,        color: PowerFlowPalette.cpu),
            PowerSoCComponent(id: "gpu",     label: "GPU",     watts: gpu,        color: PowerFlowPalette.gpu),
            PowerSoCComponent(id: "dram",    label: "DRAM",    watts: dram,       color: PowerFlowPalette.dram),
            PowerSoCComponent(id: "ane",     label: "ANE",     watts: ane,        color: PowerFlowPalette.ane),
            PowerSoCComponent(id: "media",   label: "Media",   watts: media,      color: PowerFlowPalette.media),
            PowerSoCComponent(id: "isp",     label: "ISP",     watts: isp,        color: PowerFlowPalette.isp),
            PowerSoCComponent(id: "tb",      label: "TB",      watts: tb,         color: PowerFlowPalette.tb),
            PowerSoCComponent(id: "fabric",  label: "Fabric",  watts: fabric,     color: PowerFlowPalette.fabric),
            PowerSoCComponent(id: "display", label: "Display", watts: displaySoC, color: PowerFlowPalette.display),
            PowerSoCComponent(id: "uncore",  label: "Uncore",  watts: uncore,     color: PowerFlowPalette.uncore),
        ]
    }
}

enum PowerFlowFormat {
    static func watts(_ value: Double, signed: Bool = false) -> String {
        if signed {
            let sign = value >= 0 ? "+" : ""
            return String(format: "%@%.1f W", sign, value)
        }
        return String(format: "%.1f W", value)
    }
}

// MARK: - Editorial Kit (shared by Power + Sensors editorial dashboards)

enum EditorialPalette {
    // Warm off-white canvas
    static let bg              = Color(red: 0xEF/255, green: 0xEA/255, blue: 0xE4/255)
    static let surface         = Color(red: 0xF3/255, green: 0xEE/255, blue: 0xE7/255)
    static let surfaceSunken   = Color(red: 0xE9/255, green: 0xE3/255, blue: 0xDA/255)
    static let hairline        = Color(red: 0xD5/255, green: 0xCF/255, blue: 0xC5/255)
    static let hairlineStrong  = Color(red: 0xBC/255, green: 0xB5/255, blue: 0xA8/255)
    static let trackEmpty      = Color(red: 0xDC/255, green: 0xD5/255, blue: 0xC9/255)

    static let ink             = Color(red: 0x1F/255, green: 0x1E/255, blue: 0x1A/255)
    static let inkMuted        = Color(red: 0x6E/255, green: 0x6A/255, blue: 0x60/255)
    static let inkDim          = Color(red: 0x9A/255, green: 0x95/255, blue: 0x88/255)

    // Categorical (mockup-faithful)
    static let teal            = Color(red: 0x2F/255, green: 0x8A/255, blue: 0x7E/255) // DISPLAY · RAILS
    static let systemGrey      = Color(red: 0x6B/255, green: 0x69/255, blue: 0x63/255) // SYSTEM
    static let compute         = Color(red: 0xB8/255, green: 0x56/255, blue: 0x30/255) // CPU / COMPUTE
    static let io              = Color(red: 0xB5/255, green: 0x8D/255, blue: 0x3A/255) // I/O / USB
    static let gpu             = Color(red: 0x6B/255, green: 0x4F/255, blue: 0x8A/255) // GPU
    static let memory          = Color(red: 0x4A/255, green: 0x86/255, blue: 0xA8/255) // MEMORY / DRAM
    static let accel           = Color(red: 0x96/255, green: 0x3A/255, blue: 0x5C/255) // ACCELERATORS (ANE, ISP, Media)
    static let nand            = Color(red: 0x4D/255, green: 0x6B/255, blue: 0x3A/255) // NAND / STORAGE
    static let pmu             = Color(red: 0x6F/255, green: 0x8F/255, blue: 0xAF/255) // PMU

    // Heatmap stops
    static let heat0 = Color(red: 0x4D/255, green: 0x6B/255, blue: 0x3A/255) // 28°
    static let heat1 = Color(red: 0x4A/255, green: 0x86/255, blue: 0xA8/255) // 37°
    static let heat2 = Color(red: 0x38/255, green: 0x59/255, blue: 0x7F/255) // 45°
    static let heat3 = Color(red: 0x1F/255, green: 0x3A/255, blue: 0x5F/255) // 54°
    static let heat4 = Color(red: 0xB5/255, green: 0x8D/255, blue: 0x3A/255) // 62°
    static let heat5 = Color(red: 0x91/255, green: 0x38/255, blue: 0x24/255) // 71°
}

/// Editorial mono label (uppercase, tracked, mono digits)
struct EditorialLabel: View {
    let text: String
    var color: Color = EditorialPalette.inkMuted
    var size: CGFloat = 10
    var weight: Font.Weight = .regular
    var tracking: CGFloat = 1.2
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: size, weight: weight, design: .monospaced))
            .tracking(tracking)
            .foregroundStyle(color)
    }
}

struct EditorialCard<Content: View>: View {
    let title: String
    let trailing: String
    let trailingColor: Color
    @ViewBuilder let content: Content

    init(title: String, trailing: String = "", trailingColor: Color = EditorialPalette.inkDim, @ViewBuilder content: () -> Content) {
        self.title = title
        self.trailing = trailing
        self.trailingColor = trailingColor
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(EditorialPalette.ink)
                Spacer()
                if !trailing.isEmpty {
                    EditorialLabel(text: trailing, color: trailingColor, size: 10)
                }
            }
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(EditorialPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(EditorialPalette.hairline, lineWidth: 1)
        )
    }
}

/// Editorial dashboard header strip (e.g., "Power" / "Sensors" with subtitle + status chip)
struct EditorialPageHeader: View {
    let title: String
    let subtitle: String
    let chipDot: Color
    let chipText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(EditorialPalette.ink)
                Spacer()
                HStack(spacing: 8) {
                    Circle().fill(chipDot).frame(width: 6, height: 6)
                    EditorialLabel(text: chipText, color: EditorialPalette.compute, size: 10.5, weight: .semibold, tracking: 1.1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(EditorialPalette.hairlineStrong, lineWidth: 1)
                )
            }
            .padding(.top, 4)
            EditorialLabel(text: subtitle, color: EditorialPalette.inkMuted, size: 10.5, tracking: 1.4)
                .padding(.top, 6)
            Rectangle()
                .fill(EditorialPalette.hairlineStrong)
                .frame(height: 1)
                .padding(.top, 14)
        }
    }
}

/// Render a watts value in the "17.24 W" mono style. Sign optional.
enum EditorialFormat {
    static func watts(_ v: Double, fraction: Int = 2) -> String {
        String(format: "%.\(fraction)f W", v)
    }
    static func wattsShort(_ v: Double) -> String {
        String(format: "%.2f W", v)
    }
    static func celsius(_ v: Double, fraction: Int = 1) -> String {
        String(format: "%.\(fraction)f °C", v)
    }
    static func deltaC(_ v: Double) -> String {
        let sign = v >= 0 ? "+" : "−"
        return String(format: "%@%.1f °C", sign, abs(v))
    }
}

struct PowerVariantPicker: View {
    @Binding var selection: PowerVariant

    var body: some View {
        HStack(spacing: 4) {
            ForEach(PowerVariant.allCases) { variant in
                Button {
                    selection = variant
                } label: {
                    Text(variant.shortLabel)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(variant == selection ? PowerFlowPalette.text1 : PowerFlowPalette.text3)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(variant == selection ? PowerFlowPalette.bgDeep : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(variant == selection ? Color.white.opacity(0.10) : Color.white.opacity(0.04), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

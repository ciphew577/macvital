// MacVital/Views/GPU/Variants/GPUVariant.swift
import SwiftUI

enum GPUVariant: Int, CaseIterable, Identifiable {
    case heatStrip = 0
    case coreGrid = 1
    case radialSpoke = 2
    case scrollingTimeline = 3
    case summaryFirst = 4

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .heatStrip:         return "Heat Strip"
        case .coreGrid:          return "Core Grid"
        case .radialSpoke:       return "Radial Spoke"
        case .scrollingTimeline: return "Scrolling Timeline"
        case .summaryFirst:      return "Summary First"
        }
    }
}

enum GPUVariantStorage {
    static let key = "com.macvital.gpu.variant"
}

enum GPUVariantPalette {
    static let bg          = Color(red: 0.110, green: 0.110, blue: 0.118)
    static let surface     = Color.white.opacity(0.04)
    static let surfaceLine = Color.white.opacity(0.08)
    static let text        = Color.white.opacity(0.88)
    static let text2       = Color.white.opacity(0.62)
    static let text3       = Color.white.opacity(0.40)
    static let text4       = Color.white.opacity(0.28)

    static let indigo = Color(red: 94/255,  green: 92/255,  blue: 230/255)
    static let teal   = Color(red: 64/255,  green: 200/255, blue: 224/255)
    static let amber  = Color(red: 255/255, green: 159/255, blue: 10/255)
    static let slate  = Color(red: 142/255, green: 142/255, blue: 160/255)

    static let render  = Color(red: 94/255,  green: 92/255,  blue: 230/255)
    static let compute = Color(red: 10/255,  green: 132/255, blue: 255/255)
    static let media   = Color(red: 255/255, green: 159/255, blue: 10/255)
    static let aneMix  = Color(red: 64/255,  green: 200/255, blue: 224/255)
    static let idle    = Color.white.opacity(0.10)

    static let heatRamp: [Color] = [
        Color(red: 0.18, green: 0.20, blue: 0.36),
        Color(red: 0.24, green: 0.28, blue: 0.55),
        Color(red: 0.31, green: 0.32, blue: 0.78),
        Color(red: 0.40, green: 0.36, blue: 0.92),
        Color(red: 0.55, green: 0.36, blue: 0.92),
        Color(red: 0.78, green: 0.34, blue: 0.78),
        Color(red: 0.95, green: 0.42, blue: 0.55),
        Color(red: 1.00, green: 0.55, blue: 0.32),
        Color(red: 1.00, green: 0.72, blue: 0.20)
    ]

    static func heat(for ratio: Double) -> Color {
        let clamped = max(0.0, min(1.0, ratio))
        let idx = Int(clamped * Double(heatRamp.count - 1) + 0.5)
        return heatRamp[min(heatRamp.count - 1, max(0, idx))]
    }
}

struct GPUVariantPerCore: Identifiable {
    let id: Int
    let busy: Double
    let freqMHz: Int
}

enum GPUVariantData {
    static func perCore(overall: Double, count: Int, baseFreq: Int) -> [GPUVariantPerCore] {
        guard count > 0 else { return [] }
        let mean = max(0.0, min(100.0, overall)) / 100.0
        return (0..<count).map { i in
            let phase = sin(Double(i) * 0.7) * 0.18 + cos(Double(i) * 1.3) * 0.10
            let jitter = max(0.0, min(1.0, mean + phase))
            let freq = max(338, baseFreq + Int((phase * 220).rounded()))
            return GPUVariantPerCore(id: i, busy: jitter, freqMHz: freq)
        }
    }

    static func split(render: Double, compute: Double,
                      mediaPct: Double, anePct: Double) -> (render: Double, compute: Double, media: Double, ane: Double, idle: Double) {
        let r = max(0, render) / 100.0
        let c = max(0, compute) / 100.0
        let m = max(0, mediaPct) / 100.0
        let a = max(0, anePct) / 100.0
        let used = min(1.0, r + c + m + a)
        return (r, c, m, a, max(0.0, 1.0 - used))
    }

    static func aneSpark(samples: Int = 60, peakWatts: Double) -> [Double] {
        let n = max(2, samples)
        let peak = max(0.05, peakWatts)
        return (0..<n).map { i in
            let t = Double(i) / Double(n - 1)
            let base = 0.05 + 0.04 * sin(t * .pi * 4)
            let spike = (i > n - 8) ? peak * (Double(n - i) / 8.0) : 0
            return max(0.0, base + spike * 0.4)
        }
    }
}

struct GPUVariantSectionLabel: View {
    let text: String
    var accent: Color = GPUVariantPalette.indigo
    var source: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(accent).frame(width: 6, height: 6)
            Text(text.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(1)
                .foregroundStyle(GPUVariantPalette.text3)
            Spacer()
            if let source {
                Text(source.uppercased())
                    .font(.system(size: 9, weight: .medium))
                    .monospacedDigit()
                    .tracking(0.6)
                    .foregroundStyle(GPUVariantPalette.text4)
            }
        }
    }
}

struct GPUVariantPanel<Content: View>: View {
    let content: () -> Content
    init(@ViewBuilder content: @escaping () -> Content) { self.content = content }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GPUVariantPalette.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 10).strokeBorder(GPUVariantPalette.surfaceLine, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct GPUVariantSplitStack: View {
    let render: Double
    let compute: Double
    let media: Double
    let ane: Double
    let idle: Double
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 1) {
                Rectangle().fill(GPUVariantPalette.render).frame(width: geo.size.width * render)
                Rectangle().fill(GPUVariantPalette.compute).frame(width: geo.size.width * compute)
                Rectangle().fill(GPUVariantPalette.media).frame(width: geo.size.width * media)
                Rectangle().fill(GPUVariantPalette.aneMix).frame(width: geo.size.width * ane)
                Rectangle().fill(GPUVariantPalette.idle).frame(maxWidth: .infinity)
            }
            .frame(height: height)
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: height / 2))
    }
}

struct GPUVariantSplitLegend: View {
    let render: Double
    let compute: Double
    let media: Double
    let anePower: Double

    var body: some View {
        HStack(spacing: 14) {
            legend(GPUVariantPalette.render, "Render", String(format: "%.0f%%", render))
            legend(GPUVariantPalette.compute, "Compute", String(format: "%.0f%%", compute))
            legend(GPUVariantPalette.media, "Media", String(format: "%.0f%%", media))
            legend(GPUVariantPalette.aneMix, "ANE", String(format: "%.2f W", anePower))
            Spacer()
        }
    }

    @ViewBuilder
    private func legend(_ color: Color, _ label: String, _ value: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(GPUVariantPalette.text2)
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(GPUVariantPalette.text)
        }
    }
}

struct GPUVariantANEPill: View {
    let watts: Double
    var threshold: Double = 0.30
    var body: some View {
        let isActive = watts >= threshold
        HStack(spacing: 5) {
            Circle()
                .fill(isActive ? GPUVariantPalette.teal : GPUVariantPalette.text4)
                .frame(width: 6, height: 6)
            Text(isActive ? "ACTIVE" : "IDLE")
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(isActive ? GPUVariantPalette.teal : GPUVariantPalette.text3)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule().fill((isActive ? GPUVariantPalette.teal : GPUVariantPalette.text4).opacity(0.10))
        )
        .overlay(
            Capsule().strokeBorder((isActive ? GPUVariantPalette.teal : GPUVariantPalette.text4).opacity(0.30), lineWidth: 1)
        )
    }
}

struct GPUVariantANESpark: View {
    let samples: [Double]
    let peak: Double
    var height: CGFloat = 30
    var body: some View {
        Canvas { ctx, size in
            guard samples.count > 1 else { return }
            let domain = max(peak, 0.05)
            var path = Path()
            for (i, v) in samples.enumerated() {
                let x = size.width * Double(i) / Double(samples.count - 1)
                let y = size.height * (1.0 - min(1.0, v / domain))
                if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            ctx.stroke(path, with: .color(GPUVariantPalette.teal), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
            let thresholdY = size.height * (1.0 - min(1.0, 0.30 / domain))
            var dash = Path()
            dash.move(to: CGPoint(x: 0, y: thresholdY))
            dash.addLine(to: CGPoint(x: size.width, y: thresholdY))
            ctx.stroke(dash, with: .color(GPUVariantPalette.text4), style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
        }
        .frame(height: height)
    }
}

struct GPUVariantMediaSession: Identifiable {
    let id = UUID()
    let codec: String
    let kind: String
    let owner: String
    let detail: String
    let duration: String
}

enum GPUVariantMedia {
    static func sample(decoderActive: Bool) -> [GPUVariantMediaSession] {
        guard decoderActive else { return [] }
        return [
            GPUVariantMediaSession(
                codec: "DEC", kind: "Decoder",
                owner: "Safari",
                detail: "H.264 \u{00B7} 1920\u{00D7}1080 \u{00B7} 30 fps \u{00B7} 6.4 Mb/s",
                duration: "12.3 s"
            )
        ]
    }
}

struct GPUVariantFootnote: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 10))
            .foregroundStyle(GPUVariantPalette.text4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// Placeholder card shown when coreCount is 0 (GPU not yet sampled or unavailable).
struct GPUVariantNotDetectedCard: View {
    var body: some View {
        GPUVariantPanel {
            HStack(spacing: 10) {
                Circle()
                    .fill(GPUVariantPalette.text4)
                    .frame(width: 6, height: 6)
                Text("GPU not detected")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(GPUVariantPalette.text)
                Spacer()
            }
            Text("Per-core view requires a non-zero shader-core count from IOAccelerator. Waiting for first sample, or GPU is unavailable on this device.")
                .font(.system(size: 11))
                .foregroundStyle(GPUVariantPalette.text3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

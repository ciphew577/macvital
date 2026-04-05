// MacVital/Views/Shared/MenuBarIconLabel.swift
//
// The SwiftUI view used as MenuBarExtra's `label:`. Renders the
// user-chosen icon style — either a static SF Symbol or live data
// (text / sparkline). Sits in the macOS menu bar next to Wi-Fi,
// clock, etc. Must be lightweight; redraws on every monitor tick.

import SwiftUI

struct MenuBarIconLabel: View {
    let style: MenuBarIconStyle
    let monitor: SystemMonitor

    var body: some View {
        switch style {
        // MARK: - Static SF Symbol styles
        case .symbolHeartbeat, .symbolGauge, .symbolCPU, .symbolThermometer:
            staticSymbolLabel

        // MARK: - Live styles
        case .liveCompositeHealth:
            liveTextLabel(text: compositeHealthText, symbol: "heart.text.square")

        case .liveCPUPercent:
            liveTextLabel(text: cpuPercentText, symbol: "cpu")

        case .liveHottestTemp:
            liveTextLabel(text: hottestTempText, symbol: "thermometer.medium")

        case .liveSparkline:
            sparklineLabel
        }
    }

    // MARK: - Static symbol with severity awareness

    private var staticSymbolLabel: some View {
        let symbolName: String = {
            // Show warning/critical overrides on the static symbols
            switch monitor.alertEngine.worstSeverity {
            case .warning:  return "exclamationmark.triangle"
            case .critical: return "exclamationmark.octagon"
            case .good:     return style.sfSymbolName ?? "waveform.path.ecg"
            }
        }()
        return Image(systemName: symbolName)
    }

    // MARK: - Live text (2-digit number + small symbol)

    private func liveTextLabel(text: String, symbol: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: symbol)
                .imageScale(.small)
            Text(text)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .monospacedDigit()
        }
    }

    // MARK: - Live sparkline (tiny CPU history graph)

    private var sparklineLabel: some View {
        HStack(spacing: 3) {
            Image(systemName: "waveform.path.ecg")
                .imageScale(.small)
            MenuBarSparkline(data: monitor.cpuHistory)
                .frame(width: 36, height: 14)
        }
    }

    // MARK: - Data accessors

    private var compositeHealthText: String {
        // Derive a simple composite: average of CPU headroom, memory headroom, thermal headroom
        let cpuHeadroom = max(0, 100 - (monitor.cpu?.totalUsage ?? 0))
        let memPressure: Double = {
            switch monitor.memory?.pressureLevel {
            case .nominal: return 95
            case .warning: return 60
            case .critical: return 25
            case nil: return 95
            }
        }()
        let thermalHeadroom: Double = {
            let maxTemp = monitor.sensors?.sensors.map(\.value).max() ?? 0
            if maxTemp >= 95 { return 30 }
            if maxTemp >= 80 { return 60 }
            return 95
        }()
        let composite = Int((cpuHeadroom + memPressure + thermalHeadroom) / 3)
        return "\(min(99, max(0, composite)))"
    }

    private var cpuPercentText: String {
        let cpu = monitor.cpu?.totalUsage ?? 0
        return String(format: "%.0f%%", cpu)
    }

    private var hottestTempText: String {
        let maxTemp = monitor.sensors?.sensors.map(\.value).max() ?? 0
        if maxTemp > 0 {
            return "\(Int(maxTemp))\u{00B0}"
        }
        return "--\u{00B0}"
    }
}

// MARK: - Tiny sparkline for menu bar (drawn with Path, not Charts — lighter weight)

private struct MenuBarSparkline: View {
    let data: [Double]

    var body: some View {
        GeometryReader { geo in
            let values = data.isEmpty ? [0.0] : data
            let maxVal = max(values.max() ?? 1, 1)
            let step = geo.size.width / CGFloat(max(values.count - 1, 1))

            Path { path in
                for (i, val) in values.enumerated() {
                    let x = CGFloat(i) * step
                    let y = geo.size.height - (CGFloat(val / maxVal) * geo.size.height)
                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(Color.primary.opacity(0.8), lineWidth: 1)
        }
    }
}

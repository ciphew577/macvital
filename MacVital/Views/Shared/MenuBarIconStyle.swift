// MacVital/Views/Shared/MenuBarIconStyle.swift
//
// Enum of selectable menu bar icon styles. Persisted to UserDefaults.
// Each case is either a static SF Symbol or a live-updating display.

import Foundation

enum MenuBarIconStyle: String, CaseIterable, Identifiable, Codable {
    // Static SF Symbol styles
    case symbolHeartbeat
    case symbolGauge
    case symbolCPU
    case symbolThermometer

    // Live-updating styles
    case liveCompositeHealth
    case liveCPUPercent
    case liveHottestTemp
    case liveSparkline

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .symbolHeartbeat:    return "Heartbeat"
        case .symbolGauge:        return "Gauge"
        case .symbolCPU:          return "Processor"
        case .symbolThermometer:  return "Thermometer"
        case .liveCompositeHealth: return "Health Score"
        case .liveCPUPercent:     return "CPU %"
        case .liveHottestTemp:    return "Temperature"
        case .liveSparkline:      return "Sparkline"
        }
    }

    var description: String {
        switch self {
        case .symbolHeartbeat:
            return "ECG waveform — a subtle health-monitoring vibe"
        case .symbolGauge:
            return "Gauge dial — classic system monitor feel"
        case .symbolCPU:
            return "Chip icon — minimal and technical"
        case .symbolThermometer:
            return "Thermometer — focus on thermals"
        case .liveCompositeHealth:
            return "Two-digit health score that updates every poll"
        case .liveCPUPercent:
            return "Live CPU usage percentage"
        case .liveHottestTemp:
            return "Hottest sensor reading in degrees, like TG Pro"
        case .liveSparkline:
            return "Tiny CPU history graph, like Stats.app"
        }
    }

    /// SF Symbol name for static icon styles. Nil for live styles.
    var sfSymbolName: String? {
        switch self {
        case .symbolHeartbeat:    return "waveform.path.ecg"
        case .symbolGauge:        return "gauge.with.dots.needle.bottom.50percent"
        case .symbolCPU:          return "cpu"
        case .symbolThermometer:  return "thermometer.medium"
        case .liveCompositeHealth, .liveCPUPercent, .liveHottestTemp, .liveSparkline:
            return nil
        }
    }

    /// Whether this style shows live-updating content.
    var isLive: Bool {
        sfSymbolName == nil
    }

    /// The SF Symbol shown as a fallback/preview for live styles.
    var previewSymbol: String {
        switch self {
        case .symbolHeartbeat:    return "waveform.path.ecg"
        case .symbolGauge:        return "gauge.with.dots.needle.bottom.50percent"
        case .symbolCPU:          return "cpu"
        case .symbolThermometer:  return "thermometer.medium"
        case .liveCompositeHealth: return "heart.text.square"
        case .liveCPUPercent:     return "cpu"
        case .liveHottestTemp:    return "thermometer.medium"
        case .liveSparkline:      return "chart.xyaxis.line"
        }
    }

    // MARK: - Persistence

    private static let defaultsKey = "menuBarIconStyle"

    static func load() -> MenuBarIconStyle {
        guard let raw = UserDefaults.standard.string(forKey: defaultsKey),
              let style = MenuBarIconStyle(rawValue: raw) else {
            return .symbolHeartbeat
        }
        return style
    }

    func save() {
        UserDefaults.standard.set(rawValue, forKey: MenuBarIconStyle.defaultsKey)
    }
}

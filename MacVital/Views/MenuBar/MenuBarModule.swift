// MacVital/Views/MenuBar/MenuBarModule.swift
//
// Multi-module menu bar system.
//
// Architecture:
//   - MenuBarModule enum defines 9 system modules
//   - MenuBarWidgetType defines 6 visual styles:
//     text, sparkline, barChart, miniGauge, textPair, battery
//   - MenuBarModuleManager orchestrates NSStatusItems + the shared popover
//   - Each module renders its widget via MenuBarWidgetNSView (NSView subclass)

import Foundation

// MARK: - Module Definition

enum MenuBarModule: String, CaseIterable, Identifiable, Codable {
    case cpu
    case memory
    case thermal
    case power
    case gpu
    case fans
    case network
    case battery
    case storage

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cpu:      return "CPU"
        case .memory:   return "Memory"
        case .thermal:  return "Thermal"
        case .power:    return "Power"
        case .gpu:      return "GPU"
        case .fans:     return "Fans"
        case .network:  return "Network"
        case .battery:  return "Battery"
        case .storage:  return "Storage"
        }
    }

    var icon: String {
        switch self {
        case .cpu:      return "cpu"
        case .memory:   return "memorychip"
        case .thermal:  return "thermometer.medium"
        case .power:    return "bolt.fill"
        case .gpu:      return "gpu"
        case .fans:     return "fan"
        case .network:  return "network"
        case .battery:  return "battery.100percent"
        case .storage:  return "internaldrive"
        }
    }

    /// Widget types available for this module.
    var availableWidgetTypes: [MenuBarWidgetType] {
        switch self {
        case .cpu:      return [.text, .sparkline, .barChart, .miniGauge]
        case .memory:   return [.text, .barChart, .miniGauge]
        case .thermal:  return [.text, .sparkline]
        case .power:    return [.text, .sparkline]
        case .gpu:      return [.text, .sparkline, .barChart]
        case .fans:     return [.text]
        case .network:  return [.textPair, .sparkline]
        case .battery:  return [.battery, .text, .miniGauge]
        case .storage:  return [.text, .barChart]
        }
    }

    /// Default widget type when first enabled.
    var defaultWidgetType: MenuBarWidgetType {
        switch self {
        case .cpu:      return .sparkline
        case .memory:   return .text
        case .thermal:  return .text
        case .power:    return .text
        case .gpu:      return .text
        case .fans:     return .text
        case .network:  return .textPair
        case .battery:  return .battery
        case .storage:  return .text
        }
    }

    /// Whether this module is enabled by default on first launch.
    var enabledByDefault: Bool {
        switch self {
        case .cpu, .memory, .thermal, .battery: return true
        default: return false
        }
    }

    /// Default display order (lower = further left in menu bar).
    var defaultOrder: Int {
        switch self {
        case .cpu:      return 0
        case .memory:   return 1
        case .thermal:  return 2
        case .power:    return 3
        case .gpu:      return 4
        case .fans:     return 5
        case .network:  return 6
        case .battery:  return 7
        case .storage:  return 8
        }
    }
}

// MARK: - Widget Type

enum MenuBarWidgetType: String, CaseIterable, Identifiable, Codable {
    case text         // "34%", "72°", "15/24GB"
    case sparkline    // 60-point line chart, 38x14, sage stroke + fill
    case barChart     // horizontal stacked bar, 36x8, sage/dim segments
    case miniGauge    // 14x14 arc gauge, 270° sweep, sage fill
    case textPair     // stacked two-line text for network (down/up)
    case battery      // Apple-style battery outline with fill + percentage

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .text:        return "Text"
        case .sparkline:   return "Sparkline"
        case .barChart:    return "Bar Chart"
        case .miniGauge:   return "Mini Gauge"
        case .textPair:    return "Text Pair"
        case .battery:     return "Battery"
        }
    }

    var icon: String {
        switch self {
        case .text:        return "textformat.123"
        case .sparkline:   return "chart.xyaxis.line"
        case .barChart:    return "chart.bar.fill"
        case .miniGauge:   return "gauge.with.dots.needle.bottom.50percent"
        case .textPair:    return "arrow.up.arrow.down"
        case .battery:     return "battery.75percent"
        }
    }
}

// MARK: - Module Configuration (persisted per module)

struct MenuBarModuleConfig: Codable, Equatable {
    let module: MenuBarModule
    var enabled: Bool
    var widgetType: MenuBarWidgetType
    var order: Int

    // MARK: - UserDefaults persistence

    private static func key(_ module: MenuBarModule, _ suffix: String) -> String {
        "menubar.\(module.rawValue).\(suffix)"
    }

    static func load(for module: MenuBarModule) -> MenuBarModuleConfig {
        let defaults = UserDefaults.standard
        let enabledKey = key(module, "enabled")
        let widgetKey = key(module, "widgetType")
        let orderKey = key(module, "order")

        let hasConfig = defaults.object(forKey: enabledKey) != nil

        let enabled: Bool
        if hasConfig {
            enabled = defaults.bool(forKey: enabledKey)
        } else {
            enabled = module.enabledByDefault
        }

        let widgetType: MenuBarWidgetType
        if let raw = defaults.string(forKey: widgetKey),
           let wt = MenuBarWidgetType(rawValue: raw),
           module.availableWidgetTypes.contains(wt) {
            widgetType = wt
        } else {
            widgetType = module.defaultWidgetType
        }

        let order: Int
        if defaults.object(forKey: orderKey) != nil {
            order = defaults.integer(forKey: orderKey)
        } else {
            order = module.defaultOrder
        }

        return MenuBarModuleConfig(
            module: module,
            enabled: enabled,
            widgetType: widgetType,
            order: order
        )
    }

    func save() {
        let defaults = UserDefaults.standard
        let prefix = "menubar.\(module.rawValue)"
        defaults.set(enabled, forKey: "\(prefix).enabled")
        defaults.set(widgetType.rawValue, forKey: "\(prefix).widgetType")
        defaults.set(order, forKey: "\(prefix).order")
    }
}

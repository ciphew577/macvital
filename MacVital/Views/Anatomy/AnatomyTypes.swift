// MacVital/Views/Anatomy/AnatomyTypes.swift
//
// Canonical value types for the Anatomy tab (Wave 1, foundation only).
// NO SwiftUI-only state here. Foundation + SwiftUI for Color tokens only.
//
// Source mockup: mockups/redesign-2026-04-23/anatomy/fusion-1-bento-schematic.html
// Component IDs and category mapping mirror the HTML data-id and data-cat
// attributes so view code can match by stable identifier in later waves.

import SwiftUI

// MARK: - AnatomyCategory

/// Filter categories shown as chips in the left sidebar.
/// `all` is the default selection and means "no filter active".
/// `soc` is a special category for the U1 SoC: it never appears as a chip
/// (the sidebar enumerates only the 8 visible chips) and U1 stays bright
/// under any active filter via the AnatomyViewModel.isDimmed special case.
enum AnatomyCategory: String, CaseIterable, Identifiable, Sendable {
    case all
    case power
    case cooling
    case storage
    case audio
    case wireless
    case display
    case sensors
    case soc

    var id: String { rawValue }

    /// The 8 categories that render as visible sidebar chips. Excludes `soc`
    /// because U1 is anchor and not user-filterable.
    static var sidebarChips: [AnatomyCategory] {
        [.all, .power, .cooling, .storage, .audio, .wireless, .display, .sensors]
    }

    /// Human-readable chip label.
    var displayName: String {
        switch self {
        case .all:      return "All"
        case .power:    return "Power"
        case .cooling:  return "Cooling"
        case .storage:  return "Storage"
        case .audio:    return "Audio"
        case .wireless: return "Wireless"
        case .display:  return "Display"
        case .sensors:  return "Sensors"
        case .soc:      return "SoC"
        }
    }

    /// Per-category accent. Hex values mirror the HTML mockup chip colours.
    var accentColor: Color {
        switch self {
        case .all:      return MV.text2
        case .power:    return Color(red: 0.561, green: 0.682, blue: 0.600)  // #8FAE99
        case .cooling:  return Color(red: 0.753, green: 0.565, blue: 0.251)  // #C09040
        case .storage:  return Color(red: 0.482, green: 0.753, blue: 0.690)  // #7BC0B0
        case .audio:    return Color(red: 0.561, green: 0.682, blue: 0.600)  // #8FAE99
        case .wireless: return Color(red: 0.482, green: 0.584, blue: 0.753)  // #7B95C0
        case .display:  return Color(red: 0.608, green: 0.541, blue: 0.769)  // #9B8AC4
        case .sensors:  return MV.text3
        case .soc:      return MV.accentSage
        }
    }

    /// Number of perimeter components in this category, computed from the
    /// canonical AnatomyComponentID category map. `all` returns the total
    /// of components that belong to a sidebar-visible chip (excludes the
    /// SoC anchor so the ALL count matches the chip set).
    var count: Int {
        if self == .all {
            return AnatomyComponentID.allCases.filter { $0.category != .soc }.count
        }
        return AnatomyComponentID.allCases.filter { $0.category == self }.count
    }
}

// MARK: - AnatomyComponentID

/// Stable identifier for each of the 10 perimeter callouts in the HTML mockup.
/// Raw values match the HTML `data-id` attribute exactly so future view code
/// can address an SVG node or SwiftUI shape by the same key.
enum AnatomyComponentID: String, CaseIterable, Identifiable, Sendable {
    case u1
    case fan1
    case fan2
    case ant1
    case bt1
    case ic1
    case spk1
    case u3
    case lcd1
    case ant2

    var id: String { rawValue }

    /// Category used by the sidebar chip filter and the dim-when-filtered rule.
    /// Mirrors HTML mockup `data-pairs` per data-cat card mapping. U1 maps
    /// to the special `.soc` category which never shows as a chip; the
    /// AnatomyViewModel.isDimmed rule keeps U1 bright under every filter.
    var category: AnatomyCategory {
        switch self {
        case .u1:                return .soc
        case .fan1, .fan2:       return .cooling
        case .ant1, .ant2:       return .wireless
        case .bt1, .ic1:         return .power
        case .spk1:              return .audio
        case .u3:                return .storage
        case .lcd1:              return .display
        }
    }
}

// MARK: - Stat

/// One labelled metric line shown inside a perimeter callout block.
struct Stat: Identifiable, Sendable, Hashable {
    let id: String
    let label: String
    let value: String
    let unit: String
}

// MARK: - AnatomyComponent

/// A single perimeter callout: identifier, ref tag, descriptive name,
/// 1 to 4 stat rows, and the filter category it belongs to.
struct AnatomyComponent: Identifiable, Sendable {
    let id: AnatomyComponentID
    let refTag: String          // e.g. "U1"
    let name: String            // e.g. "APPLE M4 PRO"
    let stats: [Stat]
    let category: AnatomyCategory
}

// MARK: - AnatomyTraceKind

/// The four trace types animated between the chassis anchor and the
/// perimeter callout block. Colour aligns with the HTML stroke palette.
enum AnatomyTraceKind: String, CaseIterable, Sendable {
    case power
    case data
    case thermal
    case rf

    /// Trace stroke colour. Pulled from the CSS variables in the HTML mockup
    /// and held here so the SwiftUI canvas can paint without re-reading hex.
    var color: Color {
        switch self {
        case .power:   return Color(red: 0.561, green: 0.682, blue: 0.600)  // #8FAE99
        case .data:    return Color(red: 0.482, green: 0.584, blue: 0.753)  // #7B95C0
        case .thermal: return Color(red: 0.753, green: 0.565, blue: 0.251)  // #C09040
        case .rf:      return Color(red: 0.482, green: 0.753, blue: 0.690)  // #7BC0B0
        }
    }
}

// MARK: - AnatomyEvent

/// One row in the events feed shown beneath the sidebar chip stack.
struct AnatomyEvent: Identifiable, Sendable {
    let id: UUID
    let timestamp: Date
    let severity: Severity
    let message: String
    let category: AnatomyCategory

    enum Severity: String, Sendable {
        case ok
        case info
        case warn
    }

    init(id: UUID = UUID(), timestamp: Date, severity: Severity, message: String, category: AnatomyCategory) {
        self.id = id
        self.timestamp = timestamp
        self.severity = severity
        self.message = message
        self.category = category
    }
}

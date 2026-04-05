// MacVital/Views/Shared/MVPalette.swift
//
// Global palette system: 6 color schemes, observable store, Environment key.
//
// INTEGRATION NOTE (for main session after all agents merge):
// 1. Create the store in AppState:
//        @State var paletteStore = MVPaletteStore()
// 2. Inject into the root view hierarchy in MacVitalApp.swift:
//        .environment(\.mvPalette, appState.paletteStore.tokens)
//        .environment(appState.paletteStore)
// 3. Update MVColors.swift to read from the environment by making `MV.*`
//    computed properties that pull from @Environment(\.mvPalette). This is
//    a single-file edit for the main session.
// 4. Add PalettePickerDense to SettingsView as a new "Palette" row.

import SwiftUI

// MARK: - Palette identifiers

enum MVPaletteID: String, CaseIterable, Identifiable, Codable, Sendable {
    case sage
    case graphite
    case earth
    case arctic
    case pastel
    case ink

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sage:      return "Sage"
        case .graphite:  return "Graphite"
        case .earth:     return "Earth"
        case .arctic:    return "Arctic"
        case .pastel:    return "Pastel"
        case .ink:       return "Ink"
        }
    }
}

// MARK: - Observable store

@Observable
@MainActor
final class MVPaletteStore: Sendable {
    var selectedID: MVPaletteID = .sage {
        didSet { persist() }
    }

    var tokens: MVPaletteTokens { MVPaletteTokens.tokens(for: selectedID) }

    private let defaultsKey = "com.macvital.palette"

    init() { load() }

    private func load() {
        if let raw = UserDefaults.standard.string(forKey: defaultsKey),
           let id = MVPaletteID(rawValue: raw) {
            selectedID = id
        }
    }

    private func persist() {
        UserDefaults.standard.set(selectedID.rawValue, forKey: defaultsKey)
    }
}

// MARK: - Environment key

private struct MVPaletteKey: EnvironmentKey {
    static let defaultValue: MVPaletteTokens = .tokens(for: .sage)
}

extension EnvironmentValues {
    var mvPalette: MVPaletteTokens {
        get { self[MVPaletteKey.self] }
        set { self[MVPaletteKey.self] = newValue }
    }
}

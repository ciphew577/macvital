// MacVital/Views/Shared/MVPaletteTokens.swift
//
// MVPaletteTokens: environment-driven color token struct.
// Hex values sourced from mockups/redesign-2026-04-23/network/variant-f-fusion.html.
// The `tokens(for:)` factory is the single source of truth for all 6 palettes.
//
// Contrast policy (2026-04-25):
// - text3 at-rest targets ~4.5:1 vs bg (WCAG 1.4.3 AA body text).
// - text4 at-rest targets ~3:1 (non-essential / disabled). High-contrast variant
//   raises it to ~4.5:1 for users with `accessibilityReduceTransparency` on
//   or `colorSchemeContrast == .increased`.
// - hairline at-rest sits at ~0.18 alpha so dividers are actually visible without
//   shouting; the high-contrast variant lifts it further.

import SwiftUI

// MARK: - Token struct

struct MVPaletteTokens: Sendable {

    // Accent
    let accentSage:     Color   // primary accent (green/sage)
    let accentSageDim:  Color   // dimmed variant used on charts/lines
    let warning:        Color   // amber, thermal, warnings
    let warningDim:     Color
    let critical:       Color   // terra, errors, critical
    let criticalDim:    Color

    // Surfaces
    let bg:             Color   // page background
    let tile:           Color   // tile / card surface (surface in HTML)
    let tileHover:      Color   // tile on hover (surface2)
    let surface3:       Color   // deepest inset surface

    // Dividers (at-rest)
    let hairline:       Color   // default divider
    let hairlineStrong: Color   // hover/emphasis

    // Dividers (high-contrast variant for reduce-transparency / increased-contrast)
    let hairlineHC:     Color

    // Text ramp (at-rest)
    let text1:          Color   // primary text
    let text2:          Color   // secondary text
    let text3:          Color   // tertiary / label text (>= 4.5:1 vs bg)
    let text4:          Color   // ghost / disabled text (~3:1 vs bg)

    // Text ramp (high-contrast variant)
    let text3HC:        Color
    let text4HC:        Color

    // Semantic alias kept for Overview
    let ok:             Color   // score ring green (overrides accentSage for Overview)
}

// MARK: - High-contrast resolution

extension MVPaletteTokens {

    /// Return the contrast-appropriate text3.
    func text3(highContrast: Bool) -> Color { highContrast ? text3HC : text3 }

    /// Return the contrast-appropriate text4.
    func text4(highContrast: Bool) -> Color { highContrast ? text4HC : text4 }

    /// Return the contrast-appropriate hairline.
    func hairline(highContrast: Bool) -> Color { highContrast ? hairlineHC : hairline }
}

// MARK: - Environment helper

extension EnvironmentValues {

    /// True when the user has asked the system for higher-contrast UI via either
    /// `accessibilityReduceTransparency` (System Settings, Reduce Transparency)
    /// or `colorSchemeContrast == .increased` (Increase Contrast).
    var mvHighContrast: Bool {
        accessibilityReduceTransparency || colorSchemeContrast == .increased
    }
}

// MARK: - Factory

extension MVPaletteTokens {

    static func tokens(for id: MVPaletteID) -> MVPaletteTokens {
        switch id {
        case .sage:      return sage
        case .graphite:  return graphite
        case .earth:     return earth
        case .arctic:    return arctic
        case .pastel:    return pastel
        case .ink:       return ink
        }
    }

    // MARK: Sage (default), matches MV.* in MVColors.swift
    // bg #0f0f10, tile #16171a; accents from variant-f-fusion root palette
    private static let sage = MVPaletteTokens(
        accentSage:     hex("#9bc4a8"),
        accentSageDim:  hex("#6d9178"),
        warning:        hex("#d4a35a"),
        warningDim:     hex("#a07840"),
        critical:       hex("#c66648"),
        criticalDim:    hex("#8a4c3c"),
        bg:             hex("#0f0f10"),
        tile:           hex("#16171a"),
        tileHover:      hex("#1a1b1e"),
        surface3:       hex("#252629"),
        hairline:       Color.white.opacity(0.18),
        hairlineStrong: Color.white.opacity(0.28),
        hairlineHC:     Color.white.opacity(0.34),
        text1:          hex("#e8e6e3"),
        text2:          hex("#e8e6e3").opacity(0.60),
        text3:          hex("#e8e6e3").opacity(0.55),
        text4:          hex("#e8e6e3").opacity(0.40),
        text3HC:        hex("#e8e6e3").opacity(0.78),
        text4HC:        hex("#e8e6e3").opacity(0.55),
        ok:             hex("#7fc48f")
    )

    // MARK: Graphite Electric, bg #0a0c0e, tile #12151a
    // text3/4 are hex-based; brighter hex used to lift contrast vs the very dark bg.
    private static let graphite = MVPaletteTokens(
        accentSage:     hex("#5eead4"),
        accentSageDim:  hex("#2dd4bf"),
        warning:        hex("#fbbf24"),
        warningDim:     hex("#d4a014"),
        critical:       hex("#f97066"),
        criticalDim:    hex("#d64a40"),
        bg:             hex("#0a0c0e"),
        tile:           hex("#12151a"),
        tileHover:      hex("#181c22"),
        surface3:       hex("#1f242b"),
        hairline:       Color.white.opacity(0.18),
        hairlineStrong: Color.white.opacity(0.28),
        hairlineHC:     Color.white.opacity(0.34),
        text1:          hex("#e6e8ec"),
        text2:          hex("#9099a5"),
        text3:          hex("#8a93a0"),   // lifted from #5a6370 for ~4.5:1
        text4:          hex("#5a626d"),   // lifted from #363c46 for ~3:1
        text3HC:        hex("#b4bbc4"),
        text4HC:        hex("#8a93a0"),
        ok:             hex("#5eead4")
    )

    // MARK: Earth, bg #1a1412, tile #22191a
    private static let earth = MVPaletteTokens(
        accentSage:     hex("#d4a35a"),
        accentSageDim:  hex("#b58545"),
        warning:        hex("#e8a06b"),
        warningDim:     hex("#bd7c4e"),
        critical:       hex("#c66648"),
        criticalDim:    hex("#9e4f37"),
        bg:             hex("#1a1412"),
        tile:           hex("#22191a"),
        tileHover:      hex("#2a2022"),
        surface3:       hex("#312729"),
        hairline:       Color(red: 0.941, green: 0.902, blue: 0.839).opacity(0.20),
        hairlineStrong: Color(red: 0.941, green: 0.902, blue: 0.839).opacity(0.30),
        hairlineHC:     Color(red: 0.941, green: 0.902, blue: 0.839).opacity(0.36),
        text1:          hex("#f0e6d6"),
        text2:          hex("#b8a78f"),
        text3:          hex("#a89272"),   // lifted from #7a6a54 for ~4.5:1
        text4:          hex("#74624c"),   // lifted from #4a3f30 for ~3:1
        text3HC:        hex("#cab394"),
        text4HC:        hex("#a89272"),
        ok:             hex("#d4a35a")
    )

    // MARK: Arctic, bg #0d1117, tile #161b22
    private static let arctic = MVPaletteTokens(
        accentSage:     hex("#7ab4d6"),
        accentSageDim:  hex("#5a9bc1"),
        warning:        hex("#e0b26b"),
        warningDim:     hex("#b38847"),
        critical:       hex("#e87c6b"),
        criticalDim:    hex("#b95d50"),
        bg:             hex("#0d1117"),
        tile:           hex("#161b22"),
        tileHover:      hex("#1d232c"),
        surface3:       hex("#252b36"),
        hairline:       Color.white.opacity(0.18),
        hairlineStrong: Color.white.opacity(0.28),
        hairlineHC:     Color.white.opacity(0.34),
        text1:          hex("#e6edf3"),
        text2:          hex("#9aa5b1"),
        text3:          hex("#8a93a0"),   // lifted from #5b6470 for ~4.5:1
        text4:          hex("#5b626d"),   // lifted from #383f49 for ~3:1
        text3HC:        hex("#b4bbc4"),
        text4HC:        hex("#8a93a0"),
        ok:             hex("#7ab4d6")
    )

    // MARK: Pastel, bg #0a0a18, tile #111125
    private static let pastel = MVPaletteTokens(
        accentSage:     hex("#ffb3c1"),
        accentSageDim:  hex("#e89cac"),
        warning:        hex("#ffd29a"),
        warningDim:     hex("#d4a874"),
        critical:       hex("#b596ff"),
        criticalDim:    hex("#8d74cc"),
        bg:             hex("#0a0a18"),
        tile:           hex("#111125"),
        tileHover:      hex("#171a30"),
        surface3:       hex("#1e223d"),
        hairline:       Color(red: 0.961, green: 0.937, blue: 0.973).opacity(0.20),
        hairlineStrong: Color(red: 0.961, green: 0.937, blue: 0.973).opacity(0.30),
        hairlineHC:     Color(red: 0.961, green: 0.937, blue: 0.973).opacity(0.36),
        text1:          hex("#f5eef8"),
        text2:          hex("#b0a8c0"),
        text3:          hex("#9b95b0"),   // lifted from #6e6884 for ~4.5:1
        text4:          hex("#67627c"),   // lifted from #413e56 for ~3:1
        text3HC:        hex("#bcb6cc"),
        text4HC:        hex("#9b95b0"),
        ok:             hex("#ffb3c1")
    )

    // MARK: Ink, bg #0e0f10, tile #15171a
    private static let ink = MVPaletteTokens(
        accentSage:     hex("#c7d0c8"),
        accentSageDim:  hex("#a6b1a8"),
        warning:        hex("#c7b79a"),
        warningDim:     hex("#a69878"),
        critical:       hex("#c89a8a"),
        criticalDim:    hex("#a87c6c"),
        bg:             hex("#0e0f10"),
        tile:           hex("#15171a"),
        tileHover:      hex("#1c1f22"),
        surface3:       hex("#23272a"),
        hairline:       Color.white.opacity(0.18),
        hairlineStrong: Color.white.opacity(0.27),
        hairlineHC:     Color.white.opacity(0.34),
        text1:          hex("#e8e9ea"),
        text2:          hex("#9a9ea1"),
        text3:          hex("#8b9094"),   // lifted from #5e6265 for ~4.5:1
        text4:          hex("#5d6164"),   // lifted from #393c3e for ~3:1
        text3HC:        hex("#b4b8bb"),
        text4HC:        hex("#8b9094"),
        ok:             hex("#c7d0c8")
    )
}

// MARK: - Hex helper (file-private)

private func hex(_ value: String) -> Color {
    var s = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if s.hasPrefix("#") { s = String(s.dropFirst()) }
    guard s.count == 6, let n = UInt64(s, radix: 16) else {
        return .clear
    }
    let r = Double((n >> 16) & 0xff) / 255.0
    let g = Double((n >> 8)  & 0xff) / 255.0
    let b = Double(n         & 0xff) / 255.0
    return Color(red: r, green: g, blue: b)
}

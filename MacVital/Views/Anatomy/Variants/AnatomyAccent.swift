// MacVital/Views/Anatomy/Variants/AnatomyAccent.swift
//
// Anatomy-local accent tokens. The shared MV palette only exposes a single
// sage/warning/critical triad, but the four schematic variants
// (Exploded, CrossSection, Wiring, iFixit) need a richer four-tone palette
// to differentiate component categories: power, thermal, signal, display.
//
// Values are sourced from the Graphite-scoped accent set used in the
// 2026-04-23 redesign mockups. Anatomy is the only consumer; keeping these
// scoped here avoids polluting MVColors / MVPaletteTokens with single-use
// tokens.
//
// amber  -> thermal (fans, heat-sensitive components)
// sage   -> power (battery, PMU, speakers)
// blue   -> signal / data (SoC, antennas, SSD)
// purple -> display (LCD)

import SwiftUI

enum AnatomyAccent {
    static let amber:  Color = Color(red: 0.753, green: 0.565, blue: 0.251)
    static let sage:   Color = Color(red: 0.561, green: 0.682, blue: 0.600)
    static let blue:   Color = Color(red: 0.482, green: 0.584, blue: 0.753)
    static let purple: Color = Color(red: 0.608, green: 0.541, blue: 0.769)
}

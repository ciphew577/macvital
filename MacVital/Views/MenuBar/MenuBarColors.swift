// MacVital/Views/MenuBar/MenuBarColors.swift
//
// Design tokens for the v4 Control Center + Sankey menu bar popover.
//
// HYBRID PALETTE (2026-04-12):
//   • Category hue lives ONLY in the SF Symbol icon fill. All category
//     hues sit in the SAME perceptual luminance band (LCH L ≈ 55, C ≈ 22)
//     so no single tile shouts louder than the others. The eye can still
//     find "this is the CPU tile" at a glance but nothing reads as
//     decorative rainbow.
//   • Value digits use the SEMANTIC state ramp from
//     v4-colour-semantic.html — at rest everything is warm dim text;
//     only out-of-nominal metrics flip to sage / amber / terracotta.
//     This is the "alive but honest" variant: colour fires when the
//     system actually has something to say.
//   • Influences: Warp terminal (#0B0C0F + single sage accent),
//     Raycast (neutral chrome, one accent per row state),
//     Linear 2024 (muted greys + disciplined hue),
//     Apple Tahoe Control Center (neutral tiles, colour in glyph only).
//
// Do NOT mutate MVColors — Overview has a parallel refactor in flight.

import SwiftUI

enum MVMenu {

    // MARK: - Popover chrome

    /// Warm off-black popover surface — #0a0a0b.
    static let popBg       = Color(red: 0.039, green: 0.039, blue: 0.043)
    /// Tile surface — 4% warm white on popBg.
    static let tile        = Color.white.opacity(0.04)
    /// Tile surface on hover — 7.5% warm white.
    static let tileHover   = Color.white.opacity(0.075)
    /// Hairline 0.5 pt border.
    static let hair        = Color.white.opacity(0.06)
    /// Stronger hairline for active borders / popover outline.
    static let hairStrong  = Color.white.opacity(0.11)
    /// Pill / readout chip background.
    static let pillBg      = Color.white.opacity(0.055)
    /// Slider rail track.
    static let rail        = Color.white.opacity(0.10)
    /// Slider rail fill — warm dim text token.
    static let railFill    = Color(red: 0.910, green: 0.902, blue: 0.890).opacity(0.72)

    // MARK: - Text ramp (warm off-white #e8e6e3)

    /// Primary text — warm #e8e6e3.
    static let text        = Color(red: 0.910, green: 0.902, blue: 0.890)
    static let textDim     = Color(red: 0.910, green: 0.902, blue: 0.890).opacity(0.60)
    static let textFaint   = Color(red: 0.910, green: 0.902, blue: 0.890).opacity(0.38)
    static let textGhost   = Color(red: 0.910, green: 0.902, blue: 0.890).opacity(0.22)

    // MARK: - Severity ramp (value-digit overlay + corner dot)
    // Lifted verbatim from v4-colour-semantic.html. These colours only
    // appear on values that have left the nominal band — otherwise
    // values render in `text`.

    /// Muted sage #9bc4a8 — "elevated but OK" (watch).
    static let sevOk       = Color(red: 0.608, green: 0.769, blue: 0.659)
    /// Muted amber #d4a35a — approaching limit (warn).
    static let sevWarn     = Color(red: 0.831, green: 0.639, blue: 0.353)
    /// Muted terracotta #c66648 — out of spec (critical).
    static let sevBad      = Color(red: 0.776, green: 0.400, blue: 0.282)
    /// Neutral slate #8d97a1 — fallback icon tint.
    static let sevNeutral  = Color(red: 0.553, green: 0.592, blue: 0.631)

    // MARK: - Category hues (SF Symbol icon fill only)
    // All hues tuned to LCH L≈55, C≈22 so they read as quietly coloured,
    // not decorative. Each is a desaturated shift of the old candy
    // palette — hue preserved so category identity is still recognisable,
    // chroma dropped ~40%, luminance aligned.

    /// CPU — muted cool blue #8a9fc2 (was #7aa2f7).
    static let cpu         = Color(red: 0.541, green: 0.624, blue: 0.761)
    /// Thermal — warm terracotta-brown #c8936a (was #e5a06b).
    static let thermal     = Color(red: 0.784, green: 0.576, blue: 0.416)
    /// Power — muted plum #a890c2 (was #b38cf7). Also Sankey stream.
    static let power       = Color(red: 0.659, green: 0.565, blue: 0.761)
    /// Memory — muted teal #7fa7a6 (was #78c8d1).
    static let memory      = Color(red: 0.498, green: 0.655, blue: 0.651)
    /// Wi-Fi — muted sage #8fb199 (was #9bc4a8).
    static let wifi        = Color(red: 0.561, green: 0.694, blue: 0.600)
    /// Battery — muted forest green #8bb58e (was #7fc48f).
    static let battery     = Color(red: 0.545, green: 0.710, blue: 0.557)
    /// Slate — fans, storage, uptime fallback — #8d97a1.
    static let slate       = Color(red: 0.553, green: 0.592, blue: 0.631)

    /// Product accent — sage #9bc4a8 (header live dot, hover accent bar).
    /// Matches Overview `MV.accentSage` exactly so the two windows
    /// read as one product.
    static let accent      = Color(red: 0.608, green: 0.769, blue: 0.659)
    static let accentSoft  = Color(red: 0.608, green: 0.769, blue: 0.659).opacity(0.16)

    // MARK: - Semantic value-digit resolver
    //
    // Per the v4-colour-semantic rule: the numeric reading in a tile
    // shifts by state, NOT by category. At rest everything is `text`;
    // only the metrics that leave nominal flip colour. Call this from
    // any tile-building code that already knows its state.

    /// Resolve value-digit colour for a tile severity.
    static func valueColor(for severity: ValueSeverity) -> Color {
        switch severity {
        case .nominal: return text
        case .watch:   return sevOk
        case .warn:    return sevWarn
        case .crit:    return sevBad
        }
    }

    /// 4-level semantic state matching v4-colour-semantic.html.
    /// Distinct from `MenuBarTile.TileSeverity` which only models the
    /// corner-dot states (nominal / watch / critical).
    enum ValueSeverity {
        case nominal   // everything fine — warm dim text
        case watch     // elevated but OK — sage
        case warn      // approaching limit — amber
        case crit      // out of spec — terracotta
    }

    // MARK: - Geometry tokens

    enum Geo {
        static let popWidth: CGFloat   = 340
        static let popPadding: CGFloat = 16
        static let innerWidth: CGFloat = 308   // popWidth - 2*padding
        static let tileGap: CGFloat    = 12
        static let tileRadius: CGFloat = 12
        static let tileHeight: CGFloat = 74
        static let stripHeight: CGFloat = 58
        static let sankeyHeight: CGFloat = 100
    }

    // MARK: - Type scale (mirrors v4 mockup tokens)

    enum FS {
        static let micro:   CGFloat = 10
        static let caption: CGFloat = 11
        static let body:    CGFloat = 12
        static let value:   CGFloat = 13
        static let h3:      CGFloat = 20
    }
}

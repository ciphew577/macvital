// MacVital/Views/Overview/MVColors.swift
//
// Design tokens for the editorial-bento Overview redesign (2026-04-11).
// Color tokens are now palette-driven via MVPaletteTokens. Switching
// MVPaletteStore.selectedID instantly re-tints every view that reads MV.*
// because all color vars forward to `MV.current` which is updated on every
// palette change from MacVitalApp via MV.setPalette(_:).
//
// Spacing (S.*), typography (FS.*), and radius stay static -- not palette-driven.

import SwiftUI

enum MV {

    // MARK: - Live palette state

    /// Current resolved token set. Seeded at .sage on launch; updated via
    /// `setPalette(_:)` whenever MVPaletteStore.selectedID changes.
    /// `nonisolated(unsafe)` allows synchronous reads from any context --
    /// writes only ever happen on the main actor via `setPalette(_:)`.
    nonisolated(unsafe) private(set) static var current: MVPaletteTokens = .tokens(for: .sage)

    /// Called by MacVitalApp whenever the store's selectedID changes.
    /// Must be called on the main actor (SwiftUI onChange is always on main).
    @MainActor
    static func setPalette(_ tokens: MVPaletteTokens) {
        current = tokens
    }

    // MARK: - Surface tokens (forwarded to current palette)

    static var bg:             Color { current.bg }
    static var tile:           Color { current.tile }
    static var tileHover:      Color { current.tileHover }
    static var hairline:       Color { current.hairline }
    static var hairlineStrong: Color { current.hairlineStrong }

    // MARK: - Text ramp

    static var text1: Color { current.text1 }
    static var text2: Color { current.text2 }
    static var text3: Color { current.text3 }
    static var text4: Color { current.text4 }

    // MARK: - Accent palette

    static var ok:         Color { current.ok }
    static var accentSage: Color { current.accentSage }

    // Per-subsystem aliases -- all forward to accentSage so the rest of the
    // codebase keeps compiling without changes. thermal maps to warning;
    // fan maps to text3.
    static var cpu:     Color { current.accentSage }
    static var gpu:     Color { current.accentSage }
    static var mem:     Color { current.accentSage }
    static var net:     Color { current.accentSage }
    static var bat:     Color { current.accentSage }
    static var thermal: Color { current.warning }
    static var fan:     Color { current.text3 }

    // MARK: - Semantic

    static var warning:  Color { current.warning }
    static var critical: Color { current.critical }

    // MARK: - Type scale (1.25 modular -- not palette-dependent)

    enum FS {
        static let micro:   CGFloat = 10
        static let caption: CGFloat = 11
        static let body:    CGFloat = 12
        static let value:   CGFloat = 13
        static let h3:      CGFloat = 20
        static let h2:      CGFloat = 28
        static let h1:      CGFloat = 36
        static let display: CGFloat = 44
    }

    // MARK: - Spacing scale (4-base -- not palette-dependent)

    enum S {
        static let s1: CGFloat = 4
        static let s2: CGFloat = 8
        static let s3: CGFloat = 12
        static let s4: CGFloat = 16
        static let s5: CGFloat = 20
        static let s6: CGFloat = 24
    }

    static let radius: CGFloat = 12
}

// MARK: - Tile modifier

/// Shared tile chrome: surface + hairline border + rounded corners + padding.
/// Every tile in the Overview bento uses this.
struct MVTile<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder _ content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .padding(.horizontal, MV.S.s4)
            .padding(.vertical, MV.S.s3)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(MV.tile)
            .overlay(
                RoundedRectangle(cornerRadius: MV.radius)
                    .strokeBorder(MV.hairline, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: MV.radius))
    }
}

// MARK: - Tile head (eyebrow label + optional hint)

struct MVTileHead: View {
    let label: String
    var hint: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label.uppercased())
                .font(.system(size: MV.FS.micro, weight: .semibold))
                .tracking(1.1)
                .foregroundStyle(MV.text3)
            Spacer(minLength: 4)
            if let hint {
                Text(hint)
                    .font(.system(size: MV.FS.micro))
                    .foregroundStyle(MV.text4)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Tile hero numeric (used by CPU / GPU / MEM / PWR / BAT)

/// A large numeric value followed by a subordinated unit suffix.
/// The unit sits at 0.48 opacity, slightly below the value baseline.
struct MVTileNumber: View {
    let value: String
    let unit: String
    var color: Color? = nil
    var size: CGFloat = MV.FS.h2

    private var resolvedColor: Color { color ?? MV.text1 }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value)
                .font(.system(size: size, weight: .semibold))
                .tracking(-0.6)
                .foregroundStyle(resolvedColor)
                .monospacedDigit()
            Text(unit)
                .font(.system(size: MV.FS.body, weight: .medium))
                .foregroundStyle(MV.text3)
                .baselineOffset(1)
        }
    }
}

// MARK: - Tile subline (caption text pinned below)

struct MVTileSub: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: MV.FS.caption))
            .foregroundStyle(MV.text2)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Shared thin progress bar (3px)

struct MVBar: View {
    let value: Double         // 0...1
    var color: Color? = nil

    private var resolvedColor: Color { color ?? MV.text2 }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.055))
                Capsule()
                    .fill(resolvedColor)
                    .frame(width: geo.size.width * max(0, min(1, value)))
            }
        }
        .frame(height: 3)
    }
}

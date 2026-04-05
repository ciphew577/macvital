// MacVital/Views/MenuBar/MenuBarView.swift
//
// Thin wrapper around `MenuBarContent` — the v4 Control Center + Sankey
// popover. This file used to own the entire bars-style popover (417 lines);
// the new design lives in its own modular components under the same folder:
//   • MenuBarColors.swift     — MVMenu design tokens
//   • MenuBarTile.swift       — 2×3 tile grid cell
//   • MenuBarSliderStrip.swift — fans / storage rail
//   • SankeyPowerFlow.swift   — hero Canvas Sankey
//   • MenuBarContent.swift    — composition + data wiring
//
// Replaces: mockups/redesign-2026-04-11/menubar/v4-final/
//           v4-control-center-sankey.html + v4-colour-category.html

import SwiftUI

struct MenuBarView: View {
    var body: some View {
        MenuBarContent()
    }
}

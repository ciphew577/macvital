// MacVital/Views/MenuBar/MenuBarTabBar.swift
//
// Underline-indicator sub-tab bar for the menu bar popover. Six tabs:
// ALL · DTL · NET · PROC · SENS · PWR. Selected tab tints its icon to
// the corresponding category hue and gets a 1.5 pt sage underline that
// slides between tabs (240 ms cubic-bezier).
//
// Matches the v6a-refined mockup grammar — Apple-native segmented look,
// not Material chips.

import SwiftUI

enum MenuBarTab: Int, CaseIterable, Identifiable {
    case glance, detail, network, procs, sensors, power

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .glance:  return "ALL"
        case .detail:  return "DTL"
        case .network: return "NET"
        case .procs:   return "PROC"
        case .sensors: return "SENS"
        case .power:   return "PWR"
        }
    }

    var iconSystemName: String {
        switch self {
        case .glance:  return "square.grid.2x2"
        case .detail:  return "cpu"
        case .network: return "wifi"
        case .procs:   return "list.bullet.rectangle"
        case .sensors: return "thermometer.medium"
        case .power:   return "bolt.fill"
        }
    }

    /// Category hue applied to the icon when this tab is selected.
    /// Sage for `glance` (the product accent), category-specific
    /// otherwise so the chrome echoes the v4 palette.
    var selectedTint: Color {
        switch self {
        case .glance:  return MVMenu.accent
        case .detail:  return MVMenu.cpu
        case .network: return MVMenu.wifi
        case .procs:   return MVMenu.memory
        case .sensors: return MVMenu.thermal
        case .power:   return MVMenu.power
        }
    }
}

struct MenuBarTabBar: View {
    @Binding var selection: MenuBarTab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let tabWidth = (geo.size.width - 4) / CGFloat(MenuBarTab.allCases.count)
            ZStack(alignment: .bottomLeading) {
                HStack(spacing: 0) {
                    ForEach(MenuBarTab.allCases) { tab in
                        Button {
                            selection = tab
                        } label: {
                            tabLabel(tab)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(Text(tab.label))
                        .accessibilityAddTraits(selection == tab ? [.isSelected, .isButton] : .isButton)
                    }
                }

                // Sage underline indicator — slides between tabs.
                Rectangle()
                    .fill(MVMenu.accent)
                    .frame(width: tabWidth, height: 1.5)
                    .cornerRadius(1)
                    .offset(x: 2 + CGFloat(selection.rawValue) * tabWidth, y: 0)
                    .animation(
                        reduceMotion ? nil : .timingCurve(0.32, 0.72, 0.16, 1, duration: 0.24),
                        value: selection
                    )
            }
        }
        .frame(height: 36)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MVMenu.hair)
                .frame(height: 0.5)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("MacVital sub-modules"))
    }

    @ViewBuilder
    private func tabLabel(_ tab: MenuBarTab) -> some View {
        let isOn = selection == tab
        VStack(spacing: 4) {
            Image(systemName: tab.iconSystemName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isOn ? tab.selectedTint : MVMenu.textFaint)
                .opacity(isOn ? 1 : 0.65)
            Text(tab.label)
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(isOn ? MVMenu.text : MVMenu.textFaint)
        }
        .padding(.top, 8)
        .padding(.bottom, 9)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

#Preview("Tab bar — Glance") {
    StatefulPreview()
        .frame(width: 308)
        .padding()
        .background(MVMenu.popBg)
}

private struct StatefulPreview: View {
    @State private var selection: MenuBarTab = .glance
    var body: some View {
        VStack(spacing: 16) {
            MenuBarTabBar(selection: $selection)
            Text("Selected: \(selection.label)")
                .font(.caption)
                .foregroundStyle(MVMenu.textDim)
        }
    }
}

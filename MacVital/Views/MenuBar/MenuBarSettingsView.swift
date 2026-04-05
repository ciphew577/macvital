// MacVital/Views/MenuBar/MenuBarSettingsView.swift
//
// Settings UI for the multi-module menu bar widget system.
// Embedded in the existing SettingsView. Lets users:
//   - Toggle each module on/off in the menu bar
//   - Pick the widget style for each enabled module
//   - See a live preview of what each widget type looks like
//
// Does NOT touch the popover design (MenuBarContent, tiles, Sankey, etc.).

import SwiftUI

struct MenuBarSettingsView: View {
    @Environment(AppState.self) private var appState

    private var manager: MenuBarModuleManager {
        appState.menuBarModuleManager
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Menu Bar Widgets")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Add per-module widgets to the menu bar. Each shows live data and opens the full popover when clicked.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            // Active count badge
            if manager.activeCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "menubar.rectangle")
                        .foregroundStyle(.secondary)
                    Text("\(manager.activeCount) widget\(manager.activeCount == 1 ? "" : "s") active in menu bar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // Module list
            VStack(spacing: 2) {
                ForEach(manager.configs, id: \.module) { config in
                    MenuBarModuleRow(
                        config: config,
                        onToggle: { enabled in
                            manager.setEnabled(enabled, for: config.module)
                        },
                        onWidgetTypeChange: { type in
                            manager.setWidgetType(type, for: config.module)
                        }
                    )
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Per-module row

private struct MenuBarModuleRow: View {
    let config: MenuBarModuleConfig
    let onToggle: (Bool) -> Void
    let onWidgetTypeChange: (MenuBarWidgetType) -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Main row: icon + name + toggle
            HStack(spacing: 12) {
                Image(systemName: config.module.icon)
                    .frame(width: 20)
                    .foregroundStyle(config.enabled ? .primary : .tertiary)

                Text(config.module.displayName)
                    .font(.body)
                    .foregroundStyle(config.enabled ? .primary : .secondary)

                Spacer()

                if config.enabled {
                    // Widget type picker (compact)
                    widgetTypePicker
                }

                Toggle("", isOn: Binding(
                    get: { config.enabled },
                    set: { onToggle($0) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())

            // Expanded: show all widget type options with previews
            if config.enabled && isExpanded {
                widgetTypeGrid
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(config.enabled ? Color.primary.opacity(0.04) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .animation(.easeInOut(duration: 0.2), value: config.enabled)
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }

    private var widgetTypePicker: some View {
        Menu {
            ForEach(config.module.availableWidgetTypes) { type in
                Button {
                    onWidgetTypeChange(type)
                } label: {
                    Label(type.displayName, systemImage: type.icon)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: config.widgetType.icon)
                    .imageScale(.small)
                Text(config.widgetType.displayName)
                    .font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .menuStyle(.borderlessButton)
    }

    private var widgetTypeGrid: some View {
        HStack(spacing: 8) {
            ForEach(config.module.availableWidgetTypes) { type in
                Button {
                    onWidgetTypeChange(type)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: type.icon)
                            .frame(width: 28, height: 22)
                        Text(type.displayName)
                            .font(.system(size: 9))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        config.widgetType == type
                            ? Color.accentColor.opacity(0.15)
                            : Color.primary.opacity(0.04)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(
                                config.widgetType == type
                                    ? Color.accentColor.opacity(0.5)
                                    : .clear,
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

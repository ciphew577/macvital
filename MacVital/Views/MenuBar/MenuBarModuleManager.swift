// MacVital/Views/MenuBar/MenuBarModuleManager.swift
//
// Manages optional per-module NSStatusItems in the macOS menu bar.
//
// Architecture (matched to Stats Kit/module/widget.swift lines 325-351):
//   - Each active module gets its own NSStatusItem via NSStatusBar.system.statusItem
//   - The widget is an NSView subclass added as a subview of statusItem.button
//     (NOT an NSImage on button.image — the NSView approach is more reliable)
//   - statusItem.button.image is set to an empty NSImage() so the button renders
//     the subview instead
//   - On each timer tick, widgetView.needsDisplay = true triggers redraw
//   - Width is exact pixels (not .variableLength) matching Stats's pattern
//
// This class is @Observable so SwiftUI settings can bind to it directly.

import AppKit
import Combine
import Foundation
import SwiftUI

@Observable
final class MenuBarModuleManager {

    /// All module configs, sorted by display order.
    var configs: [MenuBarModuleConfig] = []

    /// Active NSStatusItems keyed by module.
    private var statusItems: [MenuBarModule: NSStatusItem] = [:]

    /// Active widget NSView subviews keyed by module.
    private var widgetViews: [MenuBarModule: MenuBarWidgetNSView] = [:]

    /// The shared popover that all module clicks open. Wired by AppState.
    var sharedPopoverToggle: (() -> Void)?

    /// Shared NSPopover shown when any per-module widget is clicked.
    private var sharedPopover: NSPopover?

    /// Reference to SystemMonitor for reading current values.
    private weak var monitor: SystemMonitor?

    /// Timer for updating widget images.
    private var updateTimer: Timer?

    init() {
        // Load configs for all modules
        configs = MenuBarModule.allCases.map { MenuBarModuleConfig.load(for: $0) }
            .sorted { $0.order < $1.order }
    }

    // MARK: - Popover

    /// Create the shared NSPopover hosting MenuBarContent. Called by AppState after init.
    func setupPopover(appState: AppState) {
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 340, height: 700)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuBarContent().environment(appState)
        )
        sharedPopover = popover
    }

    // MARK: - Lifecycle

    /// Start the manager. Call after SystemMonitor is available.
    func start(monitor: SystemMonitor) {
        self.monitor = monitor

        // Create status items for initially enabled modules
        for config in configs where config.enabled {
            createStatusItem(for: config)
        }

        // Update widgets every 2 seconds (aligned with fast timer)
        updateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateAllWidgets()
        }
        // Ensure timer runs even when menu is tracking
        if let timer = updateTimer {
            RunLoop.main.add(timer, forMode: .common)
        }

        // Initial render after a brief delay to let SystemMonitor populate data
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.updateAllWidgets()
        }
    }

    /// Stop and clean up all status items.
    func stop() {
        updateTimer?.invalidate()
        updateTimer = nil

        for (module, item) in statusItems {
            NSStatusBar.system.removeStatusItem(item)
            widgetViews.removeValue(forKey: module)
            statusItems.removeValue(forKey: module)
        }
    }

    // MARK: - Module Toggle (called from Settings UI)

    func setEnabled(_ enabled: Bool, for module: MenuBarModule) {
        guard let idx = configs.firstIndex(where: { $0.module == module }) else { return }
        configs[idx].enabled = enabled
        configs[idx].save()

        if enabled {
            createStatusItem(for: configs[idx])
            updateWidget(for: module)
        } else {
            removeStatusItem(for: module)
        }
    }

    func setWidgetType(_ type: MenuBarWidgetType, for module: MenuBarModule) {
        guard let idx = configs.firstIndex(where: { $0.module == module }) else { return }
        configs[idx].widgetType = type
        configs[idx].save()

        // Recreate the widget view with the new type
        if configs[idx].enabled {
            removeStatusItem(for: module)
            createStatusItem(for: configs[idx])
            updateWidget(for: module)
        }
    }

    /// Number of currently active per-module widgets.
    var activeCount: Int {
        configs.filter(\.enabled).count
    }

    // MARK: - NSStatusItem Management (Stats pattern: NSView subview on button)

    private func createStatusItem(for config: MenuBarModuleConfig) {
        guard statusItems[config.module] == nil else { return }

        // Create the widget NSView
        let widgetView = MenuBarWidgetNSView(
            module: config.module,
            widgetType: config.widgetType
        )

        // Create status item with the exact width of the widget view
        // (Stats uses exact pixel width, not .variableLength)
        let item = NSStatusBar.system.statusItem(withLength: widgetView.frame.width)
        // NOTE: intentionally NOT setting `autosaveName`. Saved positions
        // get clobbered by macOS's notch dead zone on 14"/16" MacBooks:
        // if the user ever drags the widget left, macOS remembers that
        // offset and re-places it BEHIND the notch on next launch, where
        // it's invisible. Without autosaveName, macOS auto-places every
        // new status item at the right edge next to Control Center.

        // macOS 14+ overflow fix: explicitly mark the item visible BEFORE
        // adding the subview, so Control Center does not fold it into
        // the overflow menu when it detects an "empty" button state.
        item.isVisible = true

        // Explicit nil autosaveName: prevents macOS restoring a saved position
        // behind the notch dead-zone on notched 14"/16" MacBook Pros.
        item.autosaveName = nil

        // Blank image sized to the widget so macOS does NOT treat the
        // button as content-free. NSImage() (zero size) causes some
        // macOS versions to collapse the status item width to zero.
        // A 1-pt tall template-free image of the correct width keeps
        // the item alive while the NSView subview handles all rendering.
        if let button = item.button {
            let blank = NSImage(size: NSSize(width: widgetView.frame.width, height: 22))
            blank.isTemplate = false
            button.image = blank
            button.imagePosition = .imageOverlaps
            button.addSubview(widgetView)
            button.toolTip = "MacVital: \(config.module.displayName)"
        }

        // Belt-and-braces: reassert the exact pixel length after addSubview.
        // If macOS recalculated based on image content, this overrides it.
        item.length = widgetView.frame.width

        // Stats pattern (Kit/module/widget.swift line 224-230):
        // Widget view owns mouseDown via an onClick closure. The parent
        // button's target/action is unreliable when an NSView subview
        // intercepts hits. Wire the closure to toggle the shared popover.
        widgetView.onClick = { [weak self, weak item] in
            guard let self, let button = item?.button else { return }
            self.statusItemClicked(button)
        }

        // Store references
        statusItems[config.module] = item
        widgetViews[config.module] = widgetView

        // Wire width change callback (Stats pattern: widthHandler)
        widgetView.onWidthChanged = { [weak self, weak item] newWidth in
            guard let item else { return }
            if item.length != newWidth {
                item.length = newWidth
            }
        }
    }

    private func removeStatusItem(for module: MenuBarModule) {
        widgetViews.removeValue(forKey: module)
        if let item = statusItems.removeValue(forKey: module) {
            NSStatusBar.system.removeStatusItem(item)
        }
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        // Prefer the owned NSPopover; fall back to the closure for the main icon
        if let popover = sharedPopover {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            }
        } else {
            sharedPopoverToggle?()
        }
    }

    // MARK: - Widget Update (Stats pattern: needsDisplay = true)

    private func updateAllWidgets() {
        guard let monitor else { return }

        for config in configs where config.enabled {
            updateWidget(for: config.module, monitor: monitor)
        }
    }

    private func updateWidget(for module: MenuBarModule) {
        guard let monitor else { return }
        updateWidget(for: module, monitor: monitor)
    }

    private func updateWidget(for module: MenuBarModule, monitor: SystemMonitor) {
        guard let widgetView = widgetViews[module] else { return }

        // Push new data to the view and trigger redraw
        // (Stats pattern: setValue() then self.display() on main queue)
        if Thread.isMainThread {
            widgetView.updateData(from: monitor)
            widgetView.needsDisplay = true
        } else {
            DispatchQueue.main.async {
                widgetView.updateData(from: monitor)
                widgetView.needsDisplay = true
            }
        }
    }
}

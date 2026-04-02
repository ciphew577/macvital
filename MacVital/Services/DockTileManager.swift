// MacVital/Services/DockTileManager.swift
// Updates the dock icon with a live gauge showing CPU temperature.

import AppKit
import SwiftUI

final class DockTileManager {
    private var timer: Timer?
    private weak var monitor: SystemMonitor?
    private var hostingView: NSHostingView<DockGaugeView>?

    init(monitor: SystemMonitor) {
        self.monitor = monitor
    }

    func start() {
        DispatchQueue.main.async { [weak self] in
            self?.setupAndBegin()
        }
    }

    func stop() {
        DispatchQueue.main.async { [weak self] in
            self?.timer?.invalidate()
            self?.timer = nil
            NSApplication.shared.dockTile.contentView = nil
            NSApplication.shared.dockTile.display()
        }
    }

    private func setupAndBegin() {
        let view = NSHostingView(
            rootView: DockGaugeView(temperature: 0, maxTemp: 110)
        )
        view.frame = NSRect(x: 0, y: 0, width: 128, height: 128)
        self.hostingView = view

        NSApplication.shared.dockTile.contentView = view
        update()

        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.update()
            }
        }
    }

    private func update() {
        guard let monitor else { return }

        // Get hottest CPU temperature from sensor readings
        let maxTemp = monitor.sensors?.sensors
            .filter { $0.key.hasPrefix("Tp") }
            .map(\.value)
            .max() ?? 0

        let temp = maxTemp > 0 ? maxTemp : (monitor.sensors?.sensors.map(\.value).max() ?? 0)

        hostingView?.rootView = DockGaugeView(temperature: temp, maxTemp: 110)
        NSApplication.shared.dockTile.display()
    }
}

import SwiftUI
import CoreLocation
import os.log

@Observable
@MainActor
final class AppState {

    private static let logger = Logger(subsystem: "com.macvital.app", category: "AppState")

    var monitor = SystemMonitor()
    var isHelperInstalled = false
    var showHelperInstallPrompt = false
    var helperInstallError: String? = nil

    /// User-selected menu bar icon style, persisted to UserDefaults.
    var menuBarIconStyle: MenuBarIconStyle = MenuBarIconStyle.load() {
        didSet { menuBarIconStyle.save() }
    }

    /// Color palette store -- 6 schemes, persists selection to UserDefaults.
    var paletteStore = MVPaletteStore()

    /// Per-module menu bar widget manager (Stats-style multi-widget system).
    let menuBarModuleManager = MenuBarModuleManager()

    /// Shared XPC client used by fan control and any other privileged operations.
    let xpc = XPCClient()

    /// Per-network (per-SSID) lifetime usage tracker. Never auto-resets --
    /// only the user's Reset / Reset All buttons zero buckets.
    let perSSIDUsageStore = PerSSIDUsageStore()

    /// Live dock tile gauge showing CPU temperature.
    private var dockTileManager: DockTileManager?

    /// Location manager — needed for CoreWLAN to return WiFi SSID on macOS 14+
    private let locationManager = CLLocationManager()

    func start() {
        // Request location permission for WiFi SSID access
        locationManager.requestWhenInUseAuthorization()
        // Wire the lifetime-per-SSID tracker so the monitor's fast tick can
        // attribute per-iface deltas to the currently joined network.
        monitor.perSSIDUsageStore = perSSIDUsageStore
        checkHelperStatus()
        if isHelperInstalled {
            xpc.connect()
            monitor.xpcClient = xpc
            monitor.start()
        } else {
            showHelperInstallPrompt = true
            // Start anyway for development, will show empty data gracefully
            monitor.start()
        }

        // Safety net: verify XPC connection asynchronously after a short delay.
        // If the synchronous helper check missed a running helper (e.g. timing),
        // this ensures we still connect.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }
            if !self.isHelperInstalled {
                self.checkHelperStatus()
                if self.isHelperInstalled {
                    self.xpc.connect()
                    self.monitor.xpcClient = self.xpc
                }
            } else if !self.xpc.isConnected {
                // Helper is installed but XPC dropped, reconnect
                self.xpc.connect()
                self.monitor.xpcClient = self.xpc
            }
        }

        // Start live dock tile gauge
        dockTileManager = DockTileManager(monitor: monitor)
        dockTileManager?.start()

        // Wire up the shared NSPopover for per-module widget clicks
        menuBarModuleManager.setupPopover(appState: self)

        // Start per-module menu bar widgets
        menuBarModuleManager.start(monitor: monitor)
    }

    func stop() {
        menuBarModuleManager.stop()
        dockTileManager?.stop()
        monitor.stop()
        xpc.disconnect()
    }

    func checkHelperStatus() {
        isHelperInstalled = HelperInstaller.isHelperRunning()
    }

    func installHelper() {
        helperInstallError = nil
        do {
            try HelperInstaller.install()
            isHelperInstalled = true
            showHelperInstallPrompt = false
            xpc.connect()
            monitor.xpcClient = xpc
        } catch {
            Self.logger.error("Helper install failed: \(error.localizedDescription, privacy: .public)")
            helperInstallError = error.localizedDescription
        }
    }
}

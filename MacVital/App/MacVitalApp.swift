import SwiftUI

@main
struct MacVitalApp: App {
    @State private var appState: AppState

    /// Ensures start() runs once on launch, NOT tied to any window appearing.
    @State private var hasStarted = false

    init() {
        // One-time migration: CPUVariant was String-backed, now Int-backed.
        // If UserDefaults still holds the old String value, map it to Int and rewrite.
        let key = "com.macvital.cpu.variant"
        let defaults = UserDefaults.standard
        if let s = defaults.object(forKey: key) as? String {
            let mapping: [String: Int] = [
                "ringGrid": 0,
                "stackedBars": 1,
                "heatmapStrip": 2,
                "parallelCoordinates": 3,
                "arcMeter": 4
            ]
            let intValue = mapping[s] ?? 0
            defaults.removeObject(forKey: key)
            defaults.set(intValue, forKey: key)
        }

        _appState = State(initialValue: AppState())
    }

    var body: some Scene {
        Window("MacVital", id: "main") {
            SidebarView()
                .environment(appState)
                .environment(\.mvPalette, appState.paletteStore.tokens)
                .environment(appState.paletteStore)
                .frame(minWidth: 800, minHeight: 500)
                .onAppear {
                    startOnce()
                    // Seed the global MV.current on first appearance
                    MV.setPalette(appState.paletteStore.tokens)
                }
                .onChange(of: appState.paletteStore.selectedID) { _, _ in
                    MV.setPalette(appState.paletteStore.tokens)
                }
                .onDisappear {
                    // Don't stop when window closes, menu bar widgets should keep running
                }
                .sheet(isPresented: Binding(
                    get: { appState.showHelperInstallPrompt },
                    set: { appState.showHelperInstallPrompt = $0 }
                )) {
                    HelperInstallSheet(appState: appState)
                }
        }
        .defaultSize(width: 1000, height: 700)

        MenuBarExtra {
            MenuBarView()
                .environment(appState)
                .environment(\.mvPalette, appState.paletteStore.tokens)
                .environment(appState.paletteStore)
                .onAppear {
                    startOnce()
                }
        } label: {
            MenuBarIconLabel(
                style: appState.menuBarIconStyle,
                monitor: appState.monitor
            )
        }
        .menuBarExtraStyle(.window)
    }

    private func startOnce() {
        guard !hasStarted else { return }
        hasStarted = true
        appState.start()
    }
}

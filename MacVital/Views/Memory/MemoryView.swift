// MacVital/Views/Memory/MemoryView.swift
import SwiftUI

struct MemoryView: View {
    @Environment(AppState.self) private var appState

    private var mem: MemoryData? { appState.monitor.memory }

    @State private var appMemoryList: [AppMemoryInfo] = []
    @State private var selectedAppID: String? = nil
    @State private var isVisible: Bool = false
    @AppStorage(MemoryVariant.storageKey) private var variantRaw: Int = MemoryVariant.sunburst.rawValue
    private static let appMemoryMonitor = AppMemoryMonitor()

    private var selectedVariant: Binding<MemoryVariant> {
        Binding(
            get: { MemoryVariant(rawValue: variantRaw) ?? .sunburst },
            set: { variantRaw = $0.rawValue }
        )
    }

    // MARK: - Sunburst categories derived from MemoryData + app list

    private var sunburstCategories: [SunburstCategory] {
        let m = mem ?? Self.placeholderMemory

        // Build "User Apps" from running AppMemoryInfo list
        let userAppsBytes = appMemoryList.filter { app in
            app.icon != nil
        }.reduce(0) { $0 + $1.memoryBytes }

        let userAppsSlices: [SunburstSlice] = appMemoryList
            .filter { $0.icon != nil }
            .prefix(20)
            .map { app in
                SunburstSlice(
                    name: app.name,
                    bytes: app.memoryBytes,
                    color: Color(nsColor: app.color)
                )
            }

        // Build "User Processes" from the process list (non-GUI processes)
        let userProcBytes = appMemoryList.filter { app in
            app.icon == nil
        }.reduce(0) { $0 + $1.memoryBytes }

        let userProcSlices: [SunburstSlice] = appMemoryList
            .filter { $0.icon == nil }
            .prefix(20)
            .map { app in
                SunburstSlice(
                    name: app.name,
                    bytes: app.memoryBytes,
                    color: Color(nsColor: app.color)
                )
            }

        // System memory: wired + compressed + inactive
        let wiredBytes = m.wired
        let compressedBytes = m.compressed
        let inactiveBytes = m.inactive
        let systemTotal = wiredBytes + compressedBytes + inactiveBytes

        let systemSlices: [SunburstSlice] = [
            SunburstSlice(
                name: "Wired",
                bytes: wiredBytes,
                color: Color(red: 0.35, green: 0.43, blue: 0.59)
            ),
            SunburstSlice(
                name: "File Cache",
                bytes: inactiveBytes,
                color: Color(red: 0.50, green: 0.62, blue: 0.74)
            ),
            SunburstSlice(
                name: "Compressed",
                bytes: compressedBytes,
                color: Color(red: 0.55, green: 0.55, blue: 0.55)
            ),
        ].filter { $0.bytes > 0 }

        // Free memory
        let freeBytes = m.free
        let freeSlices: [SunburstSlice] = [
            SunburstSlice(
                name: "Free",
                bytes: freeBytes,
                color: Color(red: 0.13, green: 0.15, blue: 0.19)
            )
        ]

        var categories: [SunburstCategory] = []

        if userProcBytes > 0 {
            categories.append(SunburstCategory(
                id: "user-procs",
                label: "User Processes",
                color: Color(white: 0.45),
                bytes: userProcBytes,
                slices: userProcSlices
            ))
        }

        if userAppsBytes > 0 {
            categories.append(SunburstCategory(
                id: "user-apps",
                label: "User Apps",
                color: Color(white: 0.55),
                bytes: userAppsBytes,
                slices: userAppsSlices
            ))
        }

        if systemTotal > 0 {
            categories.append(SunburstCategory(
                id: "system",
                label: "System",
                color: Color(white: 0.32),
                bytes: systemTotal,
                slices: systemSlices
            ))
        }

        if freeBytes > 0 {
            categories.append(SunburstCategory(
                id: "free",
                label: "Free",
                color: Color(red: 0.12, green: 0.13, blue: 0.16),
                bytes: freeBytes,
                slices: freeSlices
            ))
        }

        return categories
    }

    private var footprintBytes: UInt64 {
        let m = mem ?? Self.placeholderMemory
        return m.used + m.swapUsed
    }

    private var diskFreeBytes: UInt64 {
        appState.monitor.storage?.volumes.first?.freeBytes ?? 0
    }

    // Placeholder memory shown when real data hasn't loaded yet (zeroed — shows em-dashes)
    private static let placeholderMemory = MemoryData(
        total:      0,
        used:       0,
        free:       0,
        wired:      0,
        active:     0,
        inactive:   0,
        compressed: 0,
        purgeable:  0,
        swapUsed:   0,
        swapFree:   0,
        pressureLevel: .nominal
    )

    // MARK: - Body

    var body: some View {
        let m = mem ?? Self.placeholderMemory
        VStack(spacing: 0) {
            // Main split: tree | chart
            HSplitView {
                // LEFT: Process tree (35% width ~420px)
                MemoryProcessTree(
                    apps: appMemoryList,
                    totalRAM: m.total,
                    selectedAppID: $selectedAppID
                )
                .frame(minWidth: 300, idealWidth: 420, maxWidth: 480)

                ZStack(alignment: .topTrailing) {
                    variantContent(memory: m)
                    MemoryVariantSwitcher(selection: selectedVariant)
                        .padding(.top, 12)
                        .padding(.trailing, 16)
                }
                .frame(minWidth: 400)
            }

            // BOTTOM: metrics bar
            MemoryBottomBar(
                memory: m,
                diskFreeBytes: diskFreeBytes
            )

            // RECOMMENDATION bar
            MemoryRecommendationBar(memory: m)
        }
        .onAppear {
            isVisible = true
            refreshAppMemory()
        }
        .onDisappear {
            isVisible = false
        }
        .task {
            // Refresh app memory list every 5 seconds, only while visible
            while !Task.isCancelled {
                if isVisible { refreshAppMemory() }
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }

    @ViewBuilder
    private func variantContent(memory m: MemoryData) -> some View {
        switch MemoryVariant(rawValue: variantRaw) ?? .sunburst {
        case .sunburst:
            MemoryViewSunburst(memory: m, appList: appMemoryList, footprintBytes: footprintBytes)
        case .stackedBar:
            MemoryViewStackedBar(memory: m)
        case .stairStep:
            MemoryViewStairStep(memory: m, appList: appMemoryList)
        case .circuitBoard:
            MemoryViewCircuitBoard(memory: m)
        case .pressureCentric:
            MemoryViewPressureCentric(memory: m)
        }
    }

    private func refreshAppMemory() {
        let monitor = Self.appMemoryMonitor
        Task.detached(priority: .userInitiated) {
            let list = monitor.readAppMemory()
            await MainActor.run {
                appMemoryList = list
            }
        }
    }
}

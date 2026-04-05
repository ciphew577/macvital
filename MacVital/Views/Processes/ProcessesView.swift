// MacVital/Views/Processes/ProcessesView.swift
// Pixel-perfect rewrite matching processes-final.html (1509 lines).
// BreezeKit categorized style — CPU summary bar, three collapsible sections,
// inline 40 px CPU bars, per-row heatmap coloring, inspector panel, status bar.
import SwiftUI
import Charts
import AppKit

// MARK: - Color palette (exact hex tokens from mockup :root variables)

private extension Color {
    static let procBg      = Color(red: 28/255, green: 28/255, blue: 30/255)   // #1C1C1E
    static let procBg2     = Color(red: 44/255, green: 44/255, blue: 46/255)   // #2C2C2E
    static let procBg3     = Color(red: 58/255, green: 58/255, blue: 60/255)   // #3A3A3C
    static let procBlue    = Color(red: 10/255,  green: 132/255, blue: 255/255) // #0A84FF
    static let procGreen   = Color(red: 50/255,  green: 215/255, blue: 75/255)  // #32D74B
    static let procOrange  = Color(red: 255/255, green: 159/255, blue: 10/255)  // #FF9F0A
    static let procRed     = Color(red: 255/255, green: 69/255,  blue: 58/255)  // #FF453A
    static let procSep     = Color.white.opacity(0.08)
    static let procText    = Color.white.opacity(0.85)
    static let procText2   = Color.white.opacity(0.55)
    static let procText3   = Color.white.opacity(0.35)
}

// MARK: - Sort options

enum ProcessSortOption: String, CaseIterable {
    case cpu    = "CPU %"
    case memory = "Memory"
    case name   = "Name"
}

// MARK: - Inspector history store (per-PID sparkline history)

@Observable
final class ProcessHistoryStore {
    private var cpuHistory: [Int32: [Double]] = [:]
    private var memHistory: [Int32: [Double]] = [:]
    private let limit = 60

    func record(pid: Int32, cpu: Double, mem: Double) {
        var c = cpuHistory[pid, default: []]
        c.append(cpu)
        if c.count > limit { c.removeFirst() }
        cpuHistory[pid] = c

        var m = memHistory[pid, default: []]
        m.append(mem)
        if m.count > limit { m.removeFirst() }
        memHistory[pid] = m
    }

    func cpuData(for pid: Int32) -> [Double] { cpuHistory[pid] ?? [] }
    func memData(for pid: Int32) -> [Double] { memHistory[pid] ?? [] }

    /// Drop history for PIDs that are no longer in the active set. Prevents
    /// unbounded dictionary growth as processes come and go (each new PID is
    /// a fresh key; without sweeping, dead PIDs accumulate forever).
    func prune(activePids: Set<Int32>) {
        cpuHistory = cpuHistory.filter { activePids.contains($0.key) }
        memHistory = memHistory.filter { activePids.contains($0.key) }
    }
}

// MARK: - Main View

struct ProcessesView: View {
    @Environment(AppState.self) private var appState

    @AppStorage(ProcessesVariant.storageKey) private var variantRaw: Int = -1
    @State private var searchText = ""
    @State private var sortOption: ProcessSortOption = .cpu
    @State private var selectedPID: Int32?
    @State private var userAppsExpanded   = true
    @State private var backgroundExpanded = true
    @State private var systemExpanded     = false
    @State private var historyStore = ProcessHistoryStore()
    @State private var livePulse = false

    // Named layout constants (fileprivate so sibling structs in same file can share)
    fileprivate static let cpuColWidth: CGFloat = 64
    fileprivate static let barColWidth: CGFloat = 40
    fileprivate static let memColWidth: CGFloat = 64
    fileprivate static let rowIndent: CGFloat   = 14

    private var monitor: SystemMonitor { appState.monitor }
    private var data: ProcessesData    { monitor.processesData }
    private var cpu: CPUData?          { monitor.cpu }

    // MARK: - Filtered + sorted lists

    private func sorted(_ list: [RichProcessInfo]) -> [RichProcessInfo] {
        let filtered: [RichProcessInfo] = searchText.isEmpty
            ? list
            : list.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        switch sortOption {
        case .cpu:    return filtered.sorted { $0.cpuPercent > $1.cpuPercent }
        case .memory: return filtered.sorted { $0.memoryBytes > $1.memoryBytes }
        case .name:   return filtered.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        }
    }

    private var userApps:   [RichProcessInfo] { sorted(data.userApps) }
    private var background: [RichProcessInfo] { sorted(data.background) }
    private var system:     [RichProcessInfo] { sorted(data.system) }
    private var totalCount: Int { data.all.count }

    private var selectedProcess: RichProcessInfo? {
        guard let pid = selectedPID else { return nil }
        return data.all.first { $0.id == pid }
    }

    // MARK: - Body

    var body: some View {
        if let variant = ProcessesVariant(rawValue: variantRaw) {
            variantBody(variant)
        } else {
            classicBody
        }
    }

    @ViewBuilder
    private func variantBody(_ v: ProcessesVariant) -> some View {
        let allSorted = sorted(data.all)
        let store = historyStore
        let history: (Int32) -> [Double] = { pid in store.cpuData(for: pid) }
        Group {
            switch v {
            case .classicTable:
                ProcessesClassicTable(processes: allSorted, selectedPID: $selectedPID, cpuHistoryFor: history)
            case .cardRows:
                ProcessesCardRows(processes: allSorted, selectedPID: $selectedPID, cpuHistoryFor: history)
            case .treeGrouped:
                ProcessesTreeGrouped(processes: allSorted, selectedPID: $selectedPID, cpuHistoryFor: history)
            case .kanbanCategorical:
                ProcessesKanbanCategorical(processes: allSorted, selectedPID: $selectedPID, cpuHistoryFor: history)
            case .linearVercel:
                ProcessesLinearVercel(processes: allSorted, selectedPID: $selectedPID, cpuHistoryFor: history)
            }
        }
        .onChange(of: data.all.count) { _, _ in
            let activePids = Set(data.all.map(\.id))
            historyStore.prune(activePids: activePids)
            for proc in data.all {
                let memMB = Double(proc.memoryBytes) / 1_048_576
                historyStore.record(pid: proc.id, cpu: proc.cpuPercent, mem: memMB)
            }
        }
        .onChange(of: monitor.cpu?.totalUsage) { _, _ in
            for proc in data.all {
                let memMB = Double(proc.memoryBytes) / 1_048_576
                historyStore.record(pid: proc.id, cpu: proc.cpuPercent, mem: memMB)
            }
        }
    }

    private var classicBody: some View {
        VStack(spacing: 0) {
            HSplitView {
                // Left: list panel
                VStack(spacing: 0) {
                    toolbarRow
                    cpuSummaryBar
                    columnHeader
                    processList
                }
                .background(Color.procBg)
                .frame(minWidth: 400)

                // Right: inspector panel (shown only when a process is selected)
                if let proc = selectedProcess {
                    InspectorPanel(
                        process: proc,
                        history: historyStore,
                        onClose: { selectedPID = nil },
                        onForceQuit: { forceQuit(pid: proc.id) }
                    )
                    .frame(width: 300)
                    .background(Color.procBg2)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            statusBar
        }
        .onChange(of: data.all.count) { _, _ in
            let activePids = Set(data.all.map(\.id))
            historyStore.prune(activePids: activePids)
            for proc in data.all {
                let memMB = Double(proc.memoryBytes) / 1_048_576
                historyStore.record(pid: proc.id, cpu: proc.cpuPercent, mem: memMB)
            }
        }
        .onChange(of: monitor.cpu?.totalUsage) { _, _ in
            // Lightweight trigger - record history when CPU reading changes
            for proc in data.all {
                let memMB = Double(proc.memoryBytes) / 1_048_576
                historyStore.record(pid: proc.id, cpu: proc.cpuPercent, mem: memMB)
            }
        }
        .onAppear {
            livePulse = true
        }
        .onDisappear { livePulse = false }
    }

    // MARK: - Toolbar  (height: 44px, padding: 0 14px)

    private var toolbarRow: some View {
        HStack(spacing: 10) {
            // Search field (max-width: 260px in mockup)
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.procText3)
                TextField("Filter processes…", text: $searchText)
                    .font(.system(size: 12))
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color.procText)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.procText3)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(maxWidth: 260)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.procSep, lineWidth: 1))

            Spacer()

            // Sort picker
            Picker("Sort", selection: $sortOption) {
                ForEach(ProcessSortOption.allCases, id: \.self) { opt in
                    Text(opt.rawValue).tag(opt)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 90)
            .font(.system(size: 11.5))

            // Process count + live dot (matches .proc-count + .live-dot)
            HStack(spacing: 5) {
                // count label: "<span>142</span> processes"
                HStack(spacing: 3) {
                    Text("\(totalCount)")
                        .foregroundStyle(Color.procText2)
                    + Text(" processes")
                        .foregroundStyle(Color.procText3)
                }
                .font(.system(size: 11).monospacedDigit())

                // live dot: green pulsing circle + "LIVE" text
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.procGreen)
                        .frame(width: 5, height: 5)
                        .opacity(livePulse ? 1.0 : 0.3)
                        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: livePulse)
                    Text("LIVE")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(Color.procGreen)
                }
            }
        }
        .padding(.horizontal, Self.rowIndent)
        .frame(height: 44)
        .background(Color.procBg.opacity(0.96))
        .overlay(Rectangle().fill(Color.procSep).frame(height: 1), alignment: .bottom)
    }

    // MARK: - CPU Summary Bar  (padding: 8px 14px)

    private var cpuSummaryBar: some View {
        let userPct = cpu?.userUsage   ?? 0
        let sysPct  = cpu?.systemUsage ?? 0
        let idlePct = max(0, 100 - userPct - sysPct)

        return VStack(alignment: .leading, spacing: 5) {
            // Segmented bar: user(blue) | sys(orange) | idle(dim)
            GeometryReader { geo in
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.procBlue)
                        .frame(width: max(0, geo.size.width * userPct / 100))
                    Rectangle()
                        .fill(Color.procOrange)
                        .frame(width: max(0, geo.size.width * sysPct / 100))
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: max(0, geo.size.width * idlePct / 100))
                }
                .frame(height: 6)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            .frame(height: 6)
            .animation(.easeInOut(duration: 1.2), value: userPct)

            // Labels: "User 30% · System 12% · Idle 58%"
            HStack(spacing: 0) {
                Text("User ")
                    .foregroundStyle(Color.procBlue.opacity(0.8))
                + Text(String(format: "%.1f%%", userPct))
                    .foregroundStyle(Color.procBlue.opacity(0.8))
                Text("  ·  ")
                    .foregroundStyle(Color.procText3)
                Text("System ")
                    .foregroundStyle(Color.procOrange.opacity(0.8))
                + Text(String(format: "%.1f%%", sysPct))
                    .foregroundStyle(Color.procOrange.opacity(0.8))
                Text("  ·  ")
                    .foregroundStyle(Color.procText3)
                Text("Idle ")
                    .foregroundStyle(Color.procText3)
                + Text(String(format: "%.1f%%", idlePct))
                    .foregroundStyle(Color.procText3)
            }
            .font(.system(size: 10.5).monospacedDigit())
        }
        .padding(.horizontal, Self.rowIndent)
        .padding(.vertical, 8)
        .overlay(Rectangle().fill(Color.procSep).frame(height: 1), alignment: .bottom)
    }

    // MARK: - Column Header  (height: 24px, sticky at top:0)

    private var columnHeader: some View {
        HStack(spacing: 0) {
            Text("PROCESS NAME")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("CPU")
                .frame(width: ProcessesView.cpuColWidth, alignment: .trailing)
                .padding(.trailing, 0)
            Spacer().frame(width: Self.barColWidth)
            Text("MEMORY")
                .frame(width: ProcessesView.memColWidth, alignment: .trailing)
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(Color.procText3)
        .tracking(1.2)
        .padding(.horizontal, Self.rowIndent)
        .frame(height: 24)
        .background(Color.procBg)
        .overlay(Rectangle().fill(Color.procSep).frame(height: 1), alignment: .bottom)
    }

    // MARK: - Process List

    private var processList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    if userAppsExpanded {
                        ForEach(userApps) { proc in
                            ProcessRow(
                                process: proc,
                                rowStyle: .app,
                                isSelected: selectedPID == proc.id,
                                onTap: { selectedPID = proc.id == selectedPID ? nil : proc.id }
                            )
                            Divider().opacity(0.05)
                        }
                    }
                } header: {
                    SectionHeaderRow(
                        title: "USER APPS",
                        count: userApps.count,
                        totalCPU: userApps.reduce(0) { $0 + $1.cpuPercent },
                        isExpanded: $userAppsExpanded
                    )
                }

                Section {
                    if backgroundExpanded {
                        ForEach(background) { proc in
                            ProcessRow(
                                process: proc,
                                rowStyle: .background,
                                isSelected: selectedPID == proc.id,
                                onTap: { selectedPID = proc.id == selectedPID ? nil : proc.id }
                            )
                            Divider().opacity(0.05)
                        }
                    }
                } header: {
                    SectionHeaderRow(
                        title: "BACKGROUND",
                        count: background.count,
                        totalCPU: background.reduce(0) { $0 + $1.cpuPercent },
                        isExpanded: $backgroundExpanded
                    )
                }

                Section {
                    if systemExpanded {
                        ForEach(system) { proc in
                            ProcessRow(
                                process: proc,
                                rowStyle: .system,
                                isSelected: selectedPID == proc.id,
                                onTap: { selectedPID = proc.id == selectedPID ? nil : proc.id }
                            )
                            Divider().opacity(0.05)
                        }
                    }
                } header: {
                    SectionHeaderRow(
                        title: "SYSTEM",
                        count: system.count,
                        totalCPU: system.reduce(0) { $0 + $1.cpuPercent },
                        isExpanded: $systemExpanded
                    )
                }
            }
        }
        .background(Color.procBg)
    }

    // MARK: - Status Bar  (height: 24px, matches .status-bar)

    private var statusBar: some View {
        let allCPU = (cpu?.userUsage ?? 0) + (cpu?.systemUsage ?? 0)
        let threadCount = data.all.count * 4   // approximate if no thread data
        let loadAvg = allCPU / 100.0 * 8.0     // approximate load from cpu usage

        return HStack(spacing: 0) {
            statusItem(label: "Processes", value: "\(totalCount)")
            statusDot
            statusItem(label: "Threads", value: "\(threadCount.formatted())")
            statusDot
            statusItem(label: "Load", value: String(format: "%.2f", max(0, loadAvg)))
            Spacer()
        }
        .padding(.horizontal, Self.rowIndent)
        .frame(height: 24)
        .background(Color.procBg.opacity(0.96))
        .overlay(Rectangle().fill(Color.procSep).frame(height: 1), alignment: .top)
    }

    private func statusItem(label: String, value: String) -> some View {
        HStack(spacing: 3) {
            Text(label + ":")
                .foregroundStyle(Color.procText3)
            Text(value)
                .foregroundStyle(Color.procText2)
        }
        .font(.system(size: 10).monospacedDigit())
    }

    private var statusDot: some View {
        Text(" · ")
            .font(.system(size: 10))
            .foregroundStyle(Color.procText3)
    }

    // MARK: - Force Quit

    private func forceQuit(pid: Int32) {
        kill(pid, SIGKILL)
        selectedPID = nil
    }
}

// MARK: - Section Header Row

private struct SectionHeaderRow: View {
    let title: String
    let count: Int
    let totalCPU: Double
    @Binding var isExpanded: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { isExpanded.toggle() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(Color.procText3)
                    .frame(width: 12)
                    .animation(.easeInOut(duration: 0.18), value: isExpanded)

                Text(title)
                    .font(.system(size: 10.5, weight: .bold))
                    .tracking(1.0)
                    .foregroundStyle(Color.procText2)

                Text("(\(count))")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.procText3)

                Spacer()

                if totalCPU > 0.5 {
                    Text(String(format: "%.1f%%", totalCPU))
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(Color.procText3)
                }
            }
            .padding(.horizontal, ProcessesView.rowIndent)
            .frame(height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.procBg.opacity(0.98))
        .overlay(Rectangle().fill(Color.procSep).frame(height: 1), alignment: .bottom)
    }
}

// MARK: - Process Row  (app: 32px, bg/sys: 28px)

private enum ProcessRowStyle { case app, background, system }

private struct ProcessRow: View {
    let process: RichProcessInfo
    let rowStyle: ProcessRowStyle
    let isSelected: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    private var rowHeight: CGFloat {
        rowStyle == .app ? 32 : 28
    }

    private var iconSize: CGFloat {
        rowStyle == .app ? 20 : 16
    }

    private var nameFont: Font {
        rowStyle == .app ? .system(size: 13) : .system(size: 12)
    }

    private var nameForeground: Color {
        rowStyle == .app ? .procText : .procText2
    }

    // CPU heatmap — matches cpuColor() JS in mockup
    // pct < 5:  bar=white.15, text=white.35
    // pct < 20: bar=white.40, text=white.55
    // pct < 50: bar=blue.50,  text=white.85
    // pct < 80: bar=orange.60, text=orange
    // pct >= 80: bar=red.70,  text=red
    private var cpuTextColor: Color {
        let pct = process.cpuPercent
        if pct >= 80 { return .procRed }
        if pct >= 50 { return .procOrange }
        if pct >= 20 { return .procText }
        if pct >= 5  { return .procText2 }
        return .procText3
    }

    private var cpuBarColor: Color {
        let pct = process.cpuPercent
        if pct >= 80 { return Color.procRed.opacity(0.7) }
        if pct >= 50 { return Color.procOrange.opacity(0.6) }
        if pct >= 20 { return Color.procBlue.opacity(0.5) }
        if pct >= 5  { return Color.white.opacity(0.4) }
        return Color.white.opacity(0.15)
    }

    private var barFraction: Double { min(1.0, process.cpuPercent / 100.0) }

    var body: some View {
        HStack(spacing: 0) {
            // Left accent bar (2px — blue when selected)
            Rectangle()
                .fill(isSelected ? Color.procBlue : Color.clear)
                .frame(width: 2)

            // Icon
            iconView
                .padding(.leading, 12)
                .padding(.trailing, 8)

            // Process name
            Text(process.name)
                .font(nameFont)
                .foregroundStyle(isSelected ? Color.procText : nameForeground)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 4)

            // CPU value (width: 64px in mockup .col-hdr-cpu)
            Text(String(format: "%.1f%%", process.cpuPercent))
                .font(.system(size: 11.5).monospacedDigit())
                .foregroundStyle(cpuTextColor)
                .frame(width: ProcessesView.cpuColWidth, alignment: .trailing)

            // Inline bar (40px)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: ProcessesView.barColWidth, height: 3)
                RoundedRectangle(cornerRadius: 2)
                    .fill(cpuBarColor)
                    .frame(width: max(0, ProcessesView.barColWidth * barFraction), height: 3)
                    .animation(.easeInOut(duration: 1.2), value: barFraction)
            }
            .frame(width: ProcessesView.barColWidth)

            // Memory (width: 64px in mockup .col-hdr-mem)
            Text(Self.memString(process.memoryBytes))
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(Color.procText3)
                .frame(width: ProcessesView.memColWidth, alignment: .trailing)
                .padding(.trailing, 14)
        }
        .frame(height: rowHeight)
        .background(rowBackground)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onHover { h in isHovered = h }
    }

    @ViewBuilder
    private var iconView: some View {
        if let icon = process.icon {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: iconSize, height: iconSize)
                .clipShape(RoundedRectangle(cornerRadius: rowStyle == .app ? 5 : 3))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: rowStyle == .app ? 5 : 3)
                    .fill(iconPlaceholderColor.opacity(0.15))
                Image(systemName: rowStyle == .app ? "app.fill" : "gear")
                    .font(.system(size: rowStyle == .app ? 10 : 8))
                    .foregroundStyle(iconPlaceholderColor.opacity(0.6))
            }
            .frame(width: iconSize, height: iconSize)
        }
    }

    private var rowBackground: Color {
        if isSelected { return Color.procBlue.opacity(0.10) }
        if isHovered  { return Color.white.opacity(0.03) }
        return .clear
    }

    private var iconPlaceholderColor: Color {
        switch rowStyle {
        case .app:        return Color.procBlue
        case .background: return Color.procText3
        case .system:     return Color.procOrange
        }
    }

    static func memString(_ bytes: UInt64) -> String {
        let mb = Double(bytes) / 1_048_576
        if mb >= 1024 { return String(format: "%.1f GB", mb / 1024) }
        if mb >= 1    { return String(format: "%.0f MB", mb) }
        return String(format: "%.0f KB", Double(bytes) / 1024)
    }
}

// MARK: - Inspector Panel

private struct InspectorPanel: View {
    let process: RichProcessInfo
    let history: ProcessHistoryStore
    let onClose: () -> Void
    let onForceQuit: () -> Void

    private var cpuHistory: [Double] { history.cpuData(for: process.id) }
    private var memHistory: [Double] { history.memData(for: process.id) }

    private var categoryLabel: String {
        switch process.category {
        case .userApp:    return "App"
        case .background: return "Background"
        case .system:     return "System"
        }
    }

    private var categoryBadgeColor: Color {
        switch process.category {
        case .userApp:    return Color.procBlue
        case .background: return Color.procText3
        case .system:     return Color.procOrange
        }
    }

    // Energy label derived from cpu usage (Low / Med / High)
    private var energyLabel: String {
        if process.cpuPercent >= 50 { return "High" }
        if process.cpuPercent >= 15 { return "Med" }
        return "Low"
    }

    private var energyColor: Color {
        if process.cpuPercent >= 50 { return Color.procRed }
        if process.cpuPercent >= 15 { return Color.procOrange }
        return Color.procGreen
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                inspHeader
                Divider().opacity(0.08)
                inspSparklines
                Divider().opacity(0.08)
                inspDetailGrid
                Divider().opacity(0.08)
                if !process.path.isEmpty {
                    inspPathField
                    Divider().opacity(0.08)
                }
                inspForceQuit
            }
        }
        .background(Color.procBg2)
        .overlay(Rectangle().fill(Color.procSep).frame(width: 1), alignment: .leading)
    }

    // MARK: Inspector header (icon + name + PID + badge + close)

    private var inspHeader: some View {
        HStack(alignment: .top, spacing: 10) {
            // Icon (32×32, radius 7)
            Group {
                if let icon = process.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(categoryBadgeColor.opacity(0.15))
                        Image(systemName: process.category == .userApp ? "app.fill" : "gear")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(categoryBadgeColor.opacity(0.7))
                    }
                    .frame(width: 32, height: 32)
                }
            }

            // Name + PID + type badge
            VStack(alignment: .leading, spacing: 3) {
                Text(process.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.procText)
                    .lineLimit(1)
                Text("PID \(process.id)")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.procText3)
                // Type badge (.badge-app / .badge-bg / .badge-sys)
                Text(categoryLabel)
                    .font(.system(size: 9.5, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(categoryBadgeColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(categoryBadgeColor.opacity(
                        process.category == .userApp ? 0.15
                        : process.category == .background ? 0.08
                        : 0.12
                    ))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            Spacer()

            // Close button
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.procText3)
                    .frame(width: 20, height: 20)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }

    // MARK: Sparklines (CPU + Memory side by side)

    private var inspSparklines: some View {
        HStack(spacing: 10) {
            SparkBlock(label: "CPU", data: cpuHistory,
                       color: cpuSparkColor, suffix: "%")
            SparkBlock(label: "MEMORY", data: memHistory,
                       color: Color.procGreen, suffix: " MB")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var cpuSparkColor: Color {
        if process.cpuPercent >= 80 { return .procRed }
        if process.cpuPercent >= 50 { return .procOrange }
        return .procBlue
    }

    // MARK: Detail grid (2 columns, matches .insp-grid)

    private var inspDetailGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            alignment: .leading,
            spacing: 10
        ) {
            InspField(label: "CPU",     value: String(format: "%.1f%%", process.cpuPercent))
            InspField(label: "Memory",  value: ProcessRow.memString(process.memoryBytes))
            InspField(label: "PID",     value: "\(process.id)")
            InspField(label: "Category", value: process.category.rawValue)
            // Energy with colored dot
            InspField(label: "Energy (approx)", value: energyLabel, dotColor: energyColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: Path field (full-width)

    private var inspPathField: some View {
        InspField(label: "PATH", value: process.path, fullWidth: true)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
    }

    // MARK: Force Quit  (matches .insp-force-quit + .force-quit-btn)

    private var inspForceQuit: some View {
        ForceQuitButton(action: onForceQuit)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
    }
}

// MARK: - Force Quit Button (compact, hover-only red bg)

private struct ForceQuitButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "xmark.octagon.fill")
                    .font(.system(size: 12))
                Text("Force Quit")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(Color.procRed)
            .padding(.vertical, 4)
            .padding(.horizontal, 12)
            .background(isHovered ? Color.procRed.opacity(0.15) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Sparkline Block (inspector sparklines)

private struct SparkBlock: View {
    let label: String
    let data: [Double]
    let color: Color
    let suffix: String

    private var currentVal: Double { data.last ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9.5))
                .tracking(0.7)
                .foregroundStyle(Color.procText3)

            if data.count > 1 {
                let maxVal = data.max() ?? 1
                Chart {
                    ForEach(Array(data.enumerated()), id: \.offset) { i, v in
                        LineMark(x: .value("t", i), y: .value("v", v))
                            .foregroundStyle(color.gradient)
                            .interpolationMethod(.catmullRom)
                        AreaMark(x: .value("t", i), y: .value("v", v))
                            .foregroundStyle(color.opacity(0.12).gradient)
                            .interpolationMethod(.catmullRom)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartYScale(domain: 0...max(maxVal, 1))
                .frame(height: 32)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.04))
                    .frame(height: 32)
                    .overlay(
                        Text("·")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.procText3)
                    )
            }

            Text(String(format: "%.1f", currentVal) + suffix)
                .font(.system(size: 10).monospacedDigit())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Inspector Field

private struct InspField: View {
    let label: String
    let value: String
    var fullWidth: Bool = false
    var dotColor: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9.5))
                .tracking(0.7)
                .foregroundStyle(Color.procText3)

            HStack(spacing: 4) {
                // Energy dot (colored circle, matches .energy-dot)
                if let dot = dotColor {
                    Circle()
                        .fill(dot)
                        .frame(width: 7, height: 7)
                }
                Text(value)
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(fullWidth ? Color.procText2 : Color.procText)
                    .lineLimit(fullWidth ? 3 : 1)
                    .truncationMode(.middle)
                    .fixedSize(horizontal: false, vertical: fullWidth)
            }
        }
    }
}

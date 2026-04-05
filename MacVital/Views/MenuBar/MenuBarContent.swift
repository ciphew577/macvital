// MacVital/Views/MenuBar/MenuBarContent.swift
//
// v4 Control Center + Sankey popover content. Assembled from:
//   • header with pulsing live dot + severity label
//   • 2×3 tile grid (CPU · Thermal · Power · Memory · Wi-Fi · Battery)
//   • fans slider strip (L/R rails)
//   • storage slider strip (single rail)
//   • hero Sankey power flow
//   • footer with "Updated HH:mm:ss · 1 Hz" and "Open MacVital ›"
//
// All values are bound to SystemMonitor @Observable properties. Nothing
// else on this screen mutates. Width locked to 296 pt, background #0a0a0c.

import SwiftUI

struct MenuBarContent: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var monitor: SystemMonitor { appState.monitor }

    // Live timestamp ticker — drives footer + header label refresh at 1 Hz.
    // Held as @State so we can start/stop across popover open/close without
    // a new publisher being auto-connected on every body rebuild. Without
    // this gate, combined with NSPopover's aggressive teardown cycle, the
    // timer subscription stacks and the popover visibly re-renders on every
    // tick even when hidden.
    @State private var now: Date = Date()
    @State private var tickTask: Task<Void, Never>? = nil
    @State private var fanControlMode: MenuBarFanMode = .auto
    @State private var selectedTab: MenuBarTab = .glance

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 4)

            MenuBarTabBar(selection: $selectedTab)

            tabContent
                .padding(.top, MVMenu.Geo.tileGap)
                .id(selectedTab)
                .transition(
                    reduceMotion
                        ? .identity
                        : .opacity.combined(with: .offset(y: 6))
                )
                .animation(
                    reduceMotion ? nil : .timingCurve(0.16, 1, 0.3, 1, duration: 0.2),
                    value: selectedTab
                )

            footer
                .padding(.top, MVMenu.Geo.tileGap)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(MVMenu.hair)
                        .frame(height: 0.5)
                }
        }
        .padding(MVMenu.Geo.popPadding)
        .frame(width: MVMenu.Geo.popWidth, alignment: .leading)
        .background(MVMenu.popBg)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(MVMenu.hairStrong, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .onAppear {
            now = Date()
            tickTask?.cancel()
            tickTask = Task { @MainActor in
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    if Task.isCancelled { break }
                    now = Date()
                }
            }
        }
        .onDisappear {
            tickTask?.cancel()
            tickTask = nil
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            HStack(alignment: .center, spacing: 8) {
                LivePulseDot(color: severityDotColor, reduceMotion: reduceMotion)
                Text("MacVital")
                    .font(.system(size: MVMenu.FS.value, weight: .semibold))
                    .tracking(-0.15)
                    .foregroundStyle(MVMenu.text)
                severityPill
            }

            Spacer()

            Text(timeString)
                .font(.system(size: MVMenu.FS.caption, weight: .regular, design: .monospaced))
                .foregroundStyle(MVMenu.textDim)
        }
    }

    /// Inline severity pill — replaces the dead "· Watch · Thermal" text.
    /// Tints + colors based on alertEngine.worstSeverity.
    private var severityPill: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(severityDotColor)
                .frame(width: 5, height: 5)
            Text(severityPillText)
                .font(.system(size: MVMenu.FS.micro, weight: .medium))
                .tracking(0.4)
        }
        .padding(.leading, 6)
        .padding(.trailing, 7)
        .frame(height: 18)
        .background(
            Capsule()
                .fill(severityPillBackground)
        )
        .foregroundStyle(severityPillForeground)
    }

    /// Tab content switch. Glance keeps the v4 Control Center + Sankey
    /// layout verbatim; the other 5 tabs swap into place with a 200 ms
    /// fade driven by `.transition` on the parent.
    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .glance:
            glanceContent
        case .detail:
            DetailTabView(monitor: monitor)
        case .network:
            NetworkTabView(monitor: monitor)
        case .procs:
            ProcsTabView(monitor: monitor)
        case .sensors:
            SensorsTabView(monitor: monitor)
        case .power:
            PowerTabView(monitor: monitor)
        }
    }

    /// Glance content = v4 Control Center + Sankey layout, byte-for-byte
    /// preserved from the prior MenuBarContent body.
    private var glanceContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            tileGrid

            Divider()
                .overlay(MVMenu.hair)
                .padding(.vertical, MVMenu.Geo.tileGap)

            VStack(spacing: MVMenu.Geo.tileGap) {
                fansStrip
                fanControlStrip
                storageStrip
            }

            Divider()
                .overlay(MVMenu.hair)
                .padding(.vertical, MVMenu.Geo.tileGap)

            sankey
        }
    }

    // MARK: - Tile grid (2×3)

    private var tileGrid: some View {
        VStack(spacing: MVMenu.Geo.tileGap) {
            HStack(spacing: MVMenu.Geo.tileGap) {
                cpuTile
                thermalTile
            }
            HStack(spacing: MVMenu.Geo.tileGap) {
                powerTile
                memoryTile
            }
            HStack(spacing: MVMenu.Geo.tileGap) {
                wifiTile
                batteryOrUptimeTile
            }
        }
    }

    // MARK: - Tiles

    private var cpuTile: some View {
        let load = monitor.cpu?.totalUsage ?? 0
        // P/E split — average over cluster.
        let pCores = monitor.cpu?.cores.filter { $0.clusterType == .performance } ?? []
        let eCores = monitor.cpu?.cores.filter { $0.clusterType == .efficiency } ?? []
        let pAvg = pCores.isEmpty ? 0 : pCores.map(\.usage).reduce(0, +) / Double(pCores.count)
        let eAvg = eCores.isEmpty ? 0 : eCores.map(\.usage).reduce(0, +) / Double(eCores.count)
        let severity: MenuBarTile.TileSeverity =
            load > 95 ? .critical : (load > 80 ? .watch : .nominal)

        return MenuBarTile(
            iconSystemName: "cpu",
            iconColor: MVMenu.cpu,
            label: "CPU",
            value: String(format: "%.0f", load),
            unit: "%",
            subtitle: String(format: "P %.0f · E %.0f", pAvg, eAvg),
            severity: severity
        )
    }

    private var thermalTile: some View {
        let hottest = monitor.sensors?.sensors.max(by: { $0.value < $1.value })
        let temp = hottest?.value ?? 0
        let name = hottest?.name ?? "—"
        let severity: MenuBarTile.TileSeverity =
            temp > 95 ? .critical : (temp > 80 ? .watch : .nominal)
        let pressureLabel = temp > 80 ? "Warm" : "Nominal"
        // Abbreviate sensor name for subtitle
        let shortName = abbreviateSensor(name)

        return MenuBarTile(
            iconSystemName: "thermometer.medium",
            iconColor: MVMenu.thermal,
            label: "Thermal",
            value: temp > 0 ? String(format: "%.0f", temp) : "—",
            unit: temp > 0 ? "°C" : nil,
            subtitle: "\(pressureLabel) · \(shortName) \(temp > 0 ? String(format: "%.0f°", temp) : "")",
            severity: severity
        )
    }

    private var powerTile: some View {
        let wall = monitor.socPower
        let cpu = monitor.cpuPower
        let gpu = monitor.gpuPower
        let dram = monitor.dramPowerSMC

        return MenuBarTile(
            iconSystemName: "bolt.fill",
            iconColor: MVMenu.power,
            label: "Power",
            value: wall > 0 ? String(format: "%.1f", wall) : "—",
            unit: wall > 0 ? "W" : nil,
            subtitle: String(format: "C %.0f · G %.0f · D %.1f", cpu, gpu, dram),
            severity: .nominal
        )
    }

    private var memoryTile: some View {
        let mem = monitor.memory
        let usedGB = Double(mem?.used ?? 0) / 1_073_741_824
        let totalGB = Double(mem?.total ?? 0) / 1_073_741_824
        let severity: MenuBarTile.TileSeverity = {
            switch mem?.pressureLevel {
            case .critical: return .critical
            case .warning:  return .watch
            default:        return .nominal
            }
        }()
        let pressure = (mem?.pressureLevel ?? .nominal).rawValue
        let usedValue = usedGB >= 10
            ? String(format: "%.0f", usedGB)
            : String(format: "%.1f", usedGB)
        let totalString = totalGB > 0 ? String(format: "/%.0f GB", totalGB) : nil

        return MenuBarTile(
            iconSystemName: "memorychip",
            iconColor: MVMenu.memory,
            label: "Memory",
            value: usedValue,
            unit: totalString,
            subtitle: pressure,
            severity: severity
        )
    }

    private var wifiTile: some View {
        let iface = monitor.network?.interfaces.first(where: { $0.wifiSSID != nil })
        let ssid = iface?.wifiSSID ?? "—"
        let rate = iface?.linkSpeed ?? ""
        let signalText: String = {
            guard let dBm = iface?.wifiSignalDBm else { return "—" }
            if dBm > -60 { return "strong" }
            if dBm > -75 { return "ok" }
            return "weak"
        }()
        let subtitle = rate.isEmpty ? signalText : "\(rate) · \(signalText)"

        return MenuBarTile(
            iconSystemName: "wifi",
            iconColor: MVMenu.wifi,
            label: "Wi-Fi",
            value: ssid,
            unit: nil,
            subtitle: subtitle,
            severity: .nominal
        )
    }

    @ViewBuilder
    private var batteryOrUptimeTile: some View {
        if let bat = monitor.battery {
            let severity: MenuBarTile.TileSeverity =
                bat.percentage < 10 ? .critical :
                bat.percentage < 20 ? .watch : .nominal
            MenuBarTile(
                iconSystemName: "battery.100",
                iconColor: MVMenu.battery,
                label: "Battery",
                value: String(format: "%.0f", bat.percentage),
                unit: "%",
                subtitle: String(format: "%dcy · %.0f%%",
                                 bat.cycleCount, bat.healthPercent),
                severity: severity
            )
        } else {
            let uptime = Foundation.ProcessInfo.processInfo.systemUptime
            let days = Int(uptime / 86400)
            let hours = Int((uptime.truncatingRemainder(dividingBy: 86400)) / 3600)
            let bootDate = Date().addingTimeInterval(-uptime)
            MenuBarTile(
                iconSystemName: "clock",
                iconColor: MVMenu.slate,
                label: "Uptime",
                value: "\(days)d \(hours)h",
                unit: nil,
                subtitle: "booted \(timeFormatter.string(from: bootDate))",
                severity: .nominal
            )
        }
    }

    // MARK: - Slider strips

    private var fansStrip: some View {
        let fans = monitor.sensors?.fans ?? []
        let maxRPM = fans.map(\.maxRPM).max() ?? 6000
        let allIdle = !fans.isEmpty && fans.allSatisfy { $0.rpm == 0 }
        let fractions: [Double] = fans.prefix(2).map { fan in
            guard maxRPM > 0 else { return 0 }
            return Double(fan.rpm) / Double(maxRPM)
        }
        let railsToShow: [Double] = fractions.isEmpty ? [0] : fractions

        let readout: String = {
            if fans.isEmpty { return "— rpm" }
            if allIdle { return "Idle · passive cooling" }
            if fans.count == 1 {
                return "\(fans[0].rpm) rpm"
            }
            return "L \(fans[0].rpm) · R \(fans[1].rpm) rpm"
        }()

        return MenuBarSliderStrip(
            iconSystemName: "fanblades",
            label: "Fans",
            readout: readout,
            rails: railsToShow,
            iconColor: MVMenu.slate
        )
    }

    private var storageStrip: some View {
        let root = monitor.storage?.volumes.first(where: { $0.mountPoint == "/" })
        let fraction: Double = {
            guard let v = root, v.totalBytes > 0 else { return 0 }
            return Double(v.usedBytes) / Double(v.totalBytes)
        }()
        let readout: String = {
            guard let v = root else { return "— / — GB" }
            let usedGB = Double(v.usedBytes) / 1_073_741_824
            let totalGB = Double(v.totalBytes) / 1_073_741_824
            return String(format: "%.0f / %.0f GB", usedGB, totalGB)
        }()

        return MenuBarSliderStrip(
            iconSystemName: "internaldrive",
            label: "Storage",
            readout: readout,
            rails: [fraction],
            iconColor: MVMenu.slate
        )
    }

    // MARK: - Fan control strip

    private var fanControlStrip: some View {
        let fans = monitor.sensors?.fans ?? []
        let activeFanLabel: String = {
            guard !fans.isEmpty, fanControlMode != .auto else { return "" }
            if fans.count >= 2 {
                let target: Int
                switch fanControlMode {
                case .auto: target = 0
                case .low:  target = fans[0].minRPM
                case .med:  target = (fans[0].minRPM + fans[0].maxRPM) / 2
                case .high: target = Int(Double(fans[0].maxRPM) * 0.75)
                case .max:  target = fans[0].maxRPM
                }
                return target > 0 ? " · \(target) rpm" : ""
            }
            return ""
        }()

        return HStack(spacing: 6) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(MVMenu.textFaint)

            ForEach(MenuBarFanMode.allCases, id: \.self) { mode in
                Button {
                    applyFanMode(mode, fans: fans)
                } label: {
                    Text(mode.label)
                        .font(.system(size: MVMenu.FS.micro, weight: .medium))
                        .foregroundStyle(fanControlMode == mode ? MVMenu.text : MVMenu.textDim)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(fanControlMode == mode ? MVMenu.accentSoft : MVMenu.pillBg)
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    fanControlMode == mode ? MVMenu.accent.opacity(0.5) : Color.clear,
                                    lineWidth: 0.5
                                )
                        )
                }
                .buttonStyle(.plain)
            }

            if fanControlMode != .auto {
                Text(activeFanLabel)
                    .font(.system(size: MVMenu.FS.micro, weight: .medium, design: .monospaced))
                    .foregroundStyle(MVMenu.textDim)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 36)
        .background(MVMenu.tile)
        .clipShape(RoundedRectangle(cornerRadius: MVMenu.Geo.tileRadius))
        .overlay(
            RoundedRectangle(cornerRadius: MVMenu.Geo.tileRadius)
                .strokeBorder(MVMenu.hair, lineWidth: 0.5)
        )
    }

    private func applyFanMode(_ mode: MenuBarFanMode, fans: [FanReading]) {
        fanControlMode = mode
        let xpc = appState.xpc
        print("[MenuBar FanControl] mode=\(mode) fans=\(fans.count)")
        Task {
            for (idx, fan) in fans.enumerated() {
                print("[MenuBar FanControl] fan \(idx): min=\(fan.minRPM) max=\(fan.maxRPM) current=\(fan.rpm)")
                switch mode {
                case .auto:
                    _ = await xpc.resetFan(fanIndex: idx)
                case .low:
                    _ = await xpc.setFanSpeed(fanIndex: idx, rpm: fan.minRPM)
                case .med:
                    let midRPM = (fan.minRPM + fan.maxRPM) / 2
                    _ = await xpc.setFanSpeed(fanIndex: idx, rpm: midRPM)
                case .high:
                    let highRPM = Int(Double(fan.maxRPM) * 0.75)
                    _ = await xpc.setFanSpeed(fanIndex: idx, rpm: highRPM)
                case .max:
                    _ = await xpc.setFanSpeed(fanIndex: idx, rpm: fan.maxRPM)
                }
            }
        }
    }

    // MARK: - Sankey

    private var sankey: some View {
        let wall = monitor.socPower
        let cpu = monitor.cpuPower
        let gpu = monitor.gpuPower
        let dram = monitor.dramPowerSMC
        let usb = monitor.usb1PowerSMC + monitor.usb2PowerSMC
        // Mac draw = sum of measured sinks, falls back to SoC if sinks empty.
        let rawSinks = cpu + gpu + dram + usb
        let macDraw = rawSinks > 0.1 ? rawSinks : wall
        let battery = (monitor.battery?.percentage ?? 87) / 100

        return SankeyPowerFlow(
            wallWatts: wall > 0 ? wall : macDraw,
            macWatts: macDraw,
            cpuWatts: cpu,
            gpuWatts: gpu,
            dramWatts: dram,
            usbWatts: usb,
            batteryFraction: battery
        )
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text("Updated \(timestampString) · 1 Hz")
                .font(.system(size: MVMenu.FS.micro, design: .monospaced))
                .foregroundStyle(MVMenu.textFaint)

            Spacer()

            Button {
                openWindow(id: "main")
                NSApplication.shared.activate(ignoringOtherApps: true)
            } label: {
                HStack(spacing: 4) {
                    Text("Open MacVital")
                        .font(.system(size: MVMenu.FS.caption, weight: .medium))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .medium))
                }
                .foregroundStyle(MVMenu.accent)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.clear)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private var severityDotColor: Color {
        switch monitor.alertEngine.worstSeverity {
        case .good:     return MVMenu.sevOk
        case .warning:  return MVMenu.sevWarn
        case .critical: return MVMenu.sevBad
        }
    }

    private var severityLabel: String {
        switch monitor.alertEngine.worstSeverity {
        case .good:     return "Nominal"
        case .warning:  return "Watch"
        case .critical: return "Critical"
        }
    }

    /// Hottest sensor name for the pill subhead, abbreviated when warn/crit.
    private var severityPillText: String {
        switch monitor.alertEngine.worstSeverity {
        case .good:
            return "Nominal"
        case .warning, .critical:
            let hottest = monitor.sensors?.sensors.max(by: { $0.value < $1.value })
            let cause = abbreviateSensor(hottest?.name ?? "Thermal")
            return "\(severityLabel) · \(cause)"
        }
    }

    private var severityPillBackground: Color {
        switch monitor.alertEngine.worstSeverity {
        case .good:     return MVMenu.accent.opacity(0.16)
        case .warning:  return MVMenu.sevWarn.opacity(0.16)
        case .critical: return MVMenu.sevBad.opacity(0.20)
        }
    }

    private var severityPillForeground: Color {
        switch monitor.alertEngine.worstSeverity {
        case .good:     return MVMenu.accent
        case .warning:  return MVMenu.sevWarn
        case .critical: return MVMenu.sevBad
        }
    }

    private var timeString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: now)
    }

    private var timestampString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm:ss a"
        return fmt.string(from: now)
    }

    private var timeFormatter: DateFormatter {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt
    }

    private func truncated(_ s: String, max: Int) -> String {
        s.count > max ? String(s.prefix(max)) + "…" : s
    }

    private func abbreviateSensor(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("soc") && lower.contains("die") { return "SoC" }
        if lower.contains("cpu") && lower.contains("die") { return "CPU" }
        if lower.contains("gpu") && lower.contains("die") { return "GPU" }
        if lower.contains("cpu") { return "CPU" }
        if lower.contains("gpu") { return "GPU" }
        if lower.contains("soc") { return "SoC" }
        // Fallback: first word up to 6 chars
        let first = name.split(separator: " ").first.map(String.init) ?? name
        return first.count > 6 ? String(first.prefix(6)) : first
    }
}

// MARK: - Menu bar fan mode (simplified for popover pills)

enum MenuBarFanMode: CaseIterable {
    case auto, low, med, high, max

    var label: String {
        switch self {
        case .auto: return "Auto"
        case .low:  return "Low"
        case .med:  return "Med"
        case .high: return "High"
        case .max:  return "Max"
        }
    }
}

// MARK: - Live pulse dot

/// 6×6 pt dot with a 2 s opacity/scale breathing pulse. Respects
/// `accessibilityReduceMotion` — pulse is removed entirely when set.
struct LivePulseDot: View {
    let color: Color
    let reduceMotion: Bool

    @State private var pulse: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.45))
                .frame(width: 12, height: 12)
                .scaleEffect(pulse)
                .opacity(reduceMotion ? 0 : (1 - pulse))
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 2).repeatForever(autoreverses: false)) {
                pulse = 1.2
            }
        }
    }
}

#Preview("Full popover") {
    MenuBarContent()
        .environment(AppState())
}

// MacVital/Views/Power/PowerView.swift
import SwiftUI
import Charts
import IOKit

// MARK: - Color Palette

private enum PW {
    static let bg       = Color(red: 0x1C/255, green: 0x1C/255, blue: 0x1E/255)
    static let bg2      = Color(red: 0x2C/255, green: 0x2C/255, blue: 0x2E/255)
    static let bg3      = Color(red: 0x3A/255, green: 0x3A/255, blue: 0x3C/255)
    static let text     = Color.white.opacity(0.85)
    static let text2    = Color.white.opacity(0.55)
    static let text3    = Color.white.opacity(0.35)
    static let blue     = Color(red: 0x0A/255, green: 0x84/255, blue: 0xFF/255)
    static let green    = Color(red: 0x32/255, green: 0xD7/255, blue: 0x4B/255)
    static let orange   = Color(red: 0xFF/255, green: 0x9F/255, blue: 0x0A/255)
    static let red      = Color(red: 0xFF/255, green: 0x45/255, blue: 0x3A/255)
    static let yellow   = Color(red: 0xFF/255, green: 0xD6/255, blue: 0x0A/255)
    static let indigo   = Color(red: 0x5E/255, green: 0x5C/255, blue: 0xE6/255)
    static let dim      = Color.white.opacity(0.35)
    static let barEmpty = Color.white.opacity(0.10)
}

// MARK: - Formatters

private enum PowerFormatters {
    static let watts: NumberFormatter = {
        let f = NumberFormatter()
        f.minimumFractionDigits = 1
        f.maximumFractionDigits = 1
        return f
    }()

    static func wattString(_ value: Double) -> String {
        watts.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }
}

// MARK: - Power Tree Node

private struct PowerTreeNode: Identifiable {
    let id = UUID()
    let name: String
    let watts: Double
    let color: Color
    let indent: Int
    let prefix: String           // e.g. "+-", "L-", ""
    let isExpandable: Bool
    var isExpanded: Bool = true
    var children: [PowerTreeNode] = []
    let tooltip: String

    var barCount: Int {
        let maxWatts: Double = 18
        return min(10, Int((watts / maxWatts * 10).rounded()))
    }
}

// MARK: - Power View

struct PowerView: View {
    @Environment(AppState.self) private var appState
    @AppStorage("com.macvital.power.variant") private var variantRaw: Int = PowerVariant.editorial.rawValue

    private var monitor: SystemMonitor { appState.monitor }
    private var bat: BatteryData? { monitor.battery }
    private var selectedVariant: PowerVariant { PowerVariant(rawValue: variantRaw) ?? .editorial }
    private var variantBinding: Binding<PowerVariant> {
        Binding(get: { PowerVariant(rawValue: variantRaw) ?? .editorial }, set: { variantRaw = $0.rawValue })
    }
    private var powerFlowModel: PowerFlowModel {
        PowerFlowModel(
            wallTotal: grandTotal,
            socTotal: socTotal,
            backlight: backlightPower,
            battery: batteryWattage,
            batteryIsCharging: bat?.isCharging ?? false,
            usb: usb1Power + usb2Power,
            fans: fanPower,
            cpu: cpuPower,
            gpu: gpuPower,
            dram: dramPower,
            ane: anePower,
            media: mediaPower,
            isp: ispPower,
            tb: tbPower,
            fabric: fabricPower,
            displaySoC: displaySoCPower,
            uncore: uncorePower
        )
    }

    // MARK: - Real power data from SMC (via privileged XPC helper) or battery

    // Primary power readings — sourced from SMC keys PCPC, PCPG, PSTR via helper
    private var cpuPower: Double { monitor.cpuPower }
    private var gpuPower: Double { monitor.gpuPower }
    private var systemPower: Double { monitor.socPower }
    private var batteryWattage: Double { bat?.wattage ?? 0 }

    /// True when we have real SMC power data (not just battery fallback)
    private var hasRealSMCPower: Bool { cpuPower > 0 || gpuPower > 0 }

    // Sub-component powers — prefer real SMC readings, fall back to proportional estimates.
    // When estimating, proportions are chosen so all SoC sub-components sum to ~PSTR.
    //
    // Typical M4 Pro SoC breakdown at mixed load (~30W PSTR):
    //   CPU ~45%, GPU ~15%, DRAM ~13%, Fabric ~5%, Display(SoC) ~3%,
    //   Thunderbolt ~4%, Media ~1%, GPU SRAM ~2%, ANE ~0% (idle), ISP ~0% (idle)
    //   Residual ~12% covers ring bus, IO, thermal management, etc.

    private var dramPower: Double {
        if monitor.dramPowerSMC > 0 { return monitor.dramPowerSMC }
        guard systemPower > 0 else { return 0 }
        return systemPower * 0.13
    }
    private var anePower: Double {
        // ANE genuinely draws 0W when no ML inference is running — this is correct
        return monitor.anePowerSMC
    }
    private var displaySoCPower: Double {
        if monitor.displayPowerSMC > 0 { return monitor.displayPowerSMC }
        guard systemPower > 0 else { return 0 }
        return systemPower * 0.03
    }
    private var tbPower: Double {
        if monitor.pciePowerSMC > 0 { return monitor.pciePowerSMC }
        guard systemPower > 0 else { return 0 }
        return systemPower * 0.04
    }
    private var fabricPower: Double {
        if monitor.fabricPowerSMC > 0 { return monitor.fabricPowerSMC }
        guard systemPower > 0 else { return 0 }
        return systemPower * 0.05
    }
    private var mediaPower: Double {
        if monitor.mediaPowerSMC > 0 { return monitor.mediaPowerSMC }
        guard systemPower > 0 else { return 0 }
        return systemPower * 0.01
    }
    private var ispPower: Double {
        // ISP genuinely draws 0W when camera is off — this is correct
        return monitor.ispPowerSMC
    }
    private var gpuSramPower: Double {
        if monitor.gpuSramPowerSMC > 0 { return monitor.gpuSramPowerSMC }
        guard gpuPower > 0 else { return 0 }
        return gpuPower * 0.12
    }

    // Non-SoC peripherals — prefer real SMC keys, fall back to estimates
    private var backlightPower: Double {
        if monitor.backlightPowerSMC > 0 { return monitor.backlightPowerSMC }
        guard systemPower > 0 else { return 0 }
        return 3.5 // fallback estimate
    }
    private var backlightIsReal: Bool { monitor.backlightPowerSMC > 0 }

    private var ssdPower: Double {
        guard systemPower > 0 else { return 0 }
        return 0.8
    }
    private var wifiPower: Double {
        guard systemPower > 0 else { return 0 }
        return 0.4
    }
    private var btPower: Double {
        guard systemPower > 0 else { return 0 }
        return 0.1
    }
    private var fanPower: Double {
        let fans = monitor.sensors?.fans ?? []
        guard !fans.isEmpty else { return 0 }
        let totalRPM = Double(fans.map(\.rpm).reduce(0, +))
        return totalRPM / 1500.0 // ~1W per 1500 RPM (real fan data, estimated conversion)
    }

    // Newly discovered SMC readings
    private var deliveryPower: Double { monitor.deliveryPowerSMC }  // PDTR — wall power
    private var pmuPower: Double { monitor.pmuPowerSMC }            // PPMC
    private var psCtrlPower: Double { monitor.psCtrlPowerSMC }      // PPSC
    private var thermalPower: Double { monitor.thermalPowerSMC }    // PTHS
    private var rail5vPower: Double { monitor.rail5vPowerSMC }      // P5SR
    private var rail3vPower: Double { monitor.rail3vPowerSMC }      // P3F2
    private var usb1Power: Double { monitor.usb1PowerSMC }          // PU1C
    private var usb2Power: Double { monitor.usb2PowerSMC }          // PU2C
    private var uncorePower: Double { monitor.uncorePowerSMC }      // PZCU
    private var hiperfBudget: Double { monitor.hiperfBudgetSMC }    // PHPB

    /// Sum of all individually-tracked SoC sub-components (for comparison / residual calc)
    private var socComponentSum: Double {
        cpuPower + gpuPower + anePower + dramPower + gpuSramPower
            + mediaPower + ispPower + displaySoCPower + tbPower + fabricPower
            + thermalPower + pmuPower + uncorePower
    }

    private var socTotal: Double {
        if systemPower > 0 {
            // PSTR is the authoritative SoC total — use it directly
            return systemPower
        }
        return socComponentSum
    }

    private var peripheralTotal: Double {
        backlightPower + ssdPower + wifiPower + btPower + fanPower
            + usb1Power + usb2Power
    }

    private var grandTotal: Double {
        // Prefer PDTR (wall power) if available — it's the true total system draw
        if deliveryPower > 0 { return deliveryPower }
        if systemPower > 0 { return systemPower + peripheralTotal }
        if batteryWattage > 0 { return batteryWattage }
        return 0
    }

    // E/P cluster split — prefer real PZC0/PZC1 SMC keys, fall back to estimates
    private var eCores: Int { monitor.cpu?.efficiencyCoreCount ?? 4 }
    private var pCores: Int { monitor.cpu?.performanceCoreCount ?? 0 }

    private var eClusterPower: Double {
        if monitor.eClusterPowerSMC > 0 { return monitor.eClusterPowerSMC }
        guard cpuPower > 0 else { return 0 }
        return cpuPower * 0.09
    }
    private var eClusterIsReal: Bool { monitor.eClusterPowerSMC > 0 }

    private var pClusterPower: Double {
        if monitor.pClusterPowerSMC > 0 { return monitor.pClusterPowerSMC }
        guard cpuPower > 0 else { return 0 }
        return cpuPower - eClusterPower
    }
    private var pClusterIsReal: Bool { monitor.pClusterPowerSMC > 0 }

    // Top processes sorted by CPU (proxy for energy impact)
    // Watts are estimated from CPU% share of real system power
    private var topProcesses: [(name: String, watts: Double)] {
        guard let procs = monitor.cpu?.topProcesses, !procs.isEmpty else { return [] }
        guard grandTotal > 0 else { return [] }
        return procs.prefix(6).map { proc in
            // Proportional share: process CPU% / 100 * system total * 0.6 (CPU is ~60% of total)
            let estWatts = (proc.cpuUsage / 100.0) * grandTotal * 0.6
            return (proc.name, estWatts)
        }
    }

    // Chip name — cached to avoid sysctlbyname on every body evaluation
    private static let _chipName: String = {
        var buf = [CChar](repeating: 0, count: 256)
        var size = 256
        sysctlbyname("machdep.cpu.brand_string", &buf, &size, nil, 0)
        let name = String(cString: buf)
        return name.isEmpty ? "Apple Silicon" : name
    }()
    private var chipName: String { Self._chipName }

    var body: some View {
        Group {
            if selectedVariant == .editorial {
                EditorialPowerDashboard(monitor: monitor, variantBinding: variantBinding)
            } else {
                HSplitView {
                    leftPanel
                        .frame(minWidth: 340, idealWidth: 400, maxWidth: 440)

                    rightPanel
                }
                .background(PW.bg)
            }
        }
        .navigationTitle("Power / Energy")
    }

    // MARK: - Left Panel (Power Tree)

    private var leftPanel: some View {
        VStack(spacing: 0) {
            treeColumnHeader
            ScrollView {
                VStack(spacing: 0) {
                    totalRow
                    socSection
                    peripheralRows
                    batterySection
                    processesSection
                }
            }
            statusBar
        }
        .background(PW.bg)
    }

    private var treeColumnHeader: some View {
        HStack {
            Text("COMPONENT")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("WATTS")
                .frame(width: 60, alignment: .trailing)
            Text("USAGE")
                .frame(width: 70, alignment: .trailing)
        }
        .font(.system(size: 9, design: .monospaced))
        .foregroundStyle(Color.white.opacity(0.30))
        .textCase(.uppercase)
        .tracking(0.8)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(PW.bg2)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)
        }
    }

    private var totalRow: some View {
        VStack(spacing: 0) {
            treeRow(
                name: "Power / Energy",
                watts: grandTotal,
                color: grandTotal > 0 ? PW.orange : PW.text3,
                indent: 0,
                bold: true,
                barColor: PW.orange,
                barCount: grandTotal > 0 ? 10 : 0
            )
            if grandTotal == 0 {
                Text("Install helper for power data")
                    .font(.system(size: 8.5, design: .monospaced))
                    .foregroundStyle(PW.text3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 2)
            }
        }
        .background(PW.bg2)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
        }
    }

    // MARK: SoC Section

    private var socSection: some View {
        VStack(spacing: 0) {
            // SoC Package header — derived from PSTR or sum
            treeRow(name: "SoC Package", watts: socTotal, color: PW.orange, indent: 1, barColor: PW.orange, tooltip: "PSTR — Total System-on-Chip power draw")

            // CPU — real from SMC PCPC
            treeRow(name: "CPU", watts: cpuPower, color: cpuPower > 8 ? PW.orange : PW.blue, indent: 2, barColor: PW.blue, tooltip: "PCPC — Combined CPU cluster power")

            // E-Cluster — real from PZC0, falls back to estimate
            treeRow(name: "E-Cluster (\(eCores) cores)", watts: eClusterPower, color: PW.green, indent: 3, approximate: !eClusterIsReal && cpuPower > 0, barColor: PW.green, tooltip: "PZC0 — Efficiency cores power draw")

            // P-Clusters — real from PZC1, falls back to estimate
            if pCores > 0 {
                let perCluster = pCores > 4 ? 2 : 1
                let coresPerCluster = pCores / perCluster
                ForEach(0..<perCluster, id: \.self) { idx in
                    let clusterPower = pClusterPower / Double(perCluster)
                    treeRow(
                        name: "P\(idx)-Cluster (\(coresPerCluster) cores)",
                        watts: clusterPower,
                        color: PW.yellow,
                        indent: 3,
                        approximate: !pClusterIsReal && cpuPower > 0,
                        barColor: PW.yellow,
                        tooltip: "PZC1 — Performance cores power draw"
                    )
                }
            }

            // GPU — real from SMC PCPG
            treeRow(name: "GPU", watts: gpuPower, color: gpuPower > 5 ? PW.yellow : PW.green, indent: 2, prefix: "|", barColor: PW.indigo, tooltip: "PCPG — GPU power draw")
            // Sub-components — all estimated proportional from system/GPU power
            treeRow(name: "Neural Engine (ANE)", watts: anePower, color: PW.dim, indent: 2, prefix: "|", barColor: PW.dim, tooltip: "PANE — Apple Neural Engine (0W when idle)")
            treeRow(name: "DRAM", watts: dramPower, color: dramPower > 0 ? PW.green : PW.dim, indent: 2, prefix: "|", approximate: dramPower > 0, barColor: PW.green, tooltip: "PMVC — Unified memory voltage controller")
            treeRow(name: "GPU SRAM", watts: gpuSramPower, color: PW.dim, indent: 2, prefix: "|", approximate: gpuSramPower > 0, barColor: PW.dim, tooltip: "PGSR — GPU on-chip SRAM power")
            treeRow(name: "Media Engine", watts: mediaPower, color: PW.dim, indent: 2, prefix: "|", approximate: mediaPower > 0, barColor: PW.dim, tooltip: "PMEC — Video encode/decode engine power")
            treeRow(name: "ISP (Camera)", watts: ispPower, color: PW.dim, indent: 2, prefix: "|", barColor: PW.dim, tooltip: "PISP — Image signal processor (0W camera off)")
            treeRow(name: "Display (SoC)", watts: displaySoCPower, color: PW.dim, indent: 2, prefix: "|", approximate: displaySoCPower > 0, barColor: PW.dim, tooltip: "PDSP — Display controller inside SoC")
            treeRow(name: "Thunderbolt/PCIe", watts: tbPower, color: PW.dim, indent: 2, prefix: "|", approximate: tbPower > 0, barColor: PW.dim, tooltip: "PPCI — Thunderbolt & PCIe controller power")
            treeRow(name: "Fabric (AMCC/DCS)", watts: fabricPower, color: PW.dim, indent: 2, prefix: "|", approximate: fabricPower > 0, barColor: PW.dim, tooltip: "PAMCC — Memory fabric & interconnect bus")
            if thermalPower > 0 {
                treeRow(name: "Thermal Subsystem", watts: thermalPower, color: thermalPower > 5 ? PW.orange : PW.dim, indent: 2, prefix: "|", barColor: PW.orange, tooltip: "PTHS — Thermal management & cooling power")
            }
            if pmuPower > 0 {
                treeRow(name: "PMU Controller", watts: pmuPower, color: PW.dim, indent: 2, prefix: "|", barColor: PW.dim, tooltip: "PPMC — Power management unit controller")
            }
            if uncorePower > 0 {
                treeRow(name: "Uncore", watts: uncorePower, color: PW.dim, indent: 2, prefix: "L", barColor: PW.dim, tooltip: "PZCU — Ring bus, IO, and uncore logic")
            } else {
                // Ensure last SoC row gets "L" prefix
            }
        }
    }

    // MARK: Peripheral rows

    private var peripheralRows: some View {
        VStack(spacing: 0) {
            treeRow(name: "Display (Backlight)", watts: backlightPower, color: PW.green, indent: 1, prefix: "|", approximate: !backlightIsReal, barColor: PW.green, tooltip: "PDTR derived — LCD/OLED panel backlight power")
            treeRow(name: "SSD", watts: ssdPower, color: PW.dim, indent: 1, prefix: "|", approximate: true, barColor: PW.dim, tooltip: "Estimated — NVMe SSD idle draw (~0.8W typical)")
            treeRow(name: "WiFi", watts: wifiPower, color: PW.dim, indent: 1, prefix: "|", approximate: true, barColor: PW.dim, tooltip: "Estimated — WiFi radio idle draw (~0.4W typical)")
            treeRow(name: "Bluetooth", watts: btPower, color: PW.dim, indent: 1, prefix: "|", approximate: true, barColor: PW.dim, tooltip: "Estimated — Bluetooth idle draw (~0.1W typical)")
            if usb1Power > 0 || usb2Power > 0 {
                treeRow(name: "USB-C Port 1", watts: usb1Power, color: PW.dim, indent: 1, prefix: "|", barColor: PW.dim, tooltip: "PU1C — USB-C port 1 power delivery")
                treeRow(name: "USB-C Port 2", watts: usb2Power, color: PW.dim, indent: 1, prefix: "|", barColor: PW.dim, tooltip: "PU2C — USB-C port 2 power delivery")
            }
            treeRow(name: "Fans", watts: fanPower, color: PW.green, indent: 1, prefix: "L", approximate: true, barColor: PW.green, tooltip: "Estimated from RPM — ~1W per 1500 RPM")
        }
    }

    // MARK: Battery Section

    private var batterySection: some View {
        VStack(spacing: 0) {
            if let b = bat {
                let statusText = b.isCharging ? "(chrgng)" : "(dischg)"
                let statusColor = b.isCharging ? PW.green : PW.orange

                treeRow(name: "Battery", watts: b.wattage, color: statusColor, indent: 1, bold: true, barColor: statusColor, suffix: statusText)
                treeRow(name: "Voltage", watts: b.voltage, color: PW.dim, indent: 2, prefix: "|", unit: "V", barColor: PW.dim, showBar: false)
                treeRow(name: "Current", watts: abs(Double(b.amperage)) / 1000.0, color: PW.dim, indent: 2, prefix: "|", unit: "A", barColor: PW.dim, showBar: false)
                treeRow(name: "AC Adapter", watts: 0, color: PW.text, indent: 2, prefix: "L", unit: "", barColor: PW.dim, showBar: false, suffixRight: b.isCharging ? "USB-C" : "Battery")
            }
        }
    }

    // MARK: Processes Section

    private var processesSection: some View {
        VStack(spacing: 0) {
            // Section header
            Text("TOP PROCESSES  (BY ENERGY IMPACT)")
                .font(.system(size: 9, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundStyle(Color.white.opacity(0.25))
                .tracking(1.2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(PW.bg2)
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)
                }
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1)
                }

            ForEach(Array(topProcesses.enumerated()), id: \.offset) { idx, proc in
                let processColor: Color = proc.watts > 3 ? PW.orange : (proc.watts > 1 ? PW.yellow : (proc.watts > 0.3 ? PW.green : PW.dim))
                treeRow(
                    name: "\(idx + 1)  \(proc.name)",
                    watts: proc.watts,
                    color: processColor,
                    indent: 1,
                    barColor: processColor
                )
            }
        }
    }

    // MARK: Status Bar

    private var statusBar: some View {
        HStack(spacing: 0) {
            statusItem(label: "Total", value: PowerFormatters.wattString(grandTotal) + " W", color: PW.orange)
            statusSeparator
            statusItem(label: "SoC", value: PowerFormatters.wattString(socTotal) + " W", color: PW.text2)
            statusSeparator
            if let b = bat {
                statusItem(
                    label: "Batt",
                    value: (b.isCharging ? "Charging " : "Discharging ") + "\(Int(b.percentage))%",
                    color: b.isCharging ? PW.green : PW.orange
                )
                statusSeparator
            }
            statusItem(label: "CPU", value: PowerFormatters.wattString(cpuPower) + " W", color: PW.text2)
            Spacer()
        }
        .padding(.horizontal, 10)
        .frame(height: 22)
        .background(PW.bg2)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
        }
    }

    private func statusItem(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .foregroundStyle(Color.white.opacity(0.25))
            Text(value)
                .foregroundStyle(color)
                .lineLimit(1)
                .fixedSize()
        }
        .font(.system(size: 9.5, design: .monospaced))
    }

    private var statusSeparator: some View {
        Text("|")
            .font(.system(size: 9.5, design: .monospaced))
            .foregroundStyle(Color.white.opacity(0.10))
            .padding(.horizontal, 6)
    }

    // MARK: - Tree Row Builder

    private func treeRow(
        name: String,
        watts: Double,
        color: Color,
        indent: Int,
        bold: Bool = false,
        prefix: String = "",
        approximate: Bool = false,
        unit: String = "W",
        barColor: Color = PW.green,
        barCount customBar: Int? = nil,
        showBar: Bool = true,
        suffix: String = "",
        suffixRight: String = "",
        tooltip: String = ""
    ) -> some View {
        HStack(spacing: 0) {
            // Name with indent
            HStack(spacing: 4) {
                HStack(spacing: 0) {
                    if !prefix.isEmpty {
                        Text(prefix == "L" ? "\u{2514} " : (prefix == "|" ? "\u{251C} " : ""))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.20))
                    }
                    Text(name)
                        .lineLimit(1)
                }
                if !tooltip.isEmpty {
                    Image(systemName: "info.circle")
                        .font(.system(size: 9))
                        .foregroundStyle(PW.text3)
                        .help(tooltip)
                }
            }
            .font(.system(size: 10, weight: bold ? .bold : .regular, design: .monospaced))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Watts value
            if !suffix.isEmpty {
                // Show both watts and suffix
                Text(PowerFormatters.wattString(watts) + " " + unit)
                    .font(.system(size: 10, weight: bold ? .bold : .regular, design: .monospaced))
                    .foregroundStyle(color)
                    .frame(width: 60, alignment: .trailing)
            } else if !suffixRight.isEmpty {
                Text(suffixRight)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(PW.text3)
                    .frame(width: 60, alignment: .trailing)
            } else {
                let wattsText = approximate
                    ? "\u{2248} " + PowerFormatters.wattString(watts) + " " + unit
                    : PowerFormatters.wattString(watts) + " " + unit
                Text(wattsText)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(color)
                    .frame(width: 60, alignment: .trailing)
            }

            // Bar or suffix
            if showBar {
                let count = customBar ?? barCountFor(watts: watts)
                HStack(spacing: 1) {
                    ForEach(0..<10, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(i < count ? barColor : PW.barEmpty)
                            .frame(width: 4, height: 7)
                    }
                }
                .frame(width: 70, alignment: .trailing)
            } else if !suffix.isEmpty {
                Text(suffix)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(color.opacity(0.7))
                    .lineLimit(1)
                    .frame(width: 70, alignment: .trailing)
            } else {
                Spacer().frame(width: 70)
            }
        }
        .padding(.leading, CGFloat(indent) * 8 + 8)
        .padding(.trailing, 8)
        .padding(.vertical, 1)
        .frame(minHeight: 17)
        .contentShape(Rectangle())
    }

    private func barCountFor(watts: Double) -> Int {
        let maxW: Double = 18
        return min(10, Int((watts / maxW * 10).rounded()))
    }

    // MARK: - Right Panel

    private var rightPanel: some View {
        ScrollView {
            VStack(spacing: 12) {
                overviewSection
                if deliveryPower > 0 || thermalPower > 0 {
                    powerDeliverySection
                }
                breakdownSection
                historySection
                bottomGrid
            }
            .padding(16)
        }
        .background(PW.bg)
    }

    // MARK: Overview Gauges

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionLabel("POWER OVERVIEW")
                Spacer()
                Text(hasRealSMCPower ? "SMC" : (systemPower > 0 ? "BATTERY" : "NO DATA"))
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(hasRealSMCPower ? PW.green : (systemPower > 0 ? PW.yellow : PW.red))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background((hasRealSMCPower ? PW.green : (systemPower > 0 ? PW.yellow : PW.red)).opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }

            HStack(spacing: 10) {
                powerGauge(label: "SYSTEM TOTAL", watts: grandTotal, maxWatts: 60, color: PW.orange, detail: grandTotal > 0 ? "\(Int(grandTotal / 60 * 100))% TDP" : "---")
                powerGauge(label: "SoC PACKAGE", watts: socTotal, maxWatts: 45, color: PW.orange, detail: socTotal > 0 ? "\(Int(socTotal / 45 * 100))% SoC" : "---")
                powerGauge(label: "CPU", watts: cpuPower, maxWatts: 30, color: PW.blue, detail: cpuPower > 0 ? "\(Int(cpuPower / 30 * 100))% CPU" : "---")
                powerGauge(label: "GPU", watts: gpuPower, maxWatts: 20, color: PW.indigo, detail: gpuPower > 0 ? "\(Int(gpuPower / 20 * 100))% GPU" : "---")
            }
        }
        .padding(.top, 6)
    }

    private func powerGauge(label: String, watts: Double, maxWatts: Double, color: Color, detail: String) -> some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.system(size: 8.5, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.30))
                .tracking(1.2)

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.07), lineWidth: 6)

                Circle()
                    .trim(from: 0, to: min(watts / maxWatts, 1.0))
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.smooth(duration: 0.6), value: watts)

                VStack(spacing: 1) {
                    Text(PowerFormatters.wattString(watts))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    Text("WATTS")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.40))
                        .tracking(0.3)
                    Text(detail)
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.30))
                }
            }
            .frame(width: 72, height: 72)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
        .background(PW.bg2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: Power Delivery & Rails

    private var powerDeliverySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("POWER DELIVERY & RAILS")

            let items: [(String, Double, String)] = [
                ("Wall Power (PDTR)", deliveryPower, "Total input from adapter"),
                ("SoC Package (PSTR)", socTotal, "System-on-Chip total"),
                ("Thermal Subsystem", thermalPower, "Cooling & thermal mgmt"),
                ("PMU Controller", pmuPower, "Power management unit"),
                ("Power Supply Ctrl", psCtrlPower, "Voltage regulation"),
                ("5V Rail (P5SR)", rail5vPower, "Peripherals, USB, etc"),
                ("3.3V Rail (P3F2)", rail3vPower, "Logic, I/O, sensors"),
                ("Uncore (PZCU)", uncorePower, "Interconnect, ring bus"),
            ].filter { $0.1 > 0 }

            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 8) {
                    Text(item.0)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(PW.text)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(PowerFormatters.wattString(item.1) + " W")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(item.1 > 10 ? PW.orange : PW.green)
                        .monospacedDigit()
                        .frame(width: 60, alignment: .trailing)
                }
                .padding(.vertical, 2)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Color.white.opacity(0.04)).frame(height: 1)
                }
            }

            if hiperfBudget > 0 {
                HStack(spacing: 4) {
                    Text("Hi-Perf Budget:")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(PW.text3)
                    Text("\(Int(hiperfBudget)) W")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(PW.text2)
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .background(PW.bg2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: Breakdown Stacked Bar

    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionLabel("POWER FLOW")
                Spacer()
                PowerVariantPicker(selection: variantBinding)
            }
            powerFlowVariantBody
        }
        .padding(14)
        .background(PW.bg2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var powerFlowVariantBody: some View {
        switch selectedVariant {
        case .editorial:        EmptyView()  // editorial dashboard is rendered by the parent
        case .sankey:           PowerFlowSankey(model: powerFlowModel)
        case .treemap:          PowerFlowTreemap(model: powerFlowModel)
        case .radialSunburst:   PowerFlowRadialSunburst(model: powerFlowModel)
        case .stackedLaneFlow:  PowerFlowStackedLaneFlow(model: powerFlowModel)
        case .rankList:         PowerFlowRankList(model: powerFlowModel)
        }
    }

    // MARK: Power History Chart

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("POWER HISTORY · 60s")

            let history = monitor.powerHistory
            if history.isEmpty {
                Text(systemPower > 0 ? "Collecting data..." : "Waiting for power data...")
                    .font(.system(size: 11))
                    .foregroundStyle(PW.text3)
                    .frame(height: 90)
                    .frame(maxWidth: .infinity)
            } else {
                Chart {
                    ForEach(Array(history.enumerated()), id: \.offset) { index, value in
                        AreaMark(
                            x: .value("Time", index),
                            y: .value("Watts", value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [PW.orange.opacity(0.3), PW.orange.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)

                        LineMark(
                            x: .value("Time", index),
                            y: .value("Watts", value)
                        )
                        .foregroundStyle(PW.orange)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text("\(Int(v))W")
                                    .font(.system(size: 8.5, design: .monospaced))
                                    .foregroundStyle(Color.white.opacity(0.20))
                            }
                        }
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                            .foregroundStyle(Color.white.opacity(0.06))
                    }
                }
                .chartYScale(domain: 0...max((history.max() ?? 10) * 1.2, 10))
                .frame(height: 90)
                .animation(.smooth, value: history)
            }
        }
        .padding(14)
        .background(PW.bg2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: Bottom Grid (USB + Battery)

    private var bottomGrid: some View {
        HStack(alignment: .top, spacing: 10) {
            usbSection
            batteryCardSection
        }
    }

    // USB Power section — shows real USB devices from IORegistry
    private var usbDevices: [(name: String, currentMA: Int)] {
        var devices: [(String, Int)] = []
        let matchDict = IOServiceMatching("IOUSBHostDevice") as NSDictionary
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matchDict, &iterator) == kIOReturnSuccess else {
            return devices
        }
        defer { IOObjectRelease(iterator) }
        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer { IOObjectRelease(service); service = IOIteratorNext(iterator) }
            var props: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess,
                  let dict = props?.takeRetainedValue() as? [String: Any] else { continue }
            let name = dict["USB Product Name"] as? String
                ?? dict["kUSBProductString"] as? String
            let currentMA = dict["Current Available"] as? Int
                ?? dict["kUSBDeviceMaxPower"] as? Int
                ?? 0
            // Skip internal hubs and root hubs
            if let n = name, !n.lowercased().contains("root hub"), !n.lowercased().contains("xhci"), currentMA > 0 {
                devices.append((n, currentMA))
            }
        }
        return devices
    }

    private var usbSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("USB POWER")

            let devs = usbDevices
            if devs.isEmpty {
                HStack(spacing: 10) {
                    usbPortCard(portName: "USB-C", deviceName: nil, watts: 0, detail: "", isCharging: false)
                }
            } else {
                let columns = min(devs.count, 2)
                HStack(spacing: 10) {
                    ForEach(Array(devs.prefix(columns).enumerated()), id: \.offset) { _, dev in
                        let watts = Double(dev.currentMA) * 5.0 / 1000.0 // USB 5V * mA
                        usbPortCard(
                            portName: "USB-C",
                            deviceName: dev.name,
                            watts: watts,
                            detail: "\(dev.currentMA) mA @ 5V",
                            isCharging: false
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func usbPortCard(portName: String, deviceName: String?, watts: Double, detail: String, isCharging: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(portName)
                .font(.system(size: 8.5, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.30))
                .tracking(1.2)

            if let device = deviceName {
                Text(device)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)

                Text(PowerFormatters.wattString(watts) + " W")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(PW.green)
                    .monospacedDigit()

                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(PW.text3)

                badgeView(text: isCharging ? "CHARGING" : "CONNECTED", color: isCharging ? PW.green : PW.blue)
            } else {
                Text("No device")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.20))
                    .padding(.top, 10)

                badgeView(text: "EMPTY", color: Color.white.opacity(0.25))
                    .padding(.top, 8)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PW.bg2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func badgeView(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(color)
            .tracking(0.5)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(color.opacity(0.25), lineWidth: 1)
            )
    }

    // Battery card section
    private var batteryCardSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("BATTERY")

            if let b = bat {
                HStack(spacing: 0) {
                    // Left: ring + status
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.07), lineWidth: 5)
                            Circle()
                                .trim(from: 0, to: b.percentage / 100)
                                .stroke(PW.green, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                                .rotationEffect(.degrees(-90))

                            VStack(spacing: 1) {
                                Text("\(Int(b.percentage))%")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(PW.green)
                                    .monospacedDigit()
                                Text("BATT")
                                    .font(.system(size: 7.5))
                                    .foregroundStyle(PW.text3)
                            }
                        }
                        .frame(width: 60, height: 60)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("STATUS")
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.30))
                                .tracking(1.2)
                            Text(PowerFormatters.wattString(b.wattage) + " W")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(b.isCharging ? PW.green : PW.orange)
                                .monospacedDigit()
                            Text(b.isCharging ? "Charging" : "Discharging")
                                .font(.system(size: 10))
                                .foregroundStyle(PW.text3)
                                .lineLimit(1)
                                .fixedSize()
                        }
                    }
                    .padding(14)

                    // Divider
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 1)

                    // Right: details
                    VStack(alignment: .leading, spacing: 0) {
                        Text("DETAILS")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.30))
                            .tracking(1.2)
                            .padding(.bottom, 6)

                        batteryDetailRow(key: "Voltage", value: String(format: "%.1f V", b.voltage))
                        batteryDetailRow(key: "Current", value: String(format: "%.2f A", abs(Double(b.amperage)) / 1000.0))
                        batteryDetailRow(key: "Health", value: String(format: "%.0f%%", b.healthPercent))
                        if b.timeRemaining >= 0 {
                            batteryDetailRow(key: b.isCharging ? "Time to full" : "Time left", value: "~\(b.timeRemaining / 60)h \(b.timeRemaining % 60)m")
                        }
                    }
                    .padding(14)
                }
            } else {
                Text("No battery detected")
                    .font(.system(size: 12))
                    .foregroundStyle(PW.text3)
                    .padding(14)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PW.bg2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func batteryDetailRow(key: String, value: String) -> some View {
        HStack {
            Text(key)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(PW.text3)
            Spacer()
            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.75))
        }
        .padding(.vertical, 5)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1)
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9.5, weight: .semibold))
            .foregroundStyle(Color.white.opacity(0.30))
            .tracking(1.5)
    }
}

// MARK: - Flow Layout (for breakdown legend)

private struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private struct ArrangeResult {
        let size: CGSize
        let positions: [CGPoint]
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> ArrangeResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + 8
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX)
        }

        return ArrangeResult(
            size: CGSize(width: totalWidth, height: currentY + lineHeight),
            positions: positions
        )
    }
}

// MARK: - Editorial Power Dashboard
// Light-themed editorial dashboard: header strip + total-delivery donut card,
// power-flow Sankey card, and a 24-rail live grid. Pixel-faithful to the
// supplied mockup; data sourced from existing SystemMonitor SMC keys.

private struct PowerRail: Identifiable {
    let id = UUID()
    let code: String       // e.g. "PHPB"
    let name: String       // e.g. "HP budget"
    let watts: Double
    let color: Color
    let isHeader: Bool     // big totals like PHPB/PSTR/PDTR get accent rendering
}

private enum PowerCategory: String, CaseIterable {
    case display, system, compute, io, gpu, memory, accelerators
    var color: Color {
        switch self {
        case .display:      return EditorialPalette.teal
        case .system:       return EditorialPalette.systemGrey
        case .compute:      return EditorialPalette.compute
        case .io:           return EditorialPalette.io
        case .gpu:          return EditorialPalette.gpu
        case .memory:       return EditorialPalette.memory
        case .accelerators: return EditorialPalette.accel
        }
    }
    var label: String {
        switch self {
        case .display:      return "DISPLAY · RAILS"
        case .system:       return "SYSTEM"
        case .compute:      return "COMPUTE"
        case .io:           return "I/O"
        case .gpu:          return "GPU"
        case .memory:       return "MEMORY"
        case .accelerators: return "ACCELERATORS"
        }
    }
}

private struct EditorialPowerDashboard: View {
    let monitor: SystemMonitor
    let variantBinding: Binding<PowerVariant>

    // Snapshot rails using SMC field codes
    private var rails: [PowerRail] {
        let m = monitor
        let bat = m.battery
        let socTotal = m.socPower
        let dtr  = m.deliveryPowerSMC
        let raw: [(String, String, Double, PowerCategory, Bool)] = [
            ("PHPB", "HP budget",     m.hiperfBudgetSMC,         .compute, true),
            ("PDTR", "Total delivery", dtr > 0 ? dtr : (socTotal + (bat?.wattage ?? 0)), .system, true),
            ("PSTR", "SoC total",     socTotal,                  .display, true),
            ("PHPS", "HP sustained",  m.hiperfSustPowerSMC,      .system, false),
            ("PCPC", "CPU package",   m.cpuPower,                .compute, false),
            ("PZC1", "P-cluster",     m.pClusterPowerSMC,        .compute, false),
            ("PU2C", "USB-C port 2",  m.usb2PowerSMC,            .io, false),
            ("PCPG", "GPU package",   m.gpuPower,                .gpu, false),
            ("P5SR", "5 V rail",      m.rail5vPowerSMC,          .io, false),
            ("PZCU", "Uncore",        m.uncorePowerSMC,          .compute, false),
            ("PDBR", "Backlight",     m.backlightPowerSMC,       .display, false),
            ("PMVC", "DRAM",          m.dramPowerSMC,            .memory, false),
            ("PZC0", "E-cluster",     m.eClusterPowerSMC,        .compute, false),
            ("PPBR", "PCIe",          m.pciePowerSMC,            .io, false),
            ("P3F2", "3.3 V rail",    m.rail3vPowerSMC,          .io, false),
            ("PDCS", "Fabric",        m.fabricPowerSMC,          .io, false),
            ("PANT", "Neural Engine", m.anePowerSMC,             .accelerators, false),
            ("PSRA", "GPU SRAM",      m.gpuSramPowerSMC,         .gpu, false),
            ("PMED", "Media",         m.mediaPowerSMC,           .accelerators, false),
            ("PPMC", "PMU",           m.pmuPowerSMC,             .system, false),
            ("PISP", "ISP",           m.ispPowerSMC,             .accelerators, false),
            ("PTHS", "Thermal",       m.thermalPowerSMC,         .system, false),
            ("PU1C", "USB-C port 1",  m.usb1PowerSMC,            .io, false),
            ("PPSC", "PSU ctrl",      m.psCtrlPowerSMC,          .system, false),
        ]
        return raw.map { PowerRail(code: $0.0, name: $0.1, watts: $0.2, color: $0.3.color, isHeader: $0.4) }
    }

    // Sort by watts desc (mockup shows DRAW DESC)
    private var sortedRails: [PowerRail] { rails.sorted { $0.watts > $1.watts } }

    // Category totals for donut + legend (informed by mockup numerical share).
    // fileprivate (was private) so sibling structs in this same source file
    // can reference it as EditorialPowerDashboard.CategorySlice without
    // compile errors.
    fileprivate struct CategorySlice: Identifiable {
        let id = UUID()
        let category: PowerCategory
        let watts: Double
    }

    private var categorySlices: [CategorySlice] {
        let m = monitor
        // Display·Rails: backlight + 5V + 3.3V + USB ports (everything the panel/IO rails carry)
        let display = m.backlightPowerSMC + m.rail5vPowerSMC + m.rail3vPowerSMC
        // System: PMU + thermal + PSU + uncore + sustained budget reserve
        let system  = m.pmuPowerSMC + m.thermalPowerSMC + m.psCtrlPowerSMC + m.uncorePowerSMC
        // Compute: CPU package = sum of clusters
        let compute = m.cpuPower
        // I/O: PCIe + Fabric + USB
        let io      = m.pciePowerSMC + m.fabricPowerSMC + m.usb1PowerSMC + m.usb2PowerSMC
        // GPU
        let gpu     = m.gpuPower + m.gpuSramPowerSMC
        // Memory
        let memory  = m.dramPowerSMC
        // Accelerators
        let accel   = m.anePowerSMC + m.mediaPowerSMC + m.ispPowerSMC
        return [
            CategorySlice(category: .display,      watts: display),
            CategorySlice(category: .system,       watts: system),
            CategorySlice(category: .compute,      watts: compute),
            CategorySlice(category: .io,           watts: io),
            CategorySlice(category: .gpu,          watts: gpu),
            CategorySlice(category: .memory,       watts: memory),
            CategorySlice(category: .accelerators, watts: accel),
        ]
        .sorted { $0.watts > $1.watts }
    }

    private var pdtr: Double {
        let v = monitor.deliveryPowerSMC
        if v > 0 { return v }
        return monitor.socPower + (monitor.battery?.wattage ?? 0)
    }
    private var ceilingBudget: Double { max(monitor.hiperfBudgetSMC, 22) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                EditorialPageHeader(
                    title: "Power",
                    subtitle: "SMC RAILS · 24 LIVE · CATEGORISED · 1 Hz",
                    chipDot: EditorialPalette.compute,
                    chipText: String(format: "PDTR · %.2f W · CEILING %d W", pdtr, Int(ceilingBudget.rounded()))
                )

                HStack(alignment: .top, spacing: 16) {
                    TotalDeliveryCard(slices: categorySlices, total: pdtr, history: monitor.powerHistory)
                        .frame(minWidth: 360, idealWidth: 420)
                    PowerFlowCard(
                        acInlet: max(0, pdtr),
                        battery: monitor.battery?.wattage ?? 0,
                        batteryCharging: monitor.battery?.isCharging ?? false,
                        slices: categorySlices
                    )
                    .frame(maxWidth: .infinity)
                }

                LiveRailsCard(rails: sortedRails)

                // Optional: small variant strip at bottom, switch back to other Power variants if desired
                HStack {
                    EditorialLabel(text: "VARIANT", color: EditorialPalette.inkDim, size: 9.5, tracking: 1.4)
                    PowerVariantPicker(selection: variantBinding)
                    Spacer()
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
        }
        .background(EditorialPalette.bg)
    }
}

// MARK: Total Delivery Card

private struct TotalDeliveryCard: View {
    let slices: [EditorialPowerDashboard.CategorySlice]
    let total: Double
    let history: [Double]

    private var displayedTotal: Double {
        slices.map(\.watts).reduce(0, +).rounded() > 0
            ? max(total, slices.map(\.watts).reduce(0, +))
            : total
    }

    var body: some View {
        EditorialCard(title: "Total delivery", trailing: "PDTR · 60 S") {
            HStack(alignment: .top, spacing: 18) {
                DonutChart(slices: slices, center: total)
                    .frame(width: 158, height: 158)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(slices) { s in
                        legendRow(category: s.category, watts: s.watts)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Sparkline of last 60 s
            VStack(alignment: .leading, spacing: 6) {
                Sparkline(values: history.isEmpty ? [total, total] : history, color: EditorialPalette.compute)
                    .frame(height: 44)

                HStack(spacing: 8) {
                    EditorialLabel(text: "−60 S", color: EditorialPalette.inkDim, size: 9.5, tracking: 1.2)
                    Rectangle().fill(EditorialPalette.hairline).frame(height: 1)
                    EditorialLabel(text: "NOW · STEADY UNDER P-STATE 4", color: EditorialPalette.inkDim, size: 9.5, tracking: 1.2)
                }
            }
            .padding(.top, 6)
        }
        .overlay(alignment: .topTrailing) {
            EmptyView()
        }
        .overlay {
            // Donut center label
            GeometryReader { _ in
                VStack(spacing: 1) {
                    Text(String(format: "%.2f", total))
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(EditorialPalette.ink)
                        .monospacedDigit()
                    EditorialLabel(text: "WATTS", color: EditorialPalette.inkMuted, size: 9, tracking: 2)
                }
                .frame(width: 158, height: 158, alignment: .center)
                .offset(x: 20, y: 60)  // align to donut frame (left pad 20 + title row ~ 42)
                .allowsHitTesting(false)
            }
        }
    }

    private func legendRow(category: PowerCategory, watts: Double) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(category.color)
                .frame(width: 10, height: 10)
            EditorialLabel(text: category.label, color: EditorialPalette.inkMuted, size: 10.5, tracking: 1.2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(String(format: "%.2f W", watts))
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(EditorialPalette.ink)
                .monospacedDigit()
        }
    }
}

// MARK: Donut Chart

private struct DonutChart: View {
    let slices: [EditorialPowerDashboard.CategorySlice]
    let center: Double

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let lineWidth: CGFloat = 22
            let radius = (size - lineWidth) / 2
            let total = max(slices.map(\.watts).reduce(0, +), 0.0001)
            ZStack {
                Circle()
                    .stroke(EditorialPalette.trackEmpty, lineWidth: lineWidth)
                    .frame(width: size - lineWidth, height: size - lineWidth)
                ForEach(arcs(total: total)) { arc in
                    Circle()
                        .trim(from: arc.start, to: arc.end)
                        .stroke(arc.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                        .rotationEffect(.degrees(-90))
                        .frame(width: size - lineWidth, height: size - lineWidth)
                }
            }
            .frame(width: size, height: size)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }

    private struct Arc: Identifiable { let id = UUID(); let start: Double; let end: Double; let color: Color }
    private func arcs(total: Double) -> [Arc] {
        var acc = 0.0
        var out: [Arc] = []
        let gap = 0.004
        for s in slices {
            let frac = s.watts / total
            guard frac > 0.0001 else { continue }
            let start = acc + gap / 2
            let end = acc + frac - gap / 2
            out.append(Arc(start: start, end: end, color: s.category.color))
            acc += frac
        }
        return out
    }
}

// MARK: Sparkline

private struct Sparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let pts = values.suffix(60).map { $0 }
            if pts.count >= 2 {
                let lo = pts.min() ?? 0
                let hi = pts.max() ?? 1
                let span = max(hi - lo, 0.5)
                ZStack {
                    // Reference dashed lines (top + middle + bottom)
                    ForEach(0..<3) { i in
                        Path { p in
                            let y = geo.size.height * CGFloat(i) / 2
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: geo.size.width, y: y))
                        }
                        .stroke(EditorialPalette.hairline, style: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                    }
                    Path { p in
                        for (i, v) in pts.enumerated() {
                            let x = geo.size.width * CGFloat(i) / CGFloat(pts.count - 1)
                            let y = geo.size.height * (1 - CGFloat((v - lo) / span))
                            if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                            else { p.addLine(to: CGPoint(x: x, y: y)) }
                        }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))

                    // Trailing dot
                    if let last = pts.last {
                        let x = geo.size.width
                        let y = geo.size.height * (1 - CGFloat((last - lo) / span))
                        Circle().fill(color).frame(width: 5, height: 5).position(x: x - 2, y: y)
                    }
                }
            }
        }
    }
}

// MARK: Power Flow Card (Sankey)

private struct PowerFlowCard: View {
    let acInlet: Double
    let battery: Double           // signed in BatteryData; here we treat positive=discharge contribution, charging consumed
    let batteryCharging: Bool
    let slices: [EditorialPowerDashboard.CategorySlice]

    private var sources: [(label: String, watts: Double, color: Color)] {
        // When discharging, battery contributes alongside AC
        let bw = max(0, battery)
        let acContribution = batteryCharging ? acInlet + bw : acInlet
        return [
            ("AC INLET", acContribution, EditorialPalette.ink.opacity(0.85)),
            ("BATTERY",  batteryCharging ? 0 : bw, EditorialPalette.systemGrey),
        ]
    }

    var body: some View {
        EditorialCard(title: "Power flow", trailing: "SOURCE → CONSUMER") {
            SankeyView(sources: sources, destinations: slices.filter { $0.watts > 0.05 })
                .frame(height: 280)
        }
    }
}

private struct SankeyView: View {
    let sources: [(label: String, watts: Double, color: Color)]
    let destinations: [EditorialPowerDashboard.CategorySlice]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let leftX:  CGFloat = 0
            let rightX: CGFloat = w - 110  // leave room for right labels
            let barW:   CGFloat = 12

            let srcTotal = max(sources.map(\.watts).reduce(0, +), 0.0001)
            let dstTotal = max(destinations.map(\.watts).reduce(0, +), 0.0001)

            // Pre-compute layout. Wrapped in an inline closure so the imperative
            // `for` accumulation is not parsed as ViewBuilder content (which
            // doesn't allow control-flow with mutable state).
            let srcGap: CGFloat = 14
            let srcLayout: (ys: [CGFloat], hs: [CGFloat]) = {
                let avail = h - srcGap * CGFloat(max(0, sources.count - 1))
                var ys: [CGFloat] = []
                var hs: [CGFloat] = []
                var y: CGFloat = 0
                for s in sources {
                    let hgt = avail * CGFloat(s.watts / srcTotal)
                    ys.append(y)
                    hs.append(hgt)
                    y += hgt + srcGap
                }
                return (ys, hs)
            }()
            let srcYs = srcLayout.ys
            let srcHs = srcLayout.hs

            let dstGap: CGFloat = 10
            let dstLayout: (ys: [CGFloat], hs: [CGFloat]) = {
                let avail = h - dstGap * CGFloat(max(0, destinations.count - 1))
                var ys: [CGFloat] = []
                var hs: [CGFloat] = []
                var dy: CGFloat = 0
                for d in destinations {
                    let hgt = avail * CGFloat(d.watts / dstTotal)
                    ys.append(dy)
                    hs.append(hgt)
                    dy += hgt + dstGap
                }
                return (ys, hs)
            }()
            let dstYs = dstLayout.ys
            let dstHs = dstLayout.hs

            ZStack(alignment: .topLeading) {
                // Source bars
                ForEach(Array(sources.enumerated()), id: \.offset) { i, s in
                    Rectangle()
                        .fill(s.color)
                        .frame(width: barW, height: srcHs[i])
                        .offset(x: leftX, y: srcYs[i])
                    Text(s.label)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(EditorialPalette.inkMuted)
                        .offset(x: leftX + barW + 6, y: srcYs[i] + max(2, srcHs[i] / 2 - 14))
                    Text(String(format: "%.1f W", s.watts))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(EditorialPalette.ink)
                        .monospacedDigit()
                        .offset(x: leftX + barW + 6, y: srcYs[i] + max(2, srcHs[i] / 2 - 2))
                }

                // Flows: For each (source, destination) pair, draw a band proportional to
                // source.share × destination.share (rough but visually clean)
                ForEach(Array(sources.enumerated()), id: \.offset) { si, s in
                    ForEach(Array(destinations.enumerated()), id: \.offset) { di, d in
                        let frac = (s.watts / srcTotal) * (d.watts / dstTotal)
                        let flowSrcH = srcHs[si] * CGFloat(d.watts / dstTotal)
                        let flowDstH = dstHs[di] * CGFloat(s.watts / srcTotal)
                        let srcOffset = srcOffsets(sources: sources, srcHs: srcHs, srcIndex: si, destIndex: di, destinations: destinations, dstTotal: dstTotal)
                        let dstOffset = dstOffsets(destinations: destinations, dstHs: dstHs, dstIndex: di, srcIndex: si, sources: sources, srcTotal: srcTotal)
                        SankeyBand(
                            startX: leftX + barW,
                            startY: srcYs[si] + srcOffset,
                            startH: flowSrcH,
                            endX: rightX,
                            endY: dstYs[di] + dstOffset,
                            endH: flowDstH,
                            color: d.category.color.opacity(0.55)
                        )
                        .opacity(max(0.18, min(0.9, frac * 6)))
                    }
                }

                // Destination bars + labels
                ForEach(Array(destinations.enumerated()), id: \.offset) { i, d in
                    Rectangle()
                        .fill(d.category.color)
                        .frame(width: barW, height: dstHs[i])
                        .offset(x: rightX, y: dstYs[i])
                    Text(d.category.label)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(EditorialPalette.inkMuted)
                        .offset(x: rightX + barW + 6, y: dstYs[i] + max(2, dstHs[i] / 2 - 14))
                    Text(String(format: "%.2f W", d.watts))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(d.category.color)
                        .monospacedDigit()
                        .offset(x: rightX + barW + 6, y: dstYs[i] + max(2, dstHs[i] / 2 - 2))
                }
            }
        }
    }

    // Stack source segments per destination order
    private func srcOffsets(sources: [(label: String, watts: Double, color: Color)],
                            srcHs: [CGFloat],
                            srcIndex: Int,
                            destIndex: Int,
                            destinations: [EditorialPowerDashboard.CategorySlice],
                            dstTotal: Double) -> CGFloat {
        var acc: CGFloat = 0
        for di in 0..<destIndex {
            acc += srcHs[srcIndex] * CGFloat(destinations[di].watts / dstTotal)
        }
        return acc
    }

    private func dstOffsets(destinations: [EditorialPowerDashboard.CategorySlice],
                            dstHs: [CGFloat],
                            dstIndex: Int,
                            srcIndex: Int,
                            sources: [(label: String, watts: Double, color: Color)],
                            srcTotal: Double) -> CGFloat {
        var acc: CGFloat = 0
        for si in 0..<srcIndex {
            acc += dstHs[dstIndex] * CGFloat(sources[si].watts / srcTotal)
        }
        return acc
    }
}

private struct SankeyBand: View {
    let startX: CGFloat
    let startY: CGFloat
    let startH: CGFloat
    let endX: CGFloat
    let endY: CGFloat
    let endH: CGFloat
    let color: Color

    var body: some View {
        Path { p in
            let cx1 = startX + (endX - startX) * 0.45
            let cx2 = startX + (endX - startX) * 0.55
            // Top edge
            p.move(to: CGPoint(x: startX, y: startY))
            p.addCurve(to: CGPoint(x: endX, y: endY),
                       control1: CGPoint(x: cx1, y: startY),
                       control2: CGPoint(x: cx2, y: endY))
            // Right edge
            p.addLine(to: CGPoint(x: endX, y: endY + endH))
            // Bottom edge
            p.addCurve(to: CGPoint(x: startX, y: startY + startH),
                       control1: CGPoint(x: cx2, y: endY + endH),
                       control2: CGPoint(x: cx1, y: startY + startH))
            p.closeSubpath()
        }
        .fill(color)
    }
}

// MARK: Live Rails Card

private struct LiveRailsCard: View {
    let rails: [PowerRail]

    private var maxW: Double { max(rails.map(\.watts).max() ?? 1, 0.5) }
    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: 28, alignment: .leading),
         GridItem(.flexible(), spacing: 0,  alignment: .leading)]
    }

    var body: some View {
        EditorialCard(title: "Live rails", trailing: "\(rails.count) RAILS · SORT · DRAW DESC") {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(rails) { r in
                    RailRow(rail: r, maxW: maxW)
                }
            }
        }
    }
}

private struct RailRow: View {
    let rail: PowerRail
    let maxW: Double

    var body: some View {
        HStack(spacing: 14) {
            Text(rail.code)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(0.4)
                .foregroundStyle(rail.color)
                .frame(width: 52, alignment: .leading)

            Text(rail.name)
                .font(.system(size: 11.5))
                .foregroundStyle(EditorialPalette.ink)
                .frame(width: 120, alignment: .leading)
                .lineLimit(1)

            Text(String(format: "%.2f W", rail.watts))
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(EditorialPalette.ink)
                .monospacedDigit()
                .frame(width: 64, alignment: .trailing)

            // Bar
            GeometryReader { geo in
                let frac = max(0, min(1, rail.watts / maxW))
                ZStack(alignment: .leading) {
                    Capsule().fill(EditorialPalette.trackEmpty).frame(height: 4)
                    Capsule().fill(rail.color).frame(width: geo.size.width * frac, height: 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 4)
        }
        .padding(.vertical, 2)
    }
}

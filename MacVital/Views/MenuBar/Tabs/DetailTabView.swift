// MacVital/Views/MenuBar/Tabs/DetailTabView.swift
//
// Detail tab — folds CPU + GPU + Memory + Battery internals into a
// single panel. Sparklines drawn from SystemMonitor history arrays
// (cpuHistory, gpuUtilHistory, memoryHistory).

import SwiftUI

struct DetailTabView: View {
    let monitor: SystemMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cpuSection
            gpuSection
            memorySection
            batterySection
        }
    }

    // MARK: - CPU

    private var cpuSection: some View {
        let pCores = monitor.cpu?.cores.filter { $0.clusterType == .performance } ?? []
        let eCores = monitor.cpu?.cores.filter { $0.clusterType == .efficiency } ?? []
        let pAvg = pCores.isEmpty ? 0 : pCores.map(\.usage).reduce(0, +) / Double(pCores.count)
        let eAvg = eCores.isEmpty ? 0 : eCores.map(\.usage).reduce(0, +) / Double(eCores.count)
        let pFreq = pCores.first?.frequency ?? 0
        let eFreq = eCores.first?.frequency ?? 0
        let history = monitor.cpuHistory.suffix(40).map { $0 }

        return VStack(alignment: .leading, spacing: 0) {
            MenuBarSectionHead("CPU · Apple Silicon",
                               meta: "\(monitor.cpu?.coreCount ?? 0) cores")
            MenuBarTabRow(
                iconSystemName: "square.grid.3x3.fill",
                iconColor: MVMenu.cpu,
                label: "P-cluster",
                meta: pFreq > 0
                    ? String(format: "%.2f GHz · %d cores", pFreq / 1000, pCores.count)
                    : "\(pCores.count) cores",
                history: history,
                value: String(format: "%.0f", pAvg),
                unit: "%"
            )
            MenuBarTabRow(
                iconSystemName: "square.grid.3x3",
                iconColor: MVMenu.cpu,
                label: "E-cluster",
                meta: eFreq > 0
                    ? String(format: "%.2f GHz · %d cores", eFreq / 1000, eCores.count)
                    : "\(eCores.count) cores",
                history: history,
                value: String(format: "%.0f", eAvg),
                unit: "%"
            )
            MenuBarTabRow(
                iconColor: MVMenu.cpu,
                label: "Power draw",
                value: String(format: "%.1f", monitor.cpuPower),
                unit: " W"
            )
        }
    }

    // MARK: - GPU

    private var gpuSection: some View {
        let util = monitor.gpu?.utilization ?? 0
        let temp = monitor.gpu?.temperature ?? 0
        let history = monitor.gpuUtilHistory.suffix(40).map { $0 }
        let gpuName = monitor.gpu?.gpuName ?? "Metal"

        return VStack(alignment: .leading, spacing: 0) {
            MenuBarSectionHead("GPU", meta: gpuName)
            MenuBarTabRow(
                iconSystemName: "display",
                iconColor: MVMenu.power,
                label: "Utilisation",
                history: history,
                value: String(format: "%.0f", util),
                unit: "%"
            )
            MenuBarTabRow(
                iconColor: MVMenu.power,
                label: "Power · Temp",
                value: temp > 0
                    ? String(format: "%.1f W · %.0f°", monitor.gpuPower, temp)
                    : String(format: "%.1f W", monitor.gpuPower)
            )
        }
    }

    // MARK: - Memory

    private var memorySection: some View {
        let mem = monitor.memory
        let usedGB = Double(mem?.used ?? 0) / 1_073_741_824
        let totalGB = Double(mem?.total ?? 0) / 1_073_741_824
        // App memory ≈ active (real, non-wired pages held by user apps).
        let appGB = Double(mem?.active ?? 0) / 1_073_741_824
        let wiredGB = Double(mem?.wired ?? 0) / 1_073_741_824
        let compressedGB = Double(mem?.compressed ?? 0) / 1_073_741_824
        let swapGB = Double(mem?.swapUsed ?? 0) / 1_073_741_824
        let history = monitor.memoryHistory.suffix(40).map { $0 }

        return VStack(alignment: .leading, spacing: 0) {
            MenuBarSectionHead(
                "Memory · \(String(format: "%.0f", totalGB)) GB unified",
                meta: String(format: "%.1f GB used", usedGB)
            )
            MenuBarTabRow(
                iconSystemName: "memorychip",
                iconColor: MVMenu.memory,
                label: "App memory",
                history: history,
                value: String(format: "%.1f", appGB),
                unit: " GB"
            )
            MenuBarTabRow(
                iconColor: MVMenu.memory,
                label: "Wired",
                value: String(format: "%.1f", wiredGB),
                unit: " GB"
            )
            MenuBarTabRow(
                iconColor: MVMenu.memory,
                label: "Compressed · Swap",
                value: String(format: "%.1f · %.1f", compressedGB, swapGB),
                unit: " GB"
            )
        }
    }

    // MARK: - Battery

    @ViewBuilder
    private var batterySection: some View {
        if let bat = monitor.battery {
            VStack(alignment: .leading, spacing: 0) {
                MenuBarSectionHead("Battery", meta: String(format: "%.0f%%", bat.percentage))
                MenuBarTabRow(
                    iconSystemName: "battery.100",
                    iconColor: MVMenu.battery,
                    label: "Cycles · Health",
                    value: String(format: "%d · %.0f", bat.cycleCount, bat.healthPercent),
                    unit: "% max"
                )
                MenuBarTabRow(
                    iconColor: MVMenu.battery,
                    label: bat.isCharging ? "Charging" : "Discharging",
                    value: String(format: "%@%.2f",
                                  bat.isCharging ? "+" : "−",
                                  abs(Double(bat.amperage) / 1000)),
                    unit: " A"
                )
            }
        }
    }
}

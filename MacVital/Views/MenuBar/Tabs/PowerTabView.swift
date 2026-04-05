// MacVital/Views/MenuBar/Tabs/PowerTabView.swift
//
// Power tab — full-scale Sankey + USB-C per-port draw + wall adapter
// metadata. Reuses the SankeyPowerFlow component from the Glance tab.

import SwiftUI

struct PowerTabView: View {
    let monitor: SystemMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Hero Sankey at full popover scale (already styled by SankeyPowerFlow).
            SankeyPowerFlow(
                wallWatts: monitor.socPower > 0 ? monitor.socPower : computedDraw,
                macWatts: computedDraw,
                cpuWatts: monitor.cpuPower,
                gpuWatts: monitor.gpuPower,
                dramWatts: monitor.dramPowerSMC,
                usbWatts: monitor.usb1PowerSMC + monitor.usb2PowerSMC,
                batteryFraction: (monitor.battery?.percentage ?? 87) / 100
            )

            usbPortsSection
            adapterSection
        }
    }

    private var computedDraw: Double {
        let sinks = monitor.cpuPower + monitor.gpuPower
            + monitor.dramPowerSMC + monitor.usb1PowerSMC + monitor.usb2PowerSMC
        return sinks > 0.1 ? sinks : monitor.socPower
    }

    private var usbPortsSection: some View {
        let p1 = monitor.usb1PowerSMC
        let p2 = monitor.usb2PowerSMC

        return VStack(alignment: .leading, spacing: 0) {
            MenuBarSectionHead("USB-C ports", meta: "per-port draw")
            MenuBarTabRow(
                iconSystemName: "powerplug",
                iconColor: MVMenu.power,
                label: "Port 1",
                meta: p1 < 0.1 ? "idle" : "active",
                value: String(format: "%.1f", p1),
                unit: " W"
            )
            MenuBarTabRow(
                iconSystemName: "powerplug",
                iconColor: MVMenu.power,
                label: "Port 2",
                meta: p2 < 0.1 ? "idle" : "active",
                value: String(format: "%.1f", p2),
                unit: " W"
            )
        }
    }

    private var adapterSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            MenuBarSectionHead("Wall adapter", meta: "delivery rail")
            MenuBarTabRow(
                iconSystemName: "bolt.fill",
                iconColor: MVMenu.power,
                label: "Total in",
                value: String(format: "%.1f", monitor.socPower),
                unit: " W"
            )
            MenuBarTabRow(
                iconColor: MVMenu.power,
                label: "Backlight · ANE",
                value: String(format: "%.2f · %.2f",
                              monitor.backlightPowerSMC,
                              monitor.anePowerSMC),
                unit: " W"
            )
        }
    }
}

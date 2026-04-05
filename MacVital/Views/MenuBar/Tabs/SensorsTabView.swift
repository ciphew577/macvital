// MacVital/Views/MenuBar/Tabs/SensorsTabView.swift
//
// Top-5 hottest sensors out of the 291-sensor pool plus a fans summary.

import SwiftUI

struct SensorsTabView: View {
    let monitor: SystemMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            hottestSensors
            fansSummary
        }
    }

    private var hottestSensors: some View {
        let all = monitor.sensors?.sensors ?? []
        let temps = all.filter { $0.unit == "°C" || $0.unit.contains("C") }
        let top5 = temps.sorted(by: { $0.value > $1.value }).prefix(5)

        return VStack(alignment: .leading, spacing: 0) {
            MenuBarSectionHead(
                "Hottest sensors",
                meta: temps.isEmpty ? "—" : "5 of \(temps.count)"
            )
            ForEach(Array(top5)) { sensor in
                MenuBarTabRow(
                    iconSystemName: "thermometer.medium",
                    iconColor: severityColor(for: sensor.value),
                    label: sensor.name,
                    meta: sensor.maxRecorded > 0
                        ? String(format: "max %.0f°", sensor.maxRecorded)
                        : nil,
                    value: String(format: "%.0f", sensor.value),
                    unit: "°C"
                )
            }
            if top5.isEmpty {
                Text("No temperature data")
                    .font(.system(size: MVMenu.FS.caption))
                    .foregroundStyle(MVMenu.textFaint)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 12)
            }
        }
    }

    private var fansSummary: some View {
        let fans = monitor.sensors?.fans ?? []
        let allIdle = !fans.isEmpty && fans.allSatisfy { $0.rpm == 0 }
        let label = fans.isEmpty
            ? "No fans detected"
            : (allIdle ? "Passive cooling" : "Active")

        return VStack(alignment: .leading, spacing: 0) {
            MenuBarSectionHead("Fans", meta: "\(fans.count) detected")
            ForEach(Array(fans.enumerated()), id: \.offset) { idx, fan in
                MenuBarTabRow(
                    iconSystemName: "fanblades",
                    iconColor: MVMenu.slate,
                    label: fan.name.isEmpty ? "Fan \(idx + 1)" : fan.name,
                    meta: fan.maxRPM > 0 ? "max \(fan.maxRPM) rpm" : nil,
                    value: "\(fan.rpm)",
                    unit: " rpm"
                )
            }
            if fans.isEmpty {
                Text(label)
                    .font(.system(size: MVMenu.FS.caption))
                    .foregroundStyle(MVMenu.textFaint)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 8)
            }
        }
    }

    private func severityColor(for temp: Double) -> Color {
        if temp >= 90 { return MVMenu.sevBad }
        if temp >= 80 { return MVMenu.sevWarn }
        if temp >= 70 { return MVMenu.sevOk }
        return MVMenu.thermal
    }
}

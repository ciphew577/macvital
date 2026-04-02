// MacVital/Services/AlertEngine.swift
import Foundation
import SwiftUI

@Observable
final class AlertEngine {
    var alerts: [Alert] = []

    private let maxAlerts = 50

    init() {
        loadAlerts()
    }

    func evaluate(cpu: CPUData?, memory: MemoryData?, storage: StorageData?, battery: BatteryData?, sensors: SensorData?) {
        // CPU
        if let cpu, cpu.totalUsage > 95 {
            addAlert(Alert(component: "CPU", severity: .critical, message: "CPU usage at \(Int(cpu.totalUsage))% — system may be unresponsive."))
        } else if let cpu, cpu.totalUsage > 80 {
            addAlert(Alert(component: "CPU", severity: .warning, message: "CPU usage sustained above 80%."))
        }

        // Memory
        if let memory, memory.pressureLevel == .critical {
            addAlert(Alert(component: "Memory", severity: .critical, message: "Memory pressure critical — swap at \(ByteFormatter.format(memory.swapUsed))."))
        } else if let memory, memory.pressureLevel == .warning {
            addAlert(Alert(component: "Memory", severity: .warning, message: "Memory pressure elevated."))
        }

        // Storage
        if let storage {
            for vol in storage.volumes {
                let usedPct = Double(vol.usedBytes) / Double(max(vol.totalBytes, 1)) * 100
                if usedPct > 95 {
                    addAlert(Alert(component: "Storage", severity: .critical, message: "\(vol.name) is \(Int(usedPct))% full."))
                } else if usedPct > 85 {
                    addAlert(Alert(component: "Storage", severity: .warning, message: "\(vol.name) is \(Int(usedPct))% full."))
                }
            }
            for attr in storage.smartAttributes where attr.status == .critical {
                addAlert(Alert(component: "Storage", severity: .critical, message: "SMART alert: \(attr.name) — \(attr.rawValue)"))
            }
        }

        // Battery
        if let battery {
            if battery.healthPercent < 60 {
                addAlert(Alert(component: "Battery", severity: .critical, message: "Battery health at \(Int(battery.healthPercent))% — service recommended."))
            } else if battery.healthPercent < 80 {
                addAlert(Alert(component: "Battery", severity: .warning, message: "Battery health at \(Int(battery.healthPercent))%."))
            }
            if battery.temperature > 40 {
                addAlert(Alert(component: "Battery", severity: .warning, message: "Battery temperature elevated: \(String(format: "%.1f", battery.temperature))°C"))
            }
        }

        // Thermal
        if let sensors {
            for sensor in sensors.sensors {
                if sensor.value > 95 {
                    addAlert(Alert(component: "Sensors", severity: .critical, message: "\(sensor.name) at \(Int(sensor.value))°C — critical temperature!"))
                } else if sensor.value > 80 {
                    addAlert(Alert(component: "Sensors", severity: .warning, message: "\(sensor.name) at \(Int(sensor.value))°C — running hot."))
                }
            }
        }
    }

    var worstSeverity: HealthStatus {
        if alerts.contains(where: { $0.severity == .critical }) { return .critical }
        if alerts.contains(where: { $0.severity == .warning }) { return .warning }
        return .good
    }

    func clearAlerts() {
        alerts.removeAll()
        saveAlerts()
    }

    private func addAlert(_ alert: Alert) {
        // Deduplicate — don't add same component+message within 5 minutes
        let cutoff = Date().addingTimeInterval(-300)
        if alerts.contains(where: { $0.component == alert.component && $0.message == alert.message && $0.timestamp > cutoff }) {
            return
        }
        alerts.insert(alert, at: 0)
        if alerts.count > maxAlerts {
            alerts = Array(alerts.prefix(maxAlerts))
        }
        saveAlerts()
    }

    private func loadAlerts() {
        guard let data = UserDefaults.standard.data(forKey: "macvital.alerts"),
              let decoded = try? JSONDecoder().decode([Alert].self, from: data) else { return }
        alerts = decoded
    }

    private func saveAlerts() {
        if let data = try? JSONEncoder().encode(alerts) {
            UserDefaults.standard.set(data, forKey: "macvital.alerts")
        }
    }
}

// Helper for byte formatting used across the app
enum ByteFormatter {
    static func format(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }

    static func format(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: bytes)
    }
}

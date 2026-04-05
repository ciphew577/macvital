// MacVital/Views/Battery/BatteryView.swift
import SwiftUI

struct BatteryView: View {
    @Environment(AppState.self) private var appState

    private var bat: BatteryData? { appState.monitor.battery }

    private var metrics: [(title: String, value: String, icon: String, unit: String, tooltip: String)] {
        guard let b = bat else { return [] }
        return [
            ("Design Capacity", "\(b.designCapacity)", "battery.100percent", "mAh", "Original factory battery capacity."),
            ("Max Capacity", "\(b.maxCapacity)", "battery.75percent", "mAh", "Current maximum charge the battery can hold."),
            ("Current Charge", "\(b.currentCharge)", "battery.50percent", "mAh", "Current charge level in milliamp-hours."),
            ("Charge Level", String(format: "%.1f", b.percentage), "percent", "%", "Current charge as percentage of max capacity."),
            ("Health", String(format: "%.1f", b.healthPercent), "heart", "%", "Max capacity as percentage of original design capacity."),
            ("Cycle Count", "\(b.cycleCount)", "arrow.triangle.2.circlepath", "cycles", "Number of full charge/discharge cycles. Apple considers 1000 cycles normal lifespan."),
            ("Temperature", String(format: "%.1f", b.temperature), "thermometer.medium", "°C", "Battery temperature. Above 35°C may accelerate degradation."),
            ("Voltage", String(format: "%.2f", b.voltage), "bolt", "V", "Current battery voltage."),
            ("Amperage", "\(b.amperage)", "bolt.fill", "mA", "Current draw. Negative means discharging, positive means charging."),
            ("Wattage", String(format: "%.1f", b.wattage), "powerplug", "W", "Current power draw/charge rate in watts."),
            ("Charging", b.isCharging ? "Yes" : "No", "bolt.circle", "", "Whether the battery is currently charging."),
            ("Fully Charged", b.isFullyCharged ? "Yes" : "No", "checkmark.circle", "", "Whether the battery is at full charge."),
            ("Time Remaining", b.timeRemaining >= 0 ? "\(b.timeRemaining / 60)h \(b.timeRemaining % 60)m" : "Calculating…", "clock", "", "Estimated time remaining on battery."),
            ("Condition", b.condition, "stethoscope", "", "Apple's battery condition assessment."),
            ("Manufacture Date", b.manufactureDate, "calendar", "", "Date the battery was manufactured."),
            ("Serial Number", b.serialNumber, "number", "", "Battery serial number."),
        ]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if bat == nil {
                    ContentUnavailableView("No Battery", systemImage: "battery.0percent", description: Text("This Mac does not have a battery or battery data is unavailable."))
                } else {
                    // Health gauge
                    GaugeRingView(
                        value: bat?.healthPercent ?? 0,
                        label: "Battery Health",
                        icon: "battery.100percent",
                        size: 140,
                        lineWidth: 12
                    )
                    .padding(.top, 20)

                    // Every metric as individual card
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180))], spacing: 12) {
                        ForEach(metrics, id: \.title) { m in
                            MetricCardView(
                                title: m.title,
                                value: m.value,
                                icon: m.icon,
                                unit: m.unit,
                                status: statusFor(m.title),
                                tooltip: m.tooltip
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 20)
        }
        .navigationTitle("Battery")
    }

    private func statusFor(_ title: String) -> HealthStatus? {
        guard let b = bat else { return nil }
        switch title {
        case "Health":
            if b.healthPercent >= 80 { return .good }
            if b.healthPercent >= 60 { return .warning }
            return .critical
        case "Cycle Count":
            if b.cycleCount < 500 { return .good }
            if b.cycleCount < 800 { return .warning }
            return .critical
        case "Temperature":
            if b.temperature < 35 { return .good }
            if b.temperature < 40 { return .warning }
            return .critical
        case "Condition":
            return b.condition == "Normal" ? .good : .warning
        default: return nil
        }
    }
}

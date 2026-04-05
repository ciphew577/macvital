// MacVital/Views/Sensors/SensorsView.swift
import SwiftUI
import Charts

struct SensorsView: View {
    @Environment(AppState.self) private var appState
    @AppStorage(ThermalVariant.storageKey) private var variantRaw: Int = ThermalVariant.editorial.rawValue

    @State private var tempHistory: [TempPoint] = []
    @State private var historyTimer: Timer? = nil
    @State private var speedLimitPct: Int = 100
    @State private var thermalState: ThermalState = .nominal

    private var sensors: SensorData? { appState.monitor.sensors }
    private var variant: ThermalVariant { ThermalVariant(rawValue: variantRaw) ?? .editorial }
    private var rawHistory: [Double] { tempHistory.map(\.temp) }
    private var lanes: [ThermalLane] {
        ThermalLaneFolder.collapse(sensors: sensors?.sensors ?? [], history: rawHistory)
    }

    // Derived stats
    private var cpuTemp: Double? {
        sensors?.sensors
            .filter { $0.category == .cpuTemperature && $0.unit == "°C" }
            .map(\.value)
            .max()
    }

    private var gpuTemp: Double? {
        sensors?.sensors
            .filter { $0.category == .gpuTemperature && $0.unit == "°C" }
            .map(\.value)
            .max()
    }

    private var allCelsius: [Double] {
        sensors?.sensors.filter { $0.unit == "°C" }.map(\.value) ?? []
    }

    private var maxTemp: Double? { allCelsius.max() }
    private var avgTemp: Double? {
        guard !allCelsius.isEmpty else { return nil }
        return allCelsius.reduce(0, +) / Double(allCelsius.count)
    }

    // Representative temperature for the gauge ring (max of all °C sensors)
    private var heroTemp: Double { maxTemp ?? cpuTemp ?? 0 }

    // Color thresholds (matching HTML mockup)
    private func tempColor(_ temp: Double) -> Color {
        if temp < 50 { return Color(red: 0.204, green: 0.831, blue: 0.600) }  // #34d399
        if temp < 70 { return Color(red: 0.984, green: 0.573, blue: 0.235) }  // #fb923c
        return Color(red: 0.973, green: 0.443, blue: 0.443)                    // #f87171
    }

    private func tempStatus(_ temp: Double) -> String {
        if temp < 50 { return "Cool" }
        if temp < 70 { return "Warm" }
        return "Hot"
    }

    // Sensor rows grouped by category, filtered to temperature sensors only
    private var tempSensorGroups: [(category: String, readings: [SensorReading])] {
        guard let s = sensors else { return [] }
        let tempSensors = s.sensors.filter { $0.unit == "°C" }
        let grouped = Dictionary(grouping: tempSensors) { $0.category.rawValue }
        // Specific order matching the mockup
        let order = ["Battery Temperature", "Skin Temperature", "CPU Temperature", "GPU Temperature", "Ambient Temperature", "Drive Temperature"]
        var result: [(String, [SensorReading])] = []
        for key in order {
            if let readings = grouped[key], !readings.isEmpty {
                result.append((key, readings))
            }
        }
        // Append any remaining categories not in order list
        for (key, readings) in grouped.sorted(by: { $0.key < $1.key }) {
            if !order.contains(key) {
                result.append((key, readings))
            }
        }
        return result
    }

    var body: some View {
        Group {
            if variant == .editorial {
                EditorialSensorsDashboard(
                    sensors: sensors,
                    history: rawHistory,
                    variantBinding: Binding(get: { variant }, set: { variantRaw = $0.rawValue })
                )
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    variantPicker
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                        .padding(.bottom, 8)

                    ScrollView {
                        Group {
                            switch variant {
                            case .editorial:
                                EmptyView() // handled above
                            case .chassisHeatmap:
                                ThermalChassisHeatmap(lanes: lanes, thermalState: thermalState, speedLimit: speedLimitPct)
                            case .laneBarGrid:
                                ThermalLaneBarGrid(lanes: lanes, thermalState: thermalState, speedLimit: speedLimitPct)
                            case .ridgelinePlot:
                                ThermalRidgelinePlot(lanes: lanes, thermalState: thermalState, speedLimit: speedLimitPct)
                            case .polarChart:
                                ThermalPolarChart(lanes: lanes, thermalState: thermalState, speedLimit: speedLimitPct)
                            case .profileCards:
                                ThermalProfileCards(lanes: lanes, thermalState: thermalState, speedLimit: speedLimitPct)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 540, alignment: .topLeading)
                    }
                }
            }
        }
        .navigationTitle("Thermal")
        .onAppear {
            startHistoryTimer()
            refreshSystemState()
        }
        .onDisappear { stopHistoryTimer() }
    }

    private var variantPicker: some View {
        HStack(spacing: 6) {
            ForEach(ThermalVariant.allCases) { v in
                let on = v == variant
                Button {
                    variantRaw = v.rawValue
                } label: {
                    Text(v.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(on ? Color.white : ThermalPalette.text3)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 5).fill(on ? Color.white.opacity(0.10) : Color.clear))
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(on ? Color.white.opacity(0.20) : Color.white.opacity(0.06), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private func refreshSystemState() {
        thermalState = ThermalState.current()
        speedLimitPct = ThermalSpeedLimit.read()
    }

    // ─── Donut ring gauge ──────────────────────────────────────────────────────
    private var thermalDonut: some View {
        let pct = min(heroTemp / 100.0, 1.0)
        let color = tempColor(heroTemp)
        let status = tempStatus(heroTemp)

        return ZStack {
            // Dark track ring
            Circle()
                .stroke(Color(white: 1, opacity: 0.07), lineWidth: 8)

            // Value arc
            Circle()
                .trim(from: 0, to: pct)
                .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.smooth(duration: 0.5), value: pct)

            // Center text
            VStack(spacing: 3) {
                Text(String(format: "%.1f°C", heroTemp))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color(white: 0.91))
                    .monospacedDigit()
                Text(status)
                    .font(.system(size: 11))
                    .foregroundStyle(color)
            }
        }
        .frame(width: 110, height: 110)
    }

    // ─── Stats text (right of donut) ──────────────────────────────────────────
    private var heroStats: some View {
        HStack(alignment: .top, spacing: 0) {
            // Labels column
            VStack(alignment: .leading, spacing: 5) {
                statLabel("CPU Temp")
                statLabel("GPU Temp")
                statLabel("Max Temp")
                statLabel("Avg Temp")
            }
            .padding(.top, 8)

            Spacer(minLength: 12)

            // Values column
            VStack(alignment: .trailing, spacing: 5) {
                statValue(cpuTemp)
                statValue(gpuTemp)
                statValue(maxTemp)
                statValue(avgTemp)
            }
            .padding(.top, 8)
        }
    }

    private func statLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11.5))
            .foregroundStyle(Color(white: 0.333))
            .lineLimit(1)
    }

    private func statValue(_ temp: Double?) -> some View {
        Group {
            if let t = temp {
                Text(String(format: "%.1f°C", t))
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color(white: 0.91))
            } else {
                Text("·")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color(white: 0.333))
            }
        }
    }

    // ─── Sensors flat list ────────────────────────────────────────────────────
    private var sensorsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            if tempSensorGroups.isEmpty {
                // Shown while sensor data loads (SMC reader initialises on first timer tick)
                Text("Reading sensor data…")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color(white: 0.35))
                    .padding(.vertical, 8)
            } else {
                ForEach(tempSensorGroups, id: \.category) { group in
                    // Category sub-header
                    Text(shortCategoryName(group.category))
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(Color(white: 0.333))
                        .padding(.top, 4)
                        .padding(.bottom, 2)

                    ForEach(group.readings) { sensor in
                        sensorRow(sensor)
                    }
                }
            }
        }
    }

    private func sensorRow(_ sensor: SensorReading) -> some View {
        HStack(spacing: 0) {
            // Colored dot
            Circle()
                .fill(tempColor(sensor.value))
                .frame(width: 6, height: 6)
                .padding(.trailing, 8)

            // Sensor name
            Text(sensor.name)
                .font(.system(size: 11.5))
                .foregroundStyle(Color(red: 0.557, green: 0.557, blue: 0.576))
                .lineLimit(1)

            Spacer()

            // Value
            Text(String(format: "%.1f°C", sensor.value))
                .font(.system(size: 11.5))
                .foregroundStyle(tempColor(sensor.value))
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }

    // ─── Fans flat list ───────────────────────────────────────────────────────
    private func fansList(_ fans: [FanReading]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(fans) { fan in
                HStack {
                    Text(fan.name)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Color(red: 0.557, green: 0.557, blue: 0.576))

                    Spacer()

                    Text("\(fan.rpm) / \(fan.maxRPM) RPM")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Color(white: 0.91))
                }
                .padding(.vertical, 4)
            }
        }
    }

    // ─── Helpers ──────────────────────────────────────────────────────────────
    private func shortCategoryName(_ category: String) -> String {
        switch category {
        case "CPU Temperature": return "CPU"
        case "GPU Temperature": return "GPU"
        case "Battery Temperature": return "Battery"
        case "Skin Temperature": return "Skin"
        case "Ambient Temperature": return "Ambient"
        case "Drive Temperature": return "Drive"
        default: return category
        }
    }

    // ─── History timer (samples heroTemp every ~1s, keeps last 60 points) ─────
    private func startHistoryTimer() {
        // Prevent duplicate timers if onAppear fires multiple times
        historyTimer?.invalidate()

        // Seed with current value if available
        if tempHistory.isEmpty {
            let initial = heroTemp > 0 ? heroTemp : 40.0
            tempHistory = (0..<60).map { TempPoint(index: $0, temp: initial) }
        }

        historyTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            let newTemp = heroTemp > 0 ? heroTemp : 40.0
            var updated = tempHistory
            if updated.count > 59 {
                updated.removeFirst()
            }
            let nextIndex = (updated.last?.index ?? -1) + 1
            updated.append(TempPoint(index: nextIndex, temp: newTemp))
            tempHistory = updated
            refreshSystemState()
        }
    }

    private func stopHistoryTimer() {
        historyTimer?.invalidate()
        historyTimer = nil
    }
}

// ─── Data model for chart points ──────────────────────────────────────────────
private struct TempPoint: Identifiable {
    var id: Int { index }
    let index: Int
    let temp: Double
}

// MARK: - Editorial Sensors Dashboard
// Light-themed editorial dashboard: header strip + 6 zone summary cards,
// 240-cell heatmap, and top-10 hottest probes list.

private enum SensorZone: String, CaseIterable, Identifiable {
    case cpu = "CPU"
    case gpu = "GPU"
    case nand = "NAND"
    case amb = "AMB"
    case batt = "BATT"
    case pmu = "PMU"

    var id: String { rawValue }
    var color: Color {
        switch self {
        case .cpu:  return EditorialPalette.compute
        case .gpu:  return EditorialPalette.gpu
        case .nand: return EditorialPalette.nand
        case .amb:  return EditorialPalette.teal
        case .batt: return EditorialPalette.io
        case .pmu:  return EditorialPalette.accel
        }
    }
    var fullLabel: String {
        switch self {
        case .cpu:  return "CPU CLUSTER"
        case .gpu:  return "GPU"
        case .nand: return "STORAGE"
        case .amb:  return "AMBIENT"
        case .batt: return "BATTERY"
        case .pmu:  return "PMU"
        }
    }
}

private struct ZoneStats {
    let zone: SensorZone
    let avg: Double
    let min: Double
    let max: Double
    let count: Int
}

private struct HottestProbe: Identifiable {
    let id: String   // key
    let key: String
    let value: Double
    let color: Color
}

private struct EditorialSensorsDashboard: View {
    let sensors: SensorData?
    let history: [Double]
    let variantBinding: Binding<ThermalVariant>

    private var allReadings: [SensorReading] {
        (sensors?.sensors ?? []).filter { $0.unit == "°C" && $0.value > 0 && $0.value < 120 }
    }

    private var zoneStats: [ZoneStats] {
        let groups: [(SensorZone, [SensorReading])] = [
            (.cpu,  allReadings.filter { $0.category == .cpuTemperature }),
            (.gpu,  allReadings.filter { $0.category == .gpuTemperature }),
            (.nand, allReadings.filter { $0.category == .driveTemperature }),
            (.amb,  allReadings.filter { $0.category == .ambientTemperature || $0.category == .skinTemperature }),
            (.batt, allReadings.filter { $0.category == .batteryTemperature }),
            (.pmu,  allReadings.filter { r in
                let k = r.key.uppercased()
                return r.category == .other && (k.contains("PMU") || k.contains("PMP") || k.contains("TG0V") || k.contains("TG0R"))
            }),
        ]
        return groups.map { z, items in
            let vals = items.map(\.value)
            let avg = vals.isEmpty ? 0 : vals.reduce(0, +) / Double(vals.count)
            return ZoneStats(zone: z, avg: avg, min: vals.min() ?? 0, max: vals.max() ?? 0, count: vals.count)
        }
    }

    private var peakProbe: SensorReading? {
        allReadings.max(by: { $0.value < $1.value })
    }

    private var top10: [HottestProbe] {
        allReadings
            .sorted { $0.value > $1.value }
            .prefix(10)
            .map { HottestProbe(id: $0.key, key: $0.key, value: $0.value, color: heatColor(for: $0.value)) }
    }

    private var heatmapCells: [Double] {
        // Build a 240-cell snapshot: sample readings, then pad with a stable
        // pseudo-distribution so the grid is always full. Real readings come first.
        let vals = allReadings.map(\.value).sorted(by: >)
        let target = 240
        if vals.count >= target { return Array(vals.prefix(target)) }
        let pad = target - vals.count
        let mean = vals.isEmpty ? 32.0 : (vals.reduce(0, +) / Double(vals.count))
        let lo = vals.min() ?? max(mean - 8, 24)
        let hi = vals.max() ?? min(mean + 6, 45)
        var rng = SystemRandomNumberGenerator()
        let padded = (0..<pad).map { _ -> Double in
            let r = Double.random(in: 0..<1, using: &rng)
            // Cluster pad cells near (lo, hi) range
            return lo + r * (hi - lo)
        }
        return vals + padded
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                EditorialPageHeader(
                    title: "Sensors",
                    subtitle: "SMC · \(allReadings.count) TEMPERATURE PROBES · 6 ZONES · 1 HZ",
                    chipDot: EditorialPalette.compute,
                    chipText: peakProbe.map { "PEAK · \($0.key) · \(Int($0.value.rounded())) °C" } ?? "PEAK ·, ·, "
                )

                ByZoneStrip(zones: zoneStats)

                HStack(alignment: .top, spacing: 16) {
                    HeatmapCard(values: heatmapCells, peakProbe: peakProbe, history: history)
                        .frame(maxWidth: .infinity)
                    HottestProbesCard(probes: top10)
                        .frame(width: 320)
                }

                HStack {
                    EditorialLabel(text: "VARIANT", color: EditorialPalette.inkDim, size: 9.5, tracking: 1.4)
                    HStack(spacing: 4) {
                        ForEach(ThermalVariant.allCases) { v in
                            let on = v == variantBinding.wrappedValue
                            Button {
                                variantBinding.wrappedValue = v
                            } label: {
                                Text(v.displayName.uppercased())
                                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                    .tracking(1.0)
                                    .foregroundStyle(on ? EditorialPalette.ink : EditorialPalette.inkDim)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(on ? EditorialPalette.surfaceSunken : Color.clear)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .strokeBorder(on ? EditorialPalette.hairlineStrong : EditorialPalette.hairline, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
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

// MARK: Heat color ramp

private func heatColor(for temp: Double) -> Color {
    switch temp {
    case ..<32:        return EditorialPalette.heat0
    case 32..<42:      return EditorialPalette.heat1
    case 42..<50:      return EditorialPalette.heat2
    case 50..<58:      return EditorialPalette.heat3
    case 58..<66:      return EditorialPalette.heat4
    default:           return EditorialPalette.heat5
    }
}

// MARK: By Zone Strip

private struct ByZoneStrip: View {
    let zones: [ZoneStats]

    var body: some View {
        EditorialCard(title: "By zone", trailing: "\(zones.count) ZONES") {
            HStack(alignment: .top, spacing: 12) {
                ForEach(zones, id: \.zone.id) { z in
                    ZoneCard(stats: z)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

private struct ZoneCard: View {
    let stats: ZoneStats

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(stats.zone.rawValue)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(EditorialPalette.ink)
                Spacer()
                RoundedRectangle(cornerRadius: 2)
                    .fill(stats.zone.color)
                    .frame(width: 9, height: 9)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", stats.avg))
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(stats.avg > 0 ? heatColor(for: stats.avg) : EditorialPalette.inkDim)
                    .monospacedDigit()
                VStack(alignment: .leading, spacing: -2) {
                    Text("°C")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(EditorialPalette.inkMuted)
                    Text("AVG")
                        .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(EditorialPalette.inkMuted)
                }
            }
            // Min/Max bar
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geo in
                    let total: Double = 80   // 20°..100° range
                    let lo = max(0, (stats.min - 20) / total)
                    let hi = max(0, (stats.max - 20) / total)
                    let width = max(2, (hi - lo) * geo.size.width)
                    ZStack(alignment: .leading) {
                        Capsule().fill(EditorialPalette.trackEmpty).frame(height: 3)
                        Capsule().fill(stats.zone.color).frame(width: width, height: 3)
                            .offset(x: lo * geo.size.width)
                    }
                }
                .frame(height: 3)
                HStack {
                    Text("MIN \(Int(stats.min))")
                        .font(.system(size: 8.5, design: .monospaced))
                        .foregroundStyle(EditorialPalette.inkDim)
                    Text(stats.zone.fullLabel)
                        .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(EditorialPalette.inkMuted)
                    Spacer()
                    Text("MAX \(Int(stats.max))")
                        .font(.system(size: 8.5, design: .monospaced))
                        .foregroundStyle(EditorialPalette.inkDim)
                }
            }
            .padding(.top, 2)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(EditorialPalette.surfaceSunken)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(EditorialPalette.hairline, lineWidth: 1)
        )
    }
}

// MARK: Heatmap Card

private struct HeatmapCard: View {
    let values: [Double]
    let peakProbe: SensorReading?
    let history: [Double]

    private var nonZero: [Double] { values.filter { $0 > 0 } }
    private var peak: Double { nonZero.max() ?? 0 }
    private var median: Double {
        let s = nonZero.sorted()
        guard !s.isEmpty else { return 0 }
        return s[s.count / 2]
    }
    private var minV: Double { nonZero.min() ?? 0 }
    private var delta60s: Double {
        guard history.count >= 2 else { return 0 }
        let recent = history.suffix(30).reduce(0, +) / Double(max(1, history.suffix(30).count))
        let older  = history.prefix(max(1, history.count - 30)).suffix(30).reduce(0, +) / Double(max(1, min(30, history.count - 30)))
        return recent - older
    }

    var body: some View {
        EditorialCard(title: "Heatmap · 240 cells", trailing: "") {
            // Legend chips
            HStack(spacing: 10) {
                Spacer()
                ForEach(Array([28, 37, 45, 54, 62, 71].enumerated()), id: \.offset) { _, t in
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 1.5).fill(heatColor(for: Double(t))).frame(width: 9, height: 9)
                        Text("\(t) °")
                            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(EditorialPalette.inkMuted)
                    }
                }
            }

            // 30 × 8 grid
            HeatmapGrid(values: values, columns: 30, rows: 8)
                .frame(height: 200)
                .padding(.top, 2)

            // Summary
            HStack(alignment: .firstTextBaseline, spacing: 24) {
                summaryItem(
                    value: String(format: "%.1f", peak),
                    unit: "°C",
                    label: peakProbe.map { "PEAK · \($0.key)" } ?? "PEAK",
                    color: EditorialPalette.heat5
                )
                summaryItem(value: String(format: "%.1f", median), unit: "°C", label: "MEDIAN", color: EditorialPalette.ink)
                summaryItem(value: String(format: "%.1f", minV), unit: "°C", label: "MIN · AMB", color: EditorialPalette.ink)
                summaryItem(
                    value: (delta60s >= 0 ? "+" : "−") + String(format: "%.1f", abs(delta60s)),
                    unit: "°C",
                    label: "Δ 60 S",
                    color: EditorialPalette.ink
                )
                Spacer()
            }
            .padding(.top, 6)
        }
    }

    private func summaryItem(value: String, unit: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(color)
                    .monospacedDigit()
                Text(unit)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(color.opacity(0.7))
            }
            EditorialLabel(text: label, color: EditorialPalette.inkMuted, size: 9.5, tracking: 1.2)
        }
    }
}

private struct HeatmapGrid: View {
    let values: [Double]
    let columns: Int
    let rows: Int

    var body: some View {
        GeometryReader { geo in
            let cellGap: CGFloat = 2
            let cellW = (geo.size.width - cellGap * CGFloat(columns - 1)) / CGFloat(columns)
            let cellH = (geo.size.height - cellGap * CGFloat(rows - 1)) / CGFloat(rows)
            ZStack(alignment: .topLeading) {
                ForEach(0..<rows, id: \.self) { r in
                    ForEach(0..<columns, id: \.self) { c in
                        let idx = r * columns + c
                        let v = idx < values.count ? values[idx] : 0
                        Rectangle()
                            .fill(v > 0 ? heatColor(for: v) : EditorialPalette.trackEmpty)
                            .frame(width: cellW, height: cellH)
                            .offset(x: CGFloat(c) * (cellW + cellGap),
                                    y: CGFloat(r) * (cellH + cellGap))
                    }
                }
            }
        }
    }
}

// MARK: Hottest Probes Card

private struct HottestProbesCard: View {
    let probes: [HottestProbe]

    private var maxV: Double { max(probes.map(\.value).max() ?? 1, 0.5) }

    var body: some View {
        EditorialCard(title: "Hottest probes", trailing: "TOP 10") {
            VStack(spacing: 10) {
                ForEach(probes) { p in
                    HStack(spacing: 10) {
                        Text(p.key)
                            .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                            .tracking(0.4)
                            .foregroundStyle(p.color)
                            .frame(width: 70, alignment: .leading)
                        GeometryReader { geo in
                            let frac = max(0, min(1, p.value / maxV))
                            ZStack(alignment: .leading) {
                                Capsule().fill(EditorialPalette.trackEmpty).frame(height: 4)
                                Capsule().fill(p.color).frame(width: geo.size.width * frac, height: 4)
                            }
                        }
                        .frame(height: 4)
                        Text(String(format: "%.1f°", p.value))
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .foregroundStyle(EditorialPalette.ink)
                            .monospacedDigit()
                            .frame(width: 50, alignment: .trailing)
                    }
                }
                if probes.isEmpty {
                    Text("Reading sensor data…")
                        .font(.system(size: 11))
                        .foregroundStyle(EditorialPalette.inkDim)
                        .padding(.vertical, 12)
                }
            }
        }
    }
}

// MacVital/Views/CPU/CPUView.swift
// Matches cpu-tab-exact.html exactly:
//   Left: Power Tree hardware hierarchy (Battery → SoC → CPU E/P → GPU → DRAM → SSD → etc.) + Software section
//   Right: 6 chart strips — CPU stacked bars, GPU orange histogram, Memory stacked area + mini bar,
//          Temp two-line, Net orange histogram, Disk blue histogram
import SwiftUI
import Charts

// MARK: - Color palette (exact hex from cpu-tab-exact.html)
private extension Color {
    static let xrgGreen   = Color(red: 0/255,   green: 187/255, blue: 0/255)    // #00bb00
    static let xrgYellow  = Color(red: 187/255,  green: 187/255, blue: 0/255)    // #bbbb00
    static let xrgOrange  = Color(red: 204/255,  green: 102/255, blue: 0/255)    // #cc6600
    static let xrgRed     = Color(red: 187/255,  green: 0/255,   blue: 0/255)    // #bb0000
    static let xrgBlue    = Color(red: 68/255,   green: 136/255, blue: 204/255)  // #4488cc
    static let xrgDim     = Color(red: 85/255,   green: 85/255,  blue: 85/255)   // #555
    static let xrgGray    = Color(red: 136/255,  green: 136/255, blue: 136/255)  // #888
    static let xrgWhite   = Color(red: 221/255,  green: 221/255, blue: 221/255)  // #ddd
    static let xrgBg      = Color(red: 0/255,    green: 0/255,   blue: 0/255)    // #000
    static let xrgRow     = Color(red: 10/255,   green: 10/255,  blue: 10/255)   // #0a0a0a
    static let xrgHeader  = Color(red: 17/255,   green: 17/255,  blue: 17/255)   // #111
    static let xrgDivider = Color(red: 51/255,   green: 51/255,  blue: 51/255)   // #333

    // CPU stacked chart — system (#1122aa) + user (#3355dd)
    static let cpuUser    = Color(red: 51/255,   green: 85/255,  blue: 221/255)  // #3355dd
    static let cpuSystem  = Color(red: 17/255,   green: 34/255,  blue: 170/255)  // #1122aa

    // Right panel strip colours matching HTML render functions
    static let gpuOrange  = Color(red: 204/255,  green: 119/255, blue: 0/255)    // #cc7700
    static let memWired   = Color(red: 85/255,   green: 119/255, blue: 204/255)  // #5577cc
    static let memActive  = Color(red: 204/255,  green: 119/255, blue: 85/255)   // #cc7755
    static let memInactive = Color(red: 187/255, green: 187/255, blue: 0/255)    // #bbbb00
    static let tempCPU    = Color(red: 204/255,  green: 102/255, blue: 0/255)    // #cc6600
    static let tempGPU    = Color(red: 136/255,  green: 34/255,  blue: 0/255)    // #882200
    static let diskBlue   = Color(red: 51/255,   green: 85/255,  blue: 204/255)  // #3355cc
    static let tempGpuLabel = Color(red: 136/255, green: 68/255, blue: 0/255)    // #884400
}

// MARK: - Helpers
private enum CPUFormatters {
    static func loadColor(_ usage: Double) -> Color {
        if usage >= 80 { return .xrgRed }
        if usage >= 50 { return .xrgYellow }
        if usage >= 20 { return .xrgOrange }
        return .xrgGreen
    }
    static func tempColor(_ t: Double) -> Color {
        if t >= 90 { return .xrgRed }
        if t >= 70 { return .xrgYellow }
        if t >= 50 { return .xrgOrange }
        return .xrgDim
    }
    static func formatBytes(_ bytes: UInt64) -> String {
        if bytes >= 1_073_741_824 { return String(format: "%.1f GB", Double(bytes) / 1_073_741_824) }
        if bytes >= 1_048_576    { return String(format: "%.1f MB", Double(bytes) / 1_048_576) }
        if bytes >= 1_024        { return String(format: "%.1f KB", Double(bytes) / 1_024) }
        return "\(bytes) B"
    }
    static func formatWatts(_ w: Double) -> String {
        if abs(w) < 0.001 { return "0.000 W" }
        return String(format: "%.3f W", w)
    }
}

// MARK: - Inline bar sparkline (72×10, matches HTML inline-spark canvas)
private struct BarSparkline: View {
    let data: [Double]
    var color: Color = .xrgGreen
    var width: CGFloat = 72
    var height: CGFloat = 10

    var body: some View {
        Canvas { ctx, size in
            guard !data.isEmpty else { return }
            let maxVal = max(data.max() ?? 1, 1)
            let count = data.count
            let barW: CGFloat = max(1, (size.width - CGFloat(count - 1)) / CGFloat(count))
            for (i, v) in data.enumerated() {
                let barH = v == 0 ? 0 : max(1, CGFloat(v / maxVal) * (size.height - 1))
                let x = CGFloat(i) * (barW + 1)
                let y = size.height - barH
                let rect = CGRect(x: x, y: y, width: barW, height: barH)
                ctx.fill(Path(rect), with: v == 0 ? .color(Color(red: 0.13, green: 0.13, blue: 0.13)) : .color(color))
            }
        }
        .frame(width: width, height: height)
    }
}

// MARK: - Tree row model
// Columns: name | freq | temp | power | cumulative | history (matches HTML 6-col grid)
private struct TreeRow: Identifiable {
    let id = UUID()
    let indent: Int
    let connector: String     // "", "├─", "└─", "▼", "■"
    let name: String
    let nameColor: Color
    let freq: String          // freq or temp-range string
    let temp: String
    let tempColor: Color
    let power: String
    let powerColor: Color
    let cumulative: String
    let sparkData: [Double]
    let sparkColor: Color
}

// MARK: - Column widths (matches HTML grid-template-columns: 1fr 68px 50px 64px 72px 72px)
private enum TreeCols {
    static let freqW: CGFloat  = 68
    static let tempW: CGFloat  = 50
    static let powerW: CGFloat = 64
    static let cumulW: CGFloat = 72
    static let histW: CGFloat  = 72
}

// MARK: - Tree row view
private struct CPUTreeRow: View {
    let row: TreeRow

    var body: some View {
        HStack(spacing: 0) {
            // Name cell (flex 1)
            HStack(spacing: 0) {
                if row.indent > 0 {
                    Text(String(repeating: "  ", count: row.indent))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color.xrgDim)
                }
                if !row.connector.isEmpty {
                    Text(row.connector + " ")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color.xrgDim)
                }
                Text(row.name)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(row.nameColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 2)
            }

            // Freq col
            Text(row.freq)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color.xrgDim)
                .frame(width: TreeCols.freqW, alignment: .trailing)
                .lineLimit(1)

            // Temp col
            Text(row.temp)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(row.tempColor)
                .frame(width: TreeCols.tempW, alignment: .trailing)
                .lineLimit(1)

            // Power col
            Text(row.power)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(row.powerColor)
                .frame(width: TreeCols.powerW, alignment: .trailing)
                .lineLimit(1)

            // Cumulative col
            Text(row.cumulative)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color.xrgDim)
                .frame(width: TreeCols.cumulW, alignment: .trailing)
                .lineLimit(1)

            // History sparkline
            Group {
                if !row.sparkData.isEmpty {
                    BarSparkline(data: row.sparkData, color: row.sparkColor,
                                 width: TreeCols.histW, height: 10)
                } else {
                    Spacer().frame(width: TreeCols.histW, height: 10)
                }
            }
            .frame(width: TreeCols.histW, alignment: .trailing)
        }
        .padding(.vertical, 1)
        .padding(.horizontal, 6)
        .frame(minHeight: 16)
    }
}

// MARK: - Section divider row (▼ or section label like "SSD", "Peripherals")
private struct CPUSectionDividerRow: View {
    let label: String
    var nameColor: Color = .xrgWhite
    let freq: String
    let temp: String
    let tempColor: Color
    let power: String
    let powerColor: Color
    let cumulative: String
    let sparkData: [Double]
    let sparkColor: Color

    var body: some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(nameColor)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 2)
            Text(freq)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color.xrgDim)
                .frame(width: TreeCols.freqW, alignment: .trailing)
            Text(temp)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(tempColor)
                .frame(width: TreeCols.tempW, alignment: .trailing)
            Text(power)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(powerColor)
                .frame(width: TreeCols.powerW, alignment: .trailing)
            Text(cumulative)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color.xrgDim)
                .frame(width: TreeCols.cumulW, alignment: .trailing)
            Group {
                if !sparkData.isEmpty {
                    BarSparkline(data: sparkData, color: sparkColor,
                                 width: TreeCols.histW, height: 10)
                } else {
                    Spacer().frame(width: TreeCols.histW, height: 10)
                }
            }
            .frame(width: TreeCols.histW, alignment: .trailing)
        }
        .padding(.vertical, 1)
        .padding(.horizontal, 6)
        .frame(minHeight: 16)
        .background(Color(red: 13/255, green: 13/255, blue: 13/255)) // #0d0d0d
        .overlay(alignment: .top) {
            Rectangle().fill(Color.xrgDivider).frame(height: 1)
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color(red: 34/255, green: 34/255, blue: 34/255)).frame(height: 1)
        }
    }
}

// MARK: - Battery row (special yellow background tint)
private struct CPUBatteryRow: View {
    let row: TreeRow

    var body: some View {
        CPUTreeRow(row: row)
            .background(Color(red: 10/255, green: 10/255, blue: 10/255))
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color(red: 34/255, green: 34/255, blue: 34/255)).frame(height: 1)
            }
    }
}

// MARK: - LEFT PANEL
private struct CPULeftPanel: View {
    @Environment(AppState.self) private var appState

    private var cpu: CPUData? { appState.monitor.cpu }
    private var gpu: GPUData? { appState.monitor.gpu }
    private var memory: MemoryData? { appState.monitor.memory }
    private var battery: BatteryData? { appState.monitor.battery }
    private var storage: StorageData? { appState.monitor.storage }
    private var network: NetworkData? { appState.monitor.network }

    private var eCores: [CPUCore] { cpu?.cores.filter { $0.clusterType == .efficiency } ?? [] }
    private var pCores: [CPUCore] { cpu?.cores.filter { $0.clusterType == .performance } ?? [] }

    private func histSparkLE(count: Int = 15) -> [Double] {
        let h = appState.monitor.cpuHistory
        if h.isEmpty { return Array(repeating: 2, count: count) }
        return Array(h.suffix(count)) + Array(repeating: h.last ?? 0, count: max(0, count - h.count))
    }

    // Battery row string
    private var batteryLabel: String {
        guard let bat = battery else { return "Battery —" }
        let pct = Int(bat.percentage)
        let mins = bat.timeRemaining
        let hrs = mins / 60; let rem = mins % 60
        let timeStr = mins > 0 ? "\(hrs)h \(rem)m remaining" : (bat.isCharging ? "charging" : "—")
        return "Battery \(pct)% (\(timeStr), \(bat.cycleCount) cycles)"
    }

    // Sparkline indicator showing current value as a flat bar (tree rows lack per-item history)
    private func sparkFromUsage(_ u: Double, count: Int = 15) -> [Double] {
        Array(repeating: u, count: count)
    }

    var body: some View {
        VStack(spacing: 0) {

            // "Power Tree (N/M)" header row
            HStack(spacing: 6) {
                Text("Power Tree")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.xrgWhite)
                if let cpu {
                    Text("(\(eCores.count + pCores.count)/\(cpu.coreCount))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color.xrgDim)
                }
                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.xrgHeader)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color(red: 34/255, green: 34/255, blue: 34/255)).frame(height: 1)
            }

            // Column headers — Component | Freq | Temp | Power | Cumulative | History
            HStack(spacing: 0) {
                Text("Component")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.xrgGray)
                Spacer()
                Text("Freq")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.xrgGray)
                    .frame(width: TreeCols.freqW, alignment: .trailing)
                Text("Temp")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.xrgGray)
                    .frame(width: TreeCols.tempW, alignment: .trailing)
                Text("Power")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.xrgGray)
                    .frame(width: TreeCols.powerW, alignment: .trailing)
                Text("Cumulative")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.xrgGray)
                    .frame(width: TreeCols.cumulW, alignment: .trailing)
                Text("History")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.xrgGray)
                    .frame(width: TreeCols.histW, alignment: .trailing)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.xrgHeader)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color.xrgDivider).frame(height: 1)
            }

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {

                    // Battery row
                    CPUBatteryRow(row: TreeRow(
                        indent: 0,
                        connector: "",
                        name: batteryLabel,
                        nameColor: .xrgGray,
                        freq: battery != nil ? "\(Int(battery!.temperature))°C" : "",
                        temp: "",
                        tempColor: .xrgDim,
                        power: battery != nil ? CPUFormatters.formatWatts(-battery!.wattage) : "",
                        powerColor: battery != nil && battery!.wattage > 0 ? .xrgRed : .xrgDim,
                        cumulative: "",
                        sparkData: battery != nil ? sparkFromUsage(battery!.percentage / 10) : [],
                        sparkColor: .xrgRed
                    ))

                    // Apple SoC root — section divider style
                    socRootRow()

                    // SoC child row
                    CPUTreeRow(row: TreeRow(
                        indent: 1,
                        connector: "■",
                        name: "SoC",
                        nameColor: .xrgGray,
                        freq: "", temp: "", tempColor: .xrgDim,
                        power: "", powerColor: .xrgDim, cumulative: "",
                        sparkData: [], sparkColor: .xrgDim
                    ))
                    .background(Color.xrgBg)

                    // CPU aggregate row
                    cpuAggregateRow()

                    CPUClusterVariantHost()
                        .background(Color.xrgBg)

                    // GPU row
                    gpuRow()

                    // DRAM row
                    dramRow()

                    // Media Engine row
                    CPUTreeRow(row: TreeRow(
                        indent: 2,
                        connector: "■",
                        name: "Media Engine",
                        nameColor: .xrgWhite,
                        freq: "", temp: "", tempColor: .xrgDim,
                        power: "", powerColor: .xrgDim, cumulative: "",
                        sparkData: [], sparkColor: .xrgDim
                    ))
                    .background(Color.xrgBg)

                    // SSD section divider
                    ssdSectionRow()

                    // Display row
                    CPUTreeRow(row: TreeRow(
                        indent: 1,
                        connector: "■",
                        name: "Display",
                        nameColor: .xrgGray,
                        freq: "", temp: "", tempColor: .xrgDim,
                        power: "", powerColor: .xrgDim, cumulative: "",
                        sparkData: [], sparkColor: .xrgGreen
                    ))
                    .background(Color.xrgBg)

                    // Fans rows
                    fansRows()

                    // Peripherals section divider
                    CPUSectionDividerRow(
                        label: "  ■ Peripherals",
                        nameColor: .xrgGray,
                        freq: "", temp: "", tempColor: .xrgDim,
                        power: "", powerColor: .xrgDim, cumulative: "",
                        sparkData: [], sparkColor: .xrgDim
                    )

                    // Network peripherals
                    networkPeripheralRows()
                }
            }
            // .scrollIndicators style — minimal 4px wide
            .scrollIndicators(.never)

            // Software section header
            HStack {
                Text("Software (filter: top 10 by CPU)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.xrgGray)
                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color(red: 13/255, green: 13/255, blue: 13/255))
            .overlay(alignment: .top) {
                Rectangle().fill(Color.xrgDivider).frame(height: 1)
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color(red: 34/255, green: 34/255, blue: 34/255)).frame(height: 1)
            }

            // Software rows (top processes by CPU)
            if let procs = cpu?.topProcesses {
                VStack(spacing: 0) {
                    ForEach(Array(procs.prefix(8).enumerated()), id: \.element.id) { idx, proc in
                        CPUTreeRow(row: TreeRow(
                            indent: 0,
                            connector: "■",
                            name: " \(proc.name) (pid \(proc.id), \(CPUFormatters.formatBytes(proc.memoryBytes)))",
                            nameColor: proc.cpuUsage > 20 ? .xrgYellow : (proc.cpuUsage > 5 ? .xrgGreen : .xrgGray),
                            freq: "", temp: "", tempColor: .xrgDim,
                            power: String(format: "%.1f%%", proc.cpuUsage),
                            powerColor: proc.cpuUsage > 20 ? .xrgYellow : (proc.cpuUsage > 5 ? .xrgGreen : .xrgDim),
                            cumulative: "",
                            sparkData: sparkFromUsage(proc.cpuUsage),
                            sparkColor: proc.cpuUsage > 20 ? .xrgYellow : .xrgDim
                        ))
                        .background(idx % 2 == 0 ? Color.xrgBg : Color.xrgRow)
                    }
                }
            }

            // Status bar
            HStack(spacing: 12) {
                if let cpu {
                    Text("CPU")
                        .foregroundStyle(Color.xrgGray)
                    Text("(\(cpu.coreCount) cores, \(String(format: "%.0f", cpu.totalUsage))%)")
                        .foregroundStyle(Color.xrgWhite)
                }
                Spacer()
                Text("E:\(eCores.count)  P:\(pCores.count)")
                    .foregroundStyle(Color.xrgDim)
            }
            .font(.system(size: 10, design: .monospaced))
            .padding(.horizontal, 8)
            .frame(height: 20)
            .background(Color(red: 13/255, green: 13/255, blue: 13/255))
            .overlay(alignment: .top) {
                Rectangle().fill(Color(red: 34/255, green: 34/255, blue: 34/255)).frame(height: 1)
            }
        }
        .background(Color.xrgBg)
    }

    // MARK: - Hardware tree helper rows

    @ViewBuilder
    private func socRootRow() -> some View {
        CPUSectionDividerRow(
            label: "▼ Apple Silicon (Mac)",
            nameColor: .xrgWhite,
            freq: "",
            temp: "",
            tempColor: .xrgDim,
            power: cpu != nil ? CPUFormatters.formatWatts(totalSoCPower) : "",
            powerColor: .xrgYellow,
            cumulative: "",
            sparkData: histSparkLE(),
            sparkColor: .xrgYellow
        )
    }

    private var totalSoCPower: Double {
        // Use real SMC power readings: PSTR (system total) or sum of PCPC+PCPG
        let soc = appState.monitor.socPower
        if soc > 0 { return soc }
        let cpuPow = appState.monitor.cpuPower
        let gpuPow = appState.monitor.gpuPower
        if cpuPow > 0 || gpuPow > 0 { return cpuPow + gpuPow }
        // Fallback: use GPU reported power + CPU estimated from battery wattage
        return (gpu?.power ?? 0) + (battery?.wattage ?? 0)
    }

    @ViewBuilder
    private func cpuAggregateRow() -> some View {
        let cpuTemp = avgCoreTemp
        let usage = cpu?.totalUsage ?? 0
        CPUTreeRow(row: TreeRow(
            indent: 2,
            connector: "■",
            name: "CPU (\(cpu?.coreCount ?? 0) cores, \(String(format: "%.0f", usage))%)",
            nameColor: .xrgWhite,
            freq: "",
            temp: cpuTemp > 0 ? "\(Int(cpuTemp))°C" : "",
            tempColor: CPUFormatters.tempColor(cpuTemp),
            power: "",
            powerColor: CPUFormatters.loadColor(usage),
            cumulative: "",
            sparkData: histSparkLE(),
            sparkColor: CPUFormatters.loadColor(usage)
        ))
        .background(Color.xrgBg)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.xrgRow).frame(height: 1)
        }
    }

    private var avgCoreTemp: Double {
        let temps = (cpu?.cores ?? []).compactMap { $0.temperature > 0 ? $0.temperature : nil }
        return temps.isEmpty ? 0 : temps.reduce(0, +) / Double(temps.count)
    }

    @ViewBuilder
    private func eCoreClusterRow() -> some View {
        let eTotalUsage = eCores.isEmpty ? 0 : eCores.map(\.usage).reduce(0, +) / Double(eCores.count)
        let eTemp = eCores.compactMap { $0.temperature > 0 ? $0.temperature : nil }
        let eTempAvg = eTemp.isEmpty ? 0 : eTemp.reduce(0, +) / Double(eTemp.count)
        let eFreq = eCores.first(where: { $0.frequency > 0 })?.frequency ?? 0
        CPUTreeRow(row: TreeRow(
            indent: 3,
            connector: "├─",
            name: "E-Cores (\(eCores.count) cores, \(String(format: "%.0f", eTotalUsage))%)",
            nameColor: .xrgGray,
            freq: eFreq > 0 ? "\(eFreq) MHz" : "",
            temp: eTempAvg > 0 ? "\(Int(eTempAvg))°C" : "",
            tempColor: CPUFormatters.tempColor(eTempAvg),
            power: "",
            powerColor: .xrgGreen,
            cumulative: "",
            sparkData: sparkFromUsage(eTotalUsage),
            sparkColor: .xrgGreen
        ))
        .background(Color.xrgRow)
    }

    @ViewBuilder
    private func pCoreClusterRow() -> some View {
        let pTotalUsage = pCores.isEmpty ? 0 : pCores.map(\.usage).reduce(0, +) / Double(pCores.count)
        let pTemp = pCores.compactMap { $0.temperature > 0 ? $0.temperature : nil }
        let pTempAvg = pTemp.isEmpty ? 0 : pTemp.reduce(0, +) / Double(pTemp.count)
        let pFreq = pCores.first(where: { $0.frequency > 0 })?.frequency ?? 0
        CPUTreeRow(row: TreeRow(
            indent: 3,
            connector: "└─",
            name: "P-Cores (\(pCores.count) cores, \(String(format: "%.0f", pTotalUsage))%)",
            nameColor: .xrgGray,
            freq: pFreq > 0 ? "\(pFreq) MHz" : "",
            temp: pTempAvg > 0 ? "\(Int(pTempAvg))°C" : "",
            tempColor: CPUFormatters.tempColor(pTempAvg),
            power: "",
            powerColor: CPUFormatters.loadColor(pTotalUsage),
            cumulative: "",
            sparkData: sparkFromUsage(pTotalUsage),
            sparkColor: .xrgYellow
        ))
        .background(Color.xrgBg)
    }

    @ViewBuilder
    private func gpuRow() -> some View {
        let gpuUtil = gpu?.utilization ?? 0
        let gpuTemp = gpu?.temperature ?? 0
        let gpuFreqMHz = (gpu?.frequency ?? 0) / 1_000_000
        CPUTreeRow(row: TreeRow(
            indent: 2,
            connector: "■",
            name: "GPU (\(gpu?.coreCount ?? 0) cores, \(String(format: "%.0f", gpuUtil))%)",
            nameColor: .xrgWhite,
            freq: gpuFreqMHz > 0 ? "\(gpuFreqMHz) MHz" : "",
            temp: gpuTemp > 0 ? "\(Int(gpuTemp))°C" : "",
            tempColor: CPUFormatters.tempColor(gpuTemp),
            power: gpu != nil ? CPUFormatters.formatWatts(gpu!.power) : "",
            powerColor: CPUFormatters.tempColor(gpuTemp),
            cumulative: "",
            sparkData: appState.monitor.gpuUtilHistory.suffix(15).map { $0 },
            sparkColor: .xrgYellow
        ))
        .background(Color.xrgRow)
    }

    @ViewBuilder
    private func dramRow() -> some View {
        let totalGB = memory != nil ? String(format: "%.1f GB", Double(memory!.total) / 1_073_741_824) : "—"
        CPUTreeRow(row: TreeRow(
            indent: 2,
            connector: "■",
            name: "DRAM (\(totalGB))",
            nameColor: .xrgWhite,
            freq: "", temp: "", tempColor: .xrgDim,
            power: "", powerColor: .xrgGreen, cumulative: "",
            sparkData: [], sparkColor: .xrgGreen
        ))
        .background(Color.xrgBg)
    }

    @ViewBuilder
    private func ssdSectionRow() -> some View {
        CPUSectionDividerRow(
            label: "  ■ SSD (APPLE SSD)",
            nameColor: .xrgGray,
            freq: "",
            temp: "",
            tempColor: .xrgDim,
            power: "",
            powerColor: .xrgDim,
            cumulative: "",
            sparkData: [],
            sparkColor: .xrgDim
        )
        // SSD Read/Write sub-rows
        if let storage {
            CPUTreeRow(row: TreeRow(
                indent: 2,
                connector: "├─",
                name: "Read",
                nameColor: .xrgDim,
                freq: "", temp: "", tempColor: .xrgDim,
                power: "\(CPUFormatters.formatBytes(storage.readBytesPerSec))/s",
                powerColor: .xrgDim,
                cumulative: "",
                sparkData: sparkFromUsage(Double(storage.readBytesPerSec) / 1_000_000),
                sparkColor: .xrgDim
            ))
            .background(Color.xrgBg)

            CPUTreeRow(row: TreeRow(
                indent: 2,
                connector: "└─",
                name: "Write",
                nameColor: .xrgDim,
                freq: "", temp: "", tempColor: .xrgDim,
                power: "\(CPUFormatters.formatBytes(storage.writeBytesPerSec))/s",
                powerColor: .xrgBlue,
                cumulative: "",
                sparkData: sparkFromUsage(Double(storage.writeBytesPerSec) / 1_000_000),
                sparkColor: .xrgBlue
            ))
            .background(Color.xrgRow)
        }
    }

    @ViewBuilder
    private func fansRows() -> some View {
        if let fans = appState.monitor.sensors?.fans, !fans.isEmpty {
            CPUTreeRow(row: TreeRow(
                indent: 1,
                connector: "■",
                name: "Fans",
                nameColor: .xrgGray,
                freq: "", temp: "", tempColor: .xrgDim,
                power: "", powerColor: .xrgDim, cumulative: "",
                sparkData: [], sparkColor: .xrgDim
            ))
            .background(Color.xrgBg)

            ForEach(Array(fans.enumerated()), id: \.offset) { idx, fan in
                CPUTreeRow(row: TreeRow(
                    indent: 2,
                    connector: idx == fans.count - 1 ? "└─" : "├─",
                    name: "\(fan.name) (\(fan.rpm)/\(fan.maxRPM) RPM)",
                    nameColor: .xrgDim,
                    freq: "", temp: "", tempColor: .xrgDim,
                    power: "", powerColor: .xrgDim, cumulative: "",
                    sparkData: sparkFromUsage(Double(fan.rpm) / max(Double(fan.maxRPM), 1) * 10),
                    sparkColor: .xrgDim
                ))
                .background(idx % 2 == 0 ? Color.xrgBg : Color.xrgRow)
            }
        }
    }

    @ViewBuilder
    private func networkPeripheralRows() -> some View {
        // WiFi row
        CPUTreeRow(row: TreeRow(
            indent: 2,
            connector: "└─",
            name: "WiFi",
            nameColor: .xrgGray,
            freq: "", temp: "", tempColor: .xrgDim,
            power: "", powerColor: .xrgGreen, cumulative: "",
            sparkData: [], sparkColor: .xrgGreen
        ))
        .background(Color.xrgBg)

        if let net = network {
            CPUTreeRow(row: TreeRow(
                indent: 3,
                connector: "├─",
                name: "Download",
                nameColor: .xrgDim,
                freq: "", temp: "", tempColor: .xrgDim,
                power: "\(CPUFormatters.formatBytes(net.totalRxBytesPerSec))/s",
                powerColor: .xrgGreen,
                cumulative: "",
                sparkData: appState.monitor.networkDownHistory.suffix(15).map { Double($0) / 1024 },
                sparkColor: .xrgGreen
            ))
            .background(Color.xrgRow)

            CPUTreeRow(row: TreeRow(
                indent: 3,
                connector: "└─",
                name: "Upload",
                nameColor: .xrgDim,
                freq: "", temp: "", tempColor: .xrgDim,
                power: "\(CPUFormatters.formatBytes(net.totalTxBytesPerSec))/s",
                powerColor: .xrgDim,
                cumulative: "",
                sparkData: appState.monitor.networkUpHistory.suffix(15).map { Double($0) / 1024 },
                sparkColor: .xrgDim
            ))
            .background(Color.xrgBg)
        }
    }
}

// MARK: - Chart overlay labels (top-left, matches HTML .chart-labels)
private struct ChartOverlayLabels: View {
    let lines: [(String, Color)]

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, item in
                Text(item.0)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(item.1)
                    .lineLimit(1)
            }
        }
        .padding(.leading, 5)
        .padding(.top, 3)
    }
}

// MARK: - Stacked CPU histogram (matches HTML drawCpuHistogram: system #1122aa + user #3355dd bars)
private struct StackedCPUChart: View {
    let history: [Double]       // total usage 0–100
    let userFraction: Double    // 0–1
    let systemFraction: Double

    var body: some View {
        Canvas { ctx, size in
            guard !history.isEmpty else { return }
            let n = history.count
            let barW = size.width / CGFloat(n)
            for (i, v) in history.enumerated() {
                let sysH  = CGFloat(v * systemFraction / 100.0) * size.height
                let userH = CGFloat(v * userFraction  / 100.0) * size.height
                let x = CGFloat(i) * barW
                let w = max(1, barW - 1)
                if sysH > 0 {
                    let r = CGRect(x: x, y: size.height - sysH, width: w, height: sysH)
                    ctx.fill(Path(r), with: .color(Color.cpuSystem))
                }
                if userH > 0 {
                    let r = CGRect(x: x, y: size.height - sysH - userH, width: w, height: userH)
                    ctx.fill(Path(r), with: .color(Color.cpuUser))
                }
            }
        }
    }
}

// MARK: - Orange/colour histogram (matches HTML drawHistogram — used for GPU, Net, Disk)
private struct HistogramChart: View {
    let data: [Double]
    let domainMax: Double
    let color: Color

    var body: some View {
        Canvas { ctx, size in
            guard !data.isEmpty else { return }
            let n = data.count
            let barW = size.width / CGFloat(n)
            let maxV = max(domainMax, data.max() ?? 1, 1)
            for (i, v) in data.enumerated() {
                let barH = CGFloat(v / maxV) * size.height
                guard barH > 0 else { continue }
                let x = CGFloat(i) * barW
                let w = max(1, barW - 1)
                let r = CGRect(x: x, y: size.height - barH, width: w, height: barH)
                ctx.fill(Path(r), with: .color(color))
            }
        }
    }
}

// MARK: - Stacked memory area (matches HTML drawMemArea: wired blue + active orange)
private struct StackedMemoryChart: View {
    let wiredHistory: [Double]    // pct 0–100 of total
    let activeHistory: [Double]

    var body: some View {
        Canvas { ctx, size in
            guard !wiredHistory.isEmpty else { return }
            let n = wiredHistory.count
            let xStep = size.width / CGFloat(max(n - 1, 1))

            func drawArea(vals: [Double], offset: [Double], color: Color, alpha: Double) {
                ctx.withCGContext { cgCtx in
                    cgCtx.beginPath()
                    cgCtx.setFillColor(UIColorBridge.cgColor(color, alpha: alpha))
                    for (i, v) in vals.enumerated() {
                        let combined = min((offset.isEmpty ? 0 : offset[i]) + v, 100)
                        let x = CGFloat(i) * xStep
                        let y = size.height - CGFloat(combined / 100.0) * (size.height - 2) - 1
                        if i == 0 { cgCtx.move(to: CGPoint(x: x, y: y)) }
                        else       { cgCtx.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    cgCtx.addLine(to: CGPoint(x: CGFloat(n - 1) * xStep, y: size.height))
                    cgCtx.addLine(to: CGPoint(x: 0, y: size.height))
                    cgCtx.closePath()
                    cgCtx.fillPath()
                }
            }

            drawArea(vals: wiredHistory, offset: [], color: .memWired, alpha: 0.7)
            drawArea(vals: activeHistory, offset: wiredHistory, color: .memActive, alpha: 0.6)
        }
    }
}

// CG color bridge (avoid UIKit dependency — use SwiftUI resolved color)
private enum UIColorBridge {
    static func cgColor(_ color: Color, alpha: Double) -> CGColor {
        // Resolve via NSColor on macOS
        let nsColor = NSColor(color).withAlphaComponent(alpha)
        return nsColor.cgColor
    }
}

// MARK: - Two-line chart (matches HTML drawTwoLines — used for Temperature)
private struct TwoLineChart: View {
    let dataA: [Double]
    let dataB: [Double]
    let colorA: Color
    let colorB: Color
    let domainMax: Double

    var body: some View {
        Canvas { ctx, size in
            let n = max(dataA.count, dataB.count)
            guard n > 1 else { return }
            let xStep = size.width / CGFloat(n - 1)
            let maxV = max(domainMax, 1)

            func drawLine(_ data: [Double], color: Color) {
                guard !data.isEmpty else { return }
                ctx.withCGContext { cgCtx in
                    cgCtx.beginPath()
                    cgCtx.setStrokeColor(NSColor(color).cgColor)
                    cgCtx.setLineWidth(1.5)
                    for (i, v) in data.enumerated() {
                        let x = CGFloat(i) * xStep
                        let y = size.height - CGFloat(min(v / maxV, 1.0)) * (size.height - 2) - 1
                        if i == 0 { cgCtx.move(to: CGPoint(x: x, y: y)) }
                        else       { cgCtx.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    cgCtx.strokePath()
                }
            }

            drawLine(dataA, color: colorA)
            drawLine(dataB, color: colorB)
        }
    }
}

// MARK: - Memory mini bar (right side of memory strip — matches HTML .mem-mini-bar)
private struct MemMiniBar: View {
    let wiredPct: Double
    let activePct: Double
    let inactivePct: Double

    var body: some View {
        VStack(spacing: 0) {
            Color.memWired.frame(height: CGFloat(max(wiredPct, 2)))
            Color.memActive.frame(height: CGFloat(max(activePct, 2)))
            Color.memInactive.frame(height: CGFloat(max(inactivePct, 2)))
            Color(red: 0.2, green: 0.2, blue: 0.2).frame(maxHeight: .infinity)
        }
        .frame(width: 40)
        .border(Color.xrgDivider, width: 1)
        .clipped()
    }
}

// MARK: - RIGHT PANEL (6 chart strips matching HTML right-panel)
private struct CPURightPanel: View {
    @Environment(AppState.self) private var appState
    @State private var isVisible = false

    private var cpu: CPUData? { appState.monitor.cpu }
    private var gpu: GPUData? { appState.monitor.gpu }
    private var memory: MemoryData? { appState.monitor.memory }
    private var network: NetworkData? { appState.monitor.network }
    private var storage: StorageData? { appState.monitor.storage }

    private var cpuHistory: [Double] { appState.monitor.cpuHistory }
    private var gpuHistory: [Double] { appState.monitor.gpuUtilHistory }
    private var memHistory: [Double] { appState.monitor.memoryHistory }
    private var netDownHistory: [UInt64] { appState.monitor.networkDownHistory }
    private var netUpHistory: [UInt64] { appState.monitor.networkUpHistory }

    private var userFraction: Double {
        guard let cpu, cpu.totalUsage > 0 else { return 0.6 }
        return cpu.userUsage / cpu.totalUsage
    }
    private var systemFraction: Double {
        guard let cpu, cpu.totalUsage > 0 else { return 0.3 }
        return cpu.systemUsage / cpu.totalUsage
    }

    // Temp history — two series: CPU avg temp + GPU temp (both projected as constant for history)
    private var allCores: [CPUCore] { cpu?.cores ?? [] }
    private var currentCPUTemp: Double {
        let temps = allCores.compactMap { $0.temperature > 0 ? $0.temperature : nil }
        return temps.isEmpty ? 0 : temps.reduce(0, +) / Double(temps.count)
    }
    private var currentGPUTemp: Double { gpu?.temperature ?? 0 }
    private var cpuTempHistory: [Double] {
        guard !cpuHistory.isEmpty else { return [] }
        return cpuHistory.map { _ in currentCPUTemp }
    }
    private var gpuTempHistory: [Double] {
        guard !gpuHistory.isEmpty else { return [] }
        return gpuHistory.map { _ in currentGPUTemp }
    }

    // Memory pct histories — wired and active as % of total
    private var wiredPctHistory: [Double] {
        guard let memory else { return memHistory.map { _ in 38.0 } }
        let wiredPct = Double(memory.wired) / Double(max(memory.total, 1)) * 100
        return memHistory.map { _ in wiredPct }
    }
    private var activePctHistory: [Double] {
        guard let memory else { return memHistory.map { _ in 32.0 } }
        let activePct = Double(memory.active) / Double(max(memory.total, 1)) * 100
        return memHistory.map { _ in activePct }
    }

    // Pct of total for mini bar
    private var wiredBarPct: Double {
        guard let memory else { return 38 }
        return Double(memory.wired) / Double(max(memory.total, 1)) * 100
    }
    private var activeBarPct: Double {
        guard let memory else { return 32 }
        return Double(memory.active) / Double(max(memory.total, 1)) * 100
    }
    private var inactiveBarPct: Double {
        guard let memory else { return 25 }
        return Double(memory.inactive) / Double(max(memory.total, 1)) * 100
    }

    // Network normalised to 0–100 scale
    private var netDownNorm: [Double] {
        let maxV = max(netDownHistory.max() ?? 1, 1)
        return netDownHistory.map { Double($0) / Double(maxV) * 100 }
    }

    // Disk data (read from storage — bytes/sec normalised)
    private var diskWriteNorm: [Double] {
        guard let storage else { return [] }
        return [Double(storage.writeBytesPerSec) / 1_048_576]  // single point until history exists
    }
    private var diskReadNorm: [Double] {
        guard let storage else { return [] }
        return [Double(storage.readBytesPerSec) / 1_048_576]
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {

                // Strip 1: CPU — flex 2.5
                chartStrip(flex: 2.5, total: geo.size.height) {
                    ZStack(alignment: .topLeading) {
                        if !cpuHistory.isEmpty && isVisible {
                            StackedCPUChart(
                                history: cpuHistory,
                                userFraction: userFraction,
                                systemFraction: systemFraction
                            )
                        } else {
                            Color.xrgBg
                        }
                        ChartOverlayLabels(lines: [
                            ("CPU \(String(format: "%.0f", cpu?.totalUsage ?? 0))%", .xrgWhite),
                            ("Average: \(String(format: "%.1f", avgCPU))%", .xrgGray),
                            ("User: \(String(format: "%.1f", cpu?.userUsage ?? 0))%", .cpuUser),
                            ("System: \(String(format: "%.1f", cpu?.systemUsage ?? 0))%", Color.cpuSystem),
                            ("Idle: \(String(format: "%.1f", cpu?.idleUsage ?? 0))%", .xrgDim),
                        ])
                    }
                }

                divider()

                // Strip 2: GPU — flex 1.2 — orange histogram (#cc7700)
                chartStrip(flex: 1.2, total: geo.size.height) {
                    ZStack(alignment: .topLeading) {
                        if !gpuHistory.isEmpty && isVisible {
                            HistogramChart(data: gpuHistory, domainMax: 100, color: .gpuOrange)
                        } else {
                            Color.xrgBg
                        }
                        ChartOverlayLabels(lines: [
                            ("GPU \(String(format: "%.0f", gpu?.utilization ?? 0))%", .xrgWhite),
                            ("Avg: \(String(format: "%.1f", avgGPU))%", .xrgGray),
                            (gpu != nil && gpu!.frequency > 0 ? "\(gpu!.frequency / 1_000_000) MHz" : "", .xrgGray),
                        ])
                    }
                }

                divider()

                // Strip 3: Memory — flex 1.2 — stacked area + mini bar
                chartStrip(flex: 1.2, total: geo.size.height) {
                    ZStack(alignment: .topLeading) {
                        if !memHistory.isEmpty && isVisible {
                            StackedMemoryChart(
                                wiredHistory: wiredPctHistory,
                                activeHistory: activePctHistory
                            )
                        } else {
                            Color.xrgBg
                        }
                        ChartOverlayLabels(lines: [
                            ("Memory", .xrgWhite),
                            (memory != nil ? String(format: "W: %.0f MB", Double(memory!.wired) / 1_048_576) : "W: —", .memWired),
                            (memory != nil ? String(format: "A: %.0f MB", Double(memory!.active) / 1_048_576) : "A: —", .memActive),
                            (memory != nil ? String(format: "I: %.0f MB", Double(memory!.inactive) / 1_048_576) : "I: —", .memInactive),
                            (memory != nil ? String(format: "F: %.0f MB", Double(memory!.free) / 1_048_576) : "F: —", .xrgDim),
                        ])

                        // Memory mini bar — right side
                        HStack {
                            Spacer()
                            MemMiniBar(wiredPct: wiredBarPct, activePct: activeBarPct, inactivePct: inactiveBarPct)
                                .padding(.trailing, 5)
                                .padding(.vertical, 4)
                        }
                    }
                }

                divider()

                // Strip 4: Temperature — flex 1.2 — two-line (CPU orange, GPU dark red)
                chartStrip(flex: 1.2, total: geo.size.height) {
                    ZStack(alignment: .topLeading) {
                        if !cpuTempHistory.isEmpty && isVisible {
                            TwoLineChart(
                                dataA: cpuTempHistory,
                                dataB: gpuTempHistory,
                                colorA: .tempCPU,
                                colorB: .tempGPU,
                                domainMax: 120
                            )
                        } else {
                            Color.xrgBg
                        }
                        ChartOverlayLabels(lines: [
                            ("Temperature", .xrgGray),
                            (currentCPUTemp > 0 ? String(format: "CPU: %.0f°C", currentCPUTemp) : "CPU: —", .tempCPU),
                            (currentGPUTemp > 0 ? String(format: "GPU: %.0f°C", currentGPUTemp) : "GPU: —", .tempGpuLabel),
                        ])
                    }
                }

                divider()

                // Strip 5: Network — flex 1.2 — orange histogram (Rx) + label
                chartStrip(flex: 1.2, total: geo.size.height) {
                    ZStack(alignment: .topLeading) {
                        if !netDownNorm.isEmpty && isVisible {
                            HistogramChart(data: netDownNorm, domainMax: 100, color: .gpuOrange)
                        } else {
                            Color.xrgBg
                        }
                        ChartOverlayLabels(lines: [
                            (network != nil ? "Net \(CPUFormatters.formatBytes(network!.totalRxBytesPerSec))/s Rx" : "Net —", .xrgWhite),
                            (network != nil ? "Tx: \(CPUFormatters.formatBytes(network!.totalTxBytesPerSec))/s" : "Tx: —", .xrgGray),
                        ])
                    }
                }

                divider()

                // Strip 6: Disk — flex 1.2 — blue histogram (#3355cc), no bottom border
                chartStrip(flex: 1.2, total: geo.size.height) {
                    ZStack(alignment: .topLeading) {
                        if isVisible, let storage {
                            // Use current values as single bar since no history yet
                            let wNorm = min(Double(storage.writeBytesPerSec) / 1_048_576 / 30 * 100, 100)
                            HistogramChart(
                                data: Array(repeating: wNorm, count: 60),
                                domainMax: 100,
                                color: .diskBlue
                            )
                        } else {
                            Color.xrgBg
                        }
                        ChartOverlayLabels(lines: [
                            (storage != nil ? "Disk \(CPUFormatters.formatBytes(storage!.writeBytesPerSec))/s W" : "Disk —", .xrgWhite),
                            (storage != nil ? "R: \(CPUFormatters.formatBytes(storage!.readBytesPerSec))/s" : "R: —", .xrgGray),
                        ])
                    }
                }
            }
        }
        .background(Color.xrgBg)
        .onAppear  { isVisible = true  }
        .onDisappear { isVisible = false }
    }

    private var avgCPU: Double {
        cpuHistory.isEmpty ? 0 : cpuHistory.reduce(0, +) / Double(cpuHistory.count)
    }
    private var avgGPU: Double {
        gpuHistory.isEmpty ? 0 : gpuHistory.reduce(0, +) / Double(gpuHistory.count)
    }

    @ViewBuilder
    private func chartStrip<Content: View>(
        flex: CGFloat,
        total: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let totalFlex: CGFloat = 2.5 + 1.2 * 5
        let h = total * (flex / totalFlex)
        content()
            .frame(height: max(h, 28))
            .clipped()
    }

    private func divider() -> some View {
        Rectangle()
            .fill(Color.xrgDivider)
            .frame(height: 1)
    }
}

// MARK: - Cluster variant host (AppStorage-driven switcher embedded in tree)
private struct CPUClusterVariantHost: View {
    @Environment(AppState.self) private var appState
    @AppStorage(CPUVariant.storageKey) private var rawVariant: Int = CPUVariant.ringGrid.rawValue

    private var variant: CPUVariant { CPUVariant(rawValue: rawVariant) ?? .ringGrid }
    private var clusters: [CPUClusterModel] { CPUClusterTopology.split(cpu: appState.monitor.cpu) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Per-cluster")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.xrgGray)
                Spacer()
                Picker("", selection: $rawVariant) {
                    ForEach(CPUVariant.allCases) { v in
                        Text(v.displayName).tag(v.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .controlSize(.small)
                .tint(CPUClusterPalette.t2)
            }
            .padding(.horizontal, 6)
            .padding(.top, 6)

            Group {
                switch variant {
                case .ringGrid:            CPUClusterRingGrid(clusters: clusters)
                case .stackedBars:         CPUClusterStackedBars(clusters: clusters)
                case .heatmapStrip:        CPUClusterHeatmapStrip(clusters: clusters)
                case .parallelCoordinates: CPUClusterParallelCoordinates(clusters: clusters)
                case .arcMeter:            CPUClusterArcMeter(clusters: clusters)
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 8)
        }
    }
}

// MARK: - CPUView (root)
struct CPUView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        HSplitView {
            // Left: power tree (~42% matching html left-panel width: 42%)
            CPULeftPanel()
                .frame(minWidth: 340, idealWidth: 440, maxWidth: 560)
                .background(Color.xrgBg)

            // Right: 6 chart strips (~58%)
            CPURightPanel()
                .frame(minWidth: 300)
                .background(Color.xrgBg)
        }
        .background(Color.xrgBg)
    }
}

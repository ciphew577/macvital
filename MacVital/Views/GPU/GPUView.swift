// MacVital/Views/GPU/GPUView.swift
// Pixel-perfect match to mockups/gpu-final.html
// Flat design, no card backgrounds, section dividers only
import SwiftUI
import Charts

// MARK: - Color palette

private enum GPUColors {
    // Exact hex values from HTML :root vars
    static let indigo  = Color(red: 94/255,  green: 92/255,  blue: 230/255) // #5E5CE6 --indigo
    static let blue    = Color(red: 10/255,  green: 132/255, blue: 255/255) // #0A84FF --blue
    static let green   = Color(red: 50/255,  green: 215/255, blue: 75/255)  // #32D74B --green
    static let red     = Color(red: 255/255, green: 69/255,  blue: 58/255)  // #FF453A --red
    static let orange  = Color(red: 255/255, green: 159/255, blue: 10/255)  // #FF9F0A
    // --text: rgba(255,255,255,0.85)
    static let text    = Color.white.opacity(0.85)
    // --text2: rgba(255,255,255,0.55)
    static let text2   = Color.white.opacity(0.55)
    // --text3: rgba(255,255,255,0.35)
    static let text3   = Color.white.opacity(0.35)
    // --sep: rgba(255,255,255,0.08)
    static let sep     = Color.white.opacity(0.08)
    // --bg: #1C1C1E
    static let bg      = Color(red: 0.11, green: 0.11, blue: 0.118)
}

// MARK: - Number formatters

private enum GPUFMT {
    static let rpm: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        return f
    }()
}

// MARK: - Area chart (Swift Charts AreaMark + LineMark)

private struct GPUAreaChart: View {
    let data: [Double]
    var color: Color = GPUColors.indigo
    var domainMax: Double = 100
    var height: CGFloat = 220
    var showGridLines: Bool = false
    var fillOpacity: Double = 0.35
    var isActive: Bool = true

    private struct Pt: Identifiable {
        let id: Int
        let x: Int
        let y: Double
    }

    private var pts: [Pt] {
        let base = data.isEmpty ? [0.0, 0.0] : data
        return base.enumerated().map { Pt(id: $0.offset, x: $0.offset, y: $0.element) }
    }

    var body: some View {
        Chart {
            if showGridLines {
                // Horizontal grid lines at 25, 50, 75, 100
                ForEach([25.0, 50.0, 75.0, 100.0], id: \.self) { v in
                    RuleMark(y: .value("grid", v))
                        .foregroundStyle(Color.white.opacity(0.06))
                        .lineStyle(StrokeStyle(lineWidth: 0.5))
                }
            }
            ForEach(pts) { p in
                AreaMark(
                    x: .value("t", p.x),
                    y: .value("v", p.y)
                )
                .foregroundStyle(color.opacity(fillOpacity))
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("t", p.x),
                    y: .value("v", p.y)
                )
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...max(domainMax, 1))
        .frame(height: height)
        .animation(isActive ? .smooth(duration: 0.4) : .none, value: data)
    }
}

// MARK: - Bandwidth dual area chart

private struct GPUBandwidthChart: View {
    let readData: [Double]    // GB/s
    let writeData: [Double]   // GB/s
    var height: CGFloat = 80
    var isActive: Bool = true

    private struct BWPt: Identifiable {
        let id: Int
        let x: Int
        let read: Double
        let write: Double
    }

    private var pts: [BWPt] {
        let count = max(readData.count, writeData.count)
        guard count > 0 else { return [BWPt(id: 0, x: 0, read: 0, write: 0)] }
        return (0..<count).map { i in
            BWPt(
                id: i, x: i,
                read:  i < readData.count  ? readData[i]  : 0,
                write: i < writeData.count ? writeData[i] : 0
            )
        }
    }

    private var domainMax: Double {
        let m = max(readData.max() ?? 0, writeData.max() ?? 0)
        return max(m * 1.15, 1)
    }

    var body: some View {
        Chart {
            ForEach(pts) { p in
                AreaMark(
                    x: .value("t", p.x),
                    y: .value("Read", p.read)
                )
                .foregroundStyle(GPUColors.blue.opacity(0.25))
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("t", p.x),
                    y: .value("Read", p.read)
                )
                .foregroundStyle(GPUColors.blue)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("t", p.x),
                    y: .value("Write", p.write)
                )
                .foregroundStyle(GPUColors.red.opacity(0.25))
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("t", p.x),
                    y: .value("Write", p.write)
                )
                .foregroundStyle(GPUColors.red)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
                .interpolationMethod(.catmullRom)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...domainMax)
        .frame(height: height)
        .animation(isActive ? .smooth(duration: 0.4) : .none, value: readData)
        .animation(isActive ? .smooth(duration: 0.4) : .none, value: writeData)
    }
}

// MARK: - Section divider (18px vertical margin each side)

private struct GPUSectionDivider: View {
    var body: some View {
        Rectangle()
            .fill(GPUColors.sep)
            .frame(height: 1)
            .padding(.vertical, 18)
    }
}

// MARK: - Section label (10px semibold uppercase, letter-spacing .08em, color text3)

private struct GPUSectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(1)       // ~0.08em at 10px
            .foregroundStyle(GPUColors.text3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 10)
    }
}

// MARK: - Flat row (thermals / power)
// HTML: .flat-row, flex space-between, padding 7px 0, border-bottom rgba(255,255,255,0.04)

private struct GPUFlatRow: View {
    let key: String
    let value: String
    var sub: String? = nil
    var valueColor: Color = GPUColors.text

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(key)
                .font(.system(size: 12))
                .foregroundStyle(GPUColors.text2)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(valueColor)
            if let sub {
                Text(sub)
                    .font(.system(size: 10))
                    .monospacedDigit()
                    .foregroundStyle(GPUColors.text3)
                    .padding(.leading, 6)
            }
        }
        .padding(.vertical, 7)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.04))
                .frame(height: 1)
        }
    }
}

// MARK: - Helpers

private func statsString(_ data: [Double], unit: String = "%") -> String {
    guard !data.isEmpty else { return "min - / avg - / max -" }
    let mn  = data.min() ?? 0
    let mx  = data.max() ?? 0
    let avg = data.reduce(0, +) / Double(data.count)
    if unit == "%" {
        return String(format: "min %.0f / avg %.0f / max %.0f %%", mn, avg, mx)
    }
    return String(format: "min %.1f / avg %.1f / max %.1f %@", mn, avg, mx, unit)
}

// P-State frequencies matching HTML mockup
private let pstateFreqs: [Int] = [
    338, 450, 556, 650, 722, 820, 900, 950, 1040, 1150, 1250, 1350, 1450, 1530, 1578
]
private let pstateLabels: [String] = ["338 MHz", "600 MHz", "800 MHz", "950 MHz", "1200 MHz", "1578 MHz"]

// MARK: - GPUView

struct GPUView: View {
    @Environment(AppState.self) private var appState
    @State private var isVisible = false
    @AppStorage(GPUVariantStorage.key) private var gpuVariantRaw: Int = GPUVariant.heatStrip.rawValue
    private var gpuVariant: GPUVariant { GPUVariant(rawValue: gpuVariantRaw) ?? .heatStrip }

    private var gpu: GPUData? { appState.monitor.gpu }
    private var utilH: [Double]   { appState.monitor.gpuUtilHistory }
    private var renderH: [Double] { appState.monitor.gpuRenderHistory }
    private var tilerH: [Double]  { appState.monitor.gpuTilerHistory }
    private var computeH: [Double] { appState.monitor.gpuComputeHistory }
    private var readBWH: [Double] { appState.monitor.gpuReadBWHistory.map { toGBs($0) } }
    private var writeBWH: [Double] { appState.monitor.gpuWriteBWHistory.map { toGBs($0) } }

    private func tempColor(_ t: Double) -> Color {
        if t >= 90 { return GPUColors.red }
        if t >= 70 { return GPUColors.orange }
        return GPUColors.green
    }

    private func processColor(type: String) -> Color {
        // Standardised across GPU tab: Render = indigo, Compute = blue.
        // Matches GPUVariantPalette.render / .compute used by all GPU variants.
        switch type {
        case "Render":  return GPUColors.indigo
        case "Compute": return GPUColors.blue
        default:        return GPUColors.green
        }
    }

    private func toGBs(_ bytes: UInt64) -> Double {
        Double(bytes) / 1_073_741_824.0
    }

    private var gpuNameDisplay: String { gpu?.gpuName ?? "Apple GPU" }
    private var gpuCores: Int          { gpu?.coreCount ?? 0 }
    private var metalVer: String       { gpu?.metalVersion ?? "Metal 3" }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                // ── IDENTITY ROW ──────────────────────────────────────
                identityRow

                // ── HERO: GPU UTILIZATION ─────────────────────────────
                GPUSectionLabel(text: "GPU Utilization")
                heroSection
                GPUSectionDivider()

                // ── SHADER CORES + ANE/MEDIA (SWITCHABLE VARIANT) ─────
                gpuCoresVariantHeader
                gpuCoresVariantBody
                GPUSectionDivider()

                // ── ENGINE BREAKDOWN ──────────────────────────────────
                GPUSectionLabel(text: "Engine Breakdown")
                engineBreakdown
                GPUSectionDivider()

                // ── UNIFIED MEMORY ────────────────────────────────────
                GPUSectionLabel(text: "Unified Memory")
                memorySection
                GPUSectionDivider()

                // ── THERMALS + POWER ──────────────────────────────────
                GPUSectionLabel(text: "Thermals & Power")
                thermalsAndPower
                GPUSectionDivider()

                // ── P-STATE FREQUENCY DISTRIBUTION ───────────────────
                GPUSectionLabel(text: "P-State Frequency Distribution")
                pstateHistogram
                GPUSectionDivider()

                // ── NEURAL ENGINE (ANE) ───────────────────────────────
                aneSection
                GPUSectionDivider()

                // ── TOP GPU PROCESSES ─────────────────────────────────
                GPUSectionLabel(text: "Top GPU Processes")
                processTable
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .navigationTitle("GPU")
        .onAppear  { isVisible = true  }
        .onDisappear { isVisible = false }
    }

    // MARK: - Identity Row
    // HTML: .identity, flex, align-center, gap:10, mb:18
    // Left: name (15px semibold), badges (indigo/blue)
    // Right: memory clock + core clock (tabular), status dot (green), fan pill

    @ViewBuilder
    private var identityRow: some View {
        HStack(alignment: .center, spacing: 10) {
            // GPU name, .id-name: 15px semibold, color text
            Text(gpuNameDisplay)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(GPUColors.text)

            // Cores badge, .badge-indigo: bg rgba(94,92,230,0.2), color indigo
            if gpuCores > 0 {
                Text("\(gpuCores) Cores")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(GPUColors.indigo)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(GPUColors.indigo.opacity(0.2),
                                in: RoundedRectangle(cornerRadius: 4))
            }

            // Metal badge, .badge-blue: bg rgba(10,132,255,0.15), color blue
            Text(metalVer)
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(GPUColors.blue)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(GPUColors.blue.opacity(0.15),
                            in: RoundedRectangle(cornerRadius: 4))

            Spacer()

            // id-clocks: memory clock (left), core clock (right), gap 16
            HStack(alignment: .center, spacing: 16) {
                // Memory Clock
                VStack(alignment: .trailing, spacing: 1) {
                    Text(gpu.map { $0.memoryFrequency > 0
                         ? String(format: "%.1f GHz", Double($0.memoryFrequency) / 1_000_000_000.0)
                         : "-" } ?? "-")
                        .font(.system(size: 13, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(GPUColors.text)
                    Text("Memory Clock")
                        .font(.system(size: 9))
                        .tracking(0.6)
                        .textCase(.uppercase)
                        .foregroundStyle(GPUColors.text3)
                }

                // Core Clock
                VStack(alignment: .trailing, spacing: 1) {
                    Text(gpu.map { $0.frequency > 0
                         ? "\($0.frequency / 1_000_000) MHz"
                         : "-" } ?? "-")
                        .font(.system(size: 13, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(GPUColors.text)
                    Text("Core Clock")
                        .font(.system(size: 9))
                        .tracking(0.6)
                        .textCase(.uppercase)
                        .foregroundStyle(GPUColors.text3)
                }
            }

            // Status dot, .status-dot: green, 6px circle (no shadow per MV palette)
            HStack(spacing: 5) {
                Circle()
                    .fill(GPUColors.green)
                    .frame(width: 6, height: 6)
                Text("Active")
                    .font(.system(size: 11))
                    .foregroundStyle(GPUColors.green)
            }
            .padding(.leading, 8)

            // Fan pill, .fan-pill: bg rgba(255,255,255,0.07), border sep, capsule
            if let fan = gpu, fan.fanRPM > 0 {
                let rpmStr = GPUFMT.rpm.string(from: NSNumber(value: fan.fanRPM)) ?? "\(fan.fanRPM)"
                Text(String(format: "GPU Fan %.0f%% · %@ RPM", fan.fanPercent, rpmStr))
                    .font(.system(size: 11))
                    .foregroundStyle(GPUColors.text2)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(Color.white.opacity(0.07))
                            .overlay(Capsule().strokeBorder(GPUColors.sep, lineWidth: 1))
                    )
                    .padding(.leading, 4)
            }
        }
        .padding(.bottom, 18)
    }

    // MARK: - Hero Section
    // HTML: hero-header (flex, lastTextBaseline), hero canvas 220px

    @ViewBuilder
    private var heroSection: some View {
        // Hero header
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            // .hero-big-val: 44px weight-800 indigo tabular letter-spacing:-1px
            Text(String(format: "%.0f", gpu?.utilization ?? 0))
                .font(.system(size: 44, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(GPUColors.indigo)
                .kerning(-1)

            // .hero-big-pct: 20px bold indigo, align-self flex-end, mb:6
            Text("%")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(GPUColors.indigo)
                .padding(.leading, 1)
                .padding(.bottom, 4)

            // .hero-label: 13px text2, align-self flex-end, mb:8, ml:10
            Text("Overall GPU Load")
                .font(.system(size: 13))
                .foregroundStyle(GPUColors.text2)
                .padding(.leading, 10)
                .padding(.bottom, 6)

            Spacer()

            // .hero-stats: margin-left auto, align-self flex-end, mb:6
            Text(statsString(utilH))
                .font(.system(size: 11))
                .monospacedDigit()
                .foregroundStyle(GPUColors.text3)
                .padding(.bottom, 4)
        }
        .padding(.bottom, 6)

        // Hero canvas, 220px, with y-axis labels (100/75/50/25/0)
        HStack(alignment: .top, spacing: 0) {
            // Y-axis labels: .chart-yaxis, 26px wide, flex col justify space-between
            VStack(alignment: .trailing, spacing: 0) {
                ForEach(["100", "75", "50", "25", "0"], id: \.self) { label in
                    Text(label)
                        .font(.system(size: 9))
                        .monospacedDigit()
                        .foregroundStyle(GPUColors.text3)
                    if label != "0" { Spacer() }
                }
            }
            .frame(width: 26, height: 220)
            .padding(.bottom, 18) // chart-yaxis: bottom 18px (for x-axis space)

            GPUAreaChart(
                data: utilH,
                color: GPUColors.indigo,
                domainMax: 100,
                height: 220,
                showGridLines: true,
                isActive: isVisible
            )
        }
        .padding(.bottom, 4)

        HStack {
            Spacer()
            Text("120s rolling window")
                .font(.system(size: 10))
                .foregroundStyle(GPUColors.text3)
        }
        .padding(.bottom, 4)
    }

    // MARK: - Engine Breakdown (3 columns)
    // HTML: .engines, grid 1fr 1fr 1fr, gap:1px, bg sep, border sep, border-radius:8, overflow hidden

    @ViewBuilder
    private var engineBreakdown: some View {
        HStack(spacing: 1) {
            engineColumn(name: "Render",  value: gpu?.renderUtilization  ?? 0,
                         color: GPUColors.indigo, history: renderH)

            Rectangle().fill(GPUColors.sep).frame(width: 1)

            engineColumn(name: "Tiler",   value: gpu?.tilerUtilization   ?? 0,
                         color: GPUColors.green,  history: tilerH)

            Rectangle().fill(GPUColors.sep).frame(width: 1)

            engineColumn(name: "Compute", value: gpu?.computeUtilization ?? 0,
                         color: GPUColors.blue,   history: computeH)
        }
        .background(GPUColors.sep)   // gap fill
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(GPUColors.sep, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // HTML: .engine-col, bg var(--bg), padding 12px 14px
    @ViewBuilder
    private func engineColumn(name: String, value: Double,
                              color: Color, history: [Double]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // .engine-name: 9px semibold uppercase letter-spacing .1em text3
            Text(name.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(GPUColors.text3)
                .padding(.bottom, 4)

            // .engine-val: 22px bold tabular mb:8 line-height:1
            Text(String(format: "%.0f%%", value))
                .font(.system(size: 22, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(color)
                .padding(.bottom, 8)

            GPUAreaChart(data: history, color: color, domainMax: 100, height: 80, fillOpacity: 0.3, isActive: isVisible)

            // .engine-stats: 10px text3 mt:6 tabular
            Text(statsString(history))
                .font(.system(size: 10))
                .monospacedDigit()
                .foregroundStyle(GPUColors.text3)
                .padding(.top, 6)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GPUColors.bg) // --bg: #1C1C1E
    }

    // MARK: - Memory Section
    // HTML: .mem-line (font-size 12 text2), seg-bar (6px capsule), legend, bandwidth

    @ViewBuilder
    private var memorySection: some View {
        let active   = gpu?.vramUsed   ?? 0
        let mapped   = gpu?.vramMapped ?? 0
        let total    = gpu?.vramTotal  ?? 1
        let totalGB  = Double(total)  / 1_073_741_824.0
        let activeGB = Double(active) / 1_073_741_824.0
        let mappedGB = Double(mapped) / 1_073_741_824.0
        let freeGB   = max(0.0, totalGB - activeGB - mappedGB)

        let activeFrac = Double(active) / Double(max(total, 1))
        let mappedFrac = Double(mapped) / Double(max(total, 1))

        // .mem-line: flex, gap:8, font-size 12, text2, mb:10
        HStack(spacing: 4) {
            Group {
                Text("GPU Active:").foregroundStyle(GPUColors.text2)
                Text(ByteFormatter.format(active)).fontWeight(.semibold).foregroundStyle(GPUColors.text)
                if mapped > 0 {
                    Text("·").foregroundStyle(GPUColors.text3)
                    Text("In Use:").foregroundStyle(GPUColors.text2)
                    Text(ByteFormatter.format(mapped)).fontWeight(.semibold).foregroundStyle(GPUColors.text)
                }
                Text("·").foregroundStyle(GPUColors.text3)
                Text("Total:").foregroundStyle(GPUColors.text2)
                Text(String(format: "%.0f GB Unified", totalGB)).fontWeight(.semibold).foregroundStyle(GPUColors.text)
            }
            .font(.system(size: 12))
            Spacer()
        }
        .padding(.bottom, 10)

        // .seg-bar: height 6px, border-radius 3px, bg rgba(255,255,255,0.05)
        GeometryReader { geo in
            HStack(spacing: 0) {
                // GPU Active, indigo solid
                Rectangle()
                    .fill(GPUColors.indigo)
                    .frame(width: geo.size.width * activeFrac, height: 6)
                // In Use, indigo 40%
                if mappedFrac > 0 {
                    Rectangle()
                        .fill(GPUColors.indigo.opacity(0.4))
                        .frame(width: geo.size.width * mappedFrac, height: 6)
                }
                // Free, white 4%
                Rectangle()
                    .fill(Color.white.opacity(0.04))
                    .frame(height: 6)
            }
            .frame(height: 6)
        }
        .frame(height: 6)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .padding(.bottom, 6)

        // Legend dots (7px circle, font-size 10, text3)
        HStack(spacing: 16) {
            memLegendItem(color: GPUColors.indigo,
                          label: String(format: "GPU Active %.1f GB", activeGB))
            if mapped > 0 {
                memLegendItem(color: GPUColors.indigo.opacity(0.5),
                              label: String(format: "In Use %.1f GB", mappedGB))
            }
            memLegendItem(color: Color.white.opacity(0.08),
                          label: String(format: "Free %.1f GB", freeGB))
            Spacer()
        }
        .padding(.bottom, 14)

        // Memory Bandwidth sub-section
        // HTML: .section-label with style="margin-top:4px;"
        GPUSectionLabel(text: "Memory Bandwidth")

        let hasBW = (readBWH.last ?? 0) > 0 || (writeBWH.last ?? 0) > 0 || readBWH.contains(where: { $0 > 0 })

        if hasBW {
            // .bw-labels: flex, gap:16, mb:6
            HStack(spacing: 16) {
                // Read swatch + label
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(GPUColors.blue)
                        .frame(width: 8, height: 8)
                    Text("Read")
                        .font(.system(size: 11))
                        .foregroundStyle(GPUColors.text2)
                    Text(String(format: "%.1f GB/s", readBWH.last ?? 0))
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(GPUColors.text)
                }
                // Write swatch + label
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(GPUColors.red)
                        .frame(width: 8, height: 8)
                    Text("Write")
                        .font(.system(size: 11))
                        .foregroundStyle(GPUColors.text2)
                    Text(String(format: "%.1f GB/s", writeBWH.last ?? 0))
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(GPUColors.text)
                }
                Spacer()
            }
            .padding(.bottom, 6)

            GPUBandwidthChart(readData: readBWH, writeData: writeBWH, height: 80, isActive: isVisible)

            HStack {
                Spacer()
                Text("60s rolling window")
                    .font(.system(size: 10))
                    .foregroundStyle(GPUColors.text3)
            }
            .padding(.top, 4)
        } else {
            Text("Bandwidth counters not exposed via IOAccelerator on this GPU")
                .font(.system(size: 11))
                .foregroundStyle(GPUColors.text3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func memLegendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(GPUColors.text3)
        }
    }

    // MARK: - Thermals + Power (2-column flat rows)
    // HTML .two-col: grid 2 cols, gap: 0 32px
    // LEFT: Temperature, GPU Power, Core Clock, Memory Clock
    // RIGHT: Video Encode, Video Decode, ProRes, Fan Speed

    @ViewBuilder
    private var thermalsAndPower: some View {
        HStack(alignment: .top, spacing: 32) {
            // Left column
            VStack(spacing: 0) {
                GPUFlatRow(
                    key: "Temperature",
                    value: gpu.map { $0.temperature > 0
                        ? String(format: "%.0f°C", $0.temperature)
                        : "-" } ?? "-",
                    sub: utilH.count > 2
                        ? statsString([gpu?.temperature ?? 0], unit: "°C")
                        : nil,
                    valueColor: tempColor(gpu?.temperature ?? 0)
                )
                GPUFlatRow(
                    key: "GPU Power",
                    value: gpu.map { $0.power > 0
                        ? String(format: "%.2f W", $0.power)
                        : "-" } ?? "-"
                )
                GPUFlatRow(
                    key: "Core Clock",
                    value: gpu.map { $0.frequency > 0
                        ? "\($0.frequency / 1_000_000) MHz"
                        : "-" } ?? "-"
                )
                GPUFlatRow(
                    key: "Memory Clock",
                    value: gpu.map { $0.memoryFrequency > 0
                        ? String(format: "%.1f GHz", Double($0.memoryFrequency) / 1_000_000_000.0)
                        : "-" } ?? "-"
                )
            }
            .frame(maxWidth: .infinity)

            // Right column. HTML order: Video Encode, Video Decode, ProRes, Fan Speed.
            // Encode/decode/ProRes utilization keys not exposed in IOAccelerator PerformanceStatistics
            // on Apple Silicon, show "-" when 0 (indistinguishable from "inactive" vs "unavailable").
            VStack(spacing: 0) {
                GPUFlatRow(
                    key: "Video Encode",
                    value: (gpu?.encoderUtilization ?? 0) > 0 ? String(format: "%.0f%%", gpu!.encoderUtilization) : "-"
                )
                GPUFlatRow(
                    key: "Video Decode",
                    value: (gpu?.decoderUtilization ?? 0) > 0 ? String(format: "%.0f%%", gpu!.decoderUtilization) : "-"
                )
                GPUFlatRow(
                    key: "ProRes",
                    value: (gpu?.proResUtilization ?? 0) > 0 ? String(format: "%.0f%%", gpu!.proResUtilization) : "-"
                )
                GPUFlatRow(
                    key: "Fan Speed",
                    value: gpu.map { $0.fanPercent > 0
                        ? String(format: "%.0f%%", $0.fanPercent)
                        : "-" } ?? "-",
                    sub: gpu.flatMap { g -> String? in
                        guard g.fanRPM > 0 else { return nil }
                        let rpmStr = GPUFMT.rpm.string(from: NSNumber(value: g.fanRPM)) ?? "\(g.fanRPM)"
                        return "\(rpmStr) RPM"
                    }
                )
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - P-State Frequency Distribution
    // HTML: .pstate-bar-row (flex align-end, gap:3, height:44, mb:4)
    //       bars: flex:1, border-radius 2 2 0 0, bg rgba(255,255,255,0.12), min-height 3
    //       active bar: bg var(--indigo)
    //       labels: 6 labels evenly spaced, font-size 9, text3

    @ViewBuilder
    private var pstateHistogram: some View {
        let currentFreq = gpu.map { $0.frequency > 0 ? Int($0.frequency / 1_000_000) : 0 } ?? 0

        if currentFreq > 0 {
            // Active index = closest P-state to current frequency
            let activeIdx = pstateFreqs.indices.min(by: {
                abs(pstateFreqs[$0] - currentFreq) < abs(pstateFreqs[$1] - currentFreq)
            }) ?? 0

            let maxBarH: CGFloat = 40
            let minBarH: CGFloat = 4

            VStack(spacing: 4) {
                // Bars, only the active P-state is highlighted; no distribution data available without IOReport
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(0..<pstateFreqs.count, id: \.self) { i in
                        let isActive = i == activeIdx
                        Rectangle()
                            .fill(isActive ? GPUColors.indigo : Color.white.opacity(0.12))
                            .frame(height: isActive ? maxBarH : minBarH)
                            .clipShape(
                                UnevenRoundedRectangle(
                                    topLeadingRadius: 2, bottomLeadingRadius: 0,
                                    bottomTrailingRadius: 0, topTrailingRadius: 2
                                )
                            )
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 44)

                // Labels, 6 labels evenly spread
                HStack {
                    ForEach(pstateLabels.indices, id: \.self) { i in
                        if i > 0 { Spacer() }
                        Text(pstateLabels[i])
                            .font(.system(size: 9))
                            .monospacedDigit()
                            .foregroundStyle(GPUColors.text3)
                    }
                }

                Text("Current: \(currentFreq) MHz  \u{00B7}  Distribution data unavailable without IOReport")
                    .font(.system(size: 10))
                    .foregroundStyle(GPUColors.text3)
                    .padding(.top, 4)
            }
        } else {
            Text("P-State data unavailable")
                .font(.system(size: 12))
                .foregroundStyle(GPUColors.text3)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
    }

    // MARK: - ANE Section
    // HTML: .ane-row, flex, align-center, gap:14
    // Icon: 14x14 SVG rect rx:3 fill rgba(94,92,230,0.25), A-shape path in #5E5CE6
    // "Neural Engine" 12px weight-500 text, "16 cores" 11px text3,
    // "·" text3, status (Idle/<%) 11px text3, "·" text3, watt 11px text3
    // .ane-status: ml auto, 11px text3, bg rgba(255,255,255,0.06), px:8 py:2 border-radius:10

    @ViewBuilder
    private var aneSection: some View {
        HStack(spacing: 14) {
            // Neural Engine icon (14×14 rounded rect + A-shape lines)
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(GPUColors.indigo.opacity(0.25))
                    .frame(width: 14, height: 14)
                Canvas { ctx, size in
                    // A-shape: path "M4 10L7 4L10 10" + crossbar "M5.5 8H8.5"
                    var path = Path()
                    path.move(to: CGPoint(x: 4, y: 10))
                    path.addLine(to: CGPoint(x: 7, y: 4))
                    path.addLine(to: CGPoint(x: 10, y: 10))
                    ctx.stroke(path, with: .color(GPUColors.indigo),
                               style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                    var bar = Path()
                    bar.move(to: CGPoint(x: 5.5, y: 8))
                    bar.addLine(to: CGPoint(x: 8.5, y: 8))
                    ctx.stroke(bar, with: .color(GPUColors.indigo),
                               style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                }
                .frame(width: 14, height: 14)
            }
            .frame(width: 14, height: 14)

            // "Neural Engine", 12px weight-500 text2
            Text("Neural Engine")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(GPUColors.text2)

            // ANE core count, no public API to read this
            Text("ANE")
                .font(.system(size: 11))
                .foregroundStyle(GPUColors.text3)

            Text("·").foregroundStyle(GPUColors.text3).font(.system(size: 11))

            // Status, Idle or pct
            Text(gpu?.aneUtilization ?? 0 < 2 ? "Idle" : String(format: "%.0f%%", gpu?.aneUtilization ?? 0))
                .font(.system(size: 11))
                .foregroundStyle(GPUColors.text3)

            Text("·").foregroundStyle(GPUColors.text3).font(.system(size: 11))

            // Watt
            Text(gpu.map { $0.anePower > 0
                 ? String(format: "%.1f W", $0.anePower)
                 : "0 W" } ?? "0 W")
                .font(.system(size: 11))
                .foregroundStyle(GPUColors.text3)

            Spacer()

            // .ane-status pill, bg rgba(255,255,255,0.06), px:8 py:2, border-radius:10
            Text(String(format: "%.0f%%", gpu?.aneUtilization ?? 0))
                .font(.system(size: 11))
                .foregroundStyle(GPUColors.text3)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    Capsule().fill(Color.white.opacity(0.06))
                )
        }
    }

    // MARK: - Process Table
    // HTML: .proc-table, headers (9px semibold uppercase tracking .08em text3, pb:8, border-bottom sep)
    //       rows: td 8px 0 padding, font-size 12 text2, border-bottom rgba(255,255,255,0.04)
    //       proc-name: text weight-500 12px
    //       type-badge: 9px semibold tracking .04em, bg/color per type
    //       GPU %: flat-val (12px weight-500 tabular text)
    //       bar: 80px wide, 3px high, bg rgba(255,255,255,0.08), fill rounded

    @ViewBuilder
    private var processTable: some View {
        let procs = gpu?.topProcesses ?? []

        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 0) {
                Text("Process")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(GPUColors.text3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Type")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(GPUColors.text3)
                    .frame(width: 64, alignment: .leading)
                Text("GPU %")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(GPUColors.text3)
                    .frame(width: 44, alignment: .trailing)
                Text("Usage")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(GPUColors.text3)
                    .frame(width: 88, alignment: .trailing)
            }
            .padding(.bottom, 8)
            .overlay(alignment: .bottom) {
                Rectangle().fill(GPUColors.sep).frame(height: 1)
            }

            if procs.isEmpty {
                Text("No GPU activity detected")
                    .font(.system(size: 12))
                    .foregroundStyle(GPUColors.text3)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(procs) { proc in
                    processRow(proc: proc)
                }
            }
        }
    }

    @ViewBuilder
    private func processRow(proc: GPUProcess) -> some View {
        let color = processColor(type: proc.type)
        HStack(spacing: 0) {
            // Process name, .proc-name: text weight-500 12px
            Text(proc.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(GPUColors.text)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Type badge, .type-badge: 9px semibold tracking .04em, corners 4
            // Compute uses 0.2 opacity bg; Render/Display use 0.15
            let badgeOpacity: Double = proc.type == "Compute" ? 0.2 : 0.15
            Text(proc.type)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(color.opacity(badgeOpacity), in: RoundedRectangle(cornerRadius: 4))
                .frame(width: 64, alignment: .leading)

            // GPU %, .flat-val: 12px weight-500 tabular text
            Text(String(format: "%.0f%%", proc.gpuPercent))
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(GPUColors.text)
                .frame(width: 44, alignment: .trailing)

            // Mini bar, .proc-bar-wrap: 80px wide 3px high bg rgba(255,255,255,0.08)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 80, height: 3)
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 80 * min(proc.gpuPercent / 100.0, 1.0), height: 3)
            }
            .frame(width: 80, height: 3)
            .padding(.leading, 8)
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.04))
                .frame(height: 1)
        }
    }

    // Shader cores + ANE/Media variant header with picker
    @ViewBuilder
    private var gpuCoresVariantHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            GPUSectionLabel(text: "Shader Cores, ANE, Media Engine")
            Spacer()
            Picker("", selection: $gpuVariantRaw) {
                ForEach(GPUVariant.allCases) { v in
                    Text(v.displayName).tag(v.rawValue)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 180)
            .padding(.bottom, 10)
        }
    }

    @ViewBuilder
    private var gpuCoresVariantBody: some View {
        switch gpuVariant {
        case .heatStrip:         GPUCoresHeatStrip(gpu: gpu)
        case .coreGrid:          GPUCoresGrid(gpu: gpu)
        case .radialSpoke:       GPUCoresRadialSpoke(gpu: gpu)
        case .scrollingTimeline: GPUCoresScrollingTimeline(gpu: gpu)
        case .summaryFirst:      GPUCoresSummaryFirst(gpu: gpu)
        }
    }
}

// MacVital/Views/Network/v2/NetworkBigChart.swift
//
// 60-min (and multi-zoom) network area chart ported from variant-f-fusion.html.
// Targets macOS 13+ (Swift Charts introduced macOS 13).
//
// NOTE: NetworkSample, NetworkChartSeries, NetworkSparkCard are defined as
// placeholders below, defined by data-stubs agent, replace on merge.

import Charts
import SwiftUI

// NetworkSample, NetworkChartSeries declared in NetworkV2Types.swift.
// NetworkSparkCard declared in NetworkSparkCards.swift.
// All chart code below uses those canonical types.

// MARK: - Zoom enum

enum ChartZoom: CaseIterable, Identifiable {
    case fiveMinutes
    case fifteenMinutes
    case oneHour
    case sixHours
    case twentyFourHours

    var id: Self { self }

    var label: String {
        switch self {
        case .fiveMinutes:     return "5m"
        case .fifteenMinutes:  return "15m"
        case .oneHour:         return "1h"
        case .sixHours:        return "6h"
        case .twentyFourHours: return "24h"
        }
    }

    var windowSeconds: Int {
        switch self {
        case .fiveMinutes:     return 5 * 60
        case .fifteenMinutes:  return 15 * 60
        case .oneHour:         return 60 * 60
        case .sixHours:        return 6 * 3600
        case .twentyFourHours: return 24 * 3600
        }
    }

    /// X-axis label pairs: (offset seconds from now, display string)
    var xLabels: [(offsetSeconds: Int, label: String)] {
        switch self {
        case .fiveMinutes:
            return [(-300, "5m ago"), (-240, "4m"), (-180, "3m"), (-120, "2m"), (-60, "1m"), (0, "now")]
        case .fifteenMinutes:
            return [(-900, "15m ago"), (-720, "12m"), (-540, "9m"), (-360, "6m"), (-180, "3m"), (0, "now")]
        case .oneHour:
            return [(-3600, "60m ago"), (-2700, "45m"), (-1800, "30m"), (-900, "15m"), (0, "now")]
        case .sixHours:
            return [(-21600, "6h ago"), (-14400, "4h"), (-7200, "2h"), (-3600, "1h"), (0, "now")]
        case .twentyFourHours:
            return [(-86400, "24h ago"), (-64800, "18h"), (-43200, "12h"), (-21600, "6h"), (0, "now")]
        }
    }
}

// MARK: - Tooltip data model

private struct TooltipInfo {
    let timestamp: Date
    let downloadMBps: Double
    let uploadKBps: Double
    let xPosition: CGFloat
}

// MARK: - Helpers

private func formatBytes(_ bps: UInt64) -> String {
    let mbps = Double(bps) / 1_000_000
    if mbps >= 1 {
        return String(format: "%.1f MB/s", mbps)
    }
    let kbps = Double(bps) / 1_000
    return String(format: "%.0f KB/s", kbps)
}

private func peakLabel(from samples: [NetworkSample], now: Date, windowSeconds: Int) -> String {
    let cutoff = now.addingTimeInterval(-Double(windowSeconds))
    let visible = samples.filter { $0.timestamp >= cutoff }
    guard let peak = visible.max(by: { $0.bytesPerSec < $1.bytesPerSec }) else {
        return "Peak · --"
    }
    let timeStr = DateFormatter.hmm.string(from: peak.timestamp)
    return "Peak · \(formatBytes(peak.bytesPerSec)) at \(timeStr)"
}

// chartTitle: reflects focused card -- download is primary unless focused is upload
private func chartTitle(focused: NetworkSparkCard, zoom: ChartZoom) -> String {
    let window = zoom.label + " history"
    switch focused {
    case .downloadNow: return "Download, \(window)"
    case .uploadNow:   return "Upload, \(window)"
    case .session:     return "Session, \(window)"
    case .today:       return "Today, \(window)"
    case .peak24h:     return "Peak 24h, \(window)"
    case .latency:     return "Latency, \(window)"
    }
}

extension DateFormatter {
    static let hmm: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
    static let hmmss: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()
}

// MARK: - Main view

struct NetworkBigChart: View {
    let series: NetworkChartSeries
    let focused: NetworkSparkCard

    @State private var zoom: ChartZoom = .oneHour
    @State private var tooltipInfo: TooltipInfo?
    @State private var chartFrameWidth: CGFloat = 1

    // Fixed chart height: caps the canvas at 200pt so it doesn't eat the viewport
    private let chartHeight: CGFloat = 200

    private let now = Date()

    // MARK: Filtered slices

    private func visibleDown(zoom: ChartZoom) -> [NetworkSample] {
        let cutoff = now.addingTimeInterval(-Double(zoom.windowSeconds))
        return series.down.filter { $0.timestamp >= cutoff }
    }

    private func visibleUp(zoom: ChartZoom) -> [NetworkSample] {
        let cutoff = now.addingTimeInterval(-Double(zoom.windowSeconds))
        return series.up.filter { $0.timestamp >= cutoff }
    }

    // MARK: Axis ranges

    private func xDomain(zoom: ChartZoom) -> ClosedRange<Date> {
        let start = now.addingTimeInterval(-Double(zoom.windowSeconds))
        return start...now
    }

    // Peak data sits at 75% of chart height: yMax = peak / 0.75 (25% headroom above)
    private func yMax(downSamples: [NetworkSample], upSamples: [NetworkSample]) -> Double {
        let downPeak = downSamples.map { Double($0.bytesPerSec) }.max() ?? 1_000_000
        let upPeak   = upSamples.map { Double($0.bytesPerSec) }.max() ?? 0
        let combined = max(downPeak, upPeak)
        return combined / 0.75
    }

    // MARK: Y tick values (4 lines at 25/50/75/100% of yMax, skip zero)

    private func yTicks(max: Double) -> [Double] {
        [max * 0.25, max * 0.50, max * 0.75, max]
    }

    private func formatYTick(_ value: Double) -> String {
        let mb = value / 1_000_000
        if mb >= 1 {
            return String(format: "%.1f MB/s", mb)
        }
        let kb = value / 1_000
        return String(format: "%.0f KB/s", kb)
    }

    // MARK: Peak marker

    private func peakSample(from samples: [NetworkSample]) -> NetworkSample? {
        samples.max(by: { $0.bytesPerSec < $1.bytesPerSec })
    }

    // MARK: Average line

    private func avgValue(from samples: [NetworkSample]) -> Double {
        guard !samples.isEmpty else { return 0 }
        let total = samples.reduce(0.0) { $0 + Double($1.bytesPerSec) }
        return total / Double(samples.count)
    }

    // MARK: Focused primary / secondary series

    // When focused == .uploadNow, upload is prominent, download is subordinated
    private var uploadFocused: Bool { focused == .uploadNow }

    // MARK: Body

    var body: some View {
        let downSamples = visibleDown(zoom: zoom)
        let upSamples   = visibleUp(zoom: zoom)
        let maxY        = yMax(downSamples: downSamples, upSamples: upSamples)
        let avgY        = avgValue(from: uploadFocused ? upSamples : downSamples)
        let peakSmp     = peakSample(from: uploadFocused ? upSamples : downSamples)
        let domain      = xDomain(zoom: zoom)

        VStack(spacing: 0) {
            // MARK: Header row
            HStack(alignment: .firstTextBaseline, spacing: MV.S.s3) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(chartTitle(focused: focused, zoom: zoom).uppercased())
                        .font(.system(size: MV.FS.micro, weight: .semibold))
                        .tracking(1.1)
                        .foregroundStyle(MV.text2)

                    Text(peakLabel(
                        from: uploadFocused ? upSamples : downSamples,
                        now: now,
                        windowSeconds: zoom.windowSeconds
                    ))
                        .font(.system(size: MV.FS.micro).monospacedDigit())
                        .foregroundStyle(MV.text3)
                }

                Spacer(minLength: MV.S.s4)

                // Zoom chips
                HStack(spacing: 2) {
                    ForEach(ChartZoom.allCases) { z in
                        ZoomChip(label: z.label, isActive: zoom == z) {
                            zoom = z
                            tooltipInfo = nil
                        }
                    }
                }
            }
            .padding(.horizontal, MV.S.s4)
            .padding(.top, 10)
            .padding(.bottom, 4)

            // Legend
            HStack(spacing: 14) {
                LegendDot(
                    color: uploadFocused ? MV.accentSage.opacity(0.45) : MV.accentSage,
                    label: "DOWNLOAD",
                    dashed: uploadFocused
                )
                LegendDot(
                    color: uploadFocused ? MV.warning : MV.warning.opacity(0.75),
                    label: "UPLOAD",
                    dashed: !uploadFocused
                )
                Spacer()
            }
            .padding(.horizontal, MV.S.s4)
            .padding(.bottom, 4)

            // MARK: Chart area - fixed height to prevent viewport-eating
            ZStack(alignment: .topLeading) {
                GeometryReader { geo in
                    ZStack(alignment: .topLeading) {
                        Chart {
                            // Horizontal grid lines at 25/50/75/100% of yMax
                            ForEach(yTicks(max: maxY), id: \.self) { tick in
                                RuleMark(y: .value("Grid", tick))
                                    .lineStyle(StrokeStyle(lineWidth: 0.5))
                                    .foregroundStyle(MV.hairline)
                            }

                            // Avg horizontal dashed rule
                            if avgY > 0 {
                                RuleMark(y: .value("Avg", avgY))
                                    .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                                    .foregroundStyle(MV.text3)
                            }

                            // Upload: area fill + stroke (prominent when upload-focused,
                            // subordinated dashed line otherwise)
                            if !upSamples.isEmpty {
                                if uploadFocused {
                                    // Upload is the primary: area chart fill
                                    ForEach(upSamples) { sample in
                                        AreaMark(
                                            x: .value("Time", sample.timestamp),
                                            yStart: .value("Base", 0.0),
                                            yEnd: .value("Upload", Double(sample.bytesPerSec))
                                        )
                                        .foregroundStyle(
                                            LinearGradient(
                                                stops: [
                                                    .init(color: MV.warning.opacity(0.22), location: 0),
                                                    .init(color: MV.warning.opacity(0.06), location: 0.70),
                                                    .init(color: MV.warning.opacity(0.00), location: 1.0)
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .interpolationMethod(.catmullRom)
                                    }
                                    ForEach(upSamples) { sample in
                                        LineMark(
                                            x: .value("Time", sample.timestamp),
                                            y: .value("Upload", Double(sample.bytesPerSec))
                                        )
                                        .foregroundStyle(MV.warning)
                                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                                        .interpolationMethod(.catmullRom)
                                    }
                                } else {
                                    // Upload subordinated: thin area fill behind download
                                    ForEach(upSamples) { sample in
                                        AreaMark(
                                            x: .value("Time", sample.timestamp),
                                            yStart: .value("Base", 0.0),
                                            yEnd: .value("Upload", Double(sample.bytesPerSec))
                                        )
                                        .foregroundStyle(MV.warning.opacity(0.18))
                                        .interpolationMethod(.catmullRom)
                                    }
                                    ForEach(upSamples) { sample in
                                        LineMark(
                                            x: .value("Time", sample.timestamp),
                                            y: .value("Upload", Double(sample.bytesPerSec))
                                        )
                                        .foregroundStyle(MV.warning.opacity(0.7))
                                        .lineStyle(StrokeStyle(lineWidth: 1.0))
                                        .interpolationMethod(.catmullRom)
                                    }
                                }
                            }

                            // Download area fill + stroke
                            if !downSamples.isEmpty {
                                let downPrimary = !uploadFocused

                                ForEach(downSamples) { sample in
                                    AreaMark(
                                        x: .value("Time", sample.timestamp),
                                        yStart: .value("Base", 0.0),
                                        yEnd: .value("Download", Double(sample.bytesPerSec))
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            stops: [
                                                .init(color: MV.accentSage.opacity(downPrimary ? 0.22 : 0.10), location: 0),
                                                .init(color: MV.accentSage.opacity(downPrimary ? 0.06 : 0.02), location: 0.70),
                                                .init(color: MV.accentSage.opacity(0.00), location: 1.0)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .interpolationMethod(.catmullRom)
                                }

                                if downPrimary {
                                    // Download stroke (primary)
                                    ForEach(downSamples) { sample in
                                        LineMark(
                                            x: .value("Time", sample.timestamp),
                                            y: .value("Download", Double(sample.bytesPerSec))
                                        )
                                        .foregroundStyle(MV.accentSage)
                                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                                        .interpolationMethod(.catmullRom)
                                    }
                                } else {
                                    // Download dashed (subordinated when upload focused)
                                    ForEach(downSamples) { sample in
                                        LineMark(
                                            x: .value("Time", sample.timestamp),
                                            y: .value("Download", Double(sample.bytesPerSec))
                                        )
                                        .foregroundStyle(MV.accentSage.opacity(0.45))
                                        .lineStyle(StrokeStyle(lineWidth: 1.0, dash: [4, 3]))
                                        .interpolationMethod(.catmullRom)
                                    }
                                }
                            }

                            // Peak marker dot (double: outer sage, inner white)
                            if let peak = peakSmp {
                                PointMark(
                                    x: .value("Time", peak.timestamp),
                                    y: .value("Peak", Double(peak.bytesPerSec))
                                )
                                .symbolSize(CGSize(width: 8, height: 8))
                                .foregroundStyle(uploadFocused ? MV.warning : MV.accentSage)

                                PointMark(
                                    x: .value("Time", peak.timestamp),
                                    y: .value("Peak", Double(peak.bytesPerSec))
                                )
                                .symbolSize(CGSize(width: 4, height: 4))
                                .foregroundStyle(Color.white)
                            }

                            // Tooltip crosshair vertical rule
                            if let tip = tooltipInfo {
                                RuleMark(x: .value("Cursor", tip.timestamp))
                                    .lineStyle(StrokeStyle(lineWidth: 0.5))
                                    .foregroundStyle(MV.text3)
                            }
                        }
                        .chartXScale(domain: domain)
                        .chartYScale(domain: 0...maxY)
                        .chartXAxis(.hidden)
                        .chartYAxis(.hidden)
                        .chartLegend(.hidden)
                        .chartOverlay { proxy in
                            chartInteractionOverlay(proxy: proxy, geo: geo)
                        }
                        .background(Color.clear)

                        // Y-axis labels: right edge inside plot, 9pt mono text3
                        yAxisLabels(maxY: maxY, height: geo.size.height, width: geo.size.width)

                        // X-axis labels: bottom of canvas, clipped-safe
                        xAxisLabels(domain: domain, width: geo.size.width, height: geo.size.height)

                        // Avg label chip anchored at right edge
                        if avgY > 0 {
                            avgLabel(avgY: avgY, maxY: maxY, height: geo.size.height, width: geo.size.width)
                        }

                        // Peak leader line + label chip
                        if let peak = peakSmp {
                            peakLeader(
                                peak: peak,
                                maxY: maxY,
                                domain: domain,
                                height: geo.size.height,
                                width: geo.size.width
                            )
                        }

                        // Tooltip box
                        if let tip = tooltipInfo {
                            tooltipBox(tip: tip, totalWidth: geo.size.width)
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .onAppear { chartFrameWidth = geo.size.width }
                    .onChange(of: geo.size.width) { chartFrameWidth = $0 }
                }
            }
            .frame(height: chartHeight)
            .padding(.horizontal, MV.S.s2)
            .padding(.bottom, MV.S.s2)
        }
    }

    // MARK: Chart interaction overlay

    @ViewBuilder
    private func chartInteractionOverlay(proxy: ChartProxy, geo: GeometryProxy) -> some View {
        Rectangle()
            .fill(Color.clear)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let x = value.location.x
                        let date: Date
                        if let resolved: Date = proxy.value(atX: x) {
                            date = resolved
                        } else {
                            let fraction = max(0, min(1, x / geo.size.width))
                            let startInterval = now.addingTimeInterval(-Double(zoom.windowSeconds)).timeIntervalSinceReferenceDate
                            let endInterval   = now.timeIntervalSinceReferenceDate
                            let interpolated  = startInterval + fraction * (endInterval - startInterval)
                            date = Date(timeIntervalSinceReferenceDate: interpolated)
                        }

                        let dl = nearestSample(in: visibleDown(zoom: zoom), to: date)
                        let ul = nearestSample(in: visibleUp(zoom: zoom), to: date)

                        tooltipInfo = TooltipInfo(
                            timestamp: date,
                            downloadMBps: Double(dl?.bytesPerSec ?? 0) / 1_000_000,
                            uploadKBps: Double(ul?.bytesPerSec ?? 0) / 1_000,
                            xPosition: x
                        )
                    }
                    .onEnded { _ in
                        tooltipInfo = nil
                    }
            )
    }

    private func nearestSample(in samples: [NetworkSample], to date: Date) -> NetworkSample? {
        samples.min(by: {
            abs($0.timestamp.timeIntervalSince(date)) < abs($1.timestamp.timeIntervalSince(date))
        })
    }

    // MARK: Y-axis label overlay
    // Labels sit at the right edge inside the plot area, 4pt right padding

    @ViewBuilder
    private func yAxisLabels(maxY: Double, height: CGFloat, width: CGFloat) -> some View {
        let ticks = yTicks(max: maxY)
        ForEach(Array(ticks.enumerated()), id: \.offset) { idx, tick in
            let fraction = maxY > 0 ? (tick / maxY) : 0
            // y=0 is top in screen coords; data grows upward so invert
            let yPos = height * (1.0 - fraction)
            // Skip the topmost tick if it's within 10pt of the top edge to avoid clipping
            if yPos > 10 {
                Text(formatYTick(tick))
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(MV.text3)
                    .fixedSize()
                    .position(x: width - 4, y: max(8, yPos - 8))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    // MARK: X-axis label overlay
    // 8pt internal margin prevents edge clipping

    @ViewBuilder
    private func xAxisLabels(domain: ClosedRange<Date>, width: CGFloat, height: CGFloat) -> some View {
        let domainSpan = domain.upperBound.timeIntervalSince(domain.lowerBound)
        // Reserve 20pt on each side as safe margin so first/last labels don't clip
        let minX: CGFloat = 20
        let maxX: CGFloat = width - 20
        ForEach(zoom.xLabels, id: \.label) { item in
            let date = now.addingTimeInterval(Double(item.offsetSeconds))
            let fraction = domainSpan > 0
                ? (date.timeIntervalSince(domain.lowerBound) / domainSpan)
                : 0
            let rawX = width * CGFloat(fraction)
            // Clamp so label text stays within canvas
            let xPos = min(maxX, max(minX, rawX))
            Text(item.label)
                .font(.system(size: 9).monospacedDigit())
                .foregroundStyle(MV.text3)
                .fixedSize()
                .position(x: xPos, y: height - 8)
        }
    }

    // MARK: Avg label chip

    @ViewBuilder
    private func avgLabel(avgY: Double, maxY: Double, height: CGFloat, width: CGFloat) -> some View {
        let fraction = maxY > 0 ? (avgY / maxY) : 0
        let yPos = height * (1.0 - fraction)
        // Only draw if the label won't collide with bottom x-axis strip
        if yPos > 20 && yPos < height - 20 {
            Text("AVG \(formatYTick(avgY))")
                .font(.system(size: 9).monospacedDigit())
                .foregroundStyle(MV.text3)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(MV.tile)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .strokeBorder(MV.hairline, lineWidth: 1)
                        )
                )
                .fixedSize()
                .position(x: width - 52, y: max(10, yPos - 10))
        }
    }

    // MARK: Peak leader line + label chip

    @ViewBuilder
    private func peakLeader(
        peak: NetworkSample,
        maxY: Double,
        domain: ClosedRange<Date>,
        height: CGFloat,
        width: CGFloat
    ) -> some View {
        let domainSpan = domain.upperBound.timeIntervalSince(domain.lowerBound)
        let fraction = domainSpan > 0
            ? (peak.timestamp.timeIntervalSince(domain.lowerBound) / domainSpan)
            : 0.5
        let xPos = width * CGFloat(fraction)
        let yFrac = maxY > 0 ? (Double(peak.bytesPerSec) / maxY) : 0
        let dotY  = height * (1.0 - yFrac)

        // Only render leader if peak dot is not at the very top edge
        if dotY > 28 {
            let labelY = max(14, dotY - 24)
            let accentColor = uploadFocused ? MV.warning : MV.accentSage

            ZStack {
                // Vertical leader line from label chip down to dot
                Path { p in
                    p.move(to: CGPoint(x: xPos, y: labelY + 10))
                    p.addLine(to: CGPoint(x: xPos, y: dotY - 5))
                }
                .stroke(accentColor.opacity(0.4), lineWidth: 0.5)

                // Label chip
                Text("\(formatYTick(Double(peak.bytesPerSec))) · \(DateFormatter.hmm.string(from: peak.timestamp))")
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(MV.text2)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(MV.tile)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .strokeBorder(accentColor.opacity(0.35), lineWidth: 1)
                            )
                    )
                    .fixedSize()
                    .position(
                        x: min(max(44, xPos), width - 44),
                        y: labelY
                    )
            }
        }
    }

    // MARK: Tooltip box

    @ViewBuilder
    private func tooltipBox(tip: TooltipInfo, totalWidth: CGFloat) -> some View {
        let boxWidth: CGFloat = 130
        let flipThreshold: CGFloat = totalWidth - boxWidth - 12
        let xOffset: CGFloat = tip.xPosition > flipThreshold
            ? tip.xPosition - boxWidth - 8
            : tip.xPosition + 8

        VStack(alignment: .leading, spacing: 3) {
            Text(DateFormatter.hmmss.string(from: tip.timestamp))
                .font(.system(size: 9).monospacedDigit())
                .foregroundStyle(MV.text3)

            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(MV.accentSage)
                    .frame(width: 6, height: 6)
                Text(String(format: "%.2f MB/s", tip.downloadMBps))
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(MV.accentSage)
            }

            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(MV.warning.opacity(0.75))
                    .frame(width: 6, height: 6)
                Text(String(format: "%.0f KB/s", tip.uploadKBps))
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(MV.warning)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(MV.tile)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(MV.hairlineStrong, lineWidth: 1)
                )
        )
        .frame(width: boxWidth)
        .position(x: xOffset + boxWidth / 2, y: 36)
    }
}

// MARK: - Zoom chip

private struct ZoomChip: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label.uppercased())
                .font(.system(size: 8.5, weight: .medium))
                .tracking(0.6)
                .foregroundStyle(isActive ? MV.accentSage : MV.text2)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isActive ? MV.accentSage.opacity(0.07) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(
                            isActive ? MV.accentSage.opacity(0.28) : MV.hairline,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Legend dot

private struct LegendDot: View {
    let color: Color
    let label: String
    var dashed: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            if dashed {
                // Dashed swatch rendered as two short rectangles with a gap
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 1)
                        .fill(color)
                        .frame(width: 5, height: 2)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(color)
                        .frame(width: 3, height: 2)
                }
                .frame(width: 10)
            } else {
                RoundedRectangle(cornerRadius: 1)
                    .fill(color)
                    .frame(width: 10, height: 2)
            }
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .tracking(0.6)
                .foregroundStyle(MV.text3)
        }
    }
}

// MARK: - Preview

#Preview("NetworkBigChart - 1h burst") {
    // Generate 360 fake samples at 10s intervals (60 min window)
    let baseDate = Date()
    var downPoints: [NetworkSample] = []
    var upPoints: [NetworkSample] = []

    for i in 0..<360 {
        let t = baseDate.addingTimeInterval(Double(i - 359) * 10)

        // Simulate a burst around the 200-250 sample range
        let burstFactor: Double
        if i > 200 && i < 260 {
            burstFactor = 1.0 + Double(i - 200) / 30
        } else {
            burstFactor = 1.0
        }
        let noise = Double.random(in: 0.6...1.4)
        let baseDL: Double = 4_500_000
        let dlBps = UInt64(baseDL * burstFactor * noise)

        let ulNoise = Double.random(in: 0.5...1.3)
        let ulBps = UInt64(800_000 * ulNoise)

        downPoints.append(NetworkSample(timestamp: t, bytesPerSec: dlBps))
        upPoints.append(NetworkSample(timestamp: t, bytesPerSec: ulBps))
    }

    let fakeSeries = NetworkChartSeries(down: downPoints, up: upPoints)

    return NetworkBigChart(series: fakeSeries, focused: .downloadNow)
        .frame(width: 900, height: 260)
        .background(MV.tile)
}

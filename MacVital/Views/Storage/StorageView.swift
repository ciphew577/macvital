// MacVital/Views/Storage/StorageView.swift
// Disk tab · pixel-perfect match of mockups/disk-final.html
// Sections: drive tabs · volume hero (donut) · space breakdown · I/O activity
//           R/W chart · NVMe SMART (16 rows) · top I/O processes · history
import SwiftUI
import Charts

// MARK: - Exact hex colour palette (matches disk-final.html :root vars)

private enum DiskColors {
    static let bg       = Color(red: 0.110, green: 0.110, blue: 0.118)  // #1C1C1E
    static let bg2      = Color(red: 0.173, green: 0.173, blue: 0.180)  // #2C2C2E
    static let bg3      = Color(red: 0.228, green: 0.228, blue: 0.235)  // #3A3A3C
    static let text     = Color.white.opacity(0.85)
    static let text2    = Color.white.opacity(0.55)
    static let text3    = Color.white.opacity(0.35)
    static let blue     = Color(red: 0.039, green: 0.518, blue: 1.000)  // #0A84FF
    static let green    = Color(red: 0.196, green: 0.843, blue: 0.294)  // #32D74B
    static let orange   = Color(red: 1.000, green: 0.624, blue: 0.039)  // #FF9F0A
    static let red      = Color(red: 1.000, green: 0.271, blue: 0.227)  // #FF453A
    static let gray     = Color(red: 0.388, green: 0.388, blue: 0.400)  // #636366
    static let gray2    = Color(red: 0.282, green: 0.282, blue: 0.290)  // #48484A
    static let separator = Color.white.opacity(0.08)

    // Space breakdown segment colours (matches HTML storage-bar)
    static let spaceApps      = blue
    static let spaceDocuments = orange
    static let spacePhotos    = green
    static let spaceSystem    = gray
    static let spaceOther     = gray2
}

// MARK: - Local data types

private struct IOPoint: Identifiable {
    let id: Int
    let read: Double    // MB/s
    let write: Double   // MB/s
}

private struct SpaceCategory {
    let name: String
    let bytes: UInt64
    let color: Color
}

private struct DiskProcess: Identifiable {
    let id = UUID()
    let rank: Int
    let name: String
    let icon: String     // SF Symbol name
    let readBytesPerSec: UInt64
    let writeBytesPerSec: UInt64
}

private enum HistoryRange: String, CaseIterable {
    case oneHour   = "1h"
    case oneDay    = "24h"
    case sevenDay  = "7d"
    case thirtyDay = "30d"
}

// MARK: - StorageView

struct StorageView: View {
    @Environment(AppState.self) private var appState

    @AppStorage("com.macvital.storage.variant") private var storageVariantRaw: Int = StorageVariant.threeCellRow.rawValue

    @State private var ioHistory: [IOPoint] = []
    @State private var selectedDriveIndex = 0
    @State private var selectedHistoryRange: HistoryRange = .oneHour
    @State private var sessionReadBytes: UInt64  = 0
    @State private var sessionWriteBytes: UInt64 = 0
    @State private var isActive = false   // pause animations when hidden

    // MARK: Derived

    private var storage: StorageData? { appState.monitor.storage }
    private var volumes: [Volume] { storage?.volumes ?? [] }
    private var selectedVolume: Volume? {
        guard !volumes.isEmpty else { return nil }
        return volumes[min(selectedDriveIndex, volumes.count - 1)]
    }
    private var selectedVolumePct: Double {
        guard let vol = selectedVolume, vol.totalBytes > 0 else { return 0 }
        return Double(vol.usedBytes) / Double(vol.totalBytes)
    }

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Drive selector tabs · always visible
                driveSelectorTabs

                VStack(alignment: .leading, spacing: 16) {
                    truthTableVariantSection
                    spaceBreakdownSection
                    ioActivitySection
                    smartHealthSection
                    topProcessesSection
                    historySection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .padding(.bottom, 24)
            }
        }
        .background(DiskColors.bg)
        .onAppear {
            isActive = true
            seedHistory()
        }
        .onDisappear { isActive = false }
        .onChange(of: storage?.readBytesPerSec) { _, newVal in
            appendIOPoint(read: newVal ?? 0, write: storage?.writeBytesPerSec ?? 0)
            sessionReadBytes += (newVal ?? 0) * 30
        }
        .onChange(of: storage?.writeBytesPerSec) { _, newVal in
            sessionWriteBytes += (newVal ?? 0) * 30
        }
    }

    // MARK: - Drive Selector Tabs

    private var driveSelectorTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                if volumes.isEmpty {
                    // Placeholder tab shown while storage data loads
                    VStack(spacing: 0) {
                        Text("Macintosh HD (n/a)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(DiskColors.blue)
                            .padding(.vertical, 7)
                            .padding(.horizontal, 14)
                        Rectangle()
                            .frame(height: 2)
                            .foregroundStyle(DiskColors.blue)
                    }
                } else {
                    ForEach(Array(volumes.enumerated()), id: \.offset) { idx, vol in
                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) { selectedDriveIndex = idx }
                        } label: {
                            VStack(spacing: 0) {
                                Text("\(vol.name) (\(ByteFormatter.format(vol.totalBytes)))")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(idx == selectedDriveIndex ? DiskColors.blue : DiskColors.text2)
                                    .padding(.vertical, 7)
                                    .padding(.horizontal, 14)
                                Rectangle()
                                    .frame(height: 2)
                                    .foregroundStyle(idx == selectedDriveIndex ? DiskColors.blue : Color.clear)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 6)
        }
        .overlay(alignment: .bottom) { Divider().background(DiskColors.separator) }
        .background(DiskColors.bg)
    }

    // MARK: - Truth-Table Variant Section (5 swappable layouts via @AppStorage)

    private var selectedStorageVariant: StorageVariant {
        StorageVariant(rawValue: storageVariantRaw) ?? .threeCellRow
    }

    private var truthTriad: StorageTruthTriad? {
        guard let mp = selectedVolume?.mountPoint else { return nil }
        return StorageTruthReader.read(mountPoint: mp)
    }

    private var truthTableVariantSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                sectionLabel("Storage Truth-Table")
                Spacer()
                variantPicker
            }
            switch selectedStorageVariant {
            case .threeCellRow:    StorageTruthTableThreeCellRow(triad: truthTriad)
            case .nestedBars:      StorageTruthTableNestedBars(triad: truthTriad)
            case .stairCards:      StorageTruthTableStairCards(triad: truthTriad)
            case .numberLine:      StorageTruthTableNumberLine(triad: truthTriad)
            case .nestedCircles:   StorageTruthTableNestedCircles(triad: truthTriad)
            }
        }
    }

    private var variantPicker: some View {
        HStack(spacing: 2) {
            ForEach(StorageVariant.allCases) { variant in
                Button {
                    storageVariantRaw = variant.rawValue
                } label: {
                    Text(variant.title)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(variant.rawValue == storageVariantRaw ? DiskColors.text : DiskColors.text2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            variant.rawValue == storageVariantRaw ? DiskColors.bg3 : Color.clear,
                            in: RoundedRectangle(cornerRadius: 5)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(DiskColors.bg2, in: RoundedRectangle(cornerRadius: 7))
    }

    // MARK: - Volume Hero  (donut + stats grid + badges)

    private var volumeHeroSection: some View {
        HStack(alignment: .center, spacing: 24) {
            donutRing

            VStack(alignment: .leading, spacing: 0) {
                // 3-column stats grid
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                    alignment: .leading,
                    spacing: 12
                ) {
                    if let vol = selectedVolume {
                        volumeStat(value: ByteFormatter.format(vol.usedBytes),  label: "Used")
                        volumeStat(value: ByteFormatter.format(vol.freeBytes),  label: "Free")
                        volumeStat(value: ByteFormatter.format(vol.totalBytes), label: "Total")
                    } else {
                        volumeStat(value: "n/a", label: "Used")
                        volumeStat(value: "n/a", label: "Free")
                        volumeStat(value: "n/a", label: "Total")
                    }
                }

                // Badges row
                HStack(spacing: 6) {
                    if let vol = selectedVolume, !vol.fileSystem.isEmpty {
                        diskBadge(vol.fileSystem,        bg: DiskColors.blue.opacity(0.15),  fg: DiskColors.blue)
                    }
                    diskBadge("NVMe",                    bg: DiskColors.gray.opacity(0.25),  fg: DiskColors.gray)
                }
                .padding(.top, 12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(DiskColors.bg2, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(DiskColors.separator, lineWidth: 1))
    }

    private var donutRing: some View {
        ZStack {
            let pct = selectedVolumePct
            let circumference: Double = 2 * .pi * 38  // r=38 → 238.76
            let usedArc   = pct * circumference
            let freeArc   = max(0, circumference - usedArc)

            // Track ring
            Circle()
                .stroke(DiskColors.bg3, lineWidth: 10)
                .frame(width: 100, height: 100)

            // Used arc (blue, solid)
            Circle()
                .trim(from: 0, to: pct)
                .stroke(
                    DiskColors.blue,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .frame(width: 100, height: 100)
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: pct)

            // Free arc (dim blue)
            if freeArc > 0 {
                Circle()
                    .trim(from: pct, to: 1.0)
                    .stroke(
                        DiskColors.blue.opacity(0.12),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
            }

            // Center label
            VStack(spacing: 2) {
                Text("\(Int(pct * 100))%")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(DiskColors.text)
                    .monospacedDigit()
                Text("Used")
                    .font(.system(size: 10))
                    .foregroundStyle(DiskColors.text3)
                    .kerning(0.2)
            }
        }
        .frame(width: 100, height: 100)
        .fixedSize()
    }

    private func volumeStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DiskColors.text)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 10.5))
                .foregroundStyle(DiskColors.text3)
        }
    }

    private func diskBadge(_ label: String, bg: Color, fg: Color) -> some View {
        Text(label)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(bg, in: RoundedRectangle(cornerRadius: 4))
            .foregroundStyle(fg)
            .kerning(0.2)
    }

    // MARK: - Space Breakdown Bar

    private var spaceBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Space Breakdown")

            // Segmented bar · 10 px tall, rounded
            GeometryReader { geo in
                HStack(spacing: 0) {
                    let total = Double(selectedVolume?.totalBytes ?? 1)
                    ForEach(Array(spaceCategories.enumerated()), id: \.offset) { _, cat in
                        let w = geo.size.width * (Double(cat.bytes) / total)
                        Rectangle()
                            .fill(cat.color)
                            .frame(width: max(0, w), height: 10)
                    }
                    // Free space segment
                    if let vol = selectedVolume, vol.totalBytes > 0 {
                        let usedFraction = Double(vol.usedBytes) / Double(vol.totalBytes)
                        let freeW = max(0, geo.size.width * (1.0 - usedFraction))
                        ZStack {
                            Rectangle()
                                .fill(DiskColors.bg)
                            Rectangle()
                                .strokeBorder(DiskColors.separator, lineWidth: 1)
                        }
                        .frame(width: freeW, height: 10)
                    }
                }
                .frame(height: 10)
                .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .frame(height: 10)
            .padding(.top, 8)
            .padding(.bottom, 10)

            // Legend
            let allItems: [(Color, String, UInt64)] = {
                var items: [(Color, String, UInt64)] = spaceCategories.map { ($0.color, $0.name, $0.bytes) }
                if let vol = selectedVolume {
                    items.append((DiskColors.bg3, "Free", vol.freeBytes))
                }
                return items
            }()

            FlowLegend(items: allItems)
        }
    }

    private var spaceCategories: [SpaceCategory] {
        guard let vol = selectedVolume, vol.usedBytes > 0 else {
            return fallbackSpaceCategories(used: 0)
        }
        // Use real breakdown from StorageReader when available
        if let bd = storage?.spaceBreakdown {
            return [
                SpaceCategory(name: "Apps",      bytes: bd.appsBytes,      color: DiskColors.spaceApps),
                SpaceCategory(name: "Documents", bytes: bd.documentsBytes, color: DiskColors.spaceDocuments),
                SpaceCategory(name: "Photos",    bytes: bd.photosBytes,    color: DiskColors.spacePhotos),
                SpaceCategory(name: "System",    bytes: bd.systemBytes,    color: DiskColors.spaceSystem),
                SpaceCategory(name: "Other",     bytes: bd.otherBytes,     color: DiskColors.spaceOther),
            ]
        }
        return fallbackSpaceCategories(used: vol.usedBytes)
    }

    /// Fallback until first real scan completes · shows total used as a single segment
    private func fallbackSpaceCategories(used: UInt64) -> [SpaceCategory] {
        guard used > 0 else { return [] }
        return [
            SpaceCategory(name: "Used (scanning\u{2026})", bytes: used, color: DiskColors.spaceApps),
        ]
    }

    // MARK: - I/O Activity

    private var ioActivitySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                sectionLabel("I/O Activity")
                if volumes.count > 1 {
                    Text("Total disk activity (all volumes)")
                        .font(.system(size: 10))
                        .foregroundStyle(DiskColors.text3)
                }
            }
            .padding(.bottom, 10)

            // Speed cards · Read (blue) / Write (red)
            HStack(spacing: 14) {
                ioSpeedCard(
                    speed: diskSpeedString(storage?.readBytesPerSec ?? 0),
                    label: "Read throughput",
                    color: DiskColors.blue,
                    isActive: (storage?.readBytesPerSec ?? 0) > 0
                )
                ioSpeedCard(
                    speed: diskSpeedString(storage?.writeBytesPerSec ?? 0),
                    label: "Write throughput",
                    color: DiskColors.red,
                    isActive: (storage?.writeBytesPerSec ?? 0) > 0
                )
            }
            .padding(.bottom, 12)

            // Sub-stats 4-column grid
            HStack(spacing: 0) {
                ioSubStat(
                    value: ByteFormatter.format(sessionReadBytes),
                    label: "Session Read",
                    valueColor: DiskColors.blue
                )
                Divider().frame(height: 44).background(DiskColors.separator)
                ioSubStat(
                    value: ByteFormatter.format(sessionWriteBytes),
                    label: "Session Written",
                    valueColor: DiskColors.red
                )
                Divider().frame(height: 44).background(DiskColors.separator)
                ioSubStat(value: iopsDisplay,          label: "IOPS Read / Write", valueColor: DiskColors.text)
                Divider().frame(height: 44).background(DiskColors.separator)
                ioSubStat(value: kbPerTransferDisplay, label: "KB per Transfer",   valueColor: DiskColors.text)
            }
            .background(DiskColors.bg2, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(DiskColors.separator, lineWidth: 1))
            .padding(.bottom, 12)

            // R/W Chart · 60-second window
            rwChartSection
        }
    }

    private func ioSpeedCard(speed: String, label: String, color: Color, isActive: Bool) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(isActive ? color : DiskColors.bg3)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(speed)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(color)
                    .monospacedDigit()
                Text(label)
                    .font(.system(size: 10.5))
                    .foregroundStyle(DiskColors.text3)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(DiskColors.bg2, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(DiskColors.separator, lineWidth: 1))
    }

    private func ioSubStat(value: String, label: String, valueColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(valueColor)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(DiskColors.text3)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static let decimalFmt: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()

    private var iopsDisplay: String {
        guard let s = storage else { return "n/a" }
        let rIOPS = s.readBytesPerSec  > 0 ? Int(Double(s.readBytesPerSec)  / 4_096) : 0
        let wIOPS = s.writeBytesPerSec > 0 ? Int(Double(s.writeBytesPerSec) / 4_096) : 0
        guard rIOPS > 0 || wIOPS > 0 else { return "n/a" }
        let r = Self.decimalFmt.string(from: NSNumber(value: rIOPS)) ?? "\(rIOPS)"
        let w = Self.decimalFmt.string(from: NSNumber(value: wIOPS)) ?? "\(wIOPS)"
        return "\(r) / \(w)"
    }

    private var kbPerTransferDisplay: String {
        guard let s = storage else { return "n/a" }
        let total = s.readBytesPerSec + s.writeBytesPerSec
        guard total > 0 else { return "n/a" }
        let iops = max(1, Int(Double(total) / 4_096))
        let kbpt = Double(total) / 1_024.0 / Double(iops)
        return String(format: "%.1f KB/t", kbpt)
    }

    // MARK: - Byte formatting

    private func diskSpeedString(_ bytesPerSec: UInt64) -> String {
        let mb = Double(bytesPerSec) / 1_048_576
        if mb >= 1_000 { return String(format: "%.1f GB/s", mb / 1_000) }
        if mb >= 1     { return String(format: "%.0f MB/s", mb) }
        let kb = Double(bytesPerSec) / 1_024
        if kb >= 1     { return String(format: "%.0f KB/s", kb) }
        return "0 KB/s"
    }

    // MARK: - R/W Chart (60s)

    private var rwChartSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: title + legend
            HStack {
                Text("Read / Write · 60s")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DiskColors.text)
                Spacer()
                HStack(spacing: 14) {
                    chartLegendLine(color: DiskColors.blue,  label: "Read")
                    chartLegendLine(color: DiskColors.red,   label: "Write")
                }
            }
            .padding(.bottom, 10)

            // Chart
            if ioHistory.isEmpty {
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 70)
            } else {
                Chart {
                    ForEach(ioHistory) { point in
                        // Write fill (draw first, below read)
                        AreaMark(
                            x: .value("t", point.id),
                            y: .value("MB/s", point.write)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [DiskColors.red.opacity(0.06), DiskColors.red.opacity(0)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)

                        LineMark(
                            x: .value("t", point.id),
                            y: .value("MB/s", point.write)
                        )
                        .foregroundStyle(DiskColors.red)
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                        .interpolationMethod(.catmullRom)

                        // Read fill
                        AreaMark(
                            x: .value("t", point.id),
                            y: .value("MB/s", point.read)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [DiskColors.blue.opacity(0.10), DiskColors.blue.opacity(0)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)

                        LineMark(
                            x: .value("t", point.id),
                            y: .value("MB/s", point.read)
                        )
                        .foregroundStyle(DiskColors.blue)
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 70)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background(DiskColors.bg2, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(DiskColors.separator, lineWidth: 1))
    }

    private func chartLegendLine(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 1)
                .fill(color)
                .frame(width: 14, height: 2)
            Text(label)
                .font(.system(size: 10.5))
                .foregroundStyle(DiskColors.text2)
        }
    }

    // MARK: - NVMe SMART Health

    private var smartHealthSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: label + badge
            HStack(alignment: .center) {
                sectionLabel("NVMe SMART Health")
                Spacer()
                let pct = Int(storage?.healthPercent ?? 97)
                Text("Healthy \(pct)%")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(smartBadgeBg(pct: pct), in: RoundedRectangle(cornerRadius: 5))
                    .foregroundStyle(smartBadgeFg(pct: pct))
            }
            .padding(.bottom, 10)

            // SMART list card
            VStack(spacing: 0) {
                let attrs = storage?.smartAttributes ?? []
                if attrs.isEmpty {
                    ForEach(Array(smartPlaceholders.enumerated()), id: \.offset) { idx, ph in
                        SmartPlaceholderRow(info: ph)
                        if idx < smartPlaceholders.count - 1 {
                            Divider()
                                .background(DiskColors.separator)
                                .padding(.leading, 14)
                        }
                    }
                } else {
                    ForEach(Array(attrs.prefix(16).enumerated()), id: \.offset) { idx, attr in
                        SmartLiveRow(attribute: attr)
                        if idx < min(attrs.count, 16) - 1 {
                            Divider()
                                .background(DiskColors.separator)
                                .padding(.leading, 14)
                        }
                    }
                }

                // Footer (no assumed badges; real capabilities shown via SMART attributes above)
                Color.clear.frame(height: 4)
            }
            .background(DiskColors.bg2, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(DiskColors.separator, lineWidth: 1))
        }
    }

    private func smartBadgeBg(pct: Int) -> Color {
        if pct >= 90 { return DiskColors.green.opacity(0.15) }
        if pct >= 60 { return DiskColors.orange.opacity(0.15) }
        return DiskColors.red.opacity(0.15)
    }
    private func smartBadgeFg(pct: Int) -> Color {
        if pct >= 90 { return DiskColors.green }
        if pct >= 60 { return DiskColors.orange }
        return DiskColors.red
    }

    // MARK: - Top I/O Processes

    private var topProcessesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Top I/O Processes")
                .padding(.bottom, 10)

            VStack(spacing: 0) {
                // Header row
                HStack(spacing: 0) {
                    Color.clear.frame(width: 18, height: 1)   // rank spacer
                    Color.clear.frame(width: 28, height: 1)   // icon spacer
                    Text("PROCESS")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(DiskColors.text3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .kerning(0.4)
                    Text("READ")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(DiskColors.blue)
                        .frame(width: 80, alignment: .trailing)
                        .kerning(0.4)
                    Text("WRITE")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(DiskColors.red)
                        .frame(width: 80, alignment: .trailing)
                        .kerning(0.4)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.02))
                .overlay(alignment: .bottom) {
                    Divider().background(DiskColors.separator)
                }

                // Per-process I/O tracking requires a background daemon, not yet implemented
                Text("Per-process I/O data unavailable")
                    .font(.system(size: 12))
                    .foregroundStyle(DiskColors.text3)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 14)
            }
            .background(DiskColors.bg2, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(DiskColors.separator, lineWidth: 1))
        }
    }

    // MARK: - Disk Usage History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                sectionLabel("Disk Usage History")
                Spacer()
                // Time range toggles
                HStack(spacing: 2) {
                    ForEach(HistoryRange.allCases, id: \.self) { range in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedHistoryRange = range
                            }
                        } label: {
                            Text(range.rawValue)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(
                                    selectedHistoryRange == range ? DiskColors.text : DiskColors.text2
                                )
                                .padding(.horizontal, 10)
                                .padding(.vertical, 3)
                                .background(
                                    selectedHistoryRange == range ? DiskColors.bg3 : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 5)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(DiskColors.bg2, in: RoundedRectangle(cornerRadius: 7))
            }
            .padding(.bottom, 10)

            // History chart card
            VStack(alignment: .leading, spacing: 0) {
                let data = historyChartData(for: selectedHistoryRange)
                if data.isEmpty {
                    Rectangle().fill(Color.clear).frame(height: 60)
                } else {
                    Chart {
                        ForEach(data) { point in
                            AreaMark(
                                x: .value("t", point.id),
                                y: .value("%", point.read)   // read = usage %
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [DiskColors.blue.opacity(0.10), DiskColors.blue.opacity(0)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.catmullRom)

                            LineMark(
                                x: .value("t", point.id),
                                y: .value("%", point.read)
                            )
                            .foregroundStyle(DiskColors.blue)
                            .lineStyle(StrokeStyle(lineWidth: 1.5))
                            .interpolationMethod(.catmullRom)
                        }
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis {
                        AxisMarks(position: .leading, values: [25, 50, 75, 100]) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(Color.white.opacity(0.06))
                            AxisValueLabel {
                                if let v = value.as(Int.self) {
                                    Text("\(v)%")
                                        .font(.system(size: 9))
                                        .foregroundStyle(DiskColors.text3)
                                }
                            }
                        }
                    }
                    .chartYScale(domain: 0...100)
                    .frame(height: 60)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)
            .background(DiskColors.bg2, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(DiskColors.separator, lineWidth: 1))
        }
    }

    // MARK: - Shared label

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(DiskColors.text3)
            .kerning(0.7)
    }

    // MARK: - Data helpers

    private func seedHistory() {
        // Start with empty history; real data accumulates from live I/O readings
        guard ioHistory.isEmpty else { return }
        // No fake seed data; chart fills as real readings arrive
    }

    private func appendIOPoint(read: UInt64, write: UInt64) {
        let r = Double(read)  / 1_048_576
        let w = Double(write) / 1_048_576
        let nextID = (ioHistory.last?.id ?? -1) + 1
        ioHistory.append(IOPoint(id: nextID, read: r, write: w))
        if ioHistory.count > 60 { ioHistory.removeFirst() }
    }

    /// History chart · shows live I/O history for 1h; longer ranges unavailable without persistent storage
    private func historyChartData(for range: HistoryRange) -> [IOPoint] {
        switch range {
        case .oneHour:
            // Show real accumulated I/O history
            return ioHistory
        case .oneDay, .sevenDay, .thirtyDay:
            // Longer history ranges require persistent data logging, not yet implemented
            return []
        }
    }

    /// Top I/O processes · not available without a background daemon; show empty state
    private var topProcesses: [DiskProcess] { [] }

    // SMART placeholder tuples: (name, value, note, status, showBar, barPct)
    private typealias SmartInfo = (name: String, value: String, note: String, status: HealthStatus, showBar: Bool, barPct: Double)

    private var smartPlaceholders: [SmartInfo] {
        let hp = storage?.healthPercent ?? 0
        let hasHealth = hp > 0
        return [
            (name: "Health Score",          value: hasHealth ? "\(Int(hp))%" : "-",  note: "",                              status: hp >= 90 ? .good : hp >= 60 ? .warning : .critical, showBar: hasHealth, barPct: hp / 100),
            (name: "Temperature",           value: "-",  note: "Waiting for SMART data",    status: .good,    showBar: false, barPct: 0),
            (name: "Available Spare",       value: "-",  note: "",                          status: .good,    showBar: false, barPct: 0),
            (name: "Wear Level",            value: "-",  note: "",                          status: .good,    showBar: false, barPct: 0),
            (name: "Power Cycles",          value: "-",  note: "",                          status: .good,    showBar: false, barPct: 0),
            (name: "Power-On Hours",        value: "-",  note: "",                          status: .good,    showBar: false, barPct: 0),
            (name: "Lifetime Read",         value: "-",  note: "",                          status: .good,    showBar: false, barPct: 0),
            (name: "Lifetime Written",      value: "-",  note: "",                          status: .good,    showBar: false, barPct: 0),
            (name: "Unsafe Shutdowns",      value: "-",  note: "",                          status: .good,    showBar: false, barPct: 0),
            (name: "Media Errors",          value: "-",  note: "",                          status: .good,    showBar: false, barPct: 0),
            (name: "Error Log Entries",     value: "-",  note: "",                          status: .good,    showBar: false, barPct: 0),
            (name: "Critical Warning",      value: "-",  note: "",                          status: .good,    showBar: false, barPct: 0),
        ]
    }
}

// MARK: - SmartLiveRow  (real SMARTAttribute data)

private struct SmartLiveRow: View {
    let attribute: SMARTAttribute
    @State private var showInfo = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(dotColor)
                .frame(width: 7, height: 7)
                .padding(.leading, 14)

            Text(attribute.name)
                .font(.system(size: 12))
                .foregroundStyle(DiskColors.text2)

            // Info icon · shows description + threshold on hover/click
            if !attribute.explanation.isEmpty || (attribute.threshold != "-" && !attribute.threshold.isEmpty) {
                Button {
                    showInfo.toggle()
                } label: {
                    Text("(i)")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(DiskColors.text3)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showInfo, arrowEdge: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        if !attribute.explanation.isEmpty {
                            Text(attribute.explanation)
                                .font(.system(size: 11.5))
                                .foregroundStyle(.primary)
                        }
                        if attribute.threshold != "-" && !attribute.threshold.isEmpty {
                            Text("Threshold: \(attribute.threshold)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: 260, alignment: .leading)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                if isPercent(attribute.rawValue) {
                    ThresholdBar(fill: barColor, pct: parsePct(attribute.rawValue))
                }

                Text(attribute.rawValue)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DiskColors.text)
                    .monospacedDigit()
            }
            .padding(.trailing, 14)
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }

    private var dotColor: Color {
        switch attribute.status {
        case .good:    return DiskColors.green
        case .warning: return DiskColors.orange
        case .critical: return DiskColors.red
        case .unknown:  return Color.clear
        }
    }
    private var barColor: Color {
        switch attribute.status {
        case .good:     return DiskColors.green
        case .warning:  return DiskColors.orange
        case .critical: return DiskColors.red
        case .unknown:  return DiskColors.blue
        }
    }
    private func isPercent(_ v: String) -> Bool { v.hasSuffix("%") }
    private func parsePct(_ v: String) -> Double {
        let s = v.replacingOccurrences(of: "%", with: "")
        return min(1, max(0, (Double(s) ?? 0) / 100))
    }
}

// MARK: - SmartPlaceholderRow  (placeholder when no SMART data yet)

private struct SmartPlaceholderRow: View {
    let info: (name: String, value: String, note: String, status: HealthStatus, showBar: Bool, barPct: Double)

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(dotColor)
                .frame(width: 7, height: 7)
                .padding(.leading, 14)

            Text(info.name)
                .font(.system(size: 12))
                .foregroundStyle(DiskColors.text2)
                .frame(minWidth: 160, alignment: .leading)

            Spacer()

            HStack(spacing: 8) {
                Text(info.value)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DiskColors.text)
                    .monospacedDigit()

                if info.showBar {
                    ThresholdBar(fill: barColor, pct: info.barPct)
                }

                if !info.note.isEmpty {
                    Text(info.note)
                        .font(.system(size: 10.5))
                        .foregroundStyle(DiskColors.text3)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 14)
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }

    private var dotColor: Color {
        switch info.status {
        case .good:     return DiskColors.green
        case .warning:  return DiskColors.orange
        case .critical: return DiskColors.red
        }
    }
    private var barColor: Color {
        switch info.status {
        case .good:     return DiskColors.green
        case .warning:  return DiskColors.orange
        case .critical: return DiskColors.red
        }
    }
}

// MARK: - Shared sub-views

/// Mini threshold bar (4 px tall, track + fill)
private struct ThresholdBar: View {
    let fill: Color
    let pct: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2).fill(DiskColors.bg3)
                RoundedRectangle(cornerRadius: 2)
                    .fill(fill)
                    .frame(width: geo.size.width * max(0, min(1, pct)))
            }
        }
        .frame(width: 60, height: 4)
    }
}

/// Horizontal wrapping legend (flows items in a single scrollable HStack)
private struct FlowLegend: View {
    let items: [(Color, String, UInt64)]

    var body: some View {
        // Use a wrapping layout via LazyVGrid rows of 3
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 18), GridItem(.flexible(), spacing: 18), GridItem(.flexible())],
            alignment: .leading,
            spacing: 10
        ) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                let (color, name, bytes) = item
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: 8, height: 8)
                    Text(name)
                        .font(.system(size: 11))
                        .foregroundStyle(DiskColors.text2)
                    Spacer(minLength: 0)
                    Text(ByteFormatter.format(bytes))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(DiskColors.text)
                }
            }
        }
    }
}

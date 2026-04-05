import SwiftUI

enum StorageVariant: Int, CaseIterable, Identifiable {
    case threeCellRow = 0
    case nestedBars = 1
    case stairCards = 2
    case numberLine = 3
    case nestedCircles = 4

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .threeCellRow:   return "Three-Cell Row"
        case .nestedBars:     return "Nested Bars"
        case .stairCards:     return "Stair Cards"
        case .numberLine:     return "Number Line"
        case .nestedCircles:  return "Nested Circles"
        }
    }
}

enum StorageVariantPalette {
    static let bg        = Color(red: 0.059, green: 0.059, blue: 0.063)
    static let tile      = Color(red: 0.086, green: 0.090, blue: 0.102)
    static let tileH     = Color(red: 0.102, green: 0.106, blue: 0.118)
    static let tileDeep  = Color(red: 0.071, green: 0.075, blue: 0.086)
    static let hair      = Color.white.opacity(0.055)
    static let hairS     = Color.white.opacity(0.10)
    static let hairLine  = Color.white.opacity(0.16)
    static let text1     = Color(red: 0.910, green: 0.902, blue: 0.890)
    static let text2     = Color(red: 0.910, green: 0.902, blue: 0.890).opacity(0.62)
    static let text3     = Color(red: 0.910, green: 0.902, blue: 0.890).opacity(0.40)
    static let text4     = Color(red: 0.910, green: 0.902, blue: 0.890).opacity(0.22)
    static let text5     = Color(red: 0.910, green: 0.902, blue: 0.890).opacity(0.14)
    static let slate     = Color(red: 0.482, green: 0.584, blue: 0.753)
    static let slateSoft = Color(red: 0.482, green: 0.584, blue: 0.753).opacity(0.18)
    static let slateFill = Color(red: 0.482, green: 0.584, blue: 0.753).opacity(0.32)
    static let sage      = Color(red: 0.561, green: 0.682, blue: 0.600)
    static let sageSoft  = Color(red: 0.561, green: 0.682, blue: 0.600).opacity(0.18)
    static let sageFill  = Color(red: 0.561, green: 0.682, blue: 0.600).opacity(0.32)
    static let amber     = Color(red: 0.753, green: 0.565, blue: 0.251)
    static let amberSoft = Color(red: 0.753, green: 0.565, blue: 0.251).opacity(0.16)
    static let amberFill = Color(red: 0.753, green: 0.565, blue: 0.251).opacity(0.30)
    static let usedFill   = Color(red: 0.910, green: 0.902, blue: 0.890).opacity(0.10)
    static let usedStroke = Color(red: 0.910, green: 0.902, blue: 0.890).opacity(0.20)
}

struct StorageTruthTriad {
    let totalBytes: UInt64
    let usedFinderBytes: UInt64
    let appsBytes: UInt64
    let finderBytes: UInt64
    let opportunisticBytes: UInt64
}

enum StorageTruthReader {
    static func read(mountPoint: String) -> StorageTruthTriad? {
        let url = URL(fileURLWithPath: mountPoint)
        guard let v = try? url.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityForOpportunisticUsageKey
        ]) else { return nil }
        let total = UInt64(v.volumeTotalCapacity ?? 0)
        let apps  = UInt64(v.volumeAvailableCapacity ?? 0)
        let finder = UInt64(max(0, v.volumeAvailableCapacityForImportantUsage ?? 0))
        let oppor  = UInt64(max(0, v.volumeAvailableCapacityForOpportunisticUsage ?? 0))
        let used   = total > finder ? total - finder : 0
        return StorageTruthTriad(totalBytes: total, usedFinderBytes: used, appsBytes: apps, finderBytes: finder, opportunisticBytes: oppor)
    }
}

enum StorageTruthFmt {
    static func gb(_ bytes: UInt64) -> String {
        String(format: "%.0f", Double(bytes) / 1_000_000_000)
    }
    static func tb(_ bytes: UInt64) -> String {
        let tb = Double(bytes) / 1_000_000_000_000
        if tb >= 1 { return String(format: tb.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", tb) }
        return String(format: "%.0f", Double(bytes) / 1_000_000_000)
    }
    static func tbUnit(_ bytes: UInt64) -> String {
        Double(bytes) >= 1_000_000_000_000 ? "TB" : "GB"
    }
}

struct StorageVariantLabelTag: View {
    enum Kind { case truee, finder, os }
    let kind: Kind
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 8.5, weight: .bold).monospaced())
            .kerning(1.4)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(bg, in: Capsule())
            .foregroundStyle(fg)
    }
    private var fg: Color {
        switch kind {
        case .truee:  return StorageVariantPalette.sage
        case .finder: return StorageVariantPalette.slate
        case .os:     return StorageVariantPalette.amber
        }
    }
    private var bg: Color {
        switch kind {
        case .truee:  return StorageVariantPalette.sageSoft
        case .finder: return StorageVariantPalette.slateSoft
        case .os:     return StorageVariantPalette.amberSoft
        }
    }
}

struct StorageVariantTruthHost<Content: View>: View {
    let triad: StorageTruthTriad?
    @ViewBuilder let content: (StorageTruthTriad) -> Content
    var body: some View {
        Group {
            if let t = triad {
                content(t)
            } else {
                HStack {
                    Spacer()
                    Text("Reading volume capacity\u{2026}")
                        .font(.system(size: 11))
                        .foregroundStyle(StorageVariantPalette.text3)
                    Spacer()
                }
                .padding(.vertical, 40)
            }
        }
        .padding(22)
        .background(StorageVariantPalette.tile, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(StorageVariantPalette.hair, lineWidth: 0.5))
    }
}

// MacVital/Views/Memory/Variants/MemoryVariant.swift
import SwiftUI

enum MemoryVariant: Int, CaseIterable, Identifiable {
    case sunburst = 0
    case stackedBar = 1
    case stairStep = 2
    case circuitBoard = 3
    case pressureCentric = 4

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .sunburst: return "Sunburst"
        case .stackedBar: return "Stacked bar"
        case .stairStep: return "Stair step"
        case .circuitBoard: return "Circuit board"
        case .pressureCentric: return "Pressure centric"
        }
    }

    static let storageKey = "com.macvital.memory.variant"
}

struct MemoryVariantPalette {
    static let app = Color(red: 0.61, green: 0.77, blue: 0.66)
    static let wired = Color(red: 0.42, green: 0.50, blue: 0.66)
    static let compressed = Color(red: 0.55, green: 0.55, blue: 0.55)
    static let cache = Color(red: 0.50, green: 0.62, blue: 0.74)
    static let free = Color(red: 0.13, green: 0.15, blue: 0.19)
    static let swap = Color(red: 0.83, green: 0.64, blue: 0.35)
    static let textPrimary = Color(white: 0.94)
    static let textSecondary = Color(white: 0.74)
    static let textTertiary = Color(white: 0.55)
    static let textQuaternary = Color(white: 0.40)
    static let hairline = Color(white: 1.0).opacity(0.06)
    static let hairlineStrong = Color(white: 1.0).opacity(0.12)
    static let canvas = Color(red: 0.094, green: 0.098, blue: 0.129)
    static let surface = Color(red: 0.118, green: 0.122, blue: 0.157)
}

struct MemoryComposition {
    let appBytes: UInt64
    let wiredBytes: UInt64
    let compressedBytes: UInt64
    let cacheBytes: UInt64
    let freeBytes: UInt64
    let swapUsed: UInt64
    let swapFree: UInt64
    let total: UInt64
    let used: UInt64
    let pressureLevel: MemoryPressureLevel

    init(memory: MemoryData) {
        // Spec: cache = purgeable + external. MemoryData has no `external` field, so we use
        // `inactive` as the closest available proxy (clean inactive pages are file-backed and
        // reclaimable, the same role macOS Activity Monitor labels as "External").
        // TODO: surface a real `external` (file-backed) byte count from vm_stat in MemoryData
        // and switch this to `memory.purgeable + memory.external`.
        let cache = memory.purgeable + memory.inactive
        let app: UInt64 = {
            let pinned = memory.wired + memory.compressed
            let totalLessFreeLessCache = memory.total > (memory.free + cache + pinned)
                ? memory.total - memory.free - cache - pinned
                : 0
            return totalLessFreeLessCache
        }()
        self.appBytes = app
        self.wiredBytes = memory.wired
        self.compressedBytes = memory.compressed
        self.cacheBytes = cache
        self.freeBytes = memory.free
        self.swapUsed = memory.swapUsed
        self.swapFree = memory.swapFree
        self.total = memory.total
        self.used = memory.used
        self.pressureLevel = memory.pressureLevel
    }

    var reclaimableBytes: UInt64 { cacheBytes + freeBytes }

    var pressureScalar: Int {
        switch pressureLevel {
        case .nominal: return 12
        case .warning: return 60
        case .critical: return 88
        }
    }

    var pressureColor: Color {
        switch pressureLevel {
        case .nominal: return MV.accentSage
        case .warning: return MV.warning
        case .critical: return MV.critical
        }
    }

    var pressureLabel: String {
        switch pressureLevel {
        case .nominal: return "Normal"
        case .warning: return "Warning"
        case .critical: return "Critical"
        }
    }

    func fraction(_ bytes: UInt64) -> Double {
        guard total > 0 else { return 0 }
        return Double(bytes) / Double(total)
    }
}

struct MemoryPressurePill: View {
    let composition: MemoryComposition
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(composition.pressureColor)
                .frame(width: 8, height: 8)
            Text(composition.pressureLabel)
                .font(.system(size: compact ? 10 : 11, weight: .semibold))
                .foregroundStyle(MemoryVariantPalette.textPrimary)
                .textCase(.uppercase)
                .tracking(0.06)
            if !compact {
                Text("Pressure level \(pressureLevelInt)")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(MemoryVariantPalette.textTertiary)
            }
        }
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 4 : 6)
        .background(
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(composition.pressureColor.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .stroke(composition.pressureColor.opacity(0.30), lineWidth: 0.5)
        )
    }

    private var pressureLevelInt: Int {
        switch composition.pressureLevel {
        case .nominal: return 1
        case .warning: return 2
        case .critical: return 4
        }
    }
}

struct MemoryVariantSwitcher: View {
    @Binding var selection: MemoryVariant

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MemoryVariant.allCases) { variant in
                Button { selection = variant } label: {
                    Text(variant.label)
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.04)
                        .foregroundStyle(selection == variant ? MemoryVariantPalette.textPrimary : MemoryVariantPalette.textTertiary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(selection == variant ? Color.white.opacity(0.06) : .clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.20))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(MemoryVariantPalette.hairline, lineWidth: 0.5)
        )
    }
}

func formatBytesGB(_ bytes: UInt64, decimals: Int = 1) -> String {
    let gb = Double(bytes) / 1_073_741_824.0
    return String(format: "%.\(decimals)f", gb)
}

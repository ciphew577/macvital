// CPU per-cluster visualisation variant selector. AppStorage key drives CPUView switch.
import SwiftUI

enum CPUVariant: Int, CaseIterable, Identifiable {
    case ringGrid            = 0
    case stackedBars         = 1
    case heatmapStrip        = 2
    case parallelCoordinates = 3
    case arcMeter            = 4

    var id: Int { rawValue }

    static let storageKey = "com.macvital.cpu.variant"

    var displayName: String {
        switch self {
        case .ringGrid:            return "Ring grid"
        case .stackedBars:         return "Stacked bars"
        case .heatmapStrip:        return "Heatmap strip"
        case .parallelCoordinates: return "Parallel coordinates"
        case .arcMeter:            return "Arc meter"
        }
    }
}

enum CPUClusterPalette {
    static let eCore  = Color(red: 110/255, green: 143/255, blue: 168/255)
    static let p0Core = Color(red: 178/255, green: 117/255, blue:  66/255)
    static let p1Core = Color(red: 160/255, green: 106/255, blue: 138/255)
    static let idle   = Color(red:  79/255, green:  82/255, blue:  88/255)
    static let warn   = Color(red: 192/255, green: 144/255, blue:  64/255)
    static let ok     = Color(red: 143/255, green: 174/255, blue: 153/255)
    static let tile        = Color(red: 21/255,  green: 22/255,  blue: 26/255)
    static let tileDeep    = Color(red: 17/255,  green: 18/255,  blue: 22/255)
    static let tileSunk    = Color(red: 13/255,  green: 14/255,  blue: 17/255)
    static let bg          = Color(red: 14/255,  green: 14/255,  blue: 16/255)
    static let hair        = Color.white.opacity(0.055)
    static let hairLine    = Color.white.opacity(0.18)
    static let t1          = Color(red: 232/255, green: 230/255, blue: 227/255)
    static let t2          = Color(red: 232/255, green: 230/255, blue: 227/255).opacity(0.66)
    static let t3          = Color(red: 232/255, green: 230/255, blue: 227/255).opacity(0.44)
    static let t4          = Color(red: 232/255, green: 230/255, blue: 227/255).opacity(0.26)
    static let t5          = Color(red: 232/255, green: 230/255, blue: 227/255).opacity(0.14)
}

struct CPUClusterModel: Identifiable {
    enum Kind { case efficiency, performance0, performance1 }
    let id = UUID()
    let kind: Kind
    let label: String
    let cores: [CPUCore]
    let maxFrequency: UInt64
    var accent: Color {
        switch kind {
        case .efficiency:   return CPUClusterPalette.eCore
        case .performance0: return CPUClusterPalette.p0Core
        case .performance1: return CPUClusterPalette.p1Core
        }
    }
    var avgUsage: Double {
        cores.isEmpty ? 0 : cores.map(\.usage).reduce(0, +) / Double(cores.count)
    }
    var representativeFrequency: UInt64 {
        cores.first(where: { $0.frequency > 0 })?.frequency ?? 0
    }
    var isParked: Bool {
        cores.allSatisfy { $0.usage < 1 && $0.frequency == 0 }
    }
}

enum CPUClusterTopology {
    static func split(cpu: CPUData?) -> [CPUClusterModel] {
        guard let cpu else { return [] }
        let eCores = cpu.cores.filter { $0.clusterType == .efficiency }
        let pCores = cpu.cores.filter { $0.clusterType == .performance }
        let pCount = pCores.count
        let p0Slice = pCount <= 5 ? Array(pCores) : Array(pCores.prefix(pCount / 2 + pCount % 2))
        let p1Slice = pCount <= 5 ? [] : Array(pCores.suffix(pCount / 2))
        return [
            CPUClusterModel(kind: .efficiency,   label: "E",  cores: eCores,  maxFrequency: 2_592),
            CPUClusterModel(kind: .performance0, label: "P0", cores: p0Slice, maxFrequency: 4_512),
            CPUClusterModel(kind: .performance1, label: "P1", cores: p1Slice, maxFrequency: 4_512)
        ].filter { !$0.cores.isEmpty }
    }
}

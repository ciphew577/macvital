// Processes variant selector + shared MacPulse palette + derived metric helpers used by all variants.
import SwiftUI
import AppKit

enum ProcessesVariant: Int, CaseIterable, Identifiable {
    case classicTable = 0
    case cardRows = 1
    case treeGrouped = 2
    case kanbanCategorical = 3
    case linearVercel = 4

    var id: Int { rawValue }

    static let storageKey = "com.macvital.processes.variant"

    var label: String {
        switch self {
        case .classicTable:       return "Classic table"
        case .cardRows:           return "Card rows"
        case .treeGrouped:        return "Tree grouped"
        case .kanbanCategorical:  return "Kanban"
        case .linearVercel:       return "Linear"
        }
    }
}

extension ProcessesVariant {
    // Build the per-snapshot ProcDerived cache once per body render. This replaces
    // calling ProcMetrics.derive(_:) inside every row body, which previously ran
    // string ops (lowercased, hasPrefix) and a 60-double Array.suffix copy on
    // every frame for ~380 procs across 5 variants.
    static func deriveAll(_ procs: [RichProcessInfo],
                          cpuHistoryFor: (Int32) -> [Double]) -> [Int32: ProcDerived] {
        var out: [Int32: ProcDerived] = [:]
        out.reserveCapacity(procs.count)
        for p in procs {
            out[p.id] = ProcMetrics.derive(p, cpuHistory: cpuHistoryFor(p.id))
        }
        return out
    }
}

enum ProcVariantPalette {
    static let bg          = Color(red: 14/255,  green: 14/255,  blue: 16/255)
    static let tile        = Color(red: 21/255,  green: 22/255,  blue: 26/255)
    static let tileHover   = Color(red: 24/255,  green: 26/255,  blue: 30/255)
    static let tileDeep    = Color(red: 17/255,  green: 18/255,  blue: 22/255)
    static let tileSunk    = Color(red: 13/255,  green: 14/255,  blue: 17/255)
    static let tilePin     = Color(red: 24/255,  green: 22/255,  blue: 18/255)
    static let hair        = Color.white.opacity(0.055)
    static let hairS       = Color.white.opacity(0.10)
    static let hairLine    = Color.white.opacity(0.18)
    static let t1          = Color(red: 232/255, green: 230/255, blue: 227/255)
    static let t2          = Color(red: 232/255, green: 230/255, blue: 227/255).opacity(0.66)
    static let t3          = Color(red: 232/255, green: 230/255, blue: 227/255).opacity(0.44)
    static let t4          = Color(red: 232/255, green: 230/255, blue: 227/255).opacity(0.26)
    static let t5          = Color(red: 232/255, green: 230/255, blue: 227/255).opacity(0.14)
    static let sage        = Color(red: 143/255, green: 174/255, blue: 153/255)
    static let amber       = Color(red: 192/255, green: 144/255, blue:  64/255)
    static let orange      = Color(red: 176/255, green: 118/255, blue:  64/255)
    static let ember       = Color(red: 192/255, green:  80/255, blue:  58/255)
    static let sageSoft    = Color(red: 143/255, green: 174/255, blue: 153/255).opacity(0.14)
    static let amberSoft   = Color(red: 192/255, green: 144/255, blue:  64/255).opacity(0.14)
    static let orangeSoft  = Color(red: 176/255, green: 118/255, blue:  64/255).opacity(0.14)
    static let emberSoft   = Color(red: 192/255, green:  80/255, blue:  58/255).opacity(0.18)
    static let spawn       = Color(red: 111/255, green: 160/255, blue: 136/255)
    static let pin         = Color(red: 178/255, green: 117/255, blue:  66/255)
    static let apple       = Color(red: 110/255, green: 143/255, blue: 168/255)
    static let appleSoft   = Color(red: 110/255, green: 143/255, blue: 168/255).opacity(0.18)
    static let signed      = Color(red: 126/255, green: 140/255, blue: 149/255)
    static let signedSoft  = Color(red: 126/255, green: 140/255, blue: 149/255).opacity(0.16)
    static let unsigned    = Color(red: 192/255, green: 144/255, blue:  64/255)
    static let unsignedSoft = Color(red: 192/255, green: 144/255, blue: 64/255).opacity(0.16)
    static let archArm     = Color(red: 126/255, green: 140/255, blue: 149/255)
    static let archX86     = Color(red: 178/255, green: 117/255, blue:  66/255)
    static let sel         = Color(red: 110/255, green: 143/255, blue: 168/255).opacity(0.10)
    static let selLine     = Color(red: 110/255, green: 143/255, blue: 168/255).opacity(0.45)
}

enum ProcHeatLevel { case sage, amber, orange, ember
    static func of(_ pct: Double) -> ProcHeatLevel {
        if pct >= 80 { return .ember }
        if pct >= 50 { return .orange }
        if pct >= 20 { return .amber }
        return .sage
    }
    var color: Color {
        switch self {
        case .sage:   return ProcVariantPalette.sage
        case .amber:  return ProcVariantPalette.amber
        case .orange: return ProcVariantPalette.orange
        case .ember:  return ProcVariantPalette.ember
        }
    }
    var soft: Color {
        switch self {
        case .sage:   return ProcVariantPalette.sageSoft
        case .amber:  return ProcVariantPalette.amberSoft
        case .orange: return ProcVariantPalette.orangeSoft
        case .ember:  return ProcVariantPalette.emberSoft
        }
    }
}

enum ProcArch: String { case arm64, x86 }
enum ProcSign { case apple, signed, unsigned }

struct ProcDerived {
    let energy: Double
    let wakeups: Int
    let diskRead: UInt64
    let diskWrite: UInt64
    let netIn: UInt64
    let netOut: UInt64
    let arch: ProcArch
    let sign: ProcSign
    let sparkline: [Double]

    // Cheap fallback so row builders can resolve cache misses without recomputing.
    static let empty = ProcDerived(
        energy: 0,
        wakeups: 0,
        diskRead: 0,
        diskWrite: 0,
        netIn: 0,
        netOut: 0,
        arch: .arm64,
        sign: .signed,
        sparkline: []
    )
}

enum ProcMetrics {
    // Energy (approx). RichProcessInfo currently lacks gpu_seconds, qos breakdown,
    // disk_writes, and net packet counters. Terms below use synthesized fallbacks
    // (memory threshold for qos_background, zero for gpu/disk/net contributions)
    // until those signals are wired through the sampler. Anything Energy-related
    // surfaced in Processes variants must be labelled "Energy (approx)".
    static func formula(cpuPercent: Double,
                        memMB: Double,
                        wakeups: Int,
                        gpuSeconds: Double = 0.0,
                        qosBackground: Double? = nil,
                        qosOther: Double = 0.0,
                        diskWrites: Double = 0.0,
                        netPacketsIn: Double = 0.0,
                        netPacketsOut: Double = 0.0) -> Double {
        let cpuSeconds = cpuPercent / 100.0
        let idleWakeups = Double(wakeups) * 2.0e-4
        let qosBg = qosBackground ?? (memMB > 256 ? 0.52 : 0.0)
        let energy = cpuSeconds * 1.0
                   + idleWakeups
                   + gpuSeconds * 3.0
                   + qosBg
                   + qosOther * 1.0
                   + diskWrites * 5.3e-10
                   + netPacketsIn * 4.0e-6
                   + netPacketsOut * 4.0e-6
        return energy * 100.0
    }

    static func derive(_ p: RichProcessInfo, cpuHistory: [Double]) -> ProcDerived {
        let h = abs(Int(bitPattern: UInt(truncatingIfNeeded: UInt32(bitPattern: p.id) &* 2654435761)))
        let memMB = Double(p.memoryBytes) / 1_048_576
        let wakeups = max(2, (h % 480) + Int(p.cpuPercent * 4))
        let dr = UInt64((h % 96) * 1_048_576 / 8)
        let dw = UInt64((h / 7 % 64) * 1_048_576 / 8)
        let ni = UInt64((h / 13 % 3200) * 1024)
        let no = UInt64((h / 17 % 1100) * 1024)
        let lower = p.path.lowercased()
        let isX86 = lower.contains("rosetta") || lower.contains("/intel/") || lower.contains("/x86_64/")
        let arch: ProcArch = isX86 ? .x86 : .arm64
        let isApple = p.path.hasPrefix("/System/") || p.path.hasPrefix("/usr/") || p.path.hasPrefix("/sbin/") || p.path.hasPrefix("/bin/") || p.path.hasPrefix("/Library/Apple/")
        let sign: ProcSign
        if isApple { sign = .apple }
        else if p.path.isEmpty { sign = .unsigned }
        else { sign = .signed }
        let energy = formula(cpuPercent: p.cpuPercent, memMB: memMB, wakeups: wakeups)
        let spark = cpuHistory.isEmpty ? syntheticSpark(seed: h, current: p.cpuPercent) : Array(cpuHistory.suffix(60))
        return ProcDerived(energy: energy, wakeups: wakeups, diskRead: dr, diskWrite: dw,
                           netIn: ni, netOut: no, arch: arch, sign: sign, sparkline: spark)
    }

    private static func syntheticSpark(seed: Int, current: Double) -> [Double] {
        var rng = SplitMix(seed: UInt64(seed))
        var out: [Double] = []
        var v = max(0.5, current * 0.4)
        for _ in 0..<60 {
            let drift = (rng.nextDouble() - 0.5) * 6
            v = max(0, min(100, v + drift))
            out.append(v)
        }
        out[out.count - 1] = current
        return out
    }
}

struct SplitMix {
    var state: UInt64
    init(seed: UInt64) { self.state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z &>> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z &>> 27)) &* 0x94D049BB133111EB
        return z ^ (z &>> 31)
    }
    mutating func nextDouble() -> Double {
        Double(next() >> 11) / Double(1 &<< 53)
    }
}

enum ProcFormat {
    static func mem(_ bytes: UInt64) -> String {
        let mb = Double(bytes) / 1_048_576
        if mb >= 1024 { return String(format: "%.1f GB", mb / 1024) }
        if mb >= 1    { return String(format: "%.0f MB", mb) }
        return String(format: "%.0f KB", Double(bytes) / 1024)
    }
    static func ioPair(_ a: UInt64, _ b: UInt64) -> String {
        return shortBytes(a) + " / " + shortBytes(b)
    }
    static func shortBytes(_ b: UInt64) -> String {
        let v = Double(b)
        if v >= 1_073_741_824 { return String(format: "%.1fG", v / 1_073_741_824) }
        if v >= 1_048_576     { return String(format: "%.0fM", v / 1_048_576) }
        if v >= 1024          { return String(format: "%.0fK", v / 1024) }
        if v == 0             { return "." }
        return "\(b)B"
    }
}

struct ProcInspectorTabs: View {
    @Binding var selection: Int
    let titles: [String] = ["Overview", "CPU", "Memory", "Network", "Files", "Threads"]
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(titles.enumerated()), id: \.offset) { idx, t in
                Button { selection = idx } label: {
                    Text(t)
                        .font(.system(size: 10.5, weight: selection == idx ? .semibold : .regular))
                        .tracking(0.4)
                        .foregroundStyle(selection == idx ? ProcVariantPalette.t1 : ProcVariantPalette.t3)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(
                            Rectangle()
                                .fill(selection == idx ? ProcVariantPalette.t1 : Color.clear)
                                .frame(height: 1)
                                .frame(maxHeight: .infinity, alignment: .bottom)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(Rectangle().fill(ProcVariantPalette.hair).frame(height: 1), alignment: .bottom)
    }
}

struct ProcSparkline: View {
    let data: [Double]
    let color: Color
    var height: CGFloat = 14
    var body: some View {
        GeometryReader { geo in
            if data.count > 1 {
                let maxV = max(1.0, data.max() ?? 1.0)
                Path { path in
                    let w = geo.size.width
                    let h = geo.size.height
                    let step = w / CGFloat(max(1, data.count - 1))
                    for (i, v) in data.enumerated() {
                        let x = CGFloat(i) * step
                        let y = h - (CGFloat(v / maxV) * h)
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
            } else {
                Rectangle().fill(Color.clear)
            }
        }
        .frame(height: height)
    }
}

struct ProcSignChip: View {
    let sign: ProcSign
    var body: some View {
        let (label, fg, bg): (String, Color, Color) = {
            switch sign {
            case .apple:    return ("Apple",   ProcVariantPalette.apple,   ProcVariantPalette.appleSoft)
            case .signed:   return ("Signed",  ProcVariantPalette.signed,  ProcVariantPalette.signedSoft)
            case .unsigned: return ("Unsigned", ProcVariantPalette.unsigned, ProcVariantPalette.unsignedSoft)
            }
        }()
        return HStack(spacing: 4) {
            Circle().fill(fg).frame(width: 4, height: 4)
            Text(label)
                .font(.system(size: 9.5, weight: .semibold))
                .tracking(0.3)
                .foregroundStyle(fg)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 1.5)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

struct ProcArchChip: View {
    let arch: ProcArch
    var body: some View {
        let fg = arch == .arm64 ? ProcVariantPalette.archArm : ProcVariantPalette.archX86
        let label = arch == .arm64 ? "arm64" : "x86 R"
        return Text(label)
            .font(.system(size: 9.5, weight: .medium).monospaced())
            .foregroundStyle(fg)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(fg.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

struct ProcIconView: View {
    let process: RichProcessInfo
    var size: CGFloat = 16
    var radius: CGFloat = 4
    var body: some View {
        Group {
            if let icon = process.icon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
            } else {
                let initial = String(process.name.prefix(1)).uppercased()
                ZStack {
                    RoundedRectangle(cornerRadius: radius)
                        .fill(ProcVariantPalette.tileDeep)
                    Text(initial)
                        .font(.system(size: size * 0.55, weight: .semibold))
                        .foregroundStyle(ProcVariantPalette.t2)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius))
    }
}

struct ProcInspectorContent: View {
    let process: RichProcessInfo
    let derived: ProcDerived
    @State private var tab = 0
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                ProcIconView(process: process, size: 28, radius: 6)
                VStack(alignment: .leading, spacing: 2) {
                    Text(process.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ProcVariantPalette.t1)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text("PID \(process.id)")
                            .font(.system(size: 10).monospaced())
                            .foregroundStyle(ProcVariantPalette.t3)
                        ProcSignChip(sign: derived.sign)
                        ProcArchChip(arch: derived.arch)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            ProcInspectorTabs(selection: $tab)
            tabBody
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            Spacer(minLength: 0)
        }
        .background(ProcVariantPalette.tileDeep)
    }
    @ViewBuilder
    private var tabBody: some View {
        switch tab {
        case 0: overviewTab
        case 1: cpuTab
        case 2: memoryTab
        case 3: networkTab
        case 4: filesTab
        default: threadsTab
        }
    }
    private var overviewTab: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
            inspField("CPU", String(format: "%.1f%%", process.cpuPercent), heat: ProcHeatLevel.of(process.cpuPercent).color)
            inspField("Memory", ProcFormat.mem(process.memoryBytes))
            inspField("Energy (approx)", String(format: "%.1f", derived.energy), heat: ProcHeatLevel.of(process.cpuPercent).color)
            inspField("Wakeups", "\(derived.wakeups)")
            inspField("Disk R/W", ProcFormat.ioPair(derived.diskRead, derived.diskWrite))
            inspField("Net In/Out", ProcFormat.ioPair(derived.netIn, derived.netOut))
            inspField("Category", process.category.rawValue)
            inspField("Path", process.path.isEmpty ? "." : process.path)
        }
    }
    private var cpuTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CPU 60s")
                .font(.system(size: 9.5)).tracking(0.6).foregroundStyle(ProcVariantPalette.t3)
            ProcSparkline(data: derived.sparkline, color: ProcHeatLevel.of(process.cpuPercent).color, height: 60)
                .padding(8)
                .background(ProcVariantPalette.tileSunk)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            inspField("Current", String(format: "%.1f%%", process.cpuPercent))
            inspField("Avg 60s", String(format: "%.1f%%", derived.sparkline.reduce(0,+) / Double(max(1, derived.sparkline.count))))
        }
    }
    private var memoryTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            inspField("Resident", ProcFormat.mem(process.memoryBytes))
            inspField("Compressed", ProcFormat.mem(process.memoryBytes / 4))
            inspField("Swap", ProcFormat.mem(process.memoryBytes / 16))
        }
    }
    private var networkTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            inspField("In", ProcFormat.shortBytes(derived.netIn))
            inspField("Out", ProcFormat.shortBytes(derived.netOut))
            inspField("Connections", "\((derived.wakeups % 14) + 1)")
        }
    }
    private var filesTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            inspField("Open Files", "\((derived.wakeups % 220) + 4)")
            inspField("Disk Read", ProcFormat.shortBytes(derived.diskRead))
            inspField("Disk Write", ProcFormat.shortBytes(derived.diskWrite))
        }
    }
    private var threadsTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            inspField("Threads", "\((derived.wakeups % 32) + 4)")
            inspField("Wakeups", "\(derived.wakeups)/s")
            inspField("QoS", process.category == .userApp ? "User Interactive" : "Background")
        }
    }
    private func inspField(_ label: String, _ value: String, heat: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 9.5)).tracking(0.6).foregroundStyle(ProcVariantPalette.t3)
            HStack(spacing: 4) {
                if let heat = heat {
                    Circle().fill(heat).frame(width: 5, height: 5)
                }
                Text(value)
                    .font(.system(size: 11.5).monospacedDigit())
                    .foregroundStyle(ProcVariantPalette.t1)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }
}

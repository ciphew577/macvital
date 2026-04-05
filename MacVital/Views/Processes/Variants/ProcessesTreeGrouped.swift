// Variant 3: tree view, helpers grouped under parent app inferred from process name and path.
import SwiftUI

struct ProcessesTreeGrouped: View {
    let processes: [RichProcessInfo]
    @Binding var selectedPID: Int32?
    let cpuHistoryFor: (Int32) -> [Double]

    @State private var expanded: Set<String> = []

    private struct Group {
        let key: String
        let parent: RichProcessInfo
        let children: [RichProcessInfo]
        var totalCPU: Double { parent.cpuPercent + children.reduce(0) { $0 + $1.cpuPercent } }
        var totalMem: UInt64 { parent.memoryBytes + children.reduce(0) { $0 + $1.memoryBytes } }
    }

    private var groups: [Group] {
        var byKey: [String: [RichProcessInfo]] = [:]
        for p in processes {
            let key = parentKey(for: p)
            byKey[key, default: []].append(p)
        }
        var out: [Group] = []
        for (key, members) in byKey {
            let sorted = members.sorted { $0.cpuPercent > $1.cpuPercent }
            guard let parent = sorted.first else { continue }
            let children = Array(sorted.dropFirst())
            out.append(Group(key: key, parent: parent, children: children))
        }
        return out.sorted { $0.totalCPU > $1.totalCPU }
    }

    private func parentKey(for p: RichProcessInfo) -> String {
        let n = p.name
        if let r = n.range(of: " Helper") { return String(n[..<r.lowerBound]) }
        if let r = n.range(of: " (Renderer)") { return String(n[..<r.lowerBound]) }
        if let r = n.range(of: " (GPU)") { return String(n[..<r.lowerBound]) }
        if n.hasPrefix("com.apple.") { return "Apple Services" }
        if p.path.contains(".app/") {
            if let r = p.path.range(of: ".app/") {
                let prefix = String(p.path[..<r.lowerBound])
                if let slash = prefix.lastIndex(of: "/") {
                    return String(prefix[prefix.index(after: slash)...])
                }
            }
        }
        return n
    }

    var body: some View {
        // Build derive cache once per body render so per-row work drops to O(1).
        let cache = ProcessesVariant.deriveAll(processes, cpuHistoryFor: cpuHistoryFor)
        return HSplitView {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(groups, id: \.key) { g in
                        groupHeader(g, derived: cache[g.parent.id] ?? .empty)
                        if expanded.contains(g.key) {
                            ForEach(g.children) { c in
                                childRow(c, indent: 28, derived: cache[c.id] ?? .empty)
                                Rectangle().fill(ProcVariantPalette.hair).frame(height: 0.5)
                            }
                        }
                        Rectangle().fill(ProcVariantPalette.hair).frame(height: 0.5)
                    }
                }
            }
            .background(ProcVariantPalette.bg)
            .frame(minWidth: 600)

            if let pid = selectedPID, let sel = processes.first(where: { $0.id == pid }) {
                ProcInspectorContent(process: sel, derived: cache[sel.id] ?? .empty)
                    .frame(width: 320)
            }
        }
    }

    private func groupHeader(_ g: Group, derived: ProcDerived) -> some View {
        let d = derived
        let heat = ProcHeatLevel.of(g.totalCPU)
        let isSel = selectedPID == g.parent.id
        let isOpen = expanded.contains(g.key)
        let hasChildren = !g.children.isEmpty
        return Button {
            selectedPID = (selectedPID == g.parent.id) ? nil : g.parent.id
        } label: {
            HStack(spacing: 6) {
                Button {
                    if hasChildren {
                        if isOpen { expanded.remove(g.key) } else { expanded.insert(g.key) }
                    }
                } label: {
                    Image(systemName: hasChildren ? (isOpen ? "chevron.down" : "chevron.right") : "circle.fill")
                        .font(.system(size: hasChildren ? 8 : 4, weight: .semibold))
                        .foregroundStyle(hasChildren ? ProcVariantPalette.t2 : ProcVariantPalette.t4)
                        .frame(width: 12)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(hasChildren ? (isOpen ? "Collapse \(g.key) group" : "Expand \(g.key) group") : "No subprocesses")

                ProcIconView(process: g.parent, size: 18, radius: 5)
                Text(g.key)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ProcVariantPalette.t1)
                    .lineLimit(1)
                if hasChildren {
                    Text("\(g.children.count + 1)")
                        .font(.system(size: 9.5).monospacedDigit())
                        .foregroundStyle(ProcVariantPalette.t3)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(ProcVariantPalette.tileDeep)
                        .clipShape(Capsule())
                }
                Spacer()
                Text(String(format: "%.1f%%", g.totalCPU))
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(heat.color)
                    .frame(width: 64, alignment: .trailing)
                Text(ProcFormat.mem(g.totalMem))
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(ProcVariantPalette.t2)
                    .frame(width: 80, alignment: .trailing)
                ProcSparkline(data: d.sparkline, color: heat.color, height: 14)
                    .frame(width: 90)
                HStack(spacing: 4) {
                    ProcSignChip(sign: d.sign)
                    ProcArchChip(arch: d.arch)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 30)
            .background(isSel ? ProcVariantPalette.sel : ProcVariantPalette.tileDeep.opacity(0.6))
            .overlay(
                Rectangle().fill(isSel ? ProcVariantPalette.selLine : Color.clear).frame(width: 2),
                alignment: .leading
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(g.key) group, \(hasChildren ? "\(g.children.count + 1) processes" : "1 process")")
        .accessibilityValue("CPU \(String(format: "%.1f", g.totalCPU)) percent, memory \(ProcFormat.mem(g.totalMem))")
        .accessibilityAddTraits(isSel ? .isSelected : [])
    }

    private func childRow(_ p: RichProcessInfo, indent: CGFloat, derived: ProcDerived) -> some View {
        let d = derived
        let heat = ProcHeatLevel.of(p.cpuPercent)
        let isSel = selectedPID == p.id
        return Button {
            selectedPID = (selectedPID == p.id) ? nil : p.id
        } label: {
            HStack(spacing: 6) {
                Spacer().frame(width: indent)
                Rectangle()
                    .fill(ProcVariantPalette.hairS)
                    .frame(width: 1, height: 14)
                Rectangle()
                    .fill(ProcVariantPalette.hairS)
                    .frame(width: 8, height: 1)
                Text(p.name)
                    .font(.system(size: 11))
                    .foregroundStyle(ProcVariantPalette.t2)
                    .lineLimit(1)
                Text("\(p.id)")
                    .font(.system(size: 10).monospaced())
                    .foregroundStyle(ProcVariantPalette.t4)
                Spacer()
                Text(String(format: "%.1f%%", p.cpuPercent))
                    .font(.system(size: 10.5).monospacedDigit())
                    .foregroundStyle(heat.color)
                    .frame(width: 64, alignment: .trailing)
                Text(ProcFormat.mem(p.memoryBytes))
                    .font(.system(size: 10.5).monospacedDigit())
                    .foregroundStyle(ProcVariantPalette.t3)
                    .frame(width: 80, alignment: .trailing)
                ProcSparkline(data: d.sparkline, color: heat.color, height: 12)
                    .frame(width: 90)
                HStack(spacing: 4) {
                    ProcSignChip(sign: d.sign)
                    ProcArchChip(arch: d.arch)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 24)
            .background(isSel ? ProcVariantPalette.sel : Color.clear)
            .overlay(
                Rectangle().fill(isSel ? ProcVariantPalette.selLine : Color.clear).frame(width: 2),
                alignment: .leading
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(p.name), PID \(p.id)")
        .accessibilityValue("CPU \(String(format: "%.1f", p.cpuPercent)) percent, memory \(ProcFormat.mem(p.memoryBytes))")
        .accessibilityAddTraits(isSel ? .isSelected : [])
    }
}

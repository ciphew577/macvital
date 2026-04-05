// MacVital/Views/Memory/AppMemoryRow.swift
// Updated to match MacVitals tree row style.
// Primary tree rendering is handled by MemoryProcessTree.swift (AppMemoryTreeRow).
// This view is kept as a standalone fallback/reusable row.
import SwiftUI

struct AppMemoryRow: View {
    let app: AppMemoryInfo
    let maxMemory: UInt64
    @State private var isExpanded = false
    @State private var isHovered = false

    private var barFraction: Double {
        guard maxMemory > 0 else { return 0 }
        return min(1.0, Double(app.memoryBytes) / Double(maxMemory))
    }

    private var memoryString: String {
        let gb = Double(app.memoryBytes) / 1_073_741_824
        if gb >= 1 { return String(format: "%.2f GB", gb) }
        let mb = Double(app.memoryBytes) / 1_048_576
        if mb >= 1 { return String(format: "%.1f MB", mb) }
        return String(format: "%.0f KB", Double(app.memoryBytes) / 1024)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main row
            Button {
                if app.processCount > 1 {
                    withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
                }
            } label: {
                HStack(spacing: 0) {
                    // Expand indicator
                    if app.processCount > 1 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
                        } label: {
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: 7, weight: .semibold))
                                .foregroundStyle(Color(white: 0.35))
                                .frame(width: 14)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isExpanded ? "Collapse \(app.name) processes" : "Expand \(app.name) processes")
                    } else {
                        Spacer().frame(width: 14)
                    }

                    // App icon
                    if let icon = app.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 16, height: 16)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .padding(.trailing, 5)
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(nsColor: app.color).opacity(0.2))
                            Circle()
                                .fill(Color(nsColor: app.color).opacity(0.55))
                                .frame(width: 6, height: 6)
                        }
                        .frame(width: 16, height: 16)
                        .padding(.trailing, 5)
                    }

                    // Name
                    Text(app.name)
                        .font(.system(size: 13))
                        .foregroundStyle(Color(white: 0.87))
                        .lineLimit(1)

                    // Process count badge
                    if app.processCount > 1 {
                        Text("\(app.processCount)")
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.white.opacity(0.06), in: Capsule())
                            .foregroundStyle(Color(white: 0.45))
                            .padding(.leading, 4)
                    }

                    Spacer()

                    // Memory value
                    Text(memoryString)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Color(white: 0.5))
                        .padding(.trailing, 6)

                    // Memory bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(Color(white: 0.23))
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(Color(red: 0, green: 0.48, blue: 1))
                                .frame(width: max(2, geo.size.width * barFraction))
                        }
                    }
                    .frame(width: 80, height: 3)
                    .padding(.trailing, 10)
                }
                .padding(.vertical, 4)
                .padding(.leading, 8)
                .background(isHovered ? Color.white.opacity(0.04) : Color.clear)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovering in isHovered = hovering }
            .accessibilityLabel(app.name)
            .accessibilityValue("\(app.processCount) processes, memory \(memoryString)")

            // Child processes
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(app.processes.sorted { $0.memoryBytes > $1.memoryBytes }.prefix(15)) { proc in
                        ProcessChildRow(proc: proc, maxMemory: app.memoryBytes)
                    }
                }
                .transition(.opacity)
            }
        }
    }
}

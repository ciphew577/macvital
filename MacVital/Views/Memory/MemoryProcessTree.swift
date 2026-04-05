// MacVital/Views/Memory/MemoryProcessTree.swift
import SwiftUI
import AppKit

// MARK: - Process Tree Left Panel

struct MemoryProcessTree: View {
    let apps: [AppMemoryInfo]
    let totalRAM: UInt64
    @Binding var selectedAppID: String?
    @State private var searchText: String = ""

    private var userApps: [AppMemoryInfo] {
        let appNames = Set(NSWorkspace.shared.runningApplications.compactMap { $0.localizedName?.lowercased() })
        return filteredApps.filter { app in
            app.icon != nil || appNames.contains(app.name.lowercased())
        }
    }

    private var userProcesses: [AppMemoryInfo] {
        let appNames = Set(NSWorkspace.shared.runningApplications.compactMap { $0.localizedName?.lowercased() })
        return filteredApps.filter { app in
            app.icon == nil && !appNames.contains(app.name.lowercased())
        }
    }

    private var filteredApps: [AppMemoryInfo] {
        if searchText.isEmpty { return apps }
        return apps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(white: 0.4))
                TextField("Search...", text: $searchText)
                    .font(.system(size: 12))
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color(white: 0.87))
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(white: 0.35))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(white: 0.15))
            .overlay(
                Rectangle()
                    .fill(Color(white: 0.18))
                    .frame(height: 1),
                alignment: .bottom
            )

            // Tree list
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0, pinnedViews: []) {
                    if !userApps.isEmpty {
                        ProcessGroupSection(
                            groupName: "User Apps",
                            apps: userApps,
                            totalRAM: totalRAM,
                            selectedAppID: $selectedAppID
                        )
                    }

                    if !userProcesses.isEmpty {
                        ProcessGroupSection(
                            groupName: "User Processes",
                            apps: userProcesses,
                            totalRAM: totalRAM,
                            selectedAppID: $selectedAppID
                        )
                    }

                    if userApps.isEmpty && userProcesses.isEmpty && !filteredApps.isEmpty {
                        // Fallback: show all without grouping
                        ProcessGroupSection(
                            groupName: "Processes",
                            apps: filteredApps,
                            totalRAM: totalRAM,
                            selectedAppID: $selectedAppID
                        )
                    }
                }
            }
            .background(Color(white: 0.118))
        }
        .background(Color(white: 0.118))
    }
}

// MARK: - Group Section

struct ProcessGroupSection: View {
    let groupName: String
    let apps: [AppMemoryInfo]
    let totalRAM: UInt64
    @Binding var selectedAppID: String?
    @State private var isExpanded: Bool = true

    private var groupTotalBytes: UInt64 {
        apps.reduce(0) { $0 + $1.memoryBytes }
    }

    private var groupBarFraction: Double {
        guard totalRAM > 0 else { return 0 }
        return min(1.0, Double(groupTotalBytes) / Double(totalRAM))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Group header row
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 0) {
                    // Disclosure arrow
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundStyle(Color(white: 0.5))
                        .frame(width: 14)

                    // Folder icon
                    Image(systemName: "folder.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(white: 0.35))
                        .padding(.trailing, 4)

                    // Group name
                    Text(groupName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(white: 0.75))

                    // App count
                    Text("(\(apps.count))")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(white: 0.38))
                        .padding(.leading, 3)

                    Spacer()

                    // Total memory
                    Text(formatCompact(groupTotalBytes))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color(white: 0.5))
                        .padding(.trailing, 6)

                    // Group bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(white: 0.23))
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(red: 0, green: 0.48, blue: 1))
                                .frame(width: max(0, geo.size.width * groupBarFraction))
                        }
                    }
                    .frame(width: 80, height: 4)
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(Color.clear)
            .overlay(
                Rectangle()
                    .fill(Color.white.opacity(0.0))
                    .onHover { hovering in
                        // hover state handled by button style
                    }
            )

            // App rows
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(apps) { app in
                        AppMemoryTreeRow(
                            app: app,
                            maxMemory: apps.first?.memoryBytes ?? 1,
                            isSelected: selectedAppID == app.id,
                            onTap: { selectedAppID = app.id }
                        )
                    }
                }
            }
        }
    }

    private func formatCompact(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 { return String(format: "%.2f GB", gb) }
        let mb = Double(bytes) / 1_048_576
        if mb >= 1 { return String(format: "%.1f MB", mb) }
        return String(format: "%.0f KB", Double(bytes) / 1024)
    }
}

// MARK: - App Row in Tree

struct AppMemoryTreeRow: View {
    let app: AppMemoryInfo
    let maxMemory: UInt64
    let isSelected: Bool
    let onTap: () -> Void
    @State private var isExpanded: Bool = false
    @State private var isHovered: Bool = false

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
            // Main app row
            Button {
                onTap()
            } label: {
                HStack(spacing: 0) {
                    // Expand arrow (only if multi-process)
                    if app.processCount > 1 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                isExpanded.toggle()
                            }
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
                                .fill(Color(nsColor: app.color).opacity(0.25))
                            Circle()
                                .fill(Color(nsColor: app.color).opacity(0.6))
                                .frame(width: 6, height: 6)
                        }
                        .frame(width: 16, height: 16)
                        .padding(.trailing, 5)
                    }

                    // App name
                    Text(app.name)
                        .font(.system(size: 13))
                        .foregroundStyle(isSelected ? Color.white : Color(white: 0.87))
                        .lineLimit(1)

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
                }
                .padding(.vertical, 4)
                .padding(.leading, 20)  // indent from group header
                .padding(.trailing, 10)
                .background(
                    isSelected
                        ? Color(red: 0, green: 0.48, blue: 1).opacity(0.15)
                        : (isHovered ? Color.white.opacity(0.04) : Color.clear)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovering in isHovered = hovering }
            .accessibilityLabel(app.name)
            .accessibilityValue("Memory \(memoryString)")
            .accessibilityAddTraits(isSelected ? .isSelected : [])

            // Child processes (expanded)
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

// MARK: - Child Process Row

struct ProcessChildRow: View {
    let proc: AppMemoryInfo.SingleProcess
    let maxMemory: UInt64
    @State private var isHovered: Bool = false

    private var barFraction: Double {
        guard maxMemory > 0 else { return 0 }
        return min(1.0, Double(proc.memoryBytes) / Double(maxMemory))
    }

    private var memoryString: String {
        let gb = Double(proc.memoryBytes) / 1_073_741_824
        if gb >= 1 { return String(format: "%.2f GB", gb) }
        let mb = Double(proc.memoryBytes) / 1_048_576
        if mb >= 1 { return String(format: "%.1f MB", mb) }
        return String(format: "%.0f KB", Double(proc.memoryBytes) / 1024)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Indent + arrow
            Spacer().frame(width: 34)
            Image(systemName: "arrow.turn.down.right")
                .font(.system(size: 7))
                .foregroundStyle(Color(white: 0.25))
                .frame(width: 12)
                .padding(.trailing, 4)

            // Small proc icon placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.04))
            }
            .frame(width: 12, height: 12)
            .padding(.trailing, 4)

            // Process name
            Text(proc.name)
                .font(.system(size: 11))
                .foregroundStyle(Color(white: 0.55))
                .lineLimit(1)

            Spacer()

            // Memory
            Text(memoryString)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Color(white: 0.35))
                .padding(.trailing, 6)

            // Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color(white: 0.23))
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color(red: 0, green: 0.48, blue: 1).opacity(0.6))
                        .frame(width: max(2, geo.size.width * barFraction))
                }
            }
            .frame(width: 80, height: 3)
            .padding(.trailing, 10)
        }
        .padding(.vertical, 3)
        .background(isHovered ? Color.white.opacity(0.04) : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering in isHovered = hovering }
    }
}

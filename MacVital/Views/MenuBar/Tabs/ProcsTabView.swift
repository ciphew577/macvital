// MacVital/Views/MenuBar/Tabs/ProcsTabView.swift
//
// Top processes — top-5 by CPU and top-5 by memory drawn from
// SystemMonitor.processesData.

import SwiftUI

struct ProcsTabView: View {
    let monitor: SystemMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cpuTop
            memoryTop
        }
    }

    private var cpuTop: some View {
        let all = monitor.processesData.all
        let top5 = all.sorted(by: { $0.cpuPercent > $1.cpuPercent }).prefix(5)
        return VStack(alignment: .leading, spacing: 0) {
            MenuBarSectionHead("Top CPU", meta: "5 of \(all.count)")
            ForEach(Array(top5)) { proc in
                MenuBarTabRow(
                    iconSystemName: "cpu",
                    iconColor: MVMenu.cpu,
                    label: proc.name,
                    value: String(format: "%.1f", proc.cpuPercent),
                    unit: "%"
                )
            }
            if top5.isEmpty {
                placeholder("No process data")
            }
        }
    }

    private var memoryTop: some View {
        let all = monitor.processesData.all
        let top5 = all.sorted(by: { $0.memoryBytes > $1.memoryBytes }).prefix(5)
        return VStack(alignment: .leading, spacing: 0) {
            MenuBarSectionHead("Top Memory", meta: "5 of \(all.count)")
            ForEach(Array(top5)) { proc in
                MenuBarTabRow(
                    iconSystemName: "memorychip",
                    iconColor: MVMenu.memory,
                    label: proc.name,
                    value: formatMemory(proc.memoryBytes)
                )
            }
            if top5.isEmpty {
                placeholder("No process data")
            }
        }
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(.system(size: MVMenu.FS.caption))
            .foregroundStyle(MVMenu.textFaint)
            .padding(.horizontal, 4)
            .padding(.vertical, 12)
    }

    private func formatMemory(_ bytes: UInt64) -> String {
        let mb = Double(bytes) / 1_048_576
        if mb >= 1024 {
            return String(format: "%.2f GB", mb / 1024)
        }
        return String(format: "%.0f MB", mb)
    }
}

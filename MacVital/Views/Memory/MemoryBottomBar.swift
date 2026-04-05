// MacVital/Views/Memory/MemoryBottomBar.swift
import SwiftUI

struct MemoryBottomBar: View {
    let memory: MemoryData
    let diskFreeBytes: UInt64

    private var pressureColor: Color {
        switch memory.pressureLevel {
        case .nominal: return Color(red: 0, green: 0.6, blue: 0.23)
        case .warning: return Color(red: 1, green: 0.57, blue: 0.19)
        case .critical: return Color(red: 1, green: 0.26, blue: 0.27)
        }
    }

    private var swapColor: Color {
        let gb = Double(memory.swapUsed) / 1_073_741_824
        if gb > 4 { return Color(red: 1, green: 0.26, blue: 0.27) }
        if gb > 1 { return Color(red: 1, green: 0.57, blue: 0.19) }
        return Color(white: 0.87)
    }

    private var usedColor: Color {
        let fraction = Double(memory.used) / Double(max(memory.total, 1))
        if fraction > 0.9 { return Color(red: 1, green: 0.26, blue: 0.27) }
        if fraction > 0.75 { return Color(red: 1, green: 0.57, blue: 0.19) }
        return Color(white: 0.87)
    }

    var body: some View {
        HStack(spacing: 0) {
            BottomMetricItem(
                icon: "memorychip",
                iconColor: Color(white: 0.45),
                label: "Physical Memory",
                value: formatGBRound(memory.total),
                valueColor: Color(white: 0.87)
            )

            BottomBarSeparator()

            BottomMetricItem(
                icon: "circle.fill",
                iconColor: usedColor,
                label: "Used",
                value: formatGB(memory.used),
                valueColor: usedColor
            )

            BottomBarSeparator()

            BottomMetricItem(
                icon: "gauge.with.needle",
                iconColor: pressureColor,
                label: "Pressure",
                value: memory.pressureLevel.rawValue,
                valueColor: pressureColor
            )

            BottomBarSeparator()

            BottomMetricItem(
                icon: "arrow.up.arrow.down",
                iconColor: Color(white: 0.45),
                label: "Swap Used",
                value: formatGB(memory.swapUsed),
                valueColor: swapColor
            )

            BottomBarSeparator()

            BottomMetricItem(
                icon: "internaldrive",
                iconColor: Color(white: 0.45),
                label: "Disk Free",
                value: formatGB(diskFreeBytes),
                valueColor: Color(white: 0.87)
            )

            Spacer()

            Text("MACVITALS")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(Color(white: 0.25))
                .padding(.trailing, 16)
        }
        .frame(height: 36)
        .background(Color(white: 0.118))
        .overlay(
            Rectangle()
                .fill(Color(white: 0.18))
                .frame(height: 1),
            alignment: .top
        )
    }

    // MARK: - Formatting

    private func formatGB(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 { return String(format: "%.2f GB", gb) }
        let mb = Double(bytes) / 1_048_576
        if mb >= 1 { return String(format: "%.0f MB", mb) }
        return "0 B"
    }

    private func formatGBRound(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        let rounded = (gb / 4).rounded() * 4
        return "\(Int(rounded)) GB"
    }
}

// MARK: - Bottom Metric Item

struct BottomMetricItem: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    let valueColor: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(iconColor)

            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Color(white: 0.42))

            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(valueColor)
        }
        .padding(.horizontal, 14)
    }
}

// MARK: - Separator

struct BottomBarSeparator: View {
    var body: some View {
        Rectangle()
            .fill(Color(white: 0.18))
            .frame(width: 1, height: 16)
    }
}

// MARK: - Recommendation Bar

struct MemoryRecommendationBar: View {
    let memory: MemoryData

    private var recommendation: String {
        let swapGB = Double(memory.swapUsed) / 1_073_741_824
        let usedFraction = Double(memory.used) / Double(max(memory.total, 1))
        let totalGB = Double(memory.total) / 1_073_741_824

        switch memory.pressureLevel {
        case .critical:
            if swapGB > 4 {
                return "\(String(format: "%.1f", swapGB)) GB swap indicates heavy memory pressure. This workload aligns better with \(Int((totalGB * 2 / 8).rounded(.up) * 8)) GB RAM."
            }
            return "Memory pressure is critical. Close unused applications or consider upgrading RAM."
        case .warning:
            if swapGB > 1 {
                return "\(String(format: "%.1f", swapGB)) GB swap in use. Memory pressure is elevated — consider closing background apps."
            }
            return "Memory pressure is elevated. System is actively managing available RAM."
        case .nominal:
            if usedFraction > 0.8 {
                return "Memory usage is high but pressure is nominal. System is managing memory efficiently."
            }
            return "Memory pressure is nominal. All systems are operating within comfortable limits."
        }
    }

    private var iconName: String {
        switch memory.pressureLevel {
        case .nominal: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.octagon.fill"
        }
    }

    private var iconColor: Color {
        switch memory.pressureLevel {
        case .nominal: return Color(red: 0, green: 0.6, blue: 0.23)
        case .warning: return Color(red: 1, green: 0.57, blue: 0.19)
        case .critical: return Color(red: 1, green: 0.26, blue: 0.27)
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 12))
                .foregroundStyle(iconColor)

            Text(recommendation)
                .font(.system(size: 10))
                .foregroundStyle(Color(white: 0.55))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .background(Color.black)
        .overlay(
            Rectangle()
                .fill(Color(white: 0.18))
                .frame(height: 1),
            alignment: .top
        )
    }
}

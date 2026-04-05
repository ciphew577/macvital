// MacVital/Views/Shared/MenuBarIconPicker.swift
//
// Settings view for choosing the menu bar icon style. Renders a
// grid of cards — each shows a live preview of the icon as it would
// appear in the menu bar, plus a name and description. Tapping a
// card applies it immediately (no save button needed).

import SwiftUI

struct MenuBarIconPicker: View {
    @Environment(AppState.self) private var appState

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Menu Bar Icon")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Choose how MacVital appears in your menu bar. Static icons are lightweight; live styles update every poll cycle.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            // Grid of icon style cards
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(MenuBarIconStyle.allCases) { style in
                    IconStyleCard(
                        style: style,
                        isSelected: appState.menuBarIconStyle == style,
                        monitor: appState.monitor
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appState.menuBarIconStyle = style
                        }
                    }
                }
            }

            // Research note
            VStack(alignment: .leading, spacing: 6) {
                Label("Inspired by the best", systemImage: "sparkles")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fontWeight(.medium)
                Text("Static symbols follow Apple HIG template-image conventions. Live styles draw from Stats.app (sparkline graphs) and TG Pro (temperature readout).")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Individual icon style card

private struct IconStyleCard: View {
    let style: MenuBarIconStyle
    let isSelected: Bool
    let monitor: SystemMonitor

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 10) {
            // Preview area — simulates what the menu bar item looks like
            previewArea
                .frame(height: 36)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected
                              ? Color(nsColor: .controlAccentColor).opacity(0.08)
                              : Color(nsColor: .quaternarySystemFill))
                )

            // Label
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Text(style.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                    if style.isLive {
                        Text("LIVE")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                Capsule()
                                    .fill(Color.green.opacity(0.7))
                            )
                    }
                }
                Text(style.description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered
                      ? Color(nsColor: .quaternarySystemFill)
                      : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isSelected ? Color(red: 0.608, green: 0.769, blue: 0.659) : Color.clear,
                    lineWidth: 2
                )
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .accessibilityLabel("\(style.displayName) menu bar icon")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Preview rendering

    @ViewBuilder
    private var previewArea: some View {
        switch style {
        case .symbolHeartbeat, .symbolGauge, .symbolCPU, .symbolThermometer:
            Image(systemName: style.sfSymbolName ?? "questionmark")
                .font(.system(size: 16))
                .foregroundStyle(.primary)

        case .liveCompositeHealth:
            HStack(spacing: 3) {
                Image(systemName: "heart.text.square")
                    .font(.system(size: 12))
                liveHealthText
            }
            .foregroundStyle(.primary)

        case .liveCPUPercent:
            HStack(spacing: 3) {
                Image(systemName: "cpu")
                    .font(.system(size: 12))
                Text(cpuText)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .monospacedDigit()
            }
            .foregroundStyle(.primary)

        case .liveHottestTemp:
            HStack(spacing: 3) {
                Image(systemName: "thermometer.medium")
                    .font(.system(size: 12))
                Text(tempText)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .monospacedDigit()
            }
            .foregroundStyle(.primary)

        case .liveSparkline:
            HStack(spacing: 3) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 12))
                MiniSparklinePreview(data: monitor.cpuHistory)
                    .frame(width: 36, height: 14)
            }
            .foregroundStyle(.primary)
        }
    }

    private var liveHealthText: some View {
        let cpuHeadroom = max(0, 100 - (monitor.cpu?.totalUsage ?? 0))
        let memScore: Double = {
            switch monitor.memory?.pressureLevel {
            case .nominal: return 95
            case .warning: return 60
            case .critical: return 25
            case nil: return 95
            }
        }()
        let thermalScore: Double = {
            let maxTemp = monitor.sensors?.sensors.map(\.value).max() ?? 0
            if maxTemp >= 95 { return 30 }
            if maxTemp >= 80 { return 60 }
            return 95
        }()
        let composite = Int((cpuHeadroom + memScore + thermalScore) / 3)
        return Text("\(min(99, max(0, composite)))")
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .monospacedDigit()
    }

    private var cpuText: String {
        let cpu = monitor.cpu?.totalUsage ?? 0
        return String(format: "%.0f%%", cpu)
    }

    private var tempText: String {
        let maxTemp = monitor.sensors?.sensors.map(\.value).max() ?? 0
        return maxTemp > 0 ? "\(Int(maxTemp))\u{00B0}" : "--\u{00B0}"
    }
}

// MARK: - Mini sparkline for the picker preview cards

private struct MiniSparklinePreview: View {
    let data: [Double]

    var body: some View {
        GeometryReader { geo in
            let values = data.isEmpty ? [10.0, 25, 15, 40, 30, 50, 35] : data
            let maxVal = max(values.max() ?? 1, 1)
            let step = geo.size.width / CGFloat(max(values.count - 1, 1))

            Path { path in
                for (i, val) in values.enumerated() {
                    let x = CGFloat(i) * step
                    let y = geo.size.height - (CGFloat(val / maxVal) * geo.size.height)
                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(Color.primary.opacity(0.6), lineWidth: 1)
        }
    }
}

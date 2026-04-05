// MacVital/Views/Network/v2/NetworkSparkCards.swift
//
// Six-card spark row for the Network V2 tab (variant-f-fusion, 2026-04-23).
//
// HTML reference: .card-grid (168px, 6 equal columns, no inter-column gap --
// dividers are rendered as 0.5pt right-edge hairlines on each card).
//
// Each card:
//   - Eyebrow label 8.5pt semibold tracked uppercase MV.text3
//   - Big mono number 24pt regular tabular, MV.text1
//   - Unit label mono 11pt MV.text3 baseline-aligned
//   - Sub-caption 9pt MV.text3 (interface name, avg window, etc.)
//   - Sparkline Canvas 40pt tall, 1.5pt sage stroke, sage.opacity(0.22) fill
//   - Delta badge 9pt mono semibold: sage (+), terra (-), text3 (stable)
//
// Focused state: 1pt sage hairline ring + very subtle sage tint background.
// Hover (non-focused): slightly lighter surface.
//
// NetworkSparkCard enum is defined here because it drives UI only. The
// data-stubs agent owns NetworkSparkCardMetrics (the data payload).

import SwiftUI

// MARK: - NetworkSparkCard (UI enum, owned by this file)

enum NetworkSparkCard: String, CaseIterable, Hashable {
    case downloadNow  = "DOWNLOAD NOW"
    case uploadNow    = "UPLOAD NOW"
    case session      = "SESSION"
    case today        = "TODAY"
    case peak24h      = "PEAK 24H"
    case latency      = "LATENCY"
}

// MARK: - NetworkSparkCardsRow

struct NetworkSparkCardsRow: View {

    @Binding var focused: NetworkSparkCard

    /// Per-card metric payloads, one per NetworkSparkCard case.
    /// Supplied by NetworkV2ViewModel.cardMetrics(for:).
    let metrics: [NetworkSparkCard: NetworkSparkCardMetrics]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(NetworkSparkCard.allCases, id: \.self) { card in
                SparkCard(
                    card: card,
                    metrics: metrics[card] ?? .placeholder(for: card),
                    isFocused: focused == card
                ) {
                    focused = card
                }
                // Right hairline divider on all cards except the last.
                if card != NetworkSparkCard.allCases.last {
                    Rectangle()
                        .fill(MV.hairline)
                        .frame(width: 0.5)
                }
            }
        }
        .frame(height: 132)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MV.hairline)
                .frame(height: 0.5)
        }
    }
}

// MARK: - SparkCard

private struct SparkCard: View {

    let card: NetworkSparkCard
    let metrics: NetworkSparkCardMetrics
    let isFocused: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(alignment: .leading, spacing: 0) {

                // Eyebrow label
                Text(card.rawValue)
                    .font(.system(size: 8.5, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(MV.text3)
                    .lineLimit(1)
                    .padding(.bottom, 4)

                // Big number + unit
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(metrics.displayValue)
                        .font(.system(size: 24, weight: .regular).monospacedDigit())
                        .foregroundStyle(MV.text1)
                        .tracking(-0.5)
                        .lineLimit(1)
                    Text(metrics.displayUnit)
                        .font(.system(size: MV.FS.caption, weight: .regular).monospacedDigit())
                        .foregroundStyle(MV.text3)
                        .lineLimit(1)
                }
                .padding(.bottom, 2)

                // Sub-caption
                Text(metrics.subCaption)
                    .font(.system(size: 9))
                    .foregroundStyle(MV.text3)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.bottom, 4)

                // Sparkline
                CardSparkline(data: metrics.sparkData)
                    .frame(height: 40)
                    .padding(.bottom, 4)

                // Footer: delta badge + spacer
                HStack {
                    DeltaBadge(delta: metrics.delta)
                    Spacer(minLength: 0)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(cardBackground)
            .overlay(focusRing)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .metricA11y(
            label: card.rawValue,
            value: "\(metrics.displayValue) \(metrics.displayUnit), \(metrics.subCaption)",
            hint: isFocused ? "Currently focused" : "Focus this metric"
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }

    // MARK: - Visual states

    @ViewBuilder
    private var cardBackground: some View {
        if isFocused {
            MV.accentSage.opacity(0.04)
        } else if isHovered {
            MV.tileHover
        } else {
            MV.tile
        }
    }

    @ViewBuilder
    private var focusRing: some View {
        if isFocused {
            Rectangle()
                .strokeBorder(MV.accentSage.opacity(0.38), lineWidth: 1)
        }
    }
}

// MARK: - CardSparkline

/// Canvas sparkline for a metric card: 1.5pt sage stroke + sage.opacity(0.22) fill.
private struct CardSparkline: View {
    let data: [Double]

    var body: some View {
        Canvas { ctx, size in
            guard data.count >= 2 else { return }

            let minV = data.min() ?? 0
            let maxV = data.max() ?? 1
            let range = max(maxV - minV, 0.0001)
            let stepX = size.width / CGFloat(data.count - 1)

            func yPos(_ v: Double) -> CGFloat {
                let n = (v - minV) / range
                let usable = size.height - 4
                return 2 + (1 - CGFloat(n)) * usable
            }

            // Build the polyline path.
            var line = Path()
            for (i, v) in data.enumerated() {
                let pt = CGPoint(x: CGFloat(i) * stepX, y: yPos(v))
                i == 0 ? line.move(to: pt) : line.addLine(to: pt)
            }

            // Fill region below the line.
            var fill = line
            fill.addLine(to: CGPoint(x: size.width, y: size.height))
            fill.addLine(to: CGPoint(x: 0,           y: size.height))
            fill.closeSubpath()

            ctx.fill(fill, with: .color(MV.accentSage.opacity(0.22)))
            ctx.stroke(line, with: .color(MV.accentSage), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
    }
}

// MARK: - DeltaBadge

private enum DeltaDirection {
    case up, down, stable
}

private struct DeltaBadge: View {
    let delta: String   // e.g. "+12%", "-5%", "stable"

    private var direction: DeltaDirection {
        if delta.hasPrefix("+") { return .up }
        if delta.hasPrefix("-") { return .down }
        return .stable
    }

    private var textColor: Color {
        switch direction {
        case .up:     return MV.accentSage
        case .down:   return MV.critical
        case .stable: return MV.text3
        }
    }

    private var bgColor: Color {
        switch direction {
        case .up:     return MV.accentSage.opacity(0.12)
        case .down:   return MV.critical.opacity(0.12)
        case .stable: return Color.white.opacity(0.04)
        }
    }

    var body: some View {
        Text(delta)
            .font(.system(size: 9, weight: .semibold).monospacedDigit())
            .foregroundStyle(textColor)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(bgColor)
            )
    }
}

// MARK: - NetworkSparkCardMetrics (stub contract for this file)
// The real type is owned by the data-stubs agent and will have more fields
// (time series from SQLite, etc.). This minimal protocol-compatible struct
// ensures the file compiles and previews independently.
//
// If the data-stubs agent defines NetworkSparkCardMetrics differently,
// delete the struct below and keep only the .placeholder extension.

struct NetworkSparkCardMetrics {
    var displayValue: String
    var displayUnit: String
    var subCaption: String
    var sparkData: [Double]
    var delta: String

    static func placeholder(for card: NetworkSparkCard) -> NetworkSparkCardMetrics {
        switch card {
        case .downloadNow:
            return .init(
                displayValue: "0.0",
                displayUnit:  "MB/s",
                subCaption:   "en0 · loading...",
                sparkData:    Array(repeating: 0.0, count: 30),
                delta:        "stable"
            )
        case .uploadNow:
            return .init(
                displayValue: "0.0",
                displayUnit:  "MB/s",
                subCaption:   "en0 · loading...",
                sparkData:    Array(repeating: 0.0, count: 30),
                delta:        "stable"
            )
        case .session:
            return .init(
                displayValue: "0.0",
                displayUnit:  "MB",
                subCaption:   "since launch",
                sparkData:    Array(repeating: 0.0, count: 30),
                delta:        "stable"
            )
        case .today:
            return .init(
                displayValue: "0.0",
                displayUnit:  "GB",
                subCaption:   "30-day total",
                sparkData:    Array(repeating: 0.0, count: 30),
                delta:        "stable"
            )
        case .peak24h:
            return .init(
                displayValue: "0.0",
                displayUnit:  "MB/s",
                subCaption:   "last 24h",
                sparkData:    Array(repeating: 0.0, count: 30),
                delta:        "stable"
            )
        case .latency:
            return .init(
                displayValue: "---",
                displayUnit:  "ms",
                subCaption:   "60s avg",
                sparkData:    Array(repeating: 0.0, count: 30),
                delta:        "stable"
            )
        }
    }
}

// MARK: - Mock helpers for preview

private extension NetworkSparkCardMetrics {
    static let mockDown = NetworkSparkCardMetrics(
        displayValue: "4.52",
        displayUnit:  "MB/s",
        subCaption:   "en0 · Wi-Fi 6 GHz",
        sparkData:    [1.2, 1.8, 3.1, 2.4, 4.1, 4.8, 3.9, 4.52],
        delta:        "+12%"
    )
    static let mockUp = NetworkSparkCardMetrics(
        displayValue: "0.31",
        displayUnit:  "MB/s",
        subCaption:   "en0 · Wi-Fi 6 GHz",
        sparkData:    [0.1, 0.2, 0.35, 0.28, 0.31, 0.29, 0.30, 0.31],
        delta:        "-5%"
    )
    static let mockSession = NetworkSparkCardMetrics(
        displayValue: "842",
        displayUnit:  "MB",
        subCaption:   "since 9:14 AM",
        sparkData:    [100, 210, 380, 490, 600, 710, 800, 842],
        delta:        "stable"
    )
    static let mockToday = NetworkSparkCardMetrics(
        displayValue: "3.1",
        displayUnit:  "GB",
        subCaption:   "30-day total",
        sparkData:    [0.3, 0.8, 1.2, 1.5, 1.9, 2.4, 2.8, 3.1],
        delta:        "+8%"
    )
    static let mockPeak = NetworkSparkCardMetrics(
        displayValue: "18.4",
        displayUnit:  "MB/s",
        subCaption:   "at 11:32 AM",
        sparkData:    [4.1, 8.2, 14.3, 18.4, 12.1, 6.0, 3.5, 2.2],
        delta:        "+3%"
    )
    static let mockLatency = NetworkSparkCardMetrics(
        displayValue: "12",
        displayUnit:  "ms",
        subCaption:   "60s avg · 8.8.8.8",
        sparkData:    [14, 12, 11, 13, 12, 10, 11, 12],
        delta:        "stable"
    )
}

// MARK: - Preview

#if DEBUG
#Preview("SparkCardsRow · populated") {
    let mockMetrics: [NetworkSparkCard: NetworkSparkCardMetrics] = [
        .downloadNow: .mockDown,
        .uploadNow:   .mockUp,
        .session:     .mockSession,
        .today:       .mockToday,
        .peak24h:     .mockPeak,
        .latency:     .mockLatency,
    ]
    struct Harness: View {
        @State private var focused: NetworkSparkCard = .downloadNow
        let metrics: [NetworkSparkCard: NetworkSparkCardMetrics]
        var body: some View {
            NetworkSparkCardsRow(focused: $focused, metrics: metrics)
                .frame(width: 1_100)
                .background(MV.bg)
        }
    }
    return Harness(metrics: mockMetrics)
}

#Preview("SparkCardsRow · placeholders") {
    struct Harness: View {
        @State private var focused: NetworkSparkCard = .latency
        var body: some View {
            NetworkSparkCardsRow(focused: $focused, metrics: [:])
                .frame(width: 1_100)
                .background(MV.bg)
        }
    }
    return Harness()
}
#endif

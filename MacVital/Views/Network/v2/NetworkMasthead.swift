// MacVital/Views/Network/v2/NetworkMasthead.swift
//
// Masthead band for the Network V2 tab (variant-f-fusion, 2026-04-23).
//
// Height: 40pt fixed, MV.tile background, 0.5pt bottom hairline.
//
// Layout (left to right):
//   "MACVITAL" micro semibold MV.text3 tracked
//   1pt vertical separator 14pt tall MV.hairlineStrong
//   "NETWORK"  micro semibold MV.text1 tracked
//   flex spacer
//   pulsing 5pt sage dot
//   "LIVE" micro tracked MV.text3
//   throughput row: down-arrow + speed + up-arrow + speed (mono tabular)
//   time-range chip row: Session / Today / 7D / 30D / All
//
// Bindings owned by NetworkViewV2; liveDownBps / liveUpBps come from
// NetworkV2ViewModel (data-stubs agent).

import SwiftUI

// MARK: - NetworkMasthead

struct NetworkMasthead: View {

    @Binding var selectedRange: NetworkTimeRange

    /// Current download speed in bytes-per-second. 0 when no live data.
    let liveDownBps: Double
    /// Current upload speed in bytes-per-second. 0 when no live data.
    let liveUpBps: Double

    var body: some View {
        HStack(spacing: 0) {

            // -- Brand strip --------------------------------------------------
            brandStrip

            // -- Flex spacer --------------------------------------------------
            Spacer(minLength: MV.S.s4)

            // -- Live badge ---------------------------------------------------
            liveBadge

            // -- Throughput readouts -----------------------------------------
            throughputRow
                .padding(.leading, MV.S.s4)

            // -- Time-range chips --------------------------------------------
            rangeChipRow
                .padding(.leading, MV.S.s4)
                .padding(.trailing, MV.S.s4)
        }
        .frame(height: 40)
        .frame(maxWidth: .infinity)
        .background(MV.tile)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MV.hairline)
                .frame(height: 0.5)
        }
        .padding(.leading, MV.S.s4)
    }

    // MARK: - Sub-views

    private var brandStrip: some View {
        HStack(spacing: 0) {
            Text("MACVITAL")
                .font(.system(size: MV.FS.micro, weight: .semibold))
                .tracking(2.0)
                .foregroundStyle(MV.text3)

            // 1pt vertical rule
            Rectangle()
                .fill(MV.hairlineStrong)
                .frame(width: 1, height: 14)
                .padding(.horizontal, MV.S.s2)

            Text("NETWORK")
                .font(.system(size: MV.FS.micro, weight: .semibold))
                .tracking(2.0)
                .foregroundStyle(MV.text1)
        }
    }

    private var liveBadge: some View {
        HStack(spacing: 5) {
            PulsingDot()
            Text("LIVE")
                .font(.system(size: MV.FS.micro, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(MV.text3)
        }
    }

    private var throughputRow: some View {
        HStack(spacing: 12) {
            // Download speed
            HStack(spacing: 4) {
                Text("▼")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(MV.accentSage)
                throughputLabel(bps: liveDownBps)
            }
            // Upload speed
            HStack(spacing: 4) {
                Text("▲")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(MV.warning)
                throughputLabel(bps: liveUpBps)
            }
        }
    }

    private func throughputLabel(bps: Double) -> some View {
        let (value, unit) = formatBps(bps)
        return HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(value)
                .font(.system(size: MV.FS.caption, weight: .medium).monospacedDigit())
                .foregroundStyle(MV.text1)
            Text(unit)
                .font(.system(size: 9, weight: .regular).monospacedDigit())
                .foregroundStyle(MV.text3)
        }
    }

    private var rangeChipRow: some View {
        HStack(spacing: 2) {
            ForEach(NetworkTimeRange.allCases, id: \.self) { range in
                RangeChip(label: range.label, isActive: selectedRange == range) {
                    selectedRange = range
                }
            }
        }
    }

    // MARK: - Helpers

    /// Converts bytes-per-second to a (value, unit) string pair.
    private func formatBps(_ bps: Double) -> (String, String) {
        switch bps {
        case ..<1_000:           return (String(format: "%.0f", bps),         "B/s")
        case ..<1_000_000:       return (String(format: "%.1f", bps / 1_000), "KB/s")
        case ..<1_000_000_000:   return (String(format: "%.1f", bps / 1_000_000), "MB/s")
        default:                 return (String(format: "%.2f", bps / 1_000_000_000), "GB/s")
        }
    }
}

// MARK: - PulsingDot

/// 5pt filled circle that fades between 0.4 and 1.0 on a 0.8s ease-in-out
/// toggle. Driven by a paused-when-inactive Timer publisher rather than
/// TimelineView(.animation), to avoid 60-120 Hz redraws for a tiny dot.
/// Honours accessibilityReduceMotion (static full-opacity dot).
private struct PulsingDot: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var on: Bool = false

    private let pulse = Timer.publish(every: 0.8, on: .main, in: .common).autoconnect()

    var body: some View {
        Circle()
            .fill(MV.accentSage)
            .frame(width: 5, height: 5)
            .opacity(reduceMotion ? 1.0 : (on ? 1.0 : 0.4))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.8), value: on)
            .onReceive(pulse) { _ in
                guard !reduceMotion, scenePhase == .active else { return }
                on.toggle()
            }
    }
}

// MARK: - RangeChip

private struct RangeChip: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .tracking(0.8)
                .foregroundStyle(isActive ? MV.accentSage : MV.text3)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isActive ? MV.accentSage.opacity(0.08) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(
                            isActive ? MV.accentSage.opacity(0.30) : Color.clear,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }
}

// NetworkTimeRange lives in NetworkV2Types.swift; imports are intra-module
// so no stand-in stub needed.

// MARK: - Preview

#if DEBUG
#Preview("Masthead · live") {
    // Uses the real NetworkTimeRange from the data-stubs agent in a full
    // build. In isolation, substitute a @State wrapper.
    struct Harness: View {
        @State private var range: NetworkTimeRange = .sevenDays
        var body: some View {
            NetworkMasthead(
                selectedRange: $range,
                liveDownBps: 4_521_000,
                liveUpBps: 312_000
            )
            .frame(width: 1_100)
            .background(MV.bg)
        }
    }
    return Harness()
}

#Preview("Masthead · idle") {
    struct Harness: View {
        @State private var range: NetworkTimeRange = .today
        var body: some View {
            NetworkMasthead(
                selectedRange: $range,
                liveDownBps: 0,
                liveUpBps: 0
            )
            .frame(width: 1_100)
            .background(MV.bg)
        }
    }
    return Harness()
}
#endif

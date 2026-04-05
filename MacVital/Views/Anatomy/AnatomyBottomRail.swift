// MacVital/Views/Anatomy/AnatomyBottomRail.swift
//
// Anatomy bottom rail (Wave 2B of native Anatomy port).
//
// Six equal-width subsystem cards sitting under the Anatomy hero. Each card
// shows: header (colored dot + category label + component IDs), one hero
// stat (large value + unit), a small sparkline, and one secondary k/v.
//
// Reference mockup (bottom-rail section):
//   mockups/redesign-2026-04-23/anatomy/fusion-1-bento-schematic.html
//
// Design tokens come from `MVColors.swift` (MV.tile, MV.hairline, MV.text*,
// etc). The sparkline reuses the shared `MVSparkline` from the Overview
// pane so the visual language stays one family.
//
import SwiftUI

// MARK: - Card model

/// One subsystem card in the rail. Pure data, rendered by `AnatomyCard`.
struct AnatomyRailCard: Identifiable, Hashable {
    let id: String
    let category: AnatomyCategory
    let label: String
    let pairs: [AnatomyComponentID]
    let heroValue: String
    let heroUnit: String
    let secondaryLabel: String
    let secondaryValue: String

    /// First pair in the card. Driver for hover and dim state. Falls back
    /// to U1 when the card has no associated pairs (defensive only).
    var primaryPair: AnatomyComponentID { pairs.first ?? .u1 }

    /// Comma joined component IDs displayed in the header (uppercase).
    var pairsLabel: String {
        pairs.map { $0.rawValue.uppercased() }.joined(separator: ", ")
    }
}

extension AnatomyRailCard {
    /// Default rail layout, in display order.
    static let defaultRail: [AnatomyRailCard] = [
        AnatomyRailCard(
            id: "power",
            category: .power,
            label: "Power",
            pairs: [.bt1, .ic1],
            heroValue: "85",
            heroUnit: "%",
            secondaryLabel: "Draw",
            secondaryValue: "3.7 W"
        ),
        AnatomyRailCard(
            id: "cooling",
            category: .cooling,
            label: "Cooling",
            pairs: [.fan1, .fan2],
            heroValue: "2,816",
            heroUnit: "RPM",
            secondaryLabel: "Duty",
            secondaryValue: "36 %"
        ),
        AnatomyRailCard(
            id: "storage",
            category: .storage,
            label: "Storage",
            pairs: [.u3],
            heroValue: "7.3",
            heroUnit: "GB/S",
            secondaryLabel: "Used",
            secondaryValue: "43 %"
        ),
        AnatomyRailCard(
            id: "audio",
            category: .audio,
            label: "Audio",
            pairs: [.spk1],
            heroValue: "-14.2",
            heroUnit: "DBFS",
            secondaryLabel: "Mode",
            secondaryValue: "SPATIAL"
        ),
        AnatomyRailCard(
            id: "wireless",
            category: .wireless,
            label: "Wireless",
            pairs: [.ant1, .ant2],
            heroValue: "-53",
            heroUnit: "DBM",
            secondaryLabel: "SSID",
            secondaryValue: "Home-5G"
        ),
        AnatomyRailCard(
            id: "display",
            category: .display,
            label: "Display",
            pairs: [.lcd1],
            heroValue: "538",
            heroUnit: "NITS",
            secondaryLabel: "Rfrsh",
            secondaryValue: "120 Hz"
        ),
    ]
}

// MARK: - Stub sparkline data

/// 24 normalized samples (sine + small jitter). Wave 3 will swap this for
/// real per-pair history pulled from `SystemMonitor`.
private func stubSparkline(seed: Int) -> [Double] {
    let count = 24
    var out: [Double] = []
    out.reserveCapacity(count)
    for i in 0..<count {
        let phase = Double(i) / Double(count - 1) * .pi * 2
        let base = (sin(phase + Double(seed) * 0.7) + 1) / 2          // 0...1
        let jitterSeed = Double((i &* 31) &+ seed &* 17)
        let jitter = (sin(jitterSeed) + 1) / 2 * 0.18 - 0.09          // +/- 0.09
        out.append(min(1, max(0, base * 0.7 + 0.15 + jitter)))
    }
    return out
}

// MARK: - AnatomyBottomRail

struct AnatomyBottomRail: View {
    @Bindable var viewModel: AnatomyViewModel
    var cards: [AnatomyRailCard] = AnatomyRailCard.defaultRail

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(MV.hairline)
                .frame(height: 1)

            HStack(spacing: 14) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    AnatomyCard(
                        card: card,
                        sparkline: stubSparkline(seed: index),
                        viewModel: viewModel
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - AnatomyCard

private struct AnatomyCard: View {
    let card: AnatomyRailCard
    let sparkline: [Double]
    @Bindable var viewModel: AnatomyViewModel
    @State private var isHovering: Bool = false

    private var isFilteredOut: Bool {
        viewModel.activeFilter != .all && card.category != viewModel.activeFilter
    }

    private var isPinDimmed: Bool {
        // Cards only dim from a pin when the pinned component is part of a
        // different card. If the pinned component IS one of this card's pairs,
        // this card stays bright. This avoids wiping out the whole rail every
        // time someone pins a perimeter block.
        if let pinned = viewModel.pinnedID, !card.pairs.contains(pinned) {
            return true
        }
        return false
    }

    /// Match the HTML rule `.page-grid.has-cat-filter .card { opacity: 0.25 }`.
    /// We only dim from a category filter, never from a pin alone, so the
    /// rail behaviour mirrors the source mockup exactly.
    private var dim: Bool { isFilteredOut }

    private var background: Color {
        isHovering ? MV.tileHover : MV.tile
    }

    private var borderColor: Color {
        isHovering ? MV.hairlineStrong : MV.hairline
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header row: dot + category + component IDs.
            HStack(spacing: 8) {
                Circle()
                    .fill(card.category.accentColor)
                    .frame(width: 8, height: 8)

                Text(card.label.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(MV.text3)

                Spacer(minLength: 4)

                Text(card.pairsLabel)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(MV.text4)
                    .lineLimit(1)
            }

            Spacer().frame(height: 12)

            // Hero stat: large numeric + unit.
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(card.heroValue)
                    .font(.system(size: 36, weight: .semibold, design: .monospaced))
                    .foregroundStyle(MV.text1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(card.heroUnit)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(MV.text3)
                    .baselineOffset(1)
            }

            Spacer().frame(height: 8)

            // Sparkline.
            MVSparkline(
                data: sparkline,
                color: card.category.accentColor.opacity(0.7),
                fillOpacity: 0.10,
                strokeWidth: 1,
                showNowDot: true
            )
            .frame(width: 60, height: 24)

            Spacer().frame(height: 8)

            // Secondary k/v row.
            HStack {
                Text(card.secondaryLabel.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(MV.text3)

                Spacer(minLength: 4)

                Text(card.secondaryValue)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(MV.text2)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(background)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .opacity(dim ? 0.25 : 1)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
            viewModel.hoveredID = hovering ? card.primaryPair : nil
        }
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .animation(.easeOut(duration: 0.15), value: dim)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("AnatomyBottomRail") {
    AnatomyBottomRail(viewModel: AnatomyViewModel())
        .padding(24)
        .background(MV.bg)
}

#Preview("AnatomyBottomRail (filter: cooling)") {
    let vm = AnatomyViewModel()
    vm.activeFilter = .cooling
    return AnatomyBottomRail(viewModel: vm)
        .padding(24)
        .background(MV.bg)
}

#Preview("AnatomyBottomRail (pinned: bt1)") {
    let vm = AnatomyViewModel()
    vm.pinnedID = .bt1
    return AnatomyBottomRail(viewModel: vm)
        .padding(24)
        .background(MV.bg)
}
#endif

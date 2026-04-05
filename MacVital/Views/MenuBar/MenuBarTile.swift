// MacVital/Views/MenuBar/MenuBarTile.swift
//
// Reusable 126×74 control-center tile with SF Symbol icon tinted by
// category hue, caps label, hero value with optional unit, and a
// pill subtitle. Corner severity dot overlays only when watch/crit.
//
// Anatomy (matches v4 mockup):
//   [icon 22pt · label caps]
//   [value 20pt tabular]
//   [pill 10pt dim]

import SwiftUI

struct MenuBarTile: View {
    let iconSystemName: String
    let iconColor: Color
    let label: String
    let value: String
    let unit: String?
    let subtitle: String
    let severity: TileSeverity

    @State private var isHovering = false

    enum TileSeverity {
        case nominal
        case watch
        case critical

        /// Corner-dot colour — only fires on watch / critical.
        /// Watch reads as sage (elevated but OK), critical as terracotta.
        var dotColor: Color? {
            switch self {
            case .nominal:  return nil
            case .watch:    return MVMenu.sevOk
            case .critical: return MVMenu.sevBad
            }
        }

        /// Value-digit colour overlay per v4-colour-semantic rule.
        /// At rest the hero value renders in warm text; on watch it
        /// sages, on critical it terracotta-flips. Amber warn is
        /// reserved for metrics approaching — wire from the tile owner
        /// when you have a numeric threshold.
        var valueColor: Color {
            switch self {
            case .nominal:  return MVMenu.text
            case .watch:    return MVMenu.sevOk
            case .critical: return MVMenu.sevBad
            }
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            tileContent
                .padding(EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 12))
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: MVMenu.Geo.tileHeight)
                .background(isHovering ? MVMenu.tileHover : MVMenu.tile)
                .overlay(alignment: .leading) {
                    // Left accent bar (sage) on hover — matches mockup
                    Rectangle()
                        .fill(isHovering ? MVMenu.accent : Color.clear)
                        .frame(width: 2, height: 53)
                        .clipShape(
                            RoundedRectangle(cornerRadius: 1)
                        )
                        .padding(.leading, 0)
                }
                .clipShape(RoundedRectangle(cornerRadius: MVMenu.Geo.tileRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: MVMenu.Geo.tileRadius)
                        .strokeBorder(MVMenu.hair, lineWidth: 0.5)
                )
                .animation(.easeOut(duration: 0.14), value: isHovering)
                .onHover { isHovering = $0 }

            // Corner severity dot — only when not nominal.
            if let dot = severity.dotColor {
                Circle()
                    .fill(dot)
                    .frame(width: 5, height: 5)
                    .padding(EdgeInsets(top: 7, leading: 0, bottom: 0, trailing: 7))
            }
        }
    }

    private var tileContent: some View {
        HStack(alignment: .center, spacing: 10) {
            // Icon — 26×26 frame, 20 pt glyph.
            ZStack {
                Image(systemName: iconSystemName)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(iconColor.opacity(0.85))
            }
            .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 1) {
                // Eyebrow label — 10 pt caps, tracked.
                Text(label.uppercased())
                    .font(.system(size: MVMenu.FS.micro, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(MVMenu.textFaint)
                    .lineLimit(1)

                // Hero value — 20 pt display, tabular, tracked tight.
                // Colour flips per semantic state (see `TileSeverity.valueColor`).
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(size: MVMenu.FS.h3, weight: .semibold, design: .default))
                        .tracking(-0.36)
                        .foregroundStyle(severity.valueColor)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    if let unit {
                        Text(unit)
                            .font(.system(size: MVMenu.FS.caption, weight: .regular))
                            .foregroundStyle(MVMenu.textDim)
                    }
                }
                .padding(.top, 2)

                // Subtitle pill — 10 pt, dim, chip background.
                Text(subtitle)
                    .font(.system(size: MVMenu.FS.micro, weight: .medium))
                    .foregroundStyle(MVMenu.textDim)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(MVMenu.pillBg)
                    )
                    .padding(.top, 3)
            }
        }
    }
}

#Preview("Tile grid preview") {
    VStack(spacing: 12) {
        HStack(spacing: 12) {
            MenuBarTile(
                iconSystemName: "cpu",
                iconColor: MVMenu.cpu,
                label: "CPU",
                value: "34",
                unit: "%",
                subtitle: "P 48 · E 12",
                severity: .nominal
            )
            MenuBarTile(
                iconSystemName: "thermometer.medium",
                iconColor: MVMenu.thermal,
                label: "Thermal",
                value: "67",
                unit: "°C",
                subtitle: "Nominal · SOC die",
                severity: .watch
            )
        }
        HStack(spacing: 12) {
            MenuBarTile(
                iconSystemName: "bolt.fill",
                iconColor: MVMenu.power,
                label: "Power",
                value: "14.4",
                unit: "W",
                subtitle: "14.8 in · +0.4 chg",
                severity: .nominal
            )
            MenuBarTile(
                iconSystemName: "memorychip",
                iconColor: MVMenu.memory,
                label: "Memory",
                value: "17.2",
                unit: "/36 GB",
                subtitle: "Nominal · 48% used",
                severity: .nominal
            )
        }
    }
    .padding(16)
    .frame(width: MVMenu.Geo.popWidth)
    .background(MVMenu.popBg)
}

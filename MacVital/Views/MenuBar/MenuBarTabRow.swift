// MacVital/Views/MenuBar/MenuBarTabRow.swift
//
// Stat-row primitive used by the Detail / Network / Procs / Sensors /
// Power tabs. Layout: [16pt icon] [label · meta] [44×12 sparkline] [val].
//
// The sparkline is optional. When `history` is empty, the spark slot is
// reserved (44 pt) but left empty so values stay column-aligned across
// rows that have history vs not.

import SwiftUI

struct MenuBarTabRow: View {
    let iconSystemName: String?
    let iconColor: Color
    let label: String
    let meta: String?
    let history: [Double]
    let value: String
    let unit: String?

    init(
        iconSystemName: String? = nil,
        iconColor: Color = MVMenu.textFaint,
        label: String,
        meta: String? = nil,
        history: [Double] = [],
        value: String,
        unit: String? = nil
    ) {
        self.iconSystemName = iconSystemName
        self.iconColor = iconColor
        self.label = label
        self.meta = meta
        self.history = history
        self.value = value
        self.unit = unit
    }

    var body: some View {
        HStack(spacing: 8) {
            // Icon slot (always 16 pt wide so labels align)
            Group {
                if let name = iconSystemName {
                    Image(systemName: name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(iconColor)
                } else {
                    Color.clear
                }
            }
            .frame(width: 16)

            // Label + meta
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: MVMenu.FS.caption, weight: .regular))
                    .foregroundStyle(MVMenu.text)
                    .lineLimit(1)
                if let meta {
                    Text(meta)
                        .font(.system(size: MVMenu.FS.micro, weight: .regular))
                        .foregroundStyle(MVMenu.textFaint)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Sparkline slot
            MenuBarTabSparkline(samples: history, color: iconColor)
                .frame(width: 44, height: 12)
                .opacity(history.count > 1 ? 0.32 : 0)

            // Value + unit
            HStack(spacing: 1) {
                Text(value)
                    .font(.system(size: MVMenu.FS.caption, weight: .medium, design: .monospaced))
                    .foregroundStyle(MVMenu.text)
                if let unit {
                    Text(unit)
                        .font(.system(size: MVMenu.FS.micro, weight: .regular, design: .monospaced))
                        .foregroundStyle(MVMenu.textDim)
                }
            }
        }
        .padding(.horizontal, 4)
        .frame(height: 26)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MVMenu.hair)
                .frame(height: 0.5)
        }
    }
}

/// 44×12 inline sparkline. Single-pixel stroke with rounded line caps.
/// Caller controls colour and opacity via `color`. Returns an empty
/// shape when fewer than two samples.
struct MenuBarTabSparkline: View {
    let samples: [Double]
    let color: Color

    var body: some View {
        Canvas { context, size in
            guard samples.count > 1 else { return }
            let lo = samples.min() ?? 0
            let hi = samples.max() ?? 1
            let span = max(hi - lo, 1e-6)
            let n = samples.count

            var path = Path()
            for (idx, sample) in samples.enumerated() {
                let x = CGFloat(idx) / CGFloat(n - 1) * size.width
                let normalized = (sample - lo) / span
                let y = size.height - normalized * size.height
                if idx == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round)
            )
        }
    }
}

/// Section header used to group rows inside a tab. Eyebrow text on the
/// left, optional meta text on the right (typically a count or
/// timestamp). Matches the .sect-head grammar in the v6a-refined mockup.
struct MenuBarSectionHead: View {
    let eyebrow: String
    let meta: String?

    init(_ eyebrow: String, meta: String? = nil) {
        self.eyebrow = eyebrow
        self.meta = meta
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(eyebrow)
                .font(.system(size: MVMenu.FS.micro, weight: .regular))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(MVMenu.textFaint)
            Spacer()
            if let meta {
                Text(meta)
                    .font(.system(size: MVMenu.FS.micro, weight: .regular, design: .monospaced))
                    .foregroundStyle(MVMenu.textFaint)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

// MacVital/Views/MenuBar/MenuBarSliderStrip.swift
//
// Full-width slider strip used for Fans (stacked L/R rails) and
// Storage (single rail). Matches v4-control-center-sankey.html
// .strip block: icon 18pt + label caps + right readout + rails.

import SwiftUI

struct MenuBarSliderStrip: View {
    let iconSystemName: String
    let label: String
    let readout: String
    /// One or two rails. Each value is 0...1.
    let rails: [Double]
    /// Icon tint — category hue or slate.
    var iconColor: Color = MVMenu.slate

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: iconSystemName)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(iconColor.opacity(0.85))
                    .frame(width: 18, height: 18)

                Text(label.uppercased())
                    .font(.system(size: MVMenu.FS.micro, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(MVMenu.textFaint)

                Spacer(minLength: 4)

                Text(readout)
                    .font(.system(size: MVMenu.FS.caption, weight: .medium, design: .monospaced))
                    .foregroundStyle(MVMenu.text)
            }

            VStack(spacing: 5) {
                ForEach(Array(rails.enumerated()), id: \.offset) { _, fraction in
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(MVMenu.rail)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(MVMenu.railFill)
                                .frame(
                                    width: geo.size.width * max(0, min(1, fraction))
                                )
                        }
                    }
                    .frame(height: 5)
                }
            }
        }
        .padding(EdgeInsets(top: 10, leading: 14, bottom: 12, trailing: 12))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isHovering ? MVMenu.tileHover : MVMenu.tile)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(isHovering ? MVMenu.accent : Color.clear)
                .frame(width: 2, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 1))
        }
        .clipShape(RoundedRectangle(cornerRadius: MVMenu.Geo.tileRadius))
        .overlay(
            RoundedRectangle(cornerRadius: MVMenu.Geo.tileRadius)
                .strokeBorder(MVMenu.hair, lineWidth: 0.5)
        )
        .animation(.easeOut(duration: 0.14), value: isHovering)
        .onHover { isHovering = $0 }
    }
}

#Preview("Slider strips") {
    VStack(spacing: 12) {
        MenuBarSliderStrip(
            iconSystemName: "fanblades",
            label: "Fans",
            readout: "L 1820 · R 1910 rpm",
            rails: [0.28, 0.294]
        )
        MenuBarSliderStrip(
            iconSystemName: "internaldrive",
            label: "Storage",
            readout: "743 / 994 GB",
            rails: [0.747]
        )
    }
    .padding(16)
    .frame(width: MVMenu.Geo.popWidth)
    .background(MVMenu.popBg)
}

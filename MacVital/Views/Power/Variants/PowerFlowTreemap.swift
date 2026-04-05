import SwiftUI

struct PowerFlowTreemap: View {
    let model: PowerFlowModel

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let total = max(model.wallTotal, 0.0001)
            let dests = model.destinations.filter { $0.watts > 0.05 }
            let stacked = layoutHorizontal(items: dests.map { ($0.id, $0.watts) }, total: total, x: 0, y: 0, w: w, h: h)

            ZStack(alignment: .topLeading) {
                ForEach(dests) { d in
                    if let rect = stacked[d.id] {
                        if d.id == "soc" {
                            socNestedTile(rect: rect, dest: d)
                        } else {
                            simpleTile(rect: rect, color: d.color, label: d.label, watts: d.watts, signed: d.isSigned, charging: model.batteryIsCharging)
                        }
                    }
                }
            }
        }
        .frame(height: 360)
    }

    private func socNestedTile(rect: CGRect, dest: PowerFlowDestination) -> some View {
        let comps = model.socComponents.filter { $0.watts > 0.05 }
        let socSum = max(comps.reduce(0) { $0 + $1.watts }, 0.0001)
        let inset: CGFloat = 8
        let labelHeight: CGFloat = 22
        let inner = CGRect(x: rect.minX + inset, y: rect.minY + labelHeight, width: rect.width - inset * 2, height: rect.height - labelHeight - inset)
        let nested = layoutVertical(items: comps.map { ($0.id, $0.watts) }, total: socSum, x: inner.minX, y: inner.minY, w: inner.width, h: inner.height)
        return ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(dest.color.opacity(0.18))
                .overlay(Rectangle().strokeBorder(dest.color.opacity(0.55), lineWidth: 1))
                .frame(width: rect.width, height: rect.height)
                .offset(x: rect.minX, y: rect.minY)
            HStack(spacing: 6) {
                Text(dest.label.uppercased())
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(1.0)
                    .foregroundStyle(PowerFlowPalette.text2)
                Text(PowerFlowFormat.watts(dest.watts))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(PowerFlowPalette.text1)
                    .monospacedDigit()
            }
            .padding(.leading, 8)
            .offset(x: rect.minX, y: rect.minY + 4)
            ForEach(comps) { c in
                if let r = nested[c.id] {
                    nestedTile(rect: r, color: c.color, label: c.label, watts: c.watts)
                }
            }
        }
    }

    private func simpleTile(rect: CGRect, color: Color, label: String, watts: Double, signed: Bool, charging: Bool) -> some View {
        let displayWatts = signed ? (charging ? -watts : watts) : watts
        return ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(color.opacity(0.85))
                .overlay(Rectangle().strokeBorder(Color.black.opacity(0.20), lineWidth: 0.5))
            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(Color.black.opacity(0.55))
                Text(PowerFlowFormat.watts(displayWatts, signed: signed))
                    .font(.system(size: rect.width > 90 ? 16 : 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.black.opacity(0.85))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .padding(8)
        }
        .frame(width: rect.width, height: rect.height)
        .offset(x: rect.minX, y: rect.minY)
    }

    private func nestedTile(rect: CGRect, color: Color, label: String, watts: Double) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(color.opacity(0.80))
                .overlay(Rectangle().strokeBorder(Color.black.opacity(0.18), lineWidth: 0.5))
            if rect.height > 18 {
                HStack(spacing: 6) {
                    Text(label)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.black.opacity(0.65))
                    Spacer()
                    Text(PowerFlowFormat.watts(watts))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.black.opacity(0.85))
                        .monospacedDigit()
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
            }
        }
        .frame(width: rect.width, height: rect.height)
        .offset(x: rect.minX, y: rect.minY)
    }

    private func layoutHorizontal(items: [(String, Double)], total: Double, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) -> [String: CGRect] {
        var result: [String: CGRect] = [:]
        var cx = x
        for (id, value) in items {
            let width = CGFloat(value / total) * w
            result[id] = CGRect(x: cx, y: y, width: width, height: h)
            cx += width
        }
        return result
    }

    private func layoutVertical(items: [(String, Double)], total: Double, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) -> [String: CGRect] {
        var result: [String: CGRect] = [:]
        var cy = y
        for (id, value) in items {
            let height = CGFloat(value / total) * h
            result[id] = CGRect(x: x, y: cy, width: w, height: height)
            cy += height
        }
        return result
    }
}

// MacVital/Views/Overview/MVSparkline.swift
//
// Canvas-based sparkline for the editorial bento Overview.
//
// One shared component: 1 px stroke, 0.12 fill below, 1.5 px filled "now"
// dot at the right edge. Normalises the data series to its own min/max so
// small variations are still visible.
//
// No animation — redraws when `data` changes. If you want a smooth tween,
// wrap in `.animation(.smooth, value: data)` at the call site.

import SwiftUI

struct MVSparkline: View {
    let data: [Double]
    /// Defaults to `MV.ok` at render time so palette changes propagate.
    var color: Color? = nil
    var fillOpacity: Double = 0.12
    var strokeWidth: CGFloat = 1
    var showNowDot: Bool = true

    private var resolvedColor: Color { color ?? MV.ok }

    var body: some View {
        Canvas { context, size in
            guard data.count >= 2 else { return }

            let minV = data.min() ?? 0
            let maxV = data.max() ?? 1
            // Add a tiny headroom so perfectly flat lines still render mid-box.
            let range = max(maxV - minV, 0.0001)

            let stepX = size.width / CGFloat(data.count - 1)

            func y(for value: Double) -> CGFloat {
                let normalised = (value - minV) / range
                // Leave 2 px of headroom top and bottom.
                let usable = size.height - 4
                return 2 + (1 - CGFloat(normalised)) * usable
            }

            // Build the line path.
            var line = Path()
            for (i, v) in data.enumerated() {
                let point = CGPoint(x: CGFloat(i) * stepX, y: y(for: v))
                if i == 0 {
                    line.move(to: point)
                } else {
                    line.addLine(to: point)
                }
            }

            // Fill path (line + down to bottom).
            var fill = line
            fill.addLine(to: CGPoint(x: size.width, y: size.height))
            fill.addLine(to: CGPoint(x: 0, y: size.height))
            fill.closeSubpath()

            context.fill(fill, with: .color(resolvedColor.opacity(fillOpacity)))
            context.stroke(line, with: .color(resolvedColor), lineWidth: strokeWidth)

            if showNowDot, let last = data.last {
                let p = CGPoint(x: size.width, y: y(for: last))
                let dot = Path(ellipseIn: CGRect(x: p.x - 1.5, y: p.y - 1.5, width: 3, height: 3))
                context.fill(dot, with: .color(resolvedColor))
            }
        }
    }
}

// MARK: - Convenience overloads

extension MVSparkline {
    init(uint64Data: [UInt64], color: Color? = nil) {
        self.init(data: uint64Data.map { Double($0) }, color: color)
    }
}

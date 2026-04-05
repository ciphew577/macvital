// MacVital/Views/MenuBar/MenuBarWidgetView.swift
//
// NSView subclass for menu bar widgets — overrides draw(_:) to render
// directly into the status item button's view hierarchy.
//
// Architecture matches Stats.app (Kit/module/widget.swift):
//   - WidgetWrapper: NSView subclass that overrides draw(_:)
//   - Added as subview of NSStatusItem.button via button.addSubview()
//   - Updates via needsDisplay = true on the main queue
//   - Width changes reported via onWidthChanged callback
//
// MacVital palette: sage #9bc4a8, warm amber #d4a35a, terracotta #c66648.
// Text uses NSColor.controlTextColor / secondaryLabelColor for automatic
// dark/light menu bar adaptation. No vivid neons — muted and calm.

import AppKit
import Foundation

// MARK: - MacVital Menu Bar Palette

struct MVBarPalette {
    static let accent = NSColor(red: 0.608, green: 0.769, blue: 0.659, alpha: 1)      // #9bc4a8 sage
    static let warn = NSColor(red: 0.831, green: 0.659, blue: 0.353, alpha: 1)        // #d4a35a amber
    static let crit = NSColor(red: 0.776, green: 0.400, blue: 0.298, alpha: 1)        // #c66648 terracotta
    static var text: NSColor { .controlTextColor }                                      // adapts to menu bar
    static var textDim: NSColor { .secondaryLabelColor }
    static var textFaint: NSColor { .tertiaryLabelColor }
    static var track: NSColor { .quaternaryLabelColor }
}

// MARK: - Constants (matching Stats Kit/helpers.swift Widget constants)

private enum WidgetConstants {
    static let height: CGFloat = 22  // menu bar height
    static let marginX: CGFloat = 2
    static let marginY: CGFloat = 2
}

// MARK: - Snapshot of monitor data (thread-safe copy for drawing)

private struct WidgetData {
    var cpuUsage: Double = 0
    var cpuUser: Double = 0
    var cpuSystem: Double = 0
    var memoryPct: Double = 0
    var memoryUsedGB: Double = 0
    var memoryTotalGB: Double = 0
    var memoryAppFrac: Double = 0
    var memoryWiredFrac: Double = 0
    var memoryCompressedFrac: Double = 0
    var memoryPressure: Int = 0  // 0=normal, 1=warning, 2=critical
    var temperature: Double = 0
    var power: Double = 0
    var gpuUtil: Double = 0
    var fanRPM: Int = 0
    var netDown: UInt64 = 0
    var netUp: UInt64 = 0
    var batteryPct: Double = -1
    var batteryCharging: Bool = false
    var storagePct: Double = 0
    var cpuHistory: [Double] = []
    var powerHistory: [Double] = []
    var gpuHistory: [Double] = []
    var netDownHistory: [UInt64] = []
}

// MARK: - MenuBarWidgetNSView (Stats WidgetWrapper equivalent)

final class MenuBarWidgetNSView: NSView {

    let module: MenuBarModule
    let widgetType: MenuBarWidgetType

    /// Callback when the view's width changes (Stats pattern: widthHandler)
    var onWidthChanged: ((CGFloat) -> Void)?

    /// Current snapshot of data for drawing
    private var data = WidgetData()

    /// Shadow of the last set width to avoid redundant callbacks
    private var currentWidth: CGFloat

    init(module: MenuBarModule, widgetType: MenuBarWidgetType) {
        self.module = module
        self.widgetType = widgetType

        let initialWidth = Self.estimatedWidth(for: widgetType)
        self.currentWidth = initialWidth

        // Use full menu bar height (22 pt) so the subview fills the button
        // exactly as Stats does. y=0 means the view's origin aligns with
        // the button's bottom edge, no margin offset that could clip drawing.
        // Drawing Y coordinates are calibrated for this 22 pt bounds below.
        super.init(frame: NSRect(
            x: 0,
            y: 0,
            width: initialWidth,
            height: WidgetConstants.height
        ))

        self.canDrawConcurrently = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Click handler closure. Set by MenuBarModuleManager when creating
    /// the status item. Matches Stats.app's `onClick` pattern
    /// (Kit/module/widget.swift line 224-230): the widget view owns
    /// mouseDown and calls a closure instead of relying on the parent
    /// NSStatusBarButton's target/action (which NSView subviews eat).
    var onClick: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        if let onClick {
            onClick()
        } else {
            super.mouseDown(with: event)
        }
    }

    /// Update data snapshot from SystemMonitor. Call on main thread before needsDisplay = true.
    func updateData(from monitor: SystemMonitor) {
        data.cpuUsage = monitor.cpu?.totalUsage ?? 0
        data.cpuUser = monitor.cpu?.userUsage ?? 0
        data.cpuSystem = monitor.cpu?.systemUsage ?? 0

        if let mem = monitor.memory {
            let total = Double(max(mem.total, 1))
            data.memoryPct = Double(mem.used) / total * 100
            data.memoryUsedGB = Double(mem.used) / (1024 * 1024 * 1024)
            data.memoryTotalGB = total / (1024 * 1024 * 1024)
            data.memoryAppFrac = Double(mem.active) / total
            data.memoryWiredFrac = Double(mem.wired) / total
            data.memoryCompressedFrac = Double(mem.compressed) / total
            switch mem.pressureLevel {
            case .critical: data.memoryPressure = 2
            case .warning:  data.memoryPressure = 1
            default:        data.memoryPressure = 0
            }
        }

        data.temperature = monitor.sensors?.sensors.map(\.value).max() ?? 0
        data.power = monitor.socPower
        data.gpuUtil = monitor.gpu?.utilization ?? 0
        data.fanRPM = Int(monitor.sensors?.fans.first?.rpm ?? 0)
        data.netDown = monitor.network?.totalRxBytesPerSec ?? 0
        data.netUp = monitor.network?.totalTxBytesPerSec ?? 0
        data.batteryPct = monitor.battery?.percentage ?? -1
        data.batteryCharging = monitor.battery?.isCharging ?? false

        if let st = monitor.storage, let vol = st.volumes.first {
            data.storagePct = Double(vol.usedBytes) / Double(max(vol.totalBytes, 1)) * 100
        }

        data.cpuHistory = monitor.cpuHistory
        data.powerHistory = monitor.powerHistory
        data.gpuHistory = monitor.gpuUtilHistory
        data.netDownHistory = monitor.networkDownHistory
    }

    // MARK: - draw(_:) — Stats pattern: all rendering here

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let newWidth: CGFloat

        switch widgetType {
        case .text:
            newWidth = drawText()
        case .sparkline:
            newWidth = drawSparkline()
        case .barChart:
            newWidth = drawBarChart()
        case .miniGauge:
            newWidth = drawMiniGauge()
        case .textPair:
            newWidth = drawTextPair()
        case .battery:
            newWidth = drawBattery()
        }

        setWidgetWidth(newWidth)
    }

    // MARK: - Width Management (Stats WidgetWrapper.setWidth pattern)

    private func setWidgetWidth(_ width: CGFloat) {
        let newWidth = max(width, 8)
        guard currentWidth != newWidth else { return }
        currentWidth = newWidth

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.setFrameSize(NSSize(width: newWidth, height: self.frame.height))
            self.onWidthChanged?(newWidth)
        }
    }

    private static func estimatedWidth(for type: MenuBarWidgetType) -> CGFloat {
        // Stats-faithful widths (Kit/constants.swift Widget.width LUT):
        switch type {
        case .text:        return 34  // Mini: 7 pt label + 12 pt value centered
        case .sparkline:   return 38  // LineChart: 32×22 box + 2×2 margin
        case .barChart:    return 36  // BarChart: 30 wide
        case .miniGauge:   return 16  // Tachometer: 14 arc + 2 margin
        case .textPair:    return 42  // Speed: 2-line mono
        case .battery:     return 30  // 22 body + 3 nub + 5 margin
        }
    }

    /// Stats-faithful renderer — NO decorative SF Symbol prefix on widgets.
    /// Stats encodes module identity via the 3-letter label (CPU/RAM/GPU)
    /// printed in 7 pt above the value, not via a glyph. This is the
    /// Bjango/Gruber consensus rule: "match SF Symbols weight, no padding,
    /// monochrome template."
    private var moduleIcon: String? { nil }

    // MARK: - Text Widget (Stats Mini pixel-port)
    //
    // Source: /tmp/stats-research-mb/Kit/Widgets/Mini.swift:108-145
    // Exact spec:
    //   · 7 pt .light label on top row at y=12, full-width centered
    //   · 12 pt .regular value on bottom row at y=1 (or 14 pt when no label)
    //   · Colour = NSColor.textColor (auto light/dark)
    //   · No SF Symbol, no decorative chrome — label IS the identity
    // This is what power users recognise as "Stats-style" and what the
    // Bjango/Gruber/Tonsky consensus calls "native-looking."

    private func drawText() -> CGFloat {
        let (valueStr, unitStr) = textValueAndUnit()
        let combined = unitStr.isEmpty ? valueStr : valueStr + unitStr
        let label = statsLabel()
        let color = textColor()

        let hasLabel = !label.isEmpty
        let valueSize: CGFloat = hasLabel ? 12 : 14
        let labelSize: CGFloat = 7

        let style = NSMutableParagraphStyle()
        style.alignment = .center

        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: valueSize, weight: .regular),
            .foregroundColor: color,
            .paragraphStyle: style,
        ]
        let valueStr_ = NSAttributedString(string: combined, attributes: valueAttrs)
        let valueWidth = ceil(valueStr_.size().width)

        // Width: max of value and label widths + horizontal margins.
        var contentWidth = valueWidth
        if hasLabel {
            let labelAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: labelSize, weight: .light),
                .foregroundColor: color,
                .paragraphStyle: style,
            ]
            let labelStr = NSAttributedString(string: label, attributes: labelAttrs)
            contentWidth = max(contentWidth, ceil(labelStr.size().width))
        }
        let width = contentWidth + WidgetConstants.marginX * 2

        // Stats layout (Mini.swift:122): label at y=12, value at y=1 for an
        // 18 pt bounds. With the new full-height 22 pt bounds (y=0), shift
        // both coordinates up by 2 pt to preserve the same visual spacing:
        //   label: y=14 (was 12), value: y=3 (was 1).
        // This keeps the two-row text block visually centred in the 22 pt bar.
        if hasLabel {
            let labelAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: labelSize, weight: .light),
                .foregroundColor: color,
                .paragraphStyle: style,
            ]
            let rect = CGRect(
                x: WidgetConstants.marginX, y: 14,
                width: contentWidth, height: labelSize
            )
            NSAttributedString(string: label, attributes: labelAttrs).draw(with: rect)
        }

        let valueY: CGFloat = hasLabel ? 3 : (self.bounds.height - valueSize) / 2
        let valueRect = CGRect(
            x: WidgetConstants.marginX, y: valueY,
            width: contentWidth, height: valueSize + 1
        )
        valueStr_.draw(with: valueRect)

        return width
    }

    /// 3-letter uppercase label matching Stats Mini convention:
    /// CPU / RAM / GPU / TMP / PWR / BAT / FAN / NET / SSD.
    /// Returns empty string if widget is too narrow to benefit
    /// (e.g. battery widget has its own custom renderer).
    private func statsLabel() -> String {
        switch module {
        case .cpu:     return "CPU"
        case .memory:  return "RAM"
        case .gpu:     return "GPU"
        case .thermal: return "TMP"
        case .power:   return "PWR"
        case .battery: return "BAT"
        case .fans:    return "FAN"
        case .network: return "NET"
        case .storage: return "SSD"
        }
    }

    /// Draw the leading module SF Symbol if one is configured for this
    /// widget. Returns the contribution to total widget width (icon + gap).
    /// Mutates `x` so the caller can draw subsequent text right after.
    ///
    /// Tints the SF Symbol to `color` by drawing the template image and
    /// overlaying via `.sourceAtop` — the standard AppKit recipe for
    /// recolouring a monochrome NSImage with an arbitrary fill, used by
    /// every Stats-style widget renderer.
    @discardableResult
    private func drawLeadingIcon(at x: inout CGFloat, size: CGFloat, color: NSColor, gap: CGFloat) -> CGFloat {
        guard let symbolName = moduleIcon,
              let raw = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        else { return 0 }

        let cfg = NSImage.SymbolConfiguration(pointSize: size, weight: .regular)
        let symbol = raw.withSymbolConfiguration(cfg) ?? raw

        let tinted = NSImage(size: symbol.size, flipped: false) { rect in
            symbol.draw(in: rect)
            color.set()
            rect.fill(using: .sourceAtop)
            return true
        }

        let imageSize = tinted.size
        let iconY = (self.bounds.height - imageSize.height) / 2
        let rect = NSRect(x: x, y: iconY, width: imageSize.width, height: imageSize.height)
        tinted.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)

        x += imageSize.width + gap
        return imageSize.width + gap
    }

    // MARK: - Sparkline Widget
    //
    // 60-point line chart. 38x14 content area. 1px stroke in sage,
    // 0.12 alpha fill below. Ending with 1.5px "now" dot.

    private func drawSparkline() -> CGFloat {
        // Stats LineChart pixel-port (Kit/Widgets/LineChart.swift:131-181).
        // 32×22 box, 1 pt frame in textColor at 0.5 alpha, mirror-fill
        // under the line at 0.5 alpha. No leading icon — identity via label.
        let history = sparklineData()
        let contentWidth: CGFloat = 32
        let graphHeight: CGFloat = 14
        let yOffset: CGFloat = (self.bounds.height - graphHeight) / 2
        let xOffset: CGFloat = WidgetConstants.marginX
        let width: CGFloat = contentWidth + WidgetConstants.marginX * 2

        guard !history.isEmpty else {
            // Flat placeholder line
            MVBarPalette.track.setStroke()
            let path = NSBezierPath()
            path.move(to: NSPoint(x: xOffset, y: self.bounds.height / 2))
            path.line(to: NSPoint(x: xOffset + contentWidth, y: self.bounds.height / 2))
            path.lineWidth = 0.5
            path.stroke()
            return width
        }

        let color = sparklineColor()
        let displayData = Array(history.suffix(60))
        let maxVal = max(displayData.max() ?? 1, 1)
        let step = contentWidth / CGFloat(max(displayData.count - 1, 1))

        let linePath = NSBezierPath()
        var lastPoint = NSPoint.zero
        for (i, val) in displayData.enumerated() {
            let x = xOffset + CGFloat(i) * step
            let y = yOffset + (CGFloat(val / maxVal) * graphHeight)
            let pt = NSPoint(x: x, y: y)
            if i == 0 {
                linePath.move(to: pt)
            } else {
                linePath.line(to: pt)
            }
            lastPoint = pt
        }

        // Fill below, sage at 0.12 alpha (subtle, not distracting).
        // Defensive cast: Apple guarantees NSBezierPath, but fall back to the
        // original path if a future SDK ever returns a different type.
        let fillPath = (linePath.copy() as? NSBezierPath) ?? linePath
        fillPath.line(to: NSPoint(x: lastPoint.x, y: yOffset))
        fillPath.line(to: NSPoint(x: xOffset, y: yOffset))
        fillPath.close()
        color.withAlphaComponent(0.12).setFill()
        fillPath.fill()

        // Stroke — 1px in sage
        color.setStroke()
        linePath.lineWidth = 1.0
        linePath.lineJoinStyle = .round
        linePath.lineCapStyle = .round
        linePath.stroke()

        // "Now" dot — 1.5px radius, solid sage
        let dotRadius: CGFloat = 1.5
        let dotRect = NSRect(
            x: lastPoint.x - dotRadius,
            y: lastPoint.y - dotRadius,
            width: dotRadius * 2,
            height: dotRadius * 2
        )
        color.setFill()
        NSBezierPath(ovalIn: dotRect).fill()

        return width
    }

    // MARK: - Bar Chart Widget
    //
    // Horizontal stacked bar for CPU user/system/idle. 36x8 bar
    // with 2px rounded corners. User segment in sage, system in
    // secondaryLabelColor, idle in quaternaryLabelColor.

    private func drawBarChart() -> CGFloat {
        // Stats BarChart pixel-port (Kit/Widgets/BarChart.swift).
        let barWidth: CGFloat = 30
        let barHeight: CGFloat = 8
        let cornerRadius: CGFloat = 2
        let barY = (self.bounds.height - barHeight) / 2
        let barX: CGFloat = WidgetConstants.marginX
        let width: CGFloat = barWidth + WidgetConstants.marginX * 2

        let barRect = NSRect(x: barX, y: barY, width: barWidth, height: barHeight)

        // Track background — quaternaryLabelColor (idle)
        MVBarPalette.track.setFill()
        NSBezierPath(roundedRect: barRect, xRadius: cornerRadius, yRadius: cornerRadius).fill()

        let segments = stackedBarSegments()

        // Clip to rounded rect
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: barRect, xRadius: cornerRadius, yRadius: cornerRadius).addClip()

        var xCursor = barX
        for (fraction, color) in segments {
            let segWidth = fraction * barWidth
            if segWidth > 0.5 {
                let segRect = NSRect(x: xCursor, y: barY, width: segWidth, height: barHeight)
                color.setFill()
                NSBezierPath(rect: segRect).fill()
            }
            xCursor += segWidth
        }
        NSGraphicsContext.restoreGraphicsState()

        return width
    }

    // MARK: - Mini Gauge Widget
    //
    // Small arc gauge. 14x14. 270-degree arc from bottom-left.
    // 2px track in quaternaryLabelColor, 2px fill in sage proportional
    // to value. Round line caps.

    private func drawMiniGauge() -> CGFloat {
        let value = gaugeValue()
        let diameter: CGFloat = 14
        let width: CGFloat = diameter + WidgetConstants.marginX * 2
        let center = NSPoint(x: width / 2, y: self.bounds.height / 2)
        let strokeWidth: CGFloat = 2.0
        let radius: CGFloat = (diameter - strokeWidth) / 2

        // 270-degree arc: starts at bottom-left (225 degrees), sweeps 270 clockwise
        let startAngle: CGFloat = 225
        let totalSweep: CGFloat = 270
        let endAngle: CGFloat = startAngle - totalSweep

        // Track — full arc in quaternaryLabelColor
        let trackPath = NSBezierPath()
        trackPath.appendArc(withCenter: center, radius: radius,
                           startAngle: startAngle, endAngle: endAngle, clockwise: true)
        MVBarPalette.track.setStroke()
        trackPath.lineWidth = strokeWidth
        trackPath.lineCapStyle = .round
        trackPath.stroke()

        // Value arc — proportional fill in sage (or warning colours)
        let clamped = min(max(value, 0), 1)
        if clamped > 0.01 {
            let valueEnd = startAngle - totalSweep * CGFloat(clamped)
            let valuePath = NSBezierPath()
            valuePath.appendArc(withCenter: center, radius: radius,
                              startAngle: startAngle, endAngle: valueEnd, clockwise: true)
            gaugeColor(value: value).setStroke()
            valuePath.lineWidth = strokeWidth
            valuePath.lineCapStyle = .round
            valuePath.stroke()
        }

        return width
    }

    // MARK: - Text Pair Widget
    //
    // Stacked two-line text for network. "down 2.4" on top, "up 0.4" below.
    // Both 9pt regular. The arrows are drawn in sage (down) / amber (up).
    // Compact ~38x16.

    private func drawTextPair() -> CGFloat {
        let (line1, line2, color1, color2) = textPairValues()

        let font = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular)

        let attrs1: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color1]
        let attrs2: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color2]

        let str1 = NSAttributedString(string: line1, attributes: attrs1)
        let str2 = NSAttributedString(string: line2, attributes: attrs2)

        let size1 = str1.size()
        let size2 = str2.size()
        let rowHeight = self.bounds.height / 2
        let width = max(size1.width, size2.width) + WidgetConstants.marginX * 2

        // Top line (download), bottom line (upload) — Stats SpeedWidget twoRows pattern
        str1.draw(at: NSPoint(x: WidgetConstants.marginX, y: rowHeight + 1))
        str2.draw(at: NSPoint(x: WidgetConstants.marginX, y: 1))

        return width
    }

    // MARK: - Battery Widget (Stats punchthrough pixel-port)
    //
    // Source: /tmp/stats-research-mb/Kit/Widgets/Battery.swift:180-231
    // Exact spec:
    //   · Body 22×11, 1 pt border, 2 pt corner radius, NSColor.textColor
    //   · Nub 3×4 to the right of the body
    //   · Inner fill: proportional to charge, radius 1 pt
    //   · Percent digit drawn with ctx.setBlendMode(.destinationIn) —
    //     so the digit carves through the coloured fill instead of sitting
    //     on top. This is THE Stats look.
    //   · No external text — everything in one pill.
    //   · Severity tints the fill only; border stays NSColor.textColor.

    private func drawBattery() -> CGFloat {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return 8 }

        let pct = data.batteryPct
        let x: CGFloat = WidgetConstants.marginX
        let bodyWidth: CGFloat = 22
        let bodyHeight: CGFloat = 11
        let nubWidth: CGFloat = 3
        let nubHeight: CGFloat = 4
        let cornerRadius: CGFloat = 2
        let borderWidth: CGFloat = 1.0
        let bodyY = (self.bounds.height - bodyHeight) / 2

        // Body outline — stroked in textColor (adapts to bar theme).
        let bodyRect = NSRect(
            x: x + borderWidth / 2,
            y: bodyY + borderWidth / 2,
            width: bodyWidth - borderWidth,
            height: bodyHeight - borderWidth
        )
        let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: cornerRadius, yRadius: cornerRadius)
        MVBarPalette.text.setStroke()
        bodyPath.lineWidth = borderWidth
        bodyPath.stroke()

        // Nub on the right.
        let nubRect = NSRect(
            x: x + bodyWidth,
            y: bodyY + (bodyHeight - nubHeight) / 2,
            width: nubWidth,
            height: nubHeight
        )
        MVBarPalette.text.setFill()
        NSBezierPath(roundedRect: nubRect, xRadius: 1, yRadius: 1).fill()

        // Unknown battery — draw "?" centered.
        if pct < 0 {
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 8, weight: .bold),
                .foregroundColor: MVBarPalette.text,
                .paragraphStyle: style,
            ]
            NSAttributedString(string: "?", attributes: attrs)
                .draw(with: bodyRect)
            return x + bodyWidth + nubWidth + WidgetConstants.marginX
        }

        // Inner fill — width proportional to charge.
        let innerPadding: CGFloat = 1
        let maxFillWidth = bodyWidth - borderWidth * 2 - innerPadding * 2 - 1
        let fillWidth = max(1, maxFillWidth * CGFloat(pct / 100.0))
        let innerRadius: CGFloat = 1

        let fillColor: NSColor
        if pct < 10 {
            fillColor = MVBarPalette.crit
        } else if pct <= 20 {
            fillColor = MVBarPalette.warn
        } else {
            fillColor = MVBarPalette.text
        }

        let innerRect = NSRect(
            x: x + borderWidth + innerPadding,
            y: bodyY + borderWidth + innerPadding,
            width: fillWidth,
            height: bodyHeight - borderWidth * 2 - innerPadding * 2
        )
        fillColor.setFill()
        NSBezierPath(roundedRect: innerRect, xRadius: innerRadius, yRadius: innerRadius).fill()

        // Percent digit — drawn with .destinationIn so it PUNCHES THROUGH
        // the fill and reveals whatever sits underneath (the bar background).
        // This is line 228-231 of Battery.swift verbatim.
        let fontSize: CGFloat = 8
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let digitAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: NSColor.clear,
            .paragraphStyle: style,
        ]
        let digitRect = CGRect(
            x: x + borderWidth + innerPadding,
            y: (self.bounds.height - (fontSize + 2)) / 2,
            width: maxFillWidth,
            height: fontSize
        )
        let digitStr = NSAttributedString(
            string: "\(Int(pct.rounded()))",
            attributes: digitAttrs
        )

        ctx.saveGState()
        ctx.setBlendMode(.destinationIn)
        digitStr.draw(with: digitRect)
        ctx.restoreGState()

        return x + bodyWidth + nubWidth + WidgetConstants.marginX
    }

    // MARK: - Data Accessors

    private func textValueAndUnit() -> (String, String) {
        switch module {
        case .cpu:
            return ("\(Int(data.cpuUsage))", "%")
        case .memory:
            // Show "15/24" style
            let used = data.memoryUsedGB
            let total = data.memoryTotalGB
            if total > 0 {
                return ("\(Int(used.rounded()))/\(Int(total.rounded()))", "GB")
            }
            return ("--", "GB")
        case .thermal:
            let t = data.temperature
            return (t > 0 ? "\(Int(t))" : "--", "\u{00B0}")
        case .power:
            let w = data.power
            if w >= 10 { return ("\(Int(w))", "W") }
            if w > 0 { return (String(format: "%.1f", w), "W") }
            return ("--", "W")
        case .gpu:
            return ("\(Int(data.gpuUtil))", "%")
        case .fans:
            let rpm = data.fanRPM
            return (rpm > 0 ? "\(rpm)" : "--", "rpm")
        case .network:
            return (formatBytes(data.netDown), "/s")
        case .battery:
            let pct = data.batteryPct
            return (pct >= 0 ? "\(Int(pct))" : "--", "%")
        case .storage:
            let pct = data.storagePct
            return (pct > 0 ? "\(Int(pct))" : "--", "%")
        }
    }

    private func sparklineData() -> [Double] {
        switch module {
        case .cpu, .thermal: return data.cpuHistory
        case .power:         return data.powerHistory
        case .gpu:           return data.gpuHistory
        case .network:       return data.netDownHistory.map { Double($0) }
        default:             return data.cpuHistory
        }
    }

    private func gaugeValue() -> Double {
        switch module {
        case .cpu:     return data.cpuUsage / 100.0
        case .memory:  return data.memoryPct / 100.0
        case .battery: return max(data.batteryPct, 0) / 100.0
        default:       return 0
        }
    }

    private func stackedBarSegments() -> [(CGFloat, NSColor)] {
        switch module {
        case .cpu:
            return [
                (CGFloat(data.cpuUser / 100.0), MVBarPalette.accent),
                (CGFloat(data.cpuSystem / 100.0), MVBarPalette.textDim),
            ]
        case .memory:
            return [
                (CGFloat(data.memoryAppFrac), MVBarPalette.accent),
                (CGFloat(data.memoryWiredFrac), MVBarPalette.textDim),
                (CGFloat(data.memoryCompressedFrac), MVBarPalette.warn),
            ]
        case .gpu:
            return [(CGFloat(data.gpuUtil / 100.0), MVBarPalette.accent)]
        case .storage:
            return [(CGFloat(data.storagePct / 100.0), MVBarPalette.accent)]
        default:
            return [(CGFloat(data.cpuUsage / 100.0), MVBarPalette.accent)]
        }
    }

    private func textPairValues() -> (String, String, NSColor, NSColor) {
        switch module {
        case .network:
            let down = formatBytes(data.netDown)
            let up = formatBytes(data.netUp)
            return ("\u{2193}\(down)", "\u{2191}\(up)", MVBarPalette.text, MVBarPalette.text)
        default:
            return ("--", "--", MVBarPalette.text, MVBarPalette.text)
        }
    }

    // MARK: - Colour Helpers

    /// Colour for the sparkline stroke + fill. Always sage for MacVital identity.
    private func sparklineColor() -> NSColor {
        MVBarPalette.accent
    }

    /// Text value colour — controlTextColor by default, amber for warnings, terracotta for critical.
    private func textColor() -> NSColor {
        switch module {
        case .cpu:
            if data.cpuUsage >= 90 { return MVBarPalette.crit }
            if data.cpuUsage >= 70 { return MVBarPalette.warn }
            return MVBarPalette.text
        case .thermal:
            if data.temperature >= 95 { return MVBarPalette.crit }
            if data.temperature >= 70 { return MVBarPalette.warn }
            return MVBarPalette.text
        case .memory:
            if data.memoryPressure == 2 { return MVBarPalette.crit }
            if data.memoryPressure == 1 { return MVBarPalette.warn }
            return MVBarPalette.text
        case .battery:
            if data.batteryPct >= 0, data.batteryPct < 10 { return MVBarPalette.crit }
            if data.batteryPct >= 0, data.batteryPct <= 20 { return MVBarPalette.warn }
            return MVBarPalette.text
        case .power:
            if data.power >= 30 { return MVBarPalette.crit }
            if data.power >= 20 { return MVBarPalette.warn }
            return MVBarPalette.text
        default:
            return MVBarPalette.text
        }
    }

    /// Gauge arc colour — sage normally, amber/terracotta for thresholds.
    private func gaugeColor(value: Double) -> NSColor {
        if module == .battery {
            if value < 0.10 { return MVBarPalette.crit }
            if value < 0.20 { return MVBarPalette.warn }
            return MVBarPalette.accent
        }
        if value > 0.90 { return MVBarPalette.crit }
        if value > 0.70 { return MVBarPalette.warn }
        return MVBarPalette.accent
    }

    // MARK: - Formatting

    private func formatBytes(_ bytes: UInt64) -> String {
        let kb = Double(bytes) / 1024
        let mb = kb / 1024
        if mb >= 1 { return String(format: "%.1fM", mb) }
        if kb >= 1 { return String(format: "%.0fK", kb) }
        return "0K"
    }
}

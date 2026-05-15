# MacVitals Sunburst Chart — Complete SwiftUI Implementation Spec

Reverse-engineered from: MacVitals.app binary strings + pixel-accurate screenshot analysis
Source app: `/System/Volumes/Data/Volumes/MacVitals/MacVitals.app`
Screenshot resolution: crop_chart.png at 1834×1528px (2× Retina, logical 917×764)
Date: 2026-04-06

---

## 1. OVERALL ARCHITECTURE

The chart has three distinct SwiftUI layers stacked in a `ZStack`:

```
ZStack {
  1. ChartBackground          — filled dark circle (#181921)
  2. Canvas { }               — all ring drawing (annular sectors, icons, labels)
  3. PieChartHoverOverlay      — hover detection (Color.clear + onContinuousHover)
  4. ChartCenterView           — text overlay (ZStack center)
  5. MemorySwapInset           — separate SwapPieChart (not in Canvas, overlaid bottom-right)
}
```

Key insight from binary: `GenericPieChart` is reusable — `MemoryPieChart` and `SwapPieChart` both use it.  
`PieChartCanvas` is the Canvas drawing layer name. `PieChartHoverOverlay` is the hit-testing layer.

---

## 2. EXACT RING GEOMETRY (measured from pixel analysis)

### Chart coordinate system

The chart uses a square canvas. All radii are expressed as fractions of `outerRadius`.

```
outerRadius      = half of the chart square side ≈ 230pt (for ~520pt container)
```

### Ring 1 — Inner Category Ring (solid fills, thick)

| Property | Value | Notes |
|---------|-------|-------|
| Inner radius | `outerRadius × 0.383` | ≈ 88pt at R=230 |
| Outer radius | `outerRadius × 0.643` | ≈ 148pt at R=230 |
| Ring width | `outerRadius × 0.260` | ≈ 60pt thick |
| `innerRadiusRatio` | `~0.595` | inner/outer of this ring only = 88/148 |

### Ring 2 — Outer App Ring (colorful, thinner)

| Property | Value | Notes |
|---------|-------|-------|
| Inner radius | `outerRadius × 0.643` | = outer ring 1 outer radius (flush, gap via gapAngle) |
| Outer radius | `outerRadius × 1.000` | = outerRadius |
| Ring width | `outerRadius × 0.357` | ≈ 82pt thick |

### Gap geometry (`gapAngle` from binary)

| Property | Observed value |
|---------|---------------|
| `gapAngle` | ~0.014 radians (~0.8°) between segments |
| Between inner+outer ring | ~2–3pt pixel gap rendered via radius offset (+2/-2) |
| Minimum visible label slice | `minSliceFractionForLabel` ≈ 0.04 (4% of total) |

### Summary ratio table (all as fraction of `outerRadius`)

```
Donut hole edge:    0.383  (innerInnerRadius)
Inner ring inner:   0.383
Inner ring outer:   0.643  (outerInnerRadius)
Outer ring inner:   0.643
Outer ring outer:   1.000  (outerRadius)
```

### Start angle convention

Both rings start at **-π/2 (top, 12 o'clock)** and sweep **clockwise**.

---

## 3. CATEGORY ORDER AND COLORS

From binary: categories named `category-User Apps`, `category-User Processes`, `system`.

Clockwise order from top (12 o'clock) in the original MacVitals chart:

| # | Category | Inner ring color | Notes |
|---|---------|-----------------|-------|
| 1 | SYSTEM | `#4e5054` (78,80,84) | Top-right quadrant, ~15–20% total |
| 2 | USER PROCESSES | `#727373` (114,115,115) | Left half |
| 3 | USER APPS | `#8c8c8c` (140,140,140) | Bottom/lower-right — contains colorful sub-slices |
| 4 | Free | `#1e2029` near-bg | Very dark, invisible against background |

The SYSTEM category's outer ring slices are also gray (matching inner ring).  
USER APPS outer ring slices use dominant app icon colors (extracted via `ColorExtractor`).  
USER PROCESSES outer ring slices are a slightly darker stripe of thin colored lines.

---

## 4. SYSTEM INNER DETAIL TILES

Inside the SYSTEM sector, the inner ring shows sub-categories as rectangular tiles (card-like arc segments). These appear as the "second ring" only in the SYSTEM area — they are rendered within the inner ring radius range.

From binary confirmed names: `Wired Memory`, `File Cache`, `Compressed`, `Other/System`

These are NOT a separate concentric ring — they are the inner ring's slices for the SYSTEM category, but rendered with rounded rect backgrounds and icons instead of plain fills.

### Tile rendering approach

For each SYSTEM sub-slice that is large enough:
1. Draw the annular sector as usual (fill with base color)
2. Overlay a rounded `NSImage`/icon at the arc midpoint
3. Draw the text label rotated along the arc or radially

### Tile colors

| Sub-category | Background | Icon SF Symbol |
|-------------|-----------|---------------|
| Wired Memory | `#596e96` (89,110,150) | `lock.fill` |
| File Cache | `#7f9ebc` (127,158,188) | `doc.fill` or `internaldrive` |
| Compressed | `#8c8b8b` (140,139,139) | `square.stack.3d.up.fill` |
| Other/System | `#4e5054` (78,80,84) | `gearshape.fill` |

---

## 5. APP ICON COLOR EXTRACTION (`ColorExtractor.swift`)

MacVitals uses the `DominantColors` library (bundled) with `CIKMeans` (Core Image K-means).

The binary exposes these exact algorithm steps (logged strings):
```
Step 1. Prepare image.
Step 2. Get colors from pixels.
Step 3. Filter colors by shade.
Step 4. Sorting by normal.
Step 5. Combine similar colors by shade.
Step 6. Combine similar colors.
Step 6.1. Add colors if count less.
Step 7. Final sorting.
Step 8. Calculate the frequency of colors as a percentage.
```

### Simplified SwiftUI equivalent (without the DominantColors pod)

```swift
import AppKit
import CoreImage

func dominantColor(from icon: NSImage, quality: Int = 8) -> NSColor {
    guard let tiff = icon.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let ciImage = CIImage(bitmapImageRep: bitmap) else {
        return NSColor.gray
    }

    // Scale down for speed
    let scaledSize = CGSize(width: 32, height: 32)
    let scaleFilter = CIFilter(name: "CILanczosScaleTransform")!
    scaleFilter.setValue(ciImage, forKey: kCIInputImageKey)
    scaleFilter.setValue(scaledSize.width / (ciImage.extent.width), forKey: kCIInputScaleKey)
    guard let scaledImage = scaleFilter.outputImage else { return NSColor.gray }

    // Use CIKMeans for cluster extraction
    let kMeansFilter = CIFilter(name: "CIKMeans")!
    kMeansFilter.setValue(scaledImage, forKey: kCIInputImageKey)
    kMeansFilter.setValue(scaledImage.extent, forKey: "inputExtent")
    kMeansFilter.setValue(quality, forKey: "inputCount")          // k=8 clusters
    kMeansFilter.setValue(10, forKey: "inputPasses")
    kMeansFilter.setValue(true, forKey: "inputPerceptual")
    guard let outputImage = kMeansFilter.outputImage else { return NSColor.gray }

    let context = CIContext()
    guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
        return NSColor.gray
    }

    // The output is a 1×k image — each pixel is a cluster center
    // Pick the most saturated non-dark cluster
    let nsImage = NSImage(cgImage: cgImage, size: outputImage.extent.size)
    // ... sample pixels, filter by brightness > 0.2 and saturation > 0.3, pick best
    return bestClusterColor(from: cgImage, count: quality)
}

private func bestClusterColor(from cgImage: CGImage, count: Int) -> NSColor {
    // Sample the k cluster pixels, return the most visually distinct (not too dark, not white)
    var best = NSColor.gray
    var bestScore: CGFloat = 0
    // Render to bitmap, sample each cluster pixel
    // Score = saturation × brightness × (1 - abs(brightness - 0.55))
    // (peaks around medium brightness, high saturation)
    return best
}
```

### Simpler alternative: average color with brightness boost

MacVitals actually stores extracted colors in a `color-cache.json` — it only re-extracts when apps change. For our purposes, use `NSImage.averageColor()` as a fallback.

---

## 6. ICON RENDERING IN SLICES

Large outer ring slices show the app icon clipped to the slice shape. MacVitals achieves this with:

1. Calculate the arc midpoint (`midAngle = (startAngle + endAngle) / 2`)
2. Calculate the mid-radius (`midR = (innerR + outerR) / 2`)
3. Position the icon center at `(cx + midR × cos(midAngle), cy + midR × sin(midAngle))`
4. Clip via Canvas `clip` context with the annular sector path

### SwiftUI Canvas implementation

```swift
// Inside Canvas drawing block
if sliceSpan > 0.08 { // only draw icon if slice > ~5° 
    let iconSize: CGFloat = 16
    let midAngle = (startAngle + endAngle) / 2
    let midR = (outerInnerR + outerR) / 2
    let iconCenter = CGPoint(
        x: cx + midR * cos(midAngle),
        y: cy + midR * sin(midAngle)
    )
    let iconRect = CGRect(
        x: iconCenter.x - iconSize / 2,
        y: iconCenter.y - iconSize / 2,
        width: iconSize,
        height: iconSize
    )
    
    // Clip to slice path before drawing icon
    ctx.withCGContext { cgCtx in
        cgCtx.saveGState()
        // Build the clip path (annular sector)
        let clipPath = annularSectorCGPath(cx: cx, cy: cy, innerR: outerInnerR + 1, outerR: outerR - 1, start: startAngle, end: endAngle)
        cgCtx.addPath(clipPath)
        cgCtx.clip()
        // Draw the NSImage
        if let nsImage = resolvedIcon {
            let cgImg = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)!
            cgCtx.draw(cgImg, in: iconRect)
        }
        cgCtx.restoreGState()
    }
}
```

---

## 7. SLICE LABELS

From binary: `label`, `shortLabel`, `groupLabel`, `groupShortLabel` are separate fields.  
`showLabels`, `showGroupLabels` are boolean controls.  
`minSliceFractionForLabel` gates label visibility.

### Label placement

Labels appear **inside** the ring segment, rotated to follow the arc:

```swift
if sliceSpan > 0.12 { // ~7° minimum for label
    let midAngle = (startAngle + endAngle) / 2
    let labelR: CGFloat
    let fontSize: CGFloat
    
    if isOuterRing {
        labelR = (outerInnerR + outerR) / 2
        fontSize = 10
    } else {
        labelR = (innerInnerR + outerInnerR) / 2
        fontSize = 11
    }
    
    let labelPos = CGPoint(
        x: cx + labelR * cos(midAngle),
        y: cy + labelR * sin(midAngle)
    )
    
    // Rotate text to align with arc tangent
    var textAngle = midAngle + .pi / 2  // tangent = normal + 90°
    // Flip if in bottom half to keep text right-side-up
    if midAngle > 0 && midAngle < .pi {
        textAngle += .pi
    }
    
    ctx.withCGContext { cgCtx in
        cgCtx.saveGState()
        cgCtx.translateBy(x: labelPos.x, y: labelPos.y)
        cgCtx.rotate(by: textAngle)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize),
            .foregroundColor: NSColor(white: 0.87, alpha: 1.0)
        ]
        let str = NSAttributedString(string: sliceLabel, attributes: attrs)
        let size = str.size()
        str.draw(at: CGPoint(x: -size.width / 2, y: -size.height / 2))
        cgCtx.restoreGState()
    }
}
```

For very large slices (>25% of total), the category label appears as a callout line extending outward from the outer ring edge. These are `groupLabel` / `groupShortLabel` strings.

### Outer callout labels (for large segments)

```swift
// Callout line from outer ring edge outward
let calloutStartR = outerR + 4
let calloutEndR = outerR + 18
let textR = outerR + 24

let lineStart = CGPoint(x: cx + calloutStartR * cos(midAngle), y: cy + calloutStartR * sin(midAngle))
let lineEnd = CGPoint(x: cx + calloutEndR * cos(midAngle), y: cy + calloutEndR * sin(midAngle))
let textPos = CGPoint(x: cx + textR * cos(midAngle), y: cy + textR * sin(midAngle))

ctx.stroke(Path { p in p.move(to: lineStart); p.addLine(to: lineEnd) },
           with: .color(Color(white: 0.5)), lineWidth: 1)
// Draw label text at textPos (right-aligned if left half, left-aligned if right half)
```

---

## 8. CENTER VIEW — Three States

### State 1: Default (`ChartCenterDefaultView`)

Shown when no slice is hovered.

```swift
VStack(spacing: 2) {
    Image(systemName: "memorychip")
        .font(.system(size: 16, weight: .light))
        .foregroundStyle(Color(white: 0.35))

    Text(formatGB(usedBytes))
        .font(.system(size: 28, weight: .bold))
        .monospacedDigit()
        .foregroundStyle(Color(red: 1.0, green: 0.259, blue: 0.275))  // #ff4246

    Text("of \(formatGBRound(totalRAM)) RAM")
        .font(.system(size: 12, weight: .regular))
        .foregroundStyle(Color(white: 0.87))

    Text("FOOTPRINT  \(formatGB(footprintBytes))")
        .font(.system(size: 9, weight: .medium))
        .monospacedDigit()
        .foregroundStyle(Color(white: 0.55))
        .tracking(0.5)
}
```

### State 2: App hover (`ChartCenterItemView`)

Shown when hovering an outer ring (app) slice. Observed from live screenshot:

```swift
VStack(spacing: 3) {
    // App icon — 22×22pt, rounded rect clip radius 4pt
    Image(nsImage: hoveredApp.icon ?? defaultIcon)
        .resizable()
        .frame(width: 22, height: 22)
        .clipShape(RoundedRectangle(cornerRadius: 4))

    // App name in hovered color
    Text(hoveredApp.name)
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(hoveredColor)
        .lineLimit(1)

    // Memory value large
    Text(formatGB(hoveredApp.bytes))
        .font(.system(size: 22, weight: .bold))
        .monospacedDigit()
        .foregroundStyle(hoveredColor)

    // Sub-label: % of RAM  
    Text(formatPercentOfRAM(hoveredApp.bytes, totalRAM))
        .font(.system(size: 10))
        .foregroundStyle(Color(white: 0.55))
}
```

From live capture, the hover center shows (example):
- "Wired Memory" (category label when hovering inner ring)
- "5.42 GB" large in the slice color
- "5 216.4 Mibim" (raw mibibytes — subtitle, smaller, dimmed)
- "Monitor bucket" — a small pill button below (SVG icon `memorychip` or `plus.circle`)

### State 3: Category hover (`ChartCenterInlineMetric`)

When hovering the inner ring:

```swift
VStack(spacing: 3) {
    Text(category.label.uppercased())
        .font(.system(size: 9, weight: .semibold))
        .tracking(1.0)
        .foregroundStyle(Color(white: 0.45))

    Text(formatGB(category.bytes))
        .font(.system(size: 24, weight: .bold))
        .monospacedDigit()
        .foregroundStyle(category.color)

    Text(formatPercent(category.bytes, usedBytes))
        .font(.system(size: 10))
        .foregroundStyle(Color(white: 0.55))
}
```

### "Monitor bucket" button (in hover state)

Below the hover info, a small pill button appears:
```swift
Button {
    // add to memory monitor / watchlist
} label: {
    HStack(spacing: 4) {
        Image(systemName: "memorychip")
            .font(.system(size: 9))
        Text("Monitor bucket")
            .font(.system(size: 10))
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 3)
    .background(Color(white: 0.2))
    .clipShape(Capsule())
}
.buttonStyle(.plain)
.foregroundStyle(Color(white: 0.6))
```

---

## 9. SWAP RING (`SwapPieChart` / `MemorySwapInset`)

### Geometry

The swap ring is a **separate, independent SwiftUI view** — NOT part of the main Canvas.  
It is overlaid bottom-right using `.overlay(alignment: .bottomTrailing)` or absolute offset.

From pixel measurements:

| Property | Value |
|---------|-------|
| Outer diameter | ~116pt |
| Ring stroke width | ~20pt (thick relative to diameter) |
| Inner hole diameter | ~76pt |
| Position offset from main chart edge | ~20pt inward from bottom-right |

```swift
struct MemorySwapRing: View {
    let swapUsed: UInt64
    let swapFree: UInt64

    private var total: UInt64 { swapUsed + swapFree }
    private var fraction: Double {
        guard total > 0 else { return 0 }
        return Double(swapUsed) / Double(total)
    }

    var body: some View {
        ZStack {
            // Dark circular background (matches chart bg)
            Circle()
                .fill(Color(red: 0.094, green: 0.098, blue: 0.129))

            // Track ring (empty = dark)
            Circle()
                .stroke(Color(white: 0.165), lineWidth: 20)

            // Used arc (gray fill)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    Color(white: 0.41),   // #696969
                    style: StrokeStyle(lineWidth: 20, lineCap: .butt)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: fraction)

            // Center label
            VStack(spacing: 1) {
                Text(formatSwapGB(swapUsed))
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color(white: 0.87))
                Text("Swap")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(white: 0.55))
            }
        }
        .frame(width: 116, height: 116)
    }
}
```

### Positioning in parent

```swift
// In the chart ZStack:
.overlay(alignment: .bottomTrailing) {
    MemorySwapRing(swapUsed: swapUsed, swapFree: swapFree)
        .padding(.bottom, 24)
        .padding(.trailing, 16)
}
```

The swap ring partially overlaps the outer chart ring — it sits at approximately 75% x, 72% y of the chart area. The dark fill of the swap ring circle covers the overlapped chart portion cleanly.

---

## 10. HOVER SYSTEM

### Binary-confirmed properties
- `hoverTrackingArea` — NSTrackingArea (AppKit — NOT used in SwiftUI Canvas approach)
- `hoverThrottleInterval` — debounce gap (~50ms based on UI feel)
- `lastHoverUpdateTime` — throttle guard timestamp
- `hoverClearWorkItem` — DispatchWorkItem for clearing hover on mouse leave
- `hoveredSlice` / `hoveredItemId` — state properties on the view

### SwiftUI hover implementation

```swift
// PieChartHoverOverlay — transparent rectangle covering the canvas
Color.clear
    .contentShape(Rectangle())
    .onContinuousHover { phase in
        switch phase {
        case .active(let location):
            // Throttle to avoid excessive updates
            let now = Date()
            guard now.timeIntervalSince(lastHoverUpdate) > 0.05 else { return }
            lastHoverUpdate = now
            hoverClearTask?.cancel()
            updateHover(at: location)
        case .ended:
            // Delay clearing hover (prevents flicker on fast mouse)
            hoverClearTask = Task {
                try? await Task.sleep(nanoseconds: 80_000_000) // 80ms
                if !Task.isCancelled {
                    hoveredSliceId = nil
                }
            }
        }
    }
```

### Hit testing algorithm

```swift
func updateHover(at point: CGPoint) {
    let dx = point.x - center.x
    let dy = point.y - center.y
    let dist = sqrt(dx*dx + dy*dy)

    // Normalize angle to [0, 2π] starting at top (12 o'clock)
    var angle = atan2(dy, dx) + .pi/2
    if angle < 0 { angle += 2 * .pi }

    // Check outer ring (app slices)
    if dist >= outerInnerR && dist <= outerR {
        // Walk through app slices to find match
        for (catIdx, cat) in categories.enumerated() {
            for (sliceIdx, slice) in cat.slices.enumerated() {
                let (sliceStart, sliceEnd) = computedSliceAngles[catIdx][sliceIdx]
                if angle >= sliceStart && angle < sliceEnd {
                    setHoveredApp(slice: slice)
                    return
                }
            }
        }
    }

    // Check inner ring (category slices)
    if dist >= innerInnerR && dist < outerInnerR {
        for (catIdx, cat) in categories.enumerated() {
            let (catStart, catEnd) = computedCatAngles[catIdx]
            if angle >= catStart && angle < catEnd {
                setHoveredCategory(cat: cat)
                return
            }
        }
    }

    // Outside all rings
    clearHover()
}
```

### Precomputing angle maps

To avoid redundant calculation on every hover event, precompute all slice angles once:

```swift
struct SliceAngles {
    let start: Double
    let end: Double
    let midAngle: Double
    let midPoint: CGPoint
}

// Computed property that returns a flat map of id → SliceAngles
var sliceAngleMap: [String: SliceAngles] {
    var map: [String: SliceAngles] = [:]
    var angle: Double = -.pi / 2
    for cat in categories {
        let catSpan = Double(cat.bytes) / Double(totalBytes) * 2 * .pi - gapAngle
        let catStart = angle + gapAngle / 2
        map["cat_\(cat.id)"] = SliceAngles(start: catStart, end: catStart + catSpan, ...)
        // ... similarly for app slices within outer ring
        angle += Double(cat.bytes) / Double(totalBytes) * 2 * .pi
    }
    return map
}
```

---

## 11. CANVAS DRAWING — COMPLETE RENDER FUNCTION

```swift
Canvas { ctx, size in
    let cx = size.width / 2
    let cy = size.height / 2
    let scale = min(size.width, size.height) / 520.0

    let outerR    = 230.0 * scale
    let outerInnerR = 148.0 * scale   // boundary between inner/outer ring
    let innerInnerR =  88.0 * scale   // inner hole edge

    // 1. Background circle
    ctx.fill(
        Path(ellipseIn: CGRect(x: cx-outerR-2, y: cy-outerR-2, width: (outerR+2)*2, height: (outerR+2)*2)),
        with: .color(Color(red:0.094, green:0.098, blue:0.129))
    )

    guard totalBytes > 0 else { return }

    // 2. Draw category rings
    var catAngle: Double = -.pi / 2
    for cat in categories {
        let catFrac = Double(cat.bytes) / Double(totalBytes)
        let catSweep = catFrac * 2 * .pi - gapAngle
        let catStart = catAngle + gapAngle / 2
        let catEnd = catStart + catSweep

        // Inner ring (solid category color)
        let innerPath = annularSector(cx, cy, innerInnerR+1, outerInnerR-1, catStart, catEnd)
        ctx.fill(innerPath, with: .color(cat.color))

        // Inner ring labels (category name, rotated)
        if catSweep > 0.12 {
            drawRotatedText(ctx, cat.shortLabel, at: midPoint(cx, cy, (innerInnerR+outerInnerR)/2, catStart, catEnd), angle: midAngle(catStart, catEnd), fontSize: 11*scale)
        }

        // Outer ring (app/process slices)
        let catAppTotal = cat.slices.reduce(0) { $0 + $1.bytes }
        var appAngle = catStart
        for slice in cat.slices {
            guard catAppTotal > 0 else { break }
            let appFrac = Double(slice.bytes) / Double(catAppTotal)
            let appSweep = appFrac * catSweep - gapAngle * 0.3
            let appStart = appAngle + gapAngle * 0.15
            let appEnd = appStart + max(appSweep, 0.001)

            let outerPath = annularSector(cx, cy, outerInnerR+1, outerR, appStart, appEnd)
            let isHovered = hoveredSliceId == slice.id
            ctx.fill(outerPath, with: .color(slice.color.opacity(isHovered ? 1.0 : 0.82)))

            // Highlight ring for hovered slice
            if isHovered {
                ctx.stroke(outerPath, with: .color(Color.white.opacity(0.15)), lineWidth: 1.5)
            }

            // App icon (for large enough slices)
            if appSweep > 0.09 && slice.icon != nil {
                drawIconInSlice(ctx, slice.icon!, cx, cy, outerInnerR, outerR, appStart, appEnd, scale)
            }

            // Slice label (for large enough slices)
            if appSweep > 0.14 {
                let mid = midAngle(appStart, appEnd)
                let labelR = (outerInnerR + outerR) / 2
                let pt = CGPoint(x: cx + labelR * cos(mid), y: cy + labelR * sin(mid))
                drawRotatedText(ctx, slice.shortLabel, at: pt, angle: mid, fontSize: 10*scale)
            }

            appAngle += appFrac * catSweep
        }

        catAngle += catFrac * 2 * .pi
    }

    // 3. Center hole (overdraw)
    ctx.fill(
        Path(ellipseIn: CGRect(x: cx-innerInnerR, y: cy-innerInnerR, width: innerInnerR*2, height: innerInnerR*2)),
        with: .color(Color(red:0.094, green:0.098, blue:0.129))
    )

    // 4. Subtle inner edge highlight
    ctx.stroke(
        Path(ellipseIn: CGRect(x: cx-innerInnerR+0.5, y: cy-innerInnerR+0.5, width: (innerInnerR-0.5)*2, height: (innerInnerR-0.5)*2)),
        with: .color(Color.white.opacity(0.03)),
        lineWidth: 1
    )
}
```

---

## 12. ANNULAR SECTOR PATH HELPER

```swift
func annularSector(
    _ cx: CGFloat, _ cy: CGFloat,
    _ innerR: CGFloat, _ outerR: CGFloat,
    _ startAngle: Double, _ endAngle: Double
) -> Path {
    guard endAngle > startAngle, outerR > innerR else { return Path() }
    var path = Path()

    // Outer arc: startAngle → endAngle (clockwise = false in standard math orientation)
    path.addArc(
        center: CGPoint(x: cx, y: cy),
        radius: outerR,
        startAngle: .radians(startAngle),
        endAngle: .radians(endAngle),
        clockwise: false
    )

    // Line to inner arc end point
    path.addLine(to: CGPoint(
        x: cx + innerR * cos(endAngle),
        y: cy + innerR * sin(endAngle)
    ))

    // Inner arc: endAngle → startAngle (reverse = clockwise: true)
    path.addArc(
        center: CGPoint(x: cx, y: cy),
        radius: innerR,
        startAngle: .radians(endAngle),
        endAngle: .radians(startAngle),
        clockwise: true
    )

    path.closeSubpath()
    return path
}
```

---

## 13. VIEW COMPOSITION AND STATE

```swift
struct MemorySunburstChart: View {

    // MARK: - Input
    let categories: [SunburstCategory]
    let totalRAM: UInt64
    let swapUsed: UInt64
    let swapFree: UInt64
    let footprintBytes: UInt64

    // MARK: - State
    @State private var hoveredSliceId: String? = nil
    @State private var hoveredCategoryId: String? = nil
    @State private var centerState: CenterState = .default
    @State private var lastHoverUpdate: Date = .distantPast
    @State private var hoverClearTask: Task<Void, Never>? = nil

    // MARK: - Geometry constants (normalized, scaled at render time)
    private let baseSize: CGFloat = 520
    private let outerRadius: CGFloat = 230
    private let outerInnerRadius: CGFloat = 148
    private let innerInnerRadius: CGFloat = 88
    private let gapAngle: Double = 0.014

    // MARK: - Derived
    private var totalBytes: UInt64 { categories.reduce(0) { $0 + $1.bytes } }
    private var usedBytes: UInt64 { categories.filter { $0.id != "free" }.reduce(0) { $0 + $1.bytes } }

    enum CenterState: Equatable {
        case `default`
        case hoveredCategory(String)
        case hoveredApp(String, UInt64)
    }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let scale = size / baseSize
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

            ZStack {
                // Drawing canvas
                Canvas { ctx, canvasSize in
                    renderChart(ctx, canvasSize, scale)
                }

                // Hover overlay
                Color.clear
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        handleHoverPhase(phase, center: center, scale: scale)
                    }

                // Center text
                centerView
                    .frame(
                        width: innerInnerRadius * 2 * scale - 12,
                        height: innerInnerRadius * 2 * scale - 12
                    )
                    .animation(.easeInOut(duration: 0.12), value: centerState)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            MemorySwapRing(swapUsed: swapUsed, swapFree: swapFree)
                .padding(.bottom, 20)
                .padding(.trailing, 14)
        }
    }

    @ViewBuilder
    var centerView: some View {
        switch centerState {
        case .default:
            ChartCenterDefaultView(
                usedBytes: usedBytes,
                totalRAM: totalRAM,
                footprintBytes: footprintBytes
            )
        case .hoveredCategory(let catId):
            if let cat = categories.first(where: { $0.id == catId }) {
                ChartCenterCategoryView(category: cat, totalBytes: usedBytes)
            }
        case .hoveredApp(let appName, let bytes):
            ChartCenterAppView(name: appName, bytes: bytes, totalRAM: totalRAM)
        }
    }
}
```

---

## 14. CHART CENTER SUB-VIEWS

```swift
struct ChartCenterDefaultView: View {
    let usedBytes: UInt64
    let totalRAM: UInt64
    let footprintBytes: UInt64

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "memorychip")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(Color(white: 0.35))

            Text(formatGB(usedBytes))
                .font(.system(size: 28, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Color(red: 1.0, green: 0.259, blue: 0.275))

            Text("of \(ramLabel(totalRAM)) RAM")
                .font(.system(size: 12))
                .foregroundStyle(Color(white: 0.87))

            Text("FOOTPRINT  \(formatGB(footprintBytes))")
                .font(.system(size: 9, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Color(white: 0.55))
                .tracking(0.5)
        }
        .multilineTextAlignment(.center)
    }
}

struct ChartCenterCategoryView: View {
    let category: SunburstCategory
    let totalBytes: UInt64

    var body: some View {
        VStack(spacing: 3) {
            Text(category.label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(Color(white: 0.45))

            Text(formatGB(category.bytes))
                .font(.system(size: 22, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(category.color)

            Text(formatPercent(category.bytes, of: totalBytes))
                .font(.system(size: 10))
                .foregroundStyle(Color(white: 0.55))
        }
        .multilineTextAlignment(.center)
    }
}

struct ChartCenterAppView: View {
    let name: String
    let bytes: UInt64
    let totalRAM: UInt64

    var body: some View {
        VStack(spacing: 3) {
            Text(name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(white: 0.85))
                .lineLimit(1)

            Text(formatGB(bytes))
                .font(.system(size: 22, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Color(white: 0.92))

            Text(formatMiB(bytes))
                .font(.system(size: 9))
                .foregroundStyle(Color(white: 0.45))

            // Monitor bucket button
            Button { /* add to watchlist */ } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 9))
                    Text("Monitor bucket")
                        .font(.system(size: 10))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(white: 0.18))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color(white: 0.55))
            .padding(.top, 2)
        }
        .multilineTextAlignment(.center)
    }
}
```

---

## 15. COMPLETE SWIFTUI FILE STRUCTURE

These files map directly to the original MacVitals source file list:

| Our file | Maps to MacVitals file | Purpose |
|---------|----------------------|---------|
| `GenericPieChart.swift` | `GenericPieChart.swift` | Core reusable chart (annularSector, Canvas, hover) |
| `MemoryPieChart.swift` | `MemoryPieChart.swift` | Memory-specific data → GenericPieChart |
| `SwapPieChart.swift` | embedded in MemoryPieChart | Swap donut ring |
| `ChartCenterView.swift` | `ChartCenterView.swift` | Center overlay — 3 states |
| `ColorExtractor.swift` | `ColorExtractor.swift` | Dominant color from NSImage |
| `PieChartRightClickHandler.swift` | `PieChartRightClickHandler.swift` | Right-click context menu |

---

## 16. KEY GEOMETRY CONSTANTS (copy-paste ready)

```swift
// GenericPieChart.swift — geometry constants
static let baseContainerSize: CGFloat = 520   // design-space size (scale everything to this)
static let outerRadius:       CGFloat = 230   // outer edge of outer ring
static let outerInnerRadius:  CGFloat = 148   // inner edge of outer ring = outer edge of inner ring
static let innerInnerRadius:  CGFloat =  88   // inner hole edge
static let gapAngle:          Double  = 0.014 // radians gap between segments (~0.8°)
static let appIconSize:       CGFloat = 16    // app icon in outer ring slice
static let minSliceFracLabel: Double  = 0.04  // hide label if slice < 4% of total
static let minSliceFracIcon:  Double  = 0.06  // hide icon if slice < 6%

// Swap ring
static let swapRingDiameter:   CGFloat = 116
static let swapStrokeWidth:    CGFloat = 20
static let swapBottomPad:      CGFloat = 20
static let swapTrailingPad:    CGFloat = 14

// Derived ratios
// innerInnerRadius / outerRadius = 88/230 = 0.383   (38.3% — donut hole)
// outerInnerRadius / outerRadius = 148/230 = 0.643  (64.3% — ring boundary)
// innerRadiusRatio (binary) = outerInnerRadius/outerRadius = 0.643
```

---

## 17. COLOR CONSTANTS

```swift
// Design tokens matching MacVitals exactly
extension Color {
    static let chartBackground = Color(red: 0.094, green: 0.098, blue: 0.129)  // #181921
    static let chartCenterRed  = Color(red: 1.0, green: 0.259, blue: 0.275)   // #ff4246
    static let chartGapFill    = Color(red: 0.094, green: 0.098, blue: 0.129) // = chartBackground
    static let swapTrack       = Color(white: 0.165)   // #2a2a2a
    static let swapFill        = Color(white: 0.412)   // #696969
    static let ringSystem      = Color(red: 0.306, green: 0.314, blue: 0.329) // #4e5054
    static let ringUserProcs   = Color(white: 0.451)   // #727373
    static let ringUserApps    = Color(white: 0.549)   // #8c8c8c
    static let ringWiredMem    = Color(red: 0.349, green: 0.431, blue: 0.588) // #596e96
    static let ringFileCache   = Color(red: 0.498, green: 0.620, blue: 0.737) // #7f9ebc
}
```

---

## 18. KNOWN DEVIATIONS IN CURRENT IMPLEMENTATION

Current `MemorySunburstChart.swift` vs MacVitals original:

| Aspect | Current code | MacVitals original | Fix needed |
|--------|-------------|-------------------|-----------|
| Ring boundary | outerInnerR=148, innerInnerR=88 | Same — correct | None |
| gapAngle | 0.014 | Same — confirmed by binary | None |
| Hover center text | 3 lines | 4-line with Monitor button | Add Monitor button |
| Swap ring size | 120pt diameter | 116pt diameter | Minor: adjust frame |
| Inner ring SYSTEM tiles | Not rendered as tiles | Rendered as card-like tiles with icons | Add icon rendering |
| Color extraction | NSImage.averageColor | CIKMeans dominant color | Upgrade ColorExtractor |
| App slice icon clip | Not implemented | Clipped to slice shape | Implement ctx.clip |
| Outer callout labels | Not implemented | Callout lines for large segs | Add for slices >20% |
| Right-click menu | Not implemented | PieChartRightClickNSView | Add NSViewRepresentable |
| Hover throttle | Not implemented | 50ms throttle + clear delay | Add throttle guard |

---

## 19. IMPLEMENTATION PRIORITY ORDER

1. **Fix swap ring size** — change 120 → 116pt, lineCap: .butt (not .round)
2. **Add hover throttle** — wrap `onContinuousHover` with 50ms guard + 80ms clear delay  
3. **Add center state machine** — replace current single VStack with 3-state `CenterState` enum
4. **Add Monitor bucket button** — pill button in `ChartCenterAppView` hover state
5. **Add app icon rendering** — `drawIconInSlice()` for slices > 6% threshold
6. **Add label rotation** — rotated text inside arc for inner ring category labels
7. **Upgrade ColorExtractor** — CIKMeans in place of averageColor
8. **Add SYSTEM tile cards** — rounded rect + icon overlaid on inner ring slices
9. **Add callout labels** — line + text for large outer segments
10. **Add right-click handler** — NSViewRepresentable for PieChartRightClickNSView

---

*Spec written from: binary string extraction (MacVitals.app), pixel analysis of crop_chart.png (1834×1528px @2x), live screenshot analysis, and study of existing MacVital project Swift files.*
*All measurements in logical pts (1x scale). Multiply by display scale factor for rendering.*

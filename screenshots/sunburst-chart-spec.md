# MacVitals Sunburst Chart — Technical Spec & Implementation

## Visual Analysis (from screenshots)

### Overall Layout
- Dark background (~#1a1a1a / NSVisualEffectView with `WindowAmbientBackground` material)
- One large main ring (Memory) occupying ~70% of the chart area width
- One smaller inset ring (Swap) positioned bottom-right, roughly 30% the diameter of the main ring
- Center of main ring: large GB number in red/coral, subtitle line "of X GB RAM", then "FOOTPRINT: X GB" in dimmer text
- No outer border or frame on the chart itself — floats on dark background

### Ring Geometry (reverse-engineered from binary + visual)

The binary confirms these field names:
- `innerRadiusRatio` — inner ring radius as a ratio of outer radius
- `gapAngle` — gap between slices (in radians, small value ~0.008 rad / ~0.5 deg)
- `minSliceFractionForLabel` — minimum slice size before label is hidden
- `startAngle` / `endAngle` — per-slice geometry
- `hasSolidSlices` — boolean flag on each slice (used for the inner category ring which has solid fills)
- `groupLabel` / `groupShortLabel` / `shortLabel` — tiered labeling based on slice size

#### Approximate radius ratios (from visual inspection):
| Ring | Inner radius | Outer radius | Notes |
|------|-------------|-------------|-------|
| Inner (categories) | ~35% of chart radius | ~60% of chart radius | Solid fills, thick ring |
| Outer (apps) | ~62% of chart radius | ~100% of chart radius | Thinner, colorful, icons |
| Gap between rings | ~2% of chart radius | — | Dark gap separator |

### Inner Ring — Memory Categories
From binary strings, confirmed category names:
| Category | Color (from screenshot) |
|----------|------------------------|
| User Apps | Multi-colored (delegates to outer ring) |
| User Processes | Dark gray |
| File Cache | Medium gray |
| Wired Memory | Light gray / near-white |
| Compressed | Slightly darker gray |
| Other/System | Darkest gray |
| Free | Near-invisible / very dark |

The inner ring uses `hasSolidSlices = true` and the `groupLabel`/`groupShortLabel` system for labeling. Labels appear as callout lines pointing outward from the inner ring edge on large slices.

### Outer Ring — Apps/Processes
- Each app gets a slice proportional to its `physFootprint` (physical memory footprint)
- Apps grouped under category parent (User Apps, User Processes, etc.)
- Each slice can show an app icon clipped to the slice shape
- `ColorExtractor` / `DominantColors` extracts the dominant color from each app's icon
- Color is used as the fill for that app's outer ring slice
- `color-cache.json` persists extracted colors across sessions
- Hover state: `hoveredSlice` / `hoveredItemId` tracked, `PieChartHoverOverlay` shown

### Center Display
From binary class names:
- `ChartCenterDefaultView` — resting state showing GB / RAM / FOOTPRINT
- `ChartCenterInlineMetric` — inline metric (used when hovering a slice)
- `ChartCenterItemView` — app-specific view shown on hover

Center text layout (top to bottom):
1. App icon (small, ~24px, when hovering an app slice)
2. Large number: "27.8 GB" in coral/red (#e05a5a approx)
3. Subtitle: "of 24 GB RAM" in medium gray
4. Label: "FOOTPRINT: 36.38 GB" in dim gray, smaller, monospaced

### Swap Ring (MemorySwapInset / SwapPieChart)
- Positioned bottom-right of main ring, NOT concentric
- Smaller donut: ~30% diameter of main chart
- Shows swap used vs available
- Center: "5.77 GB / Swap" text
- Single or two-slice donut (used / free)

### Interaction Model
- `hoverTrackingArea` + `hoverThrottleInterval` + `hoverClearWorkItem` = throttled hover updates
- `lastHoverUpdateTime` guards against excessive redraws
- `PieChartRightClickNSView` / `PieChartRightClickHandler` = right-click context menu
- Hover reveals `ChartCenterItemView` with app name, memory, icon
- `isHoveredState` / `isWindowHovered` control overlay visibility

---

## Implementation Architecture Decision

**Recommendation: SVG + vanilla JS (no canvas)**

Reasons:
- SVG `<path>` arcs are declarative and easy to position labels relative to
- Icon clipping to arc slice is achievable with `<clipPath>`
- Hover events are native on SVG elements (no manual hit-testing needed)
- Tooltips and center-text overlay are just absolutely-positioned DOM elements
- Animatable with CSS transitions on `stroke-dasharray` or transform

**Avoid Canvas** unless you need 500+ slices (unlikely for memory chart).

---

## Working HTML Implementation

Save the block below as `sunburst-demo.html` and open in any browser.

```html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>MacVitals Sunburst Chart</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }

  body {
    background: #141414;
    display: flex;
    align-items: center;
    justify-content: center;
    min-height: 100vh;
    font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Display', 'Helvetica Neue', sans-serif;
  }

  .chart-wrapper {
    position: relative;
    width: 560px;
    height: 560px;
  }

  .chart-wrapper svg {
    width: 100%;
    height: 100%;
    overflow: visible;
  }

  /* Center text overlay — positioned over SVG center */
  .chart-center {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    text-align: center;
    pointer-events: none;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 2px;
  }

  .center-icon {
    width: 28px;
    height: 28px;
    border-radius: 6px;
    background: #333;
    margin-bottom: 4px;
    display: none;
  }

  .center-main {
    font-size: 32px;
    font-weight: 700;
    color: #e05555;
    letter-spacing: -0.5px;
    font-variant-numeric: tabular-nums;
  }

  .center-sub {
    font-size: 12px;
    color: #888;
    font-weight: 400;
  }

  .center-footprint {
    font-size: 10px;
    color: #555;
    font-variant-numeric: tabular-nums;
    letter-spacing: 0.3px;
    margin-top: 2px;
  }

  .center-footprint span {
    color: #444;
    font-weight: 600;
    text-transform: uppercase;
    font-size: 9px;
    letter-spacing: 0.8px;
  }

  /* Tooltip */
  .tooltip {
    position: fixed;
    background: rgba(30,30,30,0.95);
    border: 1px solid #333;
    border-radius: 10px;
    padding: 10px 14px;
    pointer-events: none;
    opacity: 0;
    transition: opacity 0.15s ease;
    z-index: 100;
    min-width: 160px;
    backdrop-filter: blur(12px);
  }

  .tooltip.visible { opacity: 1; }

  .tooltip-name {
    font-size: 13px;
    font-weight: 600;
    color: #e8e8e8;
    margin-bottom: 3px;
  }

  .tooltip-mem {
    font-size: 12px;
    color: #888;
    font-variant-numeric: tabular-nums;
  }

  .tooltip-pct {
    font-size: 11px;
    color: #555;
    margin-top: 1px;
  }

  /* Slice hover glow */
  .outer-slice { cursor: pointer; transition: opacity 0.12s; }
  .outer-slice:hover { opacity: 0.85; filter: brightness(1.15); }
  .inner-slice { cursor: default; }

  /* Swap ring container */
  .swap-ring {
    position: absolute;
    bottom: 20px;
    right: 10px;
    width: 130px;
    height: 130px;
  }

  .swap-center {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    text-align: center;
    pointer-events: none;
  }

  .swap-gb { font-size: 14px; font-weight: 700; color: #ccc; font-variant-numeric: tabular-nums; }
  .swap-label { font-size: 9px; color: #555; text-transform: uppercase; letter-spacing: 0.5px; margin-top: 1px; }

  /* Callout labels on inner ring */
  .ring-label {
    fill: #aaa;
    font-size: 10px;
    font-family: -apple-system, sans-serif;
    font-weight: 500;
    pointer-events: none;
  }
</style>
</head>
<body>

<div class="chart-wrapper" id="chartWrapper">
  <!-- SVG injected by JS -->
  <div class="chart-center" id="chartCenter">
    <img class="center-icon" id="centerIcon" src="" alt="">
    <div class="center-main" id="centerMain">27.8 GB</div>
    <div class="center-sub" id="centerSub">of 24 GB RAM</div>
    <div class="center-footprint"><span>Footprint:</span> 36.38 GB</div>
  </div>

  <div class="swap-ring" id="swapRing">
    <div class="swap-center">
      <div class="swap-gb">5.77 GB</div>
      <div class="swap-label">Swap</div>
    </div>
  </div>
</div>

<div class="tooltip" id="tooltip">
  <div class="tooltip-name" id="ttName"></div>
  <div class="tooltip-mem" id="ttMem"></div>
  <div class="tooltip-pct" id="ttPct"></div>
</div>

<script>
// ─── DATA MODEL ───────────────────────────────────────────────────────────────
// Each category has a color for the inner ring and an array of app slices.
// In production this comes from macOS memory APIs (vm_stat, proc_info, etc.)

const TOTAL_RAM_GB = 24;
const USED_GB = 27.8;
const FOOTPRINT_GB = 36.38;
const SWAP_GB = 5.77;

const categories = [
  {
    id: 'user-apps',
    label: 'User Apps',
    shortLabel: 'Apps',
    color: '#3a3a3e',          // inner ring: dark — outer ring slices use app colors
    memGB: 12.4,
    apps: [
      { name: 'zoom.us',      memGB: 3.2,  color: '#2D8CFF' },
      { name: 'Safari',       memGB: 1.8,  color: '#006ECD' },
      { name: 'Xcode',        memGB: 2.1,  color: '#1472DB' },
      { name: 'Slack',        memGB: 0.9,  color: '#4A154B' },
      { name: 'Arc',          memGB: 1.1,  color: '#FF5733' },
      { name: 'Terminal',     memGB: 0.6,  color: '#2C2C2E' },
      { name: 'Other Apps',   memGB: 2.7,  color: '#444' },
    ]
  },
  {
    id: 'user-procs',
    label: 'User Processes',
    shortLabel: 'Procs',
    color: '#2c2c2e',
    memGB: 8.3,
    apps: [
      { name: 'node (2.191)', memGB: 1.4,  color: '#68A063' },
      { name: 'node',         memGB: 1.1,  color: '#5B9A57' },
      { name: 'node',         memGB: 0.9,  color: '#4E8B4B' },
      { name: 'caffeine',     memGB: 0.3,  color: '#8B572A' },
      { name: 'zsh',          memGB: 0.2,  color: '#555' },
      { name: 'Other Procs',  memGB: 4.4,  color: '#3a3a3e' },
    ]
  },
  {
    id: 'file-cache',
    label: 'File Cache',
    shortLabel: 'Cache',
    color: '#3d3d3f',
    memGB: 4.2,
    apps: [
      { name: 'File Cache',   memGB: 4.2,  color: '#5a5a5e' },
    ]
  },
  {
    id: 'wired',
    label: 'Wired Mem.',
    shortLabel: 'Wired',
    color: '#6b6b70',
    memGB: 2.1,
    apps: [
      { name: 'Wired Memory', memGB: 2.1,  color: '#8a8a90' },
    ]
  },
  {
    id: 'compressed',
    label: 'Compressed',
    shortLabel: 'Comp.',
    color: '#4a4a4f',
    memGB: 0.8,
    apps: [
      { name: 'Compressed',   memGB: 0.8,  color: '#6a6a6f' },
    ]
  },
];

// ─── GEOMETRY CONSTANTS ───────────────────────────────────────────────────────
const CX = 280, CY = 280;           // SVG center
const OUTER_R = 255;                 // outer ring outer radius
const OUTER_INNER_R = 165;          // outer ring inner radius (= inner ring outer radius)
const INNER_INNER_R = 95;           // inner ring inner radius (the "hole")
const GAP_ANGLE = 0.012;            // radians gap between slices
const START_ANGLE = -Math.PI / 2;   // 12 o'clock
const MIN_LABEL_FRAC = 0.04;        // min fraction to show label on outer slice

// ─── HELPERS ──────────────────────────────────────────────────────────────────
function polarToXY(cx, cy, r, angle) {
  return {
    x: cx + r * Math.cos(angle),
    y: cy + r * Math.sin(angle),
  };
}

function arcPath(cx, cy, rInner, rOuter, startA, endA) {
  // SVG arc path for an annular sector (donut slice)
  const p1 = polarToXY(cx, cy, rOuter, startA);
  const p2 = polarToXY(cx, cy, rOuter, endA);
  const p3 = polarToXY(cx, cy, rInner, endA);
  const p4 = polarToXY(cx, cy, rInner, startA);
  const large = (endA - startA) > Math.PI ? 1 : 0;

  return [
    `M ${p1.x} ${p1.y}`,
    `A ${rOuter} ${rOuter} 0 ${large} 1 ${p2.x} ${p2.y}`,
    `L ${p3.x} ${p3.y}`,
    `A ${rInner} ${rInner} 0 ${large} 0 ${p4.x} ${p4.y}`,
    'Z'
  ].join(' ');
}

function roundedArcPath(cx, cy, rInner, rOuter, startA, endA, cornerR = 4) {
  // Rounded corners version — approximate by nudging start/end angles inward
  const midR = (rInner + rOuter) / 2;
  const angOffset = cornerR / midR;
  const s = startA + angOffset;
  const e = endA - angOffset;
  if (e <= s) return arcPath(cx, cy, rInner, rOuter, startA, endA); // too small
  return arcPath(cx, cy, rInner, rOuter, s, e);
}

function formatGB(gb) {
  if (gb >= 1) return `${gb.toFixed(2)} GB`;
  return `${(gb * 1024).toFixed(0)} MB`;
}

// ─── BUILD SVG ────────────────────────────────────────────────────────────────
function buildChart() {
  const totalMem = categories.reduce((s, c) => s + c.memGB, 0);
  const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
  svg.setAttribute('viewBox', `0 0 560 560`);
  svg.setAttribute('xmlns', 'http://www.w3.org/2000/svg');

  const defs = document.createElementNS('http://www.w3.org/2000/svg', 'defs');
  svg.appendChild(defs);

  // Dark background circle (the "hole" fill)
  const bg = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
  bg.setAttribute('cx', CX); bg.setAttribute('cy', CY);
  bg.setAttribute('r', OUTER_R);
  bg.setAttribute('fill', '#1c1c1e');
  svg.appendChild(bg);

  const innerBg = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
  innerBg.setAttribute('cx', CX); innerBg.setAttribute('cy', CY);
  innerBg.setAttribute('r', INNER_INNER_R);
  innerBg.setAttribute('fill', '#141414');
  svg.appendChild(innerBg);

  let currentAngle = START_ANGLE;

  categories.forEach((cat) => {
    const catFrac = cat.memGB / totalMem;
    const catSpan = catFrac * (2 * Math.PI) - GAP_ANGLE;
    const catStart = currentAngle + GAP_ANGLE / 2;
    const catEnd = catStart + catSpan;

    // ── INNER RING SLICE (category) ──
    const innerPath = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    innerPath.setAttribute('d', arcPath(CX, CY, INNER_INNER_R + 2, OUTER_INNER_R - 4, catStart, catEnd));
    innerPath.setAttribute('fill', cat.color);
    innerPath.setAttribute('class', 'inner-slice');
    svg.appendChild(innerPath);

    // Inner ring label (callout if slice is big enough)
    if (catFrac >= MIN_LABEL_FRAC) {
      const midAngle = (catStart + catEnd) / 2;
      const labelR = (INNER_INNER_R + OUTER_INNER_R) / 2;
      const lp = polarToXY(CX, CY, labelR, midAngle);

      // For large slices, show label as callout outside the ring
      if (catFrac >= 0.12) {
        const calloutR = OUTER_INNER_R + 18;
        const cp = polarToXY(CX, CY, calloutR, midAngle);
        const textR = OUTER_INNER_R + 32;
        const tp = polarToXY(CX, CY, textR, midAngle);
        const anchor = Math.cos(midAngle) > 0 ? 'start' : 'end';

        const line = document.createElementNS('http://www.w3.org/2000/svg', 'line');
        line.setAttribute('x1', polarToXY(CX, CY, OUTER_INNER_R, midAngle).x);
        line.setAttribute('y1', polarToXY(CX, CY, OUTER_INNER_R, midAngle).y);
        line.setAttribute('x2', cp.x); line.setAttribute('y2', cp.y);
        line.setAttribute('stroke', '#555'); line.setAttribute('stroke-width', '0.8');
        svg.appendChild(line);

        const text = document.createElementNS('http://www.w3.org/2000/svg', 'text');
        text.setAttribute('x', tp.x); text.setAttribute('y', tp.y);
        text.setAttribute('text-anchor', anchor);
        text.setAttribute('dominant-baseline', 'middle');
        text.setAttribute('class', 'ring-label');
        text.textContent = catFrac >= 0.2 ? cat.label : cat.shortLabel;
        svg.appendChild(text);
      } else {
        // Small enough — label inside ring, rotated along arc
        const text = document.createElementNS('http://www.w3.org/2000/svg', 'text');
        text.setAttribute('x', lp.x); text.setAttribute('y', lp.y);
        text.setAttribute('text-anchor', 'middle');
        text.setAttribute('dominant-baseline', 'middle');
        text.setAttribute('transform', `rotate(${(midAngle * 180/Math.PI) + 90}, ${lp.x}, ${lp.y})`);
        text.setAttribute('class', 'ring-label');
        text.setAttribute('font-size', '9');
        text.textContent = cat.shortLabel;
        svg.appendChild(text);
      }
    }

    // ── OUTER RING SLICES (apps within this category) ──
    const catTotalApps = cat.apps.reduce((s, a) => s + a.memGB, 0);
    let appAngle = catStart;

    cat.apps.forEach((app, ai) => {
      const appFrac = app.memGB / totalMem;
      const appSpan = (app.memGB / catTotalApps) * catSpan - GAP_ANGLE * 0.5;
      const appStart = appAngle + GAP_ANGLE * 0.25;
      const appEnd = appStart + appSpan;
      appAngle += (app.memGB / catTotalApps) * catSpan;

      const outerPath = document.createElementNS('http://www.w3.org/2000/svg', 'path');
      const d = roundedArcPath(CX, CY, OUTER_INNER_R + 3, OUTER_R - 2, appStart, appEnd);
      outerPath.setAttribute('d', d);
      outerPath.setAttribute('fill', app.color);
      outerPath.setAttribute('class', 'outer-slice');
      outerPath.dataset.name = app.name;
      outerPath.dataset.mem = formatGB(app.memGB);
      outerPath.dataset.pct = `${((app.memGB / USED_GB) * 100).toFixed(1)}% of used RAM`;

      // Hover events
      outerPath.addEventListener('mouseenter', onSliceHover);
      outerPath.addEventListener('mouseleave', onSliceLeave);
      outerPath.addEventListener('mousemove', onSliceMove);

      svg.appendChild(outerPath);

      // Label on outer ring for large enough slices
      if (appFrac >= MIN_LABEL_FRAC * 1.5) {
        const midAngle = (appStart + appEnd) / 2;
        const labelR = (OUTER_INNER_R + OUTER_R) / 2;
        const lp = polarToXY(CX, CY, labelR, midAngle);

        const text = document.createElementNS('http://www.w3.org/2000/svg', 'text');
        text.setAttribute('x', lp.x); text.setAttribute('y', lp.y);
        text.setAttribute('text-anchor', 'middle');
        text.setAttribute('dominant-baseline', 'middle');
        text.setAttribute('transform', `rotate(${(midAngle * 180/Math.PI) + 90}, ${lp.x}, ${lp.y})`);
        text.setAttribute('fill', 'rgba(255,255,255,0.7)');
        text.setAttribute('font-size', '9');
        text.setAttribute('font-family', '-apple-system, sans-serif');
        text.setAttribute('pointer-events', 'none');
        // Truncate name to fit
        const shortName = app.name.length > 10 ? app.name.substring(0, 9) + '…' : app.name;
        text.textContent = shortName;
        svg.appendChild(text);
      }
    });

    currentAngle += catFrac * 2 * Math.PI;
  });

  return svg;
}

// ─── SWAP RING ────────────────────────────────────────────────────────────────
function buildSwapRing() {
  const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
  svg.setAttribute('viewBox', '0 0 130 130');
  svg.setAttribute('xmlns', 'http://www.w3.org/2000/svg');
  svg.style.width = '100%'; svg.style.height = '100%';

  const cx = 65, cy = 65, rOuter = 58, rInner = 38;
  const swapFrac = Math.min(SWAP_GB / 16, 1); // assume 16 GB max swap for display

  // Background ring
  const bgPath = document.createElementNS('http://www.w3.org/2000/svg', 'path');
  bgPath.setAttribute('d', arcPath(cx, cy, rInner, rOuter, -Math.PI/2, -Math.PI/2 + 2*Math.PI - 0.02));
  bgPath.setAttribute('fill', '#2a2a2e');
  svg.appendChild(bgPath);

  // Used swap (orange/amber)
  const usedSpan = swapFrac * (2 * Math.PI) - 0.02;
  const usedPath = document.createElementNS('http://www.w3.org/2000/svg', 'path');
  usedPath.setAttribute('d', arcPath(cx, cy, rInner + 2, rOuter - 2, -Math.PI/2, -Math.PI/2 + usedSpan));
  usedPath.setAttribute('fill', '#b5b5c0');
  svg.appendChild(usedPath);

  return svg;
}

// ─── TOOLTIP ──────────────────────────────────────────────────────────────────
const tooltip = document.getElementById('tooltip');
const ttName = document.getElementById('ttName');
const ttMem = document.getElementById('ttMem');
const ttPct = document.getElementById('ttPct');

function onSliceHover(e) {
  const el = e.currentTarget;
  ttName.textContent = el.dataset.name;
  ttMem.textContent = el.dataset.mem;
  ttPct.textContent = el.dataset.pct;
  tooltip.classList.add('visible');
  positionTooltip(e);
}

function onSliceMove(e) { positionTooltip(e); }

function onSliceLeave() { tooltip.classList.remove('visible'); }

function positionTooltip(e) {
  const x = e.clientX + 14;
  const y = e.clientY - 10;
  tooltip.style.left = `${x}px`;
  tooltip.style.top = `${y}px`;
}

// ─── INIT ────────────────────────────────────────────────────────────────────
const wrapper = document.getElementById('chartWrapper');
const swapRing = document.getElementById('swapRing');

const chartSvg = buildChart();
wrapper.insertBefore(chartSvg, wrapper.firstChild);
chartSvg.style.position = 'absolute';
chartSvg.style.top = '0'; chartSvg.style.left = '0';
chartSvg.style.width = '100%'; chartSvg.style.height = '100%';

const swapSvg = buildSwapRing();
swapRing.insertBefore(swapSvg, swapRing.firstChild);
swapSvg.style.position = 'absolute';
swapSvg.style.top = '0'; swapSvg.style.left = '0';
</script>
</body>
</html>
```

---

## Production Integration Notes

### Feeding Real Data
Replace the `categories` array with live macOS memory data. Use:
- `host_statistics64()` (via Swift/Obj-C) for `vm_stat` fields: wired, active, inactive, compressed, free
- `proc_pidinfo()` with `PROC_PIDTASKINFO` for per-process `pti_resident_size` and `pti_phys_footprint`
- Group processes by `processCategory` matching the binary's `category-User Apps` / `category-User Processes` keys

### App Icon Embedding in Slices
The binary uses `ColorExtractor` + `DominantColors` (K-means clustering on icon pixels) to derive the slice fill color — this is why each outer slice matches the app's icon color palette.

To embed icons (optional, advanced):
1. For each app slice, create a `<clipPath>` element containing the arc path
2. Place a `<image>` element (app icon) inside the clip
3. Scale/center the image so it's visible within the arc bounds

Simplified version: just use the dominant color as fill (much lighter, same visual impression).

### Color Extraction (matching MacVitals)
MacVitals uses `DominantColorAlgorithm` K-means clustering:
- Sample icon pixels (e.g., 64x64 downscale)
- Run k-means with k=3–5
- Pick the cluster with highest saturation and luminance in mid-range
- Cache result to `color-cache.json` (PersistedColorCache)

In JS: use a Canvas 2D context to sample an `<img>` element's pixel data, then find the dominant color.

### Animation
On initial render, animate each slice from `startAngle` to `endAngle` using:
```js
// CSS animation on SVG path via stroke-dasharray trick, or
// requestAnimationFrame interpolating angle values on redraw
```

### Hover — Center Update
On `mouseenter` of an outer slice, update `#chartCenter`:
```js
centerMain.textContent = formatGB(app.memGB);
centerSub.textContent = app.name;
```
On `mouseleave`, restore to RAM totals.

### Key Binary Identifiers (for Swift port)
| HTML concept | Swift/binary equivalent |
|---|---|
| Inner ring slice | `GenericPieSlice` with `hasSolidSlices = true` |
| Outer ring slice | `GenericPieSlice` with `hasSolidSlices = false` |
| Inner radius ratio | `innerRadiusRatio` (Float) |
| Gap between slices | `gapAngle` (CGFloat, radians) |
| Min label threshold | `minSliceFractionForLabel` (Float) |
| Center display | `ChartCenterDefaultView` / `ChartCenterItemView` |
| Hover overlay | `PieChartHoverOverlay` |
| Swap ring | `SwapPieChart` / `MemorySwapInset` |
| Color extraction | `ColorExtractor` → `DominantColors` → K-means |

---

## Dark Theme Color Reference

| Element | Color |
|---|---|
| App background | `#141414` |
| Chart background circle | `#1c1c1e` |
| Inner ring hole | `#141414` |
| Category: User Apps (inner) | `#3a3a3e` |
| Category: User Procs (inner) | `#2c2c2e` |
| Category: File Cache (inner) | `#3d3d3f` |
| Category: Wired Memory (inner) | `#6b6b70` (lightest, matches screenshot) |
| Category: Compressed (inner) | `#4a4a4f` |
| Center GB number | `#e05555` (coral red) |
| Center "of X GB RAM" | `#888888` |
| Center "FOOTPRINT" | `#555555` |
| Label / callout text | `#aaaaaa` |
| Callout line | `#555555` |
| Tooltip background | `rgba(30,30,30,0.95)` |
| Tooltip border | `#333333` |

---

*Generated by Frontend Developer agent — MacVital project*
*Source: visual analysis of macvitals-full.png + macvitals-full2.png + binary string extraction from MacVitals.app*

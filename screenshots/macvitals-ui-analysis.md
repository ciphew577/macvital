# MacVitals Memory Tab — Complete UI Analysis
## For 1:1 HTML Replica

Generated from: live pixel sampling, binary string extraction, and visual analysis of MacVitals.app (PID 27239, window ID 2632)
Screenshot resolution: 2736x1736px @144dpi (2x Retina — logical size 1368x868px)

---

## 1. OVERALL WINDOW STRUCTURE

### Window Dimensions
- Logical window size: approximately 1200–1300px wide × 820–870px tall (resizable)
- Window corner radius: ~10px (standard macOS)
- Traffic light buttons: standard macOS, top-left corner
- Window divider icon: top-right corner (sidebar toggle), SF Symbol `rectangle.split.2x1`
- No visible title bar text — pure toolbar area

### Top-Level Layout
```
┌─────────────────────────────────────────────────────────────┐
│  [●][●][●]                              [⊞ sidebar toggle]  │  ← Titlebar (~28px)
├────────────────────┬────────────────────────────────────────┤
│                    │                                        │
│  LEFT PANEL        │  RIGHT PANEL (CHART AREA)              │
│  (~35% width)      │  (~65% width)                          │
│                    │                                        │
│  Search bar        │  Sunburst chart (main)                 │
│  ──────────────    │  Swap ring (bottom-right)              │
│  Process tree      │  System tiles (top-right of chart)     │
│  (scrollable)      │                                        │
│                    │                                        │
├────────────────────┴────────────────────────────────────────┤
│  Bottom metrics bar (5 metrics)                             │  ← ~36px
├─────────────────────────────────────────────────────────────┤
│  Recommendation text row                                    │  ← ~22px
└─────────────────────────────────────────────────────────────┘
```

---

## 2. COLOR SYSTEM

### Background Colors (sampled via Swift pixel extraction, sRGB)

| Element | Hex | RGB | Notes |
|---------|-----|-----|-------|
| Window/titlebar background | `#000000` | 0,0,0 | True black — macOS dark material |
| Left panel background | `#1e1e1e` | 30,30,30 | Dark charcoal |
| Left panel sidebar (light version) | `#161a23` | 22,26,35 | Subtle blue-tinted dark |
| Left-right panel separator line | `#171a22` | 23,26,34 | Very dark blue-black |
| Chart area background | `#181921` | 24,25,33 | Deep navy-black |
| Chart donut hole (center) | `#181921` | same | Matches chart bg |
| Bottom metrics bar bg | `#1e1e1e` | 30,30,30 | Same as left panel |
| Bottom recommendation bg | `#000000` | 0,0,0 | True black |
| Scrollbar track | `#171a22` | 23,26,34 | |
| Scrollbar thumb | `#9f9f9f` | 159,159,159 | Standard macOS gray |

### Text Colors

| Element | Hex | RGB | Weight/Style |
|---------|-----|-----|-------------|
| Primary text (app names, values) | `#dddddd` | 221,221,221 | Regular |
| Secondary text (process names) | `#9a9a9a` | 154,154,154 | Regular, smaller |
| Tertiary/dimmed text | `#737373` | 115,115,115 | |
| Group header text | `#bfbfbf` | 191,191,191 | Medium weight |
| Memory value text | `#bfbfbf`–`#dddddd` | — | |
| Chart center value (GB) | `#ff4246` | 255,66,70 | Bold, large — RED (critical pressure) |
| Chart center "of XX GB RAM" | `#dddddd` | 221,221,221 | Regular, smaller |
| Chart center "FOOTPRINT: X GB" | `#9a9a9a` | 154,154,154 | Small caps, monospace-ish |
| MACVITALS branding (bottom right) | `#555555` | 85,85,85 | Very small, dimmed |

### Semantic/Status Colors

| Status | Hex | RGB | Usage |
|--------|-----|-----|-------|
| Blue (accent) | `#007aff` | 0,122,255 | Memory bars fill, progress bars — System Blue |
| Orange (elevated) | `#ff9230` | 255,146,48 | "Elevated" pressure text, "Pressure" metric |
| Red (critical) | `#ff4246` | 255,66,70 | Chart center GB value when pressure is critical |
| Green (good) | `#00993a` | 0,153,58 | App color slices (e.g., zoom.us green) |
| Light blue | `#1099bf` | 16,153,191 | App color slices (teal/cyan) |
| Purple-blue | `#7279f8` | 114,121,248 | App icon accent (some apps) |
| Yellow | `#ffca00` | 255,202,0 | App color slice accent |
| Red-pink | `#f51619` | 245,22,25 | App color slice (some apps) |

### Chart Ring Colors

| Ring Section | Hex | RGB | Notes |
|-------------|-----|-----|-------|
| SYSTEM outer ring | `#4e5054` | 78,80,84 | Medium gray, upper-right section |
| USER PROCESSES outer ring | `#727373` | 114,115,115 | Medium-dark gray, left section |
| USER APPS outer ring | `#8c8c8c` | 140,140,140 | Lighter gray, bottom section |
| Colorful app slices (multi) | Various | — | App-dominant colors extracted from icons |
| Wired Memory tile bg | `#596e96` | 89,110,150 | Muted blue-slate |
| File Cache tile bg | `#7f9ebc` | 127,158,188 | Lighter blue-gray |
| Third system tile bg | `#8c8b8b`–gray | — | Gray |
| Swap ring fill (used swap) | `#696969` | 105,105,105 | Medium gray circle |
| Swap ring empty (track) | `#2a2a2a` | 42,42,42 | Dark background |

---

## 3. TYPOGRAPHY

### Font Family
- Primary: **SF Pro** (system-ui / -apple-system) — the standard macOS system font
- Monospace elements (FOOTPRINT label): `monospacedDigitSystemFont` — SF Mono or SF Pro with tabular numerals
- All fonts via `NSFont` system APIs — no custom web fonts

### Font Scale (logical px, mapped from binary analysis)

| Element | Size | Weight | Style |
|---------|------|--------|-------|
| Group headers (User Apps, User Processes) | 12–13px | Medium (500) | Uppercase-like, gray |
| App name in row | 13px | Regular (400) | White-ish |
| Process name (child row) | 12px | Regular (400) | Dimmed gray |
| Memory value text | 12px | Regular (400) | Right-aligned |
| Chart center GB value | 28–32px | Bold (700) | Red `#ff4246` |
| Chart center "of X GB RAM" | 13px | Regular (400) | `#dddddd` |
| Chart center "FOOTPRINT" label | 10–11px | Regular | Monospaced, all-caps, gray `#9a9a9a` |
| Chart center FOOTPRINT value | 12px | Medium | Gray |
| Swap ring label "X.XX GB" | 15–16px | Semibold | White/light |
| Swap ring sub-label "Swap" | 11px | Regular | Dimmed gray |
| Ring segment labels (zsh, node, 2.191) | 11px | Regular | White, rotated |
| Bottom bar metric label (Physical Memory) | 10px | Regular | Very dimmed `#737373` |
| Bottom bar metric value (24 GB) | 13px | Semibold | `#dddddd` white |
| Bottom bar status value (Elevated) | 13px | Semibold | `#ff9230` orange |
| Bottom recommendation text | 11–12px | Regular | `#9a9a9a` gray |
| MACVITALS branding | 9–10px | Regular | `#555555` very dim |
| Row count badge (e.g. "(1)") | 11px | Regular | `#737373` |

---

## 4. LEFT PANEL — PROCESS TREE

### Panel Dimensions
- Width: ~35% of total window (logical ~420–460px)
- Background: `#1e1e1e`
- Right border: 1px separator line `#2a2e3a` (blue-dark)
- Has vertical scrollbar on right edge

### Search Bar
- Position: top of left panel, below title bar
- Height: ~28–30px logical
- Background: `#1e1e1e` or slightly lighter `#252525`
- Placeholder text: "Filter by app name, bundle ID, or process name..."
- Placeholder color: `#737373`
- Search icon: SF Symbol magnifying glass, left-aligned, `#737373`
- Clear button: SF Symbol `xmark.circle.fill` on right, appears when text entered
- Border: subtle `1px solid #2a2a2a` or borderless
- Corner radius: none (inline with panel) or `6px` if floating

### Tree Row Structure
Each row has this horizontal layout (left to right):

```
[indent] [▶/▼] [icon 16px] [app name] ... [count badge] [value text] [memory bar] [scrollbar]
```

#### Row Height
- Group header row: ~24px logical (32px in tall display)
- App/process rows: ~20–22px logical

#### Indentation
- Root groups (User Apps, User Processes, System): 0 indentation
- Top-level app rows (zoom.us): ~20px indent
- Child process rows (zoom.us process, caphost, log): ~36px indent  
- Grandchild: ~48px indent (if shown)

#### Expand Arrow
- SF Symbol `chevron.right` / `chevron.down`
- Size: ~10px
- Color: `#737373` (collapsed) / `#9a9a9a` (expanded)

#### App Icon
- Size: 16×16px logical (32×32 @2x)
- Circular clip with `cornerRadius = 4px`
- Placed immediately after expand arrow
- System processes show gear icon `⚙` in `#9a9a9a`

#### Group Header Rows
Format: `▼ [☐ folder icon] User Apps  (1)          202.9 MB [bar]`
- Folder icon: SF Symbol `folder` or similar
- App count in parentheses: `(1)`, `(9)`, etc. — gray `#737373`
- Background: same as panel `#1e1e1e`
- Text color: `#bfbfbf` medium-weight

#### Memory Bars (right side of each row)
- Position: far right, before scrollbar — approximately last 80–100px of row width
- Track height: ~3–4px logical
- Track background: `#3a3a3a` (dark gray)
- Track corner radius: 2px (pill shape)
- Fill color: `#007aff` (System Blue) for most bars
- Fill width: proportional to memory usage relative to max visible
- The bar shows both the used amount AND the total (track length = max app memory)
- Some process bars show in red `#ff4246` when critically high
- Memory value text (e.g., "202.9 MB") displayed just to left of bar

#### Memory Value Format
- Values shown as: `205.2 MB`, `1.84 GB`, `3.28 GB`
- Font: monospaced digits, right-aligned
- Color: `#9a9a9a` dimmed

#### Delta Indicator
- Small colored dot or triangle to the right of memory value
- Indicates memory change since last refresh
- Green dot = decreasing, red dot = increasing

### Groups

1. **User Apps** — apps with GUI, direct user interaction
   - Shows macOS app icons (colorful, recognizable)
   - Expanding shows the app's child processes

2. **User Processes** — background processes, daemons, terminals
   - Shows gear icon for processes without bundle ID
   - Children are individual PID entries

3. **System** — OS-level processes (Notification Centre, Calendar, etc.)
   - Shows system app icons where available

### Scrollbar
- Standard macOS overlay scrollbar
- Thumb color: `#9f9f9f`
- Track: transparent, appears on hover
- Width: ~8px

---

## 5. SUNBURST CHART (Main Chart)

### Overall Chart Geometry
- Position: right panel, centered vertically and horizontally
- Chart center: approximately at 55% x, 47% y of total window
- Outer radius (outermost ring): approximately 42–44% of panel height
- Inner radius (donut hole): approximately 22–24% of panel height
- Number of rings: 2 (outer data ring + inner system detail ring)
- Gap between rings: ~4–6px (gap angle between segments = `gapAngle` from binary)
- Chart background: `#181921` fills the panel area around the rings

### Ring 1 — Outer Data Ring (Categories + Apps)
This is the main ring showing proportional memory usage by category.

**Segments (clockwise from top-right):**
1. **SYSTEM** — upper right quadrant, gray `#4e5054`, lighter shade
2. **USER PROCESSES** — left half, medium gray `#727373`
3. **USER APPS** — lower portion, lighter gray `#8c8c8c` for the bulk, with colorful app sub-slices in the bottom zone

**APP SLICES within USER APPS:**
- Each major app gets a slice colored by its dominant icon color
- Small apps are grouped into "Other" with flat gray
- App icon appears embedded in the slice (16×16 or 20×20px) for larger slices
- Slice label appears rotated along the arc for large slices

**Outer ring width:** ~18–22% of outer radius (thick ring)

**Segment labels:**
- Appear inside the segment, rotated to follow the arc
- Text: app name or category name (e.g., "zsh", "node", "2.191", "USER PROCESSES")
- Font: 11px SF Pro, `#dddddd`
- Labels only appear when slice is large enough

### Ring 2 — Inner System Detail Ring (top-right)
This ring appears only in the SYSTEM sector, showing breakdown of system memory types.

**Tiles visible in inner ring (top-right quadrant):**
- **Wired Memory** — slate blue `#596e96`, shows lock icon + "Wired Mem..." label
- **File Cache** — lighter blue-gray `#7f9ebc`, shows document icon + "File Cache" label
- **Third tile** (App Memory / Other) — gray, shows generic icon

These tiles appear as rectangular-ish arc segments with visible icons.

**Inner ring radius:** approximately 65–70% of outer ring inner radius

### Chart Center (Donut Hole)
- Background: `#181921` (matches chart bg — creates donut effect)
- Center icon: SF Symbol `memorychip` or similar (CPU/memory chip icon) in `#9a9a9a`
- Large value: **"29.56 GB"** — font 28–32px, bold, `#ff4246` RED
- Sub-label: **"of 24 GB RAM"** — font 13px, regular, `#dddddd`
- Footer label: **"FOOTPRINT 39.42 GB"** — font 10px, monospace, all-caps, `#9a9a9a`
- Vertical stacking with small gaps between elements

### Chart Segment Interaction
- On hover: segment highlights, tooltip appears (via `hoverThrottleInterval`)
- Right-click: context menu (via `PieChartRightClickHandler`)
- Selected segment: slightly elevated/brightened

### Segment Gap
- Small gap between each segment: `gapAngle` ~1–2 degrees
- Gap color: same as chart background `#181921`

---

## 6. SWAP RING

### Position
- Lower-right of main chart, separate smaller ring
- Approximately at 80% x, 72% y of chart panel
- Positioned so it does not overlap main chart (with deliberate spacing)
- `MemorySwapInset` controls the inset from chart edge

### Dimensions
- Outer radius: approximately 50–55px logical (much smaller than main chart)
- Ring thickness: ~18–22px (relatively thick)
- Inner radius: ~30–35px

### Colors
- Ring track (empty/dark portion): `#2a2a2a` dark background
- Ring fill (used swap): `#696969` medium gray
- Fill is proportional to swap used vs available
- No colored accent — pure gray indicating swap activity level

### Center Label
- Value: **"5.75 GB"** — font ~15px, semibold, `#dddddd`
- Sub-label: **"Swap"** — font 11px, regular, `#9a9a9a`
- Centered in ring hole

### Appearance
- Background behind the swap ring: `#181921` (same as chart area)
- The ring appears to float in the lower-right of the chart panel

---

## 7. SYSTEM MEMORY TILES (Top-Right Inner Ring)

These are card-like tiles appearing in the inner ring on the SYSTEM sector (top-right of chart).

### Tile Structure
Each tile is an arc-shaped segment within the inner ring:

```
┌─────────────────────┐
│  [🔒 icon]  Wired   │  ← Title row
│  Memory             │
│  72.6 MB            │  ← Value
└─────────────────────┘
```

### Tile Colors
| Tile | Background | Text |
|------|-----------|------|
| Wired Memory | `#596e96` (muted slate blue) | White |
| File Cache | `#7f9ebc` (light blue-gray) | White |
| Third (App/Other) | `#737373` (gray) | White |

### Tile Icons
- Wired Memory: SF Symbol `lock.fill` (represents kernel-locked memory)
- File Cache: SF Symbol `doc.fill` or `internaldrive` (represents disk cache)
- Third tile: varies

### Tile Typography
- Title: 11px SF Pro, `#dddddd`
- Value: 13px, semibold, `#ffffff` or `#dddddd`

---

## 8. BOTTOM METRICS BAR

### Structure
5 metric columns across the full window width, separated by subtle dividers.

```
| Physical Memory ⓘ | Used ⓘ         | Pressure ⓘ    | Swap Used ⓘ  | Disk Free ⓘ  |
|  24 GB            |  23.81 GB       |  Elevated     |  5.75 GB     |  55.49 GB    |
```

### Metrics Bar Dimensions
- Height: ~36px logical
- Background: `#1e1e1e` (matches left panel)
- Subtle top border: `1px solid #2a2a2a`

### Metric Cell Layout (per column)
```
[Label]  [ⓘ info icon]
[Value]
```
- Label font: 10px, regular, `#737373` dimmed
- Value font: 13px, semibold
- Info button: SF Symbol `info.circle`, ~12px, `#555555`

### Metric Value Colors
| Metric | Value Example | Color |
|--------|-------------|-------|
| Physical Memory | 24 GB | `#dddddd` (neutral white) |
| Used | 23.81 GB | `#dddddd` (neutral) — or green if low |
| Pressure | Elevated | `#ff9230` (orange) |
| Swap Used | 5.75 GB | `#dddddd` (neutral gray) |
| Disk Free | 55.49 GB | `#dddddd` (neutral) |

### Metric Labels (exact strings from binary)
- "Physical Memory"
- "Used"
- "Pressure"
- "Swap Used"
- "Disk Free"

### Pressure Status Values
- "Normal" — green `#30d158` or neutral
- "Elevated" — orange `#ff9230`
- "Critical" — red `#ff4246`

---

## 9. BOTTOM RECOMMENDATION ROW

### Position
- Below the metrics bar
- Full window width
- Height: ~22px

### Appearance
- Background: `#000000` (true black — distinct from metrics bar)
- Text: dynamically generated insight about memory status
- Example: "Memory pressure is critical — the system is swapping heavily to disk, which slows things down. This workload aligns better with about 32 GB RAM."
- Font: 11px SF Pro, `#9a9a9a` gray
- Text alignment: left-aligned with ~16px left padding
- The text is a single line (truncates if too long)

### Text Content Types (from binary)
- Normal state: "Memory looks healthy. Your X GB RAM is well-sized..."
- Elevated: "Memory usage is moderate. Plenty of headroom..."
- Critical: "Memory pressure is critical—the system is swapping heavily..."
- RAM sizing hint: "This workload aligns better with about X GB RAM."

---

## 10. BRANDING

### MACVITALS Watermark
- Position: bottom-right corner of the chart panel
- Text: "MACVITALS" in all caps
- Font: ~9px, letter-spacing: wide
- Color: `#555555` — very dim
- Appears on the chart background area

---

## 11. SPACING & LAYOUT CONSTANTS

From binary analysis (`DesignSystem.swift`, spacing tokens):

| Property | Value (logical px) |
|----------|-------------------|
| Row height (app) | ~20px |
| Row height (group header) | ~24px |
| Indentation per level | ~16–20px |
| Chart vertical padding | `chartVerticalPadding` — ~24px |
| Memory bar height | ~3–4px |
| Memory bar width | ~80–100px |
| Intercell spacing | `intercellSpacing` — ~0px (rows flush) |
| Chart gap angle | ~1.5° |
| Inner radius ratio | `innerRadiusRatio` — approximately 0.5 (donut: inner = 50% of outer) |
| Swap ring inset | `MemorySwapInset` — ~20px from chart edge |
| Panel divider height | 1px |

---

## 12. INTERACTION STATES

### Hover States
- Row hover: subtle background highlight `#252525` (slightly lighter than base)
- Chart segment hover: brightness increase, tooltip appearance
- Hover throttle: `hoverThrottleInterval` — slight delay to avoid jitter

### Selection
- Selected app in tree: `#dddddd` text (vs dimmed unselected)
- Selected chart slice: highlighted ring segment

### Context Menu
Right-clicking an app/process shows:
- "Add to Memory Monitor"
- "Remove from Monitor"
- Copy options (process name, PID, memory, bundle ID)

### Expand/Collapse Animation
- Smooth disclosure of child rows
- Controlled by `outlineView:shouldExpandItem:` / `outlineView:shouldCollapseItem:`

---

## 13. KEY SOURCE FILES (from binary symbol extraction)

| File | Purpose |
|------|---------|
| `DesignSystem.swift` | Design tokens, colors, spacing |
| `GenericPieChart.swift` | Core chart rendering |
| `MemoryPieChart.swift` | Memory-specific chart |
| `ProcessTreeView.swift` | Left panel tree |
| `ProcessTreeCells.swift` | Row cell views |
| `ProcessTreeCoordinator.swift` | Data coordinator |
| `MemoryVisualizationView.swift` | Right panel container |
| `ChartCenterView.swift` | Center label (GB value) |
| `MemorySummaryView.swift` | Bottom bar metrics |
| `RecommendationView.swift` | Bottom recommendation row |
| `FilterBar.swift` | Search/filter input |
| `IconRow.swift` | App icon display |
| `MemoryBarNSView` | NSView for progress bars |
| `MemoryDeltaNSView` | Delta change indicator |

---

## 14. CSS IMPLEMENTATION GUIDE

### Color Tokens
```css
:root {
  /* Backgrounds */
  --bg-window: #000000;
  --bg-panel: #1e1e1e;
  --bg-chart: #181921;
  --bg-separator: #171a22;
  --bg-bottom-rec: #000000;
  --bg-row-hover: #252525;
  --bg-scrollbar-thumb: #9f9f9f;
  
  /* Chart Ring Colors */
  --ring-system: #4e5054;
  --ring-user-processes: #727373;
  --ring-user-apps: #8c8c8c;
  --ring-wired-mem: #596e96;
  --ring-file-cache: #7f9ebc;
  --ring-swap-fill: #696969;
  --ring-swap-track: #2a2a2a;
  
  /* Text */
  --text-primary: #dddddd;
  --text-secondary: #9a9a9a;
  --text-tertiary: #737373;
  --text-group-header: #bfbfbf;
  --text-dimmed: #555555;
  
  /* Semantic */
  --color-critical: #ff4246;
  --color-elevated: #ff9230;
  --color-blue-accent: #007aff;
  --color-good: #30d158;
  
  /* Memory bar */
  --bar-fill: #007aff;
  --bar-track: #3a3a3a;
  
  /* Spacing */
  --row-height: 20px;
  --row-height-header: 24px;
  --indent-level: 18px;
  --bar-height: 3px;
  --bar-width: 80px;
  --chart-ring-gap: 4px;
}
```

### Layout Grid
```css
.app-window {
  display: grid;
  grid-template-columns: 35% 65%;
  grid-template-rows: 28px 1fr 36px 22px;
  background: #000000;
  color: #dddddd;
  font-family: -apple-system, SF Pro, system-ui, sans-serif;
  font-size: 13px;
}

.titlebar { grid-column: 1 / -1; background: #000000; }
.left-panel { background: #1e1e1e; border-right: 1px solid #2a2e3a; }
.chart-panel { background: #181921; }
.bottom-bar { grid-column: 1 / -1; background: #1e1e1e; border-top: 1px solid #2a2a2a; }
.recommendation { grid-column: 1 / -1; background: #000000; }
```

### Chart Implementation Notes
- Use SVG for the sunburst rings (path-based arcs)
- Main chart: 2 concentric arc rings with gap angles
- Each segment: `<path>` with arc coordinates
- Segment labels: `<text>` elements rotated to arc midpoint
- Inner ring (SYSTEM detail): smaller radius arcs in top-right quadrant only
- Swap ring: separate smaller SVG positioned bottom-right
- Chart center text: absolutely positioned HTML overlay on SVG

### Memory Bar Component
```html
<div class="memory-bar-container">
  <span class="memory-value">202.9 MB</span>
  <div class="memory-bar-track">
    <div class="memory-bar-fill" style="width: 95%"></div>
  </div>
</div>
```
```css
.memory-bar-track {
  width: 80px; height: 3px;
  background: #3a3a3a; border-radius: 2px;
}
.memory-bar-fill {
  height: 100%; background: #007aff; border-radius: 2px;
}
```

---

## 15. EXACT METRIC LABELS (from binary strings)

Bottom bar, left to right:
1. "Physical Memory" — total RAM installed
2. "Used" — RAM currently in use
3. "Pressure" — memory pressure level (Normal / Elevated / Critical)
4. "Swap Used" — disk swap currently used
5. "Disk Free" — available disk space for swap

Info button tooltip strings (from binary):
- Physical Memory: "The total amount of RAM installed in your Mac."
- Used: "The amount of RAM currently in use by apps, system processes, and caches. This includes active, wired, and compressed memory."
- Pressure: "Memory pressure is a weighted metric of how hard your system is working to manage memory"
- Swap Used: "When RAM is full, macOS writes less-used memory to your SSD as 'swap'. High swap usage can slow your Mac and cause SSD wear over time."
- Disk Free: "Available space on the volume where swap files are stored. Low disk space limits how much swap macOS can use, which may cause apps to be terminated."

---

## 16. ADDITIONAL UI ELEMENTS

### Window Icon Toggle (top-right of titlebar)
- SF Symbol: `arrow.down.left.and.arrow.up.right` / `rectangle.split.2x1`
- Toggles sidebar visibility

### Sort Control (bottom of left panel, toolbar)
- "Sort" dropdown or button
- Icon for usage bars toggle

### Usage Bars Toggle
- Label "Usage Bars" in settings
- Toggles visibility of memory bars in rows

### Sidebar Display Mode
- "Sidebar display mode" setting
- Controls what's shown in each panel section

---

## 17. COMPLETE COLOR REFERENCE

```css
/* === FINAL COMPLETE COLOR MAP === */

/* Window structure */
--window-bg:              #000000;  /* pure black window bg */
--panel-bg:               #1e1e1e;  /* left panel, bottom bar */
--chart-bg:               #181921;  /* right chart area */
--separator:              #2a2e3a;  /* panel divider */
--bottom-rec-bg:          #000000;  /* recommendation strip */

/* Text hierarchy */
--text-h1:                #dddddd;  /* primary: app names, values */
--text-h2:                #bfbfbf;  /* headers: group names */
--text-h3:                #9a9a9a;  /* secondary: process names, labels */
--text-h4:                #737373;  /* tertiary: counts, dimmed */
--text-h5:                #555555;  /* brand watermark */
--text-white:             #ffffff;  /* tile labels */

/* Status colors */
--status-critical:        #ff4246;  /* red — chart GB value, critical */
--status-elevated:        #ff9230;  /* orange — Elevated pressure */
--status-normal:          #30d158;  /* green — good state */
--status-blue:            #007aff;  /* blue accent — progress bars */

/* Chart rings */
--segment-system:         #4e5054;  /* SYSTEM segment */
--segment-user-proc:      #727373;  /* USER PROCESSES */
--segment-user-apps:      #8c8c8c;  /* USER APPS bulk */
--segment-wired:          #596e96;  /* Wired Memory tile */
--segment-file-cache:     #7f9ebc;  /* File Cache tile */
--segment-gap:            #181921;  /* gap between segments */

/* Swap ring */
--swap-fill:              #696969;  /* filled portion */
--swap-track:             #2a2a2a;  /* empty track */

/* App-dominant colors (dynamically extracted from icons) */
/* Examples: */
--app-zoom:               #1499ce;  /* Zoom blue */
--app-green:              #00993a;  /* green apps */
--app-cyan:               #1099bf;  /* cyan apps */
--app-purple:             #7279f8;  /* purple apps */
--app-yellow:             #ffca00;  /* yellow apps */
--app-red:                #f51619;  /* red apps */

/* Memory bars */
--bar-fill:               #007aff;  /* progress fill */
--bar-track:              #3a3a3a;  /* track background */

/* Scrollbar */
--scrollbar-thumb:        #9f9f9f;
```

---

*Analysis complete. All measurements are in logical (1x) pixels. Multiply by 2 for @2x Retina rendering.*
*Color values are sRGB after converting from Display P3 source.*

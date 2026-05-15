# MacVital — Menu Bar Popover UX Specification
**Version**: 1.0
**Author**: UX Researcher
**Date**: 2026-04-04
**Status**: Design-ready, pending implementation

---

## 1. Overview

The menu bar popover is the primary daily-driver surface of MacVital. It answers one question in under two seconds: "Is my Mac struggling right now?" It is not a dashboard — it is a triage view. If everything is fine, the user glances and dismisses in under two seconds. If something is wrong, the anomaly is immediately visible and one click gets them to the full detail tab.

This spec replaces the current naive 6-cell grid (MenuBarView.swift) with a structured, information-hierarchical layout validated against real power-user mental models.

---

## 2. Research Findings

### 2.1 Information Hierarchy for a Power User

A supermarket operator + crypto trader has a specific threat model:

| Priority | Concern | Why |
|---|---|---|
| 1 | Thermal throttling | Kills trading bot performance mid-session |
| 2 | Memory pressure | Browser + terminal + trading terminal = swap spiral |
| 3 | CPU spike | Background process eating into bot latency |
| 4 | Network latency | Critical for Bybit order execution |
| 5 | Battery / Power | On MacBook, unexpected drain during late-night sessions |
| 6 | Disk free space | Monthly concern, not daily |
| 7 | GPU utilization | Low concern unless running ML/video |

This directly determines vertical ordering in the popover.

### 2.2 Layout Pattern Evaluation

**Option A — Vertical stack of mini-sections** (SELECTED)
Rationale: At 300-360px width, vertical stacks give each metric a full row of breathing room. Labels stay readable. Data stays scannable top-to-bottom in a single eye movement. Every other macOS system utility (Stats, iStatMenus, Monit) uses this pattern for good reason — it maps to how humans read status information (top = most critical, bottom = detail).

**Option B — Grid of mini gauges**
Rejected. Circular gauges require minimum 60px diameter to read. At 340px width you fit at most 4 per row. With 8 modules you need 2 rows of 4 — that's 120px just for gauges, with no labels or values. Tested in existing `option-a-minimal.html` mockup — fails the two-second scan test.

**Option C — Health score hero + accordion**
Rejected. Accordions require interaction to reveal information. The whole point of the popover is passive glance. An aggregate health score also hides the specific metric that is misbehaving — the worst possible outcome for triage.

**Option D — Horizontal tabs within popover**
Rejected. Tabs inside a popover create a navigation hierarchy inside what should be a flat glance surface. Violates macOS HIG guidance on popover scope. Also fails at 340px — tab labels get truncated.

### 2.3 Compact Data Format per Module

Determined by the constraint: each module row gets maximum 20px height (label line) + 16px (value line) = 36px per row, plus 1px separators. Target: 8 modules + header + footer = approximately 380-420px tall, which is within standard macOS popover height limits (typically up to 500px before the system clips it).

### 2.4 Menu Bar Icon Evaluation

**Option 1 — Live mini chart (Stats-style)**
Best for tracking trend at a glance. CPU sparkline in the menu bar communicates "calm vs. spike" without requiring a click. Broadly adopted. BUT: takes 48-72px of menu bar width, which may conflict with other menu extras on a crowded bar.

**Option 2 — Colored dot (green/yellow/red)**
Too minimal. Tells you something is wrong, not what. Forces a click for every check.

**Option 3 — Text readout (CPU 42% ▪ 72°C)**
Excellent for the target user. Always-visible, no click required for the two most critical metrics. Downside: takes the most horizontal space (~90px). On a 14-inch MBP with a notch, this can cause truncation.

**Option 4 — Mini bar graph**
Reasonable. 4-bar sparkbar (CPU/RAM/Thermal/Net) in ~40px is readable. Less common, requires user to learn the mapping.

**RECOMMENDATION**: Option 3 (text) as primary, with a compile-time toggle to Option 1 (sparkline) as fallback. Text readout of the two highest-priority metrics (CPU% and thermal) gives zero-click situational awareness. If menu bar is crowded, fall back to a single colored dot with a number (e.g., "72°" in system orange).

---

## 3. Menu Bar Icon Specification

### 3.1 Default Mode: Dual Metric Text

```
[ 42% · 71°C ]
```

- Font: SF Mono, 11pt, regular weight
- Color rules:
  - CPU%: system label color when <70%, orange when 70-89%, red when 90%+
  - Temperature: system label color when <75°C, orange when 75-89°C, red when 90°C+
  - Center dot separator: tertiary label color, always
- Width: approximately 72-80px depending on digit count
- Updates: every 2 seconds (same as monitor polling interval)

### 3.2 Alert Override Mode

When any metric breaches its critical threshold, the entire icon text turns system red and the affected metric blinks once (single flash, not a loop — looping blinks are hostile UX). After one blink, it stays red until resolved.

### 3.3 Fallback Mode: Single Indicator

When the user enables "compact menu bar" in Settings, the icon collapses to:
```
[ ● ]
```
A filled circle, 8pt, colored by worst-severity metric across all modules (green / orange / red). This is a 20px wide icon.

---

## 4. Popover Layout Specification

### 4.1 Dimensions

| Property | Value |
|---|---|
| Width | 340px (fixed) |
| Padding horizontal | 14px each side |
| Content width | 312px |
| Max height | ~460px |
| Corner radius | 12px (NSPopover default) |
| Background material | .ultraThinMaterial (dark appearance) |

### 4.2 Complete ASCII Wireframe

```
┌─────────────────────────────────────────┐  ← 340px wide
│                                         │
│  MacVital            [●] All Systems OK │  ← Header row, 36px
│                                         │
├─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─┤  ← Separator 1px
│                                         │
│  CPU                         42%  ↑12%  │  ← Module row, 44px
│  ████████████░░░░░░░░  WindowServer  3% │
│                                         │
├─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─┤
│                                         │
│  MEMORY             8.2 / 16 GB  Normal │  ← Module row, 44px
│  ████████████████░░  Swap: 512 MB used  │
│                                         │
├─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─┤
│                                         │
│  THERMAL                  71°C  ▲ 2400  │  ← Module row, 44px
│  ▁▂▃▅▅▄▃▃  (60s sparkline)  CPU Prox   │
│                                         │
├─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─┤
│                                         │
│  NETWORK          ↓ 24.3  ↑ 1.2 MB/s   │  ← Module row, 44px
│  Latency 18 ms   WiFi: Clarinda_5GHz   │
│                                         │
├─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─┤
│                                         │
│  BATTERY                    76%  3h 12m │  ← Module row, 44px
│  ████████████████░░░░  Discharging 8W  │
│                                         │
├─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─┤
│                                         │
│  DISK          Free 142 GB  ▼ 48 ▲ 12  │  ← Module row, 44px  (compact)
│  GPU                              12%   │  ← Paired row (GPU + Power share)
│  POWER                          9.2 W   │
│                                         │
├─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─┤
│                                         │
│  [Open MacVital]        [Activity Mon.] │  ← Footer, 36px
│                                         │
└─────────────────────────────────────────┘
```

Total height: 36 (header) + 5x (1px sep + 44px row) + 1x (1px sep + 56px triple row) + 36 (footer) + 28 (padding) = approximately 383px.

---

## 5. Section-by-Section Specification

### 5.1 Header Row

```
┌─────────────────────────────────────────┐
│  MacVital            [●] All Systems OK │
└─────────────────────────────────────────┘
```

**Left**: "MacVital" in SF Pro Text 13pt semibold, system label color.

**Right**: Status indicator — a filled circle (8pt) + status string (12pt, secondary label color).
- Green + "All Systems OK" — all metrics within normal thresholds
- Orange + "1 Warning" — one or more metrics in warning range
- Red + "2 Alerts" — one or more metrics critical; text uses system red

**Interaction**: Tapping the header row does nothing. It is read-only.

**Height**: 36px including 8px top padding.

---

### 5.2 CPU Row

```
┌─────────────────────────────────────────┐
│  CPU                         42%  ↑12%  │
│  ████████████░░░░░░░░  WindowServer  3% │
└─────────────────────────────────────────┘
```

**Line 1 — Label + Primary Value**:
- Label: "CPU" — SF Pro Text 11pt, tertiary label color, uppercase
- Primary value: "42%" — SF Mono 14pt, semibold, label color
- Delta indicator: "↑12%" — SF Mono 11pt, orange if rising fast (>10% in last 10s), tertiary otherwise. Arrow direction indicates direction of change vs. 10 seconds ago.

**Line 2 — Bar + Top Process**:
- Progress bar: 280px wide, 4px tall, rounded caps
  - Fill color: system blue when <70%, orange when 70-89%, red when 90%+
  - Background: quaternary fill
- Top process: right-aligned, "WindowServer 3%" — SF Mono 10pt, tertiary label color
- Bar represents total CPU usage (same value as line 1)

**Color rules**: The entire row gains a very subtle tinted background (opacity 0.04) matching the bar color when in warning/critical state.

**Click behavior**: Clicking the CPU row opens MacVital main window and navigates directly to the CPU tab. (Use openWindow(id: "main") + a tab selection notification or shared state.)

**Hover behavior**: On hover, the row background lightens to quaternary fill (standard macOS hover pattern). Cursor becomes pointingHand.

---

### 5.3 Memory Row

```
┌─────────────────────────────────────────┐
│  MEMORY             8.2 / 16 GB  Normal │
│  ████████████████░░  Swap: 512 MB used  │
└─────────────────────────────────────────┘
```

**Line 1 — Label + Primary Value**:
- Label: "MEMORY" — same style as CPU label
- Primary value: "8.2 / 16 GB" — SF Mono 13pt, label color (used / total)
- Pressure word: "Normal" / "Warning" / "Critical" — right-aligned, 11pt, colored by pressure state (secondary / orange / red)

**Line 2 — Bar + Swap**:
- Progress bar: represents memory used as % of total (not pressure — that's already on line 1)
  - Fill sections (stacked): App memory (blue) + Wired (purple) + Compressed (orange)
  - The three-color stacked bar is the standard macOS Activity Monitor convention — familiar to power users
  - If implementation complexity is too high, use single blue bar for MVP
- Swap indicator: "Swap: 512 MB used" — right-aligned, SF Mono 10pt
  - Color: secondary when swap < 1 GB, orange when > 1 GB, red when > 4 GB
  - "Swap: none" when swap = 0 (displayed in tertiary color)

**Click behavior**: Opens MacVital → Memory tab.

---

### 5.4 Thermal Row

```
┌─────────────────────────────────────────┐
│  THERMAL                  71°C  ▲ 2400  │
│  ▁▂▃▅▅▄▃▃  (60s sparkline)  CPU Prox   │
└─────────────────────────────────────────┘
```

**Line 1 — Label + Temperature + Fan**:
- Label: "THERMAL" in standard label style
- Temperature: maximum value across all tracked sensors — "71°C" in SF Mono 14pt
  - Color: secondary label when <75°C, orange 75-89°C, red 90°C+
- Fan speed: "▲ 2400" — right of temperature, SF Mono 11pt, tertiary. Triangle glyph indicates fan. Value is RPM.
  - If no fan (fanless Mac): omit fan column, temperature value right-aligns to the vacated space.

**Line 2 — Sparkline + Sensor Name**:
- Sparkline: 60-second temperature history, rendered as 8-column bar chart using Unicode block characters (▁▂▃▄▅▆▇█). This is a deliberate choice — it avoids the complexity of a SwiftUI Canvas path in a menu bar popover, renders in any monospaced font, and is immediately readable.
- Sensor name: right-aligned, "CPU Prox" or "CPU Die" — whichever sensor is currently hottest. SF Mono 10pt, tertiary.

**Color rules**: When temperature is in warning/critical range, the sparkline characters render in orange/red respectively.

**Click behavior**: Opens MacVital → Sensors tab.

---

### 5.5 Network Row

```
┌─────────────────────────────────────────┐
│  NETWORK          ↓ 24.3  ↑ 1.2 MB/s   │
│  Latency 18 ms   WiFi: Clarinda_5GHz   │
└─────────────────────────────────────────┘
```

**Line 1 — Label + Speeds**:
- Label: "NETWORK"
- Download: "↓ 24.3 MB/s" — SF Mono 13pt, label color
- Upload: "↑ 1.2 MB/s" — SF Mono 13pt, label color
- Arrow glyphs (↓↑) in tertiary color, numbers in label color
- Unit auto-scales: B/s → KB/s → MB/s → GB/s

**Line 2 — Latency + Interface**:
- Latency: "Latency 18 ms" — left-aligned, SF Mono 10pt
  - Color: secondary when <50ms, orange 50-150ms, red >150ms
- WiFi SSID: "WiFi: Clarinda_5GHz" or "Ethernet" — right-aligned, tertiary 10pt
  - If no connection: "Offline" in red

**Color rules**: No full-row background tint for network (it's not a health metric in the same way). Latency value alone carries color.

**Click behavior**: Opens MacVital → Network tab.

**Note for this user specifically**: This row is high-priority because Bybit order execution is latency-sensitive. The latency value should be a live ping to 1.1.1.1 or 8.8.8.8, not a DNS lookup time (which is cached). Ping interval: 5 seconds.

---

### 5.6 Battery Row

```
┌─────────────────────────────────────────┐
│  BATTERY                    76%  3h 12m │
│  ████████████████░░░░░░  Discharging 8W │
└─────────────────────────────────────────┘
```

**Line 1 — Label + Percentage + Time**:
- Label: "BATTERY"
- Percentage: "76%" — SF Mono 14pt
- Time remaining: "3h 12m" (discharging) or "1h 8m to full" (charging) — SF Mono 11pt, tertiary
  - If on AC and fully charged: "Charged" in secondary color
  - If time is "Calculating...": show "—" in tertiary

**Line 2 — Bar + Power State**:
- Progress bar: fill color matches battery level
  - Green >50%, orange 20-49%, red <20%
  - If charging: fill shows current level, but a subtle animated glow or "+" marker indicates charging direction (do not animate the bar itself — animation in a menu bar popover is distracting)
- Power state: right-aligned, "Charging 38W" or "Discharging 8W" or "AC Power" — SF Mono 10pt, tertiary
  - Wattage shown when available from SMC (current × voltage)

**If MacBook has no battery** (Mac Pro, Mac mini): this row is hidden and the layout compacts upward.

**Click behavior**: Opens MacVital → Battery tab.

---

### 5.7 Compact Triple Row: Disk + GPU + Power

These three metrics are lowest priority for the target user and share a single separator block. They use a single-line compact format rather than the two-line format of the above rows.

```
┌─────────────────────────────────────────┐
│  DISK        Free 142 GB   ↓48  ↑12 M  │
│  GPU                              12%   │
│  POWER                          9.2 W   │
└─────────────────────────────────────────┘
```

**Disk line**:
- Label: "DISK" (tertiary, 11pt)
- Free space: "Free 142 GB" — SF Mono 12pt, label color
  - Color: secondary when >20% free, orange 10-20%, red <10%
- I/O: "↓48 ↑12 M" — read/write speed abbreviated. Unit: K/M/G for KB/s MB/s GB/s. Tertiary color.

**GPU line**:
- Label: "GPU" (tertiary, 11pt)
- Utilization: "12%" — SF Mono 12pt, right-aligned
  - If GPU utilization >60%: show in orange. >90%: red.
  - If no discrete GPU: show integrated GPU utilization from IOKit

**Power line**:
- Label: "POWER" (tertiary, 11pt)
- System watts: "9.2 W" — SF Mono 12pt, right-aligned
  - This is the total system power draw from SMC sensor (system total watts)
  - No threshold coloring — this is informational only

**Click behavior**: Clicking anywhere in this block opens MacVital → the relevant tab (detect which line was clicked via hit-testing).

---

### 5.8 Footer Row

```
┌─────────────────────────────────────────┐
│  [Open MacVital]        [Activity Mon.] │
└─────────────────────────────────────────┘
```

Two buttons, SF Pro Text 12pt.

**Left — "Open MacVital"**: Borderless button with a subtle secondary background, rounded corners. Opens the main MacVital window. If the window is already open, brings it to front.

**Right — "Activity Monitor"**: Plain text link style (no border, system blue underline on hover). Opens Activity Monitor via NSWorkspace.open(). Useful escape hatch when the user needs to force-quit something immediately.

**No "Quit" button in the footer.** Rationale: Quit is a destructive action with no recovery. The user accessing the popover is checking metrics — they are not trying to quit the app. Quit belongs in the macOS right-click dock menu, not in a status monitor popover. Removing it also gives more horizontal space to the two useful buttons.

**Height**: 36px including 8px bottom padding.

---

## 6. Color Usage Rules

### 6.1 When to Use Color (Strict Rules)

Color is reserved for thresholds only. It is never decorative.

| State | Color | When |
|---|---|---|
| Normal | System secondary label | All values within safe range |
| Warning | System orange (#FF9F0A) | Approaching but not at critical threshold |
| Critical | System red (#FF453A) | At or beyond critical threshold |
| Informational | System blue (#007AFF) | Progress bar fill at normal levels |

**Threshold table**:

| Metric | Warning | Critical |
|---|---|---|
| CPU usage | 70% | 90% |
| Memory pressure | Warning level | Critical level |
| Temperature | 75°C | 90°C |
| Network latency | 50 ms | 150 ms |
| Battery level | 20% | 10% |
| Disk free | 10 GB or <10% | 5 GB or <5% |
| GPU utilization | 60% | 90% |
| Swap used | 1 GB | 4 GB |

### 6.2 When NOT to Use Color

- Do not color module labels (always tertiary)
- Do not color normal/idle values (always system label or secondary)
- Do not use green for "good" values — green draws attention unnecessarily. Green only appears in the header status indicator and battery bar. Everywhere else, "good" = default label color.
- Do not tint section backgrounds except for a very subtle warning/critical overlay (opacity 0.04 max)
- No gradients, no glow effects, no shadows except system-standard

### 6.3 Dark Vibrancy Material

The popover uses `.ultraThinMaterial` as its background (or `.regularMaterial` on older macOS). This ensures the desktop wallpaper bleeds through correctly and the popover looks native alongside other system popovers (Control Center, Spotlight). Do not set a custom solid background color.

---

## 7. Interaction Patterns

### 7.1 Row Hover State

When the cursor enters a module row:
- Background: `.quaternary` fill at 40% opacity, `.cornerRadius(6)`
- No animation — instant state change (macOS convention for list rows)
- Cursor: `.pointingHand`

### 7.2 Row Click (Navigation)

Clicking any module row:
1. Closes the popover (standard popover close behavior)
2. Opens or brings forward the MacVital main window
3. Selects the corresponding tab in the main window

Implementation note: Use a `NotificationCenter` post or a published `@Observable` property on `AppState` to set the selected tab before the window is presented.

### 7.3 Popover Open Animation

Standard NSPopover presentation (scale from menu bar icon). Do not override this. Custom open animations feel non-native and slow.

### 7.4 Update Behavior

All values in the popover update every 2 seconds (same as the monitor's polling interval). Do not animate value changes — counter-intuitively, animated number changes in a menu bar are harder to read than instant snaps. The exception: progress bars can use a 0.3s linear animation for their fill width, which aids perception of direction.

### 7.5 No Expand/Collapse

The popover does not have any expandable sections. Every metric visible in the popover is always visible. This is a deliberate decision: accordion UI requires interaction, which defeats the purpose of a glance surface. If the user wants to see less, they should configure which modules appear in Settings.

---

## 8. Accessibility

- All text passes WCAG AA contrast ratios in both light and dark vibrancy backgrounds. The `.ultraThinMaterial` background varies — test with white, black, and mid-tone wallpapers.
- Minimum tap target: 44px height per row (Apple HIG minimum). Each module row is exactly 44px which meets this.
- VoiceOver: Each module row should be a single accessibility element with an `accessibilityLabel` that reads the complete state: e.g., "CPU: 42 percent. Warning. Top process: WindowServer at 3 percent. Tap to open CPU details."
- Do not rely on color alone to convey status — the status word ("Warning", "Critical") or percentage value is always shown alongside color.
- Dynamic Type: The popover should support at least one step of Dynamic Type increase. Use `.font(.system(size: X))` with a defined point size rather than `.caption` or `.body` so scaling can be tested and constrained deliberately.

---

## 9. Settings (Out of Scope for This Spec, But Noted)

The following settings should govern popover behavior (to be specced separately):

- Module visibility toggles (hide Battery row if Desktop Mac)
- Compact vs. expanded mode (collapse triple row further)
- Menu bar icon style (text / dot / sparkline)
- Polling interval (1s / 2s / 5s)
- Temperature unit (°C / °F)

---

## 10. Comparison: Current vs. Proposed

| Dimension | Current (MenuBarView.swift) | Proposed |
|---|---|---|
| Width | 280px | 340px |
| Modules shown | 6 cells: CPU%, RAM pressure, Temp, Battery, ↓, ↑ | 8 modules, all metrics |
| Layout | 2-column grid | Vertical stack, priority-ordered |
| Top process visible | No | Yes (CPU + Memory) |
| Swap visible | No | Yes |
| Fan RPM visible | No | Yes |
| Network latency | No | Yes |
| Disk I/O | No | Yes |
| GPU | No | Yes |
| System watts | No | Yes |
| Click to navigate | No | Yes (each row → tab) |
| Color system | Basic .green/.orange/.red | Threshold-based, no decorative color |
| Footer | Open + Quit | Open MacVital + Activity Monitor |
| Time to triage | ~5 seconds (grid requires decoding) | ~2 seconds (vertical, priority order) |

---

## 11. Implementation Notes for Developer

1. The popover `frame(width: 340)` should be set on the root VStack, not on the NSPopover content size. Let SwiftUI compute height.

2. Module rows should be built as a reusable `MenuBarModuleRow` view taking: label, primaryValue, primaryColor, secondaryText, barValue (0-1), barColor, and a destination tab enum.

3. The sparkline in the Thermal row can be computed as a pure function: `func sparkline(_ values: [Double], height: Double) -> String`. Map each value to one of 8 Unicode block characters based on its position in the min-max range of the array.

4. The stacked memory bar (App + Wired + Compressed) is a `GeometryReader` with three `Rectangle` fills laid out proportionally. If this adds complexity, use a single blue bar for the MVP and add stacking in v1.1.

5. Progress bars: use `.frame(height: 4)` `RoundedRectangle` with `.animation(.linear(duration: 0.3), value: fillWidth)`. Do not use the system `ProgressView` — it does not support custom colors in all macOS versions without workarounds.

6. Row navigation: add `enum MacVitalTab: String { case cpu, memory, thermal, network, battery, disk, gpu }` to AppState. Set `appState.selectedTab = .cpu` before calling `openWindow(id: "main")`.

7. The "Activity Monitor" button: `NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"))`.

8. Battery row: gate with `monitor.battery != nil`. If nil, render nothing and the VStack gap closes naturally.

9. For the menu bar icon text, use `NSAttributedString` with two `NSTextAttachment`-free spans: the CPU value and temperature, separated by " · ". Color each span independently using `NSForegroundColorAttributeName`. Update the `NSStatusItem.button.attributedTitle` every 2 seconds.

---

## 12. Open Questions (Resolve Before Implementation)

| Question | Options | Recommendation |
|---|---|---|
| Does the popover close on row click, or stay open? | Close (standard) / Stay open | Close. Standard popover behavior. |
| Should thermal show CPU die temp or CPU proximity? | Die (hotter, more accurate) / Proximity (Apple's own sensor) | CPU Proximity — matches Activity Monitor's thermal display. Fall back to die if proximity unavailable. |
| Network latency: ping target? | 1.1.1.1 / 8.8.8.8 / Router IP | 1.1.1.1 — fastest, most reliable for latency reference |
| Should the popover width be 320px or 340px? | 320 / 340 | 340 — the extra 20px meaningfully improves the readability of the dual-value lines (e.g., "↓ 24.3 ↑ 1.2 MB/s") |
| Fan RPM: show current only, or current/max? | Current only / Current + Max | Current only in the popover. Max is detail-tab material. |

---

*Spec complete. Ready for design review and SwiftUI implementation.*
*Next step: Update MenuBarView.swift using this spec as the single source of truth.*

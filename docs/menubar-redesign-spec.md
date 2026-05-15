# MacVital Menu Bar Popover — Redesign Specification
**Version**: 2.0
**Author**: UI Designer
**Date**: 2026-04-04
**Status**: Ready for implementation. Supersedes mockup menubar-popover.html and augments menubar-ux-spec.md.

---

## 1. Executive Summary

The current `menubar-popover.html` mockup fails at its primary job. A menu bar health popover has one purpose: answer "Is my Mac struggling right now?" in under two seconds without scrolling. The current design renders the same four metrics three times (gauge → sparkline → card), buries network in a footer section, includes irrelevant quick actions, and uses a health score aggregate that actively hides the specific problem.

This spec defines the correct design from first principles, informed by analysis of Stats (exelban), iStat Menus (Bjango), and the existing `menubar-ux-spec.md`.

---

## 2. Research Synthesis

### 2.1 What the Best Apps Do Right

**Stats (exelban/stats)**
- Per-module separate popovers, each ~280px wide
- CPU popup: three-zone layout — dashboard (90pt, pie chart center + side gauges 50x50pt), chart zone (120pt line chart), process list (22pt per row, 8 processes default)
- RAM popup: pie chart + pressure gauge side-by-side in dashboard zone, then line chart, then details text grid (6 values: Used/App/Wired/Compressed/Free/Swap), then top processes
- Key insight: Stats shows the drill-down information because each popover IS the drill-down. The menu bar icon is the at-a-glance surface. The popover is the detail layer.
- This works because Stats uses per-module icons — you click the CPU icon to get CPU detail. The mental model is explicit.

**iStat Menus (Bjango)**
- Single combined popover, ~370px wide
- Combined mode lets users choose what appears at the menu bar level vs. popover level
- Uses horizontal bars (not circular) for the primary reading — bars communicate both direction and magnitude simultaneously in a single left-right scan
- Groups related metrics: CPU% + CPU history chart together, Memory pressure + usage bar together
- Key insight: Horizontal bars at 6-8pt height are readable at a glance. Circular gauges at 62px require the eye to trace the arc — slower.

**What both apps validate:**
1. Vertical stack beats grid for scannable status monitoring
2. Horizontal bars beat circular gauges for speed of reading
3. Secondary detail (top process, swap amount) belongs directly below the primary metric
4. No scrolling in a triage popover — everything visible at once

### 2.2 The Core Tension: At-a-Glance vs. Drill-Down

The correct resolution is a **two-surface model**:
- Menu bar icon = at-a-glance (zero clicks, always visible): text readout of top 2 metrics
- Popover = triage (one click): all 8 modules, vertical priority stack, no scrolling
- Main window = drill-down (two clicks from icon, one from popover row): full charts, process trees, history

The current mockup conflates the popover with drill-down by showing charts, sparklines, and detailed cards. This makes the popover slower than it needs to be while still not providing the full drill-down value of the main window.

### 2.3 Gauge Shape Decision: Circular vs. Horizontal

**Circular gauges (current mockup):**
- Minimum readable size: 56-62px diameter
- 4 gauges in 320px = 280px consumed for the gauge row alone
- Reading requires tracing an arc — the eye must travel around a curve
- Value must be centered in the ring as a second visual element
- Total cognitive load: arc position + center number = two reads to confirm one value
- Verdict: **Rejected for popover triage use**

**Horizontal bars:**
- Minimum readable height: 4-6pt
- Reading requires one left-to-right scan — matches natural reading direction
- Value displayed right-aligned on the same line as the label
- Total cognitive load: one scan left-right, label + value + bar fill in one eye movement
- Stats uses this for its compact widget; iStat uses this throughout
- Verdict: **Selected**

### 2.4 Width Decision

| Width | Verdict | Reason |
|-------|---------|--------|
| 280px | Too narrow | "↓ 24.3 ↑ 1.2 MB/s" truncates; dual-value lines require space |
| 320px | Current mockup | Works but tight — "8.2 / 16 GB  Warning" barely fits |
| 340px | Selected | The extra 20px over 320px is meaningful for dual-value rows; matches menubar-ux-spec.md recommendation |
| 360px | Too wide | Feels like a window, not a popover; macOS system popovers trend toward 340px |

---

## 3. What is Wrong With the Current Mockup

This section is the direct answer to "needs to be designed better."

| Problem | Location in HTML | Why It's Wrong |
|---------|-----------------|----------------|
| Health score badge "74" | `.health-badge` | Aggregate scores hide the specific failing metric. "74 Health" tells you nothing actionable. |
| Summary pill "Your Mac is running warm" | `.pop-summary` | Redundant with the colored values visible in the rows below. Wastes 32px for zero information gain. |
| 4x circular gauges at 62px | `.pop-gauges` | Consumes 80px minimum. Requires arc-tracing. CPU appears again below in the card. CPU rendered THREE times total. |
| Sparklines below gauges | `.pop-sparklines` | A fourth representation of the same 4 metrics already shown as gauges. Adds 22px with no new information. |
| Metric cards | `.pop-cards` | A fifth representation. CPU/Mem/Battery/Disk now appear as: gauge + sparkline + card. Bloated and redundant. |
| Network at the bottom | `.pop-network` | For a trader with latency-sensitive Bybit order execution, network is a top-4 priority metric. It is currently below alerts and after the fold. |
| Alerts section | `.pop-alerts` | Duplicates information visible in the rows. "Memory pressure elevated — 11.4 GB" is already shown in the memory card above. |
| Quick actions footer | `.pop-actions` | "Force Quit" and "Empty Trash" do not belong in a health monitor popover. Only "Open MacVital" belongs. |
| Scrollable content | `.pop-scroll` | A triage surface must show everything without scrolling. Scrolling means the most important items may be off-screen. |
| Width 320px | `.popover` | 20px narrower than optimal; dual-value lines are tight |
| Emoji in content | `.pop-summary-icon` | Non-native; system SF Symbols or text is correct for macOS popovers |
| Pulsing status dot animation | `.status-dot` | Looping animations in a menu bar are hostile UX; a status indicator does not need to blink continuously |

---

## 4. The Correct Design

### 4.1 Mental Model

The popover is a **priority-ordered status board**. It answers eight questions simultaneously, each in one line:

1. How hard is the CPU working?
2. Is memory under pressure?
3. Is the Mac running hot?
4. Is network connectivity healthy?
5. What is the battery situation?
6. Is disk space a concern?
7. Is the GPU doing heavy work?
8. What is total system power draw?

That is it. No health scores. No aggregate summaries. No charts. No alerts section (the color of the values IS the alert). No quick actions except the single exit point to the main window.

### 4.2 Final Dimensions

| Property | Value | Rationale |
|----------|-------|-----------|
| Width | 340px | Optimal for dual-value lines; matches menubar-ux-spec.md |
| Horizontal padding | 14px each side | Content width = 312px |
| Max height | ~420px | No scrolling; fits all 8 modules + header + footer |
| Min row height | 44px | Apple HIG minimum touch target |
| Background | `.ultraThinMaterial` (dark) | Native macOS popover appearance |
| Corner radius | 12px | NSPopover default |

---

## 5. Complete Layout Specification

### 5.1 ASCII Wireframe — Full Popover

```
┌─────────────────────────────────────────────┐  340px
│                                             │
│  MacVital                    ● All Systems  │  Header, 38px
│                                             │
├─────────────────────────────────────────────┤  1px separator
│                                             │
│  CPU                              42%  ↑9%  │  Line 1: label + value + delta, 20px
│  ██████████████░░░░░░░  WindowServer  3.1%  │  Line 2: bar + top process, 20px
│                                             │  4px padding between rows = 44px total
├─────────────────────────────────────────────┤  1px separator
│                                             │
│  MEMORY              8.2 / 16 GB  Elevated  │  Line 1
│  ████████████████████░░░░  Swap: 512 MB     │  Line 2
│                                             │
├─────────────────────────────────────────────┤  1px separator
│                                             │
│  THERMAL                     71°C  ▲ 2,400  │  Line 1: temp + fan RPM
│  ▁▂▃▅▆▅▄▃  60s history         CPU Prox    │  Line 2: unicode sparkline + sensor
│                                             │
├─────────────────────────────────────────────┤  1px separator
│                                             │
│  NETWORK          ↓ 24.3  ↑ 1.2 MB/s       │  Line 1: speeds
│  Latency  18 ms         WiFi: IGA_5GHz      │  Line 2: latency + SSID
│                                             │
├─────────────────────────────────────────────┤  1px separator
│                                             │
│  BATTERY                      76%  3h 12m   │  Line 1: % + time
│  ████████████████████░░░░  Discharging 8W   │  Line 2: bar + wattage
│                                             │
├─────────────────────────────────────────────┤  1px separator
│                                             │
│  DISK              Free 142 GB  R48  W12 M  │  Compact single line, 20px
│  GPU                                   12%  │  Compact single line, 20px
│  POWER                               9.2 W  │  Compact single line, 20px
│                                             │
├─────────────────────────────────────────────┤  1px separator
│                                             │
│  Open MacVital              Activity Mon.   │  Footer, 36px
│                                             │
└─────────────────────────────────────────────┘
```

**Height breakdown:**
- Header: 38px
- 5x full-module rows (44px each + 1px separator): 225px
- 1x compact triple block (72px + 1px separator): 73px
- Footer: 36px
- Top/bottom body padding: 0px (padding is within rows)
- **Total: 372px** — well within the 500px macOS clip ceiling, no scrolling required

### 5.2 Header Row

```
MacVital                    ● All Systems
```

**Left side — App name:**
- "MacVital" — SF Pro Text 13pt, weight 590 (semibold), primary label color
- No icon, no badge. The name is the brand.

**Right side — Status:**
- Filled circle 7px, colored by worst metric across all modules
- Status string 11pt, secondary label color
- States: "● All Systems" (green) / "● 1 Warning" (orange) / "● 2 Alerts" (red)
- The circle is NOT animated. No pulse. Static dot.

**Height:** 38px including 10px top padding.

**Why no health score number:** A numeric aggregate (e.g., "74") is meaningless without knowing the formula. It actively misleads — a Mac could score 74 while in thermal throttle. The colored status string is unambiguous.

### 5.3 Module Rows — Full Format (CPU, Memory, Thermal, Network, Battery)

Each full module row is 44px tall: 10px top padding + 20px line 1 + 4px gap + 20px line 2 - with the remaining space as bottom padding.

Actual inner layout:
```
[LABEL]              [PRIMARY VALUE]  [SECONDARY VALUE]
[HORIZONTAL BAR ████████░░░░░░]          [DETAIL TEXT]
```

**Line 1 — Label + Values:**
- Label: SF Pro Text 11pt, weight 500, ALL CAPS, tertiary label color
- Primary value: SF Mono 14pt, weight 600, label color (or threshold-colored)
- Secondary value: SF Mono 11pt, tertiary label color — delta (↑9%), pressure word, time remaining, fan RPM

**Line 2 — Bar + Detail:**
- Bar: 4px tall, `RoundedRectangle(cornerRadius: 2)`, full content width
- Bar fill: threshold-colored (blue normal, orange warning, red critical)
- Bar background: quaternary fill
- Detail text: right-aligned, SF Mono 10pt, tertiary label color

**Hover state:** `.quaternaryFill` background on the full row, `.cornerRadius(6)`, instant (no animation). Cursor: `.pointingHand`.

**Click:** Close popover → open main window → navigate to corresponding tab.

### 5.4 Per-Module Line 2 Detail

| Module | Bar represents | Right-side detail text |
|--------|---------------|----------------------|
| CPU | Total usage % | Top process name + its % (e.g., "WindowServer  3.1%") |
| Memory | Used / Total % | Swap amount ("Swap: 512 MB" or "Swap: none") |
| Thermal | Current temp as % of 100°C | Sensor name ("CPU Prox" or "CPU Die") |
| Network | Download speed as % of max observed | Nothing — the two speed values on line 1 are sufficient |
| Battery | Charge % | Power state + watts ("Discharging 8W" or "Charging 38W") |

**Thermal row — Unicode sparkline on line 2:**

The thermal row is the exception. Line 2 shows a 60-second sparkline using Unicode block characters instead of the progress bar:

```
▁▂▃▅▆▅▄▃  60s history         CPU Prox
```

- 8 characters, each mapped to one of ▁▂▃▄▅▆▇█ by position within the min-max range of the 60-second window
- Rendered in SF Mono 12pt — the characters align naturally
- Color: tertiary when below 75°C, orange when 75-89°C, red when 90°C+
- "60s history" label in quaternary color, 9pt
- Sensor name right-aligned in tertiary, 10pt

This pattern (used by Stats for its compact widget) conveys trend without requiring a SwiftUI Canvas path, and it works natively in any monospaced font.

### 5.5 Network Row — Line 2 Layout

Network line 2 has three pieces left-to-right:
```
Latency  18 ms         WiFi: Clarinda_5GHz
```

- "Latency" label: quaternary, 10pt
- "18 ms" value: tertiary color normal, orange 50-150ms, red >150ms. SF Mono 10pt.
- "WiFi: [SSID]" or "Ethernet" right-aligned, tertiary 10pt
- If offline: "Offline" right-aligned in red

Ping target: 1.1.1.1, interval 5 seconds, ICMP (not DNS — DNS is cached and does not reflect actual connectivity latency).

### 5.6 Compact Triple Block — Disk, GPU, Power

These three metrics share one separator block. Each is a single 20px line. No progress bar. Values only.

```
DISK              Free 142 GB  R48  W12 M
GPU                                   12%
POWER                               9.2 W
```

- Label: 11pt, weight 500, tertiary, ALL CAPS
- Value(s): SF Mono 12pt, right-aligned, label color

**Disk line:** Free space left-aligned after label; I/O abbreviated as "R48  W12 M" (Read 48 MB/s, Write 12 MB/s — M = MB/s, K = KB/s, G = GB/s). Free space colored: secondary normal, orange <10% or <10GB free, red <5% or <5GB.

**GPU line:** Utilization percentage. Orange >60%, red >90%.

**Power line:** System total watts from SMC sensor. No threshold coloring — informational only.

Block height: 72px (10px top pad + 20px + 4px + 20px + 4px + 20px - 6px = 72px).

Click hit-testing: detect which of the three lines was clicked and navigate to the appropriate tab.

### 5.7 Footer Row

```
Open MacVital              Activity Mon.
```

- Height: 36px including 8px bottom padding
- Left: "Open MacVital" — filled tinted button, SF Pro Text 12pt, weight 500
  - Background: `.blue.opacity(0.12)`, border: `.blue.opacity(0.25)`, rounded 6pt
  - Opens/foregrounds main window
- Right: "Activity Mon." — plain text, system blue, 12pt
  - Opens Activity Monitor via NSWorkspace

**No "Quit" button.** A user checking system metrics is not trying to quit the app. Quit belongs in the dock right-click menu. Its absence recovers 28px of horizontal space for the two useful buttons.

---

## 6. Color Rules (Strict)

### 6.1 The Rule: Color Is Threshold-Only

Color in the popover is never decorative. It only fires when a metric crosses a defined threshold.

| State | macOS semantic color | When |
|-------|---------------------|------|
| Normal | `.secondaryLabel` | Within safe range |
| Warning | `.systemOrange` (#FF9F0A) | Approaching critical |
| Critical | `.systemRed` (#FF453A) | At or beyond critical |
| Bar fill (normal) | `.systemBlue` (#007AFF) | Normal progress bar fill |

### 6.2 "Good" Values Are Not Colored Green

Green draws the eye as powerfully as red. If a value is fine, it is default label color. Green is reserved for the header status dot only (and battery bar when >50%).

This is the iStat Menus pattern and the correct one. Coloring good values green creates visual noise on a triage surface where "nothing is green = something is wrong" needs to be the clear signal.

### 6.3 Threshold Table

| Metric | Warning | Critical |
|--------|---------|----------|
| CPU % | 70% | 90% |
| Memory pressure | Warning level (IOKit) | Critical level (IOKit) |
| Temperature | 75°C | 90°C |
| Network latency | 50ms | 150ms |
| Battery level | 20% | 10% |
| Disk free | 10 GB or <10% | 5 GB or <5% |
| GPU utilization | 60% | 90% |
| Swap used | 1 GB | 4 GB |

### 6.4 Row Background Tinting

When a module is in warning or critical state, the row background receives a very subtle tint:
- Warning: `systemOrange.opacity(0.04)`
- Critical: `systemRed.opacity(0.04)`

This gives a subconscious signal even before reading the values, useful for peripheral vision during a fast scan. Maximum tint opacity is 0.04 — any higher becomes garish.

---

## 7. Typography Specification

| Element | Font | Size | Weight | Color |
|---------|------|------|--------|-------|
| App name (header) | SF Pro Text | 13pt | 590 | `.label` |
| Status string (header) | SF Pro Text | 11pt | 400 | `.secondaryLabel` |
| Module label | SF Pro Text | 11pt | 500 | `.tertiaryLabel` (ALL CAPS) |
| Primary value | SF Mono | 14pt | 600 | `.label` (or threshold color) |
| Secondary value / delta | SF Mono | 11pt | 400 | `.tertiaryLabel` |
| Bar detail text | SF Mono | 10pt | 400 | `.tertiaryLabel` |
| Compact block values | SF Mono | 12pt | 400 | `.label` |
| Footer buttons | SF Pro Text | 12pt | 500 | `.label` / `.systemBlue` |

SF Mono for all numeric values — monospaced ensures numbers never shift horizontally as they update, which would create distracting visual jitter in a live-updating display.

---

## 8. Interaction Model

### 8.1 Row Click → Tab Navigation

Each module row is a button. Click:
1. Popover closes (standard NSPopover behavior)
2. `AppState.selectedTab` is set to the corresponding tab enum value
3. `openWindow(id: "main")` is called — window opens or comes to front

### 8.2 No Hover Expansion

Rows do not expand on hover. There is no "show more" interaction inside the popover. The popover is a fixed-height triage surface. More information = main window.

### 8.3 Update Rate

All values update every 2 seconds (same as monitor polling interval). Progress bars animate their fill width with a `0.3s linear` transition — this aids perception of direction without being distracting. Numbers snap instantly — animated number changes are harder to read, not easier.

### 8.4 Popover Dismiss

- Click outside popover: dismiss (NSPopover default)
- Click any row: navigate + dismiss
- Click footer buttons: action + dismiss
- Escape key: dismiss

---

## 9. Comparison: Current Mockup vs. This Spec

| Dimension | Current mockup (menubar-popover.html) | This spec |
|-----------|---------------------------------------|-----------|
| Width | 320px | 340px |
| Total height | ~620px (requires scrolling) | ~372px (no scroll) |
| Scrollable | Yes | No |
| Health score aggregate | Yes (misleads) | No |
| Summary pill | Yes (redundant) | No |
| Circular gauges | Yes — 4x at 62px each | No |
| Horizontal bars | No | Yes — per module |
| Times CPU metric appears | 3x (gauge + sparkline + card) | 1x |
| Network priority position | Section 4 (below fold) | Section 4 (primary stack, above fold) |
| Network latency shown | Yes (footer row) | Yes (line 2 of network row) |
| Thermal sparkline | No | Yes (unicode, line 2) |
| Swap shown | Yes (card sub-text) | Yes (bar detail text) |
| Fan RPM shown | No | Yes (line 1, thermal) |
| Alerts section | Yes (duplicates card data) | No |
| Quick actions (Force Quit etc.) | Yes | No |
| Footer actions | Open MacVital + Force Quit + Empty Trash | Open MacVital + Activity Monitor |
| Click to navigate | No (buttons only) | Yes (every row) |
| Status dot animation | Looping pulse | Static (no animation) |
| Emoji in content | Yes (🌡 ⚡ 🖥 💾 💿) | No (SF Symbols or text) |
| Time to triage | ~6–8 seconds (decode gauge grid, scroll, find key metric) | ~2 seconds (vertical scan, top to bottom) |

---

## 10. Implementation Notes

### 10.1 SwiftUI Component Structure

```swift
// Root structure
VStack(spacing: 0) {
    PopoverHeaderView()             // 38px
    Divider()
    PopoverModuleRow(.cpu)          // 44px
    Divider()
    PopoverModuleRow(.memory)       // 44px
    Divider()
    PopoverModuleRow(.thermal)      // 44px — special: unicode sparkline on line 2
    Divider()
    PopoverModuleRow(.network)      // 44px
    Divider()
    PopoverModuleRow(.battery)      // 44px — hidden if no battery
    Divider()
    PopoverCompactBlock()           // 72px — Disk + GPU + Power
    Divider()
    PopoverFooterView()             // 36px
}
.frame(width: 340)
```

### 10.2 PopoverModuleRow View Protocol

```swift
struct PopoverModuleRow: View {
    let module: MacVitalModule      // enum: cpu, memory, thermal, network, battery
    @EnvironmentObject var monitor: SystemMonitor

    // Resolved from monitor:
    var label: String               // "CPU", "MEMORY", etc.
    var primaryValue: String        // "42%", "8.2 / 16 GB", "71°C", etc.
    var primaryColor: Color         // threshold-colored or .label
    var secondaryValue: String      // "↑9%", "Elevated", "▲ 2,400", etc.
    var barFill: Double             // 0.0–1.0
    var barColor: Color             // threshold-colored
    var detailText: String          // right-aligned bar annotation
    var destination: MacVitalTab    // for navigation on click
}
```

### 10.3 Thermal Sparkline Function

```swift
func unicodeSparkline(_ values: [Double]) -> String {
    guard !values.isEmpty else { return "        " }
    let mn = values.min()!, mx = values.max()!
    let range = mx == mn ? 1.0 : mx - mn
    let chars = ["▁","▂","▃","▄","▅","▆","▇","█"]
    // Sample to 8 points
    let sampled = stride(from: 0, to: values.count, by: max(1, values.count / 8))
        .map { values[$0] }
        .prefix(8)
    return sampled.map { v in
        let idx = Int(((v - mn) / range) * Double(chars.count - 1))
        return chars[min(idx, chars.count - 1)]
    }.joined()
}
```

### 10.4 Progress Bar

Do not use SwiftUI `ProgressView` — inconsistent color control across macOS versions.

```swift
GeometryReader { geo in
    ZStack(alignment: .leading) {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.quaternaryLabel.opacity(0.4))
        RoundedRectangle(cornerRadius: 2)
            .fill(barColor)
            .frame(width: geo.size.width * barFill)
            .animation(.linear(duration: 0.3), value: barFill)
    }
}
.frame(height: 4)
```

### 10.5 Battery Row Conditional

```swift
if monitor.battery != nil {
    Divider()
    PopoverModuleRow(.battery)
}
```

The VStack gap closes naturally — no placeholder needed.

### 10.6 Menu Bar Icon Text

```swift
// NSStatusItem attributed title — two colored spans
let attrs = NSMutableAttributedString()
attrs.append(NSAttributedString(
    string: "\(cpuPct)%",
    attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
                 .foregroundColor: cpuColor]
))
attrs.append(NSAttributedString(
    string: " · ",
    attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
                 .foregroundColor: NSColor.tertiaryLabelColor]
))
attrs.append(NSAttributedString(
    string: "\(tempC)°C",
    attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
                 .foregroundColor: tempColor]
))
statusItem.button?.attributedTitle = attrs
```

---

## 11. What Not to Include (Explicit Exclusions)

The following elements from the current mockup must not appear in the redesign:

- **Health score number** — aggregate score hides specific failures
- **Summary pill / text description** — the colored values are the summary
- **Circular ring gauges** — too large, too slow to read for this context
- **SVG sparkline charts for all 4 metrics** — charts belong in the main window
- **Metric cards section** — duplication of module row data
- **Active Alerts section** — duplication; color is the alert
- **Force Quit button** — belongs in the dock menu or main window
- **Empty Trash button** — not related to system monitoring
- **Looping animations on status dot** — hostile UX for a persistent menu bar item
- **Emoji icons** — use SF Symbols or text labels; emoji are not native to macOS system UI
- **Scrollable content** — everything must be visible at once at 340px width

---

## 12. Open Questions

| Question | Options | Recommendation |
|----------|---------|---------------|
| Thermal line 2: sparkline or bar? | Unicode sparkline / progress bar | Sparkline — more information (trend vs. instantaneous) |
| Network bar fill: what does it represent? | % of self-measured max / absolute scale | Omit bar from network; the two speed values on line 1 are self-explanatory and there is no meaningful "100%" for network speed |
| Compact block click areas: per-line or whole block? | Per-line hit-test / whole block opens Disk tab | Per-line — more precise, better UX; use `.contentShape(Rectangle())` on each line's HStack |
| Memory bar: single color or stacked (App/Wired/Compressed)? | Single blue / Three-color stacked | Start with single blue for MVP; add stacked in v1.1 (matches Activity Monitor convention) |
| Should disk I/O use absolute values or sparkline? | Text values (R48 W12 M) / mini sparkline | Text — sparkline requires min 48px width to be readable, which is unavailable in the compact line |

---

*Spec complete. Primary output is the ASCII wireframe in Section 5.1 and the component structure in Section 10.1. The next step is updating `MenuBarView.swift` using this spec as the single source of truth, discarding the circular gauge section entirely.*

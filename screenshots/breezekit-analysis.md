# BreezeKit UI Reverse-Engineering Analysis

**App**: BreezeKit (System Pro)
**Bundle ID**: app.breezekit
**Version**: Built with Xcode 2640 (17E192), macOS SDK 26.4
**Min OS**: macOS 15.0
**Copyright**: 2026 BreezeKit
**Analysed**: 2026-04-04

---

## App Structure Overview

BreezeKit is a native SwiftUI macOS app. All UI is SwiftUI — no XIB/NIB files, no storyboards. The Resources directory contains only:
- `AppIcon.icns` — App icon
- `Assets.car` — Compiled asset catalog (images, colors)

A privileged helper `app.breezekit.smchelper` runs as a LaunchService to access SMC (System Management Controller) for fan control and temperature sensor data. It is signed with team `FYW5Y3U6FN`.

**Swift source files identified (from crash strings in binary)**:
- `MainView.swift` — root navigation/sidebar
- `TemperatureSection.swift` — Thermal tab
- `TemperatureRing.swift` — circular temp gauge component
- `FanControlSection.swift` — Fan Control tab
- `FanController.swift` — SMC fan logic
- `BatterySection.swift`, `MemorySection.swift`, `NetworkSection.swift`
- `DiskIOSection.swift`, `StorageSection.swift`, `CleanSection.swift`
- `DownloadSection.swift`, `DevicesSection.swift`, `ProcessListRow.swift`
- `StatCard.swift` — reusable metric card component
- `GlassEffectView.swift` — background glass/blur effect
- `SystemMonitor.swift`, `StorageAnalyzer.swift`, `MacCleaner.swift`
- `DownloadManager.swift`, `CPUThrottler.swift`, `DeviceProvider.swift`
- `IORow.swift` — disk/network IO row component
- `SettingsView.swift`, `ActivationView.swift`, `LicenseManager.swift`

---

## Global Design System

### Color Palette (observed from screenshots)

| Token | Value | Usage |
|-------|-------|-------|
| Background window | `#0d0f17` approx | App window bg, near black dark navy |
| Sidebar bg | `#111420` approx | Left sidebar, slightly lighter than window |
| Sidebar selected | `#1e3a5f` approx | Selected sidebar item (blue highlight) |
| Card bg | `#161925` approx | Content cards in all sections |
| Card border | subtle 1px darker border | Slightly visible card edges |
| Primary blue | `#4A90D9` / `#5B9FE8` approx | Active sidebar item, blue icons |
| Green (normal) | `#30D158` / `#34C759` | Normal temp, healthy status, progress bars |
| Yellow (warning) | `#FFD60A` / `#FF9500` | Elevated temperature warning |
| Red (critical) | `#FF453A` / `#FF3B30` | Fan at limit (red progress bar shown) |
| Text primary | `#FFFFFF` or `#F0F0F0` | Headings, large values |
| Text secondary | `#8E8EA0` approx | Labels, subtitles |
| Text muted | `#5A5A72` approx | Section header labels (MONITOR, CONTROL etc) |
| Separator/string | `#333333` | (extracted from binary) |

### Typography

All text uses SF Pro (system font, macOS default for SwiftUI).

| Element | Estimated Size | Weight | Notes |
|---------|---------------|--------|-------|
| Page title ("Fan Control") | ~28–32pt | Semibold | Top of content area |
| Page subtitle | ~13pt | Regular | Gray, below title |
| Section header ("LIVE THERMAL SENSORS") | ~10–11pt | Semibold | ALL CAPS, letter-spaced |
| Sensor card temperature value | ~22–26pt | Bold | Large numeric readout |
| Sensor card label | ~9–10pt | Medium | ALL CAPS small label above temp |
| Stat card large value (Overview) | ~20–22pt | Bold | RPM, %, GB values |
| Stat card label | ~9pt | Regular | ALL CAPS label below value |
| Fan RPM large display | ~28pt | Bold | In fan control cards |
| Fan min/max labels | ~11pt | Regular | Below slider range |
| Battery detail rows | ~13pt | Regular | Left label, right value |
| Section subheader ("MEMORY DETAILS") | ~10pt | Semibold | ALL CAPS section divider |
| Status message | ~12–13pt | Regular | Bottom notification bar |

### Spacing System

Observed consistent 8pt base unit:
- Window padding: ~20–24pt from edges
- Card internal padding: ~16pt
- Gap between cards in grid: ~12pt
- Gap between sections: ~20–24pt
- Sidebar item height: ~36–38pt logical (spacing 36–37pt between button y coords)
- Sidebar item padding: ~8pt top/bottom, ~16pt left
- Section label to first item gap: ~20pt

### Corner Radius

- Content cards: ~10–12pt corner radius
- Progress bars/sliders: pill shape (fully rounded)
- Fan control cards (Left Fan / Right Fan): ~12pt
- Sidebar selected item indicator: left-edge bar or full row rounded ~6pt

### Shadows / Elevation

Minimal shadow. Cards have no visible drop shadow — depth is achieved purely through background color contrast (card slightly lighter than window bg). The `GlassEffectView.swift` suggests a glass/blur material is used somewhere (possibly the sidebar or settings overlay).

---

## Sidebar Layout

**Width**: ~90–95pt logical
**Background**: Dark navy, slightly different from main content
**Items**:

```
[BreezeKit Logo + "BreezeKit" / "SYSTEM PRO"]   y≈60–80

MONITOR  (section label, muted gray, ~10pt caps)
  [icon] Overview                               button y=137
  [icon] Thermal                                button y=173
  [icon] Memory                                 button y=211 (approx)
  [icon] Processes                              button y=246 (approx)

CONTROL  (section label)                        y≈312
  [icon] Fan Control                            button y=334
  [icon] Storage                                button y=372

TOOLS    (section label)                        y≈435
  [icon] Clean                                  button y=457
  [icon] Downloads                              button y=496

SYSTEM   (section label)                        y≈559
  [icon] Battery                                button y=581
  [icon] Network                                button y=616
  [icon] Disk I/O                               button y=651
  [icon] Devices                                button y=686

[Trial badge / Upgrade to Pro button]
[Time display] [SYSTEM ACTIVE]
[Settings gear icon]
```

Sidebar uses `scroll area` as container — supports scrolling if items overflow.

**Icons**: SF Symbols (inferred from symbol names in binary):
- Thermal: `thermometer.medium` or `thermometer.sun.fill`
- Fan Control: `wind` / fan icon
- Battery: `battery.75percent`
- Network: `network`
- Storage: `internaldrive.fill`
- Clean: `shippingbox.fill` or `sparkles`
- Downloads: `arrow.down.circle.fill`

**Selected state**: Row gets blue highlight background, icon and text turn white/bright.

---

## Thermal Tab — Detailed Specification

**Page heading**: "Thermal"
**Page subtitle**: "Temperature readings across all sensors"

### Hero / Driving Sensor Card

A full-width card at the top showing the highest-priority sensor:
- Large temperature value (e.g. "58°") in white, ~40–48pt bold
- Status badge inline: "NORMAL" in green pill, "ELEVATED" in yellow pill
- Sensor name below (e.g. "CPU Core 1")
- Status message text (e.g. "Normal operating temperature. This is typical for everyday use.")
- Left side: circular ring gauge (`TemperatureRing`) showing temperature fill
  - Ring colors: green = normal, yellow = elevated, red = critical
  - This is the "SELECT DRIVING SENSOR" — user can pick which sensor drives this hero card

**Strings for status messages**:
- Normal: "Normal operating temperature. This is typical for everyday use."
- Elevated: "Temperature is elevated. Consider reducing workload."
- Cool: "Temperatures are low. Your Mac is running cool with minimal load."

### Thermal Zones Grid

**Section label**: "THERMAL ZONES" (ALL CAPS, muted gray, ~10pt semibold)

**Grid layout**: 4 columns × 2 rows (responsive — may adapt to window width)
**Card size**: approximately 160–180pt wide × 90–100pt tall
**Card gap**: ~12pt
**Card corner radius**: ~10–12pt
**Card background**: `#161925` approx (dark navy, slightly lighter than window bg)
**Card border**: 1px subtle border, slightly lighter than card bg

**Sensors shown (8 total on this machine)**:
```
Row 1: CPU Efficiency | CPU Performance | CPU Core 1 | CPU Core 2
Row 2: GPU Die        | SSD             | SSD Controller | Battery
```

**Card anatomy (top to bottom)**:
```
[Icon - SF Symbol thermometer, colored per status]   top-left of card, ~14pt
[Sensor name label - ALL CAPS ~9pt semibold, muted]  below icon or top area
[Temperature value - ~22–26pt bold, white]           center/bottom
[Thin colored progress bar at very bottom of card]   full card width, pill
```

Color coding on cards:
- Normal (below warning threshold): Blue tint on icon + text label, green progress bar
- Warning (at/above warningTemp): Yellow/orange tint on icon, yellow bar
- Critical (at/above criticalTemp): Red tint on icon, red bar

**Temperature thresholds** (from binary analysis: `criticalTemp`, `warningTemp`, `ThermalThresholds`):
- Normal: green — inferred 0–70°C
- Warning: yellow — inferred 70–85°C (exact values in `ThermalThresholds` struct)
- Critical: red — inferred 85°C+

**Peak indicator**: Top-right of the grid section shows "Peak: XX°C" — the highest reading across all sensors. Color-coded same as the sensor that holds the peak.

**Live updates**: Section labeled "LIVE THERMAL SENSORS" — data refreshes continuously (configurable in Settings: "How often sensors refresh").

**Sensor data source**: SMC via `app.breezekit.smchelper` privileged helper. Sensor names are SMC key names mapped to human-readable labels.

---

## Fan Control Tab — Detailed Specification

**Page heading**: "Fan Control"
**Page subtitle**: "Set fan speed manually or let smart mode manage it"

### Live Thermal Sensors (repeated mini-grid)

Same 4-column × 2-row sensor grid as Thermal tab, but smaller cards. Shows all 8 sensors live.
- **Peak** shown top-right: "PEAK: XX°C"
- Cards are compact — icon + value + small name label
- Same color thresholds apply

### Fan Control Cards

Two cards side by side (full width split 50/50):

**Left Fan card** and **Right Fan card** — identical layout:

```
[Card header row]
  "Left Fan" / "Right Fan"   [AUTO] [SMART] [MANUAL]  toggle button group

[Current RPM - large]
  [fan icon ~18pt] "7,851 RPM"   ~28pt bold white

[Progress bar - colored, pill shaped, full width]
  Color: green (normal), red/orange (at max)

[Range row]
  "1,200"                         "3,300"
   (min RPM, small gray text)     (max RPM, small gray text)
```

**Fan modes** (segmented picker with 3 options):
- `AUTO` — system manages fan automatically
- `SMART` — BreezeKit smart algorithm controls based on temperature
- `MANUAL` — user sets target RPM

**State variables** (from binary):
- `currentLeftRPM`, `currentRightRPM` — live readings
- `leftTargetRPM`, `rightTargetRPM` — manual target
- `leftMinRPM`, `leftMaxRPM`, `rightMinRPM`, `rightMaxRPM` — range limits
- `smartFraction` — 0.0–1.0 value for smart mode position
- `drivingSensor` — which sensor drives smart mode
- `isSmartUpdating` — animation state

**Footer button**: "Reset All to Auto" — centered, ghost/secondary button style

**Status header**: When fan control is active, shows "FAN CONTROL ACTIVE" badge in the live area.

**Smart mode interaction**: "SELECT DRIVING SENSOR" section — user picks which thermal sensor drives the smart fan algorithm.

---

## Overview Tab

**Page heading**: "Overview"
**Page subtitle**: "System status at a glance"

### Hero CPU Temperature Ring

- Large circular ring gauge at top-center
- Shows CPU temperature with ring fill colored by threshold
- Below ring: temperature value (e.g. "2°") and "CPU TEMPERATURE" label
- Ring has a subtle green glow/fill at the top indicating minimal load

### Stat Cards Row

4 cards in a horizontal row:
```
[7765 RPM]    [7805 RPM]    [41.9%]    [69%]
FAN LEFT      FAN RIGHT     CPU LOAD   MEMORY
```
- Card bg: dark navy card
- Value: ~20pt bold white
- Label: ~9pt ALL CAPS muted gray

### Battery + Network Row

2 wide cards:
```
[Battery icon] Charging  Health 86%     [Network] 130 KB/s download  34.5 KB/s upload
```

### Top Processes

Scrollable list of top CPU-consuming processes:
- App icon, app name, memory MB, CPU % on right
- List rows have subtle separator
- Strings: "Spark", "Google Chrome", "MacVitals", etc. (live data)

---

## Memory Tab

**Page heading**: "Memory"
**Page subtitle**: "RAM usage and pressure"

### Memory Usage Card

Full-width card:
- "MEMORY USAGE" section label (ALL CAPS)
- Large value: "18.4 GB of 24 GB" (~28pt bold)
- Badge top-right: "77% USED" (in orange/yellow when high)
- Segmented horizontal progress bar (orange/purple/gray fill)
- 2×2 grid of breakdown values:
  - Active: X GB | Wired: X GB
  - Compressed: X GB | Free: X GB

### Memory Details Card

- "MEMORY DETAILS" section label
- Table rows:
  - App Memory — right value in blue
  - Cached Files — right value in blue
  - Swap Used — right value in orange (warning color if non-zero)
  - Physical RAM — right value in gray

---

## Processes Tab

**Page heading**: "Processes"
**Page subtitle**: "Running apps sorted by resource usage"

### Process List

Full-width scrollable list:
- Column headers: "PROCESS NAME" | "MEMORY" | "CPU %"
- Row: [App icon 28pt] [App name bold / memory size gray] | [Memory GB] | [CPU% in color]
- CPU % color: green when low, yellow when moderate, orange/red when high
- Rows have subtle hover state
- Component: `ProcessListRow.swift`

---

## Storage Tab

**Page heading**: "Storage"
**Page subtitle**: "What's using your disk space"

### Storage Capacity Card

Full-width card:
- "STORAGE CAPACITY" section label
- Large: "402 GB used of 460 GB"
- Badge top-right: "57.6 GB free"
- Full-width segmented bar: blue (System/Other) + gray (Free Space)
- Legend below bar: "System / Other 402 GB | Free Space 57.6 GB"

### Scan Button

- Full-width prominent blue button: "Scan System Storage" with refresh icon
- After scan: shows `RECLAIMABLE STORAGE` section with deep file analysis

---

## Clean Tab

**Page heading**: "Clean"
**Page subtitle**: "Remove caches, logs, and build artifacts"

### Reclaimable Storage Card

- "RECLAIMABLE STORAGE" label
- Large: "0 B selected"
- "SCAN SYSTEM" button (small, top-right of card)

### Empty State

When not yet scanned:
- Dark card with centered sparkle/leaf icon (teal/green)
- Heading: "Ready to Analyze"
- Subtext: "Find safe-to-remove system junk and caches"

**Clean categories** (from binary strings):
- Application logs older than 7 days
- Chrome, Safari, Firefox browser caches
- Crash reports & diagnostics
- Build caches & downloaded dependencies
- Downloaded package bottles
- Compressed files like .zip, .dmg, and disk images
- Temporary files that apps can regenerate when needed
- Files that don't fit standard categories
- Archives
- Desktop
- Documents

---

## Downloads Tab

**Page heading**: "Downloads"
**Page subtitle**: "Multi-threaded file downloader"

### URL Input Area

- Card with URL text field: "Paste download URL here..."
- "PASTE FROM CLIPBOARD" link below
- Chunk selector: "4 CHUNKS" (segmented or stepper)
- "START DOWNLOAD" blue button

### Empty / Active State

- Empty: dark card, centered cloud download icon, "No Downloads", "Paste a URL above to start a high-speed download"
- Active: progress items with filename, progress bar, speed, status

---

## Battery Tab

**Page heading**: "Battery"
**Page subtitle**: "Charge, health, and power draw"

### Main Battery Card

Left: large circular donut ring showing charge %, with lightning bolt when charging.
Right metrics (4 rows):
- Health: 86%
- Cycles: 310
- Power Draw: 40.9 W
- Time Left: 1h 11m

Status badge (full-width row below): green pill — "Battery is healthy. Normal wear for 310 charge cycles."

### Battery Details Card

"BATTERY DETAILS" section header, table rows:
- Condition: Normal
- Temperature: 30.6°C (in warning-orange when elevated)
- Voltage: 12.49 V
- Current: 3249 mA
- Design Capacity: 6249 mA
- Current Max: 5632 mA
- Charging Rate: 3249 mA
- Serial: FXY9H5GN010GU000FWK

---

## Network Tab

**Page heading**: "Network"
**Page subtitle**: "Throughput and connection details"

### Live Throughput Cards

Two cards stacked:
- Download: [orange down-arrow icon] "218 KB/s" — "..." menu top-right
- Upload: [orange up-arrow icon] "500 KB/s" — "..." menu top-right

Mini sparkline graph next to each value (orange dots/bars).

### Network Details Card

"NETWORK DETAILS" section header, table rows:
- Interface: en0
- Local IP: 192.168.0.227
- Total Downloaded: 367 MB (in blue)
- Total Uploaded: 600 MB (in orange)

Status bar: green pill — "Normal network activity. Totals shown are cumulative since last boot."

---

## Disk I/O Tab

**Page heading**: "Disk I/O"
**Page subtitle**: "Read and write activity"

### Live IO Cards

Two cards stacked (same style as Network):
- Disk Read: [green icon] "42.2 MB/s"
- Disk Write: [red icon] "8.2 MB/s"

### Cumulative Since Boot Card

"CUMULATIVE SINCE BOOT" section header, table rows:
- Total Read: 420 GB (in green)
- Total Written: 601 GB (in red/orange)

Status bar: green pill — "Normal disk activity. Cumulative totals are measured since last boot."

---

## Devices Tab

**Page heading**: "Devices"
**Page subtitle**: "USB, Thunderbolt, and display connections"

### Displays Section

"DISPLAYS" section header with "3 connected" badge top-right.

Each display as a card:
- Monitor icon, display name bold (e.g. "Color LCD")
- Resolution + refresh rate (e.g. "1512 x 982 @ 120.00Hz")
- 3 columns: CONNECTION | REFRESH | COLOR
  - Values: "spdisplays_internal" / "Unknown" | "60 Hz" | "8-bit"
- Bandwidth row:
  - "Need: 2.1 Gb/s" | "Available: Unknown"
  - Color dot indicator

**Footer button**: "Refresh Devices" with counterclockwise arrow icon.

**Empty state**: "Connect USB devices, displays, or docks to see details"

---

## Component Reference for MacVital Implementation

### Key Reusable Components

| Component | BreezeKit name | Description |
|-----------|---------------|-------------|
| Sensor grid card | Implied from TemperatureSection | Dark card, icon, label, value, colored bar |
| Temperature ring | `TemperatureRing` | Circular gauge for CPU temp |
| Stat card | `StatCard` | Compact metric with large value + ALL CAPS label |
| Fan slider card | From `FanControlSection` | RPM display + progress bar + mode toggle |
| IO row | `IORow` | Two-column metric row for disk/network |
| Glass card | `GlassEffectView` | Blur/glass effect background |
| Status pill | Inline in views | Green/yellow/red rounded status badge |
| Segmented mode toggle | SwiftUI Picker | AUTO / SMART / MANUAL |
| Progress bar | Full-width pill | Colored by threshold, at card bottom |
| Section header | Static text | ALL CAPS, letter-spaced, muted gray |

### Temperature Color Thresholds

```swift
// From binary: ThermalThresholds struct with warningTemp and criticalTemp
// Inferred values (actual stored in ThermalThresholds):
enum ThermalSeverity {
    case normal    // green  — below ~70°C
    case warning   // yellow — ~70–85°C
    case critical  // red    — above ~85°C
}
```

### Fan Control State Machine

```
FanMode: auto | smart | manual
- auto:   OS controls fans completely, BreezeKit reads only
- smart:  BreezeKit adjusts based on drivingSensor temperature
- manual: user sets targetRPM directly
```

### Sidebar Navigation Structure

```
MONITOR:  Overview, Thermal, Memory, Processes
CONTROL:  Fan Control, Storage
TOOLS:    Clean, Downloads
SYSTEM:   Battery, Network, Disk I/O, Devices
```

---

## SF Symbols Used

| Symbol | Location |
|--------|----------|
| `thermometer.medium` | Sensor cards |
| `thermometer.sun.fill` | Elevated temp |
| `thermometer.high` | Critical temp |
| `gauge.with.dots.needle.33percent` | CPU load gauge |
| `gauge.with.dots.needle.50percent` | CPU load gauge |
| `gauge.with.dots.needle.100percent` | CPU load gauge |
| `battery.75percent` | Battery sidebar icon |
| `bolt.horizontal.circle.fill` | Power/charging |
| `internaldrive.fill` | Storage |
| `network` | Network |
| `arrow.down.circle.fill` | Downloads |
| `arrow.up.circle.fill` | Upload |
| `arrow.down.doc.fill` | Download value |
| `arrow.up.doc.fill` | Upload value |
| `shippingbox.fill` | Clean/packages |
| `checkmark.circle.fill` | Healthy status |
| `exclamationmark.triangle.fill` | Warning |
| `exclamationmark.circle.fill` | Error/critical |
| `xmark.circle.fill` | Remove/error |
| `arrow.counterclockwise` | Refresh |
| `arrow.triangle.2.circlepath` | Auto mode |
| `square.stack.3d.up.fill` | Memory |
| `brain.head.profile` | Processes/CPU |
| `doc.on.clipboard` | Paste from clipboard |

---

## Implementation Priority for MacVital

Based on the reverse-engineering, the highest-value views to replicate are:

1. **Thermal tab** — 8-sensor grid, hero driving sensor card, TemperatureRing
2. **Fan Control tab** — Live sensor grid + 2 fan cards with RPM + mode toggles
3. **Overview tab** — Central CPU ring + 4 stat cards + battery/network + process list
4. **Sidebar** — Consistent 4-section navigation with section labels

The most distinctive visual element is the **sensor grid card** with:
- Dark card bg (~`#161925`)
- ALL CAPS small sensor label (~9pt, muted)
- Large temperature value (~24pt bold, white)
- SF Symbol thermometer icon colored by severity
- Thin full-width colored progress bar at card bottom (green/yellow/red)
- 4-column grid layout with ~12pt gaps and ~10pt corner radius

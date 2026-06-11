# macpow & XRG UI Design Research
*Research date: 2026-04-04 | Purpose: Inform MacVital HTML mockup visual design*

---

## 1. macpow

**Repository:** https://github.com/k06a/macpow  
**Type:** Terminal UI (TUI) — runs in macOS Terminal / iTerm2  
**Platform:** Apple Silicon only (M1–M5), macOS 12+  
**Language:** Rust  
**License:** MIT  

### Screenshot URLs
- `https://raw.githubusercontent.com/k06a/macpow/main/screenshot.png` (main screenshot, 107.7 KB PNG)

### What the Screenshot Shows
The macpow interface is a full-terminal dark-mode TUI with the following visible structure:

**Header / title bar:**
- "Power Tree [9/58]" label top-left
- Column headers: `Component`, `Freq`, `Temp`, `Power`, `Cumulative`, `History`
- Battery status inline: "Battery 72% (4h 31m remaining, 13 cycles, 78.2 Wh)"
- AirPods status line beneath battery

**Tree structure (left column):**
- Root node: Apple M5 Max (Mac17,7)
- Expandable/collapsible subtrees with `+`/`-` prefix characters and `└`/`├` tree lines
- Sections: SoC → CPU (E-Cores, P-Cores, per-core PACC0–4), GPU, ANE, DRAM, GPU SRAM, Media Engine, Camera ISP, SSD, Controller, NAND Flash, Display, Keyboard, Trackpad, Audio, Fans, Peripherals (Thunderbolt/PCIe, Ethernet, WiFi, Bluetooth)
- Software section at bottom: top 18 processes by total energy

**Data columns (right side of each row):**
- `Freq` — MHz value (e.g., 5556 MHz, 2045 MHz) shown as plain text
- `Temp` — °C range (e.g., 40°C [40–58])
- `Power` — Watts with sign (e.g., 9.426 W, -0.031 W)
- `Cumulative` — Wh (watt-hours total since reset)
- `History` — Sparkline bar chart (rightmost column), multi-color

**CPU display specifically:**
- CPU node shows aggregate: "(18 cores, 15%)" utilization
- E-Cores: 12 cores, 5% utilization — sub-tree showing PACC0–4 clusters
- P-Cores: 6 cores, 53% utilization — sub-tree showing PACC0–4 clusters
- Each per-core cluster shows: Freq in MHz | Temp °C range | Power in W | Cumulative Wh | Sparkline
- Utilization shown as percentage inline with the component name
- **Visual bar in the Freq/Temp columns:** colored block characters (green/yellow) showing utilization fill

**Per-process section:**
- Header: "Software (filter: top 18 by total)"
- Columns: process name + PID + size | Power (mW) | Disk | Network | History sparkline
- Example rows: Preview, macpow, Cursor, Disk Read, Paste, Mail, CursorNSViewService, Screen Sharing

**Bottom pinned chart:**
- Full-width bar/histogram chart pinned for "CPU (18 cores, 15%)"
- Two rows of bar charts: one at 100ms resolution, one at 1000ms
- Yellow/orange bars on dark background

**Bottom status bar:**
- Single line: `q quit | r reset | a avg:0s | l 250ms | ↑↓←→ tree | space pin | a<1W m<5W s<10W p>10W`

### Layout Style
- **Orientation:** Vertical tree, full terminal width and height
- **Structure:** Hierarchical collapsible tree (left) + tabular data columns (right) + history sparklines (far right)
- **No GUI chrome** — pure text/ANSI color TUI

### Chart Types
- **Inline sparkline bar charts:** The `History` column shows mini bar charts using block characters (▁▂▃▄▅▆▇█ style), each bar representing recent power usage
- **Pinned full-width histogram:** When Space is pressed on a row, a full-width multi-bar time-series chart appears at the bottom
- **Utilization bars:** Inline colored block fills in the component name column indicating % usage

### Color Scheme
- **Background:** Pure black (`#000000` / terminal default dark)
- **Primary text:** White/light gray
- **CPU/Performance components:** Green (`#00FF00` style) for normal, yellow for elevated
- **High power / hot:** Red/orange indicators
- **Sparkline bars:** Multi-color — green (low), yellow (medium), red (high), with color-coded legend: `a<1W` (dimmed), `m<5W` (yellow), `s<10W` (orange), `p>10W` (red/bright)
- **Section headers (Apple M5 Max, SoC, etc.):** Bright white or cyan
- **Tree lines:** Dim gray (`└`, `├`, `│` characters)
- **Selected row:** Highlighted background (lighter gray)
- **Battery line:** Green for healthy charge

### Memory Display
- "DRAM (103.6/128 GB)" — used/total in GB, inline in tree
- GPU SRAM separate line

### Disk Display
- SSD subtree: Controller, NAND Flash, Read/Write sub-items
- I/O rates shown in KB/s in the Power column context
- Write: 642.5 KB/s | Read: 0 B/s visible in screenshot

### Network Display
- Per-interface: Ethernet, WiFi (with signal dBm, mode, channel)
- Shown as Download/Upload rates: "15.8 KB/s", "15.8 KB/s"
- Per-process network also shown in the software section

### Battery Display
- Top-level line: "Battery 72% (4h 31m remaining, 13 cycles, 78.2 Wh)"
- In tree: Shows voltage, amperage, temperature range
- Power column: negative watts = charging, positive = discharging

### Overall Aesthetic
**Technical / information-dense terminal aesthetic.**
- No icons, no gradients, no rounded corners — pure ANSI TUI
- Resembles `htop` or `btop` but focused entirely on power/energy
- Dense information hierarchy with excellent keyboard navigation
- Appeals to developers and power users who live in the terminal
- Would NOT replicate well directly in HTML — but the data organization philosophy (tree hierarchy, per-component drill-down, history sparklines) is highly referenceable

---

## 2. XRG (X Resource Graph)

**Repository:** https://github.com/mikepj/XRG  
**Official site:** https://gaucho.software/xrg/  
**Type:** Native macOS GUI app — floating window that sits over desktop  
**Platform:** macOS (Intel + Apple Silicon), macOS 10.13+  
**Language:** Objective-C (88.1%)  
**License:** GPL-2.0  
**Current version:** 3.2.1 (October 31, 2023)  

### Screenshot URLs
- `https://gaucho.software/xrg/images/p/xrg-screenshot-1560.png` (398.6 KB — primary/large screenshot)
- `https://gaucho.software/xrg/images/l/xrg-2.5-screenshot-1500.png` (72.6 KB — older version screenshot)
- `https://gaucho.software/xrg/images/6/xrgicon128-128.png` (app icon)

### What the Screenshots Show

#### Large Screenshot (xrg-screenshot-1560.png)
XRG appears as a **narrow horizontal menubar-anchored strip** across the top of the screen, directly beneath the macOS menubar. The interface is a single long horizontal bar divided into labeled metric panels side by side.

**Visible panels left to right:**
1. **CPU** — Label "CPU" | value "1645" | second value "GPU 1.16G" | "7000" | dark background with colored graph
2. **Memory** — "Memory 10.28 MB" | values shown | colored fill graph
3. **Battery** — "99% Charged" | percentage + status text
4. **Fan Speed** — "Fan 1.728 rpm" | numeric value
5. **Net** — "Net 341.2M" | transfer value
6. **Disk** — "Disk 170.6M W" | write speed

Each panel has:
- A short ALL-CAPS or title-case label at left edge
- A numeric value
- A **filled area/bar graph** taking up the majority of the panel width
- Dark background (#000 or near-black) with colored graph fills

**CPU panel specifically:**
- Two sub-values visible (possibly User + System CPU %)
- Graph fills use a **stacked/layered color approach**: one color for user CPU, another for system CPU
- The graph appears to be a **scrolling time-series filled area chart** (like a "mountain" chart scrolling left)

#### Narrow Screenshot (xrg-2.5-screenshot-1500.png)
This shows an even more compact single-line view — the "XRG" label at far left, then panels:
- CPU: "106%" — bright blue/teal bar fill
- GPU: "590M" — text value, no graph visible at this size
- Mem: "1669M Vu" — orange/amber filled bar
- Battery: "99% Charged" — text only
- CPU Proximity: "108.6°F" — temperature
- Net: "8.73M/s" — teal/blue fill
- Disk: "54.72M/s" — teal/blue fill

### Layout Style
- **Orientation:** Horizontal strip — all panels side by side in one row
- **Anchoring:** Sits just below macOS menubar OR floats anywhere on screen (user-configurable)
- **Width:** Stretches full screen width or to a user-defined size
- **Height:** Very compact — approximately 20–30px tall in minimal mode, expandable to show more graph history
- **No window chrome in minimal mode** — borderless or very thin border
- Individual panels can be toggled on/off

### Chart Types
- **Scrolling filled area chart (mountain chart):** The primary graph type — data scrolls left as time passes, with a filled region below the line. This is the signature XRG visual.
- **Stacked area chart for CPU:** User time (one color) + System time (second color) stacked
- **Solid bar/fill for memory:** Shows used vs. free as filled proportion
- **Text-only panels for battery/temperature:** Some metrics are text + value only, no graph

### Color Scheme (from screenshots)
- **Background:** Near-black (`#0a0a0a` or pure `#000000`)
- **CPU graph:** Blue-teal (`#0088FF` style) for user, possibly purple/darker for system
- **Memory graph:** Orange/amber (`#FF8800` style) fill
- **Network graph:** Teal/cyan fill
- **Disk graph:** Teal/blue fill (similar to network)
- **Panel labels:** White or light gray text
- **Values:** White text, bold
- **Panel dividers:** Very subtle — slight darker line or gap between panels
- **Overall:** High contrast dark theme — colors are saturated and distinct per metric type

### CPU Display
- Shows CPU percentage (e.g., "106%" suggesting multi-core total)
- Scrolling filled area graph showing recent history
- Stacked colors: user CPU vs system CPU distinction
- In expanded mode: separate lines/graphs for each core possible (based on Sensors window in v3.0+)

### Memory Display
- Shows used memory in MB/GB (e.g., "1669M Vu" — likely Virtual Used)
- Orange/amber filled area graph showing utilization over time
- Possibly shows: active, wired, compressed as stacked fills

### Network Display
- Shows transfer rate in M/s (megabytes per second)
- Teal filled area graph
- Both download and upload may be separate colors or overlaid

### Disk Display
- Shows I/O rate in M/s
- Similar teal/blue filled area graph
- Read vs write possibly stacked

### Battery Display
- Text-only in compact mode: "99% Charged" or "4h 32m"
- No graph in the screenshots visible — purely numeric/text

### Temperature Display
- "CPU Proximity 108.6°F" — label + single temperature value
- Separate "Sensors" window introduced in v3.0 shows: current, min, average, max for all sensors

### Other Features
- **Weather module** — current conditions display
- **Stock market data** — ticker display
- These are unique to XRG vs other monitors

### Overall Aesthetic
**Classic macOS utility / information overlay aesthetic.**
- Reminiscent of early-to-mid 2000s macOS widgets and Konfabulator/Dashboard era
- Dark, unobtrusive horizontal strip designed to "always be visible" without interrupting workflow
- Functional over decorative — every pixel serves a data purpose
- Scrolling mountain charts give a "heartbeat monitor" / "oscilloscope" feel
- Color coding is consistent and immediately readable
- Appeals to users who want persistent ambient monitoring without opening a full app

---

## Comparison Summary Table

| Attribute | macpow | XRG |
|---|---|---|
| **UI Type** | Terminal TUI (full-screen) | Native GUI (floating strip) |
| **Layout** | Vertical tree, full terminal | Horizontal strip, all panels inline |
| **Primary chart type** | Sparkline bar charts (block chars) | Scrolling filled area (mountain) charts |
| **Color theme** | Black bg, green/yellow/red ANSI | Black bg, blue/orange/teal saturated fills |
| **CPU display** | Tree: per-core W + % bars + sparkline | Single % value + scrolling filled area |
| **Memory display** | "Used/Total GB" text in tree | Filled area graph + MB value |
| **Network display** | Per-interface KB/s + per-process | Rate M/s + scrolling fill graph |
| **Disk display** | Read/Write KB/s in tree | Rate M/s + scrolling fill graph |
| **Battery display** | % + time + voltage + amperage + temp | % + status text (text-only panel) |
| **Temperature** | Per-core/component °C ranges | Single sensor °F value + Sensors window |
| **Information density** | Extremely high (50+ components) | Medium (6–8 metric panels) |
| **Target user** | Developer / power user / Apple Silicon enthusiast | General macOS user wanting ambient monitoring |
| **Aesthetic** | Technical / terminal / developer | Retro macOS utility / oscilloscope |
| **Interaction** | Keyboard-driven, collapsible tree | Mostly passive / preferences-driven |
| **Window presence** | Takes over terminal session | Unobtrusive persistent strip |

---

## Design Takeaways for MacVital HTML Mockups

### From macpow:
1. **Hierarchical drill-down** is powerful — show system → component → sub-component
2. **Inline sparklines** next to each metric row give instant history context
3. **Color-coded power levels** (green/yellow/orange/red) map naturally to severity
4. **Per-process breakdown** is a killer feature — show top processes with their impact
5. **Column layout** (name | current value | historical chart) works extremely well
6. **Tree expand/collapse** reduces cognitive load while keeping detail available

### From XRG:
1. **Scrolling filled area charts** ("mountain charts") are the most visually distinctive system monitor pattern
2. **Horizontal strip layout** with labeled panels is instantly scannable
3. **Stacked color fills** for CPU (user vs system) is a clear and proven pattern
4. **Consistent color per metric type** (always orange for memory, always teal for network) builds instant recognition
5. **Compact persistent overlay** concept — show just enough at a glance
6. **High contrast dark theme** with saturated single-hue fills per panel

### Recommended MacVital Visual Direction:
- **Dark background** (#0f0f0f or #111111) — both apps confirm this is the standard
- **Per-metric color identity:** CPU = blue, Memory = orange/amber, Network = teal, Disk = purple, Battery = green
- **Scrolling/animated line chart** as primary graph (XRG style) + **mini sparkline bars** for secondary drill-down (macpow style)
- **Horizontal panel strip** for top-level overview + **expandable vertical detail** for per-component data
- **Stacked area charts** for CPU to show user/system/idle split clearly
- **No rounded corners or gradients** in graph areas — flat fills, sharp edges, technical feel
- **Monospaced font** for numeric values (matches terminal/technical aesthetic of both apps)


# MacVital — Missing Features & UX Gap Analysis

**Research Date**: April 2026
**Methodology**: GitHub issues analysis (exelban/stats — 37k stars), iStatMenus feature audit, competitor comparison (iStatMenus, Stats, Activity Monitor, iStatistica, Monit), UX pattern research
**Scope**: Identify what MacVital currently lacks vs. what users demonstrably need

---

## Research Summary

MacVital has strong per-module depth across 10 tabs. What it lacks is the connective tissue: a unified dashboard, alerting infrastructure, historical data at scale, data export, and the macOS ecosystem integrations (widgets, Spotlight, shortcuts) that power users expect from a pro tool. These gaps are all well-evidenced by real user demand in competitor issue trackers and reviews.

---

## What MacVital Currently Has (Baseline)

| Tab | Core Capability |
|-----|----------------|
| Memory | MacVitals sunburst + process tree |
| CPU | XRG histograms + macpow power tree |
| Thermal | MacPulse flat sensor list |
| Power/Energy | macpow tree + gauge cards |
| GPU | Half-circle gauges per engine |
| Disk | SMART + I/O + space breakdown |
| Network | Dual-axis chart + per-WiFi history |
| Processes | Sortable table + lifecycle + inspector |
| Fans | Spinning fans + curve editor + rules |
| Menu Bar Popover | Per-module configurable |

---

## Gap 1: No Overview/Dashboard Tab

**Evidence**: GitHub issue #2287 on exelban/stats — maintainer confirmed "pretty sure it will be added." Users explicitly ask for a single-pane view when working on a laptop without external monitors.

**What users want**: One screen that surfaces the critical number from every module. Not a duplicate of each tab — a health scorecard.

**Recommended design**:

```
[ Dashboard Tab ]

Row 1 — Status Indicators (RAG — Red/Amber/Green dots)
  CPU 34%  |  RAM 67%  |  GPU 12%  |  Thermal 68°C  |  Disk 78%  |  Battery 82%

Row 2 — Sparkline Row (last 60 seconds, one per module)
  CPU ▁▂▄▃▅▄  |  RAM ▅▅▅▅▆▆  |  Network ▁▁▃▇▅▂

Row 3 — Top 3 Process Hogs (CPU, RAM, GPU columns)
  Process      CPU%    RAM      GPU%
  Xcode        28%     4.2 GB   8%
  Safari       6%      1.1 GB   2%

Row 4 — Active Alerts Banner (if any thresholds breached)
  [!] CPU temperature has been above 85°C for 3 minutes
```

**Priority**: Critical — this is the most requested missing feature class across all competitor trackers.

---

## Gap 2: No Alerts/Notifications System

**Evidence**: Multiple high-reaction issues on Stats (#2436 duration-based CPU alerts, #2996 swap alerting, #1124 temperature threshold notifications). iStatMenus built a full rule engine around this — it is a core differentiator.

**What users need**:

- Threshold-based rules: "CPU > 90% for more than 60 seconds" → send macOS notification
- Recovery alerts: "CPU dropped back below 70%" (avoids alert fatigue if no recovery)
- Compound rules: "CPU > 85% AND Thermal > 80°C" → warn
- Persistent alerts: "Disk > 90% full" — stays until resolved
- Battery rules: "Below 20% and not charging" → notify
- Network rules: "Download speed drops below 1 Mbps" (connectivity monitoring)
- Fan rules: "Fan speed at maximum for 10+ minutes"

**UI location**: Settings > Alerts tab. Also surfaced as a banner on the Dashboard tab and a badge on the menu bar icon when active.

**Notification format**:
```
MacVital Alert
CPU has been above 90% for 5 minutes
Top process: Xcode (78%)     [View in MacVital]
```

**Priority**: High — no alerts means users must babysit the app. This is what separates a monitor from a monitoring system.

---

## Gap 3: Historical Data with Time-Range Selectors

**Evidence**: GitHub issue #1194 (Stats) — open since Nov 2022, cycled between "In Progress" and "Todo." Users explicitly request 24h, 7d, 30d views for CPU, RAM, GPU. Currently MacVital shows 180-second rolling windows per tab.

**What users need**:

| Time Range | Use Case |
|-----------|----------|
| 1 hour | Debug a performance issue that just happened |
| 24 hours | See daily usage patterns, peak times |
| 7 days | Find which day/app caused slowdowns |
| 30 days | Capacity planning, warranty troubleshooting |

**Implementation approach**:

- Background data daemon writes sampled metrics to a local SQLite DB (1 row per 10 seconds = ~8,640 rows/day = ~250 KB/day — negligible)
- Each tab gets a time-range selector (1h / 24h / 7d / 30d) above its primary chart
- Charts rerender from SQLite on range change
- Dashboard tab shows 24h sparklines by default

**Storage**: 30 days of data at 10-second intervals = ~7.5 MB. Completely acceptable.

**Priority**: High — the most technically substantial gap. Users treat 180-second windows as near-useless for post-hoc investigation.

---

## Gap 4: No Export / Report Feature

**Evidence**: Power users (developers, IT admins, support engineers) routinely need to document system state — for bug reports, warranty claims, performance regression analysis, or handing a Mac to a repair shop.

**What to build**:

**Quick Export (always available)**:
- "Copy System Snapshot" → clipboard JSON of all current readings
- "Save CSV" → all sensor readings + process table at current moment

**System Report (PDF)**:
```
MacVital System Report
Generated: 4 Apr 2026, 11:43 PM

Hardware
  Model: MacBook Pro 14" (2023)
  Chip: Apple M2 Pro
  RAM: 16 GB  |  Storage: 512 GB SSD
  macOS: Sonoma 14.4.1  |  Serial: C02XY...  |  Uptime: 3d 4h

Performance (last 24 hours)
  CPU avg: 34%  |  Peak: 89% at 2:14 PM (Xcode build)
  RAM avg: 11.2 GB  |  Peak: 14.8 GB at 2:17 PM
  Thermal avg: 52°C  |  Peak: 88°C at 2:15 PM

Disk Health
  SMART Status: Verified
  Read: 2.3 TB lifetime  |  Write: 1.8 TB lifetime
  Power-on hours: 1,247h

Active Alerts (last 7 days): 3
  ...
```

**Use cases**: AppleCare calls, dev team bug reports, IT fleet management, personal record-keeping.

**Priority**: Medium — high value for a specific user segment (power users, IT), low effort relative to impact.

---

## Gap 5: No macOS Widgets (WidgetKit)

**Evidence**: GitHub issues #2733 and #3042 on Stats show widget bugs and requests — indicating active demand. iStatMenus 7 launched widgets as a headline feature.

**What to build**:

| Widget Size | Content |
|------------|---------|
| Small (2x2) | Single metric: CPU % or RAM % as a gauge |
| Medium (4x2) | 3-metric row: CPU + RAM + Thermal with sparklines |
| Large (4x4) | Full Dashboard summary: all 6 metrics + top processes |
| Lock Screen | Battery % + thermal status |

**Technical**: WidgetKit + AppIntent for interactivity. Widget reads from shared App Group UserDefaults (main app writes, widget reads — no separate daemon needed).

**Reliability**: Stats users report "No data" widget bugs — MacVital must write to App Group on every metric refresh, not just on app launch.

**Priority**: Medium — a macOS-native differentiator. Users who live in Mission Control want glanceable metrics without opening the app.

---

## Gap 6: No Keyboard Shortcuts

**Evidence**: Standard expectation for any pro Mac app. Activity Monitor uses Cmd+1–5 for tab switching. No system monitor currently does this well.

**Recommended shortcuts**:

| Shortcut | Action |
|---------|--------|
| Cmd+1 | Dashboard tab |
| Cmd+2 | CPU tab |
| Cmd+3 | Memory tab |
| Cmd+4 | Thermal tab |
| Cmd+5 | Power/Energy tab |
| Cmd+6 | GPU tab |
| Cmd+7 | Disk tab |
| Cmd+8 | Network tab |
| Cmd+9 | Processes tab |
| Cmd+0 | Fans tab |
| Cmd+R | Force refresh all metrics |
| Cmd+E | Export / Save report |
| Cmd+, | Open Preferences |
| Cmd+F | Focus process search (in Processes tab) |
| Space | Pause/resume live updates |

**Implementation**: Standard SwiftUI `.keyboardShortcut()` modifiers. Zero risk, high polish signal.

**Priority**: Low-Medium — easy to implement, high perceived quality impact for keyboard-driven users.

---

## Gap 7: Dark / Light Mode Handling

**Evidence**: GitHub issue theme — "Dark mode for main interface." MacVital likely already follows system appearance, but the question is whether it handles it intentionally with a manual override.

**What to build**:

- Auto mode (follows system): default
- Force Dark: override regardless of system
- Force Light: override regardless of system
- Setting exposed in Preferences > Appearance

**Why it matters**: Users running Macs in "Auto" mode get a jarring light-mode app when they switch at sunset. A per-app override is a small but noticed quality detail.

**Priority**: Low — almost certainly already working via SwiftUI. Add manual override only.

---

## Gap 8: Compact Mode vs. Detailed Mode

**Evidence**: iStatMenus has a "Combined" menu bar mode merging multiple items. Stats lets users disable modules to cut CPU usage by 50%. Users on smaller screens (13" MacBook, external display at 1080p) want less visual density.

**What to build**:

Two view density options per tab:

- **Compact**: Key metric number + one chart. Fits in less vertical space. Good for reference monitoring.
- **Detailed** (default): Current full layout with all sub-sections, breakdowns, and annotations.

Toggle: View menu > "Compact Mode" or a density icon in the toolbar. Persisted per-tab or globally.

**Also consider**: A "Focus Mode" for the Processes tab — hides all processes below 1% CPU/RAM to reduce noise when debugging one specific process.

**Priority**: Medium — particularly important for the Thermal and Fans tabs which have long lists.

---

## Gap 9: System Information Tab

**Evidence**: "About This Mac" in macOS is embarrassingly thin (just model, chip, RAM, macOS version). Users doing support calls, warranty claims, or capacity planning need far more. No competitor does this well.

**Recommended content**:

```
[ System Info Tab ]

Hardware Identity
  Model: MacBook Pro 14-inch, Nov 2023
  Chip: Apple M2 Pro (10-core CPU, 16-core GPU, 16-core Neural Engine)
  Serial Number: C02XY1234567
  Hardware UUID: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
  Board ID: Mac14,9

Memory
  Installed: 16 GB LPDDR5
  Bandwidth: 200 GB/s
  Unified Memory: Yes

Storage
  Drive: APPLE SSD AP0512R
  Capacity: 500.1 GB  |  Available: 124.3 GB  |  Used: 375.8 GB
  SMART: Verified
  Power-On Hours: 1,247h
  Power Cycle Count: 847
  Percentage Used (NVMe): 3%

Software
  macOS: Sonoma 14.4.1 (Build 23E224)
  Kernel: Darwin 23.4.0
  Uptime: 3 days, 4 hours, 17 minutes
  Last Boot: 1 Apr 2026, 7:26 AM
  Last Sleep: 4 Apr 2026, 10:14 PM

Network Identity
  Hostname: MyMac.local
  Primary MAC: XX:XX:XX:XX:XX:XX
  IPv4: 192.168.1.xxx  |  IPv6: fe80::...
  Public IP: [fetch on demand]

Warranty & Support
  Purchase Date: [estimated from serial — link to checkcoverage.apple.com]
  [Check Coverage button → opens Apple's coverage page with serial pre-filled]
```

**Priority**: Medium-High — zero competition in this space. Fills a genuine daily-use need for IT and power users.

---

## Gap 10: Comparison / Baseline View

**Evidence**: A sophisticated feature with no current competitor implementation. The use case: "I just installed App X and my battery life got worse — prove it."

**What to build**:

- "Set Baseline" button: snapshots all current metrics into a named baseline (e.g., "Before installing Xcode", "Clean boot")
- Baseline view: side-by-side current vs. baseline for each metric
- Delta highlighting: metrics that changed more than 10% since baseline are highlighted

**Secondary use case**: "This week vs. last week" — automatic weekly comparison report (emailed or shown in app).

**Priority**: Low — valuable differentiator but complex to implement well. Phase 2 feature.

---

## Competitor Feature Matrix

| Feature | MacVital | iStatMenus | Stats | Activity Monitor |
|---------|----------|-----------|-------|-----------------|
| Per-module tabs | Yes | No (menu bar only) | Popup only | Yes (5 tabs) |
| Dashboard/Overview | No | No | No | No |
| Alerts/Notifications | No (fans only) | Yes (full rule engine) | Basic | No |
| Historical data (24h+) | No | Yes (bandwidth only) | No | No |
| Time-range selector | No | Partial | No | No |
| Data export / PDF report | No | No | No | No |
| macOS Widgets | No | Yes | Partial (buggy) | No |
| Keyboard shortcuts | No | Partial | No | Yes (Cmd+1-5) |
| Manual dark/light override | Unknown | Yes | Yes | Follows system |
| Compact mode | No | Yes (combined bar) | Yes (module disable) | No |
| System Info tab | No | Partial | No | No |
| Comparison / baseline | No | No | No | No |
| Process kill from app | Yes (inspector) | No | No | Yes |
| Fan curve editor | Yes | No | No | No |
| Network per-WiFi history | Yes | No | No | No |
| Sunburst memory viz | Yes | No | No | No |

MacVital is already ahead on per-module depth and unique visualizations. The gaps are entirely in the cross-cutting infrastructure layer.

---

## Prioritised Implementation Roadmap

### Phase 1 — Core Infrastructure (High Impact, High Urgency)

1. **Alerts/Notifications system** — rule builder with macOS notifications. Without this, MacVital is a passive viewer, not a monitor.
2. **Historical data store** — SQLite daemon writing 10-second samples. All time-range selectors depend on this.
3. **Dashboard/Overview tab** — use the historical data store. RAG status row + sparklines + active alerts banner.

### Phase 2 — Power User Features (High Impact, Medium Effort)

4. **System Info tab** — pure read, no new data infrastructure needed. High perceived value.
5. **Export / PDF report** — needs historical data from Phase 1. Leverage it.
6. **Time-range selectors on existing tabs** — once SQLite store exists, this is just chart binding.

### Phase 3 — Platform Integration (Medium Impact, Worth Doing)

7. **WidgetKit widgets** — Small + Medium sizes first. Needs App Group setup.
8. **Keyboard shortcuts** — one afternoon of work, high polish signal.
9. **Compact mode** — view density toggle per tab.

### Phase 4 — Differentiators (Lower Urgency, High Distinctiveness)

10. **Comparison / baseline view** — unique in the market.
11. **Dark/Light mode manual override** — polish detail.
12. **Connectivity history overlay on Network chart** — requested in Stats issue #1194 comments.

---

## UX Patterns Validated by Competitor Research

**From iStatMenus audit**:
- Alert rules should support AND conditions (CPU > X AND Temperature > Y), not just single-metric thresholds
- Battery alerts need a "not charging" conditional to avoid false positives
- Weather is a differentiator feature iStatMenus has — MacVital could skip this

**From Stats GitHub issues**:
- Sensor support for new Apple Silicon chips (M3, M4, M5) breaks on each new chip release — must be maintained actively
- Network units: users hate auto-scaling (MB/s vs KB/s flipping). Consider a fixed-unit option.
- CPU efficiency vs. performance core split is heavily requested — MacVital already has this, which is good
- Swap memory monitoring (#2996) — MacVital's Memory tab should show swap used/free/in/out explicitly

**From Activity Monitor comparison**:
- Users expect Cmd+1 through Cmd+N for tab switching — MacVital's current keyboard behavior is unknown but should be verified
- "Force quit" from the process table is expected — MacVital's inspector should expose this

**General UX patterns for system monitors**:
- Color coding must be consistent: green = healthy, amber = warning, red = critical — across every tab, every metric
- Tooltips on every gauge/chart explaining what the metric means and what thresholds are normal
- Right-click on any process row should offer: "Show in Finder," "Force Quit," "Copy PID," "Open in Activity Monitor"
- The menu bar popover open time must be under 100ms — any lag here destroys trust in the whole app

---

## Specific Metric Gaps Found in Research

Beyond UI/feature gaps, these specific data points are requested but appear absent from the current MacVital spec:

| Metric | Requested In | Current Status |
|--------|-------------|---------------|
| Swap used / free / swap-in / swap-out rates | Stats #2996 | Not visible in Memory tab |
| Apple Neural Engine (ANE) utilization | Stats #2897 | Not in GPU tab |
| DNS server (IPv4 + IPv6) | Stats #2789 | Not in Network tab |
| CPU load average context (1m / 5m / 15m trend) | Standard Unix metric | In spec but verify it's surfaced |
| Per-core frequency (not just per-core usage) | Stats issues | In spec — verify showing on CPU tab |
| Disk power-on hours + power cycle count (SMART) | Standard SMART | In Disk tab spec — verify |
| Battery cycle count + design capacity | Standard — heavily used | Verify in Power tab |
| Public IP address | iStatMenus differentiator | Not in Network tab |
| Bluetooth device battery levels | Stats README | Not in any current tab |

---

## Accessibility Gaps

No competitor handles this well — it is a genuine differentiation opportunity:

- All gauges need `.accessibilityLabel` and `.accessibilityValue` with natural language descriptions ("CPU usage: 34 percent, normal")
- Color-only status indicators (green/amber/red dots) must have a shape or pattern alternative for color-blind users
- Chart animations should respect `reduceMotion` system preference
- All interactive elements need minimum 44x44pt touch targets (even on macOS, for trackpad accessibility)
- Font size should scale with macOS accessibility text size settings

---

*Research by UX Researcher agent — MacVital gap analysis*
*Next step: Prioritise Phase 1 items with the development team and begin alert rule data model design*

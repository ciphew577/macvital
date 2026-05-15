# Process Tree — SwiftUI Implementation Spec
**Version**: 1.0
**Source**: Deep binary reverse-engineering of MacVitals 1.7.1 + pixel-level screenshot analysis
**Date**: 2026-04-04
**Status**: Implementation-ready

---

## 1. What We Know From the Binary

### 1.1 Exact Source File Map (from embedded debug symbols)

MacVitals' left panel is split across exactly these Swift files:

| File | Role |
|------|------|
| `ProcessTreeView.swift` | Top-level SwiftUI wrapper — hosts `ProcessTreeNSView` |
| `ProcessTreeCoordinator.swift` | `NSViewRepresentable` coordinator — bridges SwiftUI ↔ AppKit |
| `ProcessTreeCells.swift` | All cell views: `BaseOutlineCellView`, `AppCellView`, `ProcessCellView`, `GroupHeaderCellView` |
| `ProcessOutlineView.swift` | Subclassed `NSOutlineView` — custom row heights, right-click, arrow keys |
| `ProcessMemoryManager.swift` | Data model owner — holds `_cachedCategoryGroups`, `_cachedMaxAppMemory`, `_cachedTotalAppMemory`, `_cachedAppFootprintTotal` |
| `FilterBar.swift` | Search bar NSView — placeholder "Filter by app name, bundle ID, or process name..." |
| `DesignSystem.swift` | Design tokens — spacing, colors, row heights |

### 1.2 Outline Item Class Hierarchy (confirmed from mangled names)

```
NSObject
  └── OutlineGroupItem    (_TtC9MacVitals16OutlineGroupItem)   — category row (User Apps / User Processes / System)
  └── OutlineAppItem      (_TtC9MacVitals14OutlineAppItem)     — app row (zoom.us, tmux, etc.)
  └── OutlineProcessItem  (_TtC9MacVitals18OutlineProcessItem) — child PID row (zoom.us Helper, caphost, log)
```

These are reference types (`class`, not `struct`) — confirmed by `_TtC` prefix.

### 1.3 Cell View Hierarchy

```
NSTableCellView (BaseOutlineCellView)
  └── GroupHeaderCellView   — rendered for OutlineGroupItem rows
  └── AppCellView           — rendered for OutlineAppItem rows
  └── ProcessCellView       — rendered for OutlineProcessItem rows
```

The `BaseOutlineCellView` holds shared subviews: `memoryBarView` (`MemoryBarNSView`) and `memoryDeltaView` (`MemoryDeltaNSView`).

### 1.4 Data Model Types

```swift
// From binary: physFootprint is the memory metric (not RSS)
AppMemoryInfo {
    name: String
    bundleId: String
    physFootprint: UInt64       // phys_footprint from task_info — NOT RSS
    processOnlyMemory: UInt64   // per-process memory (for child rows)
}

CategoryGroup {
    type: SidebarGroupType      // enum: .userApp | .userProcess | .system
    apps: [GroupedCategoryApps]
    totalPhysFootprint: UInt64
}

GroupedCategoryApps {
    appMemoryInfo: AppMemoryInfo
    processes: [CopyableProcessInfo]
}

// SidebarGroupType enum values (from "User AppUser ProSystem" concatenated string):
enum SidebarGroupType {
    case userApp       // "User Apps"
    case userProcess   // "User Processes"
    case system        // "System"
}

// ProcessOwnerCategory: used to decide which SidebarGroupType an app belongs to
ProcessOwnerCategory

// Per-process lightweight struct (sent to child rows):
CopyableProcessInfo {
    name: String
    memory: UInt64?
    processOnlyMemory: UInt64
}
```

### 1.5 Memory Bar Logic

From `_cachedMaxAppMemory` and `_cachedTotalAppMemory`:
- **App row bar**: `fillFraction = app.physFootprint / cachedMaxAppMemory` — proportional to the highest-memory app in the visible list, NOT total RAM
- **Group header bar**: `fillFraction = group.totalPhysFootprint / totalRAM` — proportional to physical RAM
- **Child process bar**: `fillFraction = proc.processOnlyMemory / app.physFootprint` — proportional to parent app total

### 1.6 Delta Indicator

`MemoryDeltaNSView` tracks four time windows:
- `delta30s` — 30-second change
- `delta1m` — 1-minute change
- `delta2m` — 2-minute change
- `delta5m` — 5-minute change

The user-visible labels ("30s Delta", "1m Delta", "2m Delta", "5m Delta") confirm these are selectable in settings.

Visual encoding:
- Red dot/triangle = memory **increasing** (`systemRedColor`)
- Green dot/triangle = memory **decreasing** (`systemGreenColor`)
- No dot = stable / no change detected

### 1.7 Row Heights

Two distinct constants exist in the binary:
- `rowHeightGroup` — group header rows (confirmed distinct from app rows)
- `rowHeightApp` — app and process rows

From screenshots (measured at 2x Retina, divided by 2):
- `rowHeightGroup` = **24pt** logical
- `rowHeightApp` = **20pt** logical (app rows and child process rows share this)

Intercell spacing: `setIntercellSpacing:` called with **0pt vertical** (rows are flush, no gaps).

### 1.8 Indentation

`setIndentationPerLevel:` is called. From screenshots:
- Level 0 (group headers): 0pt indent — `OutlineGroupItem` is a root item
- Level 1 (app rows): 16pt indent per level × 1 = **16pt** (NSOutlineView default is 16pt)
- Level 2 (child process rows): 16pt × 2 = **32pt**

The expand arrow (`processTreeLeftArrow` / `processTreeRightArrow`) is a custom image asset, not an SF Symbol chevron. These are stored in the app bundle.

### 1.9 Filter / Search

`FilterBar.swift` is a standalone `NSView` (not SwiftUI). Key facts:
- Placeholder: `"Filter by app name, bundle ID, or process name..."`
- Searches: app name, bundle ID, process name
- When active: `searchExpandedGroups` and `searchExpandedItems` are saved so state can be restored after clearing search
- `outlineView:shouldTypeSelectForEvent:withCurrentSearchString:` is implemented (type-to-search on the outline is enabled)

### 1.10 Expand/Collapse State Persistence

- `expandedGroups` — persisted set of expanded group IDs
- `expandedItems` — persisted set of expanded item IDs
- `defaultExpandedGroupIds` — groups expanded by default on first launch
- `isItemExpanded:` / `collapseItem:` / `expandItem:` are all used

### 1.11 Sort/Group Logic

- `isGroupRow` — `NSOutlineView` delegate returns `true` for `OutlineGroupItem`; group rows get distinct styling
- `isGroupStart` — first item after a group header
- `isPinned` — `OutlineAppItem` can be pinned (`_isPinned` ivar)
- `showWarningIcon` — `_showWarningIcon` on `OutlineAppItem` — shown when `browserMemoryHog` is true
- `sortDescriptors` — `outlineView:sortDescriptorsDidChange:` implemented, sort is interactive
- `browserMemoryHog` — flag set when an app (typically a browser) is consuming disproportionate memory

### 1.12 Context Menu Actions (from `ProcessContextMenu.swift`)

```swift
enum ContextMenuItemType {
    case forceTerminate     // "Force Quit" — menuForceClose:
    case showInFinder       // "Show in Finder" — menuShowInFinder:
    case showProcessInFinder // "Show Process in Finder" — menuShowProcessInFinder:
    case openApp            // "Open App" — onOpenApp
}
```

---

## 2. Exact Visual Spec (from screenshots)

### 2.1 Panel Layout

```
┌─── Left Panel (~35% window width, ~420–460pt logical) ────────────┐
│ ┌──────────────────────────────────────────────────────────────┐  │
│ │  🔍  Filter by app name, bundle ID, or process name...       │  │  ← FilterBar, ~28pt tall
│ └──────────────────────────────────────────────────────────────┘  │
│ ─────────────────────────────────── 1pt separator #2a2e3a ───────  │
│                                                                     │
│  ▼  📁  User Apps  (1)              202.9 MB [━━━━━━━━━━━━━━━━━]  │  ← Group header, 24pt
│    ▼  [icon]  zoom.us               202.9 MB [━━━━━━━━━━━━━━━━━]  │  ← App row, 20pt, indent 16pt
│          [•]  zoom.us               184.7 MB    [━━━━━━━━━━━━━]   │  ← Child row, 20pt, indent 32pt
│          [•]  caphost               11.4 MB     [━━━]             │
│          [•]  log                    7.8 MB     [━━]              │
│                                                                     │
│  ▼  📁  User Processes  (1)         15.8 GB [━━━━━━━━━━━━━━━━━]  │
│    ▼  [⚙]  2.191                    7.07 GB [━━━━━━━━━━━━━━━━━]  │
│          [•]  2.191                 5.73 MB     [━━]              │
│          [•]  node                  ...                            │
│    ▶  [⚙]  tmux                    3.28 GB [━━━━━━━━━━━]         │
│    ▶  [⚙]  bash                    1.64 GB [━━━━━━]              │
│    ▶  [icon]  caffeinate            1.6 MB  [━]                   │
│                                                                     │
│  ▼  📁  System  (3)               329.5 MB [━━━━━━━━━━━━━━━━━]   │
│    ▶  [icon]  Notification Centre  72.6 MB  [━━━━━━━━━━━━━━━]    │
│    ▶  [icon]  Calendar             65.0 MB  [━━━━━━━━━━━━━━]     │
│    ▶  [icon]  calserviced          31.1 MB  [━━━━━━━━━]          │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.2 Row Color Spec

| State | Background |
|-------|-----------|
| Group header (normal) | `#1e1e1e` — same as panel, no distinction |
| App row (normal) | transparent |
| App row (hovered) | `rgba(255,255,255,0.04)` — `#252525` approx |
| App row (selected) | `rgba(0,122,255,0.15)` — selection tint |
| Child row (normal) | transparent |
| Child row (hovered) | `rgba(255,255,255,0.04)` |

### 2.3 Typography Per Row Level

| Element | Size | Weight | Color |
|---------|------|--------|-------|
| Group header text | 12pt | Medium (500) | `#bfbfbf` |
| Group count badge "(1)" | 11pt | Regular | `#737373` |
| Group memory value | 10pt monospaced | Regular | `#9a9a9a` |
| App name | 13pt | Regular | `#dddddd` |
| App memory value | 12pt monospaced | Regular | `#9a9a9a` |
| Child process name | 11pt | Regular | `#737373` |
| Child memory value | 9–10pt monospaced | Regular | `#555555` |

### 2.4 Memory Bar Spec

```
[memory value text]  [track──────────]
                     [fill ████      ]
```

| Property | Group Row | App Row | Child Row |
|----------|-----------|---------|-----------|
| Track width | 80pt | 80pt | 80pt |
| Track height | 4pt | 3pt | 3pt |
| Track fill | `#3a3a3a` | `#3a3a3a` | `#3a3a3a` |
| Bar fill (normal) | `#007aff` | `#007aff` | `#007aff` opacity 0.6 |
| Bar fill (critical) | `#ff4246` | `#ff4246` | `#ff4246` opacity 0.6 |
| Corner radius | 2pt | 1.5pt | 1.5pt |
| Proportional to | Total RAM | Max app memory | Parent app memory |

### 2.5 Icons

| Row Level | Icon | Size | Corner Radius |
|-----------|------|------|---------------|
| Group header | `folder.fill` SF Symbol | 11pt | n/a |
| App row (has bundle) | `NSRunningApplication.icon` | 16×16pt | 4pt |
| App row (no bundle) | `gearshape` SF Symbol | 12pt | n/a |
| Child process row | No icon (just indent) | — | — |

---

## 3. Implementation Options

MacVitals uses **NSOutlineView** (confirmed: `ProcessOutlineView` subclasses it, coordinator implements full `NSOutlineViewDataSource` + `NSOutlineViewDelegate`). The binary imports `NSOutlineViewDataSource`, `NSOutlineViewDelegate`, `outlineView:isItemExpandable:`, `outlineView:shouldCollapseItem:`, `outlineView:shouldExpandItem:`, `outlineViewItemDidCollapse:`, `outlineViewItemDidExpand:`.

### Option A: NSOutlineView via NSViewRepresentable (Recommended — MacVitals' actual approach)

**Pros**: Native macOS feel, correct row selection, keyboard navigation, proper type-select, best performance for large process lists (100+ rows), disclosure triangles work correctly, `isGroupRow` support for non-indented group headers.

**Cons**: More code, requires coordinator pattern.

### Option B: SwiftUI List with DisclosureGroup

**Pros**: Less boilerplate, SwiftUI-native, no coordinator needed.

**Cons**: `DisclosureGroup` has no `isGroupRow` equivalent (group headers get indented), poor performance with 100+ items and rapid refresh, no native type-select, harder to get pixel-perfect row heights.

**Recommendation**: Use Option A. MacVitals' exact approach. The group header non-indentation and the `isGroupRow` behavior are not achievable cleanly in SwiftUI List.

---

## 4. Option A: Full NSOutlineView Implementation

### 4.1 Data Model (update `AppMemoryMonitor.swift`)

```swift
// Replace current AppMemoryInfo with MacVitals-matching model:

import Foundation
import AppKit

// Matches MacVitals' SidebarGroupType enum
enum ProcessCategory {
    case userApp        // Has GUI, regularApp activation policy
    case userProcess    // Background process, no GUI
    case system         // OS-level (launchd children, system agents)
}

// Matches MacVitals' CopyableProcessInfo
struct ProcessInfo: Identifiable {
    let id: Int32           // PID
    let name: String        // process name (p_comm from sysctl)
    let physFootprint: UInt64   // phys_footprint from task_info
    let parentPID: Int32
}

// Matches MacVitals' AppMemoryInfo
struct AppMemoryInfo: Identifiable {
    let id: UUID
    let name: String
    let bundleId: String
    var physFootprint: UInt64       // total across all child processes
    var processOnlyMemory: UInt64   // largest single process footprint
    var processes: [ProcessInfo]
    var icon: NSImage?
    var color: NSColor
    var category: ProcessCategory
    var isPinned: Bool = false
    var isBrowserMemoryHog: Bool = false
}

// Matches MacVitals' CategoryGroup
struct CategoryGroup {
    let type: ProcessCategory
    var displayName: String {
        switch type {
        case .userApp: return "User Apps"
        case .userProcess: return "User Processes"
        case .system: return "System"
        }
    }
    var apps: [AppMemoryInfo]
    var totalPhysFootprint: UInt64 {
        apps.reduce(0) { $0 + $1.physFootprint }
    }
}
```

### 4.2 Process Enumeration (replace `ps aux` approach)

The current `ps aux` approach uses RSS (resident set size). MacVitals uses `physFootprint` from `task_vm_info`. This is the key difference — physFootprint matches what Activity Monitor shows.

```swift
// In AppMemoryMonitor.swift — replace getProcessList()

import Darwin

private func getPhysFootprint(pid: pid_t) -> UInt64 {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
    
    var task: task_t = 0
    guard task_for_pid(mach_task_self_, pid, &task) == KERN_SUCCESS else { return 0 }
    defer { mach_port_deallocate(mach_task_self_, task) }
    
    let kr = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(task, task_flavor_t(TASK_VM_INFO), $0, &count)
        }
    }
    guard kr == KERN_SUCCESS else { return 0 }
    return info.phys_footprint
}

// NOTE: task_for_pid requires com.apple.security.get-task-allow entitlement
// OR the helper XPC process with elevated privileges (MacVitals uses XPCClient.swift)
// For the main app, use proc_info syscall as fallback:

import System

private func getMemoryViaProcInfo(pid: pid_t) -> UInt64 {
    var info = proc_taskinfo()
    let size = Int32(MemoryLayout<proc_taskinfo>.size)
    let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &info, size)
    guard result == size else { return 0 }
    return info.pti_resident_size  // RSS fallback
}
```

### 4.3 App Categorization (matching MacVitals' `ProcessOwnerCategory`)

```swift
// In AppMemoryMonitor.swift

private func categorize(_ app: NSRunningApplication) -> ProcessCategory {
    switch app.activationPolicy {
    case .regular:
        return .userApp      // Has Dock icon, menu bar, GUI window
    case .accessory:
        return .userProcess  // Menu bar app without Dock icon
    case .prohibited:
        return .userProcess  // Background agent
    @unknown default:
        return .userProcess
    }
}

private func categorizeByBundleId(_ bundleId: String) -> ProcessCategory {
    let systemPrefixes = ["com.apple.", "com.google.chrome.helper", "com.microsoft."]
    if systemPrefixes.contains(where: { bundleId.hasPrefix($0) }) {
        // com.apple. processes: further split by type
        // Processes owned by launchd with com.apple. prefix go to System
        return .system
    }
    return .userProcess
}
```

### 4.4 Outline Item Classes

```swift
// ProcessTreeItems.swift

import AppKit

// MARK: - OutlineGroupItem
final class OutlineGroupItem: NSObject {
    let group: CategoryGroup
    
    init(group: CategoryGroup) {
        self.group = group
    }
    
    var children: [OutlineAppItem] {
        group.apps.map { OutlineAppItem(app: $0) }
    }
}

// MARK: - OutlineAppItem
final class OutlineAppItem: NSObject {
    var app: AppMemoryInfo
    var isPinned: Bool = false
    var showWarningIcon: Bool = false  // browserMemoryHog
    
    init(app: AppMemoryInfo) {
        self.app = app
        self.isPinned = app.isPinned
        self.showWarningIcon = app.isBrowserMemoryHog
    }
    
    var children: [OutlineProcessItem] {
        app.processes.sorted { $0.physFootprint > $1.physFootprint }
                     .map { OutlineProcessItem(process: $0, parentApp: app) }
    }
}

// MARK: - OutlineProcessItem
final class OutlineProcessItem: NSObject {
    let process: ProcessInfo
    let parentApp: AppMemoryInfo
    
    init(process: ProcessInfo, parentApp: AppMemoryInfo) {
        self.process = process
        self.parentApp = parentApp
    }
}
```

### 4.5 NSViewRepresentable Wrapper

```swift
// ProcessTreeView.swift

import SwiftUI
import AppKit

struct ProcessTreeView: NSViewRepresentable {
    @ObservedObject var monitor: AppMemoryMonitor
    @Binding var selectedAppID: UUID?
    var searchText: String
    
    func makeNSView(context: Context) -> ProcessTreeNSView {
        let view = ProcessTreeNSView()
        view.coordinator = context.coordinator
        view.setup()
        return view
    }
    
    func updateNSView(_ nsView: ProcessTreeNSView, context: Context) {
        context.coordinator.searchText = searchText
        context.coordinator.refresh(
            groups: monitor.categoryGroups,
            maxAppMemory: monitor.cachedMaxAppMemory,
            totalRAM: monitor.totalRAM
        )
        nsView.outlineView.reloadData()
        // Restore expansion state
        nsView.restoreExpansionState()
    }
    
    func makeCoordinator() -> ProcessTreeCoordinator {
        ProcessTreeCoordinator(selectedAppID: $selectedAppID)
    }
}

// MARK: - Container NSView
final class ProcessTreeNSView: NSView {
    var coordinator: ProcessTreeCoordinator!
    let outlineView = ProcessOutlineView()
    private let scrollView = NSScrollView()
    
    func setup() {
        // Column setup
        let column = NSTableColumn(identifier: .init("main"))
        column.isEditable = false
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        outlineView.headerView = nil
        outlineView.backgroundColor = NSColor(white: 0.118, alpha: 1)
        outlineView.intercellSpacing = NSSize(width: 0, height: 0)
        outlineView.setIndentationPerLevel(16)
        outlineView.indentationMarkerFollowsCell = true
        outlineView.usesAlternatingRowBackgroundColors = false
        
        outlineView.dataSource = coordinator
        outlineView.delegate = coordinator
        outlineView.allowsEmptySelection = true
        outlineView.allowsMultipleSelection = false
        outlineView.focusRingType = .none
        
        scrollView.documentView = outlineView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.backgroundColor = NSColor(white: 0.118, alpha: 1)
        scrollView.scrollerStyle = .overlay
        
        addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
    
    func restoreExpansionState() {
        coordinator.expandedGroupItems.forEach { item in
            outlineView.expandItem(item)
        }
    }
}

// MARK: - Subclassed NSOutlineView
final class ProcessOutlineView: NSOutlineView {
    override var acceptsFirstResponder: Bool { false }
    
    // Custom disclosure button using processTreeLeftArrow / processTreeRightArrow assets
    // If assets not available, use system triangle
}
```

### 4.6 Coordinator (DataSource + Delegate)

```swift
// ProcessTreeCoordinator.swift

import AppKit
import SwiftUI

final class ProcessTreeCoordinator: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
    
    @Binding var selectedAppID: UUID?
    
    // Data
    var groupItems: [OutlineGroupItem] = []
    var appItemCache: [UUID: OutlineAppItem] = [:]  // id → OutlineAppItem
    var maxAppMemory: UInt64 = 1
    var totalRAM: UInt64 = 1
    var searchText: String = ""
    var expandedGroupItems: Set<OutlineGroupItem> = []
    
    // Default: all groups expanded
    private let defaultExpandedGroupIds: Set<ProcessCategory> = [.userApp, .userProcess, .system]
    
    init(selectedAppID: Binding<UUID?>) {
        _selectedAppID = selectedAppID
    }
    
    func refresh(groups: [CategoryGroup], maxAppMemory: UInt64, totalRAM: UInt64) {
        self.maxAppMemory = maxAppMemory
        self.totalRAM = totalRAM
        
        let filtered = applyFilter(groups: groups)
        self.groupItems = filtered.map { OutlineGroupItem(group: $0) }
        
        // Rebuild app item cache for O(1) lookup
        appItemCache = [:]
        for groupItem in groupItems {
            for appItem in groupItem.children {
                appItemCache[appItem.app.id] = appItem
            }
        }
    }
    
    private func applyFilter(groups: [CategoryGroup]) -> [CategoryGroup] {
        guard !searchText.isEmpty else { return groups }
        return groups.compactMap { group in
            let filtered = group.apps.filter { app in
                app.name.localizedCaseInsensitiveContains(searchText) ||
                app.bundleId.localizedCaseInsensitiveContains(searchText) ||
                app.processes.contains { $0.name.localizedCaseInsensitiveContains(searchText) }
            }
            guard !filtered.isEmpty else { return nil }
            return CategoryGroup(type: group.type, apps: filtered)
        }
    }
    
    // MARK: - NSOutlineViewDataSource
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil { return groupItems.count }
        if let group = item as? OutlineGroupItem { return group.children.count }
        if let app = item as? OutlineAppItem { return app.children.count }
        return 0
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil { return groupItems[index] }
        if let group = item as? OutlineGroupItem { return group.children[index] }
        if let app = item as? OutlineAppItem { return app.children[index] }
        fatalError("Unexpected item type")
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if item is OutlineGroupItem { return true }
        if let app = item as? OutlineAppItem { return app.children.count > 1 }
        return false  // Process items have no children
    }
    
    // MARK: - NSOutlineViewDelegate — Row Height
    
    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        if item is OutlineGroupItem { return 24 }
        return 20  // Both app rows and child process rows
    }
    
    // MARK: - NSOutlineViewDelegate — isGroupRow
    
    func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
        return item is OutlineGroupItem
    }
    
    // MARK: - NSOutlineViewDelegate — Cell Views
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        if let group = item as? OutlineGroupItem {
            let cell = outlineView.makeView(
                withIdentifier: .init("GroupHeaderCellView"),
                owner: nil
            ) as? GroupHeaderCellView ?? GroupHeaderCellView()
            cell.configure(group: group.group, totalRAM: totalRAM)
            return cell
        }
        
        if let app = item as? OutlineAppItem {
            let cell = outlineView.makeView(
                withIdentifier: .init("AppCellView"),
                owner: nil
            ) as? AppCellView ?? AppCellView()
            cell.configure(
                app: app.app,
                maxMemory: maxAppMemory,
                showWarning: app.showWarningIcon
            )
            return cell
        }
        
        if let proc = item as? OutlineProcessItem {
            let cell = outlineView.makeView(
                withIdentifier: .init("ProcessCellView"),
                owner: nil
            ) as? ProcessCellView ?? ProcessCellView()
            cell.configure(
                process: proc.process,
                parentMemory: proc.parentApp.physFootprint
            )
            return cell
        }
        
        return nil
    }
    
    // MARK: - NSOutlineViewDelegate — Row View
    
    func outlineView(_ outlineView: NSOutlineView, rowViewForItem item: Any) -> NSTableRowView? {
        let row = ProcessTreeRowView()
        return row
    }
    
    // MARK: - NSOutlineViewDelegate — Selection
    
    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        return item is OutlineAppItem || item is OutlineProcessItem
    }
    
    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard let outline = notification.object as? NSOutlineView else { return }
        let row = outline.selectedRow
        guard row >= 0 else {
            selectedAppID = nil
            return
        }
        if let appItem = outline.item(atRow: row) as? OutlineAppItem {
            selectedAppID = appItem.app.id
        }
    }
    
    // MARK: - NSOutlineViewDelegate — Expand/Collapse
    
    func outlineView(_ outlineView: NSOutlineView, shouldExpandItem item: Any) -> Bool { true }
    func outlineView(_ outlineView: NSOutlineView, shouldCollapseItem item: Any) -> Bool { true }
    
    func outlineViewItemDidExpand(_ notification: Notification) {
        guard let item = notification.userInfo?["NSObject"] as? OutlineGroupItem else { return }
        expandedGroupItems.insert(item)
    }
    
    func outlineViewItemDidCollapse(_ notification: Notification) {
        guard let item = notification.userInfo?["NSObject"] as? OutlineGroupItem else { return }
        expandedGroupItems.remove(item)
    }
    
    // MARK: - NSOutlineViewDelegate — Sort
    
    func outlineView(_ outlineView: NSOutlineView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        // Sort apps within each group by memory (descending) — MacVitals default
        for i in groupItems.indices {
            groupItems[i].group.apps.sort { $0.physFootprint > $1.physFootprint }
        }
        outlineView.reloadData()
    }
    
    // MARK: - Type Select
    
    func outlineView(
        _ outlineView: NSOutlineView,
        shouldTypeSelectFor event: NSEvent,
        withCurrentSearch searchString: String?
    ) -> Bool {
        return true  // Enable type-to-search on the outline
    }
}
```

### 4.7 Cell Views

```swift
// ProcessTreeCells.swift

import AppKit

// MARK: - BaseOutlineCellView (shared subviews)
class BaseOutlineCellView: NSTableCellView {
    let memoryBarView = MemoryBarNSView()
    let memoryDeltaView = MemoryDeltaNSView()
    let memoryLabel = NSTextField(labelWithString: "")
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        setupMemoryLabel()
        setupMemoryBar()
        setupDeltaView()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupMemoryLabel() {
        memoryLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        memoryLabel.textColor = NSColor(white: 0.5, alpha: 1)
        memoryLabel.alignment = .right
        memoryLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(memoryLabel)
    }
    
    private func setupMemoryBar() {
        memoryBarView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(memoryBarView)
    }
    
    private func setupDeltaView() {
        memoryDeltaView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(memoryDeltaView)
    }
}

// MARK: - GroupHeaderCellView
final class GroupHeaderCellView: BaseOutlineCellView {
    private let folderIcon = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let countLabel = NSTextField(labelWithString: "")
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        identifier = .init("GroupHeaderCellView")
        setupSubviews()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupSubviews() {
        // Folder icon
        folderIcon.image = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: nil)
        folderIcon.contentTintColor = NSColor(white: 0.35, alpha: 1)
        
        // Name label
        nameLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        nameLabel.textColor = NSColor(white: 0.75, alpha: 1)
        
        // Count label "(n)"
        countLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        countLabel.textColor = NSColor(white: 0.38, alpha: 1)
        
        // Memory bar override: 4pt height, proportional to totalRAM
        memoryBarView.barHeight = 4
        memoryLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        
        [folderIcon, nameLabel, countLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // folder icon: 11pt, left after disclosure arrow
            folderIcon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            folderIcon.centerYAnchor.constraint(equalTo: centerYAnchor),
            folderIcon.widthAnchor.constraint(equalToConstant: 14),
            folderIcon.heightAnchor.constraint(equalToConstant: 12),
            
            nameLabel.leadingAnchor.constraint(equalTo: folderIcon.trailingAnchor, constant: 4),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            countLabel.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 3),
            countLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            // Memory bar: fixed right
            memoryBarView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            memoryBarView.centerYAnchor.constraint(equalTo: centerYAnchor),
            memoryBarView.widthAnchor.constraint(equalToConstant: 80),
            memoryBarView.heightAnchor.constraint(equalToConstant: 4),
            
            // Memory label: left of bar
            memoryLabel.trailingAnchor.constraint(equalTo: memoryBarView.leadingAnchor, constant: -6),
            memoryLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            // Delta: right of bar
            memoryDeltaView.leadingAnchor.constraint(equalTo: memoryBarView.trailingAnchor, constant: 4),
            memoryDeltaView.centerYAnchor.constraint(equalTo: centerYAnchor),
            memoryDeltaView.widthAnchor.constraint(equalToConstant: 8),
            memoryDeltaView.heightAnchor.constraint(equalToConstant: 8),
        ])
    }
    
    func configure(group: CategoryGroup, totalRAM: UInt64) {
        nameLabel.stringValue = group.displayName
        countLabel.stringValue = "(\(group.apps.count))"
        memoryLabel.stringValue = formatBytes(group.totalPhysFootprint)
        
        let fraction = totalRAM > 0
            ? min(1.0, Double(group.totalPhysFootprint) / Double(totalRAM))
            : 0
        memoryBarView.setFraction(fraction)
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        let mb = Double(bytes) / 1_048_576
        if mb >= 1 { return String(format: "%.1f MB", mb) }
        return String(format: "%.0f KB", Double(bytes) / 1024)
    }
}

// MARK: - AppCellView
final class AppCellView: BaseOutlineCellView {
    private let iconView = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let warningIcon = NSImageView()  // showWarningIcon support
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        identifier = .init("AppCellView")
        setupSubviews()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupSubviews() {
        // Icon: 16×16, corner radius 4pt
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.wantsLayer = true
        iconView.layer?.cornerRadius = 4
        iconView.layer?.masksToBounds = true
        
        // Name
        nameLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        nameLabel.textColor = NSColor(white: 0.87, alpha: 1)
        nameLabel.lineBreakMode = .byTruncatingTail
        
        // Warning icon (browserMemoryHog)
        warningIcon.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "High memory usage")
        warningIcon.contentTintColor = NSColor.systemOrange
        warningIcon.isHidden = true
        
        memoryLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        memoryLabel.textColor = NSColor(white: 0.5, alpha: 1)
        
        [iconView, nameLabel, warningIcon].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),
            
            nameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 5),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: warningIcon.leadingAnchor, constant: -4),
            
            warningIcon.trailingAnchor.constraint(equalTo: memoryLabel.leadingAnchor, constant: -6),
            warningIcon.centerYAnchor.constraint(equalTo: centerYAnchor),
            warningIcon.widthAnchor.constraint(equalToConstant: 12),
            warningIcon.heightAnchor.constraint(equalToConstant: 12),
            
            memoryBarView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            memoryBarView.centerYAnchor.constraint(equalTo: centerYAnchor),
            memoryBarView.widthAnchor.constraint(equalToConstant: 80),
            memoryBarView.heightAnchor.constraint(equalToConstant: 3),
            
            memoryLabel.trailingAnchor.constraint(equalTo: memoryBarView.leadingAnchor, constant: -6),
            memoryLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            memoryDeltaView.leadingAnchor.constraint(equalTo: memoryBarView.trailingAnchor, constant: 4),
            memoryDeltaView.centerYAnchor.constraint(equalTo: centerYAnchor),
            memoryDeltaView.widthAnchor.constraint(equalToConstant: 6),
            memoryDeltaView.heightAnchor.constraint(equalToConstant: 6),
        ])
    }
    
    func configure(app: AppMemoryInfo, maxMemory: UInt64, showWarning: Bool) {
        // Icon
        if let icon = app.icon {
            iconView.image = icon
        } else {
            iconView.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
            iconView.contentTintColor = NSColor(white: 0.5, alpha: 1)
        }
        
        nameLabel.stringValue = app.name
        memoryLabel.stringValue = formatBytes(app.physFootprint)
        warningIcon.isHidden = !showWarning
        
        let fraction = maxMemory > 0
            ? min(1.0, Double(app.physFootprint) / Double(maxMemory))
            : 0
        memoryBarView.setFraction(fraction)
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 { return String(format: "%.2f GB", gb) }
        let mb = Double(bytes) / 1_048_576
        if mb >= 0.1 { return String(format: "%.1f MB", mb) }
        return String(format: "%.0f KB", Double(bytes) / 1024)
    }
}

// MARK: - ProcessCellView (child PID row)
final class ProcessCellView: BaseOutlineCellView {
    private let nameLabel = NSTextField(labelWithString: "")
    private let pidLabel = NSTextField(labelWithString: "")
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        identifier = .init("ProcessCellView")
        setupSubviews()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupSubviews() {
        nameLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        nameLabel.textColor = NSColor(white: 0.55, alpha: 1)
        nameLabel.lineBreakMode = .byTruncatingTail
        
        // PID label (optional — visible at wider widths)
        pidLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular)
        pidLabel.textColor = NSColor(white: 0.3, alpha: 1)
        
        memoryLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular)
        memoryLabel.textColor = NSColor(white: 0.35, alpha: 1)
        
        [nameLabel, pidLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            memoryBarView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            memoryBarView.centerYAnchor.constraint(equalTo: centerYAnchor),
            memoryBarView.widthAnchor.constraint(equalToConstant: 80),
            memoryBarView.heightAnchor.constraint(equalToConstant: 3),
            
            memoryLabel.trailingAnchor.constraint(equalTo: memoryBarView.leadingAnchor, constant: -6),
            memoryLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            memoryDeltaView.leadingAnchor.constraint(equalTo: memoryBarView.trailingAnchor, constant: 4),
            memoryDeltaView.centerYAnchor.constraint(equalTo: centerYAnchor),
            memoryDeltaView.widthAnchor.constraint(equalToConstant: 6),
            memoryDeltaView.heightAnchor.constraint(equalToConstant: 6),
        ])
    }
    
    func configure(process: ProcessInfo, parentMemory: UInt64) {
        nameLabel.stringValue = process.name
        pidLabel.stringValue = "\(process.id)"
        memoryLabel.stringValue = formatBytes(process.physFootprint)
        
        let fraction = parentMemory > 0
            ? min(1.0, Double(process.physFootprint) / Double(parentMemory))
            : 0
        memoryBarView.setFraction(fraction, opacity: 0.6)  // Child bars at 60% opacity
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let mb = Double(bytes) / 1_048_576
        if mb >= 1 { return String(format: "%.1f MB", mb) }
        return String(format: "%.0f KB", Double(bytes) / 1024)
    }
}
```

### 4.8 MemoryBarNSView

```swift
// MemoryBarNSView.swift

import AppKit

final class MemoryBarNSView: NSView {
    var fraction: Double = 0 { didSet { needsDisplay = true } }
    var barHeight: CGFloat = 3
    var isCritical: Bool = false  // true → red fill instead of blue
    
    func setFraction(_ value: Double, opacity: Double = 1.0) {
        self.fraction = value
        self.alphaValue = CGFloat(opacity)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        // Track
        let trackRect = NSRect(
            x: 0,
            y: (bounds.height - barHeight) / 2,
            width: bounds.width,
            height: barHeight
        )
        let trackPath = NSBezierPath(roundedRect: trackRect, xRadius: 2, yRadius: 2)
        NSColor(white: 0.23, alpha: 1).setFill()
        trackPath.fill()
        
        // Fill
        let fillWidth = max(2, bounds.width * CGFloat(fraction))
        let fillRect = NSRect(
            x: 0,
            y: (bounds.height - barHeight) / 2,
            width: fillWidth,
            height: barHeight
        )
        let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: 1.5, yRadius: 1.5)
        let fillColor: NSColor = isCritical
            ? NSColor(red: 1.0, green: 0.259, blue: 0.275, alpha: 1)  // #ff4246
            : NSColor(red: 0, green: 0.478, blue: 1, alpha: 1)         // #007aff
        fillColor.setFill()
        fillPath.fill()
    }
}
```

### 4.9 MemoryDeltaNSView

```swift
// MemoryDeltaNSView.swift

import AppKit

enum MemoryDeltaDirection {
    case increasing  // red
    case decreasing  // green
    case stable      // hidden
}

final class MemoryDeltaNSView: NSView {
    var direction: MemoryDeltaDirection = .stable {
        didSet { isHidden = (direction == .stable); needsDisplay = true }
    }
    
    // MacVitals tracks these 4 windows — use whichever is selected in settings:
    var delta30s: Int64 = 0
    var delta1m: Int64 = 0
    var delta2m: Int64 = 0
    var delta5m: Int64 = 0
    
    func update(previous: UInt64, current: UInt64) {
        let diff = Int64(current) - Int64(previous)
        if diff > 512 * 1024 {        // +512KB threshold for "increasing"
            direction = .increasing
        } else if diff < -512 * 1024 { // -512KB threshold for "decreasing"
            direction = .decreasing
        } else {
            direction = .stable
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard direction != .stable else { return }
        
        // Draw small filled circle
        let size = min(bounds.width, bounds.height)
        let rect = NSRect(
            x: (bounds.width - size) / 2,
            y: (bounds.height - size) / 2,
            width: size,
            height: size
        )
        let path = NSBezierPath(ovalIn: rect)
        
        let color: NSColor = direction == .increasing
            ? .systemRed     // systemRedColor
            : .systemGreen   // systemGreenColor
        color.setFill()
        path.fill()
    }
}
```

### 4.10 ProcessTreeRowView

```swift
// ProcessTreeRowView.swift

import AppKit

final class ProcessTreeRowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        // Custom selection: blue tint instead of system selection color
        if isSelected {
            NSColor(red: 0, green: 0.478, blue: 1, alpha: 0.15).setFill()
            NSBezierPath(rect: bounds).fill()
        }
    }
    
    override func drawBackground(in dirtyRect: NSRect) {
        // No alternating colors — transparent background
        NSColor.clear.setFill()
        NSBezierPath(rect: bounds).fill()
    }
    
    // Hover state: handled by mouseEntered/mouseExited if needed
    // MacVitals uses NSTrackingArea per row for hover highlighting
}
```

### 4.11 FilterBar Integration

```swift
// FilterBar.swift

import AppKit
import SwiftUI

// Wraps NSSearchField as a native macOS search control
struct FilterBar: NSViewRepresentable {
    @Binding var text: String
    
    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = "Filter by app name, bundle ID, or process name..."
        field.font = NSFont.systemFont(ofSize: 12)
        field.focusRingType = .none
        field.delegate = context.coordinator
        field.bezelStyle = .roundedBezel
        field.controlSize = .small
        return field
    }
    
    func updateNSView(_ nsView: NSSearchField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }
    
    final class Coordinator: NSObject, NSSearchFieldDelegate {
        @Binding var text: String
        init(text: Binding<String>) { _text = text }
        
        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSSearchField else { return }
            text = field.stringValue
        }
    }
}
```

---

## 5. Option B: SwiftUI DisclosureGroup (Simpler, Less Native)

Use only when targeting macOS 13+ and approximate pixel-match is acceptable. Not recommended for replicating MacVitals' exact behavior.

```swift
// ProcessTreeViewSwiftUI.swift

import SwiftUI

struct ProcessTreeViewSwiftUI: View {
    let groups: [CategoryGroup]
    let maxAppMemory: UInt64
    let totalRAM: UInt64
    @Binding var selectedAppID: UUID?
    @State private var searchText = ""
    
    var filteredGroups: [CategoryGroup] {
        guard !searchText.isEmpty else { return groups }
        return groups.compactMap { group in
            let filtered = group.apps.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.bundleId.localizedCaseInsensitiveContains(searchText)
            }
            guard !filtered.isEmpty else { return nil }
            return CategoryGroup(type: group.type, apps: filtered)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Filter bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(white: 0.4))
                TextField("Filter by app name, bundle ID, or process name...", text: $searchText)
                    .font(.system(size: 12))
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(white: 0.35))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(white: 0.15))
            .overlay(Rectangle().fill(Color(white: 0.18)).frame(height: 1), alignment: .bottom)
            
            List(filteredGroups, id: \.type) { group in
                // NOTE: DisclosureGroup causes group headers to be INDENTED
                // This is the fundamental difference from NSOutlineView's isGroupRow
                DisclosureGroup(
                    content: {
                        ForEach(group.apps) { app in
                            AppRowView(app: app, maxMemory: maxAppMemory, isSelected: selectedAppID == app.id)
                                .onTapGesture { selectedAppID = app.id }
                        }
                    },
                    label: {
                        GroupHeaderRow(group: group, totalRAM: totalRAM)
                    }
                )
                .disclosureGroupStyle(ProcessGroupStyle())
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(white: 0.118))
        }
    }
}

// MARK: - SwiftUI Row Components

struct GroupHeaderRow: View {
    let group: CategoryGroup
    let totalRAM: UInt64
    
    var fraction: Double {
        guard totalRAM > 0 else { return 0 }
        return min(1.0, Double(group.totalPhysFootprint) / Double(totalRAM))
    }
    
    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: "folder.fill")
                .font(.system(size: 11))
                .foregroundStyle(Color(white: 0.35))
                .padding(.trailing, 4)
            
            Text(group.displayName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(white: 0.75))
            
            Text("(\(group.apps.count))")
                .font(.system(size: 11))
                .foregroundStyle(Color(white: 0.38))
                .padding(.leading, 3)
            
            Spacer()
            
            Text(formatBytes(group.totalPhysFootprint))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color(white: 0.5))
                .padding(.trailing, 6)
            
            MemoryBarView(fraction: fraction, height: 4)
                .frame(width: 80)
        }
        .frame(height: 24)
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        return String(format: "%.1f MB", Double(bytes) / 1_048_576)
    }
}

struct AppRowView: View {
    let app: AppMemoryInfo
    let maxMemory: UInt64
    let isSelected: Bool
    @State private var isExpanded = false
    @State private var isHovered = false
    
    var fraction: Double {
        guard maxMemory > 0 else { return 0 }
        return min(1.0, Double(app.physFootprint) / Double(maxMemory))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Expand arrow
                if app.processes.count > 1 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 7, weight: .semibold))
                            .foregroundStyle(Color(white: 0.35))
                            .frame(width: 14)
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer().frame(width: 14)
                }
                
                // Icon
                Group {
                    if let icon = app.icon {
                        Image(nsImage: icon).resizable()
                            .interpolation(.high)
                            .frame(width: 16, height: 16)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    } else {
                        Image(systemName: "gearshape")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(white: 0.5))
                            .frame(width: 16, height: 16)
                    }
                }
                .padding(.trailing, 5)
                
                Text(app.name)
                    .font(.system(size: 13))
                    .foregroundStyle(isSelected ? .white : Color(white: 0.87))
                    .lineLimit(1)
                
                Spacer()
                
                Text(formatBytes(app.physFootprint))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color(white: 0.5))
                    .padding(.trailing, 6)
                
                MemoryBarView(fraction: fraction, height: 3)
                    .frame(width: 80)
            }
            .frame(height: 20)
            .padding(.leading, 20)
            .padding(.trailing, 10)
            .background(
                isSelected
                    ? Color(red: 0, green: 0.478, blue: 1).opacity(0.15)
                    : (isHovered ? Color.white.opacity(0.04) : .clear)
            )
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
            
            if isExpanded {
                ForEach(app.processes.sorted { $0.physFootprint > $1.physFootprint }.prefix(15)) { proc in
                    ChildProcessRow(process: proc, parentMemory: app.physFootprint)
                }
                .transition(.opacity)
            }
        }
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 { return String(format: "%.2f GB", gb) }
        return String(format: "%.1f MB", Double(bytes) / 1_048_576)
    }
}

struct ChildProcessRow: View {
    let process: ProcessInfo
    let parentMemory: UInt64
    @State private var isHovered = false
    
    var fraction: Double {
        guard parentMemory > 0 else { return 0 }
        return min(1.0, Double(process.physFootprint) / Double(parentMemory))
    }
    
    var body: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: 34)
            
            Text(process.name)
                .font(.system(size: 11))
                .foregroundStyle(Color(white: 0.55))
                .lineLimit(1)
            
            Spacer()
            
            Text(formatBytes(process.physFootprint))
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Color(white: 0.35))
                .padding(.trailing, 6)
            
            MemoryBarView(fraction: fraction, height: 3, opacity: 0.6)
                .frame(width: 80)
                .padding(.trailing, 10)
        }
        .frame(height: 20)
        .background(isHovered ? Color.white.opacity(0.04) : .clear)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
    
    private func formatBytes(_ bytes: UInt64) -> String {
        let mb = Double(bytes) / 1_048_576
        if mb >= 1 { return String(format: "%.1f MB", mb) }
        return String(format: "%.0f KB", Double(bytes) / 1024)
    }
}

// MARK: - Shared MemoryBarView (SwiftUI)
struct MemoryBarView: View {
    let fraction: Double
    var height: CGFloat = 3
    var opacity: Double = 1.0
    var isCritical: Bool = false
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(white: 0.23))
                
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(isCritical
                        ? Color(red: 1.0, green: 0.259, blue: 0.275)  // #ff4246
                        : Color(red: 0, green: 0.478, blue: 1))        // #007aff
                    .frame(width: max(2, geo.size.width * fraction))
                    .opacity(opacity)
            }
        }
        .frame(height: height)
    }
}
```

---

## 6. AppMemoryMonitor Updates Required

The current `AppMemoryMonitor.swift` needs these changes to match MacVitals' data model:

### 6.1 Use physFootprint Instead of RSS

```swift
// Current: uses rssKB * 1024 from `ps aux` — this is RSS
// Required: use phys_footprint from task_vm_info

// In AppMemoryMonitor, replace getProcessList() with:
func enumerateProcessesAsync() async -> [RawProcess] {
    // Use ProcessInfo.processInfo.processIdentifier for all PIDs
    // Use proc_pidinfo() with PROC_PIDTASKINFO for phys_footprint
    // This does NOT require entitlements (unlike task_for_pid)
    // proc_pidinfo returns proc_taskinfo.pti_resident_size (RSS) but
    // for phys_footprint, use PROC_PIDTASKALLINFO → pti_phys_footprint
}
```

### 6.2 Add Category Grouping

```swift
// Replace the current simple split (icon presence) with activation policy:
func categorize(_ app: AppMemoryInfo) -> ProcessCategory {
    let running = NSWorkspace.shared.runningApplications
    if let runningApp = running.first(where: { $0.bundleIdentifier == app.bundleId }) {
        switch runningApp.activationPolicy {
        case .regular: return .userApp
        default: return .userProcess
        }
    }
    // Apps with com.apple. bundle prefix that aren't regular apps → system
    if app.bundleId.hasPrefix("com.apple.") { return .system }
    return .userProcess
}
```

### 6.3 Expose Cached Aggregates

```swift
final class AppMemoryMonitor: ObservableObject {
    @Published var categoryGroups: [CategoryGroup] = []
    
    // These feed directly into the cell views:
    private(set) var cachedMaxAppMemory: UInt64 = 1   // _cachedMaxAppMemory
    private(set) var cachedTotalAppMemory: UInt64 = 0  // _cachedTotalAppMemory
    private(set) var cachedAppFootprintTotal: UInt64 = 0 // _cachedAppFootprintTotal
    private(set) var totalRAM: UInt64 = 0
    
    func refresh() {
        let processes = enumerateProcesses()
        let grouped = groupByApp(processes)
        cachedMaxAppMemory = grouped.flatMap { $0.apps }.map { $0.physFootprint }.max() ?? 1
        cachedTotalAppMemory = grouped.flatMap { $0.apps }.reduce(0) { $0 + $1.physFootprint }
        categoryGroups = grouped
    }
}
```

---

## 7. Integration in MemoryView

```swift
// MemoryView.swift — left panel integration

struct MemoryView: View {
    @StateObject private var monitor = AppMemoryMonitor()
    @State private var selectedAppID: UUID?
    @State private var searchText = ""
    
    var body: some View {
        HSplitView {
            // LEFT PANEL: process tree
            VStack(spacing: 0) {
                FilterBar(text: $searchText)
                    .frame(height: 28)
                
                ProcessTreeView(
                    monitor: monitor,
                    selectedAppID: $selectedAppID,
                    searchText: searchText
                )
            }
            .frame(minWidth: 280, idealWidth: 420, maxWidth: 500)
            
            // RIGHT PANEL: charts
            MemorySunburstChart(monitor: monitor, selectedAppID: selectedAppID)
        }
        .task {
            while !Task.isCancelled {
                monitor.refresh()
                try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2s refresh
            }
        }
    }
}
```

---

## 8. Key Gotchas

| Issue | Solution |
|-------|---------|
| Group headers are indented in `DisclosureGroup` | Use NSOutlineView with `isGroupRow → true` for `OutlineGroupItem` |
| `ps aux` RSS != MacVitals physFootprint | Use `proc_pidinfo(PROC_PIDTASKINFO)` or XPC helper for `task_vm_info` |
| Memory bar proportional baseline wrong | Group bar → `/ totalRAM`, app bar → `/ cachedMaxAppMemory`, child bar → `/ parentApp.physFootprint` |
| NSOutlineView row reuse | Cells must support `configure()` re-population — use `makeView(withIdentifier:owner:)` pattern |
| Delta dot flicker on every refresh | Use `staleThreshold` — only update delta if difference exceeds ~512KB |
| Expansion state lost on refresh | Save to `expandedGroups` set; call `expandItem:` after `reloadData()` |
| Type-select conflicts with filter bar | Implement `outlineView:shouldTypeSelectForEvent:withCurrentSearchString:` to return `false` when FilterBar is first responder |
| Icon load performance | Cache icons in `IconService` (`_TtC9MacVitals11IconService`); `NSRunningApplication.icon` is synchronous and fast for running apps |

---

## 9. File Checklist for Implementation

| File | Status | Action |
|------|--------|--------|
| `AppMemoryMonitor.swift` | Exists, needs update | Replace RSS with physFootprint; add `CategoryGroup`, `ProcessCategory`; expose `cachedMaxAppMemory` |
| `ProcessTreeItems.swift` | Does not exist | Create: `OutlineGroupItem`, `OutlineAppItem`, `OutlineProcessItem` |
| `ProcessTreeCoordinator.swift` | Does not exist | Create: full `NSOutlineViewDataSource` + `NSOutlineViewDelegate` |
| `ProcessTreeView.swift` | Exists (SwiftUI only) | Replace with `NSViewRepresentable` wrapper + `ProcessTreeNSView` |
| `ProcessTreeCells.swift` | Does not exist | Create: `BaseOutlineCellView`, `GroupHeaderCellView`, `AppCellView`, `ProcessCellView` |
| `MemoryBarNSView.swift` | Does not exist | Create: `MemoryBarNSView` |
| `MemoryDeltaNSView.swift` | Does not exist | Create: `MemoryDeltaNSView` with 30s/1m/2m/5m tracking |
| `ProcessTreeRowView.swift` | Does not exist | Create: custom `NSTableRowView` with selection tint |
| `FilterBar.swift` | Inline in `MemoryProcessTree.swift` | Extract to standalone `NSViewRepresentable` wrapping `NSSearchField` |
| `MemoryProcessTree.swift` | Exists, will be replaced | Keep as SwiftUI fallback Option B only |

---

*Spec derived from: MacVitals 1.7.1 binary string extraction (37 source file names, 32 class/struct names, all outline delegate methods, all data model field names) + pixel-level analysis of 6 screenshots at 2x Retina resolution.*

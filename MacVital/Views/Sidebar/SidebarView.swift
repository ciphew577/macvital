// MacVital/Views/Sidebar/SidebarView.swift
import SwiftUI

enum SidebarTab: String, CaseIterable, Identifiable {
    case overview   = "Overview"
    case cpu        = "CPU"
    case memory     = "Memory"
    case storage    = "Storage"
    case power      = "Power"
    case thermal    = "Thermal"
    case fans       = "Fans"
    case gpu        = "GPU"
    case networkV2  = "Network"
    case anatomy    = "Anatomy"
    case processes  = "Processes"
    case report     = "Report"
    case settings   = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .overview:  return "heart.text.square"
        case .cpu:       return "cpu"
        case .memory:    return "memorychip"
        case .storage:   return "internaldrive"
        case .power:     return "bolt.fill"
        case .thermal:   return "thermometer.medium"
        case .fans:      return "fan"
        case .gpu:       return "gpu"
        case .networkV2: return "network"
        case .anatomy:   return "square.stack.3d.up.fill"
        case .processes: return "list.bullet.rectangle"
        case .report:    return "doc.text.magnifyingglass"
        case .settings:  return "gearshape"
        }
    }
}

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @State private var selection: SidebarTab? = .overview

    var body: some View {
        NavigationSplitView {
            List(SidebarTab.allCases, selection: $selection) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
            .listStyle(.sidebar)
        } detail: {
            Group {
                switch selection {
                case .overview:   OverviewView()
                case .cpu:        CPUView()
                case .memory:     MemoryView()
                case .storage:    StorageView()
                case .power:      PowerView()
                case .thermal:    SensorsView()
                case .fans:       FansView()
                case .gpu:        GPUView()
                case .networkV2:  NetworkViewV2()
                case .anatomy:    AnatomyView()
                case .processes:  ProcessesView()
                case .report:     ReportView()
                case .settings:   SettingsView()
                case nil:
                    ContentUnavailableView("Select a Category", systemImage: "heart.text.square", description: Text("Choose a category from the sidebar"))
                }
            }
            .environment(appState)
        }
    }
}

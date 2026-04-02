// Shared/Models/ProcessesData.swift
// Full-list process data model for the Processes tab.
import Foundation
import AppKit

public enum ProcessCategory: String, Codable, Sendable {
    case userApp    = "User Apps"
    case background = "Background"
    case system     = "System"
}

/// Rich process info used exclusively by ProcessesView.
/// cpuPercent is a real-time snapshot percent (0–100 per core, can exceed 100 on multi-core).
public struct RichProcessInfo: Identifiable, Sendable {
    public let id: Int32          // pid
    public let name: String
    public let path: String
    public var cpuPercent: Double
    public var memoryBytes: UInt64
    public let category: ProcessCategory
    public var icon: NSImage?

    public init(id: Int32, name: String, path: String, cpuPercent: Double,
                memoryBytes: UInt64, category: ProcessCategory, icon: NSImage?) {
        self.id = id
        self.name = name
        self.path = path
        self.cpuPercent = cpuPercent
        self.memoryBytes = memoryBytes
        self.category = category
        self.icon = icon
    }
}

public struct ProcessesData: Sendable {
    public var all: [RichProcessInfo]
    public var userApps: [RichProcessInfo]  { all.filter { $0.category == .userApp } }
    public var background: [RichProcessInfo] { all.filter { $0.category == .background } }
    public var system: [RichProcessInfo]    { all.filter { $0.category == .system } }

    public init(all: [RichProcessInfo] = []) {
        self.all = all
    }
}

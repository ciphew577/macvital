import Foundation

public enum MemoryPressureLevel: String, Codable, Sendable {
    case nominal = "Nominal"
    case warning = "Warning"
    case critical = "Critical"
}

public struct MemoryData: Codable, Sendable {
    public var total: UInt64
    public var used: UInt64
    public var free: UInt64
    public var wired: UInt64
    public var active: UInt64
    public var inactive: UInt64
    public var compressed: UInt64
    public var purgeable: UInt64
    public var swapUsed: UInt64
    public var swapFree: UInt64
    public var pressureLevel: MemoryPressureLevel
    public var topProcesses: [ProcessInfo]

    public init(total: UInt64, used: UInt64, free: UInt64, wired: UInt64, active: UInt64, inactive: UInt64, compressed: UInt64, purgeable: UInt64, swapUsed: UInt64, swapFree: UInt64, pressureLevel: MemoryPressureLevel, topProcesses: [ProcessInfo] = []) {
        self.total = total; self.used = used; self.free = free; self.wired = wired; self.active = active; self.inactive = inactive; self.compressed = compressed; self.purgeable = purgeable; self.swapUsed = swapUsed; self.swapFree = swapFree; self.pressureLevel = pressureLevel; self.topProcesses = topProcesses
    }
}

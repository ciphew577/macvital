import Foundation

public enum ClusterType: String, Codable, Sendable {
    case performance = "P"
    case efficiency = "E"
    case unknown = "?"
}

public struct CPUCore: Codable, Sendable, Identifiable {
    public let id: Int
    public var usage: Double
    public var frequency: UInt64
    public var temperature: Double
    public var power: Double
    public let clusterType: ClusterType

    public init(id: Int, usage: Double, frequency: UInt64, temperature: Double, power: Double, clusterType: ClusterType) {
        self.id = id; self.usage = usage; self.frequency = frequency; self.temperature = temperature; self.power = power; self.clusterType = clusterType
    }
}

public struct ProcessInfo: Codable, Sendable, Identifiable {
    public let id: Int32
    public let name: String
    public var cpuUsage: Double
    public var memoryBytes: UInt64

    public init(id: Int32, name: String, cpuUsage: Double, memoryBytes: UInt64) {
        self.id = id; self.name = name; self.cpuUsage = cpuUsage; self.memoryBytes = memoryBytes
    }
}

public struct CPUData: Codable, Sendable {
    public var cores: [CPUCore]
    public var totalUsage: Double
    public var systemUsage: Double
    public var userUsage: Double
    public var idleUsage: Double
    public let coreCount: Int
    public let performanceCoreCount: Int
    public let efficiencyCoreCount: Int
    public var topProcesses: [ProcessInfo]

    public init(cores: [CPUCore], totalUsage: Double, systemUsage: Double, userUsage: Double, idleUsage: Double, coreCount: Int, performanceCoreCount: Int, efficiencyCoreCount: Int, topProcesses: [ProcessInfo] = []) {
        self.cores = cores; self.totalUsage = totalUsage; self.systemUsage = systemUsage; self.userUsage = userUsage; self.idleUsage = idleUsage; self.coreCount = coreCount; self.performanceCoreCount = performanceCoreCount; self.efficiencyCoreCount = efficiencyCoreCount; self.topProcesses = topProcesses
    }
}

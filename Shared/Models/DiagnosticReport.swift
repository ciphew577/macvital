import Foundation

public struct DiagnosticReport: Codable, Sendable {
    public let timestamp: Date
    public let macModel: String
    public let macOSVersion: String
    public let chipType: String
    public let serialNumber: String
    public let cpu: CPUData
    public let memory: MemoryData
    public let storage: StorageData
    public let battery: BatteryData?
    public let sensors: SensorData
    public let gpu: GPUData
    public let network: NetworkData
    public let healthScores: [HealthScore]
    public let overallHealthScore: Double
    public let recommendations: [String]

    public init(timestamp: Date, macModel: String, macOSVersion: String, chipType: String, serialNumber: String, cpu: CPUData, memory: MemoryData, storage: StorageData, battery: BatteryData?, sensors: SensorData, gpu: GPUData, network: NetworkData, healthScores: [HealthScore], overallHealthScore: Double, recommendations: [String]) {
        self.timestamp = timestamp; self.macModel = macModel; self.macOSVersion = macOSVersion; self.chipType = chipType; self.serialNumber = serialNumber; self.cpu = cpu; self.memory = memory; self.storage = storage; self.battery = battery; self.sensors = sensors; self.gpu = gpu; self.network = network; self.healthScores = healthScores; self.overallHealthScore = overallHealthScore; self.recommendations = recommendations
    }
}

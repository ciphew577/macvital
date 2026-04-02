import Foundation

public struct BatteryData: Codable, Sendable {
    public var designCapacity: Int
    public var maxCapacity: Int
    public var currentCharge: Int
    public var percentage: Double
    public var cycleCount: Int
    public var temperature: Double
    public var voltage: Double
    public var amperage: Int
    public var wattage: Double
    public var isCharging: Bool
    public var isFullyCharged: Bool
    public var timeRemaining: Int
    public var condition: String
    public var manufactureDate: String
    public var serialNumber: String
    public var healthPercent: Double {
        guard designCapacity > 0 else { return 0 }
        return (Double(maxCapacity) / Double(designCapacity)) * 100.0
    }

    public init(designCapacity: Int, maxCapacity: Int, currentCharge: Int, percentage: Double, cycleCount: Int, temperature: Double, voltage: Double, amperage: Int, wattage: Double, isCharging: Bool, isFullyCharged: Bool, timeRemaining: Int, condition: String, manufactureDate: String, serialNumber: String) {
        self.designCapacity = designCapacity; self.maxCapacity = maxCapacity; self.currentCharge = currentCharge; self.percentage = percentage; self.cycleCount = cycleCount; self.temperature = temperature; self.voltage = voltage; self.amperage = amperage; self.wattage = wattage; self.isCharging = isCharging; self.isFullyCharged = isFullyCharged; self.timeRemaining = timeRemaining; self.condition = condition; self.manufactureDate = manufactureDate; self.serialNumber = serialNumber
    }
}

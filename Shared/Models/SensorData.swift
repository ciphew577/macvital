import Foundation

public enum SensorCategory: String, Codable, Sendable {
    case cpuTemperature = "CPU Temperature"
    case gpuTemperature = "GPU Temperature"
    case batteryTemperature = "Battery Temperature"
    case driveTemperature = "Drive Temperature"
    case skinTemperature = "Skin Temperature"
    case ambientTemperature = "Ambient Temperature"
    case voltage = "Voltage"
    case current = "Current"
    case power = "Power"
    case other = "Other"
}

public struct SensorReading: Codable, Sendable, Identifiable {
    public var id: String { key }
    public let name: String
    public let key: String
    public var value: Double
    public let unit: String
    public let category: SensorCategory
    public var minRecorded: Double
    public var maxRecorded: Double

    public init(name: String, key: String, value: Double, unit: String, category: SensorCategory, minRecorded: Double, maxRecorded: Double) {
        self.name = name; self.key = key; self.value = value; self.unit = unit; self.category = category; self.minRecorded = minRecorded; self.maxRecorded = maxRecorded
    }
}

/// Fan control mode as reported/stored by the helper.
public enum FanControlMode: Int, Codable, Sendable {
    case auto   = 0   // thermalmonitord controls (F{n}Md = 0)
    case manual = 1   // MacVital controls (F{n}Md = 1)
}

public struct FanReading: Codable, Sendable, Identifiable {
    public var id: String { name }
    public let name: String
    public var rpm: Int
    public let minRPM: Int
    public let maxRPM: Int

    /// Current F{n}Tg — the target RPM written to SMC (0 when in auto mode).
    public var targetRPM: Int

    /// Current F{n}Md — 0 = auto, 1 = manual.
    public var controlMode: FanControlMode

    public init(name: String, rpm: Int, minRPM: Int, maxRPM: Int,
                targetRPM: Int = 0, controlMode: FanControlMode = .auto) {
        self.name = name
        self.rpm = rpm
        self.minRPM = minRPM
        self.maxRPM = maxRPM
        self.targetRPM = targetRPM
        self.controlMode = controlMode
    }
}

public struct SensorData: Codable, Sendable {
    public var sensors: [SensorReading]
    public var fans: [FanReading]

    public init(sensors: [SensorReading], fans: [FanReading]) {
        self.sensors = sensors; self.fans = fans
    }
}

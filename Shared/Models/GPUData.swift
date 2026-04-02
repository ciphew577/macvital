import Foundation

public struct GPUProcess: Codable, Sendable, Identifiable {
    public var id: Int32        // pid
    public var name: String
    public var gpuPercent: Double
    public var type: String     // "Render", "Compute", "Display"

    public init(id: Int32, name: String, gpuPercent: Double, type: String) {
        self.id = id
        self.name = name
        self.gpuPercent = gpuPercent
        self.type = type
    }
}

public struct GPUData: Codable, Sendable {
    // Overall utilization
    public var utilization: Double

    // Per-engine utilization (0–100)
    public var renderUtilization: Double
    public var tilerUtilization: Double
    public var computeUtilization: Double

    // Unified memory (bytes)
    public var vramUsed: UInt64       // GPU active
    public var vramMapped: UInt64     // GPU mapped
    public var vramTotal: UInt64      // Total unified RAM

    // Memory bandwidth (bytes/sec)
    public var memReadBytesPerSec: UInt64
    public var memWriteBytesPerSec: UInt64

    // Thermal / power
    public var temperature: Double
    public var power: Double          // Watts

    // Clock
    public var frequency: UInt64      // Hz (core clock)
    public var memoryFrequency: UInt64 // Hz

    // Encoders
    public var encoderUtilization: Double
    public var decoderUtilization: Double
    public var proResUtilization: Double

    // Fan
    public var fanPercent: Double
    public var fanRPM: UInt32

    // ANE (Apple Neural Engine)
    public var aneUtilization: Double
    public var anePower: Double       // Watts

    // GPU name / identity
    public var gpuName: String
    public var coreCount: Int
    public var metalVersion: String

    // Top processes
    public var topProcesses: [GPUProcess]

    public init(
        utilization: Double = 0,
        renderUtilization: Double = 0,
        tilerUtilization: Double = 0,
        computeUtilization: Double = 0,
        vramUsed: UInt64 = 0,
        vramMapped: UInt64 = 0,
        vramTotal: UInt64 = 0,
        memReadBytesPerSec: UInt64 = 0,
        memWriteBytesPerSec: UInt64 = 0,
        temperature: Double = 0,
        power: Double = 0,
        frequency: UInt64 = 0,
        memoryFrequency: UInt64 = 0,
        encoderUtilization: Double = 0,
        decoderUtilization: Double = 0,
        proResUtilization: Double = 0,
        fanPercent: Double = 0,
        fanRPM: UInt32 = 0,
        aneUtilization: Double = 0,
        anePower: Double = 0,
        gpuName: String = "Apple GPU",
        coreCount: Int = 0,
        metalVersion: String = "Metal 3",
        topProcesses: [GPUProcess] = []
    ) {
        self.utilization = utilization
        self.renderUtilization = renderUtilization
        self.tilerUtilization = tilerUtilization
        self.computeUtilization = computeUtilization
        self.vramUsed = vramUsed
        self.vramMapped = vramMapped
        self.vramTotal = vramTotal
        self.memReadBytesPerSec = memReadBytesPerSec
        self.memWriteBytesPerSec = memWriteBytesPerSec
        self.temperature = temperature
        self.power = power
        self.frequency = frequency
        self.memoryFrequency = memoryFrequency
        self.encoderUtilization = encoderUtilization
        self.decoderUtilization = decoderUtilization
        self.proResUtilization = proResUtilization
        self.fanPercent = fanPercent
        self.fanRPM = fanRPM
        self.aneUtilization = aneUtilization
        self.anePower = anePower
        self.gpuName = gpuName
        self.coreCount = coreCount
        self.metalVersion = metalVersion
        self.topProcesses = topProcesses
    }
}

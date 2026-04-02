import Foundation

public enum SMARTStatus: String, Codable, Sendable {
    case good = "Good"
    case warning = "Warning"
    case critical = "Critical"
    case unknown = "Unknown"
}

public struct Volume: Codable, Sendable, Identifiable {
    public var id: String { mountPoint }
    public let name: String
    public let mountPoint: String
    public var totalBytes: UInt64
    public var usedBytes: UInt64
    public var freeBytes: UInt64
    public let fileSystem: String

    public init(name: String, mountPoint: String, totalBytes: UInt64, usedBytes: UInt64, freeBytes: UInt64, fileSystem: String) {
        self.name = name; self.mountPoint = mountPoint; self.totalBytes = totalBytes; self.usedBytes = usedBytes; self.freeBytes = freeBytes; self.fileSystem = fileSystem
    }
}

public struct SMARTAttribute: Codable, Sendable, Identifiable {
    public let id: Int
    public let name: String
    public var rawValue: String
    public let threshold: String
    public var status: SMARTStatus
    public let explanation: String

    public init(id: Int, name: String, rawValue: String, threshold: String, status: SMARTStatus, explanation: String) {
        self.id = id; self.name = name; self.rawValue = rawValue; self.threshold = threshold; self.status = status; self.explanation = explanation
    }
}

public struct SpaceBreakdown: Codable, Sendable {
    public let appsBytes: UInt64
    public let documentsBytes: UInt64
    public let photosBytes: UInt64
    public let systemBytes: UInt64
    public let otherBytes: UInt64

    public init(appsBytes: UInt64, documentsBytes: UInt64, photosBytes: UInt64, systemBytes: UInt64, otherBytes: UInt64) {
        self.appsBytes = appsBytes; self.documentsBytes = documentsBytes; self.photosBytes = photosBytes; self.systemBytes = systemBytes; self.otherBytes = otherBytes
    }
}

public struct StorageData: Codable, Sendable {
    public var volumes: [Volume]
    public var smartAttributes: [SMARTAttribute]
    public var healthPercent: Double
    public var readBytesPerSec: UInt64
    public var writeBytesPerSec: UInt64
    public var spaceBreakdown: SpaceBreakdown?

    public init(volumes: [Volume], smartAttributes: [SMARTAttribute], healthPercent: Double, readBytesPerSec: UInt64, writeBytesPerSec: UInt64, spaceBreakdown: SpaceBreakdown? = nil) {
        self.volumes = volumes; self.smartAttributes = smartAttributes; self.healthPercent = healthPercent; self.readBytesPerSec = readBytesPerSec; self.writeBytesPerSec = writeBytesPerSec; self.spaceBreakdown = spaceBreakdown
    }
}

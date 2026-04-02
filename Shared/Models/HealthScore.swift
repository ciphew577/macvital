import Foundation

public enum HealthStatus: String, Codable, Sendable {
    case good = "Good"
    case warning = "Warning"
    case critical = "Critical"
}

public struct HealthScore: Codable, Sendable, Identifiable {
    public var id: String { component }
    public let component: String
    public let score: Double
    public let detail: String

    public var status: HealthStatus {
        if score >= 90 { return .good }
        if score >= 60 { return .warning }
        return .critical
    }

    public init(component: String, score: Double, detail: String) {
        self.component = component; self.score = score; self.detail = detail
    }

    public static func overallScore(storage: Double, battery: Double, thermal: Double, cpu: Double, memory: Double) -> Double {
        storage * 0.30 + battery * 0.25 + thermal * 0.20 + cpu * 0.15 + memory * 0.10
    }
}

public struct Alert: Codable, Sendable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let component: String
    public let severity: HealthStatus
    public let message: String

    public init(component: String, severity: HealthStatus, message: String) {
        self.id = UUID(); self.timestamp = Date(); self.component = component; self.severity = severity; self.message = message
    }
}

import XCTest
@testable import MacVitalShared

final class ModelTests: XCTestCase {
    func testCPUDataCodable() throws {
        let core = CPUCore(id: 0, usage: 45.2, frequency: 3200, temperature: 67.5, power: 2.1, clusterType: .performance)
        let cpu = CPUData(cores: [core], totalUsage: 45.2, systemUsage: 10.0, userUsage: 30.0, idleUsage: 54.8, coreCount: 1, performanceCoreCount: 1, efficiencyCoreCount: 0)
        let data = try JSONEncoder().encode(cpu)
        let decoded = try JSONDecoder().decode(CPUData.self, from: data)
        XCTAssertEqual(decoded.cores.count, 1)
        XCTAssertEqual(decoded.cores[0].usage, 45.2)
        XCTAssertEqual(decoded.cores[0].clusterType, .performance)
    }

    func testHealthScoreStatus() {
        XCTAssertEqual(HealthScore(component: "CPU", score: 95, detail: "").status, .good)
        XCTAssertEqual(HealthScore(component: "CPU", score: 75, detail: "").status, .warning)
        XCTAssertEqual(HealthScore(component: "CPU", score: 40, detail: "").status, .critical)
    }

    func testMemoryDataCodable() throws {
        let mem = MemoryData(total: 17179869184, used: 8589934592, free: 8589934592, wired: 2147483648, active: 3221225472, inactive: 1073741824, compressed: 536870912, purgeable: 268435456, swapUsed: 0, swapFree: 2147483648, pressureLevel: .nominal)
        let data = try JSONEncoder().encode(mem)
        let decoded = try JSONDecoder().decode(MemoryData.self, from: data)
        XCTAssertEqual(decoded.total, 17179869184)
        XCTAssertEqual(decoded.pressureLevel, .nominal)
    }

    func testBatteryDataCodable() throws {
        let bat = BatteryData(designCapacity: 5103, maxCapacity: 4800, currentCharge: 4200, percentage: 87.5, cycleCount: 142, temperature: 30.2, voltage: 12.8, amperage: -1200, wattage: 15.4, isCharging: false, isFullyCharged: false, timeRemaining: 240, condition: "Normal", manufactureDate: "2023-01-15", serialNumber: "ABC123")
        let data = try JSONEncoder().encode(bat)
        let decoded = try JSONDecoder().decode(BatteryData.self, from: data)
        XCTAssertEqual(decoded.cycleCount, 142)
        XCTAssertEqual(decoded.designCapacity, 5103)
    }

    func testStorageSMARTAttribute() throws {
        let attr = SMARTAttribute(id: 1, name: "Percentage Used", rawValue: "2%", threshold: "100%", status: .good, explanation: "Estimates how much of the drive's total write endurance has been consumed.")
        let data = try JSONEncoder().encode(attr)
        let decoded = try JSONDecoder().decode(SMARTAttribute.self, from: data)
        XCTAssertEqual(decoded.name, "Percentage Used")
        XCTAssertEqual(decoded.status, .good)
    }

    func testDiagnosticReportCodable() throws {
        let report = DiagnosticReport(
            timestamp: Date(), macModel: "MacBook Pro (M2 Pro)", macOSVersion: "14.3", chipType: "Apple M2 Pro", serialNumber: "XYZ789",
            cpu: CPUData(cores: [], totalUsage: 10, systemUsage: 3, userUsage: 7, idleUsage: 90, coreCount: 10, performanceCoreCount: 6, efficiencyCoreCount: 4),
            memory: MemoryData(total: 16_000_000_000, used: 8_000_000_000, free: 8_000_000_000, wired: 2_000_000_000, active: 3_000_000_000, inactive: 1_000_000_000, compressed: 500_000_000, purgeable: 200_000_000, swapUsed: 0, swapFree: 2_000_000_000, pressureLevel: .nominal),
            storage: StorageData(volumes: [], smartAttributes: [], healthPercent: 98, readBytesPerSec: 0, writeBytesPerSec: 0),
            battery: nil, sensors: SensorData(sensors: [], fans: []),
            gpu: GPUData(utilization: 5, vramUsed: 500_000_000, vramTotal: 16_000_000_000, temperature: 40),
            network: NetworkData(interfaces: []), healthScores: [], overallHealthScore: 95, recommendations: ["All systems healthy"])
        let data = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(DiagnosticReport.self, from: data)
        XCTAssertEqual(decoded.macModel, "MacBook Pro (M2 Pro)")
        XCTAssertEqual(decoded.overallHealthScore, 95)
    }
}

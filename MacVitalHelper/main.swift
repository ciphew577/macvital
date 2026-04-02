// MacVitalHelper/main.swift
import Foundation
import Darwin

// MARK: - Connection Authentication

/// Code-signing requirement that incoming XPC peers must satisfy before we
/// accept the connection. The first string is for Developer-ID-signed builds
/// (production) and the second is the ad-hoc fallback used during local dev.
///
/// TODO: Once Developer ID signing is enabled, replace "TEAMID" with the
/// real Apple Team ID and remove the ad-hoc fallback.
private let kProductionPeerRequirement =
    "identifier \"com.macvital.app\" and anchor apple generic and " +
    "certificate leaf[subject.OU] = \"TEAMID\""
private let kAdHocPeerRequirement = "identifier \"com.macvital.app\""

/// Look up the audit-token-pid's executable path on disk. Returns nil if the
/// process has already exited or proc_pidpath fails.
private func executablePath(forPID pid: pid_t) -> String? {
    var buf = [CChar](repeating: 0, count: Int(MAXPATHLEN))
    let n = proc_pidpath(pid, &buf, UInt32(MAXPATHLEN))
    guard n > 0 else { return nil }
    return String(cString: buf)
}

/// Validate that the peer's executable lives inside a bundle whose name is
/// MacVital.app. We avoid hard-coding an absolute install path because the
/// app may run from /Applications, ~/Applications, /Volumes/... during dev,
/// or a translocation quarantine path. We do require the path to contain
/// "/MacVital.app/" as a defence against a renamed / relocated binary.
private func executableLooksLikeMacVital(_ path: String) -> Bool {
    return path.range(of: "/MacVital.app/Contents/MacOS/") != nil
}

// MARK: - XPC Service Provider

final class HelperDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {

        // 1. Require a valid code-signing identity on the peer. Try the
        //    production (Developer ID) requirement first. If the helper is
        //    itself ad-hoc signed we cannot enforce a Team ID, so we accept
        //    the looser identifier-only requirement as a fallback.
        if #available(macOS 13.0, *) {
            do {
                try newConnection.setCodeSigningRequirement(kProductionPeerRequirement)
            } catch {
                do {
                    try newConnection.setCodeSigningRequirement(kAdHocPeerRequirement)
                } catch {
                    smcLog("XPC: rejected, setCodeSigningRequirement failed for both production and ad-hoc requirements: \(error)")
                    return false
                }
            }
        } else {
            // setCodeSigningRequirement is macOS 13+. Fall back to manual
            // peer-pid validation only on older systems.
            smcLog("XPC: setCodeSigningRequirement unavailable on this macOS, relying on peer-pid validation only")
        }

        // 2. Cross-check the peer process is actually MacVital. We pull the
        //    audit token via KVC (private but standard practice; same approach
        //    used by SMJobBless sample code and most modern XPC helpers).
        let tokenObj = newConnection.value(forKey: "auditToken")
        guard let nsValue = tokenObj as? NSValue else {
            smcLog("XPC: rejected, auditToken not retrievable from connection")
            return false
        }
        var token = audit_token_t()
        nsValue.getValue(&token, size: MemoryLayout<audit_token_t>.size)
        // audit_token.val[5] holds the pid per <bsm/libbsm.h>. Inlined to avoid linking libbsm.
        let peerPID = pid_t(bitPattern: UInt32(token.val.5))
        guard peerPID > 0 else {
            smcLog("XPC: rejected, audit token pid \(peerPID) invalid")
            return false
        }
        guard let path = executablePath(forPID: peerPID) else {
            smcLog("XPC: rejected, proc_pidpath(\(peerPID)) failed (peer may have exited)")
            return false
        }
        guard executableLooksLikeMacVital(path) else {
            smcLog("XPC: rejected, peer pid \(peerPID) path does not match MacVital.app: \(path)")
            return false
        }

        smcLog("XPC: accepted connection from pid \(peerPID) (\(path))")
        newConnection.exportedInterface = NSXPCInterface(with: MacVitalHelperProtocol.self)
        newConnection.exportedObject = HelperService.shared
        newConnection.resume()
        return true
    }
}

// MARK: - Helper Service Implementation

final class HelperService: NSObject, MacVitalHelperProtocol {
    /// Shared singleton so the deadman timer and FanController state survive
    /// across multiple XPC connections from the same client. Without this,
    /// every new NSXPCConnection would build a fresh HelperService and the
    /// fan-control deadman timer would be tied to whichever instance was
    /// most recently constructed.
    static let shared = HelperService()

    private let smcReader = SMCReader()
    private let cpuReader = CPUReader()
    private let memoryReader = MemoryReader()
    private let storageReader = StorageReader()
    private let batteryReader = BatteryReader()
    private let gpuReader = GPUReader()
    private let networkReader = NetworkReader()
    private let processReader = ProcessReader()
    private let encoder = JSONEncoder()

    func pingHeartbeat(withReply reply: @escaping (Bool) -> Void) {
        // Refresh the deadman timer so manual fan mode does not auto-revert.
        // No-op if no FanController is currently active.
        fanControlController?.refreshDeadman()
        reply(true)
    }

    func getCPUData(reply: @escaping (Data) -> Void) {
        let data = cpuReader.read(smc: smcReader)
        reply((try? encoder.encode(data)) ?? Data())
    }

    func getMemoryData(reply: @escaping (Data) -> Void) {
        let data = memoryReader.read()
        reply((try? encoder.encode(data)) ?? Data())
    }

    func getStorageData(reply: @escaping (Data) -> Void) {
        let data = storageReader.read()
        reply((try? encoder.encode(data)) ?? Data())
    }

    func getBatteryData(reply: @escaping (Data) -> Void) {
        let data = batteryReader.read()
        reply((try? encoder.encode(data)) ?? Data())
    }

    func getSensorData(reply: @escaping (Data) -> Void) {
        guard let smc = smcReader else {
            reply((try? encoder.encode(SensorData(sensors: [], fans: []))) ?? Data())
            return
        }

        var sensors: [SensorReading] = []

        // Read all known temperature sensors
        for tempKey in SMCReader.appleSiliconTempKeys {
            if let temp = smc.readTemperature(key: tempKey.key) {
                let category: SensorCategory = {
                    switch tempKey.category {
                    case "CPU Temperature": return .cpuTemperature
                    case "GPU Temperature": return .gpuTemperature
                    case "Battery Temperature": return .batteryTemperature
                    case "Drive Temperature": return .driveTemperature
                    case "Skin Temperature": return .skinTemperature
                    case "Ambient Temperature": return .ambientTemperature
                    default: return .other
                    }
                }()

                sensors.append(SensorReading(
                    name: tempKey.name,
                    key: tempKey.key,
                    value: temp,
                    unit: "°C",
                    category: category,
                    minRecorded: temp,
                    maxRecorded: temp
                ))
            }
        }

        // Read fans
        var fans: [FanReading] = []
        if let fanCount = smc.readFanCount() {
            for i in 0..<fanCount {
                let rpm = smc.readFanSpeed(index: i) ?? 0
                let minRPM = smc.readFanMin(index: i) ?? 0
                let maxRPM = smc.readFanMax(index: i) ?? 0
                fans.append(FanReading(name: "Fan \(i + 1)", rpm: rpm, minRPM: minRPM, maxRPM: maxRPM))
            }
        }

        let sensorData = SensorData(sensors: sensors, fans: fans)
        reply((try? encoder.encode(sensorData)) ?? Data())
    }

    func getGPUData(reply: @escaping (Data) -> Void) {
        let data = gpuReader.read(smc: smcReader)
        reply((try? encoder.encode(data)) ?? Data())
    }

    func getNetworkData(reply: @escaping (Data) -> Void) {
        let data = networkReader.read()
        reply((try? encoder.encode(data)) ?? Data())
    }

    func getTopProcesses(limit: Int, reply: @escaping (Data) -> Void) {
        let (cpuTop, memTop) = processReader.readTopProcesses(limit: limit)
        let combined = ["cpu": cpuTop, "memory": memTop]
        reply((try? encoder.encode(combined)) ?? Data())
    }

    func runFullDiagnostic(reply: @escaping (Data) -> Void) {
        let cpu = cpuReader.read(smc: smcReader)
        let memory = memoryReader.read()
        let storage = storageReader.read()
        let battery = batteryReader.read()
        let gpu = gpuReader.read(smc: smcReader)
        let network = networkReader.read()

        // Build sensor data
        var sensors: [SensorReading] = []
        if let smc = smcReader {
            for tempKey in SMCReader.appleSiliconTempKeys {
                if let temp = smc.readTemperature(key: tempKey.key) {
                    let category: SensorCategory = {
                        switch tempKey.category {
                        case "CPU Temperature": return .cpuTemperature
                        case "GPU Temperature": return .gpuTemperature
                        case "Battery Temperature": return .batteryTemperature
                        case "Drive Temperature": return .driveTemperature
                        case "Skin Temperature": return .skinTemperature
                        case "Ambient Temperature": return .ambientTemperature
                        default: return .other
                        }
                    }()
                    sensors.append(SensorReading(name: tempKey.name, key: tempKey.key, value: temp, unit: "°C", category: category, minRecorded: temp, maxRecorded: temp))
                }
            }
        }

        var fans: [FanReading] = []
        if let smc = smcReader, let fanCount = smc.readFanCount() {
            for i in 0..<fanCount {
                let rpm = smc.readFanSpeed(index: i) ?? 0
                fans.append(FanReading(name: "Fan \(i + 1)", rpm: rpm, minRPM: smc.readFanMin(index: i) ?? 0, maxRPM: smc.readFanMax(index: i) ?? 0))
            }
        }
        let sensorData = SensorData(sensors: sensors, fans: fans)

        // Health scores
        let storageScore = storage.healthPercent
        let batteryScore = battery?.healthPercent ?? 100
        let thermalScore: Double = {
            let maxTemp = sensors.map(\.value).max() ?? 0
            if maxTemp >= 95 { return 40 }
            if maxTemp >= 80 { return 70 }
            return 95
        }()
        let cpuScore: Double = cpu.totalUsage < 80 ? 95 : (cpu.totalUsage < 95 ? 70 : 40)
        let memoryScore: Double = {
            switch memory.pressureLevel {
            case .nominal: return 95
            case .warning: return 65
            case .critical: return 30
            }
        }()

        let overall = HealthScore.overallScore(storage: storageScore, battery: batteryScore, thermal: thermalScore, cpu: cpuScore, memory: memoryScore)

        let healthScores = [
            HealthScore(component: "Storage", score: storageScore, detail: "SMART health: \(Int(storageScore))%"),
            HealthScore(component: "Battery", score: batteryScore, detail: battery != nil ? "Capacity: \(Int(batteryScore))% of design" : "No battery"),
            HealthScore(component: "Thermal", score: thermalScore, detail: "Max temp: \(Int(sensors.map(\.value).max() ?? 0))°C"),
            HealthScore(component: "CPU", score: cpuScore, detail: "Usage: \(Int(cpu.totalUsage))%"),
            HealthScore(component: "Memory", score: memoryScore, detail: "Pressure: \(memory.pressureLevel.rawValue)"),
        ]

        // Recommendations
        var recommendations: [String] = []
        if batteryScore < 80 { recommendations.append("Battery at \(Int(batteryScore))% original capacity — consider Apple service.") }
        if let bat = battery, bat.cycleCount > 500 { recommendations.append("Battery has \(bat.cycleCount) cycles — monitor health regularly.") }
        for vol in storage.volumes {
            let usedPct = Double(vol.usedBytes) / Double(max(vol.totalBytes, 1)) * 100
            if usedPct > 85 { recommendations.append("\(vol.name) is \(Int(usedPct))% full — free up space for optimal performance.") }
        }
        if thermalScore < 70 { recommendations.append("High temperatures detected — check ventilation and running processes.") }
        if memory.pressureLevel == .critical { recommendations.append("Memory pressure critical — close unused apps or consider more RAM.") }
        if recommendations.isEmpty { recommendations.append("All systems healthy — no action needed.") }

        // System info
        var modelBuf = [CChar](repeating: 0, count: 256)
        var modelSize = 256
        sysctlbyname("hw.model", &modelBuf, &modelSize, nil, 0)
        let model = String(cString: modelBuf)

        let osVersion = Foundation.ProcessInfo.processInfo.operatingSystemVersionString

        var chipBuf = [CChar](repeating: 0, count: 256)
        var chipSize = 256
        sysctlbyname("machdep.cpu.brand_string", &chipBuf, &chipSize, nil, 0)
        let chip = String(cString: chipBuf)

        let report = DiagnosticReport(
            timestamp: Date(),
            macModel: model,
            macOSVersion: osVersion,
            chipType: chip.isEmpty ? "Apple Silicon" : chip,
            serialNumber: getSerialNumber(),
            cpu: cpu,
            memory: memory,
            storage: storage,
            battery: battery,
            sensors: sensorData,
            gpu: gpu,
            network: network,
            healthScores: healthScores,
            overallHealthScore: overall,
            recommendations: recommendations
        )

        reply((try? encoder.encode(report)) ?? Data())
    }

    private func getSerialNumber() -> String {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        guard service != 0 else { return "Unknown" }
        defer { IOObjectRelease(service) }
        let serial = IORegistryEntryCreateCFProperty(service, "IOPlatformSerialNumber" as CFString, kCFAllocatorDefault, 0)
        return serial?.takeRetainedValue() as? String ?? "Unknown"
    }
}

// MARK: - Graceful shutdown handlers
//
// The helper runs as root and may be holding manual fan control (Ftst=1,
// F{n}Md=1). If the helper crashes, is killed, or exits cleanly, those
// keys must be reset so thermalmonitord regains control. Otherwise an
// unattended Mac could be left with fans pinned manually after a helper
// segfault.
//
// Three layers of defence:
//   1. atexit, clean exit() path
//   2. SIGTERM, launchd graceful stop
//   3. SIGINT, local kill / Ctrl-C during dev

private func performShutdownReset() {
    smcLog("Helper shutdown: writing Ftst=0 and all F{n}Md=0")
    // Use a fresh SMCWriter rather than reuse HelperService.shared's lazy
    // one, the lazy one may not be initialised if no client ever connected.
    guard let w = SMCWriter() else { return }
    defer { w.close() }
    // Reset every fan mode, we don't know how many fans without reading
    // FNum, but writing to non-existent F{n}Md is a harmless SMC error.
    if let fanCount = w.readUInt8(key: "FNum").map(Int.init) {
        for i in 0..<fanCount {
            let mdKey = "F\(i)Md"
            let (ok, _) = w.writeUInt8(key: mdKey, value: 0)
            if !ok { _ = w.writeUInt8Forced(key: mdKey, value: 0) }
        }
    }
    let (ok, _) = w.writeUInt8(key: "Ftst", value: 0)
    if !ok { _ = w.writeUInt8Forced(key: "Ftst", value: 0) }
}

atexit {
    performShutdownReset()
}

signal(SIGINT) { _ in
    smcLog("Helper: SIGINT received, resetting fans before exit")
    performShutdownReset()
    exit(0)
}

// SIGTERM is also installed in HelperServiceFanControl.swift as a backup;
// reinstall here so the reset runs before that handler exits.
signal(SIGTERM) { _ in
    smcLog("Helper: SIGTERM received (main), resetting fans before exit")
    performShutdownReset()
    exit(0)
}

// MARK: - Main Entry Point

let delegate = HelperDelegate()
let listener = NSXPCListener(machServiceName: macVitalHelperMachServiceName)
listener.delegate = delegate
listener.resume()
RunLoop.current.run()

import Foundation
import IOKit

final class GPUReader {

    func read(smc: SMCReader?) -> GPUData {
        let (util, renderUtil, tilerUtil, computeUtil,
             vramUsed, vramMapped, vramTotal,
             readBW, writeBW,
             encoderUtil, decoderUtil, proResUtil,
             aneUtil, anePow,
             gpuName, coreCount, metalVer,
             processes) = readAcceleratorStats()

        let temp   = smc?.readTemperature(key: "Tg0p") ?? 0
        // Power keys (PGTR = GPU power, PANE = ANE power) are float type in SMC.
        // SMCReader only exposes readTemperature; use that same path via temp keys fallback.
        // If no dedicated power reader, leave as 0 — future enhancement.
        let power: Double = 0
        let anePower: Double = anePow

        // Fan
        var fanPercent: Double = 0
        var fanRPM: UInt32 = 0
        if let fanCount = smc?.readFanCount(), fanCount > 0 {
            let rpm = smc?.readFanSpeed(index: 0) ?? 0
            let maxRPM = smc?.readFanMax(index: 0) ?? 6000
            fanRPM = UInt32(max(0, rpm))
            fanPercent = maxRPM > 0 ? min(100, Double(rpm) / Double(maxRPM) * 100) : 0
        }

        // Determine Metal version from OS
        let metalVersion = metalVer.isEmpty ? osMetalVersion() : metalVer

        return GPUData(
            utilization: util,
            renderUtilization: renderUtil,
            tilerUtilization: tilerUtil,
            computeUtilization: computeUtil,
            vramUsed: vramUsed,
            vramMapped: vramMapped,
            vramTotal: vramTotal,
            memReadBytesPerSec: readBW,
            memWriteBytesPerSec: writeBW,
            temperature: temp,
            power: power,
            frequency: 0,       // Apple Silicon doesn't expose current core clock via IOKit
            memoryFrequency: 0,
            encoderUtilization: encoderUtil,
            decoderUtilization: decoderUtil,
            proResUtilization: proResUtil,
            fanPercent: fanPercent,
            fanRPM: fanRPM,
            aneUtilization: aneUtil,
            anePower: anePower,
            gpuName: gpuName,
            coreCount: coreCount,
            metalVersion: metalVersion,
            topProcesses: processes
        )
    }

    // MARK: - IOKit accelerator read

    private func readAcceleratorStats() -> (
        util: Double, renderUtil: Double, tilerUtil: Double, computeUtil: Double,
        vramUsed: UInt64, vramMapped: UInt64, vramTotal: UInt64,
        readBW: UInt64, writeBW: UInt64,
        encoderUtil: Double, decoderUtil: Double, proResUtil: Double,
        aneUtil: Double, anePow: Double,
        gpuName: String, coreCount: Int, metalVer: String,
        processes: [GPUProcess]
    ) {
        let matching = IOServiceMatching("IOAccelerator")
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == kIOReturnSuccess else {
            return (0,0,0,0,0,0,0,0,0,0,0,0,0,0,"Apple GPU",0,"Metal 3",[])
        }
        defer { IOObjectRelease(iterator) }

        var util: Double = 0
        var renderUtil: Double = 0
        var tilerUtil: Double = 0
        var computeUtil: Double = 0
        var vramUsed: UInt64 = 0
        var vramMapped: UInt64 = 0
        var readBW: UInt64 = 0
        var writeBW: UInt64 = 0
        var encoderUtil: Double = 0
        var decoderUtil: Double = 0
        var proResUtil: Double = 0
        var aneUtil: Double = 0
        var anePow: Double = 0
        var gpuName = "Apple GPU"
        var coreCount = 0
        var metalVer = "Metal 3"
        var processes: [GPUProcess] = []

        var totalMem: UInt64 = 0
        var sz = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &totalMem, &sz, nil, 0)

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }

            var props: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess,
                  let dict = props?.takeRetainedValue() as? [String: Any] else { continue }

            // GPU name
            if let name = dict["IOGLBundleName"] as? String, !name.isEmpty {
                gpuName = name
            }
            if let name = dict["model"] as? String, !name.isEmpty {
                gpuName = name
            }

            if let perf = dict["PerformanceStatistics"] as? [String: Any] {
                // Overall utilization
                if let v = perf["Device Utilization %"] as? Double { util = v }
                else if let v = perf["GPU Activity(%)"] as? Double { util = v }
                else if let v = perf["Device Utilization %"] as? Int { util = Double(v) }

                // Per-engine utilization
                if let v = perf["Renderer Utilization %"] as? Double { renderUtil = v }
                else if let v = perf["Renderer Utilization %"] as? Int { renderUtil = Double(v) }

                if let v = perf["Tiler Utilization %"] as? Double { tilerUtil = v }
                else if let v = perf["Tiler Utilization %"] as? Int { tilerUtil = Double(v) }

                if let v = perf["Compute Utilization %"] as? Double { computeUtil = v }
                else if let v = perf["Compute Utilization %"] as? Int { computeUtil = Double(v) }

                // Memory
                if let v = perf["Alloc system memory"] as? UInt64 { vramUsed = v }
                else if let v = perf["vramUsedBytes"] as? UInt64 { vramUsed = v }
                else if let v = perf["Alloc system memory"] as? Int64 { vramUsed = UInt64(max(0, v)) }

                if let v = perf["In use system memory"] as? UInt64 { vramMapped = v }
                else if let v = perf["In use system memory"] as? Int64 { vramMapped = UInt64(max(0, v)) }

                // Memory bandwidth (bytes/sec, reported directly or as counters)
                if let v = perf["recoveredPagedMemory"] as? UInt64 { _ = v }  // not BW
                if let v = perf["GPU Core Read Bandwidth"] as? UInt64 { readBW = v }
                else if let v = perf["GPU Core Read Bandwidth"] as? Int64 { readBW = UInt64(max(0, v)) }
                if let v = perf["GPU Core Write Bandwidth"] as? UInt64 { writeBW = v }
                else if let v = perf["GPU Core Write Bandwidth"] as? Int64 { writeBW = UInt64(max(0, v)) }

                // Encoders
                if let v = perf["In use system memory"] as? UInt64 { _ = v }
                if let v = perf["Video Encode Utilization %"] as? Double { encoderUtil = v }
                else if let v = perf["Video Encode Utilization %"] as? Int { encoderUtil = Double(v) }
                if let v = perf["Video Decode Utilization %"] as? Double { decoderUtil = v }
                else if let v = perf["Video Decode Utilization %"] as? Int { decoderUtil = Double(v) }

                // ANE
                if let v = perf["Neural Engine Utilization %"] as? Double { aneUtil = v }
                else if let v = perf["Neural Engine Utilization %"] as? Int { aneUtil = Double(v) }
            }

            // Core count from AGX properties
            if let cores = dict["gpu-core-count"] as? Int { coreCount = cores }
            else if let cores = dict["GPUCoreCount"] as? Int { coreCount = cores }

            // Collect per-client GPU process stats
            if let clients = dict["PerformanceStatisticsClients"] as? [String: Any] {
                for (pname, val) in clients {
                    if let clientStats = val as? [String: Any],
                       let gpuPct = clientStats["Device Utilization %"] as? Double,
                       gpuPct > 0.5 {
                        let pid = clientStats["pid"] as? Int32 ?? 0
                        let procType = inferProcessType(name: pname, stats: clientStats)
                        processes.append(GPUProcess(id: pid, name: pname, gpuPercent: gpuPct, type: procType))
                    }
                }
            }
        }

        // Sort processes descending by GPU usage, cap at 10
        processes.sort { $0.gpuPercent > $1.gpuPercent }
        if processes.count > 10 { processes = Array(processes.prefix(10)) }

        return (util, renderUtil, tilerUtil, computeUtil,
                vramUsed, vramMapped, totalMem,
                readBW, writeBW,
                encoderUtil, decoderUtil, proResUtil,
                aneUtil, anePow,
                gpuName, coreCount, metalVer,
                processes)
    }

    // MARK: - Helpers

    private func inferProcessType(name: String, stats: [String: Any]) -> String {
        let lower = name.lowercased()
        if lower.contains("windowserver") || lower.contains("dock") || lower.contains("finder") ||
           lower.contains("safari") || lower.contains("chrome") || lower.contains("firefox") {
            return "Render"
        }
        if lower.contains("compute") || lower.contains("xcode") || lower.contains("python") ||
           lower.contains("metal") {
            return "Compute"
        }
        return "Display"
    }

    private func osMetalVersion() -> String {
        let ver = Foundation.ProcessInfo.processInfo.operatingSystemVersion
        // macOS 15+ = Metal 4, macOS 14 = Metal 3, earlier = Metal 3
        if ver.majorVersion >= 15 { return "Metal 4" }
        return "Metal 3"
    }
}

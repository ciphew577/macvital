import Foundation
import Darwin

final class CPUReader {

    func read(smc: SMCReader?) -> CPUData {
        var numCPUs: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var cpuInfoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUs, &cpuInfo, &cpuInfoCount)

        guard result == KERN_SUCCESS, let info = cpuInfo else {
            return CPUData(cores: [], totalUsage: 0, systemUsage: 0, userUsage: 0, idleUsage: 100, coreCount: 0, performanceCoreCount: 0, efficiencyCoreCount: 0)
        }

        let coreCount = Int(numCPUs)
        let (pCores, eCores) = getCoreTopology()
        var cores: [CPUCore] = []
        var totalUser: Double = 0
        var totalSystem: Double = 0
        var totalIdle: Double = 0

        let tempKeys = SMCReader.appleSiliconTempKeys.filter { $0.category == "CPU Temperature" }

        for i in 0..<coreCount {
            let offset = Int32(i) * CPU_STATE_MAX
            let user = Double(info[Int(offset + CPU_STATE_USER)])
            let system = Double(info[Int(offset + CPU_STATE_SYSTEM)])
            let idle = Double(info[Int(offset + CPU_STATE_IDLE)])
            let nice = Double(info[Int(offset + CPU_STATE_NICE)])

            let total = user + system + idle + nice
            let usage = total > 0 ? ((user + system + nice) / total) * 100.0 : 0

            let clusterType: ClusterType = {
                if eCores > 0 && i < eCores { return .efficiency }
                if eCores > 0 && i >= eCores { return .performance }
                return .unknown
            }()

            let temp: Double = {
                if i < tempKeys.count, let t = smc?.readTemperature(key: tempKeys[i].key) { return t }
                return 0
            }()

            cores.append(CPUCore(id: i, usage: usage, frequency: getFrequency(), temperature: temp, power: 0, clusterType: clusterType))
            totalUser += user
            totalSystem += system
            totalIdle += idle
        }

        let grandTotal = totalUser + totalSystem + totalIdle
        let totalUsage = grandTotal > 0 ? ((totalUser + totalSystem) / grandTotal) * 100.0 : 0
        let systemPct = grandTotal > 0 ? (totalSystem / grandTotal) * 100.0 : 0
        let userPct = grandTotal > 0 ? (totalUser / grandTotal) * 100.0 : 0
        let idlePct = grandTotal > 0 ? (totalIdle / grandTotal) * 100.0 : 0

        let prevSize = vm_size_t(cpuInfoCount) * vm_size_t(MemoryLayout<integer_t>.stride)
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), prevSize)

        return CPUData(cores: cores, totalUsage: totalUsage, systemUsage: systemPct, userUsage: userPct, idleUsage: idlePct, coreCount: coreCount, performanceCoreCount: pCores, efficiencyCoreCount: eCores)
    }

    private func getCoreTopology() -> (performance: Int, efficiency: Int) {
        var pCores: Int32 = 0
        var eCores: Int32 = 0
        var size = MemoryLayout<Int32>.size
        if sysctlbyname("hw.perflevel0.logicalcpu", &pCores, &size, nil, 0) == 0,
           sysctlbyname("hw.perflevel1.logicalcpu", &eCores, &size, nil, 0) == 0 {
            return (Int(pCores), Int(eCores))
        }
        return (0, 0)
    }

    private func getFrequency() -> UInt64 {
        var freq: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        if sysctlbyname("hw.cpufrequency", &freq, &size, nil, 0) == 0 {
            return freq / 1_000_000
        }
        return 0
    }
}

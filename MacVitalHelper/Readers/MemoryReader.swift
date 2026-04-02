import Foundation
import Darwin

final class MemoryReader {

    func read() -> MemoryData {
        let pageSize = UInt64(vm_kernel_page_size)

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)

        let result = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return MemoryData(total: 0, used: 0, free: 0, wired: 0, active: 0, inactive: 0, compressed: 0, purgeable: 0, swapUsed: 0, swapFree: 0, pressureLevel: .nominal)
        }

        var totalMem: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &totalMem, &size, nil, 0)

        // Use &* to prevent overflow traps on unsigned multiplication/subtraction
        let wired = UInt64(bitPattern: Int64(stats.wire_count)) &* pageSize
        let active = UInt64(bitPattern: Int64(stats.active_count)) &* pageSize
        let inactive = UInt64(bitPattern: Int64(stats.inactive_count)) &* pageSize
        let compressed = UInt64(bitPattern: Int64(stats.compressor_page_count)) &* pageSize
        let purgeable = UInt64(bitPattern: Int64(stats.purgeable_count)) &* pageSize
        let free = UInt64(bitPattern: Int64(stats.free_count)) &* pageSize
        // Match Activity Monitor: used = wired + active + compressed (occupied by compressor)
        // Excludes inactive (file cache) and speculative pages which are reclaimable
        let used = wired &+ active &+ compressed

        var swapUsage = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.size
        sysctlbyname("vm.swapusage", &swapUsage, &swapSize, nil, 0)

        let pressure = getPressureLevel(swapUsage)

        let swapUsedVal = UInt64(bitPattern: Int64(swapUsage.xsu_used))
        // xsu_avail IS the free/available swap amount (not total), so use it directly
        let swapFreeVal = UInt64(bitPattern: Int64(swapUsage.xsu_avail))

        return MemoryData(total: totalMem, used: used, free: free, wired: wired, active: active, inactive: inactive, compressed: compressed, purgeable: purgeable, swapUsed: swapUsedVal, swapFree: swapFreeVal, pressureLevel: pressure)
    }

    private func getPressureLevel(_ swap: xsw_usage) -> MemoryPressureLevel {
        let swapUsedGB = Double(Int64(swap.xsu_used)) / 1_073_741_824
        if swapUsedGB > 4 { return .critical }
        if swapUsedGB > 1 { return .warning }
        return .nominal
    }
}

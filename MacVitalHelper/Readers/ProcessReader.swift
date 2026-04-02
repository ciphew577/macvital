import Foundation
import Darwin

final class ProcessReader {

    func readTopProcesses(limit: Int = 10) -> (cpuTop: [ProcessInfo], memTop: [ProcessInfo]) {
        var pids = [pid_t](repeating: 0, count: 2048)
        let byteCount = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size))
        let pidCount = Int(byteCount) / MemoryLayout<pid_t>.size

        var processes: [(pid: Int32, name: String, cpu: Double, mem: UInt64)] = []

        for i in 0..<pidCount {
            let pid = pids[i]
            guard pid > 0 else { continue }

            var taskInfo = proc_taskinfo()
            let taskInfoSize = Int32(MemoryLayout<proc_taskinfo>.size)
            let result = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, taskInfoSize)
            guard result == taskInfoSize else { continue }

            var pathBuffer = [CChar](repeating: 0, count: 4096)
            proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count))
            let path = String(cString: pathBuffer)
            let name = (path as NSString).lastPathComponent
            guard !name.isEmpty else { continue }

            let cpuTime = Double(taskInfo.pti_total_user + taskInfo.pti_total_system) / 1_000_000_000.0
            let memBytes = UInt64(taskInfo.pti_resident_size)

            processes.append((pid: pid, name: name, cpu: cpuTime, mem: memBytes))
        }

        let memSorted = processes.sorted { $0.mem > $1.mem }
            .prefix(limit)
            .map { ProcessInfo(id: $0.pid, name: $0.name, cpuUsage: $0.cpu, memoryBytes: $0.mem) }

        let cpuSorted = processes.sorted { $0.cpu > $1.cpu }
            .prefix(limit)
            .map { ProcessInfo(id: $0.pid, name: $0.name, cpuUsage: $0.cpu, memoryBytes: $0.mem) }

        return (cpuTop: Array(cpuSorted), memTop: Array(memSorted))
    }
}

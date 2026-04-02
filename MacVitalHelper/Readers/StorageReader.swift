import Foundation
import IOKit
import IOKit.storage

final class StorageReader {

    // Previous cumulative byte totals + timestamp for delta calculation
    private var prevReadBytes: UInt64 = 0
    private var prevWriteBytes: UInt64 = 0
    private var prevSampleTime: Date = .distantPast

    // Cached space breakdown — dir scanning is expensive (5-10s), refresh every 5 min
    private var cachedBreakdown: SpaceBreakdown?
    private var lastBreakdownTime: Date = .distantPast
    private let breakdownInterval: TimeInterval = 300 // 5 minutes

    func read() -> StorageData {
        let volumes = getVolumes()
        let (smartAttrs, healthPercent) = getSMARTData()
        let (readSpeed, writeSpeed) = getDiskIOStats()

        // Use cached breakdown unless stale (>5 min) — dir scanning takes 5-10s
        let now = Date()
        let breakdown: SpaceBreakdown?
        if let cached = cachedBreakdown, now.timeIntervalSince(lastBreakdownTime) < breakdownInterval {
            breakdown = cached
        } else {
            breakdown = getSpaceBreakdown()
            cachedBreakdown = breakdown
            lastBreakdownTime = now
        }

        return StorageData(
            volumes: volumes,
            smartAttributes: smartAttrs,
            healthPercent: healthPercent,
            readBytesPerSec: readSpeed,
            writeBytesPerSec: writeSpeed,
            spaceBreakdown: breakdown
        )
    }

    /// Lightweight I/O-only read — call at 2-3s intervals for real-time throughput.
    /// Returns just the delta bytes/sec; caller merges into existing StorageData.
    func readIOOnly() -> (readBytesPerSec: UInt64, writeBytesPerSec: UInt64) {
        let io = getDiskIOStats()
        return (readBytesPerSec: io.read, writeBytesPerSec: io.write)
    }

    private func getVolumes() -> [Volume] {
        var volumes: [Volume] = []
        let fm = FileManager.default
        guard let mountedURLs = fm.mountedVolumeURLs(includingResourceValuesForKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeNameKey,
            .volumeLocalizedFormatDescriptionKey
        ], options: [.skipHiddenVolumes]) else { return [] }

        for url in mountedURLs {
            guard let values = try? url.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityKey,
                .volumeNameKey,
                .volumeLocalizedFormatDescriptionKey
            ]) else { continue }

            let total = UInt64(values.volumeTotalCapacity ?? 0)
            let free = UInt64(values.volumeAvailableCapacity ?? 0)
            let name = values.volumeName ?? url.lastPathComponent
            let fs = values.volumeLocalizedFormatDescription ?? "Unknown"

            volumes.append(Volume(
                name: name,
                mountPoint: url.path,
                totalBytes: total,
                usedBytes: total - free,
                freeBytes: free,
                fileSystem: fs
            ))
        }
        return volumes
    }

    /// Read NVMe SMART data via IOKit
    private func getSMARTData() -> ([SMARTAttribute], Double) {
        var attrs: [SMARTAttribute] = []

        let matching = IOServiceMatching("IONVMeController")
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == kIOReturnSuccess else {
            return ([], 100)
        }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }

            // Walk children to find IONVMeSMARTInterface
            var childIterator: io_iterator_t = 0
            guard IORegistryEntryGetChildIterator(service, kIOServicePlane, &childIterator) == kIOReturnSuccess else { continue }
            defer { IOObjectRelease(childIterator) }

            var child = IOIteratorNext(childIterator)
            while child != 0 {
                defer {
                    IOObjectRelease(child)
                    child = IOIteratorNext(childIterator)
                }

                if let props = getProperties(service: child) {
                    // Parse NVMe SMART/Health info
                    if let smartData = props["NVMeSMARTCapable"] as? Bool, smartData {
                        attrs = parseNVMeSMART(properties: props)
                    }
                }
            }
        }

        // If we couldn't get SMART from NVMe controller, try the block storage device
        if attrs.isEmpty {
            attrs = getSMARTFromBlockDevice()
        }

        // Apple Silicon M4: IOKit properties don't expose SMART values directly —
        // they require the NVMeSMARTLib CFPlugin. Fall back to smartctl if available.
        if attrs.isEmpty {
            attrs = getSMARTFromSmartctl()
        }

        let healthPercent = calculateSMARTHealth(attrs)
        return (attrs, healthPercent)
    }

    private func getSMARTFromBlockDevice() -> [SMARTAttribute] {
        var attrs: [SMARTAttribute] = []

        // Try multiple controller names for different Apple Silicon generations
        for controllerName in ["AppleANS3NVMeController", "AppleANS2NVMeController", "IONVMeController"] {
            if let m = IOServiceMatching(controllerName) {
                var iterator: io_iterator_t = 0
                if IOServiceGetMatchingServices(kIOMainPortDefault, m, &iterator) == kIOReturnSuccess {
                    var service = IOIteratorNext(iterator)
                    while service != 0 {
                        if let props = getProperties(service: service) {
                            attrs = parseNVMeSMART(properties: props)
                        }
                        IOObjectRelease(service)
                        if !attrs.isEmpty { break }
                        service = IOIteratorNext(iterator)
                    }
                    IOObjectRelease(iterator)
                    if !attrs.isEmpty { break }
                }
            }
        }
        return attrs
    }

    private func parseNVMeSMART(properties: [String: Any]) -> [SMARTAttribute] {
        var attrs: [SMARTAttribute] = []
        var id = 1

        let smartMappings: [(key: String, name: String, explanation: String, threshold: String)] = [
            ("Temperature", "Temperature", "Current drive temperature in Celsius.", "70°C"),
            ("AvailableSpare", "Available Spare", "Percentage of spare NVMe blocks remaining — below threshold indicates drive degradation.", "10%"),
            ("AvailableSpareThreshold", "Available Spare Threshold", "Manufacturer's minimum acceptable spare percentage.", "—"),
            ("PercentageUsed", "Percentage Used", "Estimates how much of the drive's total write endurance has been consumed. Can exceed 100%.", "100%"),
            ("DataUnitsRead", "Data Units Read", "Total 512-byte units read (multiply by 1000 for actual count).", "—"),
            ("DataUnitsWritten", "Data Units Written", "Total 512-byte units written (multiply by 1000 for actual count).", "—"),
            ("HostReadCommands", "Host Read Commands", "Total read commands issued by the host.", "—"),
            ("HostWriteCommands", "Host Write Commands", "Total write commands issued by the host.", "—"),
            ("ControllerBusyTime", "Controller Busy Time", "Minutes the controller was busy processing commands.", "—"),
            ("PowerCycles", "Power Cycles", "Number of power on/off cycles.", "—"),
            ("PowerOnHours", "Power On Hours", "Total hours the drive has been powered on.", "—"),
            ("UnsafeShutdowns", "Unsafe Shutdowns", "Number of unexpected power losses. High values may indicate power issues.", "100"),
            ("MediaErrors", "Media and Data Integrity Errors", "Number of unrecovered data integrity errors. Should be zero.", "0"),
            ("ErrorLogEntries", "Error Information Log Entries", "Number of error log entries. Non-zero warrants investigation.", "0"),
        ]

        for mapping in smartMappings {
            if let value = properties[mapping.key] {
                let rawStr: String
                if let num = value as? NSNumber {
                    rawStr = num.stringValue
                } else {
                    rawStr = "\(value)"
                }

                let status: SMARTStatus = evaluateSMARTStatus(name: mapping.key, rawValue: rawStr, threshold: mapping.threshold)

                attrs.append(SMARTAttribute(
                    id: id,
                    name: mapping.name,
                    rawValue: rawStr,
                    threshold: mapping.threshold,
                    status: status,
                    explanation: mapping.explanation
                ))
                id += 1
            }
        }

        return attrs
    }

    private func evaluateSMARTStatus(name: String, rawValue: String, threshold: String) -> SMARTStatus {
        guard let value = Double(rawValue.replacingOccurrences(of: "%", with: "").replacingOccurrences(of: "°C", with: "")) else { return .unknown }

        switch name {
        case "PercentageUsed":
            if value >= 90 { return .critical }
            if value >= 70 { return .warning }
            return .good
        case "AvailableSpare":
            if value <= 10 { return .critical }
            if value <= 30 { return .warning }
            return .good
        case "Temperature":
            if value >= 70 { return .critical }
            if value >= 55 { return .warning }
            return .good
        case "MediaErrors", "ErrorLogEntries":
            if value > 0 { return .critical }
            return .good
        case "UnsafeShutdowns":
            if value > 100 { return .warning }
            return .good
        default:
            return .good
        }
    }

    private func calculateSMARTHealth(_ attrs: [SMARTAttribute]) -> Double {
        var health = 100.0

        for attr in attrs {
            switch attr.name {
            case "Percentage Used":
                if let val = Double(attr.rawValue.replacingOccurrences(of: "%", with: "")) {
                    health = min(health, max(0, 100 - val))
                }
            case "Available Spare":
                if let val = Double(attr.rawValue.replacingOccurrences(of: "%", with: "")), val < 10 {
                    health -= 20
                }
            case "Media and Data Integrity Errors":
                if let val = Double(attr.rawValue), val > 0 {
                    health -= min(val * 5, 30)
                }
            case "Unsafe Shutdowns":
                if let val = Double(attr.rawValue), val > 100 {
                    health -= 10
                }
            default: break
            }
        }

        return max(0, min(100, health))
    }

    private func getDiskIOStats() -> (read: UInt64, write: UInt64) {
        // IOKit disk stats — cumulative bytes since boot
        let matching = IOServiceMatching("IOBlockStorageDriver")
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == kIOReturnSuccess else {
            return (0, 0)
        }
        defer { IOObjectRelease(iterator) }

        var cumulativeRead: UInt64 = 0
        var cumulativeWrite: UInt64 = 0

        var service = IOIteratorNext(iterator)
        while service != 0 {
            if let props = getProperties(service: service),
               let stats = props["Statistics"] as? [String: Any] {
                cumulativeRead  += (stats["Bytes (Read)"]  as? UInt64) ?? 0
                cumulativeWrite += (stats["Bytes (Write)"] as? UInt64) ?? 0
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }

        let now = Date()
        let elapsed = now.timeIntervalSince(prevSampleTime)

        // First call or too-rapid polling — store baseline, return 0
        // Require at least 1s between samples to avoid division-by-near-zero
        guard prevSampleTime != .distantPast, elapsed >= 1.0 else {
            if prevSampleTime == .distantPast {
                // True first call — set baseline
                prevReadBytes  = cumulativeRead
                prevWriteBytes = cumulativeWrite
                prevSampleTime = now
            }
            // If elapsed < 1s, skip update — return 0 and keep previous baseline
            return (0, 0)
        }

        // Guard against counter wrap or reset
        let deltaRead  = cumulativeRead  >= prevReadBytes  ? cumulativeRead  - prevReadBytes  : 0
        let deltaWrite = cumulativeWrite >= prevWriteBytes ? cumulativeWrite - prevWriteBytes : 0

        prevReadBytes  = cumulativeRead
        prevWriteBytes = cumulativeWrite
        prevSampleTime = now

        let readPerSec  = UInt64(Double(deltaRead)  / elapsed)
        let writePerSec = UInt64(Double(deltaWrite) / elapsed)

        return (readPerSec, writePerSec)
    }

    /// Compute real space breakdown by scanning key directories on the boot volume.
    /// Uses FileManager's fast `allocatedSizeOfDirectory` via enumerator with
    /// .skipsHiddenFiles for speed. Anything not categorised goes into "Other".
    private func getSpaceBreakdown() -> SpaceBreakdown? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let fm = FileManager.default

        // Quick directory size — sum allocated sizes via URL resource values
        func dirSize(_ path: String) -> UInt64 {
            let url = URL(fileURLWithPath: path)
            guard let enumerator = fm.enumerator(
                at: url,
                includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: nil
            ) else { return 0 }
            var total: UInt64 = 0
            for case let fileURL as URL in enumerator {
                guard let values = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey]) else { continue }
                total += UInt64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
            }
            return total
        }

        let appsBytes = dirSize("/Applications")
        let docsBytes = dirSize(home + "/Documents") + dirSize(home + "/Desktop") + dirSize(home + "/Downloads")

        // Photos: ~/Pictures and Photos Library
        var photosBytes = dirSize(home + "/Pictures")
        let photosLib = home + "/Pictures/Photos Library.photoslibrary"
        if fm.fileExists(atPath: photosLib) {
            // Photos Library is a package — enumerate it explicitly
            photosBytes = dirSize(photosLib)
        }

        // System: rough estimate from /System + /Library (not user-accessible but readable metadata)
        let systemBytes = dirSize("/System") + dirSize("/Library")

        // Get total used from boot volume
        let bootURL = URL(fileURLWithPath: "/")
        let totalUsed: UInt64
        if let vals = try? bootURL.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey]) {
            let total = UInt64(vals.volumeTotalCapacity ?? 0)
            let free = UInt64(vals.volumeAvailableCapacity ?? 0)
            totalUsed = total > free ? total - free : 0
        } else {
            totalUsed = appsBytes + docsBytes + photosBytes + systemBytes
        }

        let categorised = appsBytes + docsBytes + photosBytes + systemBytes
        let otherBytes = totalUsed > categorised ? totalUsed - categorised : 0

        return SpaceBreakdown(
            appsBytes: appsBytes,
            documentsBytes: docsBytes,
            photosBytes: photosBytes,
            systemBytes: systemBytes,
            otherBytes: otherBytes
        )
    }

    /// Parse SMART data from smartctl JSON output (fallback for Apple Silicon where IOKit
    /// properties don't expose SMART values directly).
    private func getSMARTFromSmartctl() -> [SMARTAttribute] {
        // Try common install locations
        let smartctlPaths = ["/opt/homebrew/bin/smartctl", "/usr/local/bin/smartctl", "/usr/bin/smartctl"]
        guard let smartctlPath = smartctlPaths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            return []
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: smartctlPath)
        process.arguments = ["-a", "/dev/disk0", "-j"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let nvmeSmart = json["nvme_smart_health_information_log"] as? [String: Any] else {
            return []
        }

        var attrs: [SMARTAttribute] = []
        var id = 1

        let mappings: [(jsonKey: String, name: String, explanation: String, threshold: String, formatter: (Any) -> String)] = [
            ("temperature", "Temperature", "Current drive temperature in Celsius.", "70°C", { "\($0)" }),
            ("available_spare", "Available Spare", "Percentage of spare NVMe blocks remaining.", "10%", { "\($0)%" }),
            ("available_spare_threshold", "Available Spare Threshold", "Manufacturer's minimum acceptable spare percentage.", "\u{2014}", { "\($0)%" }),
            ("percentage_used", "Percentage Used", "How much of the drive's write endurance has been consumed.", "100%", { "\($0)%" }),
            ("data_units_read", "Data Units Read", "Total 512-byte units read (multiply by 1000 for actual count).", "\u{2014}", { v in
                if let n = v as? Int64 ?? (v as? NSNumber)?.int64Value {
                    let tb = Double(n) * 512_000 / 1_000_000_000_000
                    return String(format: "%.1f TB", tb)
                }
                return "\(v)"
            }),
            ("data_units_written", "Data Units Written", "Total 512-byte units written (multiply by 1000 for actual count).", "\u{2014}", { v in
                if let n = v as? Int64 ?? (v as? NSNumber)?.int64Value {
                    let tb = Double(n) * 512_000 / 1_000_000_000_000
                    return String(format: "%.1f TB", tb)
                }
                return "\(v)"
            }),
            ("host_reads", "Host Read Commands", "Total read commands issued by the host.", "\u{2014}", { v in
                if let n = v as? Int64 ?? (v as? NSNumber)?.int64Value {
                    return StorageReader.formatLargeNumber(n)
                }
                return "\(v)"
            }),
            ("host_writes", "Host Write Commands", "Total write commands issued by the host.", "\u{2014}", { v in
                if let n = v as? Int64 ?? (v as? NSNumber)?.int64Value {
                    return StorageReader.formatLargeNumber(n)
                }
                return "\(v)"
            }),
            ("controller_busy_time", "Controller Busy Time", "Minutes the controller was busy processing commands.", "\u{2014}", { "\($0)" }),
            ("power_cycles", "Power Cycles", "Number of power on/off cycles.", "\u{2014}", { "\($0)" }),
            ("power_on_hours", "Power On Hours", "Total hours the drive has been powered on.", "\u{2014}", { v in
                if let n = v as? Int64 ?? (v as? NSNumber)?.int64Value {
                    return "\(n) hrs"
                }
                return "\(v)"
            }),
            ("unsafe_shutdowns", "Unsafe Shutdowns", "Number of unexpected power losses.", "100", { "\($0)" }),
            ("media_errors", "Media and Data Integrity Errors", "Unrecovered data integrity errors. Should be zero.", "0", { "\($0)" }),
            ("num_err_log_entries", "Error Information Log Entries", "Number of error log entries.", "0", { "\($0)" }),
        ]

        for mapping in mappings {
            if let value = nvmeSmart[mapping.jsonKey] {
                let rawStr = mapping.formatter(value)
                let numericStr: String
                if let num = value as? NSNumber {
                    numericStr = num.stringValue
                } else {
                    numericStr = "\(value)"
                }
                let status = evaluateSMARTStatus(name: mapping.name == "Temperature" ? "Temperature" :
                                                       mapping.name == "Available Spare" ? "AvailableSpare" :
                                                       mapping.name == "Percentage Used" ? "PercentageUsed" :
                                                       mapping.name == "Media and Data Integrity Errors" ? "MediaErrors" :
                                                       mapping.name == "Error Information Log Entries" ? "ErrorLogEntries" :
                                                       mapping.name == "Unsafe Shutdowns" ? "UnsafeShutdowns" : mapping.jsonKey,
                                                 rawValue: numericStr,
                                                 threshold: mapping.threshold)

                attrs.append(SMARTAttribute(
                    id: id,
                    name: mapping.name,
                    rawValue: rawStr,
                    threshold: mapping.threshold,
                    status: status,
                    explanation: mapping.explanation
                ))
                id += 1
            }
        }

        return attrs
    }

    /// Format large numbers with comma separators for readability
    static func formatLargeNumber(_ n: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    private func getProperties(service: io_object_t) -> [String: Any]? {
        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess else {
            return nil
        }
        return props?.takeRetainedValue() as? [String: Any]
    }
}

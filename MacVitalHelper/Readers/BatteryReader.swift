import Foundation
import IOKit
import IOKit.ps

final class BatteryReader {

    func read() -> BatteryData? {
        // First try IOPowerSources for basic info
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [Any],
              let first = sources.first,
              let desc = IOPSGetPowerSourceDescription(snapshot, first as CFTypeRef)?.takeUnretainedValue() as? [String: Any]
        else { return nil }

        // Get detailed battery info from IOKit registry
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == kIOReturnSuccess,
              let battery = props?.takeRetainedValue() as? [String: Any] else { return nil }

        let designCap = battery["DesignCapacity"] as? Int ?? 0
        // MaxCapacity from IOKit can be a percentage (100) on newer macOS.
        // Use AppleRawMaxCapacity (mAh) for the real absolute value.
        let rawMaxCap = battery["AppleRawMaxCapacity"] as? Int ?? 0
        let maxCapPct = battery["MaxCapacity"] as? Int ?? 0
        // If MaxCapacity looks like a percentage (<=100) and raw is available, prefer raw.
        let maxCap = (maxCapPct <= 100 && rawMaxCap > 0) ? rawMaxCap : maxCapPct

        // Same for CurrentCapacity — prefer AppleRawCurrentCapacity (mAh) over percentage.
        let rawCurrentCap = battery["AppleRawCurrentCapacity"] as? Int ?? 0
        let currentCapPct = battery["CurrentCapacity"] as? Int ?? 0
        let currentCharge = (currentCapPct <= 100 && rawCurrentCap > 0) ? rawCurrentCap : currentCapPct

        let cycleCount = battery["CycleCount"] as? Int ?? 0

        // Temperature is in centi-degrees (e.g., 2950 = 29.50°C)
        let tempRaw = battery["Temperature"] as? Int ?? 0
        let temperature = Double(tempRaw) / 100.0

        let voltage = Double(battery["Voltage"] as? Int ?? 0) / 1000.0 // mV to V
        // Amperage can overflow Swift Int on Apple Silicon — IOKit stores the value
        // as a UInt64 representation of a negative Int64 (e.g., -3154 mA becomes
        // 18446744073709548462). Cast as? Int fails because the unsigned value exceeds
        // Int.max. Use NSNumber.int64Value to correctly interpret the signed value.
        let amperage: Int = {
            if let a = battery["Amperage"] as? Int, a >= Int(Int16.min), a <= Int(Int16.max) {
                return a
            }
            if let num = battery["Amperage"] as? NSNumber {
                return Int(num.int64Value)
            }
            return 0
        }()
        let wattage = abs(Double(amperage) / 1000.0 * voltage)

        let isCharging = battery["IsCharging"] as? Bool ?? false
        let isFullyCharged = battery["FullyCharged"] as? Bool ?? false
        let timeRemaining = battery["TimeRemaining"] as? Int ?? -1

        // Battery condition
        let condition: String
        if let permanentFailure = battery["PermanentFailureStatus"] as? Int, permanentFailure != 0 {
            condition = "Service Required"
        } else if let batteryHealth = battery["BatteryHealthCondition"] as? String {
            condition = batteryHealth
        } else {
            condition = "Normal"
        }

        // Manufacture date (packed format: bits 0-4 = day, 5-8 = month, 9-15 = year from 1980)
        let mfgDateRaw = battery["ManufactureDate"] as? Int ?? 0
        let day = mfgDateRaw & 0x1F
        let month = (mfgDateRaw >> 5) & 0x0F
        let year = (mfgDateRaw >> 9) + 1980
        let mfgDate = "\(year)-\(String(format: "%02d", month))-\(String(format: "%02d", day))"

        let serial = battery["BatterySerialNumber"] as? String ?? battery["Serial"] as? String ?? "Unknown"

        let percentage = maxCap > 0 ? (Double(currentCharge) / Double(maxCap)) * 100.0 : 0

        // Suppress unused variable warning for desc
        _ = desc

        return BatteryData(
            designCapacity: designCap,
            maxCapacity: maxCap,
            currentCharge: currentCharge,
            percentage: percentage,
            cycleCount: cycleCount,
            temperature: temperature,
            voltage: voltage,
            amperage: amperage,
            wattage: wattage,
            isCharging: isCharging,
            isFullyCharged: isFullyCharged,
            timeRemaining: timeRemaining,
            condition: condition,
            manufactureDate: mfgDate,
            serialNumber: serial
        )
    }
}

// MacVitalHelper/HelperServiceFanControl.swift
// Extension on HelperService implementing fan control protocol methods.
// Separated to keep main.swift clean and to allow the linter to manage it independently.

import Foundation
import IOKit

// MARK: - SMC Key Allowlist (H6 finding)
//
// readSMCKey is exposed over XPC and previously accepted any 4-char string.
// The kernel SMC interface includes write keys, restart keys, and other
// operations a privileged helper should never expose to the main app, // even read-only access can leak per-machine identifiers via SRNM, SBPC,
// MSPS and similar keys.
//
// We restrict reads to keys that are clearly fan / temperature / power /
// battery / voltage / current. Any key not in this set is rejected.

private let kReadSMCKeyAllowlist: Set<String> = {
    var allow: Set<String> = []

    // Temperature keys, every entry from SMCReader.appleSiliconTempKeys.
    for tempKey in SMCReader.appleSiliconTempKeys {
        allow.insert(tempKey.key)
    }

    // Fan control + telemetry. Cover up to 8 fans (no consumer Mac ships more).
    for i in 0..<8 {
        for suffix in ["Ac", "Tg", "Md", "Mn", "Mx", "Sf", "ID"] {
            allow.insert("F\(i)\(suffix)")
        }
    }
    allow.insert("FNum")
    allow.insert("Ftst")

    // Battery and power. Single-battery only; no consumer Mac ships more.
    let batteryKeys = ["B0AC", "B0AV", "B0AT", "B0CT", "B0FC", "B0NC",
                       "B0PS", "B0RM", "B0St", "B0TE", "B0TF", "B0Tc",
                       "BATC", "BATP", "BATT", "BBAD", "BBIN", "BBPL"]
    batteryKeys.forEach { allow.insert($0) }

    // Power / voltage / current rails. Pulled from the keys
    // HelperServiceFanControl.getPowerData already iterates over.
    let powerKeys = ["PSTR", "PDTR", "PCPC", "PCPT", "PCPG", "PGTR",
                     "PZC0", "PZC1", "PZCU", "PHPC", "PHPS", "PHPB",
                     "PANT", "PMVC", "PMEM", "PDCS", "PPBR", "PMED",
                     "PISP", "PSRA", "PPMC", "PPSC", "PTHS", "PDBR",
                     "P5SR", "P3F2", "PU1C", "PU2C"]
    powerKeys.forEach { allow.insert($0) }

    return allow
}()

private func isAllowedSMCReadKey(_ key: String) -> Bool {
    // Reject anything that is not exactly 4 ASCII characters before
    // even checking the set. This blocks oversized inputs and any
    // string that would not be a valid SMC key in the first place.
    guard key.count == 4, key.allSatisfy({ $0.isASCII }) else { return false }
    return kReadSMCKeyAllowlist.contains(key)
}

// MARK: - Fan Control Extension

extension HelperService {

    // MARK: - Lazy SMC instances

    // Note: We use objc_getAssociatedObject / objc_setAssociatedObject to attach
    // the SMCWriter and FanController to the HelperService instance without adding
    // stored properties to the class (Swift extensions cannot add stored properties).

    private static let smcWriterKey = UnsafeRawPointer(bitPattern: "smcWriter".hashValue)!
    private static let fanControllerKey = UnsafeRawPointer(bitPattern: "fanController".hashValue)!

    var fanControlWriter: SMCWriter? {
        if let existing = objc_getAssociatedObject(self, HelperService.smcWriterKey) as? SMCWriter {
            return existing
        }
        guard let writer = SMCWriter() else { return nil }
        objc_setAssociatedObject(self, HelperService.smcWriterKey, writer, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return writer
    }

    var fanControlController: FanController? {
        if let existing = objc_getAssociatedObject(self, HelperService.fanControllerKey) as? FanController {
            return existing
        }
        guard let w = fanControlWriter, let fc = FanController(smc: w) else { return nil }
        objc_setAssociatedObject(self, HelperService.fanControllerKey, fc, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return fc
    }

    // MARK: - Protocol Methods

    func setFanSpeed(fanIndex: Int, rpm: Int, withReply reply: @escaping (Bool, String?) -> Void) {
        guard let fc = fanControlController else {
            reply(false, "FanController unavailable — AppleSMC not accessible")
            return
        }
        smcLog("XPC: setFanSpeed fan=\(fanIndex) rpm=\(rpm)")
        let (ok, err) = fc.setFanSpeed(fanIndex: fanIndex, rpm: rpm)
        reply(ok, err)
    }

    func resetFan(fanIndex: Int, withReply reply: @escaping (Bool, String?) -> Void) {
        guard let fc = fanControlController else {
            reply(false, "FanController unavailable")
            return
        }
        smcLog("XPC: resetFan fan=\(fanIndex)")
        let (ok, err) = fc.resetFan(fanIndex: fanIndex)
        reply(ok, err)
    }

    func resetAllFans(withReply reply: @escaping (Bool, String?) -> Void) {
        guard let fc = fanControlController else {
            reply(false, "FanController unavailable")
            return
        }
        smcLog("XPC: resetAllFans")
        let (ok, err) = fc.resetAllFans()
        reply(ok, err)
    }

    func setFanMode(fanIndex: Int, mode: Int, withReply reply: @escaping (Bool, String?) -> Void) {
        guard let fc = fanControlController else {
            reply(false, "FanController unavailable")
            return
        }
        smcLog("XPC: setFanMode fan=\(fanIndex) mode=\(mode)")
        let (ok, err) = fc.setFanMode(fanIndex: fanIndex, mode: mode)
        reply(ok, err)
    }

    func readSMCKey(_ key: String, withReply reply: @escaping (NSNumber?, String?) -> Void) {
        // Allowlist gate (H6): only fan / temp / power / battery keys may
        // be read over XPC. Any other key is silently rejected.
        guard isAllowedSMCReadKey(key) else {
            smcLog("XPC: readSMCKey rejected, '\(key)' not in allowlist")
            reply(nil, "Key '\(key)' is not on the helper's read allowlist")
            return
        }
        guard let w = fanControlWriter else {
            reply(nil, "SMCWriter unavailable")
            return
        }
        // Try fpe2 (RPM) first, fall back to temperature (sp78)
        if let rpm = w.readFpe2(key: key) {
            reply(rpm as NSNumber, nil)
        } else if let temp = w.readTemperature(key: key) {
            reply(temp as NSNumber, nil)
        } else {
            reply(nil, "Key '\(key)' not readable or not present")
        }
    }

    func readAllTemperatures(withReply reply: @escaping (NSDictionary?, String?) -> Void) {
        guard let w = fanControlWriter else {
            reply(nil, "SMCWriter unavailable")
            return
        }
        var result: [String: Double] = [:]
        for tempKey in SMCReader.appleSiliconTempKeys {
            if let temp = w.readTemperature(key: tempKey.key) {
                result[tempKey.key] = temp
            }
        }
        if result.isEmpty {
            reply(nil, "No temperatures readable")
        } else {
            reply(result as NSDictionary, nil)
        }
    }

    func readFanData(withReply reply: @escaping (NSDictionary?, String?) -> Void) {
        guard let fc = fanControlController else {
            reply(nil, "FanController unavailable")
            return
        }
        reply(fc.readFanData() as NSDictionary, nil)
    }

    func getPowerData(withReply reply: @escaping (NSDictionary?, String?) -> Void) {
        guard let w = fanControlWriter else {
            reply(nil, "SMCWriter unavailable")
            return
        }
        var result: [String: Double] = [:]
        // Primary power keys — encoding is flt  (IEEE 754) on M4, sp78 on older chips.
        // readTemperature auto-detects the encoding via keyInfo.
        //
        // PSTR = system/SoC total, PCPC/PCPT = CPU package, PCPG/PGTR = GPU package
        // Many of these keys only exist on certain chip generations.
        let powerKeys: [(key: String, name: String)] = [
            // === Primary totals ===
            ("PSTR", "system"),       // Total SoC/system power (most reliable on Apple Silicon)
            ("PDTR", "delivery"),     // Total power delivery rail (wall power, ~36W)
            // === CPU/GPU package ===
            ("PCPC", "cpu"),          // CPU package (Intel, some AS)
            ("PCPT", "cpu"),          // CPU package total (M-series alternate)
            ("PCPG", "gpu"),          // GPU package (Intel, some AS)
            ("PGTR", "gpu"),          // GPU total (M-series alternate)
            // === Per-cluster CPU power (real, not estimated) ===
            ("PZC0", "ecluster"),     // E-cluster power (Zone C0)
            ("PZC1", "pcluster"),     // P-cluster power (Zone C1)
            ("PZCU", "uncore"),       // Uncore power
            // === High-perf cluster ===
            ("PHPC", "hiperf"),       // High-performance cluster total
            ("PHPS", "hiperf_sust"), // High-performance sustained power
            ("PHPB", "hiperf_budget"), // High-performance power budget/limit
            // === SoC sub-components ===
            ("PANT", "ane"),          // Apple Neural Engine
            ("PMVC", "dram"),         // Memory voltage controller (real DRAM power on M4)
            ("PMEM", "dram"),         // Memory / DRAM (fallback for older chips)
            ("PDCS", "fabric"),       // DCS / Fabric (AMCC)
            ("PPBR", "pcie"),         // PCIe / Thunderbolt bridge
            ("PMED", "media"),        // Media engine
            ("PISP", "isp"),          // ISP (Image Signal Processor / camera)
            ("PSRA", "gpusram"),      // GPU SRAM
            // === Power management & thermal ===
            ("PPMC", "pmu"),          // PMU controller power
            ("PPSC", "psctrl"),       // Power supply controller
            ("PTHS", "thermal"),      // Thermal subsystem power
            // === Peripheral rails ===
            ("PDBR", "backlight"),    // Display backlight rail (real)
            ("P5SR", "rail5v"),       // 5V switched rail
            ("P3F2", "rail3v"),       // 3.3V rail
            // === USB-C port power ===
            ("PU1C", "usb1"),         // USB-C port 1 power
            ("PU2C", "usb2"),         // USB-C port 2 power
        ]
        for pk in powerKeys {
            // Skip if we already have a value for this logical name (first match wins)
            guard result[pk.name] == nil else { continue }
            if let v = w.readTemperature(key: pk.key), v >= 0 {
                result[pk.name] = v
            }
        }
        if result.isEmpty {
            reply(nil, "No power keys readable")
        } else {
            reply(result as NSDictionary, nil)
        }
    }
}

// MARK: - SIGTERM Handler (registered once at module load)

private let _sigtermSetup: Void = {
    signal(SIGTERM) { _ in
        smcLog("Helper: SIGTERM received — resetting all fans before exit")
        if let w = SMCWriter() {
            if let fc = FanController(smc: w) {
                _ = fc.resetAllFans()
            } else {
                // Fallback: try direct forced writes even if FanController init fails
                w.writeUInt8Forced(key: "Ftst", value: 0)
            }
            w.close()
        }
        exit(0)
    }
}()

// Force the sigterm setup to run when the module loads
private let _init = _sigtermSetup

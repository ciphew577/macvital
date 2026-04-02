// MacVitalHelper/SMCHelper.swift
// Privileged SMC read/write helper for fan speed control on Apple Silicon Macs.
//
// Unlock sequence (Apple Silicon / thermalmonitord handoff):
//   1. Write Ftst = 1  →  signal thermalmonitord to yield fan ownership
//   2. Poll F0Md=1 at 100ms intervals (up to 10s) → wait for thermalmonitord to yield
//   3. Write F{n}Md=1  →  manual mode per fan
//   4. Write F{n}Tg    →  target RPM (fpe2 encoded)
//   5. On exit/reset: Write Ftst = 0  →  thermalmonitord reclaims
//
// On Apple Silicon, keyInfo queries may fail for Ftst/F0Md/F0Tg even though the
// keys exist and are writable. The "forced" write methods bypass keyInfo and supply
// the data size/type explicitly. Reference: https://github.com/agoodkind/macos-smc-fan

import Foundation
import IOKit

// MARK: - SMC Command Constants for write operations
// (Read constants SMC_CMD_READ_BYTES=5 / SMC_CMD_READ_KEYINFO=9 / KERNEL_INDEX_SMC=2
//  are private to SMCReader.swift; we redeclare only what we additionally need.)

private let kSMCWriteKey:    UInt32 = 6   // SMC_CMD_WRITE_BYTES — write path only
private let kKernelIndexSMC: UInt32 = 2   // KERNEL_INDEX_SMC
private let kSMCReadKey:     UInt32 = 5   // SMC_CMD_READ_BYTES
private let kSMCReadKeyInfo: UInt32 = 9   // SMC_CMD_READ_KEYINFO

// SMC result codes
private let kSMCSuccess: UInt8 = 0

// Thermal watchdog ceiling, if any CPU sensor exceeds this, auto-reset all fans
private let kThermalCeilingCelsius: Double = 95.0

// Timeout waiting for thermalmonitord to yield after Ftst=1 (10s as per macos-smc-fan research)
private let kFtstYieldTimeout: TimeInterval = 10.0

// Retry interval when polling F0Md writability after Ftst unlock
private let kFtstRetryInterval: TimeInterval = 0.1

// Hard RPM bounds for setFanSpeed. Refuse anything below 1500 RPM (M4 Pro
// hardware minimum is ~2317 RPM, but we leave some headroom for older Macs
// without ever permitting a zero-RPM write that would silently kill cooling).
// Anything above 10_000 RPM is above any known consumer Mac fan max.
private let kFanRPMHardFloor: Int = 1500
private let kFanRPMHardCeiling: Int = 10_000

// Deadman timer: if no client heartbeat or fan write arrives for this long
// while manual fan control is active, automatically revert to thermalmonitord.
// 5 minutes matches what the user's ops manual guarantees: any agent that
// goes silent gets its unlock revoked before the next thermal event.
private let kFanDeadmanTimeout: TimeInterval = 300.0

// Note: SMCKeyData struct is defined in SMCReader.swift (same target) and shared here.
// SMCReader.swift:  struct SMCKeyData { Version / PLimitData / KeyInfo / key / vers /
//                   pLimitData / keyInfo / result / status / data8 / data32 / bytes }

// MARK: - Key Encoding Helpers

/// Pack a 4-character ASCII string into a big-endian UInt32 as the SMC expects.
func smcFourCharCode(_ str: String) -> UInt32 {
    var result: UInt32 = 0
    for (i, byte) in str.utf8.enumerated() {
        guard i < 4 else { break }
        result |= UInt32(byte) << UInt32(24 - i * 8)
    }
    return result
}

/// Decode a 16-bit fpe2 value (big-endian, 2 fractional bits) to Double.
/// fpe2: value = raw / 4.0
func fpe2ToDouble(hi: UInt8, lo: UInt8) -> Double {
    Double((UInt16(hi) << 8) | UInt16(lo)) / 4.0
}

/// Encode a Double RPM into fpe2 big-endian bytes.
func doubleToFpe2(_ value: Double) -> (UInt8, UInt8) {
    let raw = UInt16(max(0, value) * 4.0)
    return (UInt8(raw >> 8), UInt8(raw & 0xFF))
}

// MARK: - SMCWriter

/// Low-level IOKit-backed SMC reader/writer.
/// One instance per connection lifetime; call `close()` explicitly or rely on deinit.
final class SMCWriter {

    private var connection: io_connect_t = 0
    private let lock = NSLock()

    init?() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else {
            smcLog("SMCWriter: AppleSMC service not found")
            return nil
        }
        // Use connection type 0 — both BreezeKit and MacPulse use type 0
        // (confirmed via disassembly: `mov w2, #0x0` before IOServiceOpen).
        // Type 0 allows reads and writes from a privileged helper process.
        let kr = IOServiceOpen(service, mach_task_self_, 0, &connection)
        IOObjectRelease(service)
        if kr == kIOReturnSuccess {
            smcLog("SMCWriter: connection opened type=0 (\(connection))")
        } else {
            smcLog("SMCWriter: IOServiceOpen failed: 0x\(String(kr, radix: 16))")
            return nil
        }
    }

    deinit {
        close()
    }

    func close() {
        lock.lock()
        defer { lock.unlock() }
        if connection != 0 {
            IOServiceClose(connection)
            connection = 0
            smcLog("SMCWriter: connection closed")
        }
    }

    // MARK: - Key Info

    func keyInfo(for key: UInt32) -> SMCKeyData.KeyInfo? {
        lock.lock()
        defer { lock.unlock() }
        return _keyInfo(for: key)
    }

    private func _keyInfo(for key: UInt32) -> SMCKeyData.KeyInfo? {
        var input = SMCKeyData()
        input.key = key
        input.data8 = UInt8(kSMCReadKeyInfo)
        var output = SMCKeyData()
        let inputSize = MemoryLayout<SMCKeyData>.stride
        var outputSize = MemoryLayout<SMCKeyData>.stride

        let kr = IOConnectCallStructMethod(connection, kKernelIndexSMC,
                                           &input, inputSize,
                                           &output, &outputSize)
        guard kr == kIOReturnSuccess, output.result == kSMCSuccess else {
            return nil
        }
        return output.keyInfo
    }

    // MARK: - Read

    /// Read raw bytes for a key. Returns up to 32 bytes.
    func readBytes(key: String) -> [UInt8]? {
        let keyCode = smcFourCharCode(key)
        lock.lock()
        defer { lock.unlock() }

        guard let info = _keyInfo(for: keyCode), info.dataSize > 0 else { return nil }

        var input = SMCKeyData()
        input.key = keyCode
        input.keyInfo.dataSize = info.dataSize
        input.data8 = UInt8(kSMCReadKey)
        var output = SMCKeyData()
        let inputSize = MemoryLayout<SMCKeyData>.stride
        var outputSize = MemoryLayout<SMCKeyData>.stride

        let kr = IOConnectCallStructMethod(connection, kKernelIndexSMC,
                                           &input, inputSize,
                                           &output, &outputSize)
        guard kr == kIOReturnSuccess, output.result == kSMCSuccess else { return nil }

        let size = Int(info.dataSize)
        return withUnsafeBytes(of: output.bytes) { buf in
            Array(buf.prefix(size))
        }
    }

    /// Read a temperature key (sp78: signed 8.8 fixed point)
    func readTemperature(key: String) -> Double? {
        let keyCode = smcFourCharCode(key)
        lock.lock()
        let info = _keyInfo(for: keyCode)
        lock.unlock()
        guard let b = readBytes(key: key) else { return nil }

        // flt  = IEEE 754 float (Apple Silicon M4+)
        if let info = info, info.dataType == smcFourCharCode("flt "), b.count >= 4 {
            var f: Float = 0
            withUnsafeMutableBytes(of: &f) { buf in
                buf[0] = b[0]; buf[1] = b[1]; buf[2] = b[2]; buf[3] = b[3]
            }
            let temp = Double(f)
            return (temp > -40 && temp < 150) ? temp : nil
        }

        // sp78 = signed 8.8 fixed point (Intel / older)
        guard b.count >= 2 else { return nil }
        return Double((UInt16(b[0]) << 8) | UInt16(b[1])) / 256.0
    }

    /// Read an RPM value, auto-detecting `flt ` (Apple Silicon M4+) vs `fpe2` (older).
    func readFpe2(key: String) -> Double? {
        let keyCode = smcFourCharCode(key)
        lock.lock()
        let info = _keyInfo(for: keyCode)
        lock.unlock()

        guard let b = readBytes(key: key) else { return nil }

        // flt  = 4-byte native little-endian IEEE 754 float (Apple Silicon M4+)
        if let info = info, info.dataType == smcFourCharCode("flt "), b.count >= 4 {
            var f: Float = 0
            withUnsafeMutableBytes(of: &f) { buf in
                buf[0] = b[0]; buf[1] = b[1]; buf[2] = b[2]; buf[3] = b[3]
            }
            return Double(f)
        }

        // fpe2 = 2-byte fixed-point (Intel / older Apple Silicon)
        guard b.count >= 2 else { return nil }
        return fpe2ToDouble(hi: b[0], lo: b[1])
    }

    /// Read a single-byte unsigned int
    func readUInt8(key: String) -> UInt8? {
        guard let b = readBytes(key: key), let first = b.first else { return nil }
        return first
    }

    // MARK: - Write

    /// Write raw bytes to an SMC key. Returns success flag + optional error description.
    @discardableResult
    func writeBytes(key: String, bytes: [UInt8]) -> (Bool, String?) {
        let keyCode = smcFourCharCode(key)
        lock.lock()
        defer { lock.unlock() }

        guard let info = _keyInfo(for: keyCode) else {
            return (false, "Key '\(key)' not found or key-info unavailable")
        }
        guard bytes.count >= Int(info.dataSize) else {
            return (false, "Byte count \(bytes.count) < required \(info.dataSize) for '\(key)'")
        }

        return _writeRaw(keyCode: keyCode, dataSize: info.dataSize, dataType: info.dataType, bytes: bytes, keyName: key)
    }

    /// Write raw bytes to an SMC key with an explicit data size, bypassing the keyInfo
    /// lookup. This is critical for keys like `Ftst` on Apple Silicon where the keyInfo
    /// query itself may return kIOReturnNotPermitted even though the write succeeds.
    @discardableResult
    func writeBytesForced(key: String, bytes: [UInt8], dataSize: UInt32, dataType: UInt32 = 0) -> (Bool, String?) {
        let keyCode = smcFourCharCode(key)
        lock.lock()
        defer { lock.unlock() }
        return _writeRaw(keyCode: keyCode, dataSize: dataSize, dataType: dataType, bytes: bytes, keyName: key)
    }

    /// Internal write that does not require a prior keyInfo lookup.
    private func _writeRaw(keyCode: UInt32, dataSize: UInt32, dataType: UInt32, bytes: [UInt8], keyName: String) -> (Bool, String?) {
        var input = SMCKeyData()
        input.key = keyCode
        input.keyInfo.dataSize = dataSize
        input.keyInfo.dataType = dataType
        input.data8 = UInt8(kSMCWriteKey)

        // Copy bytes into the SMCKeyData bytes tuple
        withUnsafeMutableBytes(of: &input.bytes) { buf in
            for (i, byte) in bytes.enumerated() where i < 32 {
                buf[i] = byte
            }
        }

        var output = SMCKeyData()
        let inputSize = MemoryLayout<SMCKeyData>.stride
        var outputSize = MemoryLayout<SMCKeyData>.stride

        let kr = IOConnectCallStructMethod(connection, kKernelIndexSMC,
                                           &input, inputSize,
                                           &output, &outputSize)
        if kr != kIOReturnSuccess {
            return (false, "IOConnectCallStructMethod failed: 0x\(String(kr, radix: 16)) for '\(keyName)'")
        }
        if output.result != kSMCSuccess {
            return (false, "SMC returned error \(output.result) for key '\(keyName)'")
        }
        return (true, nil)
    }

    /// Write a UInt8 value to a key
    @discardableResult
    func writeUInt8(key: String, value: UInt8) -> (Bool, String?) {
        writeBytes(key: key, bytes: [value])
    }

    /// Write a UInt8 value bypassing keyInfo lookup.
    /// Use for keys where keyInfo returns not-permitted but the write itself succeeds.
    @discardableResult
    func writeUInt8Forced(key: String, value: UInt8) -> (Bool, String?) {
        // ui8 type = "ui8 " = 0x75693820
        writeBytesForced(key: key, bytes: [value], dataSize: 1, dataType: smcFourCharCode("ui8 "))
    }

    /// Write an RPM value, auto-detecting `flt ` vs `fpe2` based on keyInfo.
    @discardableResult
    func writeFpe2(key: String, rpm: Double) -> (Bool, String?) {
        let keyCode = smcFourCharCode(key)
        lock.lock()
        let info = _keyInfo(for: keyCode)
        lock.unlock()

        // flt  = 4-byte native little-endian IEEE 754 float (Apple Silicon M4+)
        if let info = info, info.dataType == smcFourCharCode("flt ") {
            var f = Float(rpm)
            let bytes = withUnsafeBytes(of: &f) { Array($0) }
            return writeBytes(key: key, bytes: bytes)
        }

        // fpe2 = 2-byte fixed-point (Intel / older Apple Silicon)
        let (hi, lo) = doubleToFpe2(rpm)
        return writeBytes(key: key, bytes: [hi, lo])
    }

    /// Write an RPM value bypassing keyInfo lookup, using forced flt  on Apple Silicon.
    @discardableResult
    func writeFpe2Forced(key: String, rpm: Double) -> (Bool, String?) {
        // Try flt  first (Apple Silicon M4+), then fall back to fpe2
        var f = Float(rpm)
        let fltBytes = withUnsafeBytes(of: &f) { Array($0) }
        let (fltOk, fltErr) = writeBytesForced(key: key, bytes: fltBytes, dataSize: 4, dataType: smcFourCharCode("flt "))
        if fltOk { return (true, nil) }

        // Fall back to fpe2
        let (hi, lo) = doubleToFpe2(rpm)
        let (fpeOk, fpeErr) = writeBytesForced(key: key, bytes: [hi, lo], dataSize: 2, dataType: smcFourCharCode("fpe2"))
        if fpeOk { return (true, nil) }

        return (false, "writeFpe2Forced failed for '\(key)': flt=\(fltErr ?? "?"), fpe2=\(fpeErr ?? "?")")
    }
}

// MARK: - FanController

/// High-level fan control operations built on top of SMCWriter.
/// Manages the Ftst unlock state and provides a thermal watchdog.
/// On Apple Silicon Macs (M1+), the `Ftst` key may not exist — fan control
/// gracefully degrades: tries direct `F{n}Md` writes, and reports unsupported
/// if those also fail.
final class FanController {

    private let smc: SMCWriter
    private var isUnlocked = false
    private var watchdogTimer: Timer?
    private var deadmanTimer: DispatchSourceTimer?
    private let deadmanQueue = DispatchQueue(label: "com.macvital.fancontrol.deadman", qos: .utility)
    private let controlQueue = DispatchQueue(label: "com.macvital.fancontrol", qos: .userInitiated)

    /// Cached fan count, populated on first successful SMC read, avoids transient-zero failures.
    private var _cachedFanCount: Int? = nil

    /// Whether the `Ftst` key exists on this Mac.
    /// On Apple Silicon the keyInfo query for Ftst may itself return not-permitted,
    /// so we probe by attempting a forced write of Ftst=0 (safe no-op, auto mode).
    private lazy var hasFtstKey: Bool = {
        // First try the normal keyInfo path (works on Intel)
        if smc.keyInfo(for: smcFourCharCode("Ftst")) != nil {
            smcLog("FanController: Ftst key detected via keyInfo")
            return true
        }
        // On Apple Silicon, keyInfo may fail even though the key exists.
        // Probe with a forced write of Ftst=0 (safe — means "auto / no override").
        let (ok, _) = smc.writeUInt8Forced(key: "Ftst", value: 0)
        if ok {
            smcLog("FanController: Ftst key detected via forced write probe")
        } else {
            smcLog("FanController: Ftst key NOT detected (keyInfo failed, forced write failed)")
        }
        return ok
    }()

    init?(smc: SMCWriter) {
        self.smc = smc
    }

    deinit {
        stopWatchdog()
        stopDeadman()
        resetAllFansSync()
    }

    // MARK: - Deadman Timer

    /// Refresh (or start) the deadman timer. While manual fan mode is active
    /// the helper expects a heartbeat or fan write at least every
    /// `kFanDeadmanTimeout` seconds. If none arrives, it auto-reverts to
    /// thermalmonitord. Call from any successful fan-control method or from
    /// the protocol's `pingHeartbeat`.
    func refreshDeadman() {
        deadmanQueue.sync {
            deadmanTimer?.cancel()
            let t = DispatchSource.makeTimerSource(queue: controlQueue)
            t.schedule(deadline: .now() + kFanDeadmanTimeout)
            t.setEventHandler { [weak self] in
                guard let self = self else { return }
                smcLog("FanController: DEADMAN expired, no heartbeat in \(Int(kFanDeadmanTimeout))s, reverting to auto")
                _ = self.resetAllFans()
            }
            t.resume()
            deadmanTimer = t
        }
    }

    private func stopDeadman() {
        deadmanQueue.sync {
            deadmanTimer?.cancel()
            deadmanTimer = nil
        }
    }

    // MARK: - Fan Count

    /// Returns the number of fans reported by SMC ("FNum").
    /// Retries up to 3× on failure and caches the last successful value so that
    /// a transient SMC read error does not produce a bogus zero (which would make
    /// every subsequent fan-index range check fail with "out of range (0..<0)").
    var fanCount: Int {
        // Return cached value immediately if available
        if let cached = _cachedFanCount, cached > 0 { return cached }
        // Retry up to 3 times — SMC reads can transiently fail on first call
        for _ in 0..<3 {
            if let n = smc.readUInt8(key: "FNum").map(Int.init), n > 0 {
                _cachedFanCount = n
                return n
            }
        }
        // Cache and return fallback so subsequent calls don't keep retrying
        let fallback = max(_cachedFanCount ?? 0, 2)
        _cachedFanCount = fallback
        smcLog("FanController: FNum unreadable — assuming \(fallback) fans")
        return fallback
    }

    // MARK: - Unlock / Lock

    /// Seize fan control from thermalmonitord.
    ///
    /// The unlock sequence (required on both Intel and Apple Silicon):
    /// 1. Write `Ftst=1` to signal thermalmonitord to yield fan ownership
    /// 2. Retry `F0Md=1` at 100ms intervals until it succeeds (up to 10s timeout)
    ///
    /// On Apple Silicon, keyInfo queries may fail for Ftst/F0Md even though writes
    /// succeed, so we use "forced" writes that bypass the keyInfo pre-check.
    ///
    /// Reference: https://github.com/agoodkind/macos-smc-fan
    private func unlock() -> (Bool, String?) {
        if isUnlocked { return (true, nil) }

        if hasFtstKey {
            // Try normal write first, fall back to forced write
            var (ok, err) = smc.writeUInt8(key: "Ftst", value: 1)
            if !ok {
                smcLog("FanController: Ftst=1 normal write failed (\(err ?? "?")), trying forced write")
                (ok, err) = smc.writeUInt8Forced(key: "Ftst", value: 1)
            }
            guard ok else { return (false, "Ftst unlock failed: \(err ?? "unknown")") }
            smcLog("FanController: Ftst=1 written, waiting for thermalmonitord to yield...")

            // Wait for thermalmonitord to yield — poll F0Md writability at 100ms intervals,
            // up to kFtstYieldTimeout (10s). This replaces the old fixed 3s sleep which was
            // often too short on Apple Silicon.
            let deadline = Date().addingTimeInterval(kFtstYieldTimeout)
            var modeWriteOK = false
            while Date() < deadline {
                // Try writing F0Md=1; if it succeeds, thermalmonitord has yielded
                let (mdOK, _) = smc.writeUInt8(key: "F0Md", value: 1)
                if mdOK {
                    modeWriteOK = true
                    // Immediately reset back to 0 so we don't leave it in manual mode
                    // until the caller explicitly requests it
                    smc.writeUInt8(key: "F0Md", value: 0)
                    smcLog("FanController: thermalmonitord yielded (F0Md write succeeded)")
                    break
                }
                // Also try forced write in case keyInfo is the blocker
                let (mdForcedOK, _) = smc.writeUInt8Forced(key: "F0Md", value: 1)
                if mdForcedOK {
                    modeWriteOK = true
                    smc.writeUInt8Forced(key: "F0Md", value: 0)
                    smcLog("FanController: thermalmonitord yielded (F0Md forced write succeeded)")
                    break
                }
                Thread.sleep(forTimeInterval: kFtstRetryInterval)
            }
            if !modeWriteOK {
                smcLog("FanController: WARNING — F0Md probe never succeeded within \(kFtstYieldTimeout)s, proceeding anyway")
            }
        } else {
            smcLog("FanController: Ftst key not present — skipping thermalmonitord handshake")
        }

        isUnlocked = true
        startWatchdog()
        refreshDeadman()
        smcLog("FanController: unlocked (deadman armed for \(Int(kFanDeadmanTimeout))s)")
        return (true, nil)
    }

    /// Release fan control back to thermalmonitord.
    /// On Apple Silicon without `Ftst`, simply marks as locked (thermalmonitord
    /// reclaims automatically once manual mode keys are cleared).
    private func lock() -> (Bool, String?) {
        stopWatchdog()
        stopDeadman()
        if hasFtstKey {
            var (ok, err) = smc.writeUInt8(key: "Ftst", value: 0)
            if !ok {
                (ok, err) = smc.writeUInt8Forced(key: "Ftst", value: 0)
            }
            if ok {
                isUnlocked = false
                smcLog("FanController: Ftst=0, thermalmonitord reclaimed")
            }
            return (ok, err)
        } else {
            isUnlocked = false
            smcLog("FanController: lock released (no Ftst key — thermalmonitord auto-reclaims)")
            return (true, nil)
        }
    }

    // MARK: - Public API

    /// Set a single fan to the given RPM target (clamped to [Mn, Mx] range).
    func setFanSpeed(fanIndex: Int, rpm: Int) -> (Bool, String?) {
        let count = fanCount
        guard fanIndex >= 0, fanIndex < count else {
            return (false, "Fan index \(fanIndex) out of range (0..<\(count))")
        }

        // Hard floor / ceiling, refuse any request that would silently kill
        // cooling or exceed any known consumer Mac fan speed. We do this
        // BEFORE clamping to F{n}Mn/F{n}Mx so a hostile or buggy client
        // cannot work around the floor by spoofing the SMC limits.
        guard rpm >= kFanRPMHardFloor else {
            return (false, "Refusing RPM \(rpm) below hard floor \(kFanRPMHardFloor), could disable cooling")
        }
        guard rpm <= kFanRPMHardCeiling else {
            return (false, "Refusing RPM \(rpm) above hard ceiling \(kFanRPMHardCeiling), exceeds any known Mac fan max")
        }

        // Read hardware limits
        let minRPM = smc.readFpe2(key: "F\(fanIndex)Mn") ?? 2317
        let maxRPM = smc.readFpe2(key: "F\(fanIndex)Mx") ?? 7826
        let target = Double(max(Int(minRPM), min(Int(maxRPM), rpm)))

        // Refresh the deadman, any successful fan write counts as a liveness
        // signal so we do not auto-revert mid-run.
        refreshDeadman()

        smcLog("FanController: setFanSpeed f\(fanIndex) → \(Int(target)) RPM (limits \(Int(minRPM))–\(Int(maxRPM)))")

        // Unlock thermalmonitord if needed
        let (unlocked, unlockErr) = unlock()
        guard unlocked else { return (false, unlockErr) }

        // Set manual mode (F{n}Md = 1)
        // Try normal write first, then forced write, with retries at 100ms intervals
        let mdKey = "F\(fanIndex)Md"
        var modeOK = false
        let deadline = Date().addingTimeInterval(5.0)
        var attempts = 0
        while Date() < deadline {
            attempts += 1
            let (ok, _) = smc.writeUInt8(key: mdKey, value: 1)
            if ok { modeOK = true; break }
            let (okForced, _) = smc.writeUInt8Forced(key: mdKey, value: 1)
            if okForced { modeOK = true; break }
            if attempts <= 3 {
                smcLog("FanController: \(mdKey) write attempt \(attempts) failed, retrying…")
            }
            Thread.sleep(forTimeInterval: kFtstRetryInterval)
        }
        guard modeOK else {
            return (false, "Failed to set manual mode for \(mdKey) after \(attempts) attempts (\(String(format: "%.1f", 5.0))s)")
        }
        smcLog("FanController: \(mdKey) = 1 set after \(attempts) attempt(s)")

        // Write target RPM — try normal then forced
        var (tgOK, tgErr) = smc.writeFpe2(key: "F\(fanIndex)Tg", rpm: target)
        if !tgOK {
            (tgOK, tgErr) = smc.writeFpe2Forced(key: "F\(fanIndex)Tg", rpm: target)
        }
        if tgOK {
            smcLog("FanController: F\(fanIndex)Tg = \(Int(target)) RPM written")
        }
        return (tgOK, tgErr)
    }

    /// Reset a single fan to automatic (write Md=0, then clear Tg to minRPM).
    func resetFan(fanIndex: Int) -> (Bool, String?) {
        let count = fanCount
        guard fanIndex >= 0, fanIndex < count else {
            return (false, "Fan index \(fanIndex) out of range (0..<\(count))")
        }
        smcLog("FanController: resetFan \(fanIndex)")

        let mdKey = "F\(fanIndex)Md"
        var (modeOK, modeErr) = smc.writeUInt8(key: mdKey, value: 0)
        if !modeOK {
            (modeOK, modeErr) = smc.writeUInt8Forced(key: mdKey, value: 0)
        }
        if !modeOK {
            return (false, "\(mdKey) reset failed: \(modeErr ?? "unknown")")
        }
        // Restore Tg to minimum so there's no stale manual target
        let minRPM = smc.readFpe2(key: "F\(fanIndex)Mn") ?? 2317
        let (tgOK, _) = smc.writeFpe2(key: "F\(fanIndex)Tg", rpm: minRPM)
        if !tgOK { smc.writeFpe2Forced(key: "F\(fanIndex)Tg", rpm: minRPM) }

        // If all fans are now auto, release the lock
        var anyManual = false
        for i in 0..<count {
            if let md = smc.readUInt8(key: "F\(i)Md"), md != 0 {
                anyManual = true; break
            }
        }
        if !anyManual { _ = lock() }
        return (true, nil)
    }

    /// Reset all fans and release Ftst lock entirely.
    func resetAllFans() -> (Bool, String?) {
        smcLog("FanController: resetAllFans")
        let count = fanCount
        var errors: [String] = []

        for i in 0..<count {
            let minRPM = smc.readFpe2(key: "F\(i)Mn") ?? 2317
            var (mOK, mErr) = smc.writeUInt8(key: "F\(i)Md", value: 0)
            if !mOK { (mOK, mErr) = smc.writeUInt8Forced(key: "F\(i)Md", value: 0) }
            if !mOK { errors.append("F\(i)Md: \(mErr ?? "?")") }
            let (tOK, _) = smc.writeFpe2(key: "F\(i)Tg", rpm: minRPM)
            if !tOK { smc.writeFpe2Forced(key: "F\(i)Tg", rpm: minRPM) }
        }

        let (lockOK, lockErr) = lock()
        if !lockOK { errors.append("Ftst release: \(lockErr ?? "?")") }

        if errors.isEmpty {
            return (true, nil)
        } else {
            return (false, errors.joined(separator: "; "))
        }
    }

    /// Whether manual fan speed control is available on this hardware.
    /// Returns true if Ftst exists (the unlock mechanism for both Intel and Apple Silicon).
    /// The full unlock sequence (Ftst=1 → retry F0Md=1) is required to actually control fans.
    var isManualControlSupported: Bool {
        hasFtstKey
    }

    /// Directly set F{n}Md without the full unlock sequence (for advanced use).
    func setFanMode(fanIndex: Int, mode: Int) -> (Bool, String?) {
        guard mode == 0 || mode == 1 else {
            return (false, "mode must be 0 (auto) or 1 (manual)")
        }
        if mode == 1 {
            let (unlocked, err) = unlock()
            guard unlocked else { return (false, err) }
            // Manual mode just touched, refresh deadman.
            refreshDeadman()
        }
        let mdKey = "F\(fanIndex)Md"
        var result = smc.writeUInt8(key: mdKey, value: UInt8(mode))
        if !result.0 {
            result = smc.writeUInt8Forced(key: mdKey, value: UInt8(mode))
        }
        if mode == 0 {
            // After setting auto, check if we can release the lock
            let count = fanCount
            var anyManual = false
            for i in 0..<count {
                if let md = smc.readUInt8(key: "F\(i)Md"), md != 0 { anyManual = true; break }
            }
            if !anyManual { _ = lock() }
        }
        return result
    }

    // MARK: - Thermal Watchdog

    private func startWatchdog() {
        stopWatchdog()
        let t = Timer(timeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.controlQueue.async { self?.checkThermalSafety() }
        }
        RunLoop.current.add(t, forMode: .common)
        watchdogTimer = t
        smcLog("FanController: thermal watchdog started (ceiling \(kThermalCeilingCelsius)°C)")
    }

    private func stopWatchdog() {
        watchdogTimer?.invalidate()
        watchdogTimer = nil
    }

    private func checkThermalSafety() {
        // Read a representative set of CPU temperature keys
        let cpuKeys = ["Tp09", "Tp0T", "Tp01", "Tp05", "Tp0D", "Tp0H", "Tc0c"]
        let maxTemp = cpuKeys.compactMap { smc.readTemperature(key: $0) }.max() ?? 0

        if maxTemp >= kThermalCeilingCelsius {
            smcLog("FanController: WATCHDOG — CPU temp \(String(format: "%.1f", maxTemp))°C >= \(kThermalCeilingCelsius)°C. Resetting all fans to auto.")
            let _ = resetAllFans()
        }
    }

    // MARK: - Sync variant for deinit (no throws)

    private func resetAllFansSync() {
        let count = fanCount
        for i in 0..<count {
            let (ok, _) = smc.writeUInt8(key: "F\(i)Md", value: 0)
            if !ok { smc.writeUInt8Forced(key: "F\(i)Md", value: 0) }
        }
        if hasFtstKey {
            let (ok, _) = smc.writeUInt8(key: "Ftst", value: 0)
            if !ok { smc.writeUInt8Forced(key: "Ftst", value: 0) }
        }
    }

    // MARK: - Read helpers for XPC protocol methods

    func readFanData() -> [String: Any] {
        var result: [String: Any] = [:]
        let count = fanCount
        result["fanCount"] = count

        var fansArray: [[String: Any]] = []
        for i in 0..<count {
            var fan: [String: Any] = [:]
            fan["index"]   = i
            fan["actual"]  = Int(smc.readFpe2(key: "F\(i)Ac") ?? 0)
            fan["min"]     = Int(smc.readFpe2(key: "F\(i)Mn") ?? 0)
            fan["max"]     = Int(smc.readFpe2(key: "F\(i)Mx") ?? 0)
            fan["target"]  = Int(smc.readFpe2(key: "F\(i)Tg") ?? 0)
            fan["mode"]    = Int(smc.readUInt8(key: "F\(i)Md") ?? 0)
            fansArray.append(fan)
        }
        result["fans"] = fansArray
        result["ftstActive"] = hasFtstKey ? Int(smc.readUInt8(key: "Ftst") ?? 0) : 0
        result["hasFtstKey"] = hasFtstKey
        result["manualControlSupported"] = isManualControlSupported
        return result
    }
}

// MARK: - Logging

func smcLog(_ message: String) {
    let ts = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
    let line = "[MacVitalHelper \(ts)] \(message)"
    print(line)
    // Force flush — stdout is fully buffered when redirected to a file via launchd,
    // so print() alone doesn't make log lines visible until the buffer is full.
    fflush(stdout)
}

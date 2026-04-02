// MacVital/Services/XPCClientFanControl.swift
// Fan control wrappers extending XPCClient.
// Separated from XPCClient.swift to avoid linter conflicts with the base file.

import Foundation

extension XPCClient {

    // MARK: - Fan Control

    /// Set a fan to manual mode at the given RPM.
    /// The helper clamps to [F{n}Mn, F{n}Mx] and executes the Ftst unlock sequence.
    /// - Returns: (success, errorMessage)
    func setFanSpeed(fanIndex: Int, rpm: Int) async -> (Bool, String?) {
        await withCheckedContinuation { continuation in
            guard let proxy = getProxy() else {
                continuation.resume(returning: (false, "XPC proxy unavailable"))
                return
            }
            proxy.setFanSpeed(fanIndex: fanIndex, rpm: rpm, withReply: { ok, err in
                continuation.resume(returning: (ok, err))
            })
        }
    }

    /// Reset a single fan back to automatic thermalmonitord control.
    /// - Returns: (success, errorMessage)
    func resetFan(fanIndex: Int) async -> (Bool, String?) {
        await withCheckedContinuation { continuation in
            guard let proxy = getProxy() else {
                continuation.resume(returning: (false, "XPC proxy unavailable"))
                return
            }
            proxy.resetFan(fanIndex: fanIndex, withReply: { ok, err in
                continuation.resume(returning: (ok, err))
            })
        }
    }

    /// Reset all fans and release the Ftst lock so thermalmonitord reclaims control.
    /// - Returns: (success, errorMessage)
    func resetAllFans() async -> (Bool, String?) {
        await withCheckedContinuation { continuation in
            guard let proxy = getProxy() else {
                continuation.resume(returning: (false, "XPC proxy unavailable"))
                return
            }
            proxy.resetAllFans(withReply: { ok, err in
                continuation.resume(returning: (ok, err))
            })
        }
    }

    /// Directly set F{n}Md: 0 = auto, 1 = manual.
    /// - Returns: (success, errorMessage)
    func setFanMode(fanIndex: Int, mode: Int) async -> (Bool, String?) {
        await withCheckedContinuation { continuation in
            guard let proxy = getProxy() else {
                continuation.resume(returning: (false, "XPC proxy unavailable"))
                return
            }
            proxy.setFanMode(fanIndex: fanIndex, mode: mode, withReply: { ok, err in
                continuation.resume(returning: (ok, err))
            })
        }
    }

    /// Read a raw SMC key value. For RPM keys returns RPM; for temp keys returns °C.
    /// - Returns: (value, errorMessage)
    func readSMCKey(_ key: String) async -> (Double?, String?) {
        await withCheckedContinuation { continuation in
            guard let proxy = getProxy() else {
                continuation.resume(returning: (nil, "XPC proxy unavailable"))
                return
            }
            proxy.readSMCKey(key, withReply: { number, err in
                continuation.resume(returning: (number?.doubleValue, err))
            })
        }
    }

    /// Read all known temperature sensors from the helper. Returns a dict of [SMCKey: celsius].
    func readAllTemperatures() async -> [String: Double]? {
        await withCheckedContinuation { continuation in
            guard let proxy = getProxy() else {
                continuation.resume(returning: Optional<[String: Double]>.none)
                return
            }
            proxy.readAllTemperatures(withReply: { nsDict, _ in
                continuation.resume(returning: nsDict as? [String: Double])
            })
        }
    }

    /// Read SMC power keys via privileged helper. Returns dict with "system", "cpu", "gpu" watts.
    func fetchPowerData() async -> [String: Double]? {
        await withCheckedContinuation { continuation in
            guard let proxy = getProxy() else {
                continuation.resume(returning: Optional<[String: Double]>.none)
                return
            }
            proxy.getPowerData(withReply: { nsDict, _ in
                continuation.resume(returning: nsDict as? [String: Double])
            })
        }
    }

    /// Read all fan data: index, actual RPM, min/max/target, mode, and Ftst state.
    func readFanData() async -> [String: Any]? {
        await withCheckedContinuation { continuation in
            guard let proxy = getProxy() else {
                continuation.resume(returning: Optional<[String: Any]>.none)
                return
            }
            proxy.readFanData(withReply: { nsDict, _ in
                continuation.resume(returning: nsDict as? [String: Any])
            })
        }
    }

    /// Refresh the helper's deadman timer. Call this every minute or two
    /// while the UI is holding manual fan control. If no heartbeat or fan
    /// write reaches the helper for 5 minutes, the helper auto-reverts to
    /// thermalmonitord (Ftst=0, F{n}Md=0).
    @discardableResult
    func pingHeartbeat() async -> Bool {
        await withCheckedContinuation { continuation in
            guard let proxy = getProxy() else {
                continuation.resume(returning: false)
                return
            }
            proxy.pingHeartbeat(withReply: { ok in
                continuation.resume(returning: ok)
            })
        }
    }
}

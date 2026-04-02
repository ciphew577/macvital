import Foundation

public let macVitalHelperMachServiceName = "com.macvital.helper"

@objc public protocol MacVitalHelperProtocol {
    func getCPUData(reply: @escaping (Data) -> Void)
    func getMemoryData(reply: @escaping (Data) -> Void)
    func getStorageData(reply: @escaping (Data) -> Void)
    func getBatteryData(reply: @escaping (Data) -> Void)
    func getSensorData(reply: @escaping (Data) -> Void)
    func getGPUData(reply: @escaping (Data) -> Void)
    func getNetworkData(reply: @escaping (Data) -> Void)
    func getTopProcesses(limit: Int, reply: @escaping (Data) -> Void)
    func runFullDiagnostic(reply: @escaping (Data) -> Void)

    // Fan control
    func setFanSpeed(fanIndex: Int, rpm: Int, withReply reply: @escaping (Bool, String?) -> Void)
    func resetFan(fanIndex: Int, withReply reply: @escaping (Bool, String?) -> Void)
    func resetAllFans(withReply reply: @escaping (Bool, String?) -> Void)
    func setFanMode(fanIndex: Int, mode: Int, withReply reply: @escaping (Bool, String?) -> Void)
    func readSMCKey(_ key: String, withReply reply: @escaping (NSNumber?, String?) -> Void)
    func readAllTemperatures(withReply reply: @escaping (NSDictionary?, String?) -> Void)
    func readFanData(withReply reply: @escaping (NSDictionary?, String?) -> Void)

    /// Read SMC power keys (PSTR, PCPC, PCPG) via privileged connection.
    /// Returns dictionary with keys "system", "cpu", "gpu" mapped to watts (Double).
    func getPowerData(withReply reply: @escaping (NSDictionary?, String?) -> Void)

    /// Heartbeat ping. Refreshes the deadman timer so the helper does not
    /// auto-revert manual fan mode to auto. Clients that hold manual fan
    /// control should call this every minute or two.
    func pingHeartbeat(withReply reply: @escaping (Bool) -> Void)
}

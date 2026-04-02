import Foundation
import IOKit

/// SMC parameter struct matching the kernel's C layout (80 bytes).
/// The `padding` field after `keyInfo` is required to align subsequent fields
/// to match the C struct that IOKit's IOConnectCallStructMethod expects.
/// Without it the Swift struct is 76 bytes and all fields after keyInfo
/// land at wrong offsets, causing writes to silently fail or corrupt data.
struct SMCKeyData {
    struct Version {
        var major: UInt8 = 0
        var minor: UInt8 = 0
        var build: UInt8 = 0
        var reserved: UInt8 = 0
        var release: UInt16 = 0
    }

    struct PLimitData {
        var version: UInt16 = 0
        var length: UInt16 = 0
        var cpuPLimit: UInt32 = 0
        var gpuPLimit: UInt32 = 0
        var memPLimit: UInt32 = 0
    }

    struct KeyInfo {
        var dataSize: UInt32 = 0
        var dataType: UInt32 = 0
        var dataAttributes: UInt8 = 0
    }

    var key: UInt32 = 0
    var vers = Version()
    var pLimitData = PLimitData()
    var keyInfo = KeyInfo()
    /// Padding for struct alignment when passed to the C/IOKit side.
    /// The C compiler inserts 3 bytes after KeyInfo.dataAttributes (UInt8)
    /// to align the next field; Swift does not, so we add an explicit UInt16
    /// plus the natural 1-byte padding to match the C layout.
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) =
               (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
}

private let SMC_CMD_READ_BYTES: UInt8 = 5
private let SMC_CMD_READ_KEYINFO: UInt8 = 9
private let KERNEL_INDEX_SMC: UInt32 = 2

final class SMCReader {
    private var connection: io_connect_t = 0

    init?() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return nil }
        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        IOObjectRelease(service)
        guard result == kIOReturnSuccess else { return nil }
    }

    deinit {
        if connection != 0 {
            IOServiceClose(connection)
        }
    }

    func readTemperature(key: String) -> Double? {
        // Auto-detect data type: Apple Silicon M4+ uses flt (4-byte float),
        // older Macs use sp78 (signed 8.8 fixed point, 2 bytes)
        let keyInt = stringToFourCharCode(key)
        var infoInput = SMCKeyData()
        infoInput.key = keyInt
        infoInput.data8 = SMC_CMD_READ_KEYINFO
        var infoOutput = SMCKeyData()
        let stride = MemoryLayout<SMCKeyData>.stride
        var outSize = stride

        let infoResult = IOConnectCallStructMethod(connection, KERNEL_INDEX_SMC,
                                                    &infoInput, stride, &infoOutput, &outSize)
        guard infoResult == kIOReturnSuccess, infoOutput.result == 0 else { return nil }

        let dataSize = Int(infoOutput.keyInfo.dataSize)
        let dataType = infoOutput.keyInfo.dataType

        guard let bytes = readSMCBytes(key: key, expectedSize: dataSize) else { return nil }

        // flt  = IEEE 754 float, little-endian, 4 bytes (Apple Silicon M4+)
        if dataType == stringToFourCharCode("flt "), dataSize >= 4 {
            var f: Float = 0
            withUnsafeMutableBytes(of: &f) { buf in
                for (i, b) in bytes.prefix(4).enumerated() { buf[i] = b }
            }
            let temp = Double(f)
            // Sanity check: valid temp range -40 to 150°C
            return (temp > -40 && temp < 150) ? temp : nil
        }

        // sp78 = signed 8.8 fixed point, 2 bytes (Intel / older Apple Silicon)
        guard dataSize >= 2 else { return nil }
        let intValue = (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
        return Double(intValue) / 256.0
    }

    func readFanSpeed(index: Int) -> Int? {
        let key = "F\(index)Ac"
        return readFanRPM(key: key)
    }

    func readFanMin(index: Int) -> Int? {
        let key = "F\(index)Mn"
        return readFanRPM(key: key)
    }

    func readFanMax(index: Int) -> Int? {
        let key = "F\(index)Mx"
        return readFanRPM(key: key)
    }

    /// Read a fan RPM key, auto-detecting the data type.
    /// Apple Silicon M4 Pro uses `flt ` (4-byte native little-endian IEEE 754 float).
    /// Older Macs / Intel use `fpe2` (2-byte fixed-point, value / 4.0).
    private func readFanRPM(key: String) -> Int? {
        // Get key info to determine type and size
        let keyInt = stringToFourCharCode(key)
        var infoInput = SMCKeyData()
        infoInput.key = keyInt
        infoInput.data8 = SMC_CMD_READ_KEYINFO
        var infoOutput = SMCKeyData()
        let stride = MemoryLayout<SMCKeyData>.stride
        var outSize = stride

        let infoResult = IOConnectCallStructMethod(connection, KERNEL_INDEX_SMC,
                                                    &infoInput, stride, &infoOutput, &outSize)
        guard infoResult == kIOReturnSuccess else { return nil }

        let dataSize = Int(infoOutput.keyInfo.dataSize)
        let dataType = infoOutput.keyInfo.dataType

        guard let bytes = readSMCBytes(key: key, expectedSize: dataSize) else { return nil }

        // flt  = 0x666c7420 — IEEE 754 float, native little-endian on Apple Silicon, 4 bytes
        if dataType == stringToFourCharCode("flt "), dataSize == 4 {
            var f: Float = 0
            withUnsafeMutableBytes(of: &f) { buf in
                buf[0] = bytes[0]; buf[1] = bytes[1]; buf[2] = bytes[2]; buf[3] = bytes[3]
            }
            return Int(f)
        }

        // fpe2 = 0x66706532 — fixed-point, 2 bytes, value / 4.0
        let intValue = (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
        return Int(Double(intValue) / 4.0)
    }

    func readFanCount() -> Int? {
        guard let bytes = readSMCBytes(key: "FNum", expectedSize: 1) else { return nil }
        return Int(bytes[0])
    }

    func readVoltage(key: String) -> Double? {
        guard let bytes = readSMCBytes(key: key, expectedSize: 2) else { return nil }
        let intValue = (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
        return Double(intValue) / 16384.0
    }

    func readPower(key: String) -> Double? {
        guard let bytes = readSMCBytes(key: key, expectedSize: 2) else { return nil }
        let intValue = (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
        return Double(intValue) / 256.0
    }

    static let appleSiliconTempKeys: [(key: String, name: String, category: String)] = [
        // ── CPU Core Temperatures (Tp = per-core thermal diodes) ──────────
        // Each core has 3 thermal diode readings (base, mid, peak offsets)
        // Cluster 0 cores
        ("Tp00", "CPU C0 Core 0 T0", "CPU Temperature"),
        ("Tp01", "CPU C0 Core 0 T1", "CPU Temperature"),
        ("Tp02", "CPU C0 Core 0 T2", "CPU Temperature"),
        ("Tp04", "CPU C0 Core 1 T0", "CPU Temperature"),
        ("Tp05", "CPU C0 Core 1 T1", "CPU Temperature"),
        ("Tp06", "CPU C0 Core 1 T2", "CPU Temperature"),
        ("Tp08", "CPU C0 Core 2 T0", "CPU Temperature"),
        ("Tp09", "CPU C0 Core 2 T1", "CPU Temperature"),
        ("Tp0A", "CPU C0 Core 2 T2", "CPU Temperature"),
        ("Tp0C", "CPU C0 Core 3 T0", "CPU Temperature"),
        ("Tp0D", "CPU C0 Core 3 T1", "CPU Temperature"),
        ("Tp0E", "CPU C0 Core 3 T2", "CPU Temperature"),
        ("Tp0G", "CPU C0 Core 4 T0", "CPU Temperature"),
        ("Tp0H", "CPU C0 Core 4 T1", "CPU Temperature"),
        ("Tp0I", "CPU C0 Core 4 T2", "CPU Temperature"),
        ("Tp0K", "CPU C0 Core 5 T0", "CPU Temperature"),
        ("Tp0L", "CPU C0 Core 5 T1", "CPU Temperature"),
        ("Tp0M", "CPU C0 Core 5 T2", "CPU Temperature"),
        ("Tp0O", "CPU C0 Core 6 T0", "CPU Temperature"),
        ("Tp0P", "CPU C0 Core 6 T1", "CPU Temperature"),
        ("Tp0Q", "CPU C0 Core 6 T2", "CPU Temperature"),
        ("Tp0S", "CPU C0 Core 7 T0", "CPU Temperature"),
        ("Tp0T", "CPU C0 Core 7 T1", "CPU Temperature"),
        ("Tp0U", "CPU C0 Core 7 T2", "CPU Temperature"),
        ("Tp0W", "CPU C0 Core 8 T0", "CPU Temperature"),
        ("Tp0X", "CPU C0 Core 8 T1", "CPU Temperature"),
        ("Tp0Y", "CPU C0 Core 8 T2", "CPU Temperature"),
        ("Tp0a", "CPU C0 Core 9 T0", "CPU Temperature"),
        ("Tp0b", "CPU C0 Core 9 T1", "CPU Temperature"),
        ("Tp0c", "CPU C0 Core 9 T2", "CPU Temperature"),
        // Cluster 1 cores
        ("Tp0d", "CPU C1 Core 0 T0", "CPU Temperature"),
        ("Tp0e", "CPU C1 Core 0 T1", "CPU Temperature"),
        ("Tp0f", "CPU C1 Core 0 T2", "CPU Temperature"),
        ("Tp0g", "CPU C1 Core 1 T0", "CPU Temperature"),
        ("Tp0i", "CPU C1 Core 1 T1", "CPU Temperature"),
        ("Tp0k", "CPU C1 Core 1 T2", "CPU Temperature"),
        ("Tp0l", "CPU C1 Core 2 T0", "CPU Temperature"),
        ("Tp0m", "CPU C1 Core 2 T1", "CPU Temperature"),
        ("Tp0n", "CPU C1 Core 2 T2", "CPU Temperature"),
        ("Tp0o", "CPU C1 Core 3 T0", "CPU Temperature"),
        ("Tp0q", "CPU C1 Core 3 T1", "CPU Temperature"),
        ("Tp0t", "CPU C1 Core 3 T2", "CPU Temperature"),
        ("Tp0u", "CPU C1 Core 4 T0", "CPU Temperature"),
        ("Tp0v", "CPU C1 Core 4 T1", "CPU Temperature"),
        ("Tp0w", "CPU C1 Core 4 T2", "CPU Temperature"),
        // Cluster 2 cores
        ("Tp1i", "CPU C2 Core 0 T0", "CPU Temperature"),
        ("Tp1j", "CPU C2 Core 0 T1", "CPU Temperature"),
        ("Tp1k", "CPU C2 Core 0 T2", "CPU Temperature"),
        ("Tp1m", "CPU C2 Core 1 T0", "CPU Temperature"),
        ("Tp1n", "CPU C2 Core 1 T1", "CPU Temperature"),
        ("Tp1o", "CPU C2 Core 1 T2", "CPU Temperature"),
        ("Tp1q", "CPU C2 Core 2 T0", "CPU Temperature"),
        ("Tp1t", "CPU C2 Core 2 T1", "CPU Temperature"),
        ("Tp1u", "CPU C2 Core 2 T2", "CPU Temperature"),
        ("Tp1v", "CPU C2 Core 3 T0", "CPU Temperature"),
        ("Tp1w", "CPU C2 Core 3 T1", "CPU Temperature"),
        ("Tp1x", "CPU C2 Core 3 T2", "CPU Temperature"),
        ("Tp1y", "CPU C2 Core 4 T0", "CPU Temperature"),
        ("Tp1z", "CPU C2 Core 4 T1", "CPU Temperature"),
        ("Tp20", "CPU C2 Core 4 T2", "CPU Temperature"),
        ("Tp21", "CPU C2 Core 5 T0", "CPU Temperature"),
        ("Tp22", "CPU C2 Core 5 T1", "CPU Temperature"),
        ("Tp23", "CPU C2 Core 5 T2", "CPU Temperature"),
        // Cluster 3 cores
        ("Tp24", "CPU C3 Core 0 T0", "CPU Temperature"),
        ("Tp25", "CPU C3 Core 0 T1", "CPU Temperature"),
        ("Tp26", "CPU C3 Core 0 T2", "CPU Temperature"),
        ("Tp27", "CPU C3 Core 1 T0", "CPU Temperature"),
        ("Tp28", "CPU C3 Core 1 T1", "CPU Temperature"),
        ("Tp29", "CPU C3 Core 1 T2", "CPU Temperature"),
        ("Tp2A", "CPU C3 Core 2 T0", "CPU Temperature"),
        ("Tp2B", "CPU C3 Core 2 T1", "CPU Temperature"),
        ("Tp2C", "CPU C3 Core 2 T2", "CPU Temperature"),
        ("Tp2D", "CPU C3 Core 3 T0", "CPU Temperature"),
        ("Tp2E", "CPU C3 Core 3 T1", "CPU Temperature"),
        ("Tp2G", "CPU C3 Core 3 T2", "CPU Temperature"),
        ("Tp2I", "CPU C3 Core 4 T0", "CPU Temperature"),
        ("Tp2J", "CPU C3 Core 4 T1", "CPU Temperature"),
        ("Tp2K", "CPU C3 Core 4 T2", "CPU Temperature"),
        ("Tp2L", "CPU C3 Core 5 T0", "CPU Temperature"),
        ("Tp2M", "CPU C3 Core 5 T1", "CPU Temperature"),
        ("Tp2N", "CPU C3 Core 5 T2", "CPU Temperature"),
        ("Tp2O", "CPU C3 Core 6 T0", "CPU Temperature"),
        ("Tp2Q", "CPU C3 Core 6 T1", "CPU Temperature"),
        ("Tp2R", "CPU C3 Core 6 T2", "CPU Temperature"),
        ("Tp2S", "CPU C3 Core 7 T0", "CPU Temperature"),
        ("Tp2T", "CPU C3 Core 7 T1", "CPU Temperature"),
        ("Tp2U", "CPU C3 Core 7 T2", "CPU Temperature"),
        ("Tp2V", "CPU C3 Core 8 T0", "CPU Temperature"),
        ("Tp2W", "CPU C3 Core 8 T1", "CPU Temperature"),
        ("Tp2X", "CPU C3 Core 8 T2", "CPU Temperature"),
        // CPU peak / aggregate keys
        ("Tpx0", "CPU Peak Cluster 0 Die 0", "CPU Temperature"),
        ("Tpx1", "CPU Peak Cluster 0 Die 1", "CPU Temperature"),
        ("Tpx2", "CPU Peak Cluster 1 Die 0", "CPU Temperature"),
        ("Tpx3", "CPU Peak Cluster 1 Die 1", "CPU Temperature"),
        ("Tpx4", "CPU Peak Cluster 2 Die 0", "CPU Temperature"),
        ("Tpx5", "CPU Peak Cluster 2 Die 1", "CPU Temperature"),
        ("Tpx8", "CPU Peak Cluster 3 Die 0", "CPU Temperature"),
        ("Tpx9", "CPU Peak Cluster 3 Die 1", "CPU Temperature"),
        ("TpxA", "CPU Peak Cluster 3 Die 2", "CPU Temperature"),
        ("TpxB", "CPU Peak Cluster 3 Die 3", "CPU Temperature"),
        ("TpxC", "CPU Peak Cluster 3 Die 4", "CPU Temperature"),
        ("TpxD", "CPU Peak Cluster 3 Die 5", "CPU Temperature"),
        // CPU efficiency core extended (Te = efficiency cluster thermals)
        ("Te04", "CPU E-Cluster Temp 0", "CPU Temperature"),
        ("Te05", "CPU E-Cluster Temp 1", "CPU Temperature"),
        ("Te06", "CPU E-Cluster Temp 2", "CPU Temperature"),
        ("Te0R", "CPU E-Cluster Ring 0", "CPU Temperature"),
        ("Te0S", "CPU E-Cluster Ring 1", "CPU Temperature"),
        ("Te0T", "CPU E-Cluster Ring 2", "CPU Temperature"),
        ("Tex0", "CPU E-Cluster Peak 0", "CPU Temperature"),
        ("Tex1", "CPU E-Cluster Peak 1", "CPU Temperature"),
        ("Tex2", "CPU E-Cluster Peak 2", "CPU Temperature"),
        ("Tex3", "CPU E-Cluster Peak 3", "CPU Temperature"),
        // CPU package / hotspot (TC = CPU complex aggregate)
        ("TCHP", "CPU Hotspot", "CPU Temperature"),
        ("TCMb", "CPU Complex Max Base", "CPU Temperature"),
        ("TCMz", "CPU Complex Max Peak", "CPU Temperature"),
        // Legacy Intel / some Apple Silicon
        ("Tc0p", "CPU Proximity", "CPU Temperature"),
        ("Tc0c", "CPU Core Average", "CPU Temperature"),
        // CPU fabric / interconnect (TfC = fabric controller)
        ("TfC0", "CPU Fabric Controller 0", "CPU Temperature"),
        ("TfC1", "CPU Fabric Controller 1", "CPU Temperature"),
        ("TfC2", "CPU Fabric Controller 2", "CPU Temperature"),
        ("TfC3", "CPU Fabric Controller 3", "CPU Temperature"),
        ("TfC4", "CPU Fabric Controller 4", "CPU Temperature"),

        // ── GPU Temperatures (Tg = GPU cores, TG = GPU aggregate) ─────────
        ("Tg04", "GPU Core Temp 0", "GPU Temperature"),
        ("Tg05", "GPU Core Temp 1", "GPU Temperature"),
        ("Tg0K", "GPU Cluster 0 Die 0", "GPU Temperature"),
        ("Tg0L", "GPU Cluster 0 Die 1", "GPU Temperature"),
        ("Tg0R", "GPU Cluster 0 Ring 0", "GPU Temperature"),
        ("Tg0S", "GPU Cluster 0 Ring 1", "GPU Temperature"),
        ("Tg0X", "GPU Cluster 0 Peak 0", "GPU Temperature"),
        ("Tg0Y", "GPU Cluster 0 Peak 1", "GPU Temperature"),
        ("Tg0d", "GPU Cluster 0 Core 0", "GPU Temperature"),
        ("Tg0e", "GPU Cluster 0 Core 1", "GPU Temperature"),
        ("Tg0j", "GPU Cluster 0 Junction 0", "GPU Temperature"),
        ("Tg0k", "GPU Cluster 0 Junction 1", "GPU Temperature"),
        ("Tg0y", "GPU Cluster 0 Hot 0", "GPU Temperature"),
        ("Tg0z", "GPU Cluster 0 Hot 1", "GPU Temperature"),
        ("Tg1E", "GPU Cluster 1 Die 0", "GPU Temperature"),
        ("Tg1F", "GPU Cluster 1 Die 1", "GPU Temperature"),
        ("Tg1U", "GPU Cluster 1 Peak 0", "GPU Temperature"),
        ("Tg1V", "GPU Cluster 1 Peak 1", "GPU Temperature"),
        ("Tg1c", "GPU Cluster 1 Core 0", "GPU Temperature"),
        ("Tg1d", "GPU Cluster 1 Core 1", "GPU Temperature"),
        ("Tg1k", "GPU Cluster 1 Junction 0", "GPU Temperature"),
        ("Tg1l", "GPU Cluster 1 Junction 1", "GPU Temperature"),
        // Legacy Intel / some AS
        ("Tg0p", "GPU Proximity", "GPU Temperature"),
        ("Tg0f", "GPU Die (Legacy)", "GPU Temperature"),

        // ── SoC Die Temperatures (TD = die sensors) ───────────────────────
        ("TD00", "SoC Die 0 Sensor 0", "CPU Temperature"),
        ("TD01", "SoC Die 0 Sensor 1", "CPU Temperature"),
        ("TD02", "SoC Die 0 Sensor 2", "CPU Temperature"),
        ("TD03", "SoC Die 0 Sensor 3", "CPU Temperature"),
        ("TD04", "SoC Die 0 Sensor 4", "CPU Temperature"),
        ("TD10", "SoC Die 1 Sensor 0", "CPU Temperature"),
        ("TD11", "SoC Die 1 Sensor 1", "CPU Temperature"),
        ("TD12", "SoC Die 1 Sensor 2", "CPU Temperature"),
        ("TD13", "SoC Die 1 Sensor 3", "CPU Temperature"),
        ("TD14", "SoC Die 1 Sensor 4", "CPU Temperature"),
        ("TD20", "SoC Die 2 Sensor 0", "CPU Temperature"),
        ("TD21", "SoC Die 2 Sensor 1", "CPU Temperature"),
        ("TD22", "SoC Die 2 Sensor 2", "CPU Temperature"),
        ("TD23", "SoC Die 2 Sensor 3", "CPU Temperature"),
        ("TD24", "SoC Die 2 Sensor 4", "CPU Temperature"),
        ("TDBP", "SoC Die Backplane", "CPU Temperature"),
        ("TDEL", "SoC Die Edge Left", "CPU Temperature"),
        ("TDER", "SoC Die Edge Right", "CPU Temperature"),
        ("TDTC", "SoC Die Thermal Center", "CPU Temperature"),
        ("TDTP", "SoC Die Thermal Peak", "CPU Temperature"),
        ("TDVx", "SoC Die Voltage Max", "CPU Temperature"),
        ("TDeL", "SoC Die External Left", "CPU Temperature"),
        ("TDeR", "SoC Die External Right", "CPU Temperature"),

        // ── Power Die / DRAM Temperatures (TPD/TRD/TUD = power/ram dies) ──
        ("TPD0", "Power Die 0", "Other"),
        ("TPD1", "Power Die 1", "Other"),
        ("TPD2", "Power Die 2", "Other"),
        ("TPD3", "Power Die 3", "Other"),
        ("TPD4", "Power Die 4", "Other"),
        ("TPD5", "Power Die 5", "Other"),
        ("TPD6", "Power Die 6", "Other"),
        ("TPD7", "Power Die 7", "Other"),
        ("TPD8", "Power Die 8", "Other"),
        ("TPD9", "Power Die 9", "Other"),
        ("TPDX", "Power Die Max", "Other"),
        ("TPDa", "Power Die A", "Other"),
        ("TPDb", "Power Die B", "Other"),
        ("TPDc", "Power Die C", "Other"),
        ("TPDd", "Power Die D", "Other"),
        ("TPDe", "Power Die E", "Other"),
        ("TPDf", "Power Die F", "Other"),
        ("TPMP", "Power Management Peak", "Other"),
        ("TPSP", "Power Supply Peak", "Other"),
        ("TRD0", "DRAM Die 0", "Other"),
        ("TRD1", "DRAM Die 1", "Other"),
        ("TRD2", "DRAM Die 2", "Other"),
        ("TRD3", "DRAM Die 3", "Other"),
        ("TRD4", "DRAM Die 4", "Other"),
        ("TRD5", "DRAM Die 5", "Other"),
        ("TRD6", "DRAM Die 6", "Other"),
        ("TRD7", "DRAM Die 7", "Other"),
        ("TRD8", "DRAM Die 8", "Other"),
        ("TRD9", "DRAM Die 9", "Other"),
        ("TRDX", "DRAM Die Max", "Other"),
        ("TRDa", "DRAM Die A", "Other"),
        ("TRDb", "DRAM Die B", "Other"),
        ("TRDc", "DRAM Die C", "Other"),
        ("TRDd", "DRAM Die D", "Other"),
        ("TRDe", "DRAM Die E", "Other"),
        ("TRDf", "DRAM Die F", "Other"),
        ("TUD0", "Unified Memory Die 0", "Other"),
        ("TUD1", "Unified Memory Die 1", "Other"),
        ("TUD2", "Unified Memory Die 2", "Other"),
        ("TUD3", "Unified Memory Die 3", "Other"),
        ("TUD4", "Unified Memory Die 4", "Other"),
        ("TUD5", "Unified Memory Die 5", "Other"),
        ("TUD6", "Unified Memory Die 6", "Other"),
        ("TUD7", "Unified Memory Die 7", "Other"),
        ("TUD8", "Unified Memory Die 8", "Other"),
        ("TUD9", "Unified Memory Die 9", "Other"),
        ("TUDX", "Unified Memory Die Max", "Other"),
        ("TUDa", "Unified Memory Die A", "Other"),
        ("TUDb", "Unified Memory Die B", "Other"),
        ("TUDc", "Unified Memory Die C", "Other"),
        ("TUDd", "Unified Memory Die D", "Other"),
        ("TUDe", "Unified Memory Die E", "Other"),
        ("TUDf", "Unified Memory Die F", "Other"),

        // ── Video / Media Engine (TV = video/media) ───────────────────────
        ("TVA0", "Video Accelerator Ambient", "Other"),
        ("TVD0", "Video Decoder Die", "Other"),
        ("TVMR", "Video Media Ring", "Other"),
        ("TVMX", "Video Media Max", "Other"),
        ("TVMr", "Video Media Ring Alt", "Other"),
        ("TVMx", "Video Media Max Alt", "Other"),
        ("TVS0", "Video Scaler 0", "Other"),
        ("TVS1", "Video Scaler 1", "Other"),
        ("TVS2", "Video Scaler 2", "Other"),
        ("TVS3", "Video Scaler 3", "Other"),
        ("TVV0", "Video VPU 0", "Other"),
        ("TVXX", "Video Engine Max", "Other"),
        ("TVXh", "Video Engine Hotspot", "Other"),
        ("TVXm", "Video Engine Mid", "Other"),
        ("TVh0", "Video Hotspot 0", "Other"),
        ("TVh1", "Video Hotspot 1", "Other"),
        ("TVmS", "Video Memory Subsystem", "Other"),
        ("TVms", "Video Memory Speed", "Other"),
        ("TVxx", "Video Engine Max Alt", "Other"),

        // ── System / SoC Aggregate (TS = system) ──────────────────────────
        ("TS0P", "System SoC Peak", "CPU Temperature"),
        ("TSCP", "System SoC Complex Peak", "CPU Temperature"),
        ("TSG1", "System SoC GPU 1", "GPU Temperature"),
        ("TSG2", "System SoC GPU 2", "GPU Temperature"),
        ("TMVR", "Memory VR (Voltage Regulator)", "Other"),

        // ── NVMe / SSD (TH = hard drive / NVMe) ──────────────────────────
        ("TH0a", "SSD Controller 1", "Drive Temperature"),
        ("TH0b", "SSD Controller 2", "Drive Temperature"),
        ("TH0x", "SSD Max", "Drive Temperature"),
        ("Tn0p", "SSD Proximity", "Drive Temperature"),

        // ── Battery (TB = battery) ────────────────────────────────────────
        ("TB0T", "Battery TS_MAX", "Battery Temperature"),
        ("TB1T", "Battery Cell 1", "Battery Temperature"),
        ("TB2T", "Battery Cell 2", "Battery Temperature"),

        // ── Skin / Surface (Ts = skin, palm rest, chassis) ────────────────
        ("Ts0P", "Palm Rest Left", "Skin Temperature"),
        ("Ts1P", "Palm Rest Right", "Skin Temperature"),
        // Ts## = SoC surface/skin sensors (per-cluster thermal skin readout)
        ("Ts00", "Skin SoC Cluster 0 T0", "Skin Temperature"),
        ("Ts01", "Skin SoC Cluster 0 T1", "Skin Temperature"),
        ("Ts02", "Skin SoC Cluster 0 T2", "Skin Temperature"),
        ("Ts04", "Skin SoC Cluster 1 T0", "Skin Temperature"),
        ("Ts05", "Skin SoC Cluster 1 T1", "Skin Temperature"),
        ("Ts06", "Skin SoC Cluster 1 T2", "Skin Temperature"),
        ("Ts08", "Skin SoC Cluster 2 T0", "Skin Temperature"),
        ("Ts09", "Skin SoC Cluster 2 T1", "Skin Temperature"),
        ("Ts0A", "Skin SoC Cluster 2 T2", "Skin Temperature"),
        ("Ts0C", "Skin SoC Cluster 3 T0", "Skin Temperature"),
        ("Ts0D", "Skin SoC Cluster 3 T1", "Skin Temperature"),
        ("Ts0E", "Skin SoC Cluster 3 T2", "Skin Temperature"),
        ("Ts0G", "Skin SoC GPU 0 T0", "Skin Temperature"),
        ("Ts0H", "Skin SoC GPU 0 T1", "Skin Temperature"),
        ("Ts0I", "Skin SoC GPU 0 T2", "Skin Temperature"),
        ("Ts0K", "Skin SoC GPU 1 T0", "Skin Temperature"),
        ("Ts0L", "Skin SoC GPU 1 T1", "Skin Temperature"),
        ("Ts0M", "Skin SoC GPU 1 T2", "Skin Temperature"),
        ("Ts0O", "Skin SoC Media 0 T0", "Skin Temperature"),
        ("Ts0Q", "Skin SoC Media 0 T1", "Skin Temperature"),
        ("Ts0R", "Skin SoC Media 0 T2", "Skin Temperature"),
        ("Ts0T", "Skin SoC Media 1 T0", "Skin Temperature"),
        ("Ts0U", "Skin SoC Media 1 T1", "Skin Temperature"),
        ("Ts0W", "Skin SoC Media 1 T2", "Skin Temperature"),
        ("Tsx0", "Skin SoC Peak 0", "Skin Temperature"),
        ("Tsx1", "Skin SoC Peak 1", "Skin Temperature"),

        // ── Ambient / Airflow (Ta = ambient, TAOL = ambient overall) ──────
        ("TAOL", "Ambient Overall", "Ambient Temperature"),
        ("Ta0P", "Ambient Pressure", "Ambient Temperature"),
        ("Ta01", "Ambient Sensor 1", "Ambient Temperature"),
        ("Ta05", "Ambient Sensor 5", "Ambient Temperature"),
        ("Ta09", "Ambient Sensor 9", "Ambient Temperature"),
        ("Ta0L", "Ambient Left", "Ambient Temperature"),
        ("Ta0S", "Ambient South", "Ambient Temperature"),
        ("TaLP", "Airflow Left Proximity", "Ambient Temperature"),
        ("TaLT", "Airflow Left Top", "Ambient Temperature"),
        ("TaLW", "Airflow Left Wall", "Ambient Temperature"),
        ("TaRF", "Airflow Right Front", "Ambient Temperature"),
        ("TaRT", "Airflow Right Top", "Ambient Temperature"),
        ("TaRW", "Airflow Right Wall", "Ambient Temperature"),
        ("TaTP", "Airflow Top Peak", "Ambient Temperature"),

        // ── WiFi (TW = wireless) ──────────────────────────────────────────
        ("TW0P", "WiFi Module", "Ambient Temperature"),

        // ── Memory (Tm = memory proximity) ────────────────────────────────
        ("Tm0p", "Memory Proximity", "Other"),

        // ── Heatpipe / Thermal (Th = heatpipe) ───────────────────────────
        ("Th0H", "Heatpipe", "Other"),
    ]

    private func readSMCBytes(key: String, expectedSize: Int) -> [UInt8]? {
        let keyInt = stringToFourCharCode(key)

        var inputStruct = SMCKeyData()
        inputStruct.key = keyInt
        inputStruct.data8 = SMC_CMD_READ_KEYINFO

        var outputStruct = SMCKeyData()
        let inputSize = MemoryLayout<SMCKeyData>.stride
        var outputSize = MemoryLayout<SMCKeyData>.stride

        var result = IOConnectCallStructMethod(connection, KERNEL_INDEX_SMC, &inputStruct, inputSize, &outputStruct, &outputSize)
        guard result == kIOReturnSuccess else { return nil }

        inputStruct = SMCKeyData()
        inputStruct.key = keyInt
        inputStruct.keyInfo.dataSize = outputStruct.keyInfo.dataSize
        inputStruct.data8 = SMC_CMD_READ_BYTES

        outputStruct = SMCKeyData()
        outputSize = MemoryLayout<SMCKeyData>.stride

        result = IOConnectCallStructMethod(connection, KERNEL_INDEX_SMC, &inputStruct, inputSize, &outputStruct, &outputSize)
        guard result == kIOReturnSuccess else { return nil }

        return withUnsafeBytes(of: outputStruct.bytes) { buf in
            Array(buf.prefix(expectedSize))
        }
    }

    // MARK: - Write (for fan control from app process — has GUI session IOKit access)

    private let SMC_CMD_WRITE_BYTES: UInt8 = 6

    /// Write raw bytes to an SMC key. Returns true on success.
    func writeSMCBytes(key: String, bytes: [UInt8]) -> Bool {
        let keyInt = stringToFourCharCode(key)

        // First get key info (data size + type)
        var infoInput = SMCKeyData()
        infoInput.key = keyInt
        infoInput.data8 = SMC_CMD_READ_KEYINFO
        var infoOutput = SMCKeyData()
        let stride = MemoryLayout<SMCKeyData>.stride
        var outSize = stride

        let infoResult = IOConnectCallStructMethod(connection, KERNEL_INDEX_SMC,
                                                    &infoInput, stride, &infoOutput, &outSize)
        guard infoResult == kIOReturnSuccess else {
            print("SMCReader: keyInfo failed for '\(key)' — kr=\(infoResult)")
            return false
        }

        // Now write
        var writeInput = SMCKeyData()
        writeInput.key = keyInt
        writeInput.keyInfo.dataSize = infoOutput.keyInfo.dataSize
        writeInput.data8 = SMC_CMD_WRITE_BYTES

        withUnsafeMutableBytes(of: &writeInput.bytes) { buf in
            for (i, b) in bytes.enumerated() where i < 32 {
                buf[i] = b
            }
        }

        var writeOutput = SMCKeyData()
        outSize = stride
        let writeResult = IOConnectCallStructMethod(connection, KERNEL_INDEX_SMC,
                                                     &writeInput, stride, &writeOutput, &outSize)
        if writeResult != kIOReturnSuccess {
            print("SMCReader: write failed for '\(key)' — kr=\(writeResult)")
            return false
        }
        return true
    }

    /// Write a single byte to an SMC key
    func writeUInt8(key: String, value: UInt8) -> Bool {
        writeSMCBytes(key: key, bytes: [value])
    }

    /// Write an RPM value to a fan key, auto-detecting the data type (flt  vs fpe2).
    func writeRPM(key: String, rpm: Double) -> Bool {
        let keyInt = stringToFourCharCode(key)

        // Get key info to determine type
        var infoInput = SMCKeyData()
        infoInput.key = keyInt
        infoInput.data8 = SMC_CMD_READ_KEYINFO
        var infoOutput = SMCKeyData()
        let stride = MemoryLayout<SMCKeyData>.stride
        var outSize = stride

        let infoResult = IOConnectCallStructMethod(connection, KERNEL_INDEX_SMC,
                                                    &infoInput, stride, &infoOutput, &outSize)
        let dataType = infoResult == kIOReturnSuccess ? infoOutput.keyInfo.dataType : 0

        // flt  = IEEE 754 float, native little-endian on Apple Silicon, 4 bytes
        if dataType == stringToFourCharCode("flt ") {
            var f = Float(rpm)
            let bytes = withUnsafeBytes(of: &f) { Array($0) }
            return writeSMCBytes(key: key, bytes: bytes)
        }

        // fpe2 = fixed-point, 2 bytes (Intel / older Apple Silicon)
        let raw = UInt16(max(0, rpm) * 4.0)
        return writeSMCBytes(key: key, bytes: [UInt8(raw >> 8), UInt8(raw & 0xFF)])
    }

    /// Set fan to manual mode and target RPM. Call from app process (has IOKit GUI session access).
    func setFanSpeed(index: Int, rpm: Int) -> (Bool, String?) {
        print("[SMC] setFanSpeed: fan=\(index) rpm=\(rpm)")

        // Try writing Ftst=1 to unlock thermalmonitord
        let ftst = writeUInt8(key: "Ftst", value: 1)
        print("[SMC]   Ftst=1 write: \(ftst ? "OK" : "FAILED")")
        if ftst {
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Set manual mode
        let mdOk = writeUInt8(key: "F\(index)Md", value: 1)
        print("[SMC]   F\(index)Md=1 write: \(mdOk ? "OK" : "FAILED")")
        if !mdOk {
            return (false, "F\(index)Md write failed")
        }

        // Set target RPM (auto-detects flt  vs fpe2)
        let tgOk = writeRPM(key: "F\(index)Tg", rpm: Double(rpm))
        print("[SMC]   F\(index)Tg=\(rpm) write: \(tgOk ? "OK" : "FAILED")")
        if !tgOk {
            return (false, "F\(index)Tg write failed")
        }

        // Read back actual RPM to verify
        if let actual = readFanSpeed(index: index) {
            print("[SMC]   Readback: F\(index)Ac = \(actual) RPM")
        }

        return (true, "Fan \(index + 1) → \(rpm) RPM")
    }

    /// Reset fan to automatic control
    func resetFan(index: Int) -> (Bool, String?) {
        let _ = writeUInt8(key: "F\(index)Md", value: 0)
        let _ = writeUInt8(key: "Ftst", value: 0)
        return (true, nil)
    }

    /// Reset all fans to auto
    func resetAllFans() -> (Bool, String?) {
        guard let count = readFanCount() else { return (false, "Can't read fan count") }
        for i in 0..<count {
            let _ = writeUInt8(key: "F\(i)Md", value: 0)
        }
        let _ = writeUInt8(key: "Ftst", value: 0)
        return (true, "All fans reset to auto")
    }

    private func stringToFourCharCode(_ str: String) -> UInt32 {
        var result: UInt32 = 0
        for (i, char) in str.utf8.enumerated() {
            guard i < 4 else { break }
            result |= UInt32(char) << (24 - i * 8)
        }
        return result
    }
}

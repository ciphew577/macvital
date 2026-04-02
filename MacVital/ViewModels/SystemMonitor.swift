// MacVital/ViewModels/SystemMonitor.swift
import Foundation

@Observable
final class SystemMonitor {
    // Data models
    var cpu: CPUData?
    var memory: MemoryData?
    var storage: StorageData?
    var battery: BatteryData?
    var sensors: SensorData?
    var gpu: GPUData?
    var network: NetworkData?
    var diagnosticReport: DiagnosticReport?

    // SMC power readings (Watts)
    var cpuPower: Double = 0   // PCPC/PCPT — CPU package power
    var gpuPower: Double = 0   // PCPG/PGTR — GPU package power
    var socPower: Double = 0   // PSTR — total SoC/system power

    // Per-component SMC power readings (from helper, 0 if key unavailable)
    var anePowerSMC: Double = 0       // PANT — Neural Engine
    var dramPowerSMC: Double = 0      // PMVC/PMEM — DRAM
    var fabricPowerSMC: Double = 0    // PDCS — Fabric / AMCC
    var displayPowerSMC: Double = 0   // (unused legacy, see backlightPowerSMC)
    var pciePowerSMC: Double = 0      // PPBR — PCIe / Thunderbolt
    var mediaPowerSMC: Double = 0     // PMED — Media engine
    var ispPowerSMC: Double = 0       // PISP — ISP (camera)
    var gpuSramPowerSMC: Double = 0   // PSRA — GPU SRAM

    // New per-component SMC readings discovered via full key enumeration
    var deliveryPowerSMC: Double = 0  // PDTR — Total power delivery rail (wall power)
    var eClusterPowerSMC: Double = 0  // PZC0 — E-cluster real power
    var pClusterPowerSMC: Double = 0  // PZC1 — P-cluster real power
    var uncorePowerSMC: Double = 0    // PZCU — Uncore power
    var pmuPowerSMC: Double = 0       // PPMC — PMU controller
    var psCtrlPowerSMC: Double = 0    // PPSC — Power supply controller
    var thermalPowerSMC: Double = 0   // PTHS — Thermal subsystem
    var backlightPowerSMC: Double = 0 // PDBR — Display backlight rail (real)
    var rail5vPowerSMC: Double = 0    // P5SR — 5V switched rail
    var rail3vPowerSMC: Double = 0    // P3F2 — 3.3V rail
    var usb1PowerSMC: Double = 0      // PU1C — USB-C port 1
    var usb2PowerSMC: Double = 0      // PU2C — USB-C port 2
    var hiperfSustPowerSMC: Double = 0 // PHPS — High-perf sustained
    var hiperfBudgetSMC: Double = 0   // PHPB — High-perf power budget

    // Power history for sparkline/chart (last 60 readings @ 5s medium timer)
    var powerHistory: [Double] = []

    // State
    var isConnected = true // Direct reads, always connected
    var isRunningDiagnostic = false
    var diagnosticProgress: String = ""

    // History for sparklines (last 60 readings)
    var cpuHistory: [Double] = []
    var memoryHistory: [Double] = []
    var networkUpHistory: [UInt64] = []
    var networkDownHistory: [UInt64] = []

    // Persistent network usage — survives relaunch AND reboot.
    // Published snapshots are refreshed on every fast-timer tick.
    var networkTotals: [NetworkInterfaceTotals] = []
    var networkUsageSummaries: [NetworkUsageSummary] = []

    /// Shared persistent store. Exposed so other components (menu bar,
    /// per-interface attribution agent, reports) can read it directly.
    let networkUsageStore = NetworkUsageStore.shared

    /// Per-SSID lifetime usage tracker. Injected by AppState. Accumulates
    /// bytes against the currently joined Wi-Fi SSID; never auto-resets.
    weak var perSSIDUsageStore: PerSSIDUsageStore?

    /// Last kernel counter seen for each BSD interface name. Used to compute
    /// per-tick deltas for the SSID store. Keyed by BSD name because SSIDs can
    /// change mid-session while the interface stays up.
    private var lastSSIDKernelCounters: [String: (rx: UInt64, tx: UInt64)] = [:]

    // GPU rolling history (120 readings @ 5s = 600s = 10min window; view trims to 120s)
    var gpuUtilHistory: [Double] = []
    var gpuRenderHistory: [Double] = []
    var gpuTilerHistory: [Double] = []
    var gpuComputeHistory: [Double] = []
    var gpuReadBWHistory: [UInt64] = []
    var gpuWriteBWHistory: [UInt64] = []

    let alertEngine = AlertEngine()

    // Processes tab data
    var processesData: ProcessesData = ProcessesData()

    // XPC client for privileged SMC power reads (set by AppState after connect)
    var xpcClient: XPCClient?

    // Direct readers (no XPC needed for non-sandboxed app)
    // smcReader is internal so FansView can use it for fan control writes
    let smcReader = SMCReader()
    private let cpuReader = CPUReader()
    private let memoryReader = MemoryReader()
    private let storageReader = StorageReader()
    private let batteryReader = BatteryReader()
    private let gpuReader = GPUReader()
    private let networkReader = NetworkReader()
    private let processReader = ProcessReader()
    private let fullProcessReader = FullProcessReader()
    let processNetworkReader = ProcessNetworkReader()

    private var fastTimer: Timer?   // 2s — CPU, network
    private var medTimer: Timer?    // 5s — memory, GPU, sensors
    private var slowTimer: Timer?   // 30s — battery, storage

    private let historyLimit = 60

    /// Serial background queue for all reader I/O — keeps main thread free
    private let readerQueue = DispatchQueue(label: "com.macvital.readers", qos: .userInitiated)

    @MainActor
    func start() {
        // Invalidate any existing timers to prevent duplicate polling
        stop()

        // Fast polling: CPU + Network (every 2s)
        fastTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.fetchFast()
        }
        // Medium polling: Memory + GPU + Sensors (every 5s)
        medTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.fetchMedium()
        }
        // Slow polling: Battery + Storage (every 30s)
        slowTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.fetchSlow()
        }

        // Start per-process network polling (5s interval on its own queue)
        processNetworkReader.start()

        // Initial fetch — all on background queue
        fetchFast()
        fetchMedium()
        fetchSlow()
    }

    @MainActor
    func stop() {
        fastTimer?.invalidate()
        medTimer?.invalidate()
        slowTimer?.invalidate()
        processNetworkReader.stop()
        // Make sure any buffered per-minute samples land on disk before quit.
        networkUsageStore.flush()
        perSSIDUsageStore?.flush()
    }

    func runDiagnostic() async -> DiagnosticReport? {
        isRunningDiagnostic = true
        diagnosticProgress = "Reading CPU..."

        let cpuData = cpuReader.read(smc: smcReader)
        diagnosticProgress = "Reading Memory..."
        let memData = memoryReader.read()
        diagnosticProgress = "Reading Storage & SMART..."
        let storeData = storageReader.read()
        diagnosticProgress = "Reading Battery..."
        let batData = batteryReader.read()
        diagnosticProgress = "Reading Sensors..."
        let sensorData = readSensors()
        diagnosticProgress = "Reading GPU..."
        let gpuData = gpuReader.read(smc: smcReader)
        diagnosticProgress = "Reading Network..."
        let netData = networkReader.read()
        diagnosticProgress = "Computing health scores..."

        // Health scores
        let storageScore = storeData.healthPercent
        let batteryScore = batData?.healthPercent ?? 100
        let thermalScore: Double = {
            let maxTemp = sensorData.sensors.map(\.value).max() ?? 0
            if maxTemp >= 95 { return 40 }
            if maxTemp >= 80 { return 70 }
            return 95
        }()
        let cpuScore: Double = cpuData.totalUsage < 80 ? 95 : (cpuData.totalUsage < 95 ? 70 : 40)
        let memoryScore: Double = {
            switch memData.pressureLevel {
            case .nominal: return 95
            case .warning: return 65
            case .critical: return 30
            }
        }()

        let overall = HealthScore.overallScore(storage: storageScore, battery: batteryScore, thermal: thermalScore, cpu: cpuScore, memory: memoryScore)

        let healthScores = [
            HealthScore(component: "Storage", score: storageScore, detail: "SMART health: \(Int(storageScore))%"),
            HealthScore(component: "Battery", score: batteryScore, detail: batData != nil ? "Capacity: \(Int(batteryScore))% of design" : "No battery"),
            HealthScore(component: "Thermal", score: thermalScore, detail: "Max temp: \(Int(sensorData.sensors.map(\.value).max() ?? 0))°C"),
            HealthScore(component: "CPU", score: cpuScore, detail: "Usage: \(Int(cpuData.totalUsage))%"),
            HealthScore(component: "Memory", score: memoryScore, detail: "Pressure: \(memData.pressureLevel.rawValue)"),
        ]

        var recommendations: [String] = []
        if batteryScore < 80 { recommendations.append("Battery at \(Int(batteryScore))% original capacity — consider Apple service.") }
        if let bat = batData, bat.cycleCount > 500 { recommendations.append("Battery has \(bat.cycleCount) cycles — monitor health regularly.") }
        for vol in storeData.volumes {
            let usedPct = Double(vol.usedBytes) / Double(max(vol.totalBytes, 1)) * 100
            if usedPct > 85 { recommendations.append("\(vol.name) is \(Int(usedPct))% full — free up space.") }
        }
        if thermalScore < 70 { recommendations.append("High temperatures detected — check ventilation.") }
        if memData.pressureLevel == .critical { recommendations.append("Memory pressure critical — close unused apps.") }
        if recommendations.isEmpty { recommendations.append("All systems healthy — no action needed.") }

        var modelBuf = [CChar](repeating: 0, count: 256)
        var modelSize = 256
        sysctlbyname("hw.model", &modelBuf, &modelSize, nil, 0)
        let model = String(cString: modelBuf)

        let osVersion = Foundation.ProcessInfo.processInfo.operatingSystemVersionString

        var chipBuf = [CChar](repeating: 0, count: 256)
        var chipSize = 256
        sysctlbyname("machdep.cpu.brand_string", &chipBuf, &chipSize, nil, 0)
        let chip = String(cString: chipBuf)

        let report = DiagnosticReport(
            timestamp: Date(),
            macModel: model,
            macOSVersion: osVersion,
            chipType: chip.isEmpty ? "Apple Silicon" : chip,
            serialNumber: getSerialNumber(),
            cpu: cpuData,
            memory: memData,
            storage: storeData,
            battery: batData,
            sensors: sensorData,
            gpu: gpuData,
            network: netData,
            healthScores: healthScores,
            overallHealthScore: overall,
            recommendations: recommendations
        )

        diagnosticReport = report
        isRunningDiagnostic = false
        diagnosticProgress = ""
        return report
    }

    // MARK: - Direct Reads

    private func fetchFast() {
        readerQueue.async { [weak self] in
            guard let self else { return }
            let c = self.cpuReader.read(smc: self.smcReader)
            let (cpuTop, _) = self.processReader.readTopProcesses(limit: 10)
            var cpuWithProcs = c
            cpuWithProcs.topProcesses = cpuTop

            let n = self.networkReader.read()
            let procs = self.fullProcessReader.read()

            // Persist network usage. Samples go through the store which handles
            // counter-reset detection, 1-minute bucketing, debounced writes,
            // and 7-day retention. Safe to call from any thread.
            let now = Date()
            let usageSamples: [NetworkUsageSample] = n.interfaces.map { iface in
                NetworkUsageSample(
                    interface: iface.name,
                    kernelTxBytes: iface.txBytes,
                    kernelRxBytes: iface.rxBytes,
                    kernelTxPackets: iface.packetsOut,
                    kernelRxPackets: iface.packetsIn,
                    timestamp: now
                )
            }
            self.networkUsageStore.ingest(usageSamples)
            let netTotals = self.networkUsageStore.currentTotals()
            let netSummaries = self.networkUsageStore.summarySnapshot(referenceDate: now)

            // Per-SSID lifetime attribution. For each Wi-Fi-capable interface
            // compute the delta since the previous tick and credit it to the
            // currently joined SSID. Interfaces with no SSID (wired, VPN,
            // loopback) are skipped; their traffic isn't a network the user
            // can pick. When an interface has an SSID but CoreWLAN returns
            // nil (permission not granted / hidden network) the delta falls
            // through to the "unknown" bucket so lifetime bytes never vanish.
            self.attributePerSSIDDeltas(interfaces: n.interfaces)

            // Lightweight disk I/O delta — 2s intervals give smooth real-time throughput
            let (ioRead, ioWrite) = self.storageReader.readIOOnly()

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.cpu = cpuWithProcs
                self.cpuHistory.append(cpuWithProcs.totalUsage)
                if self.cpuHistory.count > self.historyLimit { self.cpuHistory.removeFirst() }

                self.network = n
                self.networkUpHistory.append(n.totalTxBytesPerSec)
                self.networkDownHistory.append(n.totalRxBytesPerSec)
                if self.networkUpHistory.count > self.historyLimit { self.networkUpHistory.removeFirst() }
                if self.networkDownHistory.count > self.historyLimit { self.networkDownHistory.removeFirst() }

                // Publish persistent usage snapshots (cheap copies of cached structs).
                self.networkTotals = netTotals
                self.networkUsageSummaries = netSummaries

                self.processesData = procs

                // Merge live I/O into storage (volumes/SMART updated on slow timer)
                if self.storage != nil {
                    self.storage?.readBytesPerSec  = ioRead
                    self.storage?.writeBytesPerSec = ioWrite
                }
            }
        }
    }

    private func fetchMedium() {
        readerQueue.async { [weak self] in
            guard let self else { return }
            let m = self.memoryReader.read()
            let (_, memTop) = self.processReader.readTopProcesses(limit: 10)
            var memWithProcs = m
            memWithProcs.topProcesses = memTop

            let g = self.gpuReader.read(smc: self.smcReader)
            let s = self.readSensors()

            // Read SMC power keys via privileged XPC helper (Apple Silicon needs root for power keys)
            // Falls back to battery-derived power if helper unavailable
            if let xpc = self.xpcClient {
                Task { [weak self] in
                    let powerData = await xpc.fetchPowerData()
                    var cpuPow = powerData?["cpu"] ?? 0
                    var gpuPow = powerData?["gpu"] ?? 0
                    var socPow = powerData?["system"] ?? 0

                    // Per-component SMC readings (0 if key unavailable)
                    let anePow = powerData?["ane"] ?? 0
                    let dramPow = powerData?["dram"] ?? 0
                    let fabricPow = powerData?["fabric"] ?? 0
                    let displayPow = powerData?["display"] ?? 0
                    let pciePow = powerData?["pcie"] ?? 0
                    let mediaPow = powerData?["media"] ?? 0
                    let ispPow = powerData?["isp"] ?? 0
                    let gpuSramPow = powerData?["gpusram"] ?? 0

                    // New per-component readings
                    let deliveryPow = powerData?["delivery"] ?? 0
                    let eClusterPow = powerData?["ecluster"] ?? 0
                    let pClusterPow = powerData?["pcluster"] ?? 0
                    let uncorePow = powerData?["uncore"] ?? 0
                    let pmuPow = powerData?["pmu"] ?? 0
                    let psCtrlPow = powerData?["psctrl"] ?? 0
                    let thermalPow = powerData?["thermal"] ?? 0
                    let backlightPow = powerData?["backlight"] ?? 0
                    let rail5vPow = powerData?["rail5v"] ?? 0
                    let rail3vPow = powerData?["rail3v"] ?? 0
                    let usb1Pow = powerData?["usb1"] ?? 0
                    let usb2Pow = powerData?["usb2"] ?? 0
                    let hiperfSustPow = powerData?["hiperf_sust"] ?? 0
                    let hiperfBudgetPow = powerData?["hiperf_budget"] ?? 0

                    // Fallback: if PSTR unavailable, derive from battery
                    if socPow == 0, let bat = self?.battery {
                        socPow = bat.wattage
                    }

                    // M4 Pro/Max: PCPC & PCPG don't exist.
                    // PHPC (high-perf cluster) = CPU + GPU combined.
                    // Use PHPC if available, otherwise fall back to PSTR proportions.
                    let hpcPow = powerData?["hiperf"] ?? 0
                    if cpuPow == 0 && gpuPow == 0 {
                        if hpcPow > 0 {
                            // PHPC is CPU+GPU. Split ~75/25 based on typical M4 Pro ratio.
                            cpuPow = hpcPow * 0.75
                            gpuPow = hpcPow * 0.25
                        } else if socPow > 0 {
                            cpuPow = socPow * 0.45
                            gpuPow = socPow * 0.15
                        }
                    }

                    await MainActor.run { [weak self] in
                        guard let self else { return }
                        self.cpuPower = cpuPow
                        self.gpuPower = gpuPow
                        self.socPower = socPow
                        self.anePowerSMC = anePow
                        self.dramPowerSMC = dramPow
                        self.fabricPowerSMC = fabricPow
                        self.displayPowerSMC = displayPow
                        self.pciePowerSMC = pciePow
                        self.mediaPowerSMC = mediaPow
                        self.ispPowerSMC = ispPow
                        self.gpuSramPowerSMC = gpuSramPow

                        // New per-component readings
                        self.deliveryPowerSMC = deliveryPow
                        self.eClusterPowerSMC = eClusterPow
                        self.pClusterPowerSMC = pClusterPow
                        self.uncorePowerSMC = uncorePow
                        self.pmuPowerSMC = pmuPow
                        self.psCtrlPowerSMC = psCtrlPow
                        self.thermalPowerSMC = thermalPow
                        self.backlightPowerSMC = backlightPow
                        self.rail5vPowerSMC = rail5vPow
                        self.rail3vPowerSMC = rail3vPow
                        self.usb1PowerSMC = usb1Pow
                        self.usb2PowerSMC = usb2Pow
                        self.hiperfSustPowerSMC = hiperfSustPow
                        self.hiperfBudgetSMC = hiperfBudgetPow

                        // Track power history (capped at 60 points)
                        if socPow > 0 {
                            self.powerHistory.append(socPow)
                            if self.powerHistory.count > self.historyLimit {
                                self.powerHistory.removeFirst()
                            }
                        }
                    }
                }
            } else {
                // No XPC — try local SMC (will return 0 on M4 without root) then battery fallback
                var cpuPow  = self.smcReader?.readPower(key: "PCPC") ?? 0
                var gpuPow  = self.smcReader?.readPower(key: "PCPG") ?? 0
                var socPow  = self.smcReader?.readPower(key: "PSTR") ?? 0

                // Battery fallback for system power
                if socPow == 0, let bat = self.batteryReader.read() {
                    socPow = bat.wattage
                }

                // M4 Pro/Max: use PHPC (high-perf cluster = CPU+GPU combined)
                let hpcPow = self.smcReader?.readPower(key: "PHPC") ?? 0
                if cpuPow == 0 && gpuPow == 0 {
                    if hpcPow > 0 {
                        cpuPow = hpcPow * 0.75
                        gpuPow = hpcPow * 0.25
                    } else if socPow > 0 {
                        cpuPow = socPow * 0.45
                        gpuPow = socPow * 0.15
                    }
                }

                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.cpuPower = cpuPow
                    self.gpuPower = gpuPow
                    self.socPower = socPow

                    if socPow > 0 {
                        self.powerHistory.append(socPow)
                        if self.powerHistory.count > self.historyLimit {
                            self.powerHistory.removeFirst()
                        }
                    }
                }
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.memory = memWithProcs
                let usedPct = Double(memWithProcs.used) / Double(max(memWithProcs.total, 1)) * 100
                self.memoryHistory.append(usedPct)
                if self.memoryHistory.count > self.historyLimit { self.memoryHistory.removeFirst() }

                self.gpu = g
                self.sensors = s

                // GPU rolling history (cap at 120 points)
                let gpuCap = 120
                self.gpuUtilHistory.append(g.utilization)
                self.gpuRenderHistory.append(g.renderUtilization)
                self.gpuTilerHistory.append(g.tilerUtilization)
                self.gpuComputeHistory.append(g.computeUtilization)
                self.gpuReadBWHistory.append(g.memReadBytesPerSec)
                self.gpuWriteBWHistory.append(g.memWriteBytesPerSec)
                if self.gpuUtilHistory.count > gpuCap    { self.gpuUtilHistory.removeFirst() }
                if self.gpuRenderHistory.count > gpuCap  { self.gpuRenderHistory.removeFirst() }
                if self.gpuTilerHistory.count > gpuCap   { self.gpuTilerHistory.removeFirst() }
                if self.gpuComputeHistory.count > gpuCap { self.gpuComputeHistory.removeFirst() }
                if self.gpuReadBWHistory.count > gpuCap  { self.gpuReadBWHistory.removeFirst() }
                if self.gpuWriteBWHistory.count > gpuCap { self.gpuWriteBWHistory.removeFirst() }

                self.alertEngine.evaluate(cpu: self.cpu, memory: self.memory, storage: self.storage, battery: self.battery, sensors: self.sensors)
            }
        }
    }

    private func fetchSlow() {
        readerQueue.async { [weak self] in
            guard let self else { return }
            let b = self.batteryReader.read()
            let st = self.storageReader.read()

            DispatchQueue.main.async { [weak self] in
                self?.battery = b
                self?.storage = st
            }
        }
    }

    private func readSensors() -> SensorData {
        guard let smc = smcReader else { return SensorData(sensors: [], fans: []) }

        var sensors: [SensorReading] = []
        for tempKey in SMCReader.appleSiliconTempKeys {
            if let temp = smc.readTemperature(key: tempKey.key) {
                let category: SensorCategory = {
                    switch tempKey.category {
                    case "CPU Temperature": return .cpuTemperature
                    case "GPU Temperature": return .gpuTemperature
                    case "Battery Temperature": return .batteryTemperature
                    case "Drive Temperature": return .driveTemperature
                    case "Skin Temperature": return .skinTemperature
                    case "Ambient Temperature": return .ambientTemperature
                    default: return .other
                    }
                }()
                sensors.append(SensorReading(name: tempKey.name, key: tempKey.key, value: temp, unit: "°C", category: category, minRecorded: temp, maxRecorded: temp))
            }
        }

        var fans: [FanReading] = []
        if let fanCount = smc.readFanCount() {
            for i in 0..<fanCount {
                let rpm = smc.readFanSpeed(index: i) ?? 0
                fans.append(FanReading(name: "Fan \(i + 1)", rpm: rpm, minRPM: smc.readFanMin(index: i) ?? 0, maxRPM: smc.readFanMax(index: i) ?? 0))
            }
        }

        return SensorData(sensors: sensors, fans: fans)
    }

    private func getSerialNumber() -> String {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        guard service != 0 else { return "Unknown" }
        defer { IOObjectRelease(service) }
        let serial = IORegistryEntryCreateCFProperty(service, "IOPlatformSerialNumber" as CFString, kCFAllocatorDefault, 0)
        return serial?.takeRetainedValue() as? String ?? "Unknown"
    }

    // MARK: - Per-SSID lifetime attribution

    /// Converts absolute kernel byte counters into deltas per interface and
    /// hands them to the PerSSIDUsageStore under the currently joined SSID.
    ///
    /// Notes:
    ///   - Runs on the reader background queue (called from fetchFast). Routes
    ///     store mutations to the main actor because PerSSIDUsageStore is
    ///     @Observable and updates SwiftUI state.
    ///   - Counter wrap / reboot detection: if the new counter is below the
    ///     stored one we reset the baseline and credit zero for this tick,
    ///     rather than crediting the absolute post-reboot value (that would
    ///     be misattributed lifetime bytes).
    ///   - Only interfaces that present a Wi-Fi link (wifiSSID != nil in this
    ///     tick OR historically had one since launch) are attributed; wired
    ///     interfaces don't belong to a "network" in the SSID sense.
    private func attributePerSSIDDeltas(interfaces: [NetworkInterface]) {
        guard let store = perSSIDUsageStore else { return }

        // Only Wi-Fi interfaces. Identify by presence of any SSID data ever
        // seen on this BSD name during the process lifetime; otherwise skip.
        // (A wired en0 will never have an SSID and stays out of the tracker.)
        var pending: [(ssid: String?, deltaIn: UInt64, deltaOut: UInt64)] = []

        for iface in interfaces {
            let bsd = iface.name
            // Heuristic: anything that currently has an SSID counts. Skip
            // interfaces that have never had one so wired traffic doesn't
            // leak into the "unknown" bucket.
            let isWiFiLike = iface.wifiSSID != nil
            guard isWiFiLike else {
                // Forget stale baseline if the interface changed identity.
                lastSSIDKernelCounters.removeValue(forKey: bsd)
                continue
            }

            let rx = iface.rxBytes
            let tx = iface.txBytes
            let last = lastSSIDKernelCounters[bsd]
            lastSSIDKernelCounters[bsd] = (rx: rx, tx: tx)

            guard let last else {
                // First observation this process lifetime. Baseline only, no
                // attribution yet (we don't know how many of these bytes are
                // from previous runs).
                continue
            }

            var dIn: UInt64 = 0
            var dOut: UInt64 = 0
            if rx >= last.rx { dIn = rx &- last.rx }
            if tx >= last.tx { dOut = tx &- last.tx }

            // Sanity cap: ignore absurd jumps (>5 GB in one 2s tick). These
            // are almost always counter resets that satisfied >= but still
            // represent a reboot / rollover, not real traffic.
            let suspiciousJump: UInt64 = 5 * 1024 * 1024 * 1024
            if dIn > suspiciousJump || dOut > suspiciousJump {
                continue
            }

            if dIn == 0 && dOut == 0 { continue }
            pending.append((ssid: iface.wifiSSID, deltaIn: dIn, deltaOut: dOut))
        }

        guard !pending.isEmpty else { return }
        DispatchQueue.main.async {
            for entry in pending {
                store.recordDelta(ssid: entry.ssid, deltaIn: entry.deltaIn, deltaOut: entry.deltaOut)
            }
        }
    }
}

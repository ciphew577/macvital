import Foundation
import Darwin
import SystemConfiguration
import CoreWLAN

final class NetworkReader {
    // Legacy per-interface byte-rate tracker (keeps old NetworkInterface model alive
    // for the rest of the app).
    private var previousStats: [String: (txBytes: UInt64, rxBytes: UInt64, timestamp: TimeInterval)] = [:]

    // Per-(interface, SSID) bucket tracker. Each time the SSID flips for a given
    // interface a brand-new bucket is opened and the old one is frozen.
    private struct Bucket {
        let id: String               // "<bsdName>|<ssid or _none_>"
        let bsdName: String
        let ssid: String?
        var startRxBytes: UInt64     // absolute interface counter at bucket start
        var startTxBytes: UInt64
        var sessionRx: UInt64        // rolling session total for this bucket
        var sessionTx: UInt64
        var lastRxBytes: UInt64      // absolute interface counter at last poll
        var lastTxBytes: UInt64
        var lastTimestamp: TimeInterval
        var bytesInPerSec: UInt64
        var bytesOutPerSec: UInt64
        let firstSeen: Date
        var lastSeen: Date
    }
    private var buckets: [String: Bucket] = [:] // keyed by bsdName (only the active bucket)
    private var archivedBuckets: [String: Bucket] = [:] // keyed by bucket id for buckets whose SSID changed

    // Cached interface type classifications (SCNetworkInterface lookup is mildly
    // expensive and never changes within a session).
    private var cachedTypes: [String: NetworkInterfaceType] = [:]
    private var cachedDisplayNames: [String: String] = [:]
    private var cachedWiFiInterface: String?

    // MARK: - Public entry point

    func read() -> NetworkData {
        var interfaces: [NetworkInterface] = []

        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return NetworkData(interfaces: [], interfaceInfos: [])
        }
        defer { freeifaddrs(ifaddr) }

        // Collect unique interface names. Keep VPN (utun*) and loopback is still
        // skipped — the user explicitly wants VPN and USB tethering visible.
        var ifNames = Set<String>()
        var ptr = firstAddr
        while true {
            let name = String(cString: ptr.pointee.ifa_name)
            if !shouldSkipInterface(name: name) {
                ifNames.insert(name)
            }
            guard let next = ptr.pointee.ifa_next else { break }
            ptr = next
        }

        for name in ifNames.sorted() {
            let (txBytes, rxBytes, errIn, errOut, pktsIn, pktsOut) = getInterfaceStats(name: name)
            let (ipv4, ipv6) = getIPAddresses(name: name, firstAddr: firstAddr)
            let mac = getMACAddress(name: name, firstAddr: firstAddr)

            // Calculate rates (legacy path — unchanged semantics).
            let now = Date.timeIntervalSinceReferenceDate
            var txRate: UInt64 = 0
            var rxRate: UInt64 = 0
            if let prev = previousStats[name] {
                let elapsed = now - prev.timestamp
                if elapsed > 0 && txBytes >= prev.txBytes && rxBytes >= prev.rxBytes {
                    txRate = UInt64(Double(txBytes - prev.txBytes) / elapsed)
                    rxRate = UInt64(Double(rxBytes - prev.rxBytes) / elapsed)
                }
            }
            previousStats[name] = (txBytes, rxBytes, now)

            // WiFi info (only for en* interfaces — utun/bridge never have SSIDs).
            let (wifiSSID, wifiSignal, wifiBand, wifiChannel) = name.hasPrefix("en")
                ? getWiFiInfo(name: name)
                : (nil, nil, nil, nil)

            let type = classifyInterface(name: name, hasWiFiSSID: wifiSSID != nil)
            let linkSpeed = linkSpeedLabel(name: name, type: type, wifiSSID: wifiSSID)

            interfaces.append(NetworkInterface(
                name: name,
                macAddress: mac,
                ipv4Address: ipv4,
                ipv6Address: ipv6,
                linkSpeed: linkSpeed,
                txBytes: txBytes,
                rxBytes: rxBytes,
                txBytesPerSec: txRate,
                rxBytesPerSec: rxRate,
                errorsIn: errIn,
                errorsOut: errOut,
                packetsIn: pktsIn,
                packetsOut: pktsOut,
                wifiSSID: wifiSSID,
                wifiSignalDBm: wifiSignal,
                wifiBand: wifiBand,
                wifiChannel: wifiChannel
            ))

            // Update (interface, SSID) bucket.
            updateBucket(bsdName: name,
                         ssid: wifiSSID,
                         rxBytes: rxBytes,
                         txBytes: txBytes,
                         timestamp: now)
        }

        // NOTE: persistence is driven by SystemMonitor via NetworkUsageStore.ingest(...)
        // using raw kernel counters (with reboot-reset detection and 1-minute bucketing).
        // We deliberately do NOT also call .record(interface:ssid:...) here — that was
        // creating a SECOND sample row per poll keyed by "<bsd>|<ssid>", which double-
        // counted traffic in the samples table and polluted interface_totals with
        // ghost composite keys. Per-SSID attribution lives entirely in the in-memory
        // buckets below and is surfaced via NetworkInterfaceInfo; historical totals
        // come from NetworkUsageStore.summarySnapshot() in SystemMonitor.

        // Build the NetworkInterfaceInfo list the ViewModel will publish.
        let infos = buildInterfaceInfos(interfaces: interfaces)
        return NetworkData(interfaces: interfaces, interfaceInfos: infos)
    }

    // MARK: - Skip list

    private func shouldSkipInterface(name: String) -> Bool {
        // Loopback and low-value Apple virtual interfaces. VPN (utun*) is kept.
        if name.hasPrefix("lo") { return true }
        if name.hasPrefix("awdl") { return true }       // AirDrop/Wireless direct link
        if name.hasPrefix("llw") { return true }        // low-latency wlan
        if name.hasPrefix("anpi") { return true }       // apple n-p interface
        if name.hasPrefix("bridge") { return true }     // internal bridges
        if name.hasPrefix("ap") && name != "ap" { return true } // software APs
        if name == "gif0" || name == "stf0" { return true }
        return false
    }

    // MARK: - Bucket management

    private func updateBucket(bsdName: String,
                              ssid: String?,
                              rxBytes: UInt64,
                              txBytes: UInt64,
                              timestamp: TimeInterval) {
        let key = bsdName
        let bucketId = "\(bsdName)|\(ssid ?? "_none_")"

        if var existing = buckets[key] {
            if existing.id == bucketId {
                // Same (interface, SSID) — accumulate deltas.
                let rxDelta = rxBytes >= existing.lastRxBytes ? rxBytes - existing.lastRxBytes : 0
                let txDelta = txBytes >= existing.lastTxBytes ? txBytes - existing.lastTxBytes : 0
                existing.sessionRx &+= rxDelta
                existing.sessionTx &+= txDelta
                let elapsed = timestamp - existing.lastTimestamp
                if elapsed > 0 {
                    existing.bytesInPerSec = UInt64(Double(rxDelta) / elapsed)
                    existing.bytesOutPerSec = UInt64(Double(txDelta) / elapsed)
                }
                existing.lastRxBytes = rxBytes
                existing.lastTxBytes = txBytes
                existing.lastTimestamp = timestamp
                existing.lastSeen = Date()
                buckets[key] = existing
                return
            }

            // The bucket id changed. There are two distinct cases:
            //
            //   (A) nil ↔ resolved SSID on the SAME Wi-Fi interface
            //       e.g. first-poll has ssid=nil (CWWiFiClient hadn't resolved
            //       the SSID yet), second-poll resolves to "Home Wi-Fi".
            //       The user is still on the same network — we must NOT archive
            //       the old bucket as a distinct row. Merge its session totals
            //       forward into the new bucket identity.
            //
            //   (B) Real SSID flip — "Home Wi-Fi" → "Cafe Wi-Fi". The old
            //       bucket is a legitimate historical record and should be
            //       archived.
            //
            // Detect (A) as: at least one side nil AND the other side a non-
            // empty string, AND no real SSID→SSID transition.
            let isNilResolveTransition: Bool = {
                let oldEmpty = (existing.ssid ?? "").isEmpty
                let newEmpty = (ssid ?? "").isEmpty
                return oldEmpty != newEmpty
            }()

            if isNilResolveTransition {
                // Merge: carry session totals + timing forward into the new
                // bucket identity. Delta from this poll is accumulated too.
                let rxDelta = rxBytes >= existing.lastRxBytes ? rxBytes - existing.lastRxBytes : 0
                let txDelta = txBytes >= existing.lastTxBytes ? txBytes - existing.lastTxBytes : 0
                let carried = Bucket(
                    id: bucketId,
                    bsdName: bsdName,
                    ssid: ssid,
                    startRxBytes: existing.startRxBytes,
                    startTxBytes: existing.startTxBytes,
                    sessionRx: existing.sessionRx &+ rxDelta,
                    sessionTx: existing.sessionTx &+ txDelta,
                    lastRxBytes: rxBytes,
                    lastTxBytes: txBytes,
                    lastTimestamp: timestamp,
                    bytesInPerSec: 0,
                    bytesOutPerSec: 0,
                    firstSeen: existing.firstSeen,
                    lastSeen: Date()
                )
                buckets[key] = carried
                // Also scrub any archived ghost row that may already exist
                // for the nil-SSID side of this interface (defensive: if an
                // earlier poll somehow archived it before we reached this
                // code path, drop it so the UI doesn't show a duplicate).
                let oldId = existing.id
                if archivedBuckets[oldId] != nil {
                    archivedBuckets.removeValue(forKey: oldId)
                }
                return
            }

            // Real SSID → different SSID transition. Archive the old bucket.
            archivedBuckets[existing.id] = existing
        }

        // New bucket: start counters at the current absolute counters so the
        // session total only reflects traffic while this SSID is joined.
        let fresh = Bucket(
            id: bucketId,
            bsdName: bsdName,
            ssid: ssid,
            startRxBytes: rxBytes,
            startTxBytes: txBytes,
            sessionRx: 0,
            sessionTx: 0,
            lastRxBytes: rxBytes,
            lastTxBytes: txBytes,
            lastTimestamp: timestamp,
            bytesInPerSec: 0,
            bytesOutPerSec: 0,
            firstSeen: Date(),
            lastSeen: Date()
        )
        buckets[key] = fresh
    }

    // MARK: - NetworkInterfaceInfo assembly

    private func buildInterfaceInfos(interfaces: [NetworkInterface]) -> [NetworkInterfaceInfo] {
        var infos: [NetworkInterfaceInfo] = []

        // Active buckets (one per live interface).
        for iface in interfaces {
            guard let bucket = buckets[iface.name] else { continue }
            let type = classifyInterface(name: iface.name, hasWiFiSSID: iface.wifiSSID != nil)
            let isActive = !iface.ipv4Address.isEmpty
            let info = NetworkInterfaceInfo(
                id: bucket.id,
                bsdName: iface.name,
                type: type,
                displayName: displayName(for: iface.name, type: type, ssid: iface.wifiSSID),
                currentSSID: iface.wifiSSID,
                isActive: isActive,
                linkSpeedMbps: linkSpeedMbps(for: iface.name),
                ipv4Address: iface.ipv4Address,
                ipv6Address: iface.ipv6Address,
                macAddress: iface.macAddress,
                wifiSignalDBm: iface.wifiSignalDBm,
                wifiBand: iface.wifiBand,
                wifiChannel: iface.wifiChannel,
                sessionBytesIn: bucket.sessionRx,
                sessionBytesOut: bucket.sessionTx,
                bytesInPerSec: bucket.bytesInPerSec,
                bytesOutPerSec: bucket.bytesOutPerSec,
                firstSeen: bucket.firstSeen,
                lastSeen: bucket.lastSeen
            )
            infos.append(info)
        }

        // Archived buckets (SSIDs previously joined this session).
        for bucket in archivedBuckets.values {
            let type = classifyInterface(name: bucket.bsdName, hasWiFiSSID: bucket.ssid != nil)
            let info = NetworkInterfaceInfo(
                id: bucket.id,
                bsdName: bucket.bsdName,
                type: type,
                displayName: displayName(for: bucket.bsdName, type: type, ssid: bucket.ssid),
                currentSSID: bucket.ssid,
                isActive: false,
                linkSpeedMbps: nil,
                ipv4Address: "",
                ipv6Address: "",
                macAddress: "",
                wifiSignalDBm: nil,
                wifiBand: nil,
                wifiChannel: nil,
                sessionBytesIn: bucket.sessionRx,
                sessionBytesOut: bucket.sessionTx,
                bytesInPerSec: 0,
                bytesOutPerSec: 0,
                firstSeen: bucket.firstSeen,
                lastSeen: bucket.lastSeen
            )
            infos.append(info)
        }

        // Sort active first, then by session bytes descending.
        return infos.sorted { lhs, rhs in
            if lhs.isActive != rhs.isActive { return lhs.isActive }
            return (lhs.sessionBytesIn + lhs.sessionBytesOut) > (rhs.sessionBytesIn + rhs.sessionBytesOut)
        }
    }

    // MARK: - Interface type classification

    /// Classify an interface using SCNetworkInterface where possible, with
    /// name-prefix heuristics as a fallback for virtual interfaces SC does
    /// not enumerate (utun, awdl, ...).
    private func classifyInterface(name: String, hasWiFiSSID: Bool) -> NetworkInterfaceType {
        if let cached = cachedTypes[name], !hasWiFiSSID {
            // Don't cache when SSID presence might upgrade Other -> Wi-Fi.
            return cached
        }

        // Name-prefix shortcuts for interfaces SC can't see or that are
        // unambiguous from the name alone.
        if name.hasPrefix("utun") {
            cachedTypes[name] = .vpn
            return .vpn
        }
        if name.hasPrefix("lo") {
            cachedTypes[name] = .loopback
            return .loopback
        }
        if hasWiFiSSID {
            cachedTypes[name] = .wifi
            return .wifi
        }

        // SCNetworkInterface walk — reliable for en*, ethernet, Thunderbolt, USB tether.
        if let scType = scNetworkType(for: name) {
            cachedTypes[name] = scType
            return scType
        }

        // Heuristic fallback: en0 is almost always Wi-Fi on Apple Silicon laptops,
        // but detectWiFiInterfaceName() is authoritative — respect it.
        if name.hasPrefix("en") {
            if cachedWiFiInterface == nil {
                cachedWiFiInterface = detectWiFiInterfaceName() ?? ""
            }
            if cachedWiFiInterface == name {
                cachedTypes[name] = .wifi
                return .wifi
            }
            cachedTypes[name] = .ethernet
            return .ethernet
        }

        cachedTypes[name] = .other
        return .other
    }

    private func scNetworkType(for name: String) -> NetworkInterfaceType? {
        guard let rawInterfaces = SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] else {
            return nil
        }
        for scIface in rawInterfaces {
            guard let bsd = SCNetworkInterfaceGetBSDName(scIface) as String? else { continue }
            if bsd != name { continue }
            guard let rawType = SCNetworkInterfaceGetInterfaceType(scIface) as String? else { continue }
            switch rawType {
            case "IEEE80211":
                return .wifi
            case "Ethernet":
                // Could be real Ethernet, USB-C dongle, or iPhone USB tether.
                // iPhone USB shows up as "iPhone USB" in the user-visible name.
                if let displayName = SCNetworkInterfaceGetLocalizedDisplayName(scIface) as String? {
                    let lower = displayName.lowercased()
                    if lower.contains("iphone") || lower.contains("ipad") {
                        return .usbTether
                    }
                    if lower.contains("thunderbolt") {
                        return .thunderbolt
                    }
                }
                return .ethernet
            case "Bluetooth":
                return .bluetooth
            case "FireWire", "IrDA", "IPSec", "Modem", "PPP", "Serial", "WWAN":
                return .other
            default:
                return .other
            }
        }
        return nil
    }

    private func displayName(for bsdName: String, type: NetworkInterfaceType, ssid: String?) -> String {
        if let cached = cachedDisplayNames[bsdName] {
            return cached
        }
        // Prefer the SC localized display name when we can get it.
        if let rawInterfaces = SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] {
            for scIface in rawInterfaces {
                if let bsd = SCNetworkInterfaceGetBSDName(scIface) as String?, bsd == bsdName,
                   let display = SCNetworkInterfaceGetLocalizedDisplayName(scIface) as String? {
                    cachedDisplayNames[bsdName] = display
                    return display
                }
            }
        }
        // Fallbacks for virtual interfaces SC doesn't enumerate.
        let fallback: String
        switch type {
        case .vpn:       fallback = "VPN (\(bsdName))"
        case .wifi:      fallback = ssid ?? "Wi-Fi"
        case .ethernet:  fallback = "Ethernet"
        case .usbTether: fallback = "iPhone USB"
        case .loopback:  fallback = "Loopback"
        default:         fallback = bsdName
        }
        cachedDisplayNames[bsdName] = fallback
        return fallback
    }

    private func linkSpeedMbps(for name: String) -> Int? {
        // ifi_baudrate from if_data is returned in bits/sec.
        var mib = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var len: size_t = 0
        guard sysctl(&mib, UInt32(mib.count), nil, &len, nil, 0) == 0 else { return nil }
        var buf = [UInt8](repeating: 0, count: len)
        guard sysctl(&mib, UInt32(mib.count), &buf, &len, nil, 0) == 0 else { return nil }

        var offset = 0
        while offset < len {
            let msgPtr = buf.withUnsafeBufferPointer { bufPtr -> UnsafeRawPointer in
                UnsafeRawPointer(bufPtr.baseAddress! + offset)
            }
            let ifmsg = msgPtr.assumingMemoryBound(to: if_msghdr2.self).pointee
            if ifmsg.ifm_type == RTM_IFINFO2 {
                var ifNameBuf = [CChar](repeating: 0, count: Int(IFNAMSIZ))
                if_indextoname(UInt32(ifmsg.ifm_index), &ifNameBuf)
                let ifName = String(cString: ifNameBuf)
                if ifName == name {
                    let baud = UInt64(ifmsg.ifm_data.ifi_baudrate)
                    if baud == 0 { return nil }
                    return Int(baud / 1_000_000)
                }
            }
            offset += Int(ifmsg.ifm_msglen)
        }
        return nil
    }

    private func linkSpeedLabel(name: String, type: NetworkInterfaceType, wifiSSID: String?) -> String {
        if wifiSSID != nil { return "Wi-Fi" }
        switch type {
        case .wifi:       return "Wi-Fi"
        case .ethernet:   return "Ethernet"
        case .usbTether:  return "iPhone USB"
        case .vpn:        return "VPN"
        case .thunderbolt: return "Thunderbolt"
        case .bluetooth:  return "Bluetooth"
        case .loopback:   return "Loopback"
        case .other:      return name
        }
    }

    // MARK: - Low-level interface stats

    private func getInterfaceStats(name: String) -> (tx: UInt64, rx: UInt64, errIn: UInt64, errOut: UInt64, pktsIn: UInt64, pktsOut: UInt64) {
        var mib = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var len: size_t = 0

        guard sysctl(&mib, UInt32(mib.count), nil, &len, nil, 0) == 0 else { return (0,0,0,0,0,0) }
        var buf = [UInt8](repeating: 0, count: len)
        guard sysctl(&mib, UInt32(mib.count), &buf, &len, nil, 0) == 0 else { return (0,0,0,0,0,0) }

        var offset = 0
        while offset < len {
            let msgPtr = buf.withUnsafeBufferPointer { bufPtr -> UnsafeRawPointer in
                UnsafeRawPointer(bufPtr.baseAddress! + offset)
            }
            let ifmsg = msgPtr.assumingMemoryBound(to: if_msghdr2.self).pointee

            if ifmsg.ifm_type == RTM_IFINFO2 {
                var ifNameBuf = [CChar](repeating: 0, count: Int(IFNAMSIZ))
                if_indextoname(UInt32(ifmsg.ifm_index), &ifNameBuf)
                let ifName = String(cString: ifNameBuf)

                if ifName == name {
                    return (
                        tx: UInt64(ifmsg.ifm_data.ifi_obytes),
                        rx: UInt64(ifmsg.ifm_data.ifi_ibytes),
                        errIn: UInt64(ifmsg.ifm_data.ifi_ierrors),
                        errOut: UInt64(ifmsg.ifm_data.ifi_oerrors),
                        pktsIn: UInt64(ifmsg.ifm_data.ifi_ipackets),
                        pktsOut: UInt64(ifmsg.ifm_data.ifi_opackets)
                    )
                }
            }
            offset += Int(ifmsg.ifm_msglen)
        }
        return (0,0,0,0,0,0)
    }

    private func getIPAddresses(name: String, firstAddr: UnsafeMutablePointer<ifaddrs>) -> (ipv4: String, ipv6: String) {
        var ipv4 = ""
        var ipv6 = ""
        var ptr = firstAddr
        while true {
            let ifName = String(cString: ptr.pointee.ifa_name)
            if ifName == name {
                let family = ptr.pointee.ifa_addr.pointee.sa_family
                if family == UInt8(AF_INET) {
                    var addr = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                    ptr.pointee.ifa_addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { sin in
                        var inAddr = sin.pointee.sin_addr
                        inet_ntop(AF_INET, &inAddr, &addr, socklen_t(INET_ADDRSTRLEN))
                    }
                    ipv4 = String(cString: addr)
                } else if family == UInt8(AF_INET6) {
                    var addr = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
                    ptr.pointee.ifa_addr.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { sin6 in
                        var in6Addr = sin6.pointee.sin6_addr
                        inet_ntop(AF_INET6, &in6Addr, &addr, socklen_t(INET6_ADDRSTRLEN))
                    }
                    let v6 = String(cString: addr)
                    if !v6.hasPrefix("fe80") { // Skip link-local
                        ipv6 = v6
                    }
                }
            }
            guard let next = ptr.pointee.ifa_next else { break }
            ptr = next
        }
        return (ipv4, ipv6)
    }

    private func getMACAddress(name: String, firstAddr: UnsafeMutablePointer<ifaddrs>) -> String {
        var ptr = firstAddr
        while true {
            let ifName = String(cString: ptr.pointee.ifa_name)
            if ifName == name {
                let family = ptr.pointee.ifa_addr.pointee.sa_family
                if family == UInt8(AF_LINK) {
                    let sdl = ptr.pointee.ifa_addr.withMemoryRebound(to: sockaddr_dl.self, capacity: 1) { $0.pointee }
                    let macLen = Int(sdl.sdl_alen)
                    if macLen == 6 {
                        let macBytes = withUnsafePointer(to: sdl.sdl_data) { ptr in
                            let start = UnsafeRawPointer(ptr).advanced(by: Int(sdl.sdl_nlen))
                            return (0..<6).map { start.load(fromByteOffset: $0, as: UInt8.self) }
                        }
                        return macBytes.map { String(format: "%02x", $0) }.joined(separator: ":")
                    }
                }
            }
            guard let next = ptr.pointee.ifa_next else { break }
            ptr = next
        }
        return ""
    }

    private func detectWiFiInterfaceName() -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        proc.arguments = ["-listallhardwareports"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        try? proc.run()
        proc.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let lines = output.components(separatedBy: "\n")
        for (i, line) in lines.enumerated() where line.contains("Wi-Fi") {
            if i + 1 < lines.count, let match = lines[i+1].range(of: "Device: ") {
                return String(lines[i+1][match.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    // MARK: - Wi-Fi info

    private func getWiFiInfo(name: String) -> (ssid: String?, signalDBm: Int?, band: String?, channel: Int?) {
        // Try CWWiFiClient first (needs Location Services on macOS 14+).
        if let iface = CWWiFiClient.shared().interface(withName: name) {
            let ssid = iface.ssid()
            if let ssid = ssid {
                let rssi = Int(iface.rssiValue())
                let channel = iface.wlanChannel()
                let channelNumber = channel.map { Int($0.channelNumber) }
                let band: String? = channel.map { ch in
                    switch ch.channelBand {
                    case .band2GHz: return "2.4 GHz"
                    case .band5GHz: return "5 GHz"
                    case .band6GHz: return "6 GHz"
                    default:        return "Unknown"
                    }
                }
                return (ssid, rssi != 0 ? rssi : nil, band, channelNumber)
            }
        }

        // Fallback: use networksetup for SSID (doesn't need Location Services).
        if isWiFiInterface(name: name) {
            let ssid = getSSIDViaShell()
            if let ssid = ssid {
                return (ssid, nil, nil, nil)
            }
            // Return nil SSID when unresolvable. Returning a synthetic string
            // like "Wi-Fi (SSID unavailable)" would create a fake bucket id
            // that diverges from the real SSID once it resolves, producing
            // ghost rows in the Network tab. nil is the honest signal for
            // "this is a Wi-Fi interface but we couldn't read the SSID yet".
            return (nil, nil, nil, nil)
        }

        return (nil, nil, nil, nil)
    }

    private func isWiFiInterface(name: String) -> Bool {
        if cachedWiFiInterface == nil {
            cachedWiFiInterface = detectWiFiInterfaceName() ?? ""
        }
        return cachedWiFiInterface == name
    }

    private var cachedSSID: String?
    private var lastSSIDCheck: Date = .distantPast

    private func getSSIDViaShell() -> String? {
        if Date().timeIntervalSince(lastSSIDCheck) < 30, let cached = cachedSSID {
            return cached
        }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/networksetup")
        proc.arguments = ["-getairportnetwork", cachedWiFiInterface ?? "en0"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        try? proc.run()
        proc.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if let range = output.range(of: "Current Wi-Fi Network: ") {
            let ssid = String(output[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !ssid.isEmpty && !ssid.contains("not associated") {
                cachedSSID = ssid
                lastSSIDCheck = Date()
                return ssid
            }
        }
        lastSSIDCheck = Date()
        return nil
    }
}

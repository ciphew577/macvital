import Foundation

public struct NetworkInterface: Codable, Sendable, Identifiable {
    public var id: String { name }
    public let name: String
    public let macAddress: String
    public var ipv4Address: String
    public var ipv6Address: String
    public var linkSpeed: String
    public var txBytes: UInt64
    public var rxBytes: UInt64
    public var txBytesPerSec: UInt64
    public var rxBytesPerSec: UInt64
    public var errorsIn: UInt64
    public var errorsOut: UInt64
    public var packetsIn: UInt64
    public var packetsOut: UInt64
    // WiFi-specific (nil for non-WiFi interfaces)
    public var wifiSSID: String?
    public var wifiSignalDBm: Int?
    public var wifiBand: String?
    public var wifiChannel: Int?

    public init(name: String, macAddress: String, ipv4Address: String, ipv6Address: String,
                linkSpeed: String, txBytes: UInt64, rxBytes: UInt64,
                txBytesPerSec: UInt64, rxBytesPerSec: UInt64,
                errorsIn: UInt64, errorsOut: UInt64, packetsIn: UInt64, packetsOut: UInt64,
                wifiSSID: String? = nil, wifiSignalDBm: Int? = nil,
                wifiBand: String? = nil, wifiChannel: Int? = nil) {
        self.name = name; self.macAddress = macAddress; self.ipv4Address = ipv4Address
        self.ipv6Address = ipv6Address; self.linkSpeed = linkSpeed
        self.txBytes = txBytes; self.rxBytes = rxBytes
        self.txBytesPerSec = txBytesPerSec; self.rxBytesPerSec = rxBytesPerSec
        self.errorsIn = errorsIn; self.errorsOut = errorsOut
        self.packetsIn = packetsIn; self.packetsOut = packetsOut
        self.wifiSSID = wifiSSID; self.wifiSignalDBm = wifiSignalDBm
        self.wifiBand = wifiBand; self.wifiChannel = wifiChannel
    }
}

public struct NetworkData: Codable, Sendable {
    public var interfaces: [NetworkInterface]
    /// Per-(interface, SSID) buckets. Active interface entries appear first,
    /// followed by archived entries for SSIDs previously joined this session.
    /// See `NetworkInterfaceInfo` for why this lives alongside `interfaces`.
    public var interfaceInfos: [NetworkInterfaceInfo]

    public var totalTxBytesPerSec: UInt64 {
        interfaces.reduce(0) { $0 + $1.txBytesPerSec }
    }
    public var totalRxBytesPerSec: UInt64 {
        interfaces.reduce(0) { $0 + $1.rxBytesPerSec }
    }

    public init(interfaces: [NetworkInterface], interfaceInfos: [NetworkInterfaceInfo] = []) {
        self.interfaces = interfaces
        self.interfaceInfos = interfaceInfos
    }
}

// MARK: - Per-WiFi history models (mock data; production: background daemon + SQLite)

public enum NetworkConnectionStatus: String, Sendable {
    case connected = "Connected"
    case idle      = "Idle"
    case offline   = "Offline"

    /// Lower = higher priority when sorting ascending (connected first)
    public var sortOrder: Int {
        switch self {
        case .connected: return 0
        case .idle:      return 1
        case .offline:   return 2
        }
    }
}

public struct NetworkProcessEntry: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let pid: Int
    public let appName: String
    public var dnSpeedMBs: Double
    public var upSpeedMBs: Double
    public var totalBytes: UInt64
    public let proto: String

    public init(id: String, name: String, pid: Int, appName: String,
                dnSpeedMBs: Double, upSpeedMBs: Double, totalBytes: UInt64, proto: String) {
        self.id = id; self.name = name; self.pid = pid; self.appName = appName
        self.dnSpeedMBs = dnSpeedMBs; self.upSpeedMBs = upSpeedMBs
        self.totalBytes = totalBytes; self.proto = proto
    }
}

public struct NetworkDomainEntry: Identifiable, Sendable {
    public let id: String
    public let name: String
    public var downBytes: UInt64
    public var upBytes: UInt64
    public let proto: String
    public let flag: String
    public let apps: [String]

    public init(id: String, name: String, downBytes: UInt64, upBytes: UInt64,
                proto: String, flag: String, apps: [String]) {
        self.id = id; self.name = name; self.downBytes = downBytes; self.upBytes = upBytes
        self.proto = proto; self.flag = flag; self.apps = apps
    }
}

public struct NetworkAppEntry: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let icon: String
    public var downBytes: UInt64
    public var upBytes: UInt64
    public var processes: [NetworkProcessEntry]
    public var domains: [NetworkDomainEntry]
    public var totalBytes: UInt64 { downBytes + upBytes }

    public init(id: String, name: String, icon: String,
                downBytes: UInt64, upBytes: UInt64,
                processes: [NetworkProcessEntry], domains: [NetworkDomainEntry]) {
        self.id = id; self.name = name; self.icon = icon
        self.downBytes = downBytes; self.upBytes = upBytes
        self.processes = processes; self.domains = domains
    }
}

public struct NetworkHistoryEntry: Identifiable, Sendable {
    public let id: String
    public let ssid: String
    public var status: NetworkConnectionStatus
    public var downBytes: UInt64
    public var upBytes: UInt64
    public var sessionCount: Int
    public var firstSeen: Date
    public var lastSeen: Date
    public var band: String
    public var signalDBm: Int
    public var snrDB: Int?
    public var mcsIndex: Int?
    public var channelNumber: Int?
    public var apps: [NetworkAppEntry]
    public var totalBytes: UInt64 { downBytes + upBytes }

    public init(id: String, ssid: String, status: NetworkConnectionStatus,
                downBytes: UInt64, upBytes: UInt64, sessionCount: Int,
                firstSeen: Date, lastSeen: Date, band: String, signalDBm: Int,
                snrDB: Int? = nil, mcsIndex: Int? = nil, channelNumber: Int? = nil,
                apps: [NetworkAppEntry]) {
        self.id = id; self.ssid = ssid; self.status = status
        self.downBytes = downBytes; self.upBytes = upBytes; self.sessionCount = sessionCount
        self.firstSeen = firstSeen; self.lastSeen = lastSeen
        self.band = band; self.signalDBm = signalDBm
        self.snrDB = snrDB; self.mcsIndex = mcsIndex; self.channelNumber = channelNumber
        self.apps = apps
    }
}

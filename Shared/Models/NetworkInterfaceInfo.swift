// Shared/Models/NetworkInterfaceInfo.swift
//
// Per-interface, per-SSID attribution model for the Network tab.
//
// Motivation: the original `NetworkInterface` aggregates all lifetime bytes
// for an interface name (en0, en1, ...). When the user switches Wi-Fi networks
// the SSID changes but the en0 counters keep climbing, so a single row was
// showing "Home Wi-Fi + Cafe Wi-Fi + Phone hotspot" merged together.
//
// `NetworkInterfaceInfo` instead represents one bucket per unique
// (bsdName, ssid) pair. The reader tracks these buckets across polls using
// byte deltas, so the moment the SSID flips a brand-new bucket is created
// and the previous one is frozen with its final totals.
//
// Session totals are wall-clock since the app launched. Persistent totals
// (days / weeks / months) will be filled in by NetworkUsageStore once the
// persistence agent lands.
import Foundation

public enum NetworkInterfaceType: String, Codable, Sendable {
    case wifi       = "Wi-Fi"
    case ethernet   = "Ethernet"
    case usbTether  = "iPhone USB"
    case vpn        = "VPN"
    case thunderbolt = "Thunderbolt"
    case bluetooth  = "Bluetooth"
    case loopback   = "Loopback"
    case other      = "Other"

    public var sfSymbol: String {
        switch self {
        case .wifi:        return "wifi"
        case .ethernet:    return "cable.connector"
        case .usbTether:   return "iphone.gen3"
        case .vpn:         return "lock.shield"
        case .thunderbolt: return "bolt.horizontal"
        case .bluetooth:   return "b.circle"
        case .loopback:    return "arrow.triangle.2.circlepath"
        case .other:       return "network"
        }
    }
}

/// A single (interface, SSID) bucket of network usage.
///
/// `id` is stable across polls for the same (bsdName, ssid) pair so SwiftUI
/// can animate updates in place. Switching SSIDs yields a new `id`.
public struct NetworkInterfaceInfo: Codable, Sendable, Identifiable {
    public let id: String
    public let bsdName: String          // en0, en1, en8, utun3, ...
    public let type: NetworkInterfaceType
    public let displayName: String      // "Wi-Fi", "Ethernet", "iPhone USB", "VPN (utun3)"
    public let currentSSID: String?     // nil for non-Wi-Fi
    public let isActive: Bool           // has IPv4 and is up
    public let linkSpeedMbps: Int?      // best-effort, nil if unknown
    public let ipv4Address: String
    public let ipv6Address: String
    public let macAddress: String
    public let wifiSignalDBm: Int?
    public let wifiBand: String?
    public let wifiChannel: Int?

    /// Bytes received in the current (interface, SSID) session.
    public let sessionBytesIn: UInt64
    /// Bytes sent in the current (interface, SSID) session.
    public let sessionBytesOut: UInt64
    /// Instantaneous receive rate (bytes/sec) for this bucket.
    public let bytesInPerSec: UInt64
    /// Instantaneous transmit rate (bytes/sec) for this bucket.
    public let bytesOutPerSec: UInt64
    /// When this bucket first appeared during the current app session.
    public let firstSeen: Date
    /// Most recent poll that saw this bucket active.
    public let lastSeen: Date

    public init(id: String,
                bsdName: String,
                type: NetworkInterfaceType,
                displayName: String,
                currentSSID: String?,
                isActive: Bool,
                linkSpeedMbps: Int?,
                ipv4Address: String,
                ipv6Address: String,
                macAddress: String,
                wifiSignalDBm: Int?,
                wifiBand: String?,
                wifiChannel: Int?,
                sessionBytesIn: UInt64,
                sessionBytesOut: UInt64,
                bytesInPerSec: UInt64,
                bytesOutPerSec: UInt64,
                firstSeen: Date,
                lastSeen: Date) {
        self.id = id
        self.bsdName = bsdName
        self.type = type
        self.displayName = displayName
        self.currentSSID = currentSSID
        self.isActive = isActive
        self.linkSpeedMbps = linkSpeedMbps
        self.ipv4Address = ipv4Address
        self.ipv6Address = ipv6Address
        self.macAddress = macAddress
        self.wifiSignalDBm = wifiSignalDBm
        self.wifiBand = wifiBand
        self.wifiChannel = wifiChannel
        self.sessionBytesIn = sessionBytesIn
        self.sessionBytesOut = sessionBytesOut
        self.bytesInPerSec = bytesInPerSec
        self.bytesOutPerSec = bytesOutPerSec
        self.firstSeen = firstSeen
        self.lastSeen = lastSeen
    }
}

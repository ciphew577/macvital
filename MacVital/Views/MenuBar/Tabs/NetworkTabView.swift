// MacVital/Views/MenuBar/Tabs/NetworkTabView.swift
//
// Network tab — Wi-Fi (SSID · RSSI · linkSpeed · live ↓/↑) plus VPN
// (utun*) and session totals across all interfaces.

import SwiftUI

struct NetworkTabView: View {
    let monitor: SystemMonitor

    private var wifiInterface: NetworkInterface? {
        monitor.network?.interfaces.first(where: { $0.wifiSSID != nil })
    }

    private var vpnInterface: NetworkInterface? {
        monitor.network?.interfaces.first(where: { $0.name.hasPrefix("utun") })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            wifiSection
            vpnSection
            totalsSection
        }
    }

    // MARK: - Wi-Fi

    @ViewBuilder
    private var wifiSection: some View {
        if let wifi = wifiInterface {
            let downHistory = monitor.networkDownHistory.suffix(40).map { Double($0) }
            let downMBs = Double(wifi.rxBytesPerSec) / 1_048_576
            let upMBs = Double(wifi.txBytesPerSec) / 1_048_576

            VStack(alignment: .leading, spacing: 0) {
                MenuBarSectionHead(
                    "Wi-Fi · \(wifi.name)",
                    meta: wifi.wifiBand ?? "Wi-Fi"
                )
                MenuBarTabRow(
                    iconSystemName: "wifi",
                    iconColor: MVMenu.wifi,
                    label: wifi.wifiSSID ?? "—",
                    meta: wifi.wifiChannel.map { "ch \($0)" },
                    value: wifi.wifiSignalDBm.map { "\($0)" } ?? "—",
                    unit: " dBm"
                )
                MenuBarTabRow(
                    iconColor: MVMenu.wifi,
                    label: "Link rate",
                    value: wifi.linkSpeed.isEmpty ? "—" : wifi.linkSpeed,
                    unit: nil
                )
                MenuBarTabRow(
                    iconColor: MVMenu.wifi,
                    label: "↓ now · ↑ now",
                    history: downHistory,
                    value: String(format: "%.1f · %.1f", downMBs, upMBs),
                    unit: " MB/s"
                )
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                MenuBarSectionHead("Wi-Fi", meta: "no signal")
                MenuBarTabRow(
                    iconSystemName: "wifi.slash",
                    iconColor: MVMenu.textFaint,
                    label: "Not connected",
                    value: "—"
                )
            }
        }
    }

    // MARK: - VPN

    @ViewBuilder
    private var vpnSection: some View {
        if let vpn = vpnInterface {
            VStack(alignment: .leading, spacing: 0) {
                MenuBarSectionHead("VPN · \(vpn.name)", meta: "tunnel")
                MenuBarTabRow(
                    iconSystemName: "lock.shield",
                    iconColor: MVMenu.wifi,
                    label: "Address",
                    value: vpn.ipv4Address.isEmpty ? "—" : vpn.ipv4Address
                )
                MenuBarTabRow(
                    iconColor: MVMenu.wifi,
                    label: "↓ session · ↑ session",
                    value: String(format: "%@ · %@",
                                  formatBytes(vpn.rxBytes),
                                  formatBytes(vpn.txBytes))
                )
            }
        }
    }

    // MARK: - Session totals

    private var totalsSection: some View {
        let allRx = monitor.network?.interfaces.map(\.rxBytes).reduce(0, +) ?? 0
        let allTx = monitor.network?.interfaces.map(\.txBytes).reduce(0, +) ?? 0

        return VStack(alignment: .leading, spacing: 0) {
            MenuBarSectionHead("Session totals", meta: "all interfaces")
            MenuBarTabRow(
                iconSystemName: "arrow.down",
                iconColor: MVMenu.textFaint,
                label: "Downloaded",
                value: formatBytes(allRx)
            )
            MenuBarTabRow(
                iconSystemName: "arrow.up",
                iconColor: MVMenu.textFaint,
                label: "Uploaded",
                value: formatBytes(allTx)
            )
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let bcf = ByteCountFormatter()
        bcf.allowedUnits = [.useGB, .useMB, .useKB]
        bcf.countStyle = .binary
        bcf.includesUnit = true
        return bcf.string(fromByteCount: Int64(bytes))
    }
}

// MacVital/Views/Report/HTMLReportGenerator.swift
import Foundation

enum HTMLReportGenerator {

    static func generate(from report: DiagnosticReport) -> String {
        let scoreColor = report.overallHealthScore >= 90 ? "#34C759" : (report.overallHealthScore >= 60 ? "#FF9500" : "#FF3B30")

        func statusColor(_ status: HealthStatus) -> String {
            switch status {
            case .good: return "#34C759"
            case .warning: return "#FF9500"
            case .critical: return "#FF3B30"
            }
        }

        func smartStatusColor(_ status: SMARTStatus) -> String {
            switch status {
            case .good: return "#34C759"
            case .warning: return "#FF9500"
            case .critical: return "#FF3B30"
            case .unknown: return "#8E8E93"
            }
        }

        var html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>MacVital Health Report</title>
        <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'SF Pro', system-ui, sans-serif; background: #1a1a2e; color: #e0e0e0; padding: 40px; max-width: 900px; margin: 0 auto; }
        h1 { font-size: 28px; margin-bottom: 8px; }
        h2 { font-size: 20px; margin: 30px 0 12px; padding-bottom: 8px; border-bottom: 1px solid #333; }
        h3 { font-size: 16px; margin: 16px 0 8px; }
        .meta { color: #8E8E93; font-size: 14px; margin-bottom: 4px; }
        .score { font-size: 48px; font-weight: bold; margin: 20px 0; }
        .card { background: rgba(255,255,255,0.05); border-radius: 12px; padding: 16px; margin: 8px 0; backdrop-filter: blur(10px); }
        .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 8px; margin: 8px 0; }
        .metric { background: rgba(255,255,255,0.03); border-radius: 8px; padding: 12px; }
        .metric .label { font-size: 11px; color: #8E8E93; text-transform: uppercase; letter-spacing: 0.5px; }
        .metric .value { font-size: 18px; font-weight: 600; margin-top: 4px; font-variant-numeric: tabular-nums; }
        .metric .unit { font-size: 11px; color: #8E8E93; }
        .badge { display: inline-block; padding: 2px 8px; border-radius: 10px; font-size: 11px; font-weight: 500; }
        table { width: 100%; border-collapse: collapse; margin: 8px 0; font-size: 13px; }
        th, td { padding: 8px 12px; text-align: left; border-bottom: 1px solid #2a2a3e; }
        th { color: #8E8E93; font-weight: 500; font-size: 11px; text-transform: uppercase; letter-spacing: 0.5px; }
        th[onclick] { cursor: pointer; user-select: none; }
        th[onclick]:hover { color: #e0e0e0; }
        code { font-family: 'SF Mono', 'Monaco', 'Menlo', monospace; font-size: 11px; background: rgba(255,255,255,0.06); padding: 1px 4px; border-radius: 3px; }
        .tooltip { cursor: help; border-bottom: 1px dotted #555; }
        details { margin: 8px 0; }
        details summary { cursor: pointer; font-weight: 500; padding: 8px 0; list-style: none; }
        details summary::before { content: '▶ '; font-size: 10px; }
        details[open] summary::before { content: '▼ '; }
        .rec { padding: 8px 12px; margin: 4px 0; background: rgba(255,200,0,0.05); border-left: 3px solid #FF9500; border-radius: 0 8px 8px 0; }
        .section-label { font-size: 11px; color: #8E8E93; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 4px; }
        @media (prefers-color-scheme: light) {
            body { background: #f5f5f7; color: #1d1d1f; }
            .card { background: rgba(0,0,0,0.03); }
            .metric { background: rgba(0,0,0,0.02); }
            th, td { border-bottom-color: #d2d2d7; }
            code { background: rgba(0,0,0,0.06); }
            h2 { border-bottom-color: #d2d2d7; }
        }
        </style>
        <script>
        function sortTable(tableId, col) {
            const table = document.getElementById(tableId);
            if (!table) return;
            const tbody = table.querySelector('tbody') || table;
            const rows = Array.from(tbody.querySelectorAll('tr'));
            const asc = table.dataset.sortCol == col && table.dataset.sortDir == 'asc';
            rows.sort((a, b) => {
                const av = a.cells[col]?.textContent.trim() || '';
                const bv = b.cells[col]?.textContent.trim() || '';
                const an = parseFloat(av), bn = parseFloat(bv);
                if (!isNaN(an) && !isNaN(bn)) return asc ? bn - an : an - bn;
                return asc ? bv.localeCompare(av) : av.localeCompare(bv);
            });
            rows.forEach(r => tbody.appendChild(r));
            table.dataset.sortCol = col;
            table.dataset.sortDir = asc ? 'desc' : 'asc';
        }
        </script>
        </head>
        <body>
        <h1>MacVital Health Report</h1>
        <p class="meta">\(escapeHTML(report.macModel)) &mdash; macOS \(escapeHTML(report.macOSVersion))</p>
        <p class="meta">\(escapeHTML(report.chipType)) &mdash; S/N: \(escapeHTML(report.serialNumber))</p>
        <p class="meta">Generated: \(report.timestamp.formatted())</p>
        <div class="score" style="color: \(scoreColor)">\(Int(report.overallHealthScore))%</div>

        <h2>Health Scores</h2>
        <div class="grid">
        """

        for score in report.healthScores {
            let color = statusColor(score.status)
            html += """
            <div class="metric">
                <div class="label">\(escapeHTML(score.component))</div>
                <div class="value" style="color: \(color)">\(Int(score.score))%</div>
                <div class="unit">\(escapeHTML(score.detail))</div>
            </div>
            """
        }

        html += "</div>"

        // CPU
        html += "<h2>CPU</h2><div class=\"card\">"
        html += "<div class=\"grid\">"
        html += metric("Total Usage", "\(String(format: "%.1f", report.cpu.totalUsage))%")
        html += metric("User", "\(String(format: "%.1f", report.cpu.userUsage))%")
        html += metric("System", "\(String(format: "%.1f", report.cpu.systemUsage))%")
        html += metric("Idle", "\(String(format: "%.1f", report.cpu.idleUsage))%")
        html += metric("Cores", "\(report.cpu.coreCount) (\(report.cpu.performanceCoreCount)P + \(report.cpu.efficiencyCoreCount)E)")
        html += "</div>"

        if !report.cpu.cores.isEmpty {
            html += "<details><summary>Per-Core Details (\(report.cpu.cores.count) cores)</summary>"
            html += "<table id=\"coreTable\"><thead><tr><th onclick=\"sortTable('coreTable',0)\">Core</th><th onclick=\"sortTable('coreTable',1)\">Type</th><th onclick=\"sortTable('coreTable',2)\">Usage</th><th onclick=\"sortTable('coreTable',3)\">Temp</th><th onclick=\"sortTable('coreTable',4)\">Frequency</th><th onclick=\"sortTable('coreTable',5)\">Power</th></tr></thead><tbody>"
            for core in report.cpu.cores {
                let freqStr = core.frequency > 0 ? "\(core.frequency) MHz" : "—"
                html += "<tr><td>\(core.id)</td><td>\(core.clusterType.rawValue)</td><td>\(String(format: "%.1f", core.usage))%</td><td>\(Int(core.temperature))°C</td><td>\(freqStr)</td><td>\(String(format: "%.2f", core.power)) W</td></tr>"
            }
            html += "</tbody></table></details>"
        }

        if !report.cpu.topProcesses.isEmpty {
            html += "<details><summary>Top Processes</summary>"
            html += "<table><thead><tr><th>PID</th><th>Name</th><th>CPU %</th><th>Memory</th></tr></thead><tbody>"
            for proc in report.cpu.topProcesses {
                html += "<tr><td>\(proc.id)</td><td>\(escapeHTML(proc.name))</td><td>\(String(format: "%.1f", proc.cpuUsage))%</td><td>\(ByteFormatter.format(proc.memoryBytes))</td></tr>"
            }
            html += "</tbody></table></details>"
        }
        html += "</div>"

        // Memory
        html += "<h2>Memory</h2><div class=\"card\"><div class=\"grid\">"
        html += metric("Total", ByteFormatter.format(report.memory.total))
        html += metric("Used", ByteFormatter.format(report.memory.used))
        html += metric("Free", ByteFormatter.format(report.memory.free))
        html += metric("Wired", ByteFormatter.format(report.memory.wired))
        html += metric("Active", ByteFormatter.format(report.memory.active))
        html += metric("Inactive", ByteFormatter.format(report.memory.inactive))
        html += metric("Compressed", ByteFormatter.format(report.memory.compressed))
        html += metric("Purgeable", ByteFormatter.format(report.memory.purgeable))
        html += metric("Swap Used", ByteFormatter.format(report.memory.swapUsed))
        html += metric("Swap Free", ByteFormatter.format(report.memory.swapFree))
        html += metric("Pressure", report.memory.pressureLevel.rawValue)
        html += "</div>"

        if !report.memory.topProcesses.isEmpty {
            html += "<details><summary>Memory Hogs</summary>"
            html += "<table><thead><tr><th>PID</th><th>Name</th><th>Memory</th><th>CPU %</th></tr></thead><tbody>"
            for proc in report.memory.topProcesses {
                html += "<tr><td>\(proc.id)</td><td>\(escapeHTML(proc.name))</td><td>\(ByteFormatter.format(proc.memoryBytes))</td><td>\(String(format: "%.1f", proc.cpuUsage))%</td></tr>"
            }
            html += "</tbody></table></details>"
        }
        html += "</div>"

        // Storage
        html += "<h2>Storage</h2><div class=\"card\">"
        html += "<div class=\"grid\">"
        html += metric("Drive Health", "\(Int(report.storage.healthPercent))%")
        html += metric("Read Speed", ByteFormatter.format(report.storage.readBytesPerSec) + "/s")
        html += metric("Write Speed", ByteFormatter.format(report.storage.writeBytesPerSec) + "/s")
        html += "</div>"

        for vol in report.storage.volumes {
            let pct = vol.totalBytes > 0 ? Int(Double(vol.usedBytes) / Double(vol.totalBytes) * 100) : 0
            html += "<h3>\(escapeHTML(vol.name)) (\(escapeHTML(vol.mountPoint)))</h3><div class=\"grid\">"
            html += metric("Used", ByteFormatter.format(vol.usedBytes))
            html += metric("Free", ByteFormatter.format(vol.freeBytes))
            html += metric("Total", ByteFormatter.format(vol.totalBytes))
            html += metric("Usage", "\(pct)%")
            html += metric("Filesystem", escapeHTML(vol.fileSystem))
            html += "</div>"
        }

        if !report.storage.smartAttributes.isEmpty {
            html += "<details open><summary>S.M.A.R.T. Attributes</summary>"
            html += "<table id=\"smartTable\"><thead><tr><th onclick=\"sortTable('smartTable',0)\">ID</th><th onclick=\"sortTable('smartTable',1)\">Attribute</th><th onclick=\"sortTable('smartTable',2)\">Value</th><th onclick=\"sortTable('smartTable',3)\">Threshold</th><th onclick=\"sortTable('smartTable',4)\">Status</th></tr></thead><tbody>"
            for attr in report.storage.smartAttributes {
                let color = smartStatusColor(attr.status)
                html += "<tr><td>\(attr.id)</td><td class=\"tooltip\" title=\"\(escapeHTML(attr.explanation))\">\(escapeHTML(attr.name))</td><td>\(escapeHTML(attr.rawValue))</td><td>\(escapeHTML(attr.threshold))</td><td><span class=\"badge\" style=\"background: \(color)22; color: \(color)\">\(attr.status.rawValue)</span></td></tr>"
            }
            html += "</tbody></table></details>"
        }
        html += "</div>"

        // Battery
        if let bat = report.battery {
            html += "<h2>Battery</h2><div class=\"card\"><div class=\"grid\">"
            html += metric("Health", "\(String(format: "%.1f", bat.healthPercent))%")
            html += metric("Design Capacity", "\(bat.designCapacity) mAh")
            html += metric("Max Capacity", "\(bat.maxCapacity) mAh")
            html += metric("Current Charge", "\(bat.currentCharge) mAh")
            html += metric("Charge Level", "\(String(format: "%.1f", bat.percentage))%")
            html += metric("Cycle Count", "\(bat.cycleCount)")
            html += metric("Temperature", "\(String(format: "%.1f", bat.temperature))°C")
            html += metric("Voltage", "\(String(format: "%.2f", bat.voltage)) V")
            html += metric("Amperage", "\(bat.amperage) mA")
            html += metric("Wattage", "\(String(format: "%.1f", bat.wattage)) W")
            html += metric("Charging", bat.isCharging ? "Yes" : "No")
            html += metric("Fully Charged", bat.isFullyCharged ? "Yes" : "No")
            let timeStr = bat.timeRemaining >= 0 ? "\(bat.timeRemaining / 60)h \(bat.timeRemaining % 60)m" : "Calculating"
            html += metric("Time Remaining", timeStr)
            html += metric("Condition", escapeHTML(bat.condition))
            html += metric("Manufacture Date", escapeHTML(bat.manufactureDate))
            html += metric("Serial Number", escapeHTML(bat.serialNumber))
            html += "</div></div>"
        }

        // Sensors
        html += "<h2>Sensors</h2><div class=\"card\">"
        if !report.sensors.sensors.isEmpty {
            html += "<table id=\"sensorTable\"><thead><tr><th onclick=\"sortTable('sensorTable',0)\">Name</th><th onclick=\"sortTable('sensorTable',1)\">Key</th><th onclick=\"sortTable('sensorTable',2)\">Value</th><th onclick=\"sortTable('sensorTable',3)\">Category</th></tr></thead><tbody>"
            for sensor in report.sensors.sensors {
                html += "<tr><td>\(escapeHTML(sensor.name))</td><td><code>\(escapeHTML(sensor.key))</code></td><td>\(String(format: "%.1f", sensor.value))\(escapeHTML(sensor.unit))</td><td>\(sensor.category.rawValue)</td></tr>"
            }
            html += "</tbody></table>"
        }
        if !report.sensors.fans.isEmpty {
            html += "<h3>Fans</h3><table><thead><tr><th>Name</th><th>RPM</th><th>Min RPM</th><th>Max RPM</th></tr></thead><tbody>"
            for fan in report.sensors.fans {
                html += "<tr><td>\(escapeHTML(fan.name))</td><td>\(fan.rpm)</td><td>\(fan.minRPM)</td><td>\(fan.maxRPM)</td></tr>"
            }
            html += "</tbody></table>"
        }
        html += "</div>"

        // GPU
        html += "<h2>GPU</h2><div class=\"card\"><div class=\"grid\">"
        html += metric("Utilization", "\(String(format: "%.1f", report.gpu.utilization))%")
        html += metric("VRAM Used", ByteFormatter.format(report.gpu.vramUsed))
        html += metric("VRAM Total", ByteFormatter.format(report.gpu.vramTotal))
        html += metric("Temperature", "\(String(format: "%.0f", report.gpu.temperature))°C")
        html += metric("Frequency", report.gpu.frequency > 0 ? "\(report.gpu.frequency) MHz" : "—")
        html += metric("Encoder", "\(String(format: "%.1f", report.gpu.encoderUtilization))%")
        html += metric("Decoder", "\(String(format: "%.1f", report.gpu.decoderUtilization))%")
        html += "</div></div>"

        // Network
        html += "<h2>Network</h2><div class=\"card\">"
        for iface in report.network.interfaces {
            html += "<h3>\(escapeHTML(iface.name))"
            if !iface.linkSpeed.isEmpty { html += " <span style=\"color:#8E8E93; font-size:13px; font-weight:400\">(\(escapeHTML(iface.linkSpeed)))</span>" }
            html += "</h3><div class=\"grid\">"
            html += metric("IPv4", iface.ipv4Address.isEmpty ? "—" : escapeHTML(iface.ipv4Address))
            html += metric("IPv6", iface.ipv6Address.isEmpty ? "—" : escapeHTML(iface.ipv6Address))
            html += metric("MAC", iface.macAddress.isEmpty ? "—" : escapeHTML(iface.macAddress))
            html += metric("TX Total", ByteFormatter.format(iface.txBytes))
            html += metric("RX Total", ByteFormatter.format(iface.rxBytes))
            html += metric("TX Rate", ByteFormatter.format(iface.txBytesPerSec) + "/s")
            html += metric("RX Rate", ByteFormatter.format(iface.rxBytesPerSec) + "/s")
            html += metric("Packets In", "\(iface.packetsIn)")
            html += metric("Packets Out", "\(iface.packetsOut)")
            html += metric("Errors In", "\(iface.errorsIn)")
            html += metric("Errors Out", "\(iface.errorsOut)")
            html += "</div>"
        }
        html += "</div>"

        // Recommendations
        html += "<h2>Recommendations</h2>"
        if report.recommendations.isEmpty {
            html += "<p class=\"meta\">No recommendations — system is healthy.</p>"
        } else {
            for rec in report.recommendations {
                html += "<div class=\"rec\">\(escapeHTML(rec))</div>"
            }
        }

        html += """
        <p style="margin-top: 40px; text-align: center; color: #8E8E93; font-size: 12px;">
        Generated by MacVital &mdash; \(report.timestamp.formatted())
        </p>
        </body></html>
        """

        return html
    }

    private static func metric(_ label: String, _ value: String) -> String {
        """
        <div class="metric">
            <div class="label">\(label)</div>
            <div class="value">\(value)</div>
        </div>
        """
    }

    private static func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}

// MacVital/Views/Report/PDFReportGenerator.swift
import SwiftUI
import PDFKit

enum PDFReportGenerator {

    @MainActor
    static func generate(from report: DiagnosticReport) -> Data {
        let pageWidth: CGFloat = 612  // US Letter
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50

        let pdfData = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        guard let consumer = CGDataConsumer(data: pdfData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return Data()
        }

        let contentWidth = pageWidth - margin * 2
        var y: CGFloat = 0

        func newPage() {
            if y != 0 { context.endPDFPage() }
            context.beginPDFPage(nil)
            y = pageHeight - margin
        }

        func drawText(_ text: String, x: CGFloat, fontSize: CGFloat = 12, bold: Bool = false, color: NSColor = .labelColor) {
            let font: NSFont = bold ? .boldSystemFont(ofSize: fontSize) : .systemFont(ofSize: fontSize)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
            let str = NSAttributedString(string: text, attributes: attrs)
            let size = str.size()

            if y - size.height < margin {
                newPage()
            }

            let rect = CGRect(x: x, y: y - size.height, width: contentWidth, height: size.height)
            context.saveGState()
            // Flip for text drawing
            context.translateBy(x: 0, y: rect.origin.y + rect.height)
            context.scaleBy(x: 1, y: -1)
            str.draw(in: CGRect(x: rect.origin.x, y: 0, width: rect.width, height: rect.height))
            context.restoreGState()
            y -= size.height + 4
        }

        func drawLine() {
            context.setStrokeColor(NSColor.separatorColor.cgColor)
            context.setLineWidth(0.5)
            context.move(to: CGPoint(x: margin, y: y))
            context.addLine(to: CGPoint(x: pageWidth - margin, y: y))
            context.strokePath()
            y -= 10
        }

        // Cover page
        newPage()
        y = pageHeight - 200
        drawText("MacVital Health Report", x: margin, fontSize: 28, bold: true)
        y -= 10
        drawText(report.macModel, x: margin, fontSize: 16, color: .secondaryLabelColor)
        drawText("macOS \(report.macOSVersion)", x: margin, fontSize: 14, color: .secondaryLabelColor)
        drawText(report.chipType, x: margin, fontSize: 14, color: .secondaryLabelColor)
        drawText("Generated: \(report.timestamp.formatted())", x: margin, fontSize: 12, color: .tertiaryLabelColor)
        y -= 30

        let scoreColor: NSColor = report.overallHealthScore >= 90 ? .systemGreen : (report.overallHealthScore >= 60 ? .systemOrange : .systemRed)
        drawText("Overall Health: \(Int(report.overallHealthScore))%", x: margin, fontSize: 24, bold: true, color: scoreColor)
        y -= 20
        drawLine()

        // Health scores
        drawText("Component Health Scores", x: margin, fontSize: 18, bold: true)
        y -= 5
        for score in report.healthScores {
            let color: NSColor = score.status == .good ? .systemGreen : (score.status == .warning ? .systemOrange : .systemRed)
            drawText("\(score.component): \(Int(score.score))% — \(score.detail)", x: margin + 10, fontSize: 12, color: color)
        }
        y -= 10

        // CPU
        drawLine()
        drawText("CPU", x: margin, fontSize: 18, bold: true)
        drawText("Total Usage: \(String(format: "%.1f", report.cpu.totalUsage))%", x: margin + 10)
        drawText("User Usage: \(String(format: "%.1f", report.cpu.userUsage))%", x: margin + 10)
        drawText("System Usage: \(String(format: "%.1f", report.cpu.systemUsage))%", x: margin + 10)
        drawText("Idle: \(String(format: "%.1f", report.cpu.idleUsage))%", x: margin + 10)
        drawText("Cores: \(report.cpu.coreCount) (\(report.cpu.performanceCoreCount)P + \(report.cpu.efficiencyCoreCount)E)", x: margin + 10)
        if !report.cpu.cores.isEmpty {
            y -= 4
            drawText("Per-Core Details:", x: margin + 10, fontSize: 11, bold: true)
            for core in report.cpu.cores {
                drawText("  Core \(core.id) (\(core.clusterType.rawValue)): \(String(format: "%.1f", core.usage))% @ \(Int(core.temperature))°C, \(core.frequency > 0 ? "\(core.frequency) MHz" : "—")", x: margin + 10, fontSize: 9)
            }
        }
        if !report.cpu.topProcesses.isEmpty {
            y -= 4
            drawText("Top Processes:", x: margin + 10, fontSize: 11, bold: true)
            for proc in report.cpu.topProcesses {
                drawText("  \(proc.name): CPU \(String(format: "%.1f", proc.cpuUsage))%, Mem \(ByteFormatter.format(proc.memoryBytes))", x: margin + 10, fontSize: 9)
            }
        }

        // Memory
        drawLine()
        drawText("Memory", x: margin, fontSize: 18, bold: true)
        drawText("Total: \(ByteFormatter.format(report.memory.total))", x: margin + 10)
        drawText("Used: \(ByteFormatter.format(report.memory.used))", x: margin + 10)
        drawText("Free: \(ByteFormatter.format(report.memory.free))", x: margin + 10)
        drawText("Wired: \(ByteFormatter.format(report.memory.wired))", x: margin + 10)
        drawText("Active: \(ByteFormatter.format(report.memory.active))", x: margin + 10)
        drawText("Inactive: \(ByteFormatter.format(report.memory.inactive))", x: margin + 10)
        drawText("Compressed: \(ByteFormatter.format(report.memory.compressed))", x: margin + 10)
        drawText("Purgeable: \(ByteFormatter.format(report.memory.purgeable))", x: margin + 10)
        drawText("Swap Used: \(ByteFormatter.format(report.memory.swapUsed))", x: margin + 10)
        drawText("Swap Free: \(ByteFormatter.format(report.memory.swapFree))", x: margin + 10)
        drawText("Pressure: \(report.memory.pressureLevel.rawValue)", x: margin + 10)

        // Storage
        drawLine()
        drawText("Storage", x: margin, fontSize: 18, bold: true)
        drawText("Drive Health: \(Int(report.storage.healthPercent))%", x: margin + 10)
        drawText("Read Speed: \(ByteFormatter.format(report.storage.readBytesPerSec))/s", x: margin + 10)
        drawText("Write Speed: \(ByteFormatter.format(report.storage.writeBytesPerSec))/s", x: margin + 10)
        for vol in report.storage.volumes {
            y -= 4
            drawText("Volume: \(vol.name) (\(vol.mountPoint))", x: margin + 10, fontSize: 11, bold: true)
            let pct = vol.totalBytes > 0 ? Int(Double(vol.usedBytes) / Double(vol.totalBytes) * 100) : 0
            drawText("  Total: \(ByteFormatter.format(vol.totalBytes))", x: margin + 10, fontSize: 10)
            drawText("  Used: \(ByteFormatter.format(vol.usedBytes)) (\(pct)%)", x: margin + 10, fontSize: 10)
            drawText("  Free: \(ByteFormatter.format(vol.freeBytes))", x: margin + 10, fontSize: 10)
            drawText("  Filesystem: \(vol.fileSystem)", x: margin + 10, fontSize: 10)
        }
        if !report.storage.smartAttributes.isEmpty {
            y -= 5
            drawText("S.M.A.R.T. Attributes:", x: margin + 10, fontSize: 11, bold: true)
            for attr in report.storage.smartAttributes {
                let statusStr = attr.status == .good ? "OK" : attr.status.rawValue.uppercased()
                let statusColor: NSColor = attr.status == .good ? .systemGreen : (attr.status == .warning ? .systemOrange : .systemRed)
                drawText("  [\(attr.id)] \(attr.name): \(attr.rawValue) (threshold: \(attr.threshold)) [\(statusStr)] — \(attr.explanation)", x: margin + 10, fontSize: 9, color: statusColor)
            }
        }

        // Battery
        if let bat = report.battery {
            drawLine()
            drawText("Battery", x: margin, fontSize: 18, bold: true)
            drawText("Health: \(String(format: "%.1f", bat.healthPercent))%", x: margin + 10)
            drawText("Design Capacity: \(bat.designCapacity) mAh", x: margin + 10)
            drawText("Max Capacity: \(bat.maxCapacity) mAh", x: margin + 10)
            drawText("Current Charge: \(bat.currentCharge) mAh (\(String(format: "%.1f", bat.percentage))%)", x: margin + 10)
            drawText("Cycle Count: \(bat.cycleCount)", x: margin + 10)
            drawText("Temperature: \(String(format: "%.1f", bat.temperature))°C", x: margin + 10)
            drawText("Voltage: \(String(format: "%.2f", bat.voltage)) V", x: margin + 10)
            drawText("Amperage: \(bat.amperage) mA", x: margin + 10)
            drawText("Wattage: \(String(format: "%.1f", bat.wattage)) W", x: margin + 10)
            drawText("Charging: \(bat.isCharging ? "Yes" : "No")", x: margin + 10)
            drawText("Fully Charged: \(bat.isFullyCharged ? "Yes" : "No")", x: margin + 10)
            let timeStr = bat.timeRemaining >= 0 ? "\(bat.timeRemaining / 60)h \(bat.timeRemaining % 60)m" : "Calculating"
            drawText("Time Remaining: \(timeStr)", x: margin + 10)
            drawText("Condition: \(bat.condition)", x: margin + 10)
            drawText("Manufacture Date: \(bat.manufactureDate)", x: margin + 10)
            drawText("Serial: \(bat.serialNumber)", x: margin + 10)
        }

        // Sensors
        drawLine()
        drawText("Sensors", x: margin, fontSize: 18, bold: true)
        if !report.sensors.sensors.isEmpty {
            for sensor in report.sensors.sensors {
                drawText("  \(sensor.name) [\(sensor.key)]: \(String(format: "%.1f", sensor.value))\(sensor.unit) [\(sensor.category.rawValue)]", x: margin + 10, fontSize: 9)
            }
        }
        if !report.sensors.fans.isEmpty {
            y -= 4
            drawText("Fans:", x: margin + 10, fontSize: 11, bold: true)
            for fan in report.sensors.fans {
                drawText("  \(fan.name): \(fan.rpm) RPM (range: \(fan.minRPM)–\(fan.maxRPM))", x: margin + 10, fontSize: 10)
            }
        }

        // GPU
        drawLine()
        drawText("GPU", x: margin, fontSize: 18, bold: true)
        drawText("Utilization: \(String(format: "%.1f", report.gpu.utilization))%", x: margin + 10)
        drawText("VRAM Used: \(ByteFormatter.format(report.gpu.vramUsed))", x: margin + 10)
        drawText("VRAM Total: \(ByteFormatter.format(report.gpu.vramTotal))", x: margin + 10)
        drawText("Temperature: \(String(format: "%.0f", report.gpu.temperature))°C", x: margin + 10)
        drawText("Frequency: \(report.gpu.frequency > 0 ? "\(report.gpu.frequency) MHz" : "—")", x: margin + 10)
        drawText("Encoder Utilization: \(String(format: "%.1f", report.gpu.encoderUtilization))%", x: margin + 10)
        drawText("Decoder Utilization: \(String(format: "%.1f", report.gpu.decoderUtilization))%", x: margin + 10)

        // Network
        drawLine()
        drawText("Network", x: margin, fontSize: 18, bold: true)
        for iface in report.network.interfaces {
            y -= 4
            drawText("Interface: \(iface.name)", x: margin + 10, fontSize: 11, bold: true)
            drawText("  IPv4: \(iface.ipv4Address.isEmpty ? "—" : iface.ipv4Address)", x: margin + 10, fontSize: 10)
            drawText("  IPv6: \(iface.ipv6Address.isEmpty ? "—" : iface.ipv6Address)", x: margin + 10, fontSize: 10)
            drawText("  MAC: \(iface.macAddress.isEmpty ? "—" : iface.macAddress)", x: margin + 10, fontSize: 10)
            drawText("  Link Speed: \(iface.linkSpeed)", x: margin + 10, fontSize: 10)
            drawText("  TX Total: \(ByteFormatter.format(iface.txBytes))", x: margin + 10, fontSize: 10)
            drawText("  RX Total: \(ByteFormatter.format(iface.rxBytes))", x: margin + 10, fontSize: 10)
            drawText("  TX Rate: \(ByteFormatter.format(iface.txBytesPerSec))/s", x: margin + 10, fontSize: 10)
            drawText("  RX Rate: \(ByteFormatter.format(iface.rxBytesPerSec))/s", x: margin + 10, fontSize: 10)
            drawText("  Packets In: \(iface.packetsIn)  Out: \(iface.packetsOut)", x: margin + 10, fontSize: 10)
            drawText("  Errors In: \(iface.errorsIn)  Out: \(iface.errorsOut)", x: margin + 10, fontSize: 10)
        }

        // Recommendations
        drawLine()
        drawText("Recommendations", x: margin, fontSize: 18, bold: true)
        for rec in report.recommendations {
            drawText("• \(rec)", x: margin + 10, fontSize: 11)
        }

        context.endPDFPage()
        context.closePDF()

        return pdfData as Data
    }
}

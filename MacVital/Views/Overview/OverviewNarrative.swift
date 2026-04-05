// MacVital/Views/Overview/OverviewNarrative.swift
//
// Dynamic headline + narrative rule engine for the Overview hero tile.
//
// Rules are evaluated top-down — first match wins. The tail rule is a
// "everything is fine" fallback so we always return a well-formed result.
//
// Each rule returns:
//   - headline: String with an optional word-accent range embedded as
//     `«word»` — the view turns those into the sage-coloured segment.
//   - subtext:  a longer, editorial-voice body paragraph describing the
//     current state in concrete terms.
//
// The engine is deliberately small and data-driven. If you want to add a
// state, add a rule to `rules` — there's no branching to reason about.

import Foundation
import SwiftUI

struct OverviewNarrative: Sendable {
    let headlinePlain: String
    /// The headline text split into (text, isAccent) chunks so the view can
    /// render accented words in `MV.accentSage`.
    let headlineChunks: [(text: String, isAccent: Bool)]
    let subtext: String

    // MARK: - Inputs

    struct Inputs: Sendable {
        let hottestSensorName: String?
        let hottestSensorTemp: Double?      // °C
        let cpuUsage: Double?               // 0...100
        let pClusterUsage: Double?          // 0...100
        let eClusterUsage: Double?          // 0...100
        let gpuUsage: Double?               // 0...100
        let socPower: Double?               // Watts
        let memoryPressure: MemoryPressureLevel?
        let batteryPercent: Double?
        let batteryTimeRemainingMinutes: Int?
        let batteryCharging: Bool
        let maxFanRPM: Int?
        let fanCount: Int
    }

    // MARK: - Entry point

    static func make(from inputs: Inputs) -> OverviewNarrative {
        for rule in rules {
            if let result = rule(inputs) {
                return result
            }
        }
        // Final fallback — should be unreachable because the last rule
        // always matches, but the compiler doesn't know that.
        return OverviewNarrative(
            headlinePlain: "Everything's running cool and quiet.",
            headlineChunks: [
                ("Everything's running ", false),
                ("cool and quiet", true),
                (".", false),
            ],
            subtext: "No alerts in the last 24 hours."
        )
    }

    // MARK: - Rule type

    private typealias Rule = (Inputs) -> OverviewNarrative?

    private static let rules: [Rule] = [
        ruleBatteryCritical,
        ruleBatteryLow,
        ruleThermalCritical,
        ruleThermalWarm,
        ruleMemoryCritical,
        ruleCPUBusy,
        ruleGPUBusy,
        ruleAllQuiet,
    ]

    // MARK: - Helpers

    private static func formatTempCelsius(_ temp: Double) -> String {
        "\(Int(temp.rounded()))\u{00B0}C"
    }

    private static func sentence(_ chunks: [(String, Bool)]) -> OverviewNarrative {
        let plain = chunks.map(\.0).joined()
        return OverviewNarrative(
            headlinePlain: plain,
            headlineChunks: chunks.map { (text: $0.0, isAccent: $0.1) },
            subtext: ""
        )
    }

    private static func withSub(_ narrative: OverviewNarrative, _ sub: String) -> OverviewNarrative {
        OverviewNarrative(
            headlinePlain: narrative.headlinePlain,
            headlineChunks: narrative.headlineChunks,
            subtext: sub
        )
    }

    // MARK: - Individual rules

    private static func ruleBatteryCritical(_ i: Inputs) -> OverviewNarrative? {
        guard !i.batteryCharging,
              let pct = i.batteryPercent, pct < 10 else { return nil }
        let mins = i.batteryTimeRemainingMinutes ?? 0
        let remaining = mins > 0 ? "\(mins) min" : "a few minutes"
        let headline = sentence([
            ("Battery ", false),
            ("critically low", true),
            (".", false),
        ])
        let sub = "\(Int(pct))% left — roughly \(remaining) at this pace. Plug in now or start saving work."
        return withSub(headline, sub)
    }

    private static func ruleBatteryLow(_ i: Inputs) -> OverviewNarrative? {
        guard !i.batteryCharging,
              let pct = i.batteryPercent, pct < 20 else { return nil }
        let mins = i.batteryTimeRemainingMinutes ?? 0
        let remaining = mins > 0 ? "about \(mins) minutes" : "under an hour"
        let headline = sentence([
            ("Running ", false),
            ("low on power", true),
            (".", false),
        ])
        let sub = "Battery is at \(Int(pct))% with \(remaining) left. Good moment to find a charger."
        return withSub(headline, sub)
    }

    private static func ruleThermalCritical(_ i: Inputs) -> OverviewNarrative? {
        guard let temp = i.hottestSensorTemp, temp >= 90 else { return nil }
        let name = i.hottestSensorName ?? "SoC die"
        let headline = sentence([
            ("Throttling ", false),
            ("imminent", true),
            (".", false),
        ])
        let fans = i.maxFanRPM.map { "Fans at \($0.formatted(.number)) RPM." } ?? ""
        let sub = "The \(name) is at \(formatTempCelsius(temp)). Close anything heavy — the chip will start slowing itself down soon. \(fans)".trimmingCharacters(in: .whitespaces)
        return withSub(headline, sub)
    }

    private static func ruleThermalWarm(_ i: Inputs) -> OverviewNarrative? {
        guard let temp = i.hottestSensorTemp, temp >= 75 else { return nil }
        let name = i.hottestSensorName ?? "SoC die"
        let headline = sentence([
            ("Running warm, ", false),
            ("still in spec", true),
            (".", false),
        ])
        let fans = i.maxFanRPM.map { " Fans spinning at ~\($0.formatted(.number)) RPM to catch up." } ?? ""
        let sub = "Hottest sensor is the \(name) at \(formatTempCelsius(temp)).\(fans) Nothing alarming — just working hard."
        return withSub(headline, sub)
    }

    private static func ruleMemoryCritical(_ i: Inputs) -> OverviewNarrative? {
        guard i.memoryPressure == .critical else { return nil }
        let headline = sentence([
            ("Memory ", false),
            ("under pressure", true),
            (".", false),
        ])
        let sub = "Swap is active and compressed memory is climbing. Quit something you're not using — the Mac will thank you."
        return withSub(headline, sub)
    }

    private static func ruleCPUBusy(_ i: Inputs) -> OverviewNarrative? {
        guard let cpu = i.cpuUsage, cpu >= 70 else { return nil }
        let p = i.pClusterUsage ?? cpu
        let e = i.eClusterUsage ?? 0
        let headline = sentence([
            ("Working hard, ", false),
            ("earning their keep", true),
            (".", false),
        ])
        let fans = i.maxFanRPM.map { " Fans at \($0.formatted(.number)) RPM." } ?? ""
        let sub = "CPU is at \(Int(cpu))% — P-cluster doing the work (\(Int(p))%) while the E-cluster sits at \(Int(e))%.\(fans) Temps are holding."
        return withSub(headline, sub)
    }

    private static func ruleGPUBusy(_ i: Inputs) -> OverviewNarrative? {
        guard let gpu = i.gpuUsage, gpu >= 70 else { return nil }
        let headline = sentence([
            ("GPU is ", false),
            ("doing the heavy lifting", true),
            (".", false),
        ])
        let power = i.socPower.map { String(format: "System is drawing %.1f W total.", $0) } ?? ""
        let sub = "GPU utilisation at \(Int(gpu))%. \(power) CPU has the easy job right now.".trimmingCharacters(in: .whitespaces)
        return withSub(headline, sub)
    }

    /// Catch-all: everything is calm. Always matches — must be last.
    private static func ruleAllQuiet(_ i: Inputs) -> OverviewNarrative? {
        let headline = sentence([
            ("Everything's running ", false),
            ("cool and quiet", true),
            (".", false),
        ])

        // Build a subtext paragraph out of whatever real data is available.
        var parts: [String] = []

        if let temp = i.hottestSensorTemp, let name = i.hottestSensorName {
            parts.append("Hottest sensor is the \(name) at \(formatTempCelsius(temp))")
        }

        if let cpu = i.cpuUsage {
            if let p = i.pClusterUsage, let e = i.eClusterUsage {
                parts.append("CPU \(Int(cpu))% — P-cluster \(Int(p))%, E-cluster \(Int(e))%")
            } else {
                parts.append("CPU idling around \(Int(cpu))%")
            }
        }

        if let rpm = i.maxFanRPM, rpm > 0 {
            parts.append("fans at ~\(rpm.formatted(.number)) RPM — barely audible")
        } else if i.fanCount > 0 {
            parts.append("fans at idle")
        }

        if i.memoryPressure == .nominal {
            parts.append("memory pressure nominal")
        }

        parts.append("no alerts in the last 24 hours")

        let sub = parts.joined(separator: ". ") + "."
        return withSub(headline, sub)
    }
}

// MARK: - AttributedString helper

extension OverviewNarrative {
    /// Render the headline as an `AttributedString` with accent chunks
    /// coloured in `MV.accentSage`.
    ///
    /// Headline weight tuning (2026-04-17): the canonical mockup
    /// (overview/editorial-bento-refined/refined-a-typography.html)
    /// specifies CSS `font-weight: 440` — between `regular` (400) and
    /// `medium` (500). SwiftUI's `Font.Weight` enum has no slot for
    /// this; using `.regular` looks too light and `.medium` reads as
    /// shouty. NSFont accepts continuous weights via `NSFont.Weight`
    /// rawValue (range -1...1). Empirically, rawValue ≈ 0.09 sits
    /// roughly 40% of the way from regular (0.0) to medium (0.23) —
    /// a faithful approximation of CSS 440.
    var attributedHeadline: AttributedString {
        let body = OverviewNarrative.headlineFont(weight: 0.09)
        let accent = OverviewNarrative.headlineFont(weight: 0.20)

        var attr = AttributedString()
        for chunk in headlineChunks {
            var piece = AttributedString(chunk.text)
            if chunk.isAccent {
                piece.foregroundColor = MV.accentSage
                piece.font = accent
            } else {
                piece.foregroundColor = MV.text1
                piece.font = body
            }
            attr.append(piece)
        }
        return attr
    }

    private static func headlineFont(weight: Double) -> Font {
        let nsWeight = NSFont.Weight(rawValue: weight)
        return Font(NSFont.systemFont(ofSize: MV.FS.h1, weight: nsWeight))
    }
}

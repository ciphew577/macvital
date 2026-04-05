// V3 Apple Health style, soft cards with iconography.

import SwiftUI

struct ReportAppleHealth: View {
    let snapshot: ReportSnapshot
    @Binding var period: ReportPeriod
    @Binding var redactOn: Bool
    var onJump: (String) -> Void = { _ in }
    var onPDF: () -> Void = {}
    var onMarkdown: () -> Void = {}
    var onScreenshot: () -> Void = {}
    var onShare: () -> Void = {}

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    topBar
                    verdictBlock
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(tiles) { tile(for: $0) }
                    }
                    anomalyCard
                }
                .padding(.horizontal, 32).padding(.vertical, 24)
            }
            ReportExportBar(redactOn: $redactOn, onPDF: onPDF, onMarkdown: onMarkdown, onScreenshot: onScreenshot, onShare: onShare)
        }
        .background(MV.bg)
    }

    private var topBar: some View {
        HStack {
            Text(weekLabel)
                .font(.system(size: 11)).tracking(1.8)
                .foregroundStyle(MV.text3)
            Spacer()
            ReportPeriodSelector(selection: $period)
        }
    }

    private var weekLabel: String {
        let f = DateFormatter(); f.dateFormat = "EEEE, d MMMM yyyy"
        return "TODAY \u{00B7} \(f.string(from: snapshot.issueDate).uppercased())"
    }

    private var verdictBlock: some View {
        VStack(spacing: 12) {
            Text("VERDICT, LAST 24 HOURS").font(.system(size: 10)).tracking(1.8).foregroundStyle(MV.text3)
            (Text(snapshot.verdictHead + " ").foregroundStyle(MV.text1)
             + Text(snapshot.verdictTail).foregroundStyle(snapshot.verdictTone.color))
                .font(.system(size: 30, weight: .medium))
                .lineSpacing(4)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 1100)
            ReportMoodPill(label: snapshot.moodLabel, tone: snapshot.moodTone)
            highlightStrip
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .overlay(Rectangle().frame(height: 0.5).foregroundStyle(MV.hairline), alignment: .bottom)
    }

    private var highlightStrip: some View {
        HStack(spacing: 6) {
            Image(systemName: "star.circle.fill").foregroundStyle(MV.ok).font(.system(size: 12))
            Text("Highlight of the week:").font(.system(size: 11)).foregroundStyle(MV.text3)
            Text(snapshot.highlightHead).font(.system(size: 11, weight: .medium)).foregroundStyle(MV.text1)
        }
        .padding(.top, 4)
    }

    private struct Tile: Identifiable { let id: String; let icon: String; let key: String; let value: String; let delta: String; let tone: VerdictTone }

    private var tiles: [Tile] {
        snapshot.facts.prefix(4).map { f in
            let icon: String
            switch f.id {
            case "health":  icon = "heart.fill"
            case "therm":   icon = "thermometer.medium"
            case "fans":    icon = "fan"
            case "battery": icon = "battery.100"
            case "ssd":     icon = "internaldrive"
            case "swap":    icon = "memorychip"
            case "load":    icon = "cpu"
            default:        icon = "circle"
            }
            return Tile(id: f.id, icon: icon, key: f.key, value: f.value, delta: "", tone: f.tone)
        }
    }

    private func tile(for t: Tile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(t.tone.color.opacity(0.10))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(t.tone.color.opacity(0.34), lineWidth: 0.5))
                Image(systemName: t.icon).font(.system(size: 13, weight: .medium)).foregroundStyle(t.tone.color)
            }
            .frame(width: 28, height: 28)
            Text(t.key.uppercased()).font(.system(size: 9)).tracking(1.6).foregroundStyle(MV.text3)
            Text(t.value)
                .font(.system(size: 22, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(MV.text1)
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .background(MV.tile)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(MV.hairline, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var anomalyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Anomaly Spotlight").font(.system(size: 13, weight: .semibold)).foregroundStyle(MV.text1)
                Spacer()
                Text("\(snapshot.anomalies.count) EVENTS, RANKED").font(.system(size: 10)).tracking(1.6).foregroundStyle(MV.text3)
            }
            VStack(spacing: 0) {
                ForEach(snapshot.anomalies) { a in row(a) }
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 16)
        .background(MV.tile)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(MV.hairline, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func row(_ a: ReportAnomaly) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(a.severity.tone.color.opacity(0.10))
                    .overlay(Circle().strokeBorder(a.severity.tone.color.opacity(0.34), lineWidth: 0.5))
                Image(systemName: iconFor(a.jumpTab)).font(.system(size: 11)).foregroundStyle(a.severity.tone.color)
            }
            .frame(width: 22, height: 22)
            Text(a.timestamp).font(.system(size: 11, design: .monospaced)).monospacedDigit().foregroundStyle(MV.text2).frame(width: 110, alignment: .leading)
            Text(a.sentence).font(.system(size: 13)).foregroundStyle(MV.text1).frame(maxWidth: .infinity, alignment: .leading)
            ReportJumpButton(label: "Jump") { onJump(a.jumpTab) }
        }
        .padding(.vertical, 8)
        .overlay(Rectangle().frame(height: 0.5).foregroundStyle(MV.hairline), alignment: .bottom)
    }

    private func iconFor(_ tab: String) -> String {
        switch tab {
        case "Sensors":  return "thermometer.medium"
        case "Fans":     return "fan"
        case "Memory":   return "memorychip"
        case "Storage":  return "internaldrive"
        case "CPU":      return "cpu"
        default:         return "checkmark.circle"
        }
    }
}

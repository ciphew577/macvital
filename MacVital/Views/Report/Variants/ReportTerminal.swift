// V4 strict monospaced terminal page, ASCII separators using flat dividers.

import SwiftUI

struct ReportTerminal: View {
    let snapshot: ReportSnapshot
    @Binding var period: ReportPeriod
    @Binding var redactOn: Bool
    var onJump: (String) -> Void = { _ in }
    var onPDF: () -> Void = {}
    var onMarkdown: () -> Void = {}
    var onScreenshot: () -> Void = {}
    var onShare: () -> Void = {}

    private var stamp: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH:mm:ss zzz"
        return f.string(from: snapshot.issueDate)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    head
                    rule
                    title
                    metaBlock
                    rule
                    tldrBlock
                    rule
                    factsGrid
                    rule
                    anomalyList
                }
                .padding(.horizontal, 32).padding(.vertical, 24)
            }
            ReportExportBar(redactOn: $redactOn, onPDF: onPDF, onMarkdown: onMarkdown, onScreenshot: onScreenshot, onShare: onShare)
        }
        .background(MV.bg)
        .font(.system(size: 12.5, design: .monospaced))
    }

    private var rule: some View {
        Rectangle().fill(MV.hairlineStrong).frame(height: 1).padding(.vertical, 4)
    }

    private var head: some View {
        HStack {
            Text("MACVITAL // REPORT // \(snapshot.period.rawValue)")
                .font(.system(size: 11, design: .monospaced)).tracking(1.6).foregroundStyle(MV.text3)
            Spacer()
            ReportPeriodSelector(selection: $period)
            Text(stamp).font(.system(size: 11, design: .monospaced)).foregroundStyle(MV.text3)
        }
    }

    private var title: some View {
        (Text(snapshot.verdictHead + " ").foregroundStyle(MV.text1)
         + Text(snapshot.verdictTail).foregroundStyle(snapshot.verdictTone.color))
            .font(.system(size: 22, weight: .semibold, design: .monospaced))
            .tracking(-0.2)
    }

    private var metaBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            metaRow("MODEL",       snapshot.macModel)
            metaRow("CHIP",        snapshot.chip)
            metaRow("HEALTH",      "\(snapshot.healthScore) / 100  (baseline \(snapshot.healthBaseline), \(snapshot.healthDelta >= 0 ? "+" : "")\(snapshot.healthDelta) dod)")
            metaRow("MOOD",        snapshot.moodLabel)
            metaRow("HIGHLIGHT",   snapshot.highlightHead)
            metaRow("ANOMALIES",   "\(snapshot.anomalyCount.total) total, \(snapshot.anomalyCount.notable) notable, \(snapshot.anomalyCount.critical) critical")
        }
        .font(.system(size: 11.5, design: .monospaced))
    }

    private func metaRow(_ k: String, _ v: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(k).tracking(0.8).foregroundStyle(MV.text3).frame(width: 200, alignment: .leading)
            Text(v).foregroundStyle(MV.text1).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var tldrBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("> TL;DR").tracking(1.4).foregroundStyle(MV.text3)
            Text(snapshot.tldr)
                .foregroundStyle(MV.text1)
                .lineSpacing(3)
                .frame(maxWidth: 1300, alignment: .leading)
        }
    }

    private var factsGrid: some View {
        let cells = snapshot.facts.prefix(5)
        return HStack(spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.element.id) { idx, f in
                VStack(alignment: .leading, spacing: 2) {
                    Text(f.key.uppercased()).font(.system(size: 9.5, design: .monospaced)).tracking(1.4).foregroundStyle(MV.text3)
                    Text(f.value).font(.system(size: 12, design: .monospaced)).monospacedDigit().foregroundStyle(f.tone.color)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                if idx < cells.count - 1 { Rectangle().fill(MV.hairline).frame(width: 0.5) }
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(MV.hairlineStrong, lineWidth: 0.5))
    }

    private var anomalyList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("> ANOMALY SPOTLIGHT").tracking(1.4).foregroundStyle(MV.text3)
            ForEach(Array(snapshot.anomalies.enumerated()), id: \.element.id) { idx, a in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("[\(prefix(for: a.severity))]").foregroundStyle(a.severity.tone.color).frame(width: 60, alignment: .leading)
                    Text(a.timestamp).foregroundStyle(MV.text2).frame(width: 110, alignment: .leading)
                    Text(a.sentence).foregroundStyle(MV.text1).frame(maxWidth: .infinity, alignment: .leading)
                    Button("[jump]") { onJump(a.jumpTab) }.buttonStyle(.plain).foregroundStyle(MV.text2).frame(width: 90, alignment: .trailing)
                }
                .font(.system(size: 12, design: .monospaced))
                .padding(.vertical, 4)
            }
        }
    }

    private func prefix(for s: AnomalySeverity) -> String {
        switch s {
        case .high:    return "!!"
        case .notable: return "* "
        case .info:    return "ok"
        }
    }
}

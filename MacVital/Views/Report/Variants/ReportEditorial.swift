// V1 editorial magazine layout, big serif headline as Verdict.

import SwiftUI

struct ReportEditorial: View {
    let snapshot: ReportSnapshot
    @Binding var period: ReportPeriod
    @Binding var redactOn: Bool
    var onJump: (String) -> Void = { _ in }
    var onPDF: () -> Void = {}
    var onMarkdown: () -> Void = {}
    var onScreenshot: () -> Void = {}
    var onShare: () -> Void = {}

    private var issueLabel: String {
        let f = DateFormatter(); f.dateFormat = "EEE d LLL yyyy"
        return "Issue \(snapshot.issueNumber) \u{00B7} \(f.string(from: snapshot.issueDate)) \u{00B7} written locally"
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    masthead
                    Text("VERDICT, LAST 24 HOURS")
                        .font(.system(size: 10)).tracking(2.2)
                        .foregroundStyle(MV.text3)
                    headline
                    deck
                    heroStats
                    tldr
                    anomalyBlock
                }
                .padding(.horizontal, 56)
                .padding(.vertical, 32)
            }
            ReportExportBar(redactOn: $redactOn, onPDF: onPDF, onMarkdown: onMarkdown, onScreenshot: onScreenshot, onShare: onShare)
        }
        .background(MV.bg)
    }

    private var masthead: some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("MacVital, Health Notes")
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundStyle(MV.text1)
                Text(issueLabel)
                    .font(.system(size: 10))
                    .tracking(1.8)
                    .foregroundStyle(MV.text3)
            }
            Spacer()
            HStack(spacing: 12) {
                ReportPeriodSelector(selection: $period)
                ReportMoodPill(label: snapshot.moodLabel, tone: snapshot.moodTone)
            }
        }
        .padding(.bottom, 12)
        .overlay(Rectangle().frame(height: 0.5).foregroundStyle(MV.hairline), alignment: .bottom)
    }

    private var headline: some View {
        (Text(snapshot.verdictHead + " ")
            .foregroundStyle(MV.text1)
         + Text(snapshot.verdictTail)
            .italic()
            .foregroundStyle(snapshot.verdictTone.color))
            .font(.system(size: 56, weight: .semibold, design: .serif))
            .lineSpacing(2)
            .tracking(-0.5)
            .frame(maxWidth: 1280, alignment: .leading)
    }

    private var deck: some View {
        Text(snapshot.tldr)
            .font(.system(size: 18, design: .serif))
            .italic()
            .foregroundStyle(MV.text2)
            .frame(maxWidth: 1280, alignment: .leading)
    }

    private var heroStats: some View {
        HStack(spacing: 0) {
            statCol(label: "Health score",
                    value: "\(snapshot.healthScore)",
                    valueSuffix: " / 100",
                    sub: "vs \(snapshot.healthBaseline) baseline, \(snapshot.healthDelta >= 0 ? "+" : "")\(snapshot.healthDelta) day over day")
            divider
            statCol(label: "Highlight of the week",
                    value: snapshot.highlightHead,
                    valueSize: 15,
                    sub: snapshot.highlightSub)
            divider
            statCol(label: "Today, in numbers",
                    value: "\(snapshot.anomalyCount.total) anomalies \u{00B7} \(snapshot.anomalyCount.notable) notable \u{00B7} \(snapshot.anomalyCount.critical) critical",
                    valueSize: 15,
                    sub: "Detected by rolling z score, magnitude over 2.5 sustained 3 min")
        }
        .padding(.vertical, 16)
        .overlay(Rectangle().frame(height: 0.5).foregroundStyle(MV.hairline), alignment: .top)
        .overlay(Rectangle().frame(height: 0.5).foregroundStyle(MV.hairline), alignment: .bottom)
    }

    private var divider: some View {
        Rectangle().fill(MV.hairline).frame(width: 0.5).padding(.vertical, 4)
    }

    private func statCol(label: String, value: String, valueSuffix: String = "", valueSize: CGFloat = 22, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9)).tracking(1.8)
                .foregroundStyle(MV.text3)
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(value)
                    .font(.system(size: valueSize, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(MV.text1)
                if !valueSuffix.isEmpty {
                    Text(valueSuffix)
                        .font(.system(size: 14))
                        .foregroundStyle(MV.text2)
                }
            }
            Text(sub).font(.system(size: 11)).foregroundStyle(MV.text2).lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
    }

    private var tldr: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TL;DR").font(.system(size: 9)).tracking(1.6).foregroundStyle(MV.text3)
            Text(snapshot.tldr)
                .font(.system(size: 16, design: .serif))
                .lineSpacing(4)
                .foregroundStyle(MV.text1)
            HStack(spacing: 6) { ForEach(snapshot.facts) { ReportFactChip(fact: $0) } }
        }
        .frame(maxWidth: 1100, alignment: .leading)
    }

    private var anomalyBlock: some View {
        HStack(alignment: .top, spacing: 32) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Anomaly Spotlight")
                    .italic()
                    .font(.system(size: 22, weight: .medium, design: .serif))
                    .foregroundStyle(MV.text1)
                Text("\(snapshot.anomalies.count) events, ranked by severity")
                    .font(.system(size: 10))
                    .tracking(1.6)
                    .foregroundStyle(MV.text3)
            }
            .frame(width: 220, alignment: .leading)
            VStack(spacing: 0) {
                ForEach(Array(snapshot.anomalies.enumerated()), id: \.element.id) { idx, a in
                    ReportAnomalyRow(index: idx, anomaly: a, onJump: onJump)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 16)
        .overlay(Rectangle().frame(height: 0.5).foregroundStyle(MV.hairline), alignment: .top)
    }
}

// V2 dashboard, three equal hero cards plus sortable mini table.

import SwiftUI

struct ReportDashboard: View {
    let snapshot: ReportSnapshot
    @Binding var period: ReportPeriod
    @Binding var redactOn: Bool
    var onJump: (String) -> Void = { _ in }
    var onPDF: () -> Void = {}
    var onMarkdown: () -> Void = {}
    var onScreenshot: () -> Void = {}
    var onShare: () -> Void = {}
    @State private var sortAscending = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    topBar
                    heroRow
                    tldrCard
                    chipRow
                    anomalyTable
                }
                .padding(24)
            }
            ReportExportBar(redactOn: $redactOn, onPDF: onPDF, onMarkdown: onMarkdown, onScreenshot: onScreenshot, onShare: onShare)
        }
        .background(MV.bg)
    }

    private var topBar: some View {
        HStack {
            HStack(spacing: 6) {
                Text("Report").font(.system(size: 14, weight: .semibold)).foregroundStyle(MV.text1)
                Text("\u{00B7}").foregroundStyle(MV.text3)
                Text("last 24 hours, \(snapshot.macModel), \(snapshot.chip)")
                    .font(.system(size: 14)).foregroundStyle(MV.text2)
            }
            Spacer()
            ReportPeriodSelector(selection: $period)
        }
        .padding(.bottom, 12)
        .overlay(Rectangle().frame(height: 0.5).foregroundStyle(MV.hairline), alignment: .bottom)
    }

    private var heroRow: some View {
        HStack(alignment: .top, spacing: 12) {
            verdictCard.frame(maxWidth: .infinity)
            moodCard.frame(maxWidth: .infinity)
            highlightCard.frame(maxWidth: .infinity)
        }
    }

    private var verdictCard: some View {
        cardShell {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    eyebrow("Verdict")
                    Spacer()
                    ReportMoodPill(label: snapshot.moodLabel, tone: snapshot.moodTone)
                }
                (Text(snapshot.verdictHead + " ").foregroundStyle(MV.text1)
                 + Text(snapshot.verdictTail).foregroundStyle(snapshot.verdictTone.color))
                    .font(.system(size: 22, weight: .regular))
                    .lineSpacing(2)
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("\(snapshot.healthScore)")
                        .font(.system(size: 36, weight: .semibold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(snapshot.verdictTone.color)
                    Text("overall, baseline \(snapshot.healthBaseline) \u{00B7} \(snapshot.healthDelta >= 0 ? "+" : "")\(snapshot.healthDelta) day over day")
                        .font(.system(size: 11)).foregroundStyle(MV.text2)
                }
            }
        }
    }

    private var moodCard: some View {
        cardShell {
            VStack(alignment: .leading, spacing: 12) {
                HStack { eyebrow("Mac mood"); Spacer(); Circle().fill(snapshot.moodTone.color).frame(width: 6, height: 6) }
                Text(snapshot.moodLabel)
                    .font(.system(size: 26))
                    .lineSpacing(2)
                    .foregroundStyle(MV.text1)
                HStack(spacing: 16) {
                    ForEach(snapshot.moodReasons, id: \.key) { r in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.key.uppercased()).font(.system(size: 9)).tracking(1.2).foregroundStyle(MV.text3)
                            Text(r.value).font(.system(size: 11, design: .monospaced)).monospacedDigit().foregroundStyle(MV.text1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.top, 8)
                .overlay(Rectangle().frame(height: 0.5).foregroundStyle(MV.hairline), alignment: .top)
            }
        }
    }

    private var highlightCard: some View {
        cardShell {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    eyebrow("Highlight of the week")
                    Spacer()
                    Text("BEST IN 34 DAYS")
                        .font(.system(size: 9)).tracking(1.6).foregroundStyle(MV.ok)
                }
                Text(snapshot.highlightHead)
                    .font(.system(size: 16))
                    .lineSpacing(3)
                    .foregroundStyle(MV.text1)
                Text(snapshot.highlightSub)
                    .font(.system(size: 10)).foregroundStyle(MV.text2)
            }
        }
    }

    private var tldrCard: some View {
        cardShell(quiet: true) {
            VStack(alignment: .leading, spacing: 4) {
                Text("TL;DR").font(.system(size: 9)).tracking(1.6).foregroundStyle(MV.text3)
                Text(snapshot.tldr).font(.system(size: 12)).lineSpacing(3).foregroundStyle(MV.text1)
            }
        }
    }

    private var chipRow: some View {
        HStack(spacing: 6) { ForEach(snapshot.facts) { ReportFactChip(fact: $0) }; Spacer() }
    }

    private var anomalyTable: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                headerCell("Sev", width: 70)
                Button { sortAscending.toggle() } label: {
                    HStack(spacing: 4) { headerCell("Time", width: nil); Image(systemName: sortAscending ? "arrow.up" : "arrow.down").font(.system(size: 9)).foregroundStyle(MV.text2) }
                }.buttonStyle(.plain).frame(width: 140, alignment: .leading)
                headerCell("Metric", width: 170)
                headerCell("What happened", width: nil).frame(maxWidth: .infinity, alignment: .leading)
                headerCell("Delta", width: 120)
                Spacer().frame(width: 70)
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(MV.tile)
            .overlay(Rectangle().frame(height: 0.5).foregroundStyle(MV.hairline), alignment: .bottom)

            ForEach(sortedAnoms) { a in
                HStack(alignment: .center, spacing: 12) {
                    Text(a.severity.label.uppercased())
                        .font(.system(size: 10)).tracking(1.0)
                        .foregroundStyle(a.severity.tone.color)
                        .frame(width: 70, alignment: .leading)
                    Text(a.timestamp).font(.system(size: 12, design: .monospaced)).monospacedDigit().foregroundStyle(MV.text1).frame(width: 140, alignment: .leading)
                    Text(a.metric).font(.system(size: 12)).foregroundStyle(MV.text1).frame(width: 170, alignment: .leading)
                    Text(a.sentence).font(.system(size: 12)).foregroundStyle(MV.text1).frame(maxWidth: .infinity, alignment: .leading)
                    Text(a.delta).font(.system(size: 12, design: .monospaced)).monospacedDigit().foregroundStyle(a.severity.tone.color).frame(width: 120, alignment: .leading)
                    ReportJumpButton(label: "Jump") { onJump(a.jumpTab) }.frame(width: 70, alignment: .trailing)
                }
                .padding(.horizontal, 16).padding(.vertical, 9)
                .overlay(Rectangle().frame(height: 0.5).foregroundStyle(MV.hairline), alignment: .bottom)
            }
        }
        .background(MV.tile)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(MV.hairline, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var sortedAnoms: [ReportAnomaly] {
        sortAscending ? snapshot.anomalies.reversed() : snapshot.anomalies
    }

    @ViewBuilder
    private func eyebrow(_ s: String) -> some View {
        Text(s.uppercased()).font(.system(size: 9)).tracking(1.8).foregroundStyle(MV.text3)
    }

    @ViewBuilder
    private func headerCell(_ s: String, width: CGFloat?) -> some View {
        Group {
            if let width {
                Text(s.uppercased()).font(.system(size: 9)).tracking(1.6).foregroundStyle(MV.text3).frame(width: width, alignment: .leading)
            } else {
                Text(s.uppercased()).font(.system(size: 9)).tracking(1.6).foregroundStyle(MV.text3)
            }
        }
    }

    @ViewBuilder
    private func cardShell<Content: View>(quiet: Bool = false, @ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 20).padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(quiet ? MV.bg : MV.tile)
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(MV.hairline, lineWidth: 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

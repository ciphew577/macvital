// V5 newspaper print fold, two-column light paper layout.
//
// PALETTE NOTE
// The five raw Color(red:green:blue:) literals in this file (paper, ink,
// quiet, rule, emberInk, plus the per-tone tints in paperChip) are
// intentionally OFF-GRID from MV.* tokens. The Newspaper Fold variant is an
// editorial print-style page, not a system surface, so it ships its own
// paper-mode palette: warm cream paper, deep ink, hairline rules, and a
// single ember accent for the verdict tail. Do not normalise these to MV.*
// tokens, the cream/ink contrast is the point of the variant.

import SwiftUI

struct ReportNewspaperFold: View {
    let snapshot: ReportSnapshot
    @Binding var period: ReportPeriod
    @Binding var redactOn: Bool
    var onJump: (String) -> Void = { _ in }
    var onPDF: () -> Void = {}
    var onMarkdown: () -> Void = {}
    var onScreenshot: () -> Void = {}
    var onShare: () -> Void = {}

    private let paper    = Color(red: 0.957, green: 0.945, blue: 0.925)
    private let ink      = Color(red: 0.094, green: 0.086, blue: 0.071)
    private let quiet    = Color(red: 0.094, green: 0.086, blue: 0.071).opacity(0.62)
    private let rule     = Color(red: 0.094, green: 0.086, blue: 0.071).opacity(0.18)
    private let emberInk = Color(red: 0.701, green: 0.270, blue: 0.196)

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    masthead
                    fold
                }
                .padding(.horizontal, 40).padding(.vertical, 32)
            }
            .background(paper)
            ReportExportBar(redactOn: $redactOn, onPDF: onPDF, onMarkdown: onMarkdown, onScreenshot: onScreenshot, onShare: onShare, paperStyle: true)
                .background(paper)
        }
        .background(paper)
    }

    private var dateLabel: String {
        let f = DateFormatter(); f.dateFormat = "EEE d LLL yyyy"
        return f.string(from: snapshot.issueDate).uppercased()
    }

    private var masthead: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("The Daily Mac")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundStyle(ink)
            Spacer()
            HStack(spacing: 12) {
                Text("VOL. 1 \u{00B7} ISSUE \(snapshot.issueNumber) \u{00B7} \(dateLabel)")
                    .font(.system(size: 10)).tracking(1.8).foregroundStyle(quiet)
                ReportPeriodSelector(selection: $period)
            }
        }
        .padding(.bottom, 8)
        .overlay(Rectangle().frame(height: 1.5).foregroundStyle(ink), alignment: .bottom)
    }

    private var fold: some View {
        HStack(alignment: .top, spacing: 32) {
            leftColumn.frame(maxWidth: .infinity, alignment: .topLeading)
            Rectangle().fill(rule).frame(width: 0.5).frame(maxHeight: .infinity)
            rightColumn.frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("VERDICT, LAST 24 HOURS").font(.system(size: 10)).tracking(2.2).foregroundStyle(quiet)
            (Text(snapshot.verdictHead + " ").foregroundStyle(ink)
             + Text(snapshot.verdictTail).foregroundStyle(emberInk))
                .font(.system(size: 38, weight: .bold, design: .serif))
                .lineSpacing(3)
                .tracking(-0.4)
            Text(snapshot.moodLabel)
                .font(.system(size: 16, design: .serif))
                .italic()
                .foregroundStyle(ink)
                .padding(.leading, 12)
                .overlay(Rectangle().frame(width: 2).foregroundStyle(ink), alignment: .leading)
            Text("BY MACVITAL STAFF \u{00B7} \(snapshot.macModel.uppercased()) \u{00B7} \(snapshot.chip.uppercased())")
                .font(.system(size: 10)).tracking(1.6).foregroundStyle(quiet)
            Text(snapshot.tldr)
                .font(.system(size: 14, design: .serif))
                .lineSpacing(4)
                .foregroundStyle(ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Highlight of the Week")
            VStack(alignment: .leading, spacing: 4) {
                Text("HIGHLIGHT").font(.system(size: 9)).tracking(2.0).foregroundStyle(quiet)
                Text(snapshot.highlightHead)
                    .font(.system(size: 16, design: .serif))
                    .foregroundStyle(ink)
                Text(snapshot.highlightSub)
                    .font(.system(size: 12)).foregroundStyle(quiet)
            }
            .padding(12)
            .overlay(Rectangle().strokeBorder(ink, lineWidth: 1))

            sectionTitle("By the Numbers")
            HStack(spacing: 6) {
                ForEach(snapshot.facts) { f in paperChip(f) }
            }

            sectionTitle("Anomaly Spotlight")
            VStack(spacing: 0) {
                ForEach(Array(snapshot.anomalies.enumerated()), id: \.element.id) { idx, a in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(idx + 1).").font(.system(size: 13, weight: .bold, design: .serif)).foregroundStyle(ink).frame(width: 18, alignment: .leading)
                        Text(a.timestamp).font(.system(size: 11, design: .monospaced)).monospacedDigit().foregroundStyle(quiet).frame(width: 100, alignment: .leading)
                        Text(a.sentence)
                            .font(.system(size: 12.5))
                            .foregroundStyle(ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ReportPaperJumpButton(label: "Jump") { onJump(a.jumpTab) }
                    }
                    .padding(.vertical, 8)
                    .overlay(Rectangle().frame(height: 0.5).foregroundStyle(rule), alignment: .bottom)
                }
            }
        }
    }

    private func sectionTitle(_ s: String) -> some View {
        Text(s.uppercased())
            .font(.system(size: 11, weight: .bold, design: .serif))
            .tracking(2.0)
            .foregroundStyle(ink)
            .padding(.bottom, 4)
            .overlay(Rectangle().frame(height: 1).foregroundStyle(ink), alignment: .bottom)
    }

    private func paperChip(_ f: ReportFact) -> some View {
        let tint: Color
        switch f.tone {
        case .healthy: tint = Color(red: 0.31, green: 0.48, blue: 0.36)
        case .notable: tint = Color(red: 0.64, green: 0.39, blue: 0.10)
        case .alert:   tint = emberInk
        case .neutral: tint = ink
        }
        return HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(f.key.uppercased()).font(.system(size: 9)).tracking(1.2).foregroundStyle(quiet)
            Text(f.value).font(.system(size: 11, design: .monospaced)).monospacedDigit().foregroundStyle(tint)
        }
        .padding(.horizontal, 9).padding(.vertical, 4)
        .overlay(Capsule().strokeBorder(tint.opacity(0.4), lineWidth: 0.5))
    }
}

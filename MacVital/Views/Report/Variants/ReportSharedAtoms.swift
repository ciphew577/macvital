// Period selector, mood pill, fact chips, jump button, export bar, redact toggle.

import SwiftUI

struct ReportPeriodSelector: View {
    @Binding var selection: ReportPeriod

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ReportPeriod.allCases) { p in
                let active = p == selection
                Button {
                    selection = p
                } label: {
                    Text(p.rawValue)
                        .font(.system(size: 11, weight: active ? .semibold : .regular))
                        .tracking(0.4)
                        .monospacedDigit()
                        .foregroundStyle(active ? Color(nsColor: .windowBackgroundColor) : MV.text2)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(active ? MV.text1 : Color.clear, in: Capsule())
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(p.rawValue) period")
                .accessibilityValue(active ? "selected" : "not selected")
                .accessibilityAddTraits(active ? .isSelected : [])
            }
        }
        .padding(2)
        .overlay(Capsule().strokeBorder(MV.hairlineStrong, lineWidth: 0.5))
        .clipShape(Capsule())
    }
}

struct ReportMoodPill: View {
    let label: String
    let tone: VerdictTone

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(tone.color).frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 11))
                .tracking(0.4)
                .foregroundStyle(tone.color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .overlay(Capsule().strokeBorder(tone.color.opacity(0.34), lineWidth: 0.5))
        .background(tone.color.opacity(0.10), in: Capsule())
    }
}

struct ReportFactChip: View {
    let fact: ReportFact

    private var tint: Color { fact.tone.color }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(fact.key.uppercased())
                .font(.system(size: 9))
                .tracking(1.2)
                .foregroundStyle(MV.text3)
            Text(fact.value)
                .font(.system(size: 11, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .overlay(Capsule().strokeBorder(tint.opacity(0.34), lineWidth: 0.5))
    }
}

struct ReportJumpButton: View {
    let label: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.system(size: 10))
                    .tracking(0.6)
                Image(systemName: "arrow.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(MV.text2)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .overlay(Capsule().strokeBorder(MV.hairlineStrong, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .foregroundStyle(MV.text1)
    }
}

struct ReportExportBar: View {
    @Binding var redactOn: Bool
    var onPDF: () -> Void = {}
    var onMarkdown: () -> Void = {}
    var onScreenshot: () -> Void = {}
    var onShare: () -> Void = {}
    var paperStyle: Bool = false

    private var border: Color { paperStyle ? Color(red: 0.10, green: 0.09, blue: 0.07).opacity(0.18) : MV.hairline }
    private var ink: Color    { paperStyle ? Color(red: 0.10, green: 0.09, blue: 0.07) : MV.text1 }
    private var quiet: Color  { paperStyle ? Color(red: 0.10, green: 0.09, blue: 0.07).opacity(0.62) : MV.text2 }

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                Text("EXPORT")
                    .font(.system(size: 9))
                    .tracking(1.4)
                    .foregroundStyle(quiet)
                exportBtn("PDF", action: onPDF)
                // TODO: proper Markdown serialization of ReportSnapshot. For
                // now this exports HTML; label updated to match behaviour.
                exportBtn("HTML", action: onMarkdown)
                exportBtn("Screenshot", action: onScreenshot)
                exportBtn("Share", primary: true, action: onShare)
            }
            Spacer()
            Toggle(isOn: $redactOn) {
                Text(redactOn ? "Privacy redact, on" : "Privacy redact, off")
                    .font(.system(size: 11))
                    .foregroundStyle(quiet)
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .tint(MV.ok)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .overlay(Rectangle().frame(height: 0.5).foregroundStyle(border), alignment: .top)
    }

    @ViewBuilder
    private func exportBtn(_ title: String, primary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: primary ? .semibold : .regular))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(primary ? ink : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                .foregroundStyle(primary ? Color(nsColor: .windowBackgroundColor) : ink)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(primary ? ink : border, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}

struct ReportAnomalyRow: View {
    let index: Int
    let anomaly: ReportAnomaly
    var onJump: (String) -> Void = { _ in }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(String(format: "%02d", index + 1))
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(MV.text3)
                .frame(width: 28, alignment: .leading)
            Text(anomaly.timestamp)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(MV.text2)
                .frame(width: 110, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(anomaly.sentence)
                    .font(.system(size: 13))
                    .foregroundStyle(MV.text1)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Text(anomaly.metric.uppercased())
                        .font(.system(size: 9))
                        .tracking(1.0)
                        .foregroundStyle(MV.text3)
                    Text(anomaly.delta)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(anomaly.severity.tone.color)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            ReportJumpButton(label: "Jump") { onJump(anomaly.jumpTab) }
        }
        .padding(.vertical, 10)
        .overlay(Rectangle().frame(height: 0.5).foregroundStyle(MV.hairline), alignment: .bottom)
    }
}

struct ReportPaperJumpButton: View {
    let label: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text(label.uppercased())
                .font(.system(size: 9))
                .tracking(1.4)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .overlay(Capsule().strokeBorder(Color(red: 0.10, green: 0.09, blue: 0.07), lineWidth: 0.5))
                .foregroundStyle(Color(red: 0.10, green: 0.09, blue: 0.07))
        }
        .buttonStyle(.plain)
    }
}

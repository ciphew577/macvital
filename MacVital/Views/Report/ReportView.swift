// MacVital/Views/Report/ReportView.swift
import SwiftUI

struct ReportView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(ReportVariant.storageKey) private var variantRaw: Int = 0
    @AppStorage("com.macvital.report.privacyRedact") private var redactOn: Bool = true
    @State private var report: DiagnosticReport?
    @State private var isRunning = false
    @State private var period: ReportPeriod = .h24
    @State private var exportFormat: ExportFormat = .pdf
    @State private var showExportSuccess = false

    enum ExportFormat: String, CaseIterable {
        case pdf = "PDF"
        case html = "HTML"
    }

    private var variant: ReportVariant { ReportVariant(rawValue: variantRaw) ?? .editorial }

    var body: some View {
        Group {
            if report != nil {
                variantBody
            } else {
                runIntro
            }
        }
        .navigationTitle("Report")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Picker("Variant", selection: $variantRaw) {
                    ForEach(ReportVariant.allCases) { v in
                        Text(v.displayName).tag(v.rawValue)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    @ViewBuilder
    private var variantBody: some View {
        let snapshot = ReportSnapshotBuilder.snapshot(from: appState.monitor, period: period)
        switch variant {
        case .editorial:
            ReportEditorial(snapshot: snapshot, period: $period, redactOn: $redactOn,
                            onJump: handleJump, onPDF: { exportFormat = .pdf; exportReport() },
                            onMarkdown: { exportFormat = .html; exportReport() },
                            onScreenshot: takeScreenshot, onShare: { exportFormat = .pdf; exportReport() })
        case .dashboard:
            ReportDashboard(snapshot: snapshot, period: $period, redactOn: $redactOn,
                            onJump: handleJump, onPDF: { exportFormat = .pdf; exportReport() },
                            onMarkdown: { exportFormat = .html; exportReport() },
                            onScreenshot: takeScreenshot, onShare: { exportFormat = .pdf; exportReport() })
        case .appleHealth:
            ReportAppleHealth(snapshot: snapshot, period: $period, redactOn: $redactOn,
                              onJump: handleJump, onPDF: { exportFormat = .pdf; exportReport() },
                              onMarkdown: { exportFormat = .html; exportReport() },
                              onScreenshot: takeScreenshot, onShare: { exportFormat = .pdf; exportReport() })
        case .terminal:
            ReportTerminal(snapshot: snapshot, period: $period, redactOn: $redactOn,
                           onJump: handleJump, onPDF: { exportFormat = .pdf; exportReport() },
                           onMarkdown: { exportFormat = .html; exportReport() },
                           onScreenshot: takeScreenshot, onShare: { exportFormat = .pdf; exportReport() })
        case .newspaperFold:
            ReportNewspaperFold(snapshot: snapshot, period: $period, redactOn: $redactOn,
                                onJump: handleJump, onPDF: { exportFormat = .pdf; exportReport() },
                                onMarkdown: { exportFormat = .html; exportReport() },
                                onScreenshot: takeScreenshot, onShare: { exportFormat = .pdf; exportReport() })
        }
    }

    private var runIntro: some View {
        VStack(spacing: 16) {
            Image(systemName: "stethoscope").font(.system(size: 48)).foregroundStyle(.blue)
            Text("Full System Diagnostic").font(.title2.weight(.semibold))
            Text("Scans every component and generates a comprehensive health report with individual metrics and recommendations.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
            if isRunning {
                ProgressView().controlSize(.large)
                Text(appState.monitor.diagnosticProgress).font(.caption).foregroundStyle(.secondary)
            } else {
                Button(action: runDiagnostic) {
                    Label("Run Full Diagnostics", systemImage: "play.fill")
                        .font(.headline)
                        .padding(.horizontal, 24).padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            if showExportSuccess {
                Text("Report exported successfully.").font(.caption).foregroundStyle(.green).transition(.opacity)
            }
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func handleJump(_ tab: String) { _ = tab }

    private func runDiagnostic() {
        isRunning = true
        Task {
            report = await appState.monitor.runDiagnostic()
            isRunning = false
        }
    }

    @MainActor
    private func takeScreenshot() {
        let snapshot = ReportSnapshotBuilder.snapshot(from: appState.monitor, period: period)
        let renderer = ImageRenderer(
            content: ReportScreenshotContent(snapshot: snapshot, variant: variant)
                .frame(width: 1100)
        )
        renderer.scale = 2
        guard let nsImage = renderer.nsImage,
              let tiff = nsImage.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .png, properties: [:]) else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "MacVital-Report-\(Date().formatted(.dateTime.year().month().day())).png"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? data.write(to: url)
            flashExportSuccess()
        }
    }

    private func flashExportSuccess() {
        if reduceMotion {
            showExportSuccess = true
        } else {
            withAnimation { showExportSuccess = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if reduceMotion {
                showExportSuccess = false
            } else {
                withAnimation { showExportSuccess = false }
            }
        }
    }

    private func exportReport() {
        guard let report else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = exportFormat == .pdf ? [.pdf] : [.html]
        panel.nameFieldStringValue = "MacVital-Report-\(Date().formatted(.dateTime.year().month().day()))"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                switch exportFormat {
                case .pdf:
                    let data = PDFReportGenerator.generate(from: report)
                    try data.write(to: url)
                case .html:
                    let html = HTMLReportGenerator.generate(from: report)
                    try html.write(to: url, atomically: true, encoding: .utf8)
                }
                flashExportSuccess()
            } catch {
                NSLog("Report export error: %@", String(describing: error))
            }
        }
    }
}

// Stripped-down SwiftUI view used purely as the source for ImageRenderer when
// the user taps Screenshot. Includes Verdict + Highlight + TL;DR + Anomalies.
// Wiring the live variant view directly is non-trivial (bindings, scroll state),
// so we render this offscreen wrapper at scale 2 for retina output.
private struct ReportScreenshotContent: View {
    let snapshot: ReportSnapshot
    let variant: ReportVariant

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline) {
                Text("MACVITAL // REPORT // \(snapshot.period.rawValue)")
                    .font(.system(size: 11, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(MV.text3)
                Spacer()
                Text(variant.displayName.uppercased())
                    .font(.system(size: 11, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(MV.text3)
            }

            (Text(snapshot.verdictHead + " ").foregroundStyle(MV.text1)
             + Text(snapshot.verdictTail).foregroundStyle(snapshot.verdictTone.color))
                .font(.system(size: 30, weight: .semibold))
                .tracking(-0.3)

            VStack(alignment: .leading, spacing: 4) {
                Text("HIGHLIGHT")
                    .font(.system(size: 9, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(MV.text3)
                Text(snapshot.highlightHead)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(MV.text1)
                Text(snapshot.highlightSub)
                    .font(.system(size: 12))
                    .foregroundStyle(MV.text2)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("TL;DR")
                    .font(.system(size: 9, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(MV.text3)
                Text(snapshot.tldr)
                    .font(.system(size: 13))
                    .foregroundStyle(MV.text1)
                    .lineSpacing(3)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("ANOMALIES")
                    .font(.system(size: 9, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(MV.text3)
                ForEach(Array(snapshot.anomalies.enumerated()), id: \.element.id) { idx, a in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("\(idx + 1).")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(MV.text2)
                            .frame(width: 22, alignment: .leading)
                        Text(a.timestamp)
                            .font(.system(size: 11, design: .monospaced))
                            .monospacedDigit()
                            .foregroundStyle(MV.text3)
                            .frame(width: 110, alignment: .leading)
                        Text(a.sentence)
                            .font(.system(size: 12))
                            .foregroundStyle(MV.text1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MV.bg)
    }
}

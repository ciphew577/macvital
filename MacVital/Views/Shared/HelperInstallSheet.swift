// MacVital/Views/Shared/HelperInstallSheet.swift
import SwiftUI

struct HelperInstallSheet: View {
    let appState: AppState

    @State private var commandCopied = false

    private enum C {
        static let bg   = Color(red: 0.11,  green: 0.11,  blue: 0.118)   // #1C1C1E
        static let bg2  = Color(red: 0.173, green: 0.173, blue: 0.18)    // #2C2C2E
        static let bg3  = Color(red: 0.227, green: 0.227, blue: 0.235)   // #3A3A3C
        static let sep  = Color.white.opacity(0.08)
        static let text = Color.white.opacity(0.85)
        static let sub  = Color.white.opacity(0.55)
        static let blue = Color(red: 0.039, green: 0.518, blue: 1.0)     // #0A84FF
        static let orange = Color(red: 1.0, green: 0.624, blue: 0.039)   // #FF9F0A
        static let red  = Color(red: 1.0, green: 0.27, blue: 0.227)      // #FF4539
    }

    /// Path to the helper executable inside the current app bundle.
    private var helperBundlePath: String {
        let appPath = Bundle.main.bundlePath
        return "\(appPath)/Contents/Library/LaunchDaemons/MacVitalHelper"
    }

    private var manualInstallCommand: String {
        "sudo cp \"\(helperBundlePath)\" /Library/PrivilegedHelperTools/com.macvital.helper && sudo launchctl load /Library/LaunchDaemons/com.macvital.helper.plist"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "fan.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(C.blue)
                    .padding(.top, 28)

                Text("Privileged Helper Required")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(C.text)

                Text("MacVital needs a privileged helper to read SMC sensor data and control fan speeds. The helper runs as a launchd daemon and communicates via XPC.")
                    .font(.system(size: 13))
                    .foregroundStyle(C.sub)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 20)

            // Details list
            VStack(alignment: .leading, spacing: 10) {
                DetailRow(icon: "thermometer.medium", text: "Read CPU, GPU, battery & ambient temperatures")
                DetailRow(icon: "fan",                text: "Read real-time fan RPM from SMC")
                DetailRow(icon: "slider.horizontal.3",text: "Set fan speed overrides (manual / auto-boost)")
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(C.bg2, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(C.sep, lineWidth: 1)
            )
            .padding(.horizontal, 24)

            Spacer().frame(height: 16)

            // Error + manual install section (shown on failure)
            if let errorMessage = appState.helperInstallError {
                VStack(alignment: .leading, spacing: 12) {
                    // Error banner
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(C.orange)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Automatic installation failed")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(C.orange)
                            Text(errorMessage)
                                .font(.system(size: 11))
                                .foregroundStyle(C.sub)
                                .lineLimit(3)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(C.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(C.orange.opacity(0.25), lineWidth: 1)
                    )

                    // Manual install instructions
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Manual Installation (Development Build)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(C.sub)

                        Text("Ad-hoc signed builds require manual daemon setup. Run this in Terminal, then restart MacVital:")
                            .font(.system(size: 11))
                            .foregroundStyle(C.sub.opacity(0.8))

                        // Terminal command display
                        HStack(spacing: 8) {
                            Text("sudo cp ... && sudo launchctl load ...")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(C.text.opacity(0.7))
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(manualInstallCommand, forType: .string)
                                commandCopied = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    commandCopied = false
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: commandCopied ? "checkmark" : "doc.on.doc")
                                        .font(.system(size: 10))
                                    Text(commandCopied ? "Copied" : "Copy")
                                        .font(.system(size: 10, weight: .medium))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(commandCopied ? C.orange : C.blue)
                            .background(
                                (commandCopied ? C.orange : C.blue).opacity(0.15),
                                in: RoundedRectangle(cornerRadius: 5)
                            )
                        }
                        .padding(10)
                        .background(C.bg3, in: RoundedRectangle(cornerRadius: 7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .strokeBorder(C.sep, lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 24)

                Spacer().frame(height: 16)
            } else {
                Spacer().frame(height: 8)
            }

            // Action buttons
            VStack(spacing: 10) {
                Button {
                    appState.installHelper()
                } label: {
                    HStack {
                        Image(systemName: "lock.shield.fill")
                        Text("Install Helper")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(C.blue, in: RoundedRectangle(cornerRadius: 9))

                Button {
                    appState.showHelperInstallPrompt = false
                } label: {
                    Text("Skip for Now")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .foregroundStyle(C.sub)
                .background(C.bg3, in: RoundedRectangle(cornerRadius: 9))
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .strokeBorder(C.sep, lineWidth: 1)
                )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .frame(width: 360)
        .background(C.bg)
    }
}

// MARK: - Detail Row

private struct DetailRow: View {
    let icon: String
    let text: String

    private enum C {
        static let blue = Color(red: 0.039, green: 0.518, blue: 1.0)
        static let sub  = Color.white.opacity(0.65)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(C.blue)
                .frame(width: 20, alignment: .center)

            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(C.sub)
        }
    }
}

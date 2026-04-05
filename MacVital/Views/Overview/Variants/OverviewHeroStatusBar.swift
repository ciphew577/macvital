// Status-Bar variant: compact horizontal bar across full width with ambient sparkline behind the row.

import SwiftUI

struct OverviewHeroStatusBar: View {
    @Environment(AppState.self) private var appState

    private var monitor: SystemMonitor { appState.monitor }

    var body: some View {
        let snap = OverviewHeroBuilder.snapshot(from: monitor)

        ZStack(alignment: .topLeading) {
            MVSparkline(data: snap.sparkData, color: MV.accentSage.opacity(0.55))
                .frame(maxHeight: .infinity)
                .padding(.horizontal, MV.S.s4)
                .padding(.vertical, MV.S.s3)
                .opacity(0.5)

            VStack(alignment: .leading, spacing: MV.S.s2) {
                HStack(spacing: 6) {
                    Text("MACVITAL · NOW")
                        .font(.system(size: MV.FS.micro, weight: .semibold))
                        .tracking(1.1)
                        .foregroundStyle(MV.text3)
                    Spacer(minLength: 0)
                    Text("\(snap.machineLine) · \(snap.chipLine) · \(snap.uptimeLine)")
                        .font(.system(size: MV.FS.micro))
                        .foregroundStyle(MV.text3)
                        .lineLimit(1)
                }

                HStack(alignment: .center, spacing: MV.S.s4) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Running steady, in spec.")
                            .font(.system(size: MV.FS.h3, weight: .medium))
                            .tracking(-0.4)
                            .foregroundStyle(MV.text1)
                            .lineLimit(1)
                        Text("five sub-scores. tap any pip for the matching tab.")
                            .font(.system(size: MV.FS.micro))
                            .foregroundStyle(MV.text3)
                    }

                    Rectangle().fill(MV.hairline).frame(width: 0.5, height: 36)

                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(snap.score)")
                            .font(.system(size: 56, weight: .semibold))
                            .tracking(-1.6)
                            .foregroundStyle(OverviewHeroBuilder.color(for: snap.scoreTone))
                            .monospacedDigit()
                        VStack(alignment: .leading, spacing: 0) {
                            Text("HEALTH")
                                .font(.system(size: 9, weight: .semibold))
                                .tracking(0.8)
                                .foregroundStyle(MV.text3)
                            Text(snap.scoreLabel)
                                .font(.system(size: MV.FS.caption, weight: .medium))
                                .foregroundStyle(MV.text2)
                        }
                    }

                    Rectangle().fill(MV.hairline).frame(width: 0.5, height: 36)

                    HStack(alignment: .top, spacing: MV.S.s2) {
                        ForEach(snap.pips) { pip in
                            statusPip(pip: pip)
                        }
                    }

                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("THROTTLE · 6H")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(0.6)
                            .foregroundStyle(MV.text3)
                        Text("\(snap.throttleEvents)")
                            .font(.system(size: MV.FS.h3, weight: .semibold))
                            .foregroundStyle(snap.throttleEvents > 0 ? MV.warning : MV.text2)
                            .monospacedDigit()
                        Text("events")
                            .font(.system(size: 9))
                            .foregroundStyle(MV.text4)
                    }
                }

                Spacer(minLength: 0)

                HStack(spacing: MV.S.s3) {
                    Text("60 min ago")
                    Spacer()
                    Text("now")
                }
                .font(.system(size: 9))
                .foregroundStyle(MV.text4)
            }
            .padding(.horizontal, MV.S.s5)
            .padding(.vertical, MV.S.s4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(MV.tile)
        .overlay(
            RoundedRectangle(cornerRadius: MV.radius)
                .strokeBorder(MV.hairline, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: MV.radius))
    }

    private func statusPip(pip: OverviewHeroPip) -> some View {
        let color = OverviewHeroBuilder.color(for: pip.tone)
        return VStack(alignment: .leading, spacing: 2) {
            Text(pip.label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(MV.text3)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(pip.value)")
                    .font(.system(size: MV.FS.value, weight: .semibold))
                    .foregroundStyle(color)
                    .monospacedDigit()
                Capsule()
                    .fill(color.opacity(0.6))
                    .frame(width: 18, height: 2)
            }
        }
        .frame(width: 64, alignment: .leading)
    }
}

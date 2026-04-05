// Bento Mosaic variant: equal-weight tile grid for headline, score, sparkline, 5 pips, and since-panel.

import SwiftUI

struct OverviewHeroBentoMosaic: View {
    @Environment(AppState.self) private var appState

    private var monitor: SystemMonitor { appState.monitor }

    private let gap: CGFloat = MV.S.s2

    var body: some View {
        let snap = OverviewHeroBuilder.snapshot(from: monitor)

        GeometryReader { geo in
            let totalW = geo.size.width
            let colW = max(0, (totalW - gap * 11) / 12)
            let span: (Int) -> CGFloat = { c in colW * CGFloat(c) + gap * CGFloat(c - 1) }
            let totalH = geo.size.height
            let topH = max(64, (totalH - gap * 3) * 0.28)
            let midH = max(72, (totalH - gap * 3) * 0.36)
            let botH = max(64, (totalH - gap * 3) * 0.36)

            if totalW > 200 {
                VStack(spacing: gap) {
                    idStrip(snap: snap)
                        .frame(width: span(12), height: 22)

                    HStack(spacing: gap) {
                        headlineTile(snap: snap)
                            .frame(width: span(7), height: topH + midH + gap)
                        VStack(spacing: gap) {
                            scoreTile(snap: snap)
                                .frame(width: span(5), height: topH)
                            sparkTile(snap: snap)
                                .frame(width: span(5), height: midH)
                        }
                    }

                    HStack(spacing: gap) {
                        ForEach(snap.pips) { pip in
                            pipTile(pip: pip)
                                .frame(width: span(2), height: botH)
                        }
                        sinceTile(snap: snap)
                            .frame(width: span(2), height: botH)
                    }
                }
            } else {
                skeletonPlaceholder
            }
        }
        .padding(MV.S.s3)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(MV.bg)
        .overlay(
            RoundedRectangle(cornerRadius: MV.radius)
                .strokeBorder(MV.hairline, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: MV.radius))
    }

    private var skeletonPlaceholder: some View {
        VStack(spacing: gap) {
            RoundedRectangle(cornerRadius: MV.radius - 4)
                .fill(MV.tile)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func idStrip(snap: OverviewHeroSnapshot) -> some View {
        HStack(spacing: 6) {
            Text("MACVITAL · TODAY")
                .font(.system(size: MV.FS.micro, weight: .semibold))
                .tracking(1.1)
                .foregroundStyle(MV.text3)
            Text("·").foregroundStyle(MV.text4)
            Text(snap.machineLine)
                .font(.system(size: MV.FS.micro, weight: .semibold))
                .foregroundStyle(MV.text2)
            Text("·").foregroundStyle(MV.text4)
            Text(snap.chipLine)
                .font(.system(size: MV.FS.micro))
                .foregroundStyle(MV.text3)
            Spacer(minLength: 0)
            Text(snap.uptimeLine)
                .font(.system(size: MV.FS.micro))
                .foregroundStyle(MV.text3)
        }
    }

    private func headlineTile(snap: OverviewHeroSnapshot) -> some View {
        bentoCell(eyebrow: "NOW") {
            VStack(alignment: .leading, spacing: MV.S.s2) {
                Text("Running steady, in spec.")
                    .font(.system(size: MV.FS.h3, weight: .medium))
                    .tracking(-0.4)
                    .foregroundStyle(MV.text1)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Five sub-scores read across the row. The user's eye finds the worst one. No element fights for the room.")
                    .font(.system(size: MV.FS.body))
                    .lineSpacing(2)
                    .foregroundStyle(MV.text2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                HStack(spacing: 4) {
                    Circle()
                        .fill(OverviewHeroBuilder.color(for: snap.scoreTone))
                        .frame(width: 5, height: 5)
                    Text(snap.scoreLabel)
                        .font(.system(size: MV.FS.caption, weight: .semibold))
                        .foregroundStyle(OverviewHeroBuilder.color(for: snap.scoreTone))
                }
            }
        }
    }

    private func scoreTile(snap: OverviewHeroSnapshot) -> some View {
        bentoCell(eyebrow: "HEALTH · OF 100") {
            HStack(alignment: .firstTextBaseline, spacing: MV.S.s2) {
                Text("\(snap.score)")
                    .font(.system(size: 56, weight: .semibold))
                    .tracking(-1.6)
                    .foregroundStyle(OverviewHeroBuilder.color(for: snap.scoreTone))
                    .monospacedDigit()
                VStack(alignment: .leading, spacing: 0) {
                    Text("band")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(MV.text3)
                    Text(snap.scoreLabel)
                        .font(.system(size: MV.FS.caption, weight: .medium))
                        .foregroundStyle(MV.text2)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func sparkTile(snap: OverviewHeroSnapshot) -> some View {
        bentoCell(eyebrow: "HEALTH · 60 MIN") {
            VStack(alignment: .leading, spacing: 4) {
                MVSparkline(data: snap.sparkData, color: MV.accentSage)
                    .frame(maxHeight: .infinity)
                HStack {
                    Text("60 min ago")
                    Spacer()
                    Text("throttle \(snap.throttleEvents)")
                        .monospacedDigit()
                    Spacer()
                    Text("now")
                }
                .font(.system(size: 9))
                .foregroundStyle(MV.text4)
            }
        }
    }

    private func pipTile(pip: OverviewHeroPip) -> some View {
        let color = OverviewHeroBuilder.color(for: pip.tone)
        return bentoCell(eyebrow: pip.label.uppercased()) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(pip.value)")
                        .font(.system(size: MV.FS.h3, weight: .semibold))
                        .tracking(-0.4)
                        .foregroundStyle(color)
                        .monospacedDigit()
                    Text("/100")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(MV.text4)
                        .baselineOffset(2)
                }
                Spacer(minLength: 0)
                Text(pip.sub)
                    .font(.system(size: 9))
                    .foregroundStyle(MV.text3)
                    .lineLimit(2)
                Capsule()
                    .fill(color.opacity(0.5))
                    .frame(height: 2)
            }
        }
    }

    private func sinceTile(snap: OverviewHeroSnapshot) -> some View {
        bentoCell(eyebrow: "SINCE OPEN") {
            VStack(alignment: .leading, spacing: 3) {
                Text(snap.uptimeLine)
                    .font(.system(size: MV.FS.caption, weight: .semibold))
                    .foregroundStyle(MV.text1)
                    .monospacedDigit()
                Text("peak \(Int(monitor.sensors?.sensors.map(\.value).max() ?? 0))°C")
                    .font(.system(size: 9))
                    .foregroundStyle(MV.text3)
                Text("throttle \(snap.throttleEvents)")
                    .font(.system(size: 9))
                    .foregroundStyle(MV.text3)
                    .monospacedDigit()
                Spacer(minLength: 0)
            }
        }
    }

    private func bentoCell<Content: View>(
        eyebrow: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(eyebrow)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(MV.text3)
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(MV.S.s2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(MV.tile)
        .overlay(
            RoundedRectangle(cornerRadius: MV.radius - 4)
                .strokeBorder(MV.hairline, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: MV.radius - 4))
    }
}

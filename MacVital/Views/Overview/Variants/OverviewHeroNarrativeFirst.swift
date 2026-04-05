// Narrative-First variant: big headline taking ~60% width with inline pip dots embedded in prose.

import SwiftUI

struct OverviewHeroNarrativeFirst: View {
    @Environment(AppState.self) private var appState

    private var monitor: SystemMonitor { appState.monitor }

    var body: some View {
        let snap = OverviewHeroBuilder.snapshot(from: monitor)

        VStack(alignment: .leading, spacing: MV.S.s2) {
            HStack(spacing: 6) {
                Text(snap.uptimeLine)
                    .font(.system(size: MV.FS.micro, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(MV.text3)
                Text("·").foregroundStyle(MV.text4)
                Text("\(snap.machineLine) · \(snap.chipLine)")
                    .font(.system(size: MV.FS.micro))
                    .foregroundStyle(MV.text3)
                    .lineLimit(1)
                Spacer(minLength: 0)
                HStack(spacing: 4) {
                    Text("Health")
                        .font(.system(size: MV.FS.micro, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(MV.text3)
                    Text("\(snap.score)")
                        .font(.system(size: MV.FS.h3, weight: .semibold))
                        .tracking(-0.6)
                        .foregroundStyle(OverviewHeroBuilder.color(for: snap.scoreTone))
                        .monospacedDigit()
                    Text("/100")
                        .font(.system(size: MV.FS.micro))
                        .foregroundStyle(MV.text4)
                    Text("· \(snap.scoreLabel)")
                        .font(.system(size: MV.FS.micro))
                        .foregroundStyle(MV.text3)
                }
            }

            HStack(alignment: .top, spacing: MV.S.s4) {
                VStack(alignment: .leading, spacing: MV.S.s3) {
                    Text("Running steady,")
                        .font(.system(size: 56, weight: .semibold, design: .serif))
                        .tracking(-1.4)
                        .foregroundStyle(MV.text1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("still in spec.")
                        .font(.system(size: 56, weight: .semibold, design: .serif))
                        .tracking(-1.4)
                        .italic()
                        .foregroundStyle(MV.accentSage)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.top, -10)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(2)
                Spacer(minLength: 0)
            }

            FlowingPipText(snap: snap)
                .padding(.top, MV.S.s2)

            Spacer(minLength: MV.S.s2)

            HStack(alignment: .center, spacing: MV.S.s4) {
                ForEach(snap.pips.prefix(3)) { pip in
                    inlineSinceCol(pip: pip)
                }
                Spacer(minLength: 0)
                MVSparkline(data: snap.sparkData, color: MV.accentSage)
                    .frame(width: 180, height: 36)
            }
        }
        .padding(.horizontal, MV.S.s5)
        .padding(.vertical, MV.S.s4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(MV.tile)
        .overlay(
            RoundedRectangle(cornerRadius: MV.radius)
                .strokeBorder(MV.hairline, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: MV.radius))
    }

    private func inlineSinceCol(pip: OverviewHeroPip) -> some View {
        let color = OverviewHeroBuilder.color(for: pip.tone)
        return VStack(alignment: .leading, spacing: 1) {
            Text(pip.label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(MV.text3)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Circle().fill(color).frame(width: 5, height: 5)
                Text("\(pip.value)")
                    .font(.system(size: MV.FS.value, weight: .semibold))
                    .foregroundStyle(color)
                    .monospacedDigit()
            }
        }
    }
}

private struct FlowingPipText: View {
    let snap: OverviewHeroSnapshot

    var body: some View {
        let pips = snap.pips
        Text(buildAttributed(pips: pips))
            .font(.system(size: MV.FS.body))
            .lineSpacing(3)
            .foregroundStyle(MV.text2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func buildAttributed(pips: [OverviewHeroPip]) -> AttributedString {
        var s = AttributedString("Five sub-scores read ")
        for (i, p) in pips.enumerated() {
            var dot = AttributedString("● ")
            dot.foregroundColor = OverviewHeroBuilder.color(for: p.tone)
            dot.font = .system(size: 8, weight: .bold)
            var lbl = AttributedString("\(p.label) ")
            lbl.foregroundColor = MV.text3
            lbl.font = .system(size: MV.FS.body, weight: .medium)
            var num = AttributedString("\(p.value)")
            num.foregroundColor = OverviewHeroBuilder.color(for: p.tone)
            num.font = .system(size: MV.FS.body, weight: .semibold).monospacedDigit()
            s.append(dot)
            s.append(lbl)
            s.append(num)
            if i < pips.count - 1 {
                s.append(AttributedString("   "))
            }
        }
        s.append(AttributedString(". The lowest pip drives the band, the rest are quiet."))
        return s
    }
}

// Instrument variant: giant 96pt+ Health numeral with a clock-face arc and pip dots.

import SwiftUI

struct OverviewHeroInstrument: View {
    @Environment(AppState.self) private var appState

    private var monitor: SystemMonitor { appState.monitor }

    var body: some View {
        let snap = OverviewHeroBuilder.snapshot(from: monitor)

        HStack(alignment: .center, spacing: MV.S.s5) {
            ZStack {
                InstrumentArc(score: snap.score, scoreTone: snap.scoreTone)
                    .frame(width: 280, height: 280)

                VStack(spacing: 0) {
                    Text("HEALTH")
                        .font(.system(size: MV.FS.micro, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(MV.text3)
                    Text("\(snap.score)")
                        .font(.system(size: 110, weight: .semibold))
                        .tracking(-3.2)
                        .foregroundStyle(OverviewHeroBuilder.color(for: snap.scoreTone))
                        .monospacedDigit()
                        .padding(.top, -2)
                    Text("of 100")
                        .font(.system(size: MV.FS.caption))
                        .foregroundStyle(MV.text3)
                    Text(snap.scoreLabel)
                        .font(.system(size: MV.FS.caption, weight: .medium))
                        .foregroundStyle(MV.text2)
                        .padding(.top, 4)
                }
                .padding(.bottom, 8)

                ForEach(Array(snap.pips.enumerated()), id: \.element.id) { idx, pip in
                    InstrumentArcLabel(pip: pip, position: idx, total: snap.pips.count)
                        .frame(width: 280, height: 280)
                }
            }
            .frame(width: 300, height: 300)

            VStack(alignment: .leading, spacing: MV.S.s2) {
                HStack(spacing: 6) {
                    Text("SYSTEM HEALTH · LIVE")
                        .font(.system(size: MV.FS.micro, weight: .semibold))
                        .tracking(1.1)
                        .foregroundStyle(MV.text3)
                    Spacer(minLength: 0)
                    Text(snap.machineLine)
                        .font(.system(size: MV.FS.micro, weight: .semibold))
                        .foregroundStyle(MV.text2)
                }

                Text("Running steady, in spec.")
                    .font(.system(size: MV.FS.h3, weight: .medium))
                    .tracking(-0.4)
                    .foregroundStyle(MV.text1)
                    .padding(.top, 2)

                Text("\(snap.chipLine) · \(snap.uptimeLine). Click any pip to open the matching diagnostics tab. Hold command for the full panel.")
                    .font(.system(size: MV.FS.body))
                    .lineSpacing(2)
                    .foregroundStyle(MV.text2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: MV.S.s2)

                HStack(spacing: 4) {
                    Text("HEALTH · 60 MIN")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(MV.text4)
                    Spacer()
                    Text("throttle \(snap.throttleEvents)")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.4)
                        .foregroundStyle(MV.text4)
                        .monospacedDigit()
                }
                MVSparkline(data: snap.sparkData, color: MV.accentSage)
                    .frame(height: 32)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
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
}

private struct InstrumentArc: View {
    let score: Int
    let scoreTone: OverviewHeroPip.Tone

    var body: some View {
        Canvas { ctx, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 14
            let startDeg = 140.0
            let endDeg   = 40.0
            let sweep = 360.0 - (startDeg - endDeg)

            var track = Path()
            track.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(startDeg),
                endAngle: .degrees(endDeg + 360),
                clockwise: false
            )
            ctx.stroke(track, with: .color(MV.hairline), lineWidth: 2)

            let progressEnd = startDeg + sweep * Double(min(max(score, 0), 100)) / 100
            var progress = Path()
            progress.addArc(
                center: center,
                radius: radius,
                startAngle: .degrees(startDeg),
                endAngle: .degrees(progressEnd),
                clockwise: false
            )
            let stroke = StrokeStyle(lineWidth: 2.4, lineCap: .round)
            ctx.stroke(progress, with: .color(OverviewHeroBuilder.color(for: scoreTone)), style: stroke)

            let inner = Path(ellipseIn: CGRect(
                x: center.x - radius + 18, y: center.y - radius + 18,
                width: 2 * (radius - 18), height: 2 * (radius - 18)
            ))
            ctx.stroke(inner, with: .color(MV.hairline.opacity(0.4)), lineWidth: 0.5)
        }
    }
}

private struct InstrumentArcLabel: View {
    let pip: OverviewHeroPip
    let position: Int
    let total: Int

    var body: some View {
        GeometryReader { geo in
            let r = min(geo.size.width, geo.size.height) / 2 - 14
            let startDeg = 140.0
            let sweep = 260.0
            let frac = total > 1 ? Double(position) / Double(total - 1) : 0.5
            let deg = startDeg + sweep * frac
            let rad = deg * .pi / 180
            let cx = geo.size.width / 2 + cos(rad) * r
            let cy = geo.size.height / 2 + sin(rad) * r

            let color = OverviewHeroBuilder.color(for: pip.tone)
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                    .position(x: cx, y: cy)

                VStack(spacing: 0) {
                    Text(pip.label.uppercased())
                        .font(.system(size: 8, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(MV.text3)
                    Text("\(pip.value)")
                        .font(.system(size: MV.FS.caption, weight: .semibold))
                        .foregroundStyle(color)
                        .monospacedDigit()
                }
                .position(x: cx + cos(rad) * 18, y: cy + sin(rad) * 14)
            }
        }
    }
}

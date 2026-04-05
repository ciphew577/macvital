// Editorial variant: large serif headline + small numeric Health + sparkline-dominated footer.

import SwiftUI

struct OverviewHeroEditorial: View {
    @Environment(AppState.self) private var appState

    private var monitor: SystemMonitor { appState.monitor }

    private var hottestSensor: (name: String, temp: Double)? {
        guard let s = monitor.sensors else { return nil }
        guard let h = s.sensors.max(by: { $0.value < $1.value }) else { return nil }
        return (h.name, h.value)
    }

    private var pCluster: Double? {
        guard let cpu = monitor.cpu else { return nil }
        let p = cpu.cores.filter { $0.clusterType == .performance }
        guard !p.isEmpty else { return nil }
        return p.map(\.usage).reduce(0, +) / Double(p.count)
    }

    private var eCluster: Double? {
        guard let cpu = monitor.cpu else { return nil }
        let e = cpu.cores.filter { $0.clusterType == .efficiency }
        guard !e.isEmpty else { return nil }
        return e.map(\.usage).reduce(0, +) / Double(e.count)
    }

    private var narrative: OverviewNarrative {
        OverviewNarrative.make(from: OverviewNarrative.Inputs(
            hottestSensorName: hottestSensor?.name,
            hottestSensorTemp: hottestSensor?.temp,
            cpuUsage: monitor.cpu?.totalUsage,
            pClusterUsage: pCluster,
            eClusterUsage: eCluster,
            gpuUsage: monitor.gpu?.utilization,
            socPower: monitor.socPower > 0 ? monitor.socPower : nil,
            memoryPressure: monitor.memory?.pressureLevel,
            batteryPercent: monitor.battery?.percentage,
            batteryTimeRemainingMinutes: monitor.battery?.timeRemaining,
            batteryCharging: monitor.battery?.isCharging ?? false,
            maxFanRPM: monitor.sensors?.fans.map(\.rpm).max(),
            fanCount: monitor.sensors?.fans.count ?? 0
        ))
    }

    var body: some View {
        let snap = OverviewHeroBuilder.snapshot(from: monitor)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text("NOW")
                    .font(.system(size: MV.FS.micro, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(MV.text3)
                Text("a system check, in plain language")
                    .font(.system(size: MV.FS.micro))
                    .foregroundStyle(MV.text4)
                    .italic()
                Spacer(minLength: 0)
                Text("\(snap.machineLine) · \(snap.chipLine) · \(snap.uptimeLine)")
                    .font(.system(size: MV.FS.micro))
                    .foregroundStyle(MV.text3)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Text(narrative.attributedHeadline)
                .lineSpacing(-2)
                .tracking(-0.8)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 520, alignment: .leading)
                .padding(.top, MV.S.s2)

            Text(narrative.subtext)
                .font(.system(size: MV.FS.body))
                .lineSpacing(MV.FS.body * 0.55)
                .foregroundStyle(MV.text2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 540, alignment: .leading)
                .padding(.top, MV.S.s2)

            Spacer(minLength: MV.S.s2)

            HStack(alignment: .center, spacing: MV.S.s4) {
                HStack(alignment: .firstTextBaseline, spacing: MV.S.s1) {
                    Text("\(snap.score)")
                        .font(.system(size: MV.FS.h2, weight: .semibold))
                        .tracking(-0.6)
                        .foregroundStyle(OverviewHeroBuilder.color(for: snap.scoreTone))
                        .monospacedDigit()
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Health")
                            .font(.system(size: MV.FS.caption, weight: .medium))
                            .foregroundStyle(MV.text2)
                        Text(snap.scoreLabel)
                            .font(.system(size: MV.FS.micro))
                            .foregroundStyle(MV.text3)
                    }
                }

                Rectangle().fill(MV.hairline).frame(width: 0.5, height: 22)

                HStack(spacing: MV.S.s2) {
                    ForEach(snap.pips) { pip in
                        EditorialPip(pip: pip)
                    }
                }
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("HEALTH · LAST 60 MIN")
                    Spacer()
                    Text("tick 1 min")
                    Spacer()
                    Text("throttle ledger \(snap.throttleEvents) / 6 h")
                }
                .font(.system(size: 9, weight: .medium))
                .tracking(0.4)
                .foregroundStyle(MV.text4)

                MVSparkline(data: snap.sparkData, color: MV.accentSage)
                    .frame(height: 44)

                HStack {
                    Text("60 MIN AGO")
                    Spacer()
                    Text("NOW")
                }
                .font(.system(size: 9, weight: .medium))
                .tracking(0.4)
                .foregroundStyle(MV.text4)
            }
            .padding(.top, MV.S.s3)
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

private struct EditorialPip: View {
    let pip: OverviewHeroPip

    var body: some View {
        let color = OverviewHeroBuilder.color(for: pip.tone)
        VStack(alignment: .leading, spacing: 2) {
            Text(pip.label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(MV.text3)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(pip.value)")
                    .font(.system(size: MV.FS.value, weight: .semibold))
                    .foregroundStyle(color)
                    .monospacedDigit()
                Capsule()
                    .fill(color.opacity(0.6))
                    .frame(width: 18, height: 2)
            }
        }
    }
}

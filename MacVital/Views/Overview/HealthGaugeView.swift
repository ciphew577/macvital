// MacVital/Views/Overview/HealthGaugeView.swift
import SwiftUI

struct HealthGaugeView: View {
    let title: String
    let score: Double
    let icon: String
    let detail: String

    var body: some View {
        VStack(spacing: 4) {
            GaugeRingView(value: score, label: "", icon: icon, size: 100, lineWidth: 8)
            Text(title)
                .font(.subheadline.weight(.medium))
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

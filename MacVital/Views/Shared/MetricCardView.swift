// MacVital/Views/Shared/MetricCardView.swift
import SwiftUI

struct MetricCardView: View {
    let title: String
    let value: String
    let icon: String
    var unit: String = ""
    var status: HealthStatus? = nil
    var tooltip: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(statusColor)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                if let status {
                    StatusBadgeView(status: status)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(statusColor.opacity(0.2), lineWidth: 1)
        )
        .help(tooltip ?? "")
    }

    private var statusColor: Color {
        switch status {
        case .good: return .green
        case .warning: return .orange
        case .critical: return .red
        case nil: return .secondary
        }
    }
}

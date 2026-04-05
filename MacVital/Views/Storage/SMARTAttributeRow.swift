// MacVital/Views/Storage/SMARTAttributeRow.swift
import SwiftUI

struct SMARTAttributeRow: View {
    let attribute: SMARTAttribute

    var body: some View {
        HStack(spacing: 12) {
            Text("\(attribute.id)")
                .font(.caption.monospaced())
                .frame(width: 30, alignment: .trailing)
                .foregroundStyle(.secondary)

            Text(attribute.name)
                .font(.callout)
                .frame(minWidth: 180, alignment: .leading)

            Spacer()

            Text(attribute.rawValue)
                .font(.callout.monospaced())
                .frame(width: 100, alignment: .trailing)

            Text(attribute.threshold)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .trailing)

            StatusBadgeView(status: {
                switch attribute.status {
                case .good: return .good
                case .warning: return .warning
                case .critical: return .critical
                case .unknown: return .good
                }
            }())
            .frame(width: 70)
        }
        .padding(.vertical, 4)
        .help(attribute.explanation)
    }
}

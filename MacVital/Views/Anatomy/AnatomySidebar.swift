// MacVital/Views/Anatomy/AnatomySidebar.swift
//
// Left sidebar for the Anatomy tab (Wave 2A).
//
// Mirrors the `.left-sidebar` block in
// mockups/redesign-2026-04-23/anatomy/fusion-1-bento-schematic.html.
//
// Sections, top to bottom:
//   1. System badge (machine title + SoC / macOS / live uptime rows)
//   2. "Filter by category" eyebrow label
//   3. Eight category chips (ALL / POWER / COOLING / STORAGE / AUDIO /
//      WIRELESS / DISPLAY / SENSORS). SENSORS is disabled.
//   4. Alert strip (sage pulse + count + caption)
//   5. "Live events" eyebrow label (with live dot)
//   6. Scrolling events feed (newest first, capped at 30 rows)
//
// State is owned by the @Observable AnatomyViewModel passed in via @Bindable.
// All chip taps mutate the view model through `toggleFilter`.

import SwiftUI

// MARK: - AnatomySidebar

struct AnatomySidebar: View {

    // MARK: - Inputs

    @Bindable var viewModel: AnatomyViewModel

    // MARK: - Layout constants

    private let sidebarWidth: CGFloat = 280
    private let sectionSpacing: CGFloat = 14
    private let outerPadding: CGFloat = 18
    private let chipMaxRows: Int = 30

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: sectionSpacing) {
                systemBadge
                filterLabel
                chipStack
                alertStrip
                liveEventsLabel
                eventsFeed
            }
            .padding(outerPadding)
        }
        .frame(width: sidebarWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(MV.tile)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(MV.hairline)
                .frame(width: 0.5)
        }
    }

    // MARK: - Section 1: System badge

    private var systemBadge: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("MacBook Pro 14 inch")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(MV.text1)

            badgeRow(key: "SOC",    value: "M4 Pro")
            badgeRow(key: "MACOS",  value: "15.4")
            badgeRow(key: "UPTIME", value: viewModel.uptimeString())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MV.tile)
        .overlay(
            RoundedRectangle(cornerRadius: MV.radius)
                .strokeBorder(MV.hairline, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: MV.radius))
    }

    private func badgeRow(key: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(key)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.1)
                .foregroundStyle(MV.text3)
            Spacer(minLength: 4)
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(MV.text1)
        }
    }

    // MARK: - Section 2: Filter label

    private var filterLabel: some View {
        sectionLabel("Filter by category")
    }

    // MARK: - Section 3: Chip stack

    private var chipStack: some View {
        VStack(spacing: 4) {
            ForEach(AnatomyCategory.sidebarChips) { cat in
                chipRow(for: cat)
            }
        }
    }

    private func chipRow(for cat: AnatomyCategory) -> some View {
        ChipRow(cat: cat, viewModel: viewModel)
    }

    // MARK: - Section 4: Alert strip

    private var alertStrip: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(MV.accentSage)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(MV.accentSage.opacity(0.18), lineWidth: 3)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("0 active alerts")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(MV.text1)
                Text("ALL SYSTEMS NOMINAL")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(MV.text3)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: MV.radius)
                .fill(MV.accentSage.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: MV.radius)
                .strokeBorder(MV.accentSage.opacity(0.20), lineWidth: 1)
        )
    }

    // MARK: - Section 5: Live events label

    private var liveEventsLabel: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(MV.accentSage)
                .frame(width: 5, height: 5)
            Text("Live events".uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.1)
                .foregroundStyle(MV.text3)
        }
    }

    // MARK: - Section 6: Events feed

    private var eventsFeed: some View {
        let rows = Array(
            viewModel.events
                .sorted(by: { $0.timestamp > $1.timestamp })
                .prefix(chipMaxRows)
        )

        return ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, event in
                    eventRow(event)
                    if index < rows.count - 1 {
                        Rectangle()
                            .fill(MV.hairline)
                            .frame(height: 0.5)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func eventRow(_ event: AnatomyEvent) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(event.message)
                .font(.system(size: 11))
                .foregroundStyle(MV.text2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Circle()
                    .fill(severityColor(event.severity))
                    .frame(width: 6, height: 6)

                Text(timestampString(event.timestamp))
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundStyle(MV.text3.opacity(0.85))

                Spacer(minLength: 4)

                Text(event.category.displayName.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(event.category.accentColor)
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .semibold))
            .tracking(1.1)
            .foregroundStyle(MV.text3)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func severityColor(_ severity: AnatomyEvent.Severity) -> Color {
        switch severity {
        case .ok:   return MV.accentSage
        case .info: return MV.text3
        case .warn: return MV.warning
        }
    }

    private func timestampString(_ date: Date) -> String {
        let elapsed = Int(Date().timeIntervalSince(date))
        if elapsed < 60   { return "\(max(elapsed, 0))s ago" }
        if elapsed < 3600 { return "\(elapsed / 60)m ago" }
        if elapsed < 86_400 { return "\(elapsed / 3600)h ago" }
        return "\(elapsed / 86_400)d ago"
    }
}

// MARK: - ChipRow

/// One sidebar chip. Mirrors the HTML `.chip` selector: hover background,
/// active-cat tint, count badge with monospaced background, and the toggle
/// click semantics from `applyCatFilter` in the source HTML.
private struct ChipRow: View {

    let cat: AnatomyCategory
    @Bindable var viewModel: AnatomyViewModel

    @State private var isHovering: Bool = false

    private var isActive: Bool { viewModel.activeFilter == cat }
    private var isAllChip: Bool { cat == .all }
    private var isDisabled: Bool { cat == .sensors }

    var body: some View {
        Button {
            guard !isDisabled else { return }
            withAnimation(.easeOut(duration: 0.15)) {
                viewModel.toggleFilter(cat)
            }
        } label: {
            HStack(spacing: 9) {
                Circle()
                    .fill(cat.accentColor)
                    .frame(width: 8, height: 8)

                Text(cat.displayName.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(isActive ? MV.text1 : MV.text2)

                Spacer(minLength: 4)

                // Count badge: monospaced number on tile-h background, matching
                // the HTML `.chip-count` style (background, padding, radius).
                Text("\(cat.count)")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(MV.text4)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(MV.tileHover)
                    )
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(backgroundFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
            .opacity(isDisabled ? 0.4 : 1.0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .onHover { hovering in
            guard !isDisabled else { return }
            isHovering = hovering
        }
        .accessibilityLabel("\(cat.displayName) filter")
        .accessibilityValue("\(cat.count) components, \(isActive ? "active" : "inactive")")
        .accessibilityHint(isDisabled ? "Disabled" : "Toggle filter")
        .accessibilityAddTraits(isActive ? .isSelected : [])
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .animation(.easeOut(duration: 0.15), value: isActive)
    }

    /// Background fill matches the HTML cascade: active beats hover beats clear.
    private var backgroundFill: Color {
        if isActive && !isAllChip {
            return MV.accentSage.opacity(0.14)
        }
        if isAllChip && viewModel.activeFilter == .all {
            // ALL chip when no filter is active: subtle tint to read as the
            // "selected" chip, mirroring the HTML which leaves ALL plain when
            // nothing else is selected. We give it a subtle hover tint only.
            return isHovering ? MV.tileHover : Color.clear
        }
        if isHovering {
            return MV.tileHover
        }
        return Color.clear
    }

    private var borderColor: Color {
        if isActive && !isAllChip {
            return MV.accentSage.opacity(0.35)
        }
        return Color.clear
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Anatomy sidebar") {
    let viewModel = AnatomyViewModel()
    let now = Date()
    viewModel.events = [
        AnatomyEvent(timestamp: now.addingTimeInterval(-15),
                     severity: .ok,
                     message: "FAN2 ramped to 2218 rpm",
                     category: .cooling),
        AnatomyEvent(timestamp: now.addingTimeInterval(-90),
                     severity: .info,
                     message: "ANT2 reattached at 5 GHz",
                     category: .wireless),
        AnatomyEvent(timestamp: now.addingTimeInterval(-240),
                     severity: .warn,
                     message: "U3 temperature crossed 44 C",
                     category: .storage),
        AnatomyEvent(timestamp: now.addingTimeInterval(-480),
                     severity: .ok,
                     message: "BT1 charge held at 82 percent",
                     category: .power),
        AnatomyEvent(timestamp: now.addingTimeInterval(-820),
                     severity: .info,
                     message: "LCD1 refresh stayed at 120 Hz",
                     category: .display),
        AnatomyEvent(timestamp: now.addingTimeInterval(-1_500),
                     severity: .ok,
                     message: "SPK1 mix engaged after wake",
                     category: .audio)
    ]

    return AnatomySidebar(viewModel: viewModel)
        .frame(width: 280, height: 820)
        .background(MV.bg)
}
#endif

// MacVital/Views/Shared/PalettePicker.swift
//
// Two picker components:
//   PalettePicker       -- 6 swatches in a 3x2 grid (72x44pt each), full preview
//   PalettePickerDense  -- horizontal 6-button row for Settings, 28pt tall

import SwiftUI

// MARK: - Full swatch picker

struct PalettePicker: View {
    @Bindable var store: MVPaletteStore

    private let columns = [
        GridItem(.fixed(72), spacing: 10),
        GridItem(.fixed(72), spacing: 10),
        GridItem(.fixed(72), spacing: 10),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(MVPaletteID.allCases) { id in
                Button {
                    store.selectedID = id
                } label: {
                    SwatchCard(id: id, isSelected: store.selectedID == id)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(id.displayName) palette")
                .accessibilityValue(store.selectedID == id ? "selected" : "not selected")
                .accessibilityAddTraits(store.selectedID == id ? .isSelected : [])
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.04))
        )
    }
}

// MARK: - Individual swatch card

private struct SwatchCard: View {
    let id: MVPaletteID
    let isSelected: Bool

    private var t: MVPaletteTokens { .tokens(for: id) }

    var body: some View {
        VStack(spacing: 5) {
            // Preview strip: bg base, one tile block, accent dot
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(t.bg)
                    .frame(width: 72, height: 28)

                // Tile strip occupying right two-thirds
                RoundedRectangle(cornerRadius: 3)
                    .fill(t.tile)
                    .frame(width: 44, height: 20)
                    .padding(.leading, 24)

                // Accent dot
                Circle()
                    .fill(t.accentSage)
                    .frame(width: 7, height: 7)
                    .padding(.leading, 8)
                    .padding(.top, 0)
            }

            Text(id.displayName)
                .font(.system(size: 9, weight: .medium))
                .tracking(0.4)
                .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.50))
                .lineLimit(1)
        }
        .frame(width: 72, height: 44)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(
                    isSelected ? t.accentSage : Color.white.opacity(0.10),
                    lineWidth: isSelected ? 1.0 : 0.5
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .contentShape(Rectangle())
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Dense picker (for Settings row)

struct PalettePickerDense: View {
    @Bindable var store: MVPaletteStore

    var body: some View {
        HStack(spacing: 6) {
            ForEach(MVPaletteID.allCases) { id in
                Button {
                    store.selectedID = id
                } label: {
                    DenseButton(id: id, isSelected: store.selectedID == id)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(id.displayName) palette")
                .accessibilityValue(store.selectedID == id ? "selected" : "not selected")
                .accessibilityAddTraits(store.selectedID == id ? .isSelected : [])
            }
        }
        .frame(height: 28)
    }
}

private struct DenseButton: View {
    let id: MVPaletteID
    let isSelected: Bool

    private var t: MVPaletteTokens { .tokens(for: id) }

    var body: some View {
        HStack(spacing: 5) {
            // 8x8 color swatch
            RoundedRectangle(cornerRadius: 2)
                .fill(t.accentSage)
                .frame(width: 8, height: 8)

            Text(id.displayName.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.45))
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? t.tile : Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(
                    isSelected ? t.accentSage.opacity(0.70) : Color.white.opacity(0.08),
                    lineWidth: 0.5
                )
        )
        .contentShape(Rectangle())
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Previews

#if DEBUG

#Preview("Full Picker -- all palettes") {
    let store = MVPaletteStore()
    return VStack(spacing: 24) {
        PalettePicker(store: store)
        Text("Selected: \(store.selectedID.displayName)")
            .font(.system(size: 11))
            .foregroundStyle(Color.white.opacity(0.60))
    }
    .padding(24)
    .frame(width: 300)
    .background(Color(red: 0.07, green: 0.07, blue: 0.08))
}

#Preview("Dense Picker -- Settings row") {
    let store = MVPaletteStore()
    return VStack(alignment: .leading, spacing: 16) {
        ForEach(MVPaletteID.allCases) { id in
            Button {
                store.selectedID = id
            } label: {
                Text("Select \(id.displayName)")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.50))
            }
            .buttonStyle(.plain)
        }
        Divider().opacity(0.2)
        PalettePickerDense(store: store)
    }
    .padding(20)
    .frame(width: 500)
    .background(Color(red: 0.07, green: 0.07, blue: 0.08))
}

#endif

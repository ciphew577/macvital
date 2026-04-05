import SwiftUI

struct StorageTruthTableStairCards: View {
    let triad: StorageTruthTriad?

    var body: some View {
        StorageVariantTruthHost(triad: triad) { t in
            VStack(spacing: 8) {
                HStack(alignment: .bottom, spacing: 18) {
                    card(headLabel: "Apps see",
                         tag: ("True free", .truee),
                         accent: StorageVariantPalette.sage,
                         bytes: t.appsBytes,
                         apiKey: ".volumeAvailableCapacityKey",
                         sentence: "What an app gets when it asks for free space. Writes succeed up to here without the OS having to free anything.",
                         height: 200)
                    card(headLabel: "Finder shows",
                         tag: ("User-facing", .finder),
                         accent: StorageVariantPalette.slate,
                         bytes: t.finderBytes,
                         apiKey: ".volumeAvailableCapacityForImportantUsageKey",
                         sentence: sentenceFinder(t: t),
                         height: 240)
                    card(headLabel: "OS could free",
                         tag: ("Best case", .os),
                         accent: StorageVariantPalette.amber,
                         bytes: t.opportunisticBytes,
                         apiKey: ".volumeAvailableCapacityForOpportunisticUsageKey",
                         sentence: "Optimistic ceiling. Adds opportunistic data the OS thinks it can shed, like cached video and Photos originals. Not guaranteed.",
                         height: 280)
                }
                axisRule
            }
        }
    }

    private func card(headLabel: String,
                      tag: (String, StorageVariantLabelTag.Kind),
                      accent: Color, bytes: UInt64,
                      apiKey: String, sentence: String, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(headLabel.uppercased())
                    .font(.system(size: 9, weight: .bold).monospaced())
                    .kerning(1.6)
                    .foregroundStyle(StorageVariantPalette.text3)
                Spacer()
                StorageVariantLabelTag(kind: tag.1, text: tag.0)
            }
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(StorageTruthFmt.gb(bytes))
                    .font(.system(size: 40, weight: .semibold).monospacedDigit())
                    .kerning(-0.5)
                    .foregroundStyle(StorageVariantPalette.text1)
                Text("GB").font(.system(size: 18, weight: .medium).monospaced()).foregroundStyle(StorageVariantPalette.text3)
            }
            Text(apiKey)
                .font(.system(size: 9.5).monospaced())
                .foregroundStyle(StorageVariantPalette.text4)
            Text(sentence)
                .font(.system(size: 11))
                .foregroundStyle(StorageVariantPalette.text2)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(EdgeInsets(top: 18, leading: 20, bottom: 18, trailing: 20))
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: height, alignment: .top)
        .background {
            ZStack(alignment: .bottom) {
                Rectangle().fill(StorageVariantPalette.tileDeep)
                Rectangle().fill(accent.opacity(0.06)).frame(height: height * 0.55)
            }
        }
        .overlay(alignment: .bottom) { Rectangle().fill(accent).frame(height: 3) }
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(StorageVariantPalette.hair, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var axisRule: some View {
        HStack(spacing: 10) {
            Text("Strict")
                .font(.system(size: 9).monospaced())
                .kerning(1.0)
                .foregroundStyle(StorageVariantPalette.text4)
            Rectangle()
                .fill(StorageVariantPalette.hairLine)
                .frame(height: 1)
            Text("Generous")
                .font(.system(size: 9).monospaced())
                .kerning(1.0)
                .foregroundStyle(StorageVariantPalette.text4)
        }
        .textCase(.uppercase)
        .padding(.top, 4)
    }

    private func sentenceFinder(t: StorageTruthTriad) -> String {
        let purgeable = t.finderBytes > t.appsBytes ? t.finderBytes - t.appsBytes : 0
        return "What Finder and About This Mac display. Adds \(StorageTruthFmt.gb(purgeable)) GB of purgeable caches and snapshots, freed under pressure."
    }
}

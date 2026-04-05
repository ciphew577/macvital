import SwiftUI

struct StorageTruthTableThreeCellRow: View {
    let triad: StorageTruthTriad?

    var body: some View {
        StorageVariantTruthHost(triad: triad) { t in
            HStack(alignment: .top, spacing: 16) {
                cell(headLabel: "Apps see",
                     tag: ("True free", .truee),
                     accent: StorageVariantPalette.sage,
                     bytes: t.appsBytes,
                     apiKey: ".volumeAvailableCapacityKey",
                     sentence: "What an app gets when it asks the system for free space. Writes are guaranteed up to here without the OS having to free anything first.")

                cell(headLabel: "Finder shows",
                     tag: ("User-facing", .finder),
                     accent: StorageVariantPalette.slate,
                     bytes: t.finderBytes,
                     apiKey: ".volumeAvailableCapacityForImportantUsageKey",
                     sentence: sentenceFinder(triad: t))

                cell(headLabel: "OS could free",
                     tag: ("Best case", .os),
                     accent: StorageVariantPalette.amber,
                     bytes: t.opportunisticBytes,
                     apiKey: ".volumeAvailableCapacityForOpportunisticUsageKey",
                     sentence: "Optimistic ceiling. Adds opportunistic data the OS thinks it can shed, like cached video and Photos originals. Not guaranteed.")
            }
        }
    }

    private func cell(headLabel: String, tag: (String, StorageVariantLabelTag.Kind),
                      accent: Color, bytes: UInt64, apiKey: String, sentence: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(headLabel.uppercased())
                    .font(.system(size: 9, weight: .bold).monospaced())
                    .kerning(1.6)
                    .foregroundStyle(StorageVariantPalette.text3)
                Spacer()
                StorageVariantLabelTag(kind: tag.1, text: tag.0)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(StorageTruthFmt.gb(bytes))
                    .font(.system(size: 44, weight: .semibold).monospacedDigit())
                    .kerning(-0.5)
                    .foregroundStyle(StorageVariantPalette.text1)
                Text("GB")
                    .font(.system(size: 20, weight: .medium).monospaced())
                    .foregroundStyle(StorageVariantPalette.text3)
            }
            Text(apiKey)
                .font(.system(size: 9.5).monospaced())
                .foregroundStyle(StorageVariantPalette.text4)
            Text(sentence)
                .font(.system(size: 11.5))
                .foregroundStyle(StorageVariantPalette.text2)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(StorageVariantPalette.tileDeep, in: RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .leading) {
            Rectangle().fill(accent).frame(width: 2)
        }
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(StorageVariantPalette.hair, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func sentenceFinder(triad t: StorageTruthTriad) -> String {
        let purgeable = t.finderBytes > t.appsBytes ? t.finderBytes - t.appsBytes : 0
        return "What Finder, About This Mac, and Disk Utility report. Adds \(StorageTruthFmt.gb(purgeable)) GB of purgeable caches and snapshots the OS will reclaim under pressure."
    }
}

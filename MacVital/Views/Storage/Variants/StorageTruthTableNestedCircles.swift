import SwiftUI

struct StorageTruthTableNestedCircles: View {
    let triad: StorageTruthTriad?

    var body: some View {
        StorageVariantTruthHost(triad: triad) { t in
            HStack(alignment: .center, spacing: 28) {
                rings(t: t)
                    .frame(width: 320, height: 280)
                rows(t: t)
            }
        }
    }

    private func frac(_ part: UInt64, _ total: UInt64) -> Double {
        guard total > 0 else { return 0 }
        return min(1.0, Double(part) / Double(total))
    }

    private func rings(t: StorageTruthTriad) -> some View {
        ZStack {
            arc(radius: 124, lineWidth: 6, fill: frac(t.usedFinderBytes, t.totalBytes),
                color: StorageVariantPalette.text5.opacity(0.4), trackColor: .clear)
            ringPair(radius: 100, fill: frac(t.opportunisticBytes, t.totalBytes),
                     ringFill: StorageVariantPalette.amberFill, ringStroke: StorageVariantPalette.amber)
            ringPair(radius: 76, fill: frac(t.finderBytes, t.totalBytes),
                     ringFill: StorageVariantPalette.slateFill, ringStroke: StorageVariantPalette.slate)
            ringPair(radius: 52, fill: frac(t.appsBytes, t.totalBytes),
                     ringFill: StorageVariantPalette.sageFill, ringStroke: StorageVariantPalette.sage)

            Circle().strokeBorder(Color.white.opacity(0.04), lineWidth: 0.5).frame(width: 104, height: 104)
            Circle().strokeBorder(Color.white.opacity(0.04), lineWidth: 0.5).frame(width: 152, height: 152)
            Circle().strokeBorder(Color.white.opacity(0.04), lineWidth: 0.5).frame(width: 200, height: 200)
            Circle().strokeBorder(Color.white.opacity(0.03), lineWidth: 0.5).frame(width: 248, height: 248)

            VStack(spacing: 2) {
                Text("TOTAL")
                    .font(.system(size: 9, weight: .bold).monospaced())
                    .kerning(1.6)
                    .foregroundStyle(StorageVariantPalette.text4)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(StorageTruthFmt.tb(t.totalBytes))
                        .font(.system(size: 26, weight: .semibold).monospacedDigit())
                        .kerning(-0.2)
                        .foregroundStyle(StorageVariantPalette.text1)
                    Text(StorageTruthFmt.tbUnit(t.totalBytes))
                        .font(.system(size: 12).monospaced())
                        .foregroundStyle(StorageVariantPalette.text3)
                }
                Text("\(StorageTruthFmt.gb(t.usedFinderBytes)) GB used")
                    .font(.system(size: 10).monospaced())
                    .kerning(0.4)
                    .foregroundStyle(StorageVariantPalette.text3)
            }
        }
    }

    private func ringPair(radius: CGFloat, fill: Double, ringFill: Color, ringStroke: Color) -> some View {
        ZStack {
            Circle()
                .trim(from: 0, to: fill)
                .stroke(ringFill, style: StrokeStyle(lineWidth: 16, lineCap: .butt))
                .rotationEffect(.degrees(-90))
                .frame(width: radius * 2, height: radius * 2)
            Circle()
                .trim(from: 0, to: fill)
                .stroke(ringStroke, style: StrokeStyle(lineWidth: 2, lineCap: .butt))
                .rotationEffect(.degrees(-90))
                .frame(width: radius * 2, height: radius * 2)
                .opacity(0.95)
        }
    }

    private func arc(radius: CGFloat, lineWidth: CGFloat, fill: Double, color: Color, trackColor: Color) -> some View {
        Circle()
            .trim(from: 0, to: fill)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
            .rotationEffect(.degrees(-90))
            .frame(width: radius * 2, height: radius * 2)
    }

    private func rows(t: StorageTruthTriad) -> some View {
        let purgeable = t.finderBytes > t.appsBytes ? t.finderBytes - t.appsBytes : 0
        return VStack(spacing: 12) {
            row(color: StorageVariantPalette.sage, label: "Apps see", value: t.appsBytes,
                key: ".volumeAvailableCapacityKey",
                sentence: "True free, the inner ring. Writes succeed up to here without the OS having to free anything first.")
            row(color: StorageVariantPalette.slate, label: "Finder shows", value: t.finderBytes,
                key: ".volumeAvailableCapacityForImportantUsageKey",
                sentence: "User-facing, the middle ring. Adds \(StorageTruthFmt.gb(purgeable)) GB of purgeable caches reclaimed under pressure.")
            row(color: StorageVariantPalette.amber, label: "OS could free", value: t.opportunisticBytes,
                key: ".volumeAvailableCapacityForOpportunisticUsageKey",
                sentence: "Best case, the outer ring. Adds opportunistic data the OS thinks it can shed, like cached video and Photos originals.")
        }
    }

    private func row(color: Color, label: String, value: UInt64, key: String, sentence: String) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Circle()
                .fill(StorageVariantPalette.bg)
                .overlay(Circle().strokeBorder(color, lineWidth: 3))
                .frame(width: 14, height: 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .bold).monospaced())
                    .kerning(1.3)
                    .foregroundStyle(StorageVariantPalette.text3)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(StorageTruthFmt.gb(value))
                        .font(.system(size: 26, weight: .semibold).monospacedDigit())
                        .kerning(-0.2)
                        .foregroundStyle(StorageVariantPalette.text1)
                    Text("GB").font(.system(size: 12).monospaced()).foregroundStyle(StorageVariantPalette.text3)
                }
            }
            .frame(width: 110, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(key).font(.system(size: 9.5).monospaced()).foregroundStyle(StorageVariantPalette.text4)
                Text(sentence)
                    .font(.system(size: 11))
                    .foregroundStyle(StorageVariantPalette.text2)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(StorageVariantPalette.tileDeep, in: RoundedRectangle(cornerRadius: 6))
        .overlay(alignment: .leading) { Rectangle().fill(color).frame(width: 2) }
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(StorageVariantPalette.hair, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

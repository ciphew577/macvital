import SwiftUI

struct StorageTruthTableNumberLine: View {
    let triad: StorageTruthTriad?

    var body: some View {
        StorageVariantTruthHost(triad: triad) { t in
            VStack(alignment: .leading, spacing: 14) {
                axis(t: t)
                explainRow(t: t)
            }
            .padding(.horizontal, 6)
        }
    }

    private func endFraction(_ t: StorageTruthTriad, free: UInt64) -> Double {
        guard t.totalBytes > 0 else { return 0 }
        return min(0.998, (Double(t.usedFinderBytes) + Double(free)) / Double(t.totalBytes))
    }
    private func usedFraction(_ t: StorageTruthTriad) -> Double {
        guard t.totalBytes > 0 else { return 0 }
        return Double(t.usedFinderBytes) / Double(t.totalBytes)
    }

    private func axis(t: StorageTruthTriad) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let usedW = w * usedFraction(t)
            let trueX = w * endFraction(t, free: t.appsBytes)
            let finderX = w * endFraction(t, free: t.finderBytes)
            let osX = w * endFraction(t, free: t.opportunisticBytes)
            ZStack(alignment: .topLeading) {
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(StorageVariantPalette.usedFill)
                        .frame(width: usedW, height: 8)
                        .overlay(alignment: .trailing) {
                            Rectangle().fill(StorageVariantPalette.text4).frame(width: 1)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                }
                .offset(y: 156)

                Text("\(StorageTruthFmt.gb(t.usedFinderBytes)) GB used".uppercased())
                    .font(.system(size: 9).monospaced())
                    .kerning(1.0)
                    .foregroundStyle(StorageVariantPalette.text4)
                    .position(x: usedW / 2, y: 184)

                Rectangle().fill(StorageVariantPalette.tileH).frame(height: 4)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                    .offset(y: 168)

                Rectangle().fill(StorageVariantPalette.usedStroke)
                    .frame(width: usedW, height: 4)
                    .offset(y: 168)

                ForEach(0..<5, id: \.self) { i in
                    let x = w * Double(i) / 4.0
                    Rectangle().fill(StorageVariantPalette.text4).frame(width: 1, height: 10).offset(x: x, y: 174)
                    Text(tickLabel(i: i, total: t.totalBytes))
                        .font(.system(size: 9).monospaced())
                        .kerning(0.4)
                        .foregroundStyle(StorageVariantPalette.text4)
                        .position(x: max(20, min(w - 20, x)), y: 196)
                }
                ForEach(0..<4, id: \.self) { i in
                    let x = w * (Double(i) / 4.0 + 0.125)
                    Rectangle().fill(StorageVariantPalette.text5).frame(width: 1, height: 6).offset(x: x, y: 178)
                }

                lollipop(x: trueX, color: StorageVariantPalette.sage,
                         label: "Apps see", value: t.appsBytes, key: ".volumeAvailableCapacityKey",
                         stem: 80, cardY: 28, cardOffsetX: -32)
                lollipop(x: finderX, color: StorageVariantPalette.slate,
                         label: "Finder shows", value: t.finderBytes, key: ".volumeAvailableCapacityForImportantUsageKey",
                         stem: 130, cardY: 0, cardOffsetX: 0)
                lollipop(x: osX, color: StorageVariantPalette.amber,
                         label: "OS could free", value: t.opportunisticBytes, key: ".volumeAvailableCapacityForOpportunisticUsageKey",
                         stem: 100, cardY: 56, cardOffsetX: 32)
            }
        }
        .frame(height: 220)
    }

    private func tickLabel(i: Int, total: UInt64) -> String {
        let totalGB = Double(total) / 1_000_000_000
        if i == 0 { return "0" }
        if i == 4, totalGB >= 1000 { return "1 TB" }
        return "\(Int(totalGB * Double(i) / 4.0)) GB"
    }

    private func lollipop(x: CGFloat, color: Color,
                          label: String, value: UInt64, key: String,
                          stem: CGFloat, cardY: CGFloat, cardOffsetX: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(color).frame(width: 1.5, height: stem)
                .position(x: x, y: 168 - stem / 2)
            Circle()
                .fill(StorageVariantPalette.bg)
                .overlay(Circle().strokeBorder(color, lineWidth: 2))
                .frame(width: 12, height: 12)
                .position(x: x, y: 168 - stem - 6)

            VStack(spacing: 2) {
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .bold).monospaced())
                    .kerning(1.3)
                    .foregroundStyle(color)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(StorageTruthFmt.gb(value))
                        .font(.system(size: 24, weight: .semibold).monospacedDigit())
                        .kerning(-0.2)
                        .foregroundStyle(StorageVariantPalette.text1)
                    Text("GB").font(.system(size: 11).monospaced()).foregroundStyle(StorageVariantPalette.text3)
                }
                Text(key)
                    .font(.system(size: 8.5).monospaced())
                    .foregroundStyle(StorageVariantPalette.text4)
            }
            .fixedSize()
            .position(x: x + cardOffsetX, y: max(36, 168 - stem - 36 + cardY))
        }
    }

    private func explainRow(t: StorageTruthTriad) -> some View {
        let purgeable = t.finderBytes > t.appsBytes ? t.finderBytes - t.appsBytes : 0
        return HStack(alignment: .top, spacing: 14) {
            cell(color: StorageVariantPalette.sage, head: "Apps see", tag: ("True free", .truee),
                 sentence: "Floor of the disk. Apps writing without OS help can use this much. Excludes purgeable caches and snapshots.")
            cell(color: StorageVariantPalette.slate, head: "Finder shows", tag: ("User-facing", .finder),
                 sentence: "What Finder, About This Mac, and Disk Utility display. Adds \(StorageTruthFmt.gb(purgeable)) GB of purgeable caches reclaimed under pressure.")
            cell(color: StorageVariantPalette.amber, head: "OS could free", tag: ("Best case", .os),
                 sentence: "Optimistic ceiling. Adds opportunistic data, like cached video and Photos originals, on top. Not a guarantee.")
        }
    }

    private func cell(color: Color, head: String, tag: (String, StorageVariantLabelTag.Kind), sentence: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Text(head.uppercased())
                    .font(.system(size: 10, weight: .bold).monospaced())
                    .kerning(1.3)
                    .foregroundStyle(StorageVariantPalette.text3)
                StorageVariantLabelTag(kind: tag.1, text: tag.0)
            }
            Text(sentence)
                .font(.system(size: 11))
                .foregroundStyle(StorageVariantPalette.text2)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(StorageVariantPalette.tileDeep, in: RoundedRectangle(cornerRadius: 6))
        .overlay(alignment: .leading) { Rectangle().fill(color).frame(width: 2) }
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

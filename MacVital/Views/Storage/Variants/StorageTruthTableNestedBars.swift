import SwiftUI

struct StorageTruthTableNestedBars: View {
    let triad: StorageTruthTriad?

    var body: some View {
        StorageVariantTruthHost(triad: triad) { t in
            VStack(alignment: .leading, spacing: 14) {
                annotations(t: t)
                bar(t: t)
                bottomAxis(t: t)
                explainRow(t: t)
            }
        }
    }

    private func usedFraction(_ t: StorageTruthTriad) -> Double {
        guard t.totalBytes > 0 else { return 0 }
        return Double(t.usedFinderBytes) / Double(t.totalBytes)
    }
    private func endFraction(_ t: StorageTruthTriad, free: UInt64) -> Double {
        guard t.totalBytes > 0 else { return 0 }
        return min(1.0, (Double(t.usedFinderBytes) + Double(free)) / Double(t.totalBytes))
    }

    private func annotations(t: StorageTruthTriad) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let trueX = w * endFraction(t, free: t.appsBytes)
            let finderX = w * endFraction(t, free: t.finderBytes)
            let osX = w * endFraction(t, free: t.opportunisticBytes)
            ZStack(alignment: .topLeading) {
                annoCell(label: "Apps see", value: t.appsBytes, color: StorageVariantPalette.sage, tickHeight: 18)
                    .position(x: max(40, min(w - 40, trueX)), y: 26)
                annoCell(label: "Finder shows", value: t.finderBytes, color: StorageVariantPalette.slate, tickHeight: 6)
                    .position(x: max(40, min(w - 40, finderX)), y: 50)
                annoCell(label: "OS could free", value: t.opportunisticBytes, color: StorageVariantPalette.amber, tickHeight: 18)
                    .position(x: max(40, min(w - 40, osX)), y: 26)
            }
        }
        .frame(height: 64)
    }

    private func annoCell(label: String, value: UInt64, color: Color, tickHeight: CGFloat) -> some View {
        VStack(spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold).monospaced())
                .kerning(1.3)
                .foregroundStyle(color)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(StorageTruthFmt.gb(value))
                    .font(.system(size: 22, weight: .semibold).monospacedDigit())
                    .kerning(-0.2)
                    .foregroundStyle(StorageVariantPalette.text1)
                Text("GB").font(.system(size: 11).monospaced()).foregroundStyle(StorageVariantPalette.text3)
            }
            Rectangle().fill(color).frame(width: 1, height: tickHeight)
        }
    }

    private func bar(t: StorageTruthTriad) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let usedW = w * usedFraction(t)
            let osW = w * endFraction(t, free: t.opportunisticBytes)
            let finderW = w * endFraction(t, free: t.finderBytes)
            let trueW = w * endFraction(t, free: t.appsBytes)
            ZStack(alignment: .leading) {
                Rectangle().fill(StorageVariantPalette.usedFill).frame(width: usedW)
                Rectangle()
                    .fill(StorageVariantPalette.amberFill.opacity(0.5))
                    .overlay(alignment: .trailing) { Rectangle().fill(StorageVariantPalette.amber).frame(width: 1.5) }
                    .frame(width: osW)
                Rectangle()
                    .fill(StorageVariantPalette.slateFill)
                    .overlay(alignment: .trailing) { Rectangle().fill(StorageVariantPalette.slate).frame(width: 1.5) }
                    .frame(width: finderW)
                Rectangle()
                    .fill(StorageVariantPalette.sageFill)
                    .overlay(alignment: .trailing) { Rectangle().fill(StorageVariantPalette.sage).frame(width: 1.5) }
                    .frame(width: trueW)

                ForEach([0.25, 0.5, 0.75], id: \.self) { p in
                    Rectangle().fill(Color.white.opacity(0.18)).frame(width: 1).offset(x: w * p)
                }
                ForEach([0.125, 0.375, 0.625, 0.875], id: \.self) { p in
                    Rectangle().fill(Color.white.opacity(0.10)).frame(width: 1).offset(x: w * p)
                }
            }
            .frame(height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(StorageVariantPalette.hairS, lineWidth: 0.5))
        }
        .frame(height: 56)
    }

    private func bottomAxis(t: StorageTruthTriad) -> some View {
        let totalGB = Double(t.totalBytes) / 1_000_000_000
        return HStack {
            ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { f in
                Text(axisLabel(f: f, totalGB: totalGB))
                    .font(.system(size: 9).monospaced())
                    .kerning(0.5)
                    .foregroundStyle(StorageVariantPalette.text4)
                if f < 1.0 { Spacer() }
            }
        }
    }

    private func axisLabel(f: Double, totalGB: Double) -> String {
        let v = totalGB * f
        if f == 1.0, totalGB >= 1000 { return "1 TB" }
        if f == 0.0 { return "0" }
        return "\(Int(v)) GB"
    }

    private func explainRow(t: StorageTruthTriad) -> some View {
        let purgeable = t.finderBytes > t.appsBytes ? t.finderBytes - t.appsBytes : 0
        return HStack(alignment: .top, spacing: 14) {
            cell(color: StorageVariantPalette.sage, head: "Apps see · \(StorageTruthFmt.gb(t.appsBytes)) GB",
                 tag: ("True free", .truee),
                 sentence: "What an app gets when it asks for free space. Writes succeed up to here without the OS reclaiming anything.")
            cell(color: StorageVariantPalette.slate, head: "Finder shows · \(StorageTruthFmt.gb(t.finderBytes)) GB",
                 tag: ("User-facing", .finder),
                 sentence: "What Finder and About This Mac display. Adds \(StorageTruthFmt.gb(purgeable)) GB of purgeable caches the OS frees under pressure.")
            cell(color: StorageVariantPalette.amber, head: "OS could free · \(StorageTruthFmt.gb(t.opportunisticBytes)) GB",
                 tag: ("Best case", .os),
                 sentence: "Optimistic ceiling. Adds opportunistic data, like cached video and Photos originals, on top. Not guaranteed.")
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
        .padding(.leading, 12)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .leading) {
            Rectangle().fill(color).frame(width: 1.5)
        }
    }
}

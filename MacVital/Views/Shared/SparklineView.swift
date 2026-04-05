// MacVital/Views/Shared/SparklineView.swift
import SwiftUI
import Charts

struct SparklineView: View {
    let data: [Double]
    var color: Color = .blue
    var height: CGFloat = 40

    var body: some View {
        Chart {
            ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                LineMark(
                    x: .value("Time", index),
                    y: .value("Value", value)
                )
                .foregroundStyle(color.gradient)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Time", index),
                    y: .value("Value", value)
                )
                .foregroundStyle(color.opacity(0.1).gradient)
                .interpolationMethod(.catmullRom)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...max(data.max() ?? 100, 1))
        .frame(height: height)
        .animation(.smooth, value: data.count)
    }
}

struct SparklineUInt64View: View {
    let data: [UInt64]
    var color: Color = .blue
    var height: CGFloat = 40

    var body: some View {
        SparklineView(data: data.map { Double($0) }, color: color, height: height)
    }
}

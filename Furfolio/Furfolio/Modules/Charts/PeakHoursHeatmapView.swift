//
//  PeakHoursHeatmapView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//
import SwiftUI

struct PeakHoursHeatmapView: View {
    // [DayOfWeek: [HourOfDay: Count]]
    let peakHoursData: [Int: [Int: Int]]

    private let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private let hoursOfDay = Array(0..<24)

    private var maxCount: Int {
        peakHoursData.values.flatMap { $0.values }.max() ?? 1
    }

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 4) {
                // Header row
                HStack {
                    Text("").frame(width: 40)
                    ForEach(hoursOfDay, id: \.self) { hour in
                        Text("\(hour)")
                            .font(.caption2)
                            .frame(width: 24, height: 24)
                            .foregroundColor(.secondary)
                    }
                }

                // Rows for each day
                ForEach(0..<7, id: \.self) { dayIndex in
                    HStack(spacing: 4) {
                        Text(daysOfWeek[dayIndex])
                            .font(.caption2)
                            .frame(width: 40, height: 24)
                            .foregroundColor(.primary)

                        ForEach(hoursOfDay, id: \.self) { hour in
                            let count = peakHoursData[dayIndex]?[hour] ?? 0
                            DayHourCellView(day: daysOfWeek[dayIndex], hour: hour, count: count, maxCount: maxCount)
                        }
                    }
                }
            }
            .padding()
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(radius: 4)
        )
        .padding()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Heatmap showing peak appointment hours across days of the week")
    }
}

private struct DayHourCellView: View {
    let day: String
    let hour: Int
    let count: Int
    let maxCount: Int

    private var cellColor: Color {
        guard count > 0 else { return Color.gray.opacity(0.1) }
        let normalized = Double(count) / Double(maxCount)
        return Color.red.opacity(0.2 + 0.8 * normalized)
    }

    private var textColor: Color {
        cellColor.luminance > 0.6 ? .black : .white
    }

    var body: some View {
        Rectangle()
            .fill(cellColor)
            .frame(width: 24, height: 24)
            .cornerRadius(4)
            .overlay(
                count > 0
                    ? Text("\(count)")
                        .font(.caption2)
                        .foregroundColor(textColor)
                    : nil
            )
            .help("\(day), \(hour):00 — \(count) appointments")
            .accessibilityLabel("\(day), hour \(hour), \(count) appointments")
    }
}

private extension Color {
    var luminance: Double {
        #if canImport(UIKit)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return 0.299 * Double(red) + 0.587 * Double(green) + 0.114 * Double(blue)
        #else
        return 1.0
        #endif
    }
}

#if DEBUG
struct PeakHoursHeatmapView_Previews: PreviewProvider {
    static var previews: some View {
        var sampleData: [Int: [Int: Int]] = [:]
        for day in 0..<7 {
            var dayData: [Int: Int] = [:]
            for hour in 8..<20 {
                dayData[hour] = Int.random(in: 0...5)
            }
            sampleData[day] = dayData
        }

        return PeakHoursHeatmapView(peakHoursData: sampleData)
            .previewLayout(.sizeThatFits)
    }
}
#endif

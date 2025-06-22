//
//  BehaviorTrendChart.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//


//
//  BehaviorTrendChart.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI
import Charts

struct BehaviorTrendPoint: Identifiable {
    var id = UUID()
    var behavior: String
    var date: Date
    var rating: Int
}

struct BehaviorTrendChart: View {
    let data: [BehaviorTrendPoint]

    private var behaviors: [String] {
        Array(Set(data.map { $0.behavior })).sorted()
    }

    private let colors: [Color] = [
        .green, .orange, .red, .blue, .purple, .pink
    ]

    var body: some View {
        VStack(alignment: .leading) {
            Text("Pet Behavior Trends")
                .font(.headline)
                .padding(.bottom, 8)

            Chart {
                ForEach(behaviors.indices, id: \.self) { index in
                    let behavior = behaviors[index]
                    let filteredData = data.filter { $0.behavior == behavior }

                    ForEach(filteredData) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Rating", point.rating)
                        )
                        .foregroundStyle(colors[index % colors.count])
                        .interpolationMethod(.catmullRom)
                        .symbol(Circle())
                        .symbolSize(30)
                        .annotation(position: .top) {
                            Text("\(point.rating)")
                                .font(.caption2)
                                .foregroundColor(colors[index % colors.count])
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .frame(height: 240)

            // Legend
            HStack(spacing: 12) {
                ForEach(behaviors.indices, id: \.self) { index in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(colors[index % colors.count])
                            .frame(width: 14, height: 14)
                        Text(behaviors[index])
                            .font(.footnote)
                    }
                }
            }
            .padding(.top, 8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(radius: 6)
        )
    }
}

#if DEBUG
struct BehaviorTrendChart_Previews: PreviewProvider {
    static var previews: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let behaviors = ["Calm", "Anxious", "Aggressive"]

        var sampleData: [BehaviorTrendPoint] = []

        for behavior in behaviors {
            for monthOffset in 0..<6 {
                if let date = calendar.date(byAdding: .month, value: -monthOffset, to: today) {
                    let rating = Int.random(in: 1...5)
                    sampleData.append(BehaviorTrendPoint(behavior: behavior, date: date, rating: rating))
                }
            }
        }

        BehaviorTrendChart(data: sampleData)
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
#endif

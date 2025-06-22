//
//  RevenueTrendChart.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI
import Charts

struct RevenuePoint: Identifiable {
    var id = UUID()
    var date: Date
    var revenue: Double
}

struct RevenueTrendChart: View {
    let data: [RevenuePoint]

    var body: some View {
        VStack(alignment: .leading) {
            Text("Revenue Trend")
                .font(.headline)
                .padding(.bottom, 8)

            Chart(data) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Revenue", point.revenue)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color.accentColor)
                .symbol(Circle())
                .symbolSize(40)
                .annotation(position: .top) {
                    Text("$\(Int(point.revenue))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
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
                    AxisValueLabel(format: .currency(code: "USD"))
                }
            }
            .frame(height: 220)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)).shadow(radius: 6))
    }
}

#if DEBUG
struct RevenueTrendChart_Previews: PreviewProvider {
    static var previews: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let sampleData: [RevenuePoint] = (0..<12).map { offset in
            let date = calendar.date(byAdding: .month, value: -offset, to: today)!
            return RevenuePoint(date: date, revenue: Double.random(in: 5000...15000))
        }.reversed()

        RevenueTrendChart(data: sampleData)
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
#endif

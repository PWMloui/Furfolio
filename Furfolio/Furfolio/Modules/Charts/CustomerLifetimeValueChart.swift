//
//  CustomerLifetimeValueChart.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI
import Charts

struct CustomerLifetimeValuePoint: Identifiable {
    var id = UUID()
    var date: Date
    var lifetimeValue: Double
}

struct CustomerLifetimeValueChart: View {
    let data: [CustomerLifetimeValuePoint]

    private var currencyFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 0
        return formatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Customer Lifetime Value Over Time")
                .font(.headline)

            Chart(data) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Lifetime Value", point.lifetimeValue)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color.accentColor)
                .symbol(Circle())
                .symbolSize(40)
                .annotation(position: .top) {
                    Text(currencyFormatter.string(from: NSNumber(value: point.lifetimeValue)) ?? "$0")
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
                AxisMarks(position: .leading) {
                    AxisGridLine()
                    AxisValueLabel(format: .currency(code: "USD"))
                }
            }
            .frame(height: 220)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(radius: 6)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Customer lifetime value line chart showing historical values over time")
    }
}

#if DEBUG
struct CustomerLifetimeValueChart_Previews: PreviewProvider {
    static var previews: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let sampleData = (0..<12).map { offset in
            CustomerLifetimeValuePoint(
                date: calendar.date(byAdding: .month, value: -offset, to: today)!,
                lifetimeValue: Double.random(in: 200...1000)
            )
        }.reversed()

        return CustomerLifetimeValueChart(data: sampleData)
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
#endif

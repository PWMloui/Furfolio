//
//  ServiceTrendsChart.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI
import Charts

struct ServiceTrendPoint: Identifiable {
    var id = UUID()
    var service: String
    var date: Date
    var count: Int
}

struct ServiceTrendsChart: View {
    let data: [ServiceTrendPoint]

    // Extract distinct services for color mapping
    private var services: [String] {
        Array(Set(data.map { $0.service })).sorted()
    }

    // Color palette for services
    private let colors: [Color] = [
        .blue, .green, .orange, .purple, .pink, .red, .yellow, .teal
    ]

    var body: some View {
        VStack(alignment: .leading) {
            Text("Service Popularity Trends")
                .font(.headline)
                .padding(.bottom, 8)

            Chart {
                ForEach(services.indices, id: \.self) { index in
                    let service = services[index]
                    let serviceData = data.filter { $0.service == service }

                    LineMark(
                        x: .value("Date", serviceData.map { $0.date }),
                        y: .value("Count", serviceData.map { $0.count })
                    )

                    ForEach(serviceData) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Count", point.count)
                        )
                        .foregroundStyle(colors[index % colors.count])
                        .interpolationMethod(.catmullRom)
                        .symbol(Circle())
                        .symbolSize(30)
                        .annotation(position: .top) {
                            Text("\(point.count)")
                                .font(.caption2)
                                .foregroundColor(colors[index % colors.count])
                        }
                    }
                }
            }
            .chartForegroundStyleScale(
                Dictionary(uniqueKeysWithValues: services.enumerated().map { index, service in
                    (service, colors[index % colors.count])
                })
            )
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
                ForEach(services.indices, id: \.self) { index in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(colors[index % colors.count])
                            .frame(width: 14, height: 14)
                        Text(services[index])
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
struct ServiceTrendsChart_Previews: PreviewProvider {
    static var previews: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let services = ["Full Groom", "Bath Only", "Nail Trim"]

        var sampleData: [ServiceTrendPoint] = []

        for service in services {
            for monthOffset in 0..<6 {
                if let date = calendar.date(byAdding: .month, value: -monthOffset, to: today) {
                    let count = Int.random(in: 5...25)
                    sampleData.append(ServiceTrendPoint(service: service, date: date, count: count))
                }
            }
        }

        ServiceTrendsChart(data: sampleData)
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
#endif

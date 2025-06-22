
//
//  ServiceMixChart.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI
import Charts

struct ServiceMixData: Identifiable {
    var id = UUID()
    var service: String
    var count: Int
}

struct ServiceMixChart: View {
    let data: [ServiceMixData]

    // Predefined colors for segments
    private let colors: [Color] = [
        .blue, .green, .orange, .purple, .pink, .red, .yellow
    ]

    // Total count for calculating percentages
    private var totalCount: Int {
        data.reduce(0) { $0 + $1.count }
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Service Mix")
                .font(.headline)
                .padding(.bottom, 8)

            Chart(data) { item in
                SectorMark(
                    angle: .value("Count", item.count),
                    innerRadius: .ratio(0.5),
                    angularInset: 1.5
                )
                .foregroundStyle(by: .value("Service", item.service))
                .annotation(position: .overlay, alignment: .center) {
                    if totalCount > 0 {
                        let percent = Double(item.count) / Double(totalCount) * 100
                        Text("\(item.service)\n\(String(format: "%.1f", percent))%")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                    }
                }
            }
            .chartForegroundStyleScale(
                Dictionary(uniqueKeysWithValues: data.enumerated().map { (index, item) in
                    (item.service, colors[index % colors.count])
                })
            )
            .frame(height: 260)

            // Legend
            VStack(alignment: .leading, spacing: 8) {
                ForEach(data.indices, id: \.self) { idx in
                    HStack {
                        Rectangle()
                            .fill(colors[idx % colors.count])
                            .frame(width: 18, height: 18)
                            .cornerRadius(4)
                        Text(data[idx].service)
                            .font(.subheadline)
                    }
                }
            }
            .padding(.top, 12)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground)).shadow(radius: 5))
    }
}

#if DEBUG
struct ServiceMixChart_Previews: PreviewProvider {
    static var previews: some View {
        let sampleData = [
            ServiceMixData(service: "Full Groom", count: 45),
            ServiceMixData(service: "Bath Only", count: 25),
            ServiceMixData(service: "Nail Trim", count: 15),
            ServiceMixData(service: "Other", count: 10)
        ]

        ServiceMixChart(data: sampleData)
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
#endif

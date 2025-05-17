//
//  ServiceTrendsView.swift
//  Furfolio
//
//  Created to visualize service popularity trends over time.

import SwiftUI
import Charts
// TODO: Move service trend computation into a dedicated ViewModel for cleaner views and easier testing.

@MainActor
/// A view displaying service popularity trends with a bar chart and summary annotations.
struct ServiceTrendsView: View {
    let appointments: [Appointment]

    /// Computes booking counts grouped by service type.
    var serviceFrequency: [Appointment.ServiceType: Int] {
        Appointment.serviceTypeFrequency(for: appointments)
    }
    
    /// Computes the average number of appointments across service types.
    var averageAppointments: Double {
        let total = serviceFrequency.values.reduce(0, +)
        return serviceFrequency.isEmpty ? 0 : Double(total) / Double(serviceFrequency.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Service Trend Overview")
                .font(.title2.bold())
                .padding(.bottom, 4)

            if serviceFrequency.isEmpty {
                Text("No appointment data available.")
                    .foregroundColor(.gray)
            } else {
                /// Renders a bar chart of appointment counts per service type with an average line.
                Chart {
                    ForEach(Appointment.ServiceType.allCases, id: \.self) { type in
                        if let count = serviceFrequency[type] {
                            BarMark(
                                x: .value("Service Type", type.localized),
                                y: .value("Appointments", count)
                            )
                            .foregroundStyle(by: .value("Service", type.localized))
                        }
                    }
                    RuleMark(y: .value("Average", averageAppointments))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                        .foregroundStyle(Color.red)
                        .annotation(position: .top, alignment: .leading) {
                            Text("Avg: \(Int(averageAppointments))")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 250)
                
                Text("🔴 Dashed line shows average appointments per service.")
                    .font(.caption2)
                    .foregroundColor(.gray)
                
                if let mostPopular = serviceFrequency.max(by: { $0.value < $1.value }),
                   let leastPopular = serviceFrequency.min(by: { $0.value < $1.value }) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("📈 Most Booked: \(mostPopular.key.localized) (\(mostPopular.value))")
                            .font(.subheadline)
                            .foregroundColor(.green)

                        Text("📉 Least Booked: \(leastPopular.key.localized) (\(leastPopular.value))")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .padding()
        .cardStyle()
        .padding()
        .navigationTitle("Service Trends")
        .navigationBarTitleDisplayMode(.inline)
    }
}

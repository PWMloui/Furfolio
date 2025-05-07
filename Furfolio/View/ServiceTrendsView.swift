//
//  ServiceTrendsView.swift
//  Furfolio
//
//  Created to visualize service popularity trends over time.

import SwiftUI
import Charts

struct ServiceTrendsView: View {
    let appointments: [Appointment]

    var serviceFrequency: [Appointment.ServiceType: Int] {
        Appointment.serviceTypeFrequency(for: appointments)
    }
    
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
                Chart {
                    ForEach(Appointment.ServiceType.allCases, id: \..self) { type in
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
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
        .padding()
        .navigationTitle("Service Trends")
    }
}

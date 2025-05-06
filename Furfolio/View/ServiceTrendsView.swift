

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
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 250)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
        .padding()
        .navigationTitle("Service Trends")
    }
}


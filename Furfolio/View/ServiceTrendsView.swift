//
//  ServiceTrendsView.swift
//  Furfolio
//
//  Created to visualize service popularity trends over time.

import SwiftUI
import Charts

@MainActor
/// A view displaying service popularity trends with a bar chart and summary annotations.
struct ServiceTrendsView: View {
    private let appointments: [Appointment]
    @StateObject private var viewModel: ServiceTrendsViewModel

    init(appointments: [Appointment]) {
        self.appointments = appointments
        _viewModel = StateObject(wrappedValue: ServiceTrendsViewModel(appointments: appointments))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Service Trend Overview")
                .font(.title2.bold())
                .padding(.bottom, 4)

            if viewModel.serviceFrequency.isEmpty {
                Text("No appointment data available.")
                    .foregroundColor(.gray)
            } else {
                /// Renders a bar chart of appointment counts per service type with an average line.
                Chart {
                    ForEach(Appointment.ServiceType.allCases, id: \.self) { type in
                        if let count = viewModel.serviceFrequency[type] {
                            BarMark(
                                x: .value("Service Type", type.localized),
                                y: .value("Appointments", count)
                            )
                            .foregroundStyle(by: .value("Service", type.localized))
                        }
                    }
                    RuleMark(y: .value("Average", viewModel.averageAppointments))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                        .foregroundStyle(Color.red)
                        .annotation(position: .top, alignment: .leading) {
                            Text("Avg: \(Int(viewModel.averageAppointments))")
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
                
                if let mostPopular = viewModel.serviceFrequency.max(by: { $0.value < $1.value }),
                   let leastPopular = viewModel.serviceFrequency.min(by: { $0.value < $1.value }) {
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

import Foundation

@MainActor
final class ServiceTrendsViewModel: ObservableObject {
    @Published private(set) var serviceFrequency: [Appointment.ServiceType: Int] = [:]
    @Published private(set) var averageAppointments: Double = 0

    init(appointments: [Appointment]) {
        computeMetrics(from: appointments)
    }

    func computeMetrics(from appointments: [Appointment]) {
        let freq = Appointment.serviceTypeFrequency(for: appointments)
        serviceFrequency = freq
        let total = freq.values.reduce(0, +)
        averageAppointments = freq.isEmpty ? 0 : Double(total) / Double(freq.count)
    }
}

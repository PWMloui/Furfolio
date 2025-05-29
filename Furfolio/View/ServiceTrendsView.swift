//
//  ServiceTrendsView.swift
//  Furfolio
//
//  Created to visualize service popularity trends over time.

import SwiftUI
import Charts
import os

@MainActor
/// A view displaying service popularity trends with a bar chart and summary annotations.
struct ServiceTrendsView: View {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "ServiceTrendsView")
    private let appointments: [Appointment]
    @StateObject private var viewModel: ServiceTrendsViewModel

    init(appointments: [Appointment]) {
        self.appointments = appointments
        _viewModel = StateObject(wrappedValue: ServiceTrendsViewModel(appointments: appointments))
        logger.log("Initialized ServiceTrendsView with \(appointments.count) appointments")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Service Trend Overview")
                .font(AppTheme.title)
                .foregroundColor(AppTheme.primaryText)
                .padding(.bottom, 4)

            if viewModel.serviceFrequency.isEmpty {
                Text("No appointment data available.")
                    .font(AppTheme.body)
                    .foregroundColor(AppTheme.secondaryText)
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
                        .foregroundStyle(AppTheme.warning)
                        .annotation(position: .top, alignment: .leading) {
                            Text("Avg: \(Int(viewModel.averageAppointments))")
                                .font(.caption)
                                .foregroundColor(AppTheme.warning)
                        }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 250)
                
                Text("Dashed line shows average appointments per service.")
                    .font(AppTheme.caption)
                    .foregroundColor(AppTheme.secondaryText)
                
                if let mostPopular = viewModel.serviceFrequency.max(by: { $0.value < $1.value }),
                   let leastPopular = viewModel.serviceFrequency.min(by: { $0.value < $1.value }) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("📈 Most Booked: \(mostPopular.key.localized) (\(mostPopular.value))")
                            .font(AppTheme.body)
                            .foregroundColor(AppTheme.accent)

                        Text("📉 Least Booked: \(leastPopular.key.localized) (\(leastPopular.value))")
                            .font(AppTheme.body)
                            .foregroundColor(AppTheme.warning)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .onAppear {
            logger.log("ServiceTrendsView appeared; serviceFrequency count: \(viewModel.serviceFrequency.count)")
        }
        .padding()
        .cardStyle()
        .padding()
        .navigationTitle("Service Trends")
        .navigationBarTitleDisplayMode(.inline)
    }
}

import Foundation
import os

@MainActor
final class ServiceTrendsViewModel: ObservableObject {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "ServiceTrendsViewModel")
    @Published private(set) var serviceFrequency: [Appointment.ServiceType: Int] = [:]
    @Published private(set) var averageAppointments: Double = 0

    init(appointments: [Appointment]) {
        computeMetrics(from: appointments)
        logger.log("ServiceTrendsViewModel computed metrics for \(appointments.count) appointments: frequencies=\(serviceFrequency)")
    }

    func computeMetrics(from appointments: [Appointment]) {
        logger.log("computeMetrics called with \(appointments.count) appointments")
        let freq = Appointment.serviceTypeFrequency(for: appointments)
        serviceFrequency = freq
        let total = freq.values.reduce(0, +)
        averageAppointments = freq.isEmpty ? 0 : Double(total) / Double(freq.count)
    }
}

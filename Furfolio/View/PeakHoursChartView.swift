//
//  PeakHoursChartView.swift
//  Furfolio
//
//  Created by ChatGPT on 06/01/2025.
//

import SwiftUI
import Charts
import os

/// ViewModel for PeakHoursChartView, handles data preparation.
@MainActor
final class PeakHoursChartViewModel: ObservableObject {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "PeakHoursChartViewModel")
  @Published var hourData: [DailyRevenue.HourEntry] = []

  private let calendar = Calendar.current
  private let appointments: [Appointment]
 
  init(appointments: [Appointment]) {
    self.appointments = appointments
    logger.log("Initialized PeakHoursChartViewModel with \(appointments.count) appointments")
    loadData()
  }

  /// Computes hourly appointment frequency for today.
  func loadData() {
    logger.log("Loading hourly appointment frequency for today")
    let startOfToday = calendar.startOfDay(for: Date.now)
    hourData = DailyRevenue.hourlyAppointmentFrequency(
      for: startOfToday,
      in: appointments
    )
    logger.log("Loaded hourData entries: \(hourData.count)")
  }
}

// TODO: Move data preparation and formatting into a PeakHoursChartViewModel; cache shared Calendar and date formatter for performance.

@MainActor
/// A chart view showing the frequency of appointments per hour for a given day.
struct PeakHoursChartView: View {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "PeakHoursChartView")
  @StateObject private var viewModel: PeakHoursChartViewModel

  init(appointments: [Appointment]) {
    _viewModel = StateObject(wrappedValue: PeakHoursChartViewModel(appointments: appointments))
  }

  var body: some View {
    VStack(alignment: .leading) {
      Text("Peak Booking Hours")
        .font(AppTheme.title)
        .foregroundColor(AppTheme.primaryText)

      /// Show placeholder when no data is available.
      if viewModel.hourData.isEmpty {
        Text("No appointment time data available.")
          .foregroundColor(AppTheme.secondaryText)
          .font(AppTheme.body)
      } else {
        /// Renders a bar chart of appointment counts by hour.
        Chart {
          ForEach(viewModel.hourData, id: \.hour) { entry in
            BarMark(
              x: .value("Hour", "\(entry.hour):00"),
              y: .value("Appointments", entry.count)
            )
          }
        }
        .frame(height: 200)
        .chartXAxis { AxisMarks(position: .bottom) }
        .chartYAxis { AxisMarks(position: .leading) }
      }
    }
    .padding()
    .cardStyle()
    .onAppear {
        logger.log("PeakHoursChartView appeared with \(viewModel.hourData.count) data points")
    }
  }
}

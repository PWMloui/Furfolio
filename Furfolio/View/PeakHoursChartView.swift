//
//  PeakHoursChartView.swift
//  Furfolio
//
//  Created by ChatGPT on 06/01/2025.
//

import SwiftUI
import Charts

// TODO: Move data preparation and formatting into a PeakHoursChartViewModel; cache shared Calendar and date formatter for performance.

@MainActor
/// A chart view showing the frequency of appointments per hour for a given day.
struct PeakHoursChartView: View {
  /// Shared Calendar and reference 'now' to avoid repeated allocations.
  private static let calendar = Calendar.current
  private static var now: Date { Date.now }

  let appointments: [Appointment]

  var body: some View {
    VStack(alignment: .leading) {
      Text("Peak Booking Hours")
        .font(.headline)

      // Compute today’s start of day
      let startOfToday = Self.calendar.startOfDay(for: Self.now)

      /// Hourly appointment counts for the specified day.
      let hourData = DailyRevenue.hourlyAppointmentFrequency(
        for: startOfToday,
        in: appointments
      )

      /// Show placeholder when no data is available.
      if hourData.isEmpty {
        Text("No appointment time data available.")
          .foregroundColor(.gray)
      } else {
        /// Renders a bar chart of appointment counts by hour.
        Chart {
          ForEach(hourData, id: \.hour) { entry in
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
  }
}

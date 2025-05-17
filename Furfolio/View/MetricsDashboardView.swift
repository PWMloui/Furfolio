//
//  MetricsDashboardView.swift
//  Furfolio
//
//  Created by mac on 12/20/24.
//  Updated on 2025-06-01 — removed invalid initializers, fixed helper calls, and disambiguated concurrency Task.
//

import SwiftUI
// TODO: Move dashboard logic into a dedicated ViewModel and cache formatters to improve performance
import Charts

@MainActor
/// View presenting a metrics dashboard with charts, summaries, and interactive filters for the Furfolio app.
struct MetricsDashboardView: View {
  @State private var selectedDateRange: DateRange = .lastMonth
  @State private var isCustomDateRangeActive = false
  @State private var customStartDate: Date = Date()
  @State private var customEndDate: Date = Date()
  
  let dailyRevenues: [DailyRevenue]
  let appointments: [Appointment]
  let charges: [Charge]
  
  @State private var isRefreshing = false
  /// Shared calendar for date calculations.
  private static let calendar = Calendar.current
  /// Shared date formatter for consistent date display.
  private static let dateFormatter: DateFormatter = {
    let fmt = DateFormatter()
    fmt.dateStyle = .medium
    fmt.timeStyle = .none
    return fmt
  }()
  /// Shared currency formatter for revenue values.
  private static let currencyFormatter: NumberFormatter = {
    let fmt = NumberFormatter()
    fmt.numberStyle = .currency
    fmt.locale = .current
    return fmt
  }()
  
  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 16) {
          
          // Header
          Text("Metrics Dashboard")
            .font(.largeTitle).bold()
            .accessibilityAddTraits(.isHeader)
            .transition(.opacity)
          
          // Revenue Trends
          RevenueChartView(dailyRevenues: filteredRevenues(for: selectedDateRange))
            .transition(.move(edge: .leading))
          
          // Total Revenue
          TotalRevenueView(revenue: totalRevenue(for: selectedDateRange))
            .transition(.move(edge: .trailing))
          
          // Revenue Snapshot
          RevenueSnapshotWidgetView(
            todayRevenue: todayRevenue(),
            averageRevenue: averageLast7DaysRevenue()
          )
          
          // Quarterly Revenue
          QuarterRevenueView(dailyRevenues: dailyRevenues)
            .transition(.opacity)
          
          // Upcoming Appointments
          UpcomingAppointmentsView()
            .transition(.slide)
          
          // Charge Summary
          ChargeSummaryView(charges: chargesSummary())
            .transition(.opacity)
          
          // Popular Services
          PopularServicesView()
            .transition(.opacity)
          
          // Peak Hours Analytics
          PeakHoursChartView(appointments: appointments)
            .transition(.opacity)
          
          // Client Engagement
          ClientEngagementSummaryView(
            appointments: appointments,
            charges: charges
          )
          .transition(.move(edge: .bottom))
          
          // Date Range Picker
          DateRangePicker(
            selectedDateRange: $selectedDateRange,
            isCustomDateRangeActive: $isCustomDateRangeActive,
            customStartDate: $customStartDate,
            customEndDate: $customEndDate
          )
          .transition(.move(edge: .bottom))
        }
        .padding()
        .animation(.easeInOut, value: selectedDateRange)
      }
      .refreshable {
        await simulateDataRefresh()
      }
      .navigationTitle("Dashboard")
      .navigationBarTitleDisplayMode(.inline)
    }
  }
  
  // MARK: - Date Filtering
  
  /// Calculates the start date for the selected range.
  private func calculateStartDate(for range: DateRange) -> Date? {
    let cal = Self.calendar
    switch range {
    case .lastWeek:
      return cal.date(byAdding: .day,   value: -7, to: Date.now)
    case .lastMonth:
      return cal.date(byAdding: .month, value: -1, to: Date.now)
    case .custom:
      return customStartDate
    }
  }
  
  /// Calculates the end date for the selected range.
  private func calculateEndDate(for range: DateRange) -> Date {
    range == .custom ? customEndDate : Date.now
  }
  
  /// Filters daily revenues to those within the specified date range.
  private func filteredRevenues(for range: DateRange) -> [DailyRevenue] {
    guard let start = calculateStartDate(for: range) else {
      return dailyRevenues
    }
    let end = calculateEndDate(for: range)
    return dailyRevenues.filter { $0.date >= start && $0.date <= end }
  }
  
  /// Computes total revenue from charges within the range.
  private func totalRevenue(for range: DateRange) -> Double {
    guard let start = calculateStartDate(for: range) else {
      return charges.reduce(0) { $0 + $1.amount }
    }
    let end = calculateEndDate(for: range)
    return charges
      .filter { $0.date >= start && $0.date <= end }
      .reduce(0) { $0 + $1.amount }
  }
  
  // MARK: - Helper Lists
  
  /// Aggregates charge totals by service type.
  private func chargesSummary() -> [String: Double] {
    Charge
      .fetchTotalsByType(in: modelContext)
      .reduce(into: [String: Double]()) { dict, pair in
        dict[pair.key.rawValue] = pair.value
      }
  }
  
  /// Retrieves today's total revenue.
  private func todayRevenue() -> Double {
    let today = Self.calendar.startOfDay(for: Date.now)
    return dailyRevenues
      .first { Self.calendar.isDate($0.date, inSameDayAs: today) }?
      .totalAmount ?? 0
  }
  
  /// Computes the average revenue over the last seven days.
  private func averageLast7DaysRevenue() -> Double {
    let start = Self.calendar.date(byAdding: .day, value: -6, to: Date.now) ?? Date.now
    let recent = dailyRevenues.filter { $0.date >= start && $0.date <= Date.now }
    guard !recent.isEmpty else { return 0 }
    return recent.reduce(0) { $0 + $1.totalAmount } / Double(recent.count)
  }
  
  // MARK: - Simulated Refresh
  
  /// Simulates a data refresh with a one-second delay.
  private func simulateDataRefresh() async {
    isRefreshing = true
    try? await _Concurrency.Task.sleep(nanoseconds: 1_000_000_000)
    isRefreshing = false
  }
}

#if DEBUG
struct MetricsDashboardView_Previews: PreviewProvider {
  static var previews: some View {
    MetricsDashboardView(
      dailyRevenues: DailyRevenue.sampleData,
      appointments: Appointment.sampleData,
      charges: Charge.sampleData
    )
    .environment(\.modelContext, PreviewHelpers.context)
  }
}
#endif

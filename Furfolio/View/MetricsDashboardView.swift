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
import os

@MainActor
class MetricsDashboardViewModel: ObservableObject {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "MetricsDashboardViewModel")
  @Published var selectedDateRange: DateRange = .lastMonth
  @Published var customStartDate: Date = Date()
  @Published var customEndDate: Date = Date()
  @Published var isRefreshing = false

  private let dailyRevenues: [DailyRevenue]
  private let appointments: [Appointment]
  private let charges: [Charge]
  private static let calendar = Calendar.current

  init(dailyRevenues: [DailyRevenue], appointments: [Appointment], charges: [Charge]) {
    self.dailyRevenues = dailyRevenues
    self.appointments = appointments
    self.charges = charges
    logger.log("Initialized MetricsDashboardViewModel with \(dailyRevenues.count) revenues, \(appointments.count) appointments, \(charges.count) charges")
  }

  var filteredRevenues: [DailyRevenue] {
      logger.log("Computing filteredRevenues for range: \(selectedDateRange.rawValue)")
    guard let start = calculateStartDate() else { return dailyRevenues }
    let end = calculateEndDate()
    return dailyRevenues.filter { $0.date >= start && $0.date <= end }
  }

  var totalRevenue: Double {
    guard let start = calculateStartDate() else {
      return charges.reduce(0) { $0 + $1.amount }
    }
    let end = calculateEndDate()
    return charges
      .filter { $0.date >= start && $0.date <= end }
      .reduce(0) { $0 + $1.amount }
  }

  var chargesSummary: [String: Double] {
    Charge.fetchTotalsByType(in: modelContext)
      .reduce(into: [String: Double]()) { dict, pair in
        dict[pair.key.rawValue] = pair.value
      }
  }

  var todayRevenue: Double {
    let today = Self.calendar.startOfDay(for: Date.now)
    return dailyRevenues
      .first { Self.calendar.isDate($0.date, inSameDayAs: today) }?
      .totalAmount ?? 0
  }

  var averageLast7DaysRevenue: Double {
    let start = Self.calendar.date(byAdding: .day, value: -6, to: Date.now) ?? Date.now
    let recent = dailyRevenues.filter { $0.date >= start && $0.date <= Date.now }
    guard !recent.isEmpty else { return 0 }
    return recent.reduce(0) { $0 + $1.totalAmount } / Double(recent.count)
  }

  private func calculateStartDate() -> Date? {
    let cal = Self.calendar
    switch selectedDateRange {
    case .lastWeek:
      return cal.date(byAdding: .day, value: -7, to: Date.now)
    case .lastMonth:
      return cal.date(byAdding: .month, value: -1, to: Date.now)
    case .custom:
      return customStartDate
    }
  }

  private func calculateEndDate() -> Date {
    selectedDateRange == .custom ? customEndDate : Date.now
  }

  @MainActor func refreshData() async {
      logger.log("Refreshing dashboard data")
    isRefreshing = true
    try? await Task.sleep(nanoseconds: 1_000_000_000)
    isRefreshing = false
      logger.log("Finished refreshing dashboard data")
  }
}

@MainActor
/// View presenting a metrics dashboard with charts, summaries, and interactive filters for the Furfolio app.
struct MetricsDashboardView: View {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "MetricsDashboardView")
  @StateObject private var viewModel: MetricsDashboardViewModel

  let dailyRevenues: [DailyRevenue]
  let appointments: [Appointment]
  let charges: [Charge]

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

  init(dailyRevenues: [DailyRevenue], appointments: [Appointment], charges: [Charge]) {
    self.dailyRevenues = dailyRevenues
    self.appointments = appointments
    self.charges = charges
    _viewModel = StateObject(wrappedValue: MetricsDashboardViewModel(dailyRevenues: dailyRevenues, appointments: appointments, charges: charges))
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 16) {

          // Header
          Text("Metrics Dashboard")
            .font(AppTheme.header)
            .foregroundColor(AppTheme.primaryText)
            .accessibilityAddTraits(.isHeader)
            .transition(.opacity)

          // Revenue Trends
          RevenueChartView(dailyRevenues: viewModel.filteredRevenues)
            .transition(.move(edge: .leading))

          // Total Revenue
          TotalRevenueView(revenue: viewModel.totalRevenue)
            .transition(.move(edge: .trailing))

          // Revenue Snapshot
          RevenueSnapshotWidgetView(
            todayRevenue: viewModel.todayRevenue,
            averageRevenue: viewModel.averageLast7DaysRevenue
          )

          // Quarterly Revenue
          QuarterRevenueView(dailyRevenues: dailyRevenues)
            .transition(.opacity)

          // Upcoming Appointments
          UpcomingAppointmentsView()
            .transition(.slide)

          // Charge Summary
          ChargeSummaryView(charges: viewModel.chargesSummary)
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
            selectedDateRange: $viewModel.selectedDateRange,
            isCustomDateRangeActive: .constant(viewModel.selectedDateRange == .custom),
            customStartDate: $viewModel.customStartDate,
            customEndDate: $viewModel.customEndDate
          )
          .transition(.move(edge: .bottom))
        }
        .padding()
        .animation(.easeInOut, value: viewModel.selectedDateRange)
      }
      .refreshable {
        await viewModel.refreshData()
      }
      .navigationTitle("Dashboard")
      .navigationBarTitleDisplayMode(.inline)
      .onAppear {
          logger.log("MetricsDashboardView appeared with dateRange: \(viewModel.selectedDateRange.rawValue)")
      }
    }
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

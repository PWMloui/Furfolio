//
//  MetricsDashboardView.swift
//  Furfolio
//
//  Created by mac on 12/20/24.
//  Updated on [Today's Date] with advanced animations, modern navigation, and improved interactivity.

import SwiftUI
import Charts

struct MetricsDashboardView: View {
    @State private var selectedDateRange: DateRange = .lastMonth
    @State private var isCustomDateRangeActive = false
    @State private var customStartDate: Date = Date()
    @State private var customEndDate: Date = Date()
    
    let dailyRevenues: [DailyRevenue]
    let appointments: [Appointment]
    let charges: [Charge]
    
    // Adding a refresh state for simulated data reload
    @State private var isRefreshing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    Text(NSLocalizedString("Metrics Dashboard", comment: "Title for the metrics dashboard"))
                        .font(.largeTitle)
                        .bold()
                        .accessibilityAddTraits(.isHeader)
                        .transition(.opacity)
                    
                    // Revenue Trends Chart
                    RevenueChartView(dailyRevenues: filteredRevenues(for: selectedDateRange))
                        .transition(.move(edge: .leading))
                    
                    // Total Revenue Summary
                    TotalRevenueView(revenue: totalRevenue(for: selectedDateRange))
                        .transition(.move(edge: .trailing))

                    // Revenue Snapshot Summary
                    RevenueSnapshotWidgetView(todayRevenue: todayRevenue(), averageRevenue: averageLast7DaysRevenue())
                    
                    // Revenue by Quarters
                    QuarterRevenueView(dailyRevenues: dailyRevenues)
                        .transition(.opacity)
                    
                    // Upcoming Appointments
                    UpcomingAppointmentsView(appointments: upcomingAppointments())
                        .transition(.slide)
                    
                    // Charge Summary
                    ChargeSummaryView(charges: chargesSummary())
                        .transition(.opacity)
                    
                    // Popular Services
                    PopularServicesView(charges: charges)
                        .transition(.opacity)
                    
                    // Date Range Picker
                    DateRangePicker(selectedDateRange: $selectedDateRange,
                                    isCustomDateRangeActive: $isCustomDateRangeActive,
                                    customStartDate: $customStartDate,
                                    customEndDate: $customEndDate)
                        .transition(.move(edge: .bottom))
                }
                .padding()
                .animation(.easeInOut, value: selectedDateRange)
            }
            .refreshable {
                // Simulate a data refresh action.
                await simulateDataRefresh()
            }
            .navigationTitle(NSLocalizedString("Dashboard", comment: "Navigation title for metrics dashboard"))
        }
    }
    
    // MARK: - Helper Methods
    
    private func calculateStartDate(for range: DateRange) -> Date? {
        let calendar = Calendar.current
        switch range {
        case .lastWeek:
            return calendar.date(byAdding: .day, value: -7, to: Date())
        case .lastMonth:
            return calendar.date(byAdding: .month, value: -1, to: Date())
        case .custom:
            return customStartDate
        }
    }
    
    // New: Calculate the end date based on the selected date range.
    private func calculateEndDate(for range: DateRange) -> Date {
        if range == .custom {
            return customEndDate
        }
        return Date()
    }
    
    private func filteredRevenues(for range: DateRange) -> [DailyRevenue] {
        guard let startDate = calculateStartDate(for: range) else { return dailyRevenues }
        let endDate = calculateEndDate(for: range)
        // Animate the filtering when date range changes.
        return dailyRevenues.filter { $0.date >= startDate && $0.date <= endDate }
    }
    
    private func totalRevenue(for range: DateRange) -> Double {
        guard let startDate = calculateStartDate(for: range) else {
            return charges.reduce(0) { $0 + $1.amount }
        }
        let endDate = calculateEndDate(for: range)
        return charges.filter { $0.date >= startDate && $0.date <= endDate }
                      .reduce(0) { $0 + $1.amount }
    }
    
    private func upcomingAppointments() -> [Appointment] {
        let today = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 7, to: today) ?? today
        return appointments.filter { $0.date > today && $0.date <= endDate }
    }
    
    private func chargesSummary() -> [String: Double] {
        Charge.totalByType(charges: charges)
            .reduce(into: [String: Double]()) { result, item in
                result[item.key.rawValue] = item.value
            }
    }
    
    // MARK: - Revenue Snapshot Helpers

    private func todayRevenue() -> Double {
        let today = Calendar.current.startOfDay(for: Date())
        return dailyRevenues.first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) })?.totalAmount ?? 0
    }

    private func averageLast7DaysRevenue() -> Double {
        let startDate = Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date()
        let last7Days = dailyRevenues.filter { $0.date >= startDate && $0.date <= Date() }
        guard !last7Days.isEmpty else { return 0 }
        return last7Days.reduce(0) { $0 + $1.totalAmount } / Double(last7Days.count)
    }

    // MARK: - Simulated Data Refresh
    
    private func simulateDataRefresh() async {
        isRefreshing = true
        // Simulate a network/data refresh delay.
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        isRefreshing = false
    }
}

// MARK: - Revenue Chart View

struct RevenueChartView: View {
    let dailyRevenues: [DailyRevenue]

    var body: some View {
        VStack(alignment: .leading) {
            Text(NSLocalizedString("Revenue Trends", comment: "Section title for revenue trends"))
                .font(.headline)
            if dailyRevenues.isEmpty {
                Text(NSLocalizedString("No revenue data available.", comment: "Message when no revenue data exists"))
                    .foregroundColor(.gray)
            } else {
                Chart(dailyRevenues) {
                    LineMark(
                        x: .value("Date", $0.date),
                        y: .value("Revenue", $0.totalAmount)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.blue)
                }
                .frame(height: 200)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    AxisMarks(position: .bottom)
                }
                .accessibilityLabel(NSLocalizedString("Revenue Trends Chart", comment: "Accessibility label for revenue trends chart"))
                .accessibilityValue(NSLocalizedString("Shows revenue trends over selected date range.", comment: "Accessibility value for revenue trends chart"))
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Total Revenue View

struct TotalRevenueView: View {
    let revenue: Double

    var body: some View {
        VStack(alignment: .leading) {
            Text(NSLocalizedString("Total Revenue", comment: "Section title for total revenue"))
                .font(.headline)
            Text(revenue.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))
                .font(.title2)
                .bold()
                .accessibilityLabel(NSLocalizedString("Total Revenue", comment: "Accessibility label for total revenue"))
                .accessibilityValue(revenue.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Quarter Revenue View

struct QuarterRevenueView: View {
    let dailyRevenues: [DailyRevenue]

    var body: some View {
        VStack(alignment: .leading) {
            Text(NSLocalizedString("Quarterly Revenue", comment: "Section title for quarterly revenue"))
                .font(.headline)
            let groupedByQuarter = groupRevenuesByQuarter(dailyRevenues)
            ForEach(groupedByQuarter.keys.sorted(), id: \.self) { quarter in
                let totalRevenue = groupedByQuarter[quarter] ?? 0
                HStack {
                    Text("Q\(quarter)")
                        .font(.subheadline)
                    Spacer()
                    Text(totalRevenue.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .accessibilityLabel(String(format: NSLocalizedString("Quarter %d Revenue", comment: "Accessibility label for quarterly revenue"), quarter))
                        .accessibilityValue(totalRevenue.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))
                }
            }
        }
        .padding()
        .background(Color.teal.opacity(0.1))
        .cornerRadius(8)
    }

    private func groupRevenuesByQuarter(_ revenues: [DailyRevenue]) -> [Int: Double] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: revenues) { revenue in
            let month = calendar.component(.month, from: revenue.date)
            return (month - 1) / 3 + 1
        }
        return grouped.mapValues { $0.reduce(0) { $0 + $1.totalAmount } }
    }
}

// MARK: - Upcoming Appointments View

struct UpcomingAppointmentsView: View {
    let appointments: [Appointment]

    var body: some View {
        VStack(alignment: .leading) {
            Text(NSLocalizedString("Upcoming Appointments", comment: "Section title for upcoming appointments"))
                .font(.headline)
            if appointments.isEmpty {
                Text(NSLocalizedString("No upcoming appointments.", comment: "Message when no upcoming appointments exist"))
                    .foregroundColor(.gray)
            } else {
                ForEach(appointments) { appointment in
                    HStack {
                        Text(appointment.dogOwner.ownerName)
                            .font(.subheadline)
                        Spacer()
                        Text(appointment.date.formatted(.dateTime.month().day().hour().minute()))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Charge Summary View

struct ChargeSummaryView: View {
    let charges: [String: Double]

    var body: some View {
        VStack(alignment: .leading) {
            Text(NSLocalizedString("Charge Summary", comment: "Section title for charge summary"))
                .font(.headline)
            if charges.isEmpty {
                Text(NSLocalizedString("No charges recorded.", comment: "Message when no charges exist"))
                    .foregroundColor(.gray)
            } else {
                ForEach(charges.keys.sorted(), id: \.self) { type in
                    HStack {
                        Text(type)
                            .font(.subheadline)
                        Spacer()
                        Text(charges[type]?.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")) ?? "$0.00")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Popular Services View

struct PopularServicesView: View {
    let charges: [Charge]

    var body: some View {
        VStack(alignment: .leading) {
            Text(NSLocalizedString("Popular Services", comment: "Section title for popular services"))
                .font(.headline)
            let serviceCounts = charges.reduce(into: [String: Int]()) { counts, charge in
                counts[charge.type.rawValue, default: 0] += 1
            }
            if serviceCounts.isEmpty {
                Text(NSLocalizedString("No services data available.", comment: "Message when no service data exists"))
                    .foregroundColor(.gray)
            } else {
                ForEach(serviceCounts.keys.sorted(), id: \.self) { type in
                    HStack {
                        Text(type)
                            .font(.subheadline)
                        Spacer()
                        Text("\(serviceCounts[type] ?? 0) times")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color.purple.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Date Range Picker

struct DateRangePicker: View {
    @Binding var selectedDateRange: DateRange
    @Binding var isCustomDateRangeActive: Bool
    @Binding var customStartDate: Date
    @Binding var customEndDate: Date

    var body: some View {
        VStack {
            Picker(NSLocalizedString("Date Range", comment: "Picker title for date range selection"), selection: $selectedDateRange) {
                Text(NSLocalizedString("Last Week", comment: "Last week date range option")).tag(DateRange.lastWeek)
                Text(NSLocalizedString("Last Month", comment: "Last month date range option")).tag(DateRange.lastMonth)
                Text(NSLocalizedString("Custom", comment: "Custom date range option")).tag(DateRange.custom)
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: selectedDateRange) { _ in
                isCustomDateRangeActive = selectedDateRange == .custom
            }
            if isCustomDateRangeActive {
                DatePicker(
                    NSLocalizedString("Start Date", comment: "Start date picker label"),
                    selection: $customStartDate,
                    displayedComponents: .date
                )
                DatePicker(
                    NSLocalizedString("End Date", comment: "End date picker label"),
                    selection: $customEndDate,
                    displayedComponents: .date
                )
            }
        }
    }
}

// MARK: - Date Range Enum

enum DateRange {
    case lastWeek, lastMonth, custom
}

// MARK: - Revenue Snapshot Widget View

struct RevenueSnapshotWidgetView: View {
    let todayRevenue: Double
    let averageRevenue: Double

    var body: some View {
        VStack(alignment: .leading) {
            Text("Today's Revenue Snapshot")
                .font(.headline)
            Text(todayRevenue.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))
                .font(.title3)
                .bold()
            Text(snapshotStatus())
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.cyan.opacity(0.1))
        .cornerRadius(8)
    }

    private func snapshotStatus() -> String {
        if todayRevenue > averageRevenue {
            return "📈 Above average vs. last 7 days"
        } else if todayRevenue < averageRevenue {
            return "📉 Below average vs. last 7 days"
        } else {
            return "➖ On par with last 7 days"
        }
    }
}

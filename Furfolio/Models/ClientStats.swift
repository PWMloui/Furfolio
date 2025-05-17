//
//  ClientStats.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on Jun 10, 2025 — switched to Date.now, tightened up formatters, added chartData helper.
//

import Foundation

// TODO: Consider extracting summary and chartData into a dedicated SummaryBuilder and ChartDataProvider for reusability and testability.

@MainActor
/// Provides computed statistics and summaries for a given DogOwner, including loyalty, retention, and service usage metrics.
struct ClientStats {
    let owner: DogOwner

    // MARK: – Shared Resources & Thresholds

    private static let calendar = Calendar.current

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium      // e.g. “May 15, 2025”
        df.timeStyle = .none
        return df
    }()

    private static let monthYearFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MMM yyyy"  // e.g. “May 2025”
        return df
    }()

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        f.locale = Locale.current
        return f
    }()

    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale.current
        return f
    }()

    static let loyaltyThreshold = 10
    static let retentionDaysThreshold = 60
    static let topSpenderThreshold: Double = 1_000

    // MARK: – Helpers

    /// Formats an optional day count into a human-readable string.
    private static func dayCountString(_ days: Int?) -> String? {
        guard let d = days else { return nil }
        return d == 0 ? "Today" : "\(d) day\(d == 1 ? "" : "s") ago"
    }

    // MARK: – Basic Totals

    var totalAppointments: Int {
        owner.appointments.count
    }

    var totalCharges: Double {
        owner.charges.reduce(0) { $0 + $1.amount }
    }

    var averageChargeAmount: Double {
        guard totalAppointments > 0 else { return 0 }
        return totalCharges / Double(totalAppointments)
    }

    var formattedTotalCharges: String {
        Self.currencyFormatter.string(from: NSNumber(value: totalCharges))
            ?? "\(totalCharges)"
    }

    // MARK: – Loyalty & Retention

    var loyaltyStatus: String {
        switch totalAppointments {
        case 0: return "New"
        case 1: return "🐾 First Timer"
        case 2..<Self.loyaltyThreshold: return "🔁 Monthly Regular"
        default: return "🏅 Loyal Client"
        }
    }

    var isRetentionRisk: Bool {
        guard let last = owner.lastActivityDate,
              let cutoff = Self.calendar.date(
                  byAdding: .day,
                  value: -Self.retentionDaysThreshold,
                  to: Date.now)
        else { return true }
        return last < cutoff
    }

    var daysSinceLastActivity: Int? {
        guard let last = owner.lastActivityDate else { return nil }
        return Self.calendar.dateComponents(
            [.day],
            from: last,
            to: Date.now
        ).day
    }

    var daysSinceLastActivityString: String? {
        Self.dayCountString(daysSinceLastActivity)
    }

    // MARK: – Spending

    var isTopSpender: Bool {
        totalCharges > Self.topSpenderThreshold
    }

    var revenueLast30Days: Double {
        guard let cutoff = Self.calendar.date(
                byAdding: .day,
                value: -30,
                to: Date.now)
        else { return 0 }
        return owner.charges
            .filter { $0.date >= cutoff }
            .reduce(0) { $0 + $1.amount }
    }

    var formattedRevenueLast30Days: String {
        Self.currencyFormatter.string(from: NSNumber(value: revenueLast30Days))
            ?? "\(revenueLast30Days)"
    }

    // MARK: – Appointment Timing

    var lastAppointmentDate: Date? {
        owner.appointments.map(\.date).max()
    }

    var daysSinceLastAppointment: Int? {
        guard let date = lastAppointmentDate else { return nil }
        return Self.calendar.dateComponents(
            [.day],
            from: date,
            to: Date.now
        ).day
    }

    var formattedLastAppointmentDate: String? {
        lastAppointmentDate.map { Self.dateFormatter.string(from: $0) }
    }

    var daysSinceLastAppointmentString: String? {
        Self.dayCountString(daysSinceLastAppointment)
    }

    // MARK: – Charge Timing

    var lastChargeDate: Date? {
        owner.charges.map(\.date).max()
    }

    var daysSinceLastCharge: Int? {
        guard let date = lastChargeDate else { return nil }
        return Self.calendar.dateComponents(
            [.day],
            from: date,
            to: Date.now
        ).day
    }

    var formattedLastChargeDate: String? {
        lastChargeDate.map { Self.dateFormatter.string(from: $0) }
    }

    var daysSinceLastChargeString: String? {
        Self.dayCountString(daysSinceLastCharge)
    }

    // MARK: – Birthday

    var hasBirthdayThisMonth: Bool {
        guard let bd = owner.birthdate else { return false }
        return Self.calendar.isDate(bd, equalTo: Date.now, toGranularity: .month)
    }

    var nextBirthday: Date? {
        guard let bd = owner.birthdate else { return nil }
        var comps = Self.calendar.dateComponents([.month, .day], from: bd)
        comps.year = Self.calendar.component(.year, from: Date.now)
        guard let candidate = Self.calendar.date(from: comps) else { return nil }
        return candidate < Date.now
            ? Self.calendar.date(byAdding: .year, value: 1, to: candidate)
            : candidate
    }

    var daysUntilNextBirthday: Int? {
        guard let next = nextBirthday else { return nil }
        return Self.calendar.dateComponents(
            [.day],
            from: Date.now,
            to: next
        ).day
    }

    var daysUntilNextBirthdayString: String? {
        guard let days = daysUntilNextBirthday else { return nil }
        return days == 0 ? "Today" : "In \(days) day\(days == 1 ? "" : "s")"
    }

    var ageInYears: Int? {
        guard let bd = owner.birthdate else { return nil }
        return Self.calendar.dateComponents(
            [.year],
            from: bd,
            to: Date.now
        ).year
    }

    // MARK: – Progress & Badges

    var loyaltyProgressTag: String {
        let remaining = max(0, Self.loyaltyThreshold - totalAppointments)
        return remaining == 0
            ? "🎁 Free Bath Earned!"
            : "🏆 \(remaining) more to free bath"
    }

    var recentBehaviorBadges: [String] {
        let combined = owner.appointments.map { ($0.date, $0.behaviorLog.last ?? "") }
            + owner.charges.map { ($0.date, $0.behaviorBadge) }
        let badges = combined
            .sorted { $0.0 > $1.0 }
            .map(\.1)
            .filter { !$0.isEmpty }
        return Array(badges.prefix(3))
    }

    // TODO: Consider extracting these service-usage helpers into a separate ServiceUsageAnalyzer for reuse and testability.
    // MARK: – Service Usage

    /// Computes the average duration (in minutes) of all completed appointments.
    var averageAppointmentDuration: Double {
      let durs = owner.appointments.compactMap(\.estimatedDurationMinutes)
      guard !durs.isEmpty else { return 0 }
      return Double(durs.reduce(0, +)) / Double(durs.count)
    }

    /// Determines the most frequently booked service type.
    var mostFrequentServiceType: Appointment.ServiceType? {
      Dictionary(grouping: owner.appointments, by: \.serviceType)
        .max(by: { $0.value.count < $1.value.count })?.key
    }

    /// Localized name of the most frequently booked service, or "N/A" if none.
    var mostFrequentServiceName: String {
      mostFrequentServiceType?.localized ?? "N/A"
    }

    /// Groups a sequence by a formatted month string and computes a metric.
    private static func monthlyStat<T>(
      from items: [T],
      dateKey: (T) -> Date,
      value: (T) -> Double
    ) -> [(month: String, value: Double)] {
      Dictionary(grouping: items) {
        monthYearFormatter.string(from: dateKey($0))
      }
      .map { (month: $0.key, value: $0.value.reduce(0) { $0 + value($1) }) }
      .sorted { $0.month < $1.month }
    }

    /// Monthly visit counts keyed by "MMM yyyy", sorted ascending by month.
    var visitsPerMonth: [(month: String, count: Int)] {
      Self.monthlyStat(
        from: owner.appointments,
        dateKey: { $0.date },
        value: { Double($0.estimatedDurationMinutes ?? 0).isNaN ? 0 : 1 }
      ).map { (month: $0.month, count: Int($0.value)) }
    }

    /// Monthly revenue totals keyed by "MMM yyyy", sorted ascending by month.
    var revenuePerMonth: [(month: String, total: Double)] {
      Self.monthlyStat(
        from: owner.charges,
        dateKey: { $0.date },
        value: { $0.amount }
      ).map { (month: $0.month, total: $0.value) }
    }

    // MARK: – Chart Data Helper

    /// Returns data suitable for bar charts, mapping month labels to revenue values.
    var chartData: [(label: String, value: Double)] {
        revenuePerMonth.map { monthTotal in
            (label: monthTotal.month, value: monthTotal.total)
        }
    }

    // MARK: – Summary

    /// A concise text summary of visits, revenue, and loyalty status for display in overviews.
    var summary: String {
        "Visits: \(totalAppointments), Revenue: \(formattedTotalCharges), Status: \(loyaltyStatus)"
    }
}

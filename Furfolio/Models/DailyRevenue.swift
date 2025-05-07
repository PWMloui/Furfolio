//
//  DailyRevenue.swift
//  Furfolio
//
//  Created by mac on 12/20/24.
//

import Foundation
import SwiftData

@Model
final class DailyRevenue: Identifiable {
    @Attribute(.unique) var id: UUID
    @Attribute var date: Date
    var totalAmount: Double
    @Relationship(deleteRule: .cascade) var dogOwner: DogOwner // Relationship to DogOwner

    // MARK: - Initializer
    init(date: Date, totalAmount: Double = 0.0, dogOwner: DogOwner) throws {
        guard totalAmount >= 0 else {
            throw RevenueError.negativeAmount
        }
        guard date <= Date() else {
            throw RevenueError.futureDate
        }
        self.id = UUID()
        self.date = date
        self.totalAmount = totalAmount
        self.dogOwner = dogOwner
    }

    // MARK: - Error Handling
    enum RevenueError: Error, LocalizedError {
        case negativeAmount
        case futureDate

        var errorDescription: String? {
            switch self {
            case .negativeAmount:
                return NSLocalizedString("Total amount cannot be negative.", comment: "Revenue Error: Negative Amount")
            case .futureDate:
                return NSLocalizedString("Date cannot be in the future.", comment: "Revenue Error: Future Date")
            }
        }
    }

    // MARK: - Computed Properties

    /// Formats the total amount as a localized currency string.
    var formattedTotal: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return formatter.string(from: NSNumber(value: totalAmount)) ?? "$\(totalAmount)"
    }

    /// Returns a tag for daily revenue milestone (e.g. rewards or goals).
    var dailyRewardTag: String? {
        switch totalAmount {
        case 0..<100:
            return nil
        case 100..<250:
            return "🏅 Goal Met"
        case 250..<500:
            return "🎯 Great Day"
        case 500...:
            return "🚀 Record Breaker"
        default:
            return nil
        }
    }

    /// Bonus loyalty points earned based on daily revenue milestones.
    var earnedLoyaltyPoints: Int {
        switch totalAmount {
        case 0..<100:
            return 0
        case 100..<250:
            return 1
        case 250..<500:
            return 2
        case 500...:
            return 3
        default:
            return 0
        }
    }

    /// Computed badge showing loyalty progress and revenue thresholds.
    var loyaltyBadge: String {
        switch totalAmount {
        case 0..<100:
            return "🔸 Starter"
        case 100..<250:
            return "🔹 Loyal"
        case 250..<500:
            return "⭐️ Super Loyal"
        case 500...:
            return "🏆 VIP"
        default:
            return "🔸 Starter"
        }
    }

    /// Formats the date as a localized string.
    var formattedDate: String {
        date.formatted(.dateTime.month().day().year())
    }

    /// Checks if the revenue is for today's date.
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    /// Checks if the revenue is for the current month.
    var isCurrentMonth: Bool {
        Calendar.current.isDate(date, equalTo: Date(), toGranularity: .month)
    }

    /// Snapshot category for Revenue Snapshot Widget based on external average context.
    func snapshotCategory(averageLast7Days: Double) -> String {
        if totalAmount > averageLast7Days {
            return "📈 Above Average"
        } else if totalAmount < averageLast7Days {
            return "📉 Below Average"
        } else {
            return "➖ On Par"
        }
    }

    // MARK: - Methods

    /// Adds revenue to the total amount, ensuring the amount is non-negative.
    func addRevenue(amount: Double) {
        guard amount >= 0 else { return }
        totalAmount += amount
    }

    /// Resets the total revenue to 0.0 if the stored date isn't today.
    func resetIfNotToday() {
        if !isToday {
            totalAmount = 0.0
        }
    }

    /// Calculates the total revenue for the past 7 days, including today.
    func calculateWeeklyRevenue(from revenues: [DailyRevenue]) -> Double {
        let startDate = Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date()
        return DailyRevenue.totalRevenue(for: startDate...Date(), revenues: revenues)
    }

    /// Calculates the total revenue for the current month.
    func calculateMonthlyRevenue(from revenues: [DailyRevenue]) -> Double {
        guard let startOfMonth = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: date)),
              let endOfMonth = Calendar.current.date(byAdding: .month, value: 1, to: startOfMonth)?.addingTimeInterval(-1) else {
            return totalAmount
        }
        return DailyRevenue.totalRevenue(for: startOfMonth...endOfMonth, revenues: revenues)
    }

    /// Calculates the revenue for a specific date.
    func calculateRevenue(for specificDate: Date, from revenues: [DailyRevenue]) -> Double {
        revenues.filter { Calendar.current.isDate($0.date, inSameDayAs: specificDate) }
            .reduce(0) { $0 + $1.totalAmount }
    }

    // MARK: - Static Methods

    /// Calculates the total revenue for a specific date range.
    static func totalRevenue(for range: ClosedRange<Date>, revenues: [DailyRevenue]) -> Double {
        revenues.filter { range.contains($0.date) }
            .reduce(0) { $0 + $1.totalAmount }
    }

    /// Calculates the average daily revenue for a specific date range.
    static func averageDailyRevenue(for range: ClosedRange<Date>, revenues: [DailyRevenue]) -> Double {
        let filteredRevenues = revenues.filter { range.contains($0.date) }
        let totalDays = Calendar.current.dateComponents([.day], from: range.lowerBound, to: range.upperBound).day ?? 0
        guard totalDays > 0 else { return 0 }
        let totalRevenue = filteredRevenues.reduce(0) { $0 + $1.totalAmount }
        return totalRevenue / Double(totalDays + 1)
    }

    /// Returns the revenue for today's date, if available.
    static func revenueForToday(from revenues: [DailyRevenue]) -> DailyRevenue? {
        revenues.first { $0.isToday }
    }

    /// Summarizes the total weekly revenue grouped by week.
    static func weeklyRevenueSummary(from revenues: [DailyRevenue]) -> [(week: String, total: Double)] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: revenues) {
            calendar.component(.weekOfYear, from: $0.date)
        }

        return grouped.map { (week, weeklyRevenues) in
            let total = weeklyRevenues.reduce(0) { $0 + $1.totalAmount }
            return (week: NSLocalizedString("Week \(week)", comment: "Weekly revenue summary"), total: total)
        }
        .sorted { $0.week < $1.week }
    }

    // MARK: - New Static Methods for Improved Revenue Calculations

    /// Calculates the revenue for a specific owner over a specific date range.
    static func totalRevenueForOwner(owner: DogOwner, from revenues: [DailyRevenue]) -> Double {
        let ownerRevenues = revenues.filter { $0.dogOwner.id == owner.id }
        return ownerRevenues.reduce(0) { $0 + $1.totalAmount }
    }

    /// Returns the total revenue for each day within a given month.
    static func dailyRevenueSummary(for month: Int, year: Int, revenues: [DailyRevenue]) -> [(day: String, total: Double)] {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: DateComponents(year: year, month: month))!
        let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!.addingTimeInterval(-1)
        
        let monthlyRevenues = revenues.filter { $0.date >= startOfMonth && $0.date <= endOfMonth }
        
        let groupedByDay = Dictionary(grouping: monthlyRevenues) {
            calendar.component(.day, from: $0.date)
        }
        
        return groupedByDay.map { (day, dayRevenues) in
            let total = dayRevenues.reduce(0) { $0 + $1.totalAmount }
            return (day: "\(day)", total: total)
        }
        .sorted { Int($0.day)! < Int($1.day)! }
    }

    /// Returns the total revenue for each week of the year.
    static func weeklyRevenueSummary(for year: Int, revenues: [DailyRevenue]) -> [(week: String, total: Double)] {
        let calendar = Calendar.current
        let startOfYear = calendar.date(from: DateComponents(year: year))!
        let endOfYear = calendar.date(byAdding: .year, value: 1, to: startOfYear)!
 
        let filteredRevenues = revenues.filter { $0.date >= startOfYear && $0.date <= endOfYear }
        
        let groupedByWeek = Dictionary(grouping: filteredRevenues) {
            calendar.component(.weekOfYear, from: $0.date)
        }
        
        return groupedByWeek.map { (week, weekRevenues) in
            let total = weekRevenues.reduce(0) { $0 + $1.totalAmount }
            return (week: NSLocalizedString("Week \(week)", comment: "Weekly revenue summary"), total: total)
        }
        .sorted { $0.week < $1.week }
    }
    /// Returns the number of appointments per hour across all provided appointments.
    static func hourlyAppointmentFrequency(from appointments: [Appointment]) -> [Int: Int] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: appointments) {
            calendar.component(.hour, from: $0.date)
        }
        return grouped.mapValues { $0.count }
            .sorted { $0.key < $1.key }
            .reduce(into: [Int: Int]()) { $0[$1.key] = $1.value }
    }
    /// Calculates the average revenue per day for the current month.
    static func averageMonthlyRevenue(for month: Int, year: Int, revenues: [DailyRevenue]) -> Double {
        let calendar = Calendar.current
        guard let startOfMonth = calendar.date(from: DateComponents(year: year, month: month)),
              let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)?.addingTimeInterval(-1) else {
            return 0.0
        }

        let days = calendar.dateComponents([.day], from: startOfMonth, to: endOfMonth).day ?? 0
        guard days > 0 else { return 0.0 }

        let filtered = revenues.filter { $0.date >= startOfMonth && $0.date <= endOfMonth }
        let total = filtered.reduce(0) { $0 + $1.totalAmount }
        return total / Double(days + 1)
    }
}

//
//  DailyRevenue.swift
//  Furfolio
//
//  Created by mac on 12/20/24.
//  Updated on [Today's Date] with caching, relative date display, and improved data handling.

import Foundation
import SwiftData

@Model
final class DailyRevenue: Identifiable {
    @Attribute(.unique) var id: UUID
    @Attribute var date: Date
    var totalAmount: Double
    @Relationship(deleteRule: .cascade) var dogOwner: DogOwner // Relationship to DogOwner

    // MARK: - Cached Formatters
    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return formatter
    }()
    
    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

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

    /// Returns the total amount formatted as a localized currency string.
    var formattedTotal: String {
        // Use the cached currency formatter
        return DailyRevenue.currencyFormatter.string(from: NSNumber(value: totalAmount)) ?? "$\(totalAmount)"
    }

    /// Returns the date formatted as a localized string (e.g., "MM/DD/YYYY").
    var formattedDate: String {
        date.formatted(.dateTime.month().day().year())
    }
    
    /// Returns a human-friendly relative date string (e.g., "2 days ago").
    var relativeDateString: String {
        DailyRevenue.relativeDateFormatter.localizedString(for: date, relativeTo: Date())
    }

    /// Indicates whether the revenue is for today's date.
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    /// Indicates whether the revenue is for the current month.
    var isCurrentMonth: Bool {
        Calendar.current.isDate(date, equalTo: Date(), toGranularity: .month)
    }

    // MARK: - Methods

    /// Adds revenue to the total amount, ensuring the amount is non-negative.
    /// Logs the updated total for debugging purposes.
    func addRevenue(amount: Double) {
        guard amount >= 0 else { return }
        totalAmount += amount
        print("Added \(amount). New total for \(formattedDate): \(totalAmount)")
    }

    /// Resets the total revenue to 0.0 if the stored date isn't today.
    func resetIfNotToday() {
        if !isToday {
            totalAmount = 0.0
            print("Reset revenue for \(formattedDate) because it's not today.")
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
}

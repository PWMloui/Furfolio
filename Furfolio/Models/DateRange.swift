//
//  DateRange.swift
//  Furfolio
//
//  Created by ChatGPT on 06/01/2025.
//  Updated on 07/08/2025 — added computed start/end dates and helper API.
//


import Foundation
import os


@MainActor
/// Predefined date ranges for filtering metrics, with computed start/end dates.
enum DateRange: String, CaseIterable, @preconcurrency Identifiable {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "DateRange")
  /// Last seven days up to today.
  case lastWeek = "Last Week"
  /// Last calendar month up to today.
  case lastMonth = "Last Month"
  /// A custom date range defined by the user.
  case custom = "Custom"
    /// Shared calendar for date calculations.
    static var calendar = Calendar.current

    /// Overrideable provider for "now", useful in tests.
    static var overrideNow: (() -> Date)? = nil

    /// Reference to the current date and time.
    private static var now: Date {
        overrideNow?() ?? Date()
    }

    var id: String { rawValue }
    
    /// The end of the range, always the end of the current day.
    var endDate: Date {
        Self.logger.log("Calculating endDate for range: \(rawValue)")
        let todayStart = Self.calendar.startOfDay(for: Self.now)
        // end of day at 23:59:59
        return Self.calendar.date(byAdding: .second, value: 86_399, to: todayStart)!
    }
    
    /// The start of the range, or `nil` if the range is `.custom`.
    var startDate: Date? {
        Self.logger.log("Calculating startDate for range: \(rawValue)")
        let now = Self.now
        let cal = Self.calendar
        
        switch self {
        case .lastWeek:
            let start = cal.date(byAdding: .day, value: -7, to: now)!
            return cal.startOfDay(for: start)
        case .lastMonth:
            let start = cal.date(byAdding: .month, value: -1, to: now)!
            return cal.startOfDay(for: start)
        case .custom:
            return nil
        }
    }
    
    /// A DateInterval from `startDate` to `endDate`, or `nil` for `.custom`.
    var interval: DateInterval? {
        Self.logger.log("Calculating interval for range: \(rawValue)")
        guard let start = startDate else { return nil }
        return DateInterval(start: start, end: endDate)
    }
    
    /// Display-friendly title for the range.
    var title: String {
        rawValue
    }
}

// MARK: - CustomStringConvertible & Utilities

/// Conformance for textual representation and membership checks.
extension DateRange: CustomStringConvertible {
    /// Returns `title` as the textual description.
    var description: String { title }

    /// Determines if the given date falls within this range (always true for `.custom`).
    /// - Parameter date: The date to check.
    /// - Returns: `true` if within range or if `.custom`.
    func contains(_ date: Date) -> Bool {
        Self.logger.log("Checking if date \\(date) is within range: \(rawValue)")
        guard let interval = interval else {
            Self.logger.log("contains(\\(date)) result: true (.custom always returns true)")
            return true
        }
        let result = interval.contains(date)
        Self.logger.log("contains(\\(date)) result: \(result)")
        return result
    }
}

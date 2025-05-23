//
//  DateRange.swift
//  Furfolio
//
//  Created by ChatGPT on 06/01/2025.
//  Updated on 07/08/2025 — added computed start/end dates and helper API.
//

import Foundation

// TODO: Allow localization of titles and injection of a custom calendar for testing.

@MainActor
/// Predefined date ranges for filtering metrics, with computed start/end dates.
enum DateRange: String, CaseIterable, @preconcurrency Identifiable {
  /// Last seven days up to today.
  case lastWeek = "Last Week"
  /// Last calendar month up to today.
  case lastMonth = "Last Month"
  /// A custom date range defined by the user.
  case custom = "Custom"
    /// Shared calendar for date calculations.
    private static let calendar = Calendar.current

    /// Reference to the current date and time.
    private static var now: Date { Date.now }

    var id: String { rawValue }
    
    /// The end of the range, always the current date.
    var endDate: Date {
        Self.now
    }
    
    /// The start of the range, or `nil` if the range is `.custom`.
    var startDate: Date? {
        let now = Self.now
        let cal = Self.calendar
        
        switch self {
        case .lastWeek:
            return cal.date(byAdding: .day, value: -7, to: now)
        case .lastMonth:
            return cal.date(byAdding: .month, value: -1, to: now)
        case .custom:
            return nil
        }
    }
    
    /// A DateInterval from `startDate` to `endDate`, or `nil` for `.custom`.
    var interval: DateInterval? {
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
        guard let interval = interval else { return true }
        return interval.contains(date)
    }
}

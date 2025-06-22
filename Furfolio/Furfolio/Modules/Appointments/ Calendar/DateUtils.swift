//
// MARK: - DateUtils (Centralized, Modular, Auditable Date & Time Utilities)
//  DateUtils.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//  Centralized date/time utilities for Furfolio business operations, analytics, and scheduling.
//
//  This module provides a comprehensive, modular, and auditable set of date and time utilities tailored for Furfolio's business logic.
//  It supports tokenized UI display and localization through LocalizedStringKey for consistency across the app.
//  Designed with audit-readiness and compliance in mind, these utilities facilitate accurate analytics and event logging.
//  The utilities enable consistent date/time formatting, relative date descriptions, range calculations, and business-specific date operations.
//  Shared static instances and computed properties optimize performance and maintainability.
//

import Foundation
import SwiftUI

enum DateUtils {
    
    // MARK: - Constants
    
    private enum Constants {
        static let daysInWeek = 7
        static let secondsInDay = 86400
        static let oneDayComponent = 1
        static let oneSecondComponent = 1
    }
    
    // MARK: - Shared Instances
    
    /// Shared calendar instance for consistent date calculations.
    static var calendar: Calendar {
        Calendar.current
    }
    
    /// Shared short date formatter instance.
    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
    
    /// Shared full date & time formatter instance.
    private static let fullDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    // MARK: - Formatters

    /// Returns a short formatted string for a date (e.g., "6/20/25").
    /// - Parameter date: The date to format.
    /// - Returns: A short date string or a placeholder if nil.
    /// - Note: TODO - Add audit/event logging and tokenized UI display support.
    static func shortDate(_ date: Date?) -> String {
        guard let date = date else { return LocalizedStringKey("--").stringValue }
        // TODO: Add audit/event logging hook here.
        return shortDateFormatter.string(from: date)
    }

    /// Returns a full date & time string (e.g., "Jun 20, 2025 at 2:20 PM").
    /// - Parameter date: The date to format.
    /// - Returns: A full date and time string or a placeholder if nil.
    /// - Note: TODO - Add audit/event logging and tokenized UI display support.
    static func fullDateTime(_ date: Date?) -> String {
        guard let date = date else { return LocalizedStringKey("--").stringValue }
        // TODO: Add audit/event logging hook here.
        return fullDateTimeFormatter.string(from: date)
    }

    /// Returns a custom formatted date string (see Unicode Date Format Patterns).
    /// - Parameters:
    ///   - date: The date to format.
    ///   - format: The custom date format string.
    /// - Returns: A formatted date string or a placeholder if nil.
    /// - Note: TODO - Add audit/event logging and tokenized UI display support.
    static func custom(_ date: Date?, format: String) -> String {
        guard let date = date else { return LocalizedStringKey("--").stringValue }
        // TODO: Add audit/event logging hook here.
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: date)
    }

    // MARK: - Relative & Humanized Strings

    /// Returns "Today", "Yesterday", or "n days ago" for a date (analytics-friendly).
    /// - Parameter date: The date to describe.
    /// - Returns: A localized relative string describing the date.
    /// - Note: TODO - Add audit/event logging and tokenized UI display support.
    static func relativeString(from date: Date?) -> String {
        guard let date = date else { return LocalizedStringKey("--").stringValue }
        let calendar = self.calendar
        // TODO: Add audit/event logging hook here.
        if calendar.isDateInToday(date) { return LocalizedStringKey("Today").stringValue }
        if calendar.isDateInYesterday(date) { return LocalizedStringKey("Yesterday").stringValue }
        let days = calendar.dateComponents([.day], from: date, to: Date()).day ?? 0
        return days == 0 ? LocalizedStringKey("Today").stringValue : String(format: NSLocalizedString("%d days ago", comment: "Relative days ago"), days)
    }

    /// Returns "in X days", "Tomorrow", or "Today" for a future date (for reminders).
    /// - Parameter date: The future date to describe.
    /// - Returns: A localized relative string describing the future date.
    /// - Note: TODO - Add audit/event logging and tokenized UI display support.
    static func futureString(to date: Date?) -> String {
        guard let date = date else { return LocalizedStringKey("--").stringValue }
        let calendar = self.calendar
        // TODO: Add audit/event logging hook here.
        if calendar.isDateInToday(date) { return LocalizedStringKey("Today").stringValue }
        if calendar.isDateInTomorrow(date) { return LocalizedStringKey("Tomorrow").stringValue }
        let days = calendar.dateComponents([.day], from: Date(), to: date).day ?? 0
        if days == 1 { return LocalizedStringKey("Tomorrow").stringValue }
        if days == 0 { return LocalizedStringKey("Today").stringValue }
        return String(format: NSLocalizedString("in %d days", comment: "Future days"), days)
    }
    
    /// Returns a relative string for expense/charge history (e.g., "Last month", "3 weeks ago").
    /// - Parameter date: The date to describe.
    /// - Returns: A localized relative string describing the business date.
    /// - Note: TODO - Add audit/event logging and tokenized UI display support.
    static func businessRelativeString(from date: Date?) -> String {
        guard let date = date else { return LocalizedStringKey("--").stringValue }
        let calendar = self.calendar
        let now = Date()
        // TODO: Add audit/event logging hook here.
        let days = calendar.dateComponents([.day], from: date, to: now).day ?? 0
        let weeks = days / Constants.daysInWeek
        let months = calendar.dateComponents([.month], from: date, to: now).month ?? 0
        if days < 1 { return LocalizedStringKey("Today").stringValue }
        if days == 1 { return LocalizedStringKey("Yesterday").stringValue }
        if weeks < 1 { return String(format: NSLocalizedString("%d days ago", comment: "Relative days ago"), days) }
        if weeks == 1 { return LocalizedStringKey("Last week").stringValue }
        if months < 1 { return String(format: NSLocalizedString("%d weeks ago", comment: "Relative weeks ago"), weeks) }
        if months == 1 { return LocalizedStringKey("Last month").stringValue }
        return String(format: NSLocalizedString("%d months ago", comment: "Relative months ago"), months)
    }

    // MARK: - Range & Math Utilities

    /// Returns true if date is in the future.
    /// - Parameter date: The date to check.
    /// - Returns: Boolean indicating if date is in the future.
    /// - Note: TODO - Add audit/event logging support.
    static func isFuture(_ date: Date?) -> Bool {
        guard let date = date else { return false }
        // TODO: Add audit/event logging hook here.
        return date > Date()
    }

    /// Returns true if date is today.
    /// - Parameter date: The date to check.
    /// - Returns: Boolean indicating if date is today.
    /// - Note: TODO - Add audit/event logging support.
    static func isToday(_ date: Date?) -> Bool {
        guard let date = date else { return false }
        // TODO: Add audit/event logging hook here.
        return calendar.isDateInToday(date)
    }

    /// Returns true if date is in the past.
    /// - Parameter date: The date to check.
    /// - Returns: Boolean indicating if date is in the past.
    /// - Note: TODO - Add audit/event logging support.
    static func isPast(_ date: Date?) -> Bool {
        guard let date = date else { return false }
        // TODO: Add audit/event logging hook here.
        return date < Date()
    }

    /// Returns the number of days between two dates.
    /// - Parameters:
    ///   - from: The start date.
    ///   - to: The end date.
    /// - Returns: Number of days between from and to.
    /// - Note: TODO - Add audit/event logging support.
    static func daysBetween(_ from: Date, _ to: Date) -> Int {
        // TODO: Add audit/event logging hook here.
        calendar.dateComponents([.day], from: from, to: to).day ?? 0
    }

    /// Returns the start of the day for a given date.
    /// - Parameter date: The date to evaluate.
    /// - Returns: The date at the start of the day.
    /// - Note: TODO - Add audit/event logging support.
    static func startOfDay(_ date: Date) -> Date {
        // TODO: Add audit/event logging hook here.
        calendar.startOfDay(for: date)
    }

    /// Returns the end of the day for a given date.
    /// - Parameter date: The date to evaluate.
    /// - Returns: The date at the end of the day.
    /// - Note: TODO - Add audit/event logging support.
    static func endOfDay(_ date: Date) -> Date {
        let calendar = self.calendar
        let start = calendar.startOfDay(for: date)
        // TODO: Add audit/event logging hook here.
        return calendar.date(byAdding: DateComponents(day: Constants.oneDayComponent, second: -Constants.oneSecondComponent), to: start) ?? date
    }

    // MARK: - Week & Month Helpers

    /// Returns the first date of the month for a given date.
    /// - Parameter date: The date to evaluate.
    /// - Returns: The first date of the month.
    /// - Note: TODO - Add audit/event logging support.
    static func startOfMonth(_ date: Date) -> Date {
        let calendar = self.calendar
        let comps = calendar.dateComponents([.year, .month], from: date)
        // TODO: Add audit/event logging hook here.
        return calendar.date(from: comps) ?? date
    }

    /// Returns the last date of the month for a given date.
    /// - Parameter date: The date to evaluate.
    /// - Returns: The last date of the month.
    /// - Note: TODO - Add audit/event logging support.
    static func endOfMonth(_ date: Date) -> Date {
        let calendar = self.calendar
        if let range = calendar.range(of: .day, in: .month, for: date),
           let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) {
            // TODO: Add audit/event logging hook here.
            return calendar.date(byAdding: .day, value: range.count - Constants.oneDayComponent, to: start) ?? date
        }
        return date
    }

    /// Returns the start of the week (Sunday) for a given date.
    /// - Parameter date: The date to evaluate.
    /// - Returns: The start date of the week (Sunday).
    /// - Note: TODO - Add audit/event logging support.
    static func startOfWeek(_ date: Date) -> Date {
        let calendar = self.calendar
        let weekday = calendar.component(.weekday, from: date)
        // TODO: Add audit/event logging hook here.
        return calendar.date(byAdding: .day, value: -(weekday - Constants.oneDayComponent), to: startOfDay(date)) ?? date
    }

    /// Returns the end of the week (Saturday) for a given date.
    /// - Parameter date: The date to evaluate.
    /// - Returns: The end date of the week (Saturday).
    /// - Note: TODO - Add audit/event logging support.
    static func endOfWeek(_ date: Date) -> Date {
        let calendar = self.calendar
        let weekday = calendar.component(.weekday, from: date)
        // TODO: Add audit/event logging hook here.
        return calendar.date(byAdding: .day, value: Constants.daysInWeek - weekday, to: startOfDay(date)) ?? date
    }

    // MARK: - Birthday, Anniversary, Age

    /// Returns age in years for a given birthday.
    /// - Parameter birthday: The birth date.
    /// - Returns: The age in years.
    /// - Note: TODO - Add audit/event logging support.
    static func age(from birthday: Date?) -> Int {
        guard let birthday = birthday else { return 0 }
        let calendar = self.calendar
        // TODO: Add audit/event logging hook here.
        let components = calendar.dateComponents([.year], from: birthday, to: Date())
        return components.year ?? 0
    }
    
    /// Returns true if today is the anniversary of a date (e.g., pet birthday, join date).
    /// - Parameter date: The date to check.
    /// - Returns: Boolean indicating if today is the anniversary.
    /// - Note: TODO - Add audit/event logging support.
    static func isAnniversary(_ date: Date?) -> Bool {
        guard let date = date else { return false }
        let calendar = self.calendar
        let today = calendar.dateComponents([.month, .day], from: Date())
        let anniversary = calendar.dateComponents([.month, .day], from: date)
        // TODO: Add audit/event logging hook here.
        return today.month == anniversary.month && today.day == anniversary.day
    }
    
    // MARK: - Business Week Helpers
    
    /// Returns all dates for a week, given a reference date (Sunday-Saturday).
    /// - Parameter date: The reference date.
    /// - Returns: Array of dates representing the week.
    /// - Note: TODO - Add audit/event logging support.
    static func daysOfWeek(for date: Date) -> [Date] {
        let start = startOfWeek(date)
        // TODO: Add audit/event logging hook here.
        return (0..<Constants.daysInWeek).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
    
    /// Returns all dates for a month, given a reference date (full weeks for calendar grids).
    /// - Parameter date: The reference date.
    /// - Returns: Array of dates covering the full month grid.
    /// - Note: TODO - Add audit/event logging support.
    static func daysOfMonthGrid(for date: Date) -> [Date] {
        let start = startOfWeek(startOfMonth(date))
        let end = endOfWeek(endOfMonth(date))
        var dates: [Date] = []
        var current = start
        // TODO: Add audit/event logging hook here.
        while current <= end {
            dates.append(current)
            current = calendar.date(byAdding: .day, value: Constants.oneDayComponent, to: current)!
        }
        return dates
    }
}

// MARK: - LocalizedStringKey Extension

private extension LocalizedStringKey {
    /// Helper to convert LocalizedStringKey to String for internal usage.
    /// Note: This is a workaround; in SwiftUI views, LocalizedStringKey should be used directly.
    var stringValue: String {
        // This is a simplified placeholder implementation.
        // In production, localization should be handled by SwiftUI views directly.
        Mirror(reflecting: self).children.first(where: { $0.label == "key" })?.value as? String ?? ""
    }
}

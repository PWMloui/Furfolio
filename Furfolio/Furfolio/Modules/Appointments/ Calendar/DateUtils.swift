//
// MARK: - DateUtils (Centralized, Modular, Auditable Date & Time Utilities)
//  DateUtils.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Tokenized, BI/Compliance-Ready Date & Time Utilities

import Foundation
import SwiftUI

// MARK: - Audit/Event Logging for DateUtils

fileprivate struct DateUtilsAuditEvent: Codable {
    let timestamp: Date
    let operation: String
    let date: Date?
    let date2: Date?
    let value: String?
    let tags: [String]
    let actor: String?
    let context: String?
    let detail: String?
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        let op = operation.capitalized
        let val = value ?? ""
        return "[\(op)] \(val) at \(dateStr)\(detail.map { ": \($0)" } ?? "")"
    }
}

fileprivate final class DateUtilsAudit {
    static private(set) var log: [DateUtilsAuditEvent] = []

    static func record(
        operation: String,
        date: Date? = nil,
        date2: Date? = nil,
        value: String? = nil,
        tags: [String] = [],
        actor: String? = nil,
        context: String? = "DateUtils",
        detail: String? = nil
    ) {
        let event = DateUtilsAuditEvent(
            timestamp: Date(),
            operation: operation,
            date: date,
            date2: date2,
            value: value,
            tags: tags,
            actor: actor,
            context: context,
            detail: detail
        )
        log.append(event)
        if log.count > 500 { log.removeFirst() }
    }

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No date/time actions recorded."
    }
}

enum DateUtils {
    // MARK: - Constants
    private enum Constants {
        static let daysInWeek = 7
        static let secondsInDay = 86400
        static let oneDayComponent = 1
        static let oneSecondComponent = 1
    }

    // MARK: - Shared Instances

    static var calendar: Calendar { Calendar.current }

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    private static let fullDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    // MARK: - Formatters

    static func shortDate(_ date: Date?, actor: String? = nil, context: String? = nil) -> String {
        let result = date.map { shortDateFormatter.string(from: $0) } ?? LocalizedStringKey("--").stringValue
        DateUtilsAudit.record(
            operation: "shortDate",
            date: date,
            value: result,
            tags: ["format", "short"],
            actor: actor,
            context: context
        )
        return result
    }

    static func fullDateTime(_ date: Date?, actor: String? = nil, context: String? = nil) -> String {
        let result = date.map { fullDateTimeFormatter.string(from: $0) } ?? LocalizedStringKey("--").stringValue
        DateUtilsAudit.record(
            operation: "fullDateTime",
            date: date,
            value: result,
            tags: ["format", "full"],
            actor: actor,
            context: context
        )
        return result
    }

    static func custom(_ date: Date?, format: String, actor: String? = nil, context: String? = nil) -> String {
        guard let date = date else {
            let fallback = LocalizedStringKey("--").stringValue
            DateUtilsAudit.record(
                operation: "customFormat",
                date: nil,
                value: fallback,
                tags: ["format", "custom", "nil"],
                actor: actor,
                context: context,
                detail: "format: \(format)"
            )
            return fallback
        }
        let formatter = DateFormatter()
        formatter.dateFormat = format
        let result = formatter.string(from: date)
        DateUtilsAudit.record(
            operation: "customFormat",
            date: date,
            value: result,
            tags: ["format", "custom"],
            actor: actor,
            context: context,
            detail: "format: \(format)"
        )
        return result
    }

    // MARK: - Relative & Humanized Strings

    static func relativeString(from date: Date?, actor: String? = nil, context: String? = nil) -> String {
        guard let date = date else {
            let fallback = LocalizedStringKey("--").stringValue
            DateUtilsAudit.record(
                operation: "relativeString",
                date: nil,
                value: fallback,
                tags: ["relative", "nil"],
                actor: actor,
                context: context
            )
            return fallback
        }
        let calendar = self.calendar
        let result: String
        if calendar.isDateInToday(date) {
            result = LocalizedStringKey("Today").stringValue
        } else if calendar.isDateInYesterday(date) {
            result = LocalizedStringKey("Yesterday").stringValue
        } else {
            let days = calendar.dateComponents([.day], from: date, to: Date()).day ?? 0
            result = days == 0 ? LocalizedStringKey("Today").stringValue : String(format: NSLocalizedString("%d days ago", comment: "Relative days ago"), days)
        }
        DateUtilsAudit.record(
            operation: "relativeString",
            date: date,
            value: result,
            tags: ["relative"],
            actor: actor,
            context: context
        )
        return result
    }

    static func futureString(to date: Date?, actor: String? = nil, context: String? = nil) -> String {
        guard let date = date else {
            let fallback = LocalizedStringKey("--").stringValue
            DateUtilsAudit.record(
                operation: "futureString",
                date: nil,
                value: fallback,
                tags: ["future", "nil"],
                actor: actor,
                context: context
            )
            return fallback
        }
        let calendar = self.calendar
        let result: String
        if calendar.isDateInToday(date) {
            result = LocalizedStringKey("Today").stringValue
        } else if calendar.isDateInTomorrow(date) {
            result = LocalizedStringKey("Tomorrow").stringValue
        } else {
            let days = calendar.dateComponents([.day], from: Date(), to: date).day ?? 0
            if days == 1 { result = LocalizedStringKey("Tomorrow").stringValue }
            else if days == 0 { result = LocalizedStringKey("Today").stringValue }
            else { result = String(format: NSLocalizedString("in %d days", comment: "Future days"), days) }
        }
        DateUtilsAudit.record(
            operation: "futureString",
            date: date,
            value: result,
            tags: ["future"],
            actor: actor,
            context: context
        )
        return result
    }

    static func businessRelativeString(from date: Date?, actor: String? = nil, context: String? = nil) -> String {
        guard let date = date else {
            let fallback = LocalizedStringKey("--").stringValue
            DateUtilsAudit.record(
                operation: "businessRelativeString",
                date: nil,
                value: fallback,
                tags: ["businessRelative", "nil"],
                actor: actor,
                context: context
            )
            return fallback
        }
        let calendar = self.calendar
        let now = Date()
        let days = calendar.dateComponents([.day], from: date, to: now).day ?? 0
        let weeks = days / Constants.daysInWeek
        let months = calendar.dateComponents([.month], from: date, to: now).month ?? 0
        let result: String
        if days < 1 { result = LocalizedStringKey("Today").stringValue }
        else if days == 1 { result = LocalizedStringKey("Yesterday").stringValue }
        else if weeks < 1 { result = String(format: NSLocalizedString("%d days ago", comment: "Relative days ago"), days) }
        else if weeks == 1 { result = LocalizedStringKey("Last week").stringValue }
        else if months < 1 { result = String(format: NSLocalizedString("%d weeks ago", comment: "Relative weeks ago"), weeks) }
        else if months == 1 { result = LocalizedStringKey("Last month").stringValue }
        else { result = String(format: NSLocalizedString("%d months ago", comment: "Relative months ago"), months) }
        DateUtilsAudit.record(
            operation: "businessRelativeString",
            date: date,
            value: result,
            tags: ["businessRelative"],
            actor: actor,
            context: context
        )
        return result
    }

    // MARK: - Range & Math Utilities

    static func isFuture(_ date: Date?, actor: String? = nil, context: String? = nil) -> Bool {
        let isFuture = date.map { $0 > Date() } ?? false
        DateUtilsAudit.record(
            operation: "isFuture",
            date: date,
            value: "\(isFuture)",
            tags: ["check", "future"],
            actor: actor,
            context: context
        )
        return isFuture
    }

    static func isToday(_ date: Date?, actor: String? = nil, context: String? = nil) -> Bool {
        let isToday = date.map { calendar.isDateInToday($0) } ?? false
        DateUtilsAudit.record(
            operation: "isToday",
            date: date,
            value: "\(isToday)",
            tags: ["check", "today"],
            actor: actor,
            context: context
        )
        return isToday
    }

    static func isPast(_ date: Date?, actor: String? = nil, context: String? = nil) -> Bool {
        let isPast = date.map { $0 < Date() } ?? false
        DateUtilsAudit.record(
            operation: "isPast",
            date: date,
            value: "\(isPast)",
            tags: ["check", "past"],
            actor: actor,
            context: context
        )
        return isPast
    }

    static func daysBetween(_ from: Date, _ to: Date, actor: String? = nil, context: String? = nil) -> Int {
        let days = calendar.dateComponents([.day], from: from, to: to).day ?? 0
        DateUtilsAudit.record(
            operation: "daysBetween",
            date: from,
            date2: to,
            value: "\(days)",
            tags: ["range", "daysBetween"],
            actor: actor,
            context: context
        )
        return days
    }

    static func startOfDay(_ date: Date, actor: String? = nil, context: String? = nil) -> Date {
        let start = calendar.startOfDay(for: date)
        DateUtilsAudit.record(
            operation: "startOfDay",
            date: date,
            value: shortDate(start),
            tags: ["boundary", "startOfDay"],
            actor: actor,
            context: context
        )
        return start
    }

    static func endOfDay(_ date: Date, actor: String? = nil, context: String? = nil) -> Date {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: DateComponents(day: Constants.oneDayComponent, second: -Constants.oneSecondComponent), to: start) ?? date
        DateUtilsAudit.record(
            operation: "endOfDay",
            date: date,
            value: shortDate(end),
            tags: ["boundary", "endOfDay"],
            actor: actor,
            context: context
        )
        return end
    }

    // MARK: - Week & Month Helpers

    static func startOfMonth(_ date: Date, actor: String? = nil, context: String? = nil) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: date)
        let start = calendar.date(from: comps) ?? date
        DateUtilsAudit.record(
            operation: "startOfMonth",
            date: date,
            value: shortDate(start),
            tags: ["boundary", "startOfMonth"],
            actor: actor,
            context: context
        )
        return start
    }

    static func endOfMonth(_ date: Date, actor: String? = nil, context: String? = nil) -> Date {
        if let range = calendar.range(of: .day, in: .month, for: date),
           let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) {
            let end = calendar.date(byAdding: .day, value: range.count - Constants.oneDayComponent, to: start) ?? date
            DateUtilsAudit.record(
                operation: "endOfMonth",
                date: date,
                value: shortDate(end),
                tags: ["boundary", "endOfMonth"],
                actor: actor,
                context: context
            )
            return end
        }
        DateUtilsAudit.record(
            operation: "endOfMonth",
            date: date,
            value: shortDate(date),
            tags: ["boundary", "endOfMonth", "fail"],
            actor: actor,
            context: context
        )
        return date
    }

    static func startOfWeek(_ date: Date, actor: String? = nil, context: String? = nil) -> Date {
        let weekday = calendar.component(.weekday, from: date)
        let start = calendar.date(byAdding: .day, value: -(weekday - Constants.oneDayComponent), to: startOfDay(date)) ?? date
        DateUtilsAudit.record(
            operation: "startOfWeek",
            date: date,
            value: shortDate(start),
            tags: ["boundary", "startOfWeek"],
            actor: actor,
            context: context
        )
        return start
    }

    static func endOfWeek(_ date: Date, actor: String? = nil, context: String? = nil) -> Date {
        let weekday = calendar.component(.weekday, from: date)
        let end = calendar.date(byAdding: .day, value: Constants.daysInWeek - weekday, to: startOfDay(date)) ?? date
        DateUtilsAudit.record(
            operation: "endOfWeek",
            date: date,
            value: shortDate(end),
            tags: ["boundary", "endOfWeek"],
            actor: actor,
            context: context
        )
        return end
    }

    // MARK: - Birthday, Anniversary, Age

    static func age(from birthday: Date?, actor: String? = nil, context: String? = nil) -> Int {
        guard let birthday = birthday else {
            DateUtilsAudit.record(
                operation: "age",
                date: nil,
                value: "0",
                tags: ["age", "nil"],
                actor: actor,
                context: context
            )
            return 0
        }
        let components = calendar.dateComponents([.year], from: birthday, to: Date())
        let age = components.year ?? 0
        DateUtilsAudit.record(
            operation: "age",
            date: birthday,
            value: "\(age)",
            tags: ["age"],
            actor: actor,
            context: context
        )
        return age
    }

    static func isAnniversary(_ date: Date?, actor: String? = nil, context: String? = nil) -> Bool {
        guard let date = date else {
            DateUtilsAudit.record(
                operation: "isAnniversary",
                date: nil,
                value: "false",
                tags: ["anniversary", "nil"],
                actor: actor,
                context: context
            )
            return false
        }
        let today = calendar.dateComponents([.month, .day], from: Date())
        let anniversary = calendar.dateComponents([.month, .day], from: date)
        let isAnniv = today.month == anniversary.month && today.day == anniversary.day
        DateUtilsAudit.record(
            operation: "isAnniversary",
            date: date,
            value: "\(isAnniv)",
            tags: ["anniversary"],
            actor: actor,
            context: context
        )
        return isAnniv
    }

    // MARK: - Business Week Helpers

    static func daysOfWeek(for date: Date, actor: String? = nil, context: String? = nil) -> [Date] {
        let start = startOfWeek(date)
        let days = (0..<Constants.daysInWeek).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        DateUtilsAudit.record(
            operation: "daysOfWeek",
            date: date,
            value: "\(days.map { shortDate($0) })",
            tags: ["week", "dates"],
            actor: actor,
            context: context
        )
        return days
    }

    static func daysOfMonthGrid(for date: Date, actor: String? = nil, context: String? = nil) -> [Date] {
        let start = startOfWeek(startOfMonth(date))
        let end = endOfWeek(endOfMonth(date))
        var dates: [Date] = []
        var current = start
        while current <= end {
            dates.append(current)
            current = calendar.date(byAdding: .day, value: Constants.oneDayComponent, to: current)!
        }
        DateUtilsAudit.record(
            operation: "daysOfMonthGrid",
            date: date,
            value: "\(dates.map { shortDate($0) })",
            tags: ["monthGrid", "dates"],
            actor: actor,
            context: context
        )
        return dates
    }

    // MARK: - Enhanced Utilities

    /// Returns true if two dates fall on the same calendar day (uses current calendar). Audit-logged.
    static func isSameDay(_ date1: Date, _ date2: Date, actor: String? = nil, context: String? = nil) -> Bool {
        let same = calendar.isDate(date1, inSameDayAs: date2)
        DateUtilsAudit.record(
            operation: "isSameDay",
            date: date1,
            date2: date2,
            value: "\(same)",
            tags: ["compare", "sameDay"],
            actor: actor,
            context: context
        )
        return same
    }

    /// Returns the ISO week number for a given date (1...53). Audit-logged.
    static func weekNumber(of date: Date, actor: String? = nil, context: String? = nil) -> Int {
        let week = calendar.component(.weekOfYear, from: date)
        DateUtilsAudit.record(
            operation: "weekNumber",
            date: date,
            value: "\(week)",
            tags: ["week", "number"],
            actor: actor,
            context: context
        )
        return week
    }

    /// Returns the number of days in the given date's month. Audit-logged.
    static func daysInMonth(_ date: Date, actor: String? = nil, context: String? = nil) -> Int {
        let range = calendar.range(of: .day, in: .month, for: date)
        let count = range?.count ?? 0
        DateUtilsAudit.record(
            operation: "daysInMonth",
            date: date,
            value: "\(count)",
            tags: ["month", "daysInMonth"],
            actor: actor,
            context: context
        )
        return count
    }

    /// Returns a concise, localized, human-friendly interval string for two dates (e.g. "Jun 1–3, 2025", "Today–Friday", "Yesterday–Today").
    /// Audit-logged. Full localization support.
    static func prettyInterval(from start: Date, to end: Date, actor: String? = nil, context: String? = nil) -> String {
        let cal = calendar
        let locale = Locale.current
        let df = DateFormatter()
        df.locale = locale

        // Helper: weekday name (e.g., "Monday")
        func weekdayString(_ date: Date) -> String {
            df.dateFormat = DateFormatter.dateFormat(fromTemplate: "EEEE", options: 0, locale: locale) ?? "EEEE"
            return df.string(from: date)
        }

        // Helper: short month + day (e.g., "Jun 1")
        func monthDay(_ date: Date) -> String {
            df.dateFormat = DateFormatter.dateFormat(fromTemplate: "MMM d", options: 0, locale: locale) ?? "MMM d"
            return df.string(from: date)
        }

        // Helper: short date with year (e.g., "Jun 1, 2025")
        func monthDayYear(_ date: Date) -> String {
            df.dateFormat = DateFormatter.dateFormat(fromTemplate: "MMM d, yyyy", options: 0, locale: locale) ?? "MMM d, yyyy"
            return df.string(from: date)
        }

        // Relative string (Today, Yesterday, Tomorrow, else nil)
        func relative(_ date: Date) -> String? {
            if cal.isDateInToday(date) { return NSLocalizedString("Today", comment: "Today label") }
            if cal.isDateInYesterday(date) { return NSLocalizedString("Yesterday", comment: "Yesterday label") }
            if cal.isDateInTomorrow(date) { return NSLocalizedString("Tomorrow", comment: "Tomorrow label") }
            return nil
        }

        // If same day
        if cal.isDate(start, inSameDayAs: end) {
            let rel = relative(start)
            let result = rel ?? monthDayYear(start)
            DateUtilsAudit.record(
                operation: "prettyInterval",
                date: start,
                date2: end,
                value: result,
                tags: ["interval", "pretty", "sameDay"],
                actor: actor,
                context: context
            )
            return result
        }

        // If both are relative (Today, Yesterday, Tomorrow)
        let relStart = relative(start)
        let relEnd = relative(end)
        if let relStart = relStart, let relEnd = relEnd {
            let result = "\(relStart)–\(relEnd)"
            DateUtilsAudit.record(
                operation: "prettyInterval",
                date: start,
                date2: end,
                value: result,
                tags: ["interval", "pretty", "relative-both"],
                actor: actor,
                context: context
            )
            return result
        }

        // If start is relative
        if let relStart = relStart {
            // If end is within 6 days, show weekday
            let days = cal.dateComponents([.day], from: start, to: end).day ?? 0
            if days < 7 && days > 0 {
                let result = "\(relStart)–\(weekdayString(end))"
                DateUtilsAudit.record(
                    operation: "prettyInterval",
                    date: start,
                    date2: end,
                    value: result,
                    tags: ["interval", "pretty", "relative-start"],
                    actor: actor,
                    context: context
                )
                return result
            }
        }

        // If end is relative
        if let relEnd = relEnd {
            let days = cal.dateComponents([.day], from: start, to: end).day ?? 0
            if days < 7 && days > 0 {
                let result = "\(weekdayString(start))–\(relEnd)"
                DateUtilsAudit.record(
                    operation: "prettyInterval",
                    date: start,
                    date2: end,
                    value: result,
                    tags: ["interval", "pretty", "relative-end"],
                    actor: actor,
                    context: context
                )
                return result
            }
        }

        // If same year
        let startYear = cal.component(.year, from: start)
        let endYear = cal.component(.year, from: end)
        if startYear == endYear {
            // If same month
            let startMonth = cal.component(.month, from: start)
            let endMonth = cal.component(.month, from: end)
            if startMonth == endMonth {
                // "Jun 1–3, 2025"
                df.dateFormat = DateFormatter.dateFormat(fromTemplate: "MMM", options: 0, locale: locale) ?? "MMM"
                let monthStr = df.string(from: start)
                let day1 = cal.component(.day, from: start)
                let day2 = cal.component(.day, from: end)
                let result = String(format: NSLocalizedString("%@ %d–%d, %d", comment: "Interval: Jun 1–3, 2025"), monthStr, day1, day2, startYear)
                DateUtilsAudit.record(
                    operation: "prettyInterval",
                    date: start,
                    date2: end,
                    value: result,
                    tags: ["interval", "pretty", "range-month"],
                    actor: actor,
                    context: context
                )
                return result
            } else {
                // "Jun 29 – Jul 2, 2025"
                let result = String(format: NSLocalizedString("%@ – %@, %d", comment: "Interval: Jun 29 – Jul 2, 2025"), monthDay(start), monthDay(end), startYear)
                DateUtilsAudit.record(
                    operation: "prettyInterval",
                    date: start,
                    date2: end,
                    value: result,
                    tags: ["interval", "pretty", "range-year"],
                    actor: actor,
                    context: context
                )
                return result
            }
        } else {
            // "Dec 31, 2024 – Jan 2, 2025"
            let result = String(format: NSLocalizedString("%@ – %@", comment: "Interval: Dec 31, 2024 – Jan 2, 2025"), monthDayYear(start), monthDayYear(end))
            DateUtilsAudit.record(
                operation: "prettyInterval",
                date: start,
                date2: end,
                value: result,
                tags: ["interval", "pretty", "range-multiyear"],
                actor: actor,
                context: context
            )
            return result
        }
    }
}

// MARK: - Audit/Admin Accessors

public enum DateUtilsAuditAdmin {
    public static var lastSummary: String { DateUtilsAudit.accessibilitySummary }
    public static var lastJSON: String? { DateUtilsAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        DateUtilsAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
}

// MARK: - LocalizedStringKey Extension

private extension LocalizedStringKey {
    var stringValue: String {
        Mirror(reflecting: self).children.first(where: { $0.label == "key" })?.value as? String ?? ""
    }
}

// MARK: - Sample Usage for Enhanced Utilities
/*
 // 1. isSameDay
 let same = DateUtils.isSameDay(Date(), Date()) // true

 // 2. weekNumber(of:)
 let week = DateUtils.weekNumber(of: Date()) // e.g. 23

 // 3. daysInMonth(_:)
 let days = DateUtils.daysInMonth(Date()) // e.g. 30

 // 4. prettyInterval(from:to:)
 let today = Date()
 let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
 let interval = DateUtils.prettyInterval(from: today, to: tomorrow) // e.g. "Today–Tomorrow"
*/

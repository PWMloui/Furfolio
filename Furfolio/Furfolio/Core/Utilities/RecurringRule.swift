//
//  RecurringRule.swift
//  Furfolio
//
//  Created by mac on 6/23/25.
//


import Foundation
import SwiftUI

/**
 RecurringRule
 -------------
 A model representing recurrence rules (similar to iCalendar RRULE) in Furfolio, with async analytics and audit logging.

 - **Purpose**: Defines frequency, interval, days, and date range for recurring events.
 - **Architecture**: Struct with methods to calculate next occurrences.
 - **Concurrency & Async Logging**: Key methods log analytics and audit via non-blocking Tasks.
 - **Audit/Analytics Ready**: Defines protocols and a dedicated audit manager actor.
 - **Diagnostics**: Exposes methods to fetch recent audit entries and export as JSON.
 */

// MARK: - Analytics & Audit Protocols

public protocol RecurringRuleAnalyticsLogger {
    /// Log a recurrence event asynchronously.
    func log(event: String, parameters: [String: Any]?) async
}

public protocol RecurringRuleAuditLogger {
    /// Record a recurrence audit entry asynchronously.
    func record(_ message: String, metadata: [String: String]?) async
}

public struct NullRecurringRuleAnalyticsLogger: RecurringRuleAnalyticsLogger {
    public init() {}
    public func log(event: String, parameters: [String : Any]?) async {}
}

public struct NullRecurringRuleAuditLogger: RecurringRuleAuditLogger {
    public init() {}
    public func record(_ message: String, metadata: [String : String]?) async {}
}

// MARK: - Audit Entry & Manager

/// A record of a recurring rule audit event.
public struct RecurringRuleAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let event: String
    public let detail: String?

    public init(id: UUID = UUID(), timestamp: Date = Date(), event: String, detail: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.event = event
        self.detail = detail
    }
}

/// Concurrency-safe actor for logging recurrence rule events.
public actor RecurringRuleAuditManager {
    private var buffer: [RecurringRuleAuditEntry] = []
    private let maxEntries = 200
    public static let shared = RecurringRuleAuditManager()

    public func add(_ entry: RecurringRuleAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    public func recent(limit: Int = 20) -> [RecurringRuleAuditEntry] {
        Array(buffer.suffix(limit))
    }

    public func exportJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(buffer),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }
}

// MARK: - Recurrence Model

public enum RecurrenceFrequency: String, Codable, CaseIterable {
    case daily, weekly, monthly, yearly
}

/// Defines a recurrence rule.
public struct RecurringRule: Codable, Equatable {
    public let frequency: RecurrenceFrequency
    public let interval: Int
    public let daysOfWeek: [Int]? // 1=Sunday...7=Saturday
    public let startDate: Date
    public let endDate: Date?

    private let analytics: RecurringRuleAnalyticsLogger
    private let audit: RecurringRuleAuditLogger

    public init(
        frequency: RecurrenceFrequency,
        interval: Int = 1,
        daysOfWeek: [Int]? = nil,
        startDate: Date,
        endDate: Date? = nil,
        analytics: RecurringRuleAnalyticsLogger = NullRecurringRuleAnalyticsLogger(),
        audit: RecurringRuleAuditLogger = NullRecurringRuleAuditLogger()
    ) {
        self.frequency = frequency
        self.interval = interval
        self.daysOfWeek = daysOfWeek
        self.startDate = startDate
        self.endDate = endDate
        self.analytics = analytics
        self.audit = audit

        Task {
            let detail = "\(frequency.rawValue), interval: \(interval)"
            await analytics.log(event: "rule_created", parameters: ["frequency": frequency.rawValue, "interval": interval])
            await audit.record("Rule created", metadata: ["detail": detail])
            await RecurringRuleAuditManager.shared.add(
                RecurringRuleAuditEntry(event: "rule_created", detail: detail)
            )
        }
    }

    /// Calculates the next occurrence after a given date.
    public func next(after date: Date) -> Date? {
        var nextDate: Date?
        switch frequency {
        case .daily:
            nextDate = Calendar.current.date(byAdding: .day, value: interval, to: date)
        case .weekly:
            nextDate = Calendar.current.date(byAdding: .weekOfYear, value: interval, to: date)
        case .monthly:
            nextDate = Calendar.current.date(byAdding: .month, value: interval, to: date)
        case .yearly:
            nextDate = Calendar.current.date(byAdding: .year, value: interval, to: date)
        }
        if let candidate = nextDate, let end = endDate, candidate > end {
            nextDate = nil
        }
        if let nd = nextDate {
            Task {
                await analytics.log(event: "next_computed", parameters: ["after": date.description, "next": nd.description])
                await audit.record("Next occurrence", metadata: ["next": nd.description])
                await RecurringRuleAuditManager.shared.add(
                    RecurringRuleAuditEntry(event: "next_computed", detail: nd.description)
                )
            }
        }
        return nextDate
    }

    /// Generates a sequence of occurrences starting from startDate.
    public func occurrences(count: Int) -> [Date] {
        var dates: [Date] = []
        var current = startDate
        for _ in 0..<count {
            if let nextDate = self.next(after: current) {
                dates.append(nextDate)
                current = nextDate
            } else {
                break
            }
        }
        Task {
            await analytics.log(event: "occurrences_generated", parameters: ["count": dates.count])
            await audit.record("Occurrences generated", metadata: ["count": "\(dates.count)"])
            await RecurringRuleAuditManager.shared.add(
                RecurringRuleAuditEntry(event: "occurrences_generated", detail: "\(dates.count)")
            )
        }
        return dates
    }
}

// MARK: - Diagnostics

public extension RecurringRule {
    /// Fetch recent recurrence audit entries.
    static func recentAuditEntries(limit: Int = 20) async -> [RecurringRuleAuditEntry] {
        await RecurringRuleAuditManager.shared.recent(limit: limit)
    }

    /// Export recurrence audit log as JSON.
    static func exportAuditLogJSON() async -> String {
        await RecurringRuleAuditManager.shared.exportJSON()
    }
}

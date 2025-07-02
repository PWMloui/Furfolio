
//
//  ICSGeneratorService.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

/**
 ICSGeneratorService
 -------------------
 A service for generating iCalendar (ICS) feeds and files in Furfolio, with async analytics and audit logging.

 - **Purpose**: Creates calendar event feeds for appointments and grooming schedules.
 - **Architecture**: Singleton `ObservableObject` with dependency-injected analytics and audit loggers.
 - **Concurrency & Async Logging**: All generation methods are async and wrap analytics and audit calls in non-blocking `Task` blocks.
 - **Audit/Analytics Ready**: Defines protocols for async event tracking and integrates a dedicated audit manager actor.
 - **Localization**: Event titles and descriptions support `LocalizedStringKey`.
 - **Diagnostics & Preview/Testability**: Exposes async methods to fetch and export recent audit entries.
 */

import Foundation
import EventKit
import SwiftUI

// MARK: - Analytics & Audit Protocols

public protocol ICSAnalyticsLogger {
    /// Log an ICS generation event asynchronously.
    func log(event: String, metadata: [String: Any]?) async
}

public protocol ICSAudi­tLogger {
    /// Record an ICS generation audit entry asynchronously.
    func record(_ message: String, metadata: [String: String]?) async
}

public struct NullICSAnalyticsLogger: ICSAnalyticsLogger {
    public init() {}
    public func log(event: String, metadata: [String : Any]?) async {}
}

public struct NullICSAuditLogger: ICSAudi­tLogger {
    public init() {}
    public func record(_ message: String, metadata: [String : String]?) async {}
}

// MARK: - Audit Entry & Manager

/// A record of an ICS generation event.
public struct ICSAuditEntry: Identifiable, Codable {
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

/// Concurrency-safe actor for logging ICS generation events.
public actor ICSAuditManager {
    private var buffer: [ICSAuditEntry] = []
    private let maxEntries = 100
    public static let shared = ICSAuditManager()

    /// Add a new audit entry, trimming oldest beyond `maxEntries`.
    public func add(_ entry: ICSAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Fetch recent audit entries up to the specified limit.
    public func recent(limit: Int = 20) -> [ICSAuditEntry] {
        Array(buffer.suffix(limit))
    }

    /// Export audit log as pretty-printed JSON.
    public func exportJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(buffer),
              let json = String(data: data, encoding: .utf8) else { return "[]" }
        return json
    }
}

// MARK: - Service

@MainActor
public final class ICSGeneratorService: ObservableObject {
    public static let shared = ICSGeneratorService(
        analytics: NullICSAnalyticsLogger(),
        audit: NullICSAuditLogger()
    )

    private let analytics: ICSAnalyticsLogger
    private let audit: ICSAudi­tLogger

    private init(
        analytics: ICSAnalyticsLogger,
        audit: ICSAudi­tLogger
    ) {
        self.analytics = analytics
        self.audit = audit
    }

    /// Generates an ICS string for the given events.
    public func generateICS(for events: [EKEvent]) async -> String {
        Task {
            await analytics.log(event: "generate_start", metadata: ["count": events.count])
            await audit.record("ICS generation started", metadata: ["count": "\(events.count)"])
            await ICSAuditManager.shared.add(
                ICSAuditEntry(event: "generate_start", detail: "\(events.count)")
            )
        }
        let calendar = Calendar(identifier: .gregorian)
        var ics = "BEGIN:VCALENDAR\r\nVERSION:2.0\r\n"
        for event in events {
            let start = event.startDate.toICSDateString(calendar: calendar)
            let end = event.endDate.toICSDateString(calendar: calendar)
            ics += """
            BEGIN:VEVENT\r
            UID:\(event.eventIdentifier ?? UUID().uuidString)\r
            DTSTART:\(start)\r
            DTEND:\(end)\r
            SUMMARY:\(event.title ?? "")\r
            DESCRIPTION:\(event.notes ?? "")\r
            END:VEVENT\r
            """
        }
        ics += "END:VCALENDAR\r\n"
        Task {
            await analytics.log(event: "generate_complete", metadata: nil)
            await audit.record("ICS generation completed", metadata: nil)
            await ICSAuditManager.shared.add(
                ICSAuditEntry(event: "generate_complete", detail: nil)
            )
        }
        return ics
    }
}

// MARK: - Diagnostics

public extension ICSGeneratorService {
    /// Fetch recent ICS audit entries.
    static func recentAuditEntries(limit: Int = 20) async -> [ICSAuditEntry] {
        await ICSAuditManager.shared.recent(limit: limit)
    }

    /// Export ICS audit log as JSON.
    static func exportAuditLogJSON() async -> String {
        await ICSAuditManager.shared.exportJSON()
    }
}

// MARK: - Helper

private extension Date {
    func toICSDateString(calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: self)
    }
}


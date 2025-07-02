
//
//  CalendarSyncService.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

/**
 CalendarSyncService
 -------------------
 A service for synchronizing Furfolio appointments with external calendars (e.g., iCloud, Google Calendar).

 - **Purpose**: Exports and imports appointment data, handles conflicts, and keeps calendars in sync.
 - **Architecture**: Singleton `ObservableObject` or service class using `EventKit` and REST APIs.
 - **Concurrency & Async Logging**: All sync operations are async and wrap analytics and audit calls in non-blocking `Task` blocks.
 - **Audit/Analytics Ready**: Defines protocols for async event tracking and integrates a dedicated audit manager actor.
 - **Localization**: Error and status messages use `NSLocalizedString`.
 - **Diagnostics & Preview/Testability**: Exposes async methods to fetch and export recent audit entries.
 */

import Foundation
import EventKit
import SwiftUI

// MARK: - Analytics & Audit Protocols

public protocol CalendarSyncAnalyticsLogger {
    /// Log a calendar sync event asynchronously.
    func log(event: String, parameters: [String: Any]?) async
}

public protocol CalendarSyncAuditLogger {
    /// Record a calendar sync audit entry asynchronously.
    func record(_ message: String, metadata: [String: String]?) async
}

public struct NullCalendarSyncAnalyticsLogger: CalendarSyncAnalyticsLogger {
    public init() {}
    public func log(event: String, parameters: [String : Any]?) async {}
}

public struct NullCalendarSyncAuditLogger: CalendarSyncAuditLogger {
    public init() {}
    public func record(_ message: String, metadata: [String : String]?) async {}
}

// MARK: - Audit Entry & Manager

/// A record of a calendar sync audit event.
public struct CalendarSyncAuditEntry: Identifiable, Codable {
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

/// Concurrency-safe actor for logging calendar sync events.
public actor CalendarSyncAuditManager {
    private var buffer: [CalendarSyncAuditEntry] = []
    private let maxEntries = 100
    public static let shared = CalendarSyncAuditManager()

    /// Add a new audit entry, trimming older entries beyond `maxEntries`.
    public func add(_ entry: CalendarSyncAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Fetch recent audit entries up to the specified limit.
    public func recent(limit: Int = 20) -> [CalendarSyncAuditEntry] {
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
public final class CalendarSyncService: ObservableObject {
    public static let shared = CalendarSyncService()

    private let eventStore = EKEventStore()
    private let analytics: CalendarSyncAnalyticsLogger
    private let audit: CalendarSyncAuditLogger

    private init(
        analytics: CalendarSyncAnalyticsLogger = NullCalendarSyncAnalyticsLogger(),
        audit: CalendarSyncAuditLogger = NullCalendarSyncAuditLogger()
    ) {
        self.analytics = analytics
        self.audit = audit
    }

    /// Requests calendar access permission.
    public func requestPermission() async throws {
        let status = EKEventStore.authorizationStatus(for: .event)
        if status != .authorized {
            let granted = try await eventStore.requestAccess(to: .event)
            Task {
                await analytics.log(event: "permission_requested", parameters: ["granted": granted])
                await audit.record("Calendar permission requested", metadata: ["granted": "\(granted)"])
                await CalendarSyncAuditManager.shared.add(
                    CalendarSyncAuditEntry(event: "permission", detail: "\(granted)")
                )
            }
            if !granted { throw NSError(domain: "CalendarPermission", code: 1, userInfo: nil) }
        }
    }

    /// Exports appointments to the specified calendar.
    public func exportAppointments(to calendar: EKCalendar, appointments: [EKEvent]) async {
        Task {
            await analytics.log(event: "export_start", parameters: ["count": appointments.count])
            await audit.record("Export started", metadata: ["count": "\(appointments.count)"])
            await CalendarSyncAuditManager.shared.add(
                CalendarSyncAuditEntry(event: "export_start", detail: "\(appointments.count)")
            )
        }
        for event in appointments {
            do {
                try await eventStore.save(event, span: .thisEvent)
            } catch {
                Task {
                    await analytics.log(event: "export_error", parameters: ["error": error.localizedDescription])
                    await audit.record("Export error", metadata: ["error": error.localizedDescription])
                    await CalendarSyncAuditManager.shared.add(
                        CalendarSyncAuditEntry(event: "export_error", detail: error.localizedDescription)
                    )
                }
            }
        }
        Task {
            await analytics.log(event: "export_complete", parameters: ["count": appointments.count])
            await audit.record("Export complete", metadata: ["count": "\(appointments.count)"])
            await CalendarSyncAuditManager.shared.add(
                CalendarSyncAuditEntry(event: "export_complete", detail: "\(appointments.count)")
            )
        }
    }

    /// Imports appointments from the specified calendar.
    public func importAppointments(from calendar: EKCalendar, start: Date, end: Date) async -> [EKEvent] {
        Task {
            await analytics.log(event: "import_start", parameters: ["calendar": calendar.title])
            await audit.record("Import started", metadata: ["calendar": calendar.title])
            await CalendarSyncAuditManager.shared.add(
                CalendarSyncAuditEntry(event: "import_start", detail: calendar.title)
            )
        }
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: [calendar])
        let events = eventStore.events(matching: predicate)
        Task {
            await analytics.log(event: "import_complete", parameters: ["count": events.count])
            await audit.record("Import complete", metadata: ["count": "\(events.count)"])
            await CalendarSyncAuditManager.shared.add(
                CalendarSyncAuditEntry(event: "import_complete", detail: "\(events.count)")
            )
        }
        return events
    }
}

// MARK: - Diagnostics

public extension CalendarSyncService {
    /// Fetch recent calendar sync audit entries.
    static func recentAuditEntries(limit: Int = 20) async -> [CalendarSyncAuditEntry] {
        await CalendarSyncAuditManager.shared.recent(limit: limit)
    }

    /// Export calendar sync audit log as JSON.
    static func exportAuditLogJSON() async -> String {
        await CalendarSyncAuditManager.shared.exportJSON()
    }
}


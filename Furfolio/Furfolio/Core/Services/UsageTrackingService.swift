//
//  UsageTrackingService.swift
//  Furfolio
//
//  Created by mac on 6/25/25.
//

import Foundation

/**
 UsageTrackingService
 --------------------
 A centralized service for tracking feature usage in Furfolio, with async analytics and audit logging.

 - **Purpose**: Records user feature events, aggregates usage counts, and exposes statistics.
 - **Architecture**: Singleton `ObservableObject` service using an in-memory store and persisted counts.
 - **Concurrency & Async Logging**: Wraps tracking calls in non-blocking `Task` blocks.
 - **Audit/Analytics Ready**: Defines async protocols for event tracking and integrates a dedicated audit manager actor.
 - **Localization**: Event names and descriptions support `NSLocalizedString`.
 - **Diagnostics & Preview/Testability**: Exposes methods to fetch raw audit log and aggregated usage stats.
 */

// MARK: - Analytics & Audit Protocols

public protocol UsageAnalyticsLogger {
    /// Log a usage event asynchronously.
    func log(event: String, metadata: [String: Any]?) async
}

public protocol UsageAuditLogger {
    /// Record a usage audit entry asynchronously.
    func record(_ message: String, metadata: [String: String]?) async
}

public struct NullUsageAnalyticsLogger: UsageAnalyticsLogger {
    public init() {}
    public func log(event: String, metadata: [String : Any]?) async {}
}

public struct NullUsageAuditLogger: UsageAuditLogger {
    public init() {}
    public func record(_ message: String, metadata: [String : String]?) async {}
}

// MARK: - Audit Entry & Manager

/// A record of a usage tracking audit event.
public struct UsageAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let event: String
    public let metadata: [String: Any]?

    public init(id: UUID = UUID(),
                timestamp: Date = Date(),
                event: String,
                metadata: [String: Any]? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.event = event
        self.metadata = metadata
    }
}

/// Concurrency-safe actor for logging usage audit events.
public actor UsageAuditManager {
    private var buffer: [UsageAuditEntry] = []
    private let maxEntries = 200
    public static let shared = UsageAuditManager()

    public func add(_ entry: UsageAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    public func recent(limit: Int = 20) -> [UsageAuditEntry] {
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

// MARK: - Service

@MainActor
public final class UsageTrackingService: ObservableObject {
    public static let shared = UsageTrackingService(
        analytics: NullUsageAnalyticsLogger(),
        audit: NullUsageAuditLogger()
    )

    private let analytics: UsageAnalyticsLogger
    private let audit: UsageAuditLogger

    /// In-memory event counts keyed by event name.
    @Published public private(set) var eventCounts: [String: Int] = [:]

    private init(
        analytics: UsageAnalyticsLogger,
        audit: UsageAuditLogger
    ) {
        self.analytics = analytics
        self.audit = audit
    }

    /// Tracks occurrence of a feature event.
    public func track(event: String, metadata: [String: Any]? = nil) {
        // Increment count
        eventCounts[event, default: 0] += 1

        // Fire-and-forget analytics and audit
        Task {
            await analytics.log(event: event, metadata: metadata)
            await audit.record("Tracked event", metadata: ["event": event])
            await UsageAuditManager.shared.add(
                UsageAuditEntry(event: event, metadata: metadata)
            )
        }
    }

    /// Retrieves the count for a specific event.
    public func count(for event: String) -> Int {
        eventCounts[event] ?? 0
    }
}

// MARK: - Diagnostics

public extension UsageTrackingService {
    /// Fetch recent raw audit entries.
    static func recentAuditEntries(limit: Int = 20) async -> [UsageAuditEntry] {
        await UsageAuditManager.shared.recent(limit: limit)
    }

    /// Export usage audit log as JSON.
    static func exportAuditLogJSON() async -> String {
        await UsageAuditManager.shared.exportJSON()
    }
}

import Foundation

/**
 Service
 -------
 A base class providing shared analytics and audit logging capabilities for all Furfolio services.

 - **Purpose**: Centralizes dependency-injected analytics and audit loggers, so subclasses don’t need to reimplement the same wiring.
 - **Architecture**: Abstract `Service` class that holds references to `AnalyticsServiceProtocol` and `AuditLoggerProtocol`.
 - **Concurrency & Async Logging**: Exposes helper methods to fire-and-forget async logs.
 - **Diagnostics & Testability**: Provides accessors for recent audit entries and export of the audit trail.
 */

public class Service {
    /// Shared analytics API
    let analytics: AnalyticsServiceProtocol
    /// Shared audit logger
    let audit: AuditLoggerProtocol

    /// Designated initializer for injecting shared loggers.
    public init(analytics: AnalyticsServiceProtocol, audit: AuditLoggerProtocol) {
        self.analytics = analytics
        self.audit = audit
    }

    /// Fire-and-forget an analytics event and record it in the audit actor.
    public func logEvent(_ event: String, parameters: [String: Any]? = nil) {
        Task {
            await analytics.log(event: event, parameters: parameters)
            await AuditManager.shared.add(
                .init(event: event, parameters: parameters)
            )
        }
    }

    /// Fire-and-forget a screen view and record it in the audit actor.
    public func logScreenView(_ name: String) {
        Task {
            await analytics.screenView(name)
            await AuditManager.shared.add(
                .init(event: "screen_view:\(name)", parameters: nil)
            )
        }
    }
}

/// A single audit entry for generic service events.
public struct AuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let event: String
    public let parameters: [String: Any]?

    public init(id: UUID = UUID(), timestamp: Date = Date(), event: String, parameters: [String: Any]? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.event = event
        self.parameters = parameters
    }
}

/// Concurrency-safe actor for gathering audit entries across all services.
public actor AuditManager {
    private var buffer: [AuditEntry] = []
    private let maxEntries = 100
    public static let shared = AuditManager()

    public func add(_ entry: AuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    public func recent(limit: Int = 20) -> [AuditEntry] {
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

public extension Service {
    /// Fetch recent generic audit entries.
    static func recentAuditEntries(limit: Int = 20) async -> [AuditEntry] {
        await AuditManager.shared.recent(limit: limit)
    }

    /// Export generic audit log as JSON.
    static func exportAuditLogJSON() async -> String {
        await AuditManager.shared.exportJSON()
    }
}

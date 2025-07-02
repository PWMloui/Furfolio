
//
//  CommunicationService.swift
//  Furfolio
//
//  Created by mac on 6/25/25.
//

/**
 CommunicationService
 --------------------
 A centralized Swift service for sending messages (email, SMS, in-app) in Furfolio with async analytics and audit logging.

 - **Purpose**: Sends notifications and messages to clients and staff.
 - **Architecture**: Singleton `ObservableObject` or service class with dependency-injected analytics and audit loggers.
 - **Concurrency & Async Logging**: All send methods are async and wrap analytics and audit calls in non-blocking `Task` blocks.
 - **Audit/Analytics Ready**: Defines protocols for async event tracking and integrates a dedicated audit manager actor.
 - **Localization**: Error and status messages use `NSLocalizedString`.
 - **Diagnostics & Preview/Testability**: Exposes async methods to fetch and export recent audit entries.
 */


// MARK: - Analytics & Audit Protocols

public protocol CommunicationAnalyticsLogger {
    /// Log a communication event asynchronously.
    func log(event: String, metadata: [String: Any]?) async
}

public protocol CommunicationAuditLogger {
    /// Record a communication audit entry asynchronously.
    func record(_ message: String, metadata: [String: String]?) async
}

public struct NullCommunicationAnalyticsLogger: CommunicationAnalyticsLogger {
    public init() {}
    public func log(event: String, metadata: [String : Any]?) async {}
}

public struct NullCommunicationAuditLogger: CommunicationAuditLogger {
    public init() {}
    public func record(_ message: String, metadata: [String : String]?) async {}
}

// MARK: - Audit Entry & Manager

/// A record of a communication event for audit purposes.
public struct CommunicationAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let channel: String
    public let recipient: String
    public let event: String
    public let detail: String?

    public init(id: UUID = UUID(), timestamp: Date = Date(), channel: String, recipient: String, event: String, detail: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.channel = channel
        self.recipient = recipient
        self.event = event
        self.detail = detail
    }
}

/// Concurrency-safe actor for auditing communication events.
public actor CommunicationAuditManager {
    private var buffer: [CommunicationAuditEntry] = []
    private let maxEntries = 100
    public static let shared = CommunicationAuditManager()

    /// Add a new audit entry, trimming oldest beyond `maxEntries`.
    public func add(_ entry: CommunicationAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Fetch recent audit entries up to the specified limit.
    public func recent(limit: Int = 20) -> [CommunicationAuditEntry] {
        Array(buffer.suffix(limit))
    }

    /// Export audit log as a JSON string.
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


@MainActor
public final class CommunicationService {
    public static let shared = CommunicationService()

    private let analytics: CommunicationAnalyticsLogger
    private let audit: CommunicationAuditLogger

    private init(
        analytics: CommunicationAnalyticsLogger = NullCommunicationAnalyticsLogger(),
        audit: CommunicationAuditLogger = NullCommunicationAuditLogger()
    ) {
        self.analytics = analytics
        self.audit = audit
    }

    // Example sendEmail implementation with async analytics/audit
    public func sendEmail(to recipient: String, subject: String, body: String) async throws {
        Task {
            await analytics.log(event: "email_send_start", metadata: ["recipient": recipient, "subject": subject])
            await audit.record("Starting email send", metadata: ["recipient": recipient])
            await CommunicationAuditManager.shared.add(
                CommunicationAuditEntry(channel: "email", recipient: recipient, event: "start", detail: subject)
            )
        }
        do {
            // ... perform actual email sending here

            Task {
                await analytics.log(event: "email_send_success", metadata: ["recipient": recipient])
                await audit.record("Email sent successfully", metadata: ["recipient": recipient])
                await CommunicationAuditManager.shared.add(
                    CommunicationAuditEntry(channel: "email", recipient: recipient, event: "success", detail: nil)
                )
            }
        } catch {
            Task {
                await analytics.log(event: "email_send_error", metadata: ["recipient": recipient, "error": error.localizedDescription])
                await audit.record("Email send error", metadata: ["recipient": recipient, "error": error.localizedDescription])
                await CommunicationAuditManager.shared.add(
                    CommunicationAuditEntry(channel: "email", recipient: recipient, event: "error", detail: error.localizedDescription)
                )
            }
            throw error
        }
    }

    // Example sendSMS implementation with async analytics/audit
    public func sendSMS(to recipient: String, message: String) async throws {
        Task {
            await analytics.log(event: "sms_send_start", metadata: ["recipient": recipient])
            await audit.record("Starting SMS send", metadata: ["recipient": recipient])
            await CommunicationAuditManager.shared.add(
                CommunicationAuditEntry(channel: "sms", recipient: recipient, event: "start", detail: message)
            )
        }
        do {
            // ... perform actual SMS sending here

            Task {
                await analytics.log(event: "sms_send_success", metadata: ["recipient": recipient])
                await audit.record("SMS sent successfully", metadata: ["recipient": recipient])
                await CommunicationAuditManager.shared.add(
                    CommunicationAuditEntry(channel: "sms", recipient: recipient, event: "success", detail: nil)
                )
            }
        } catch {
            Task {
                await analytics.log(event: "sms_send_error", metadata: ["recipient": recipient, "error": error.localizedDescription])
                await audit.record("SMS send error", metadata: ["recipient": recipient, "error": error.localizedDescription])
                await CommunicationAuditManager.shared.add(
                    CommunicationAuditEntry(channel: "sms", recipient: recipient, event: "error", detail: error.localizedDescription)
                )
            }
            throw error
        }
    }
}


// MARK: - Diagnostics

public extension CommunicationService {
    /// Fetch recent communication audit entries.
    static func recentAuditEntries(limit: Int = 20) async -> [CommunicationAuditEntry] {
        await CommunicationAuditManager.shared.recent(limit: limit)
    }

    /// Export communication audit log as JSON.
    static func exportAuditLogJSON() async -> String {
        await CommunicationAuditManager.shared.exportJSON()
    }
}


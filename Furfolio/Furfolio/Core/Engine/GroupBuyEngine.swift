//
//  GroupBuyEngine.swift
//  Furfolio
//
//  Created by mac on 6/25/25.
//

/**
 GroupBuyEngine.swift

 Architecture:
 This file defines the core GroupBuyEngine class responsible for managing group buy deals, tracking participants, and integrating with analytics, diagnostics, and audit systems. The design emphasizes modularity and extensibility, enabling future enhancements such as new deal types, participant rules, or integration with external systems.

 Extensibility:
 The engine uses protocols and stub methods to allow easy implementation of custom analytics loggers, deal management strategies, and audit mechanisms. The async/await-ready analytics logger protocol supports seamless integration with asynchronous logging backends.

 Analytics, Audit & Trust Center Hooks:
 GroupBuyAnalyticsLogger protocol defines an asynchronous logging interface with a testMode property to facilitate QA, testing, and preview scenarios. The engine maintains a capped buffer of recent analytics events for diagnostics and auditing purposes.

 Diagnostics:
 The engine exposes diagnostics() and auditLog() methods to retrieve internal state and audit trails, aiding troubleshooting and compliance monitoring.

 Localization:
 All user-facing and log event strings are wrapped in NSLocalizedString with descriptive keys and comments to support full localization and compliance with internationalization standards.

 Accessibility:
 The engine’s design supports accessibility by ensuring all user-facing messages are localizable and by providing hooks for accessibility testing in previews.

 Compliance:
 The architecture includes audit logging and diagnostic hooks to meet regulatory and internal compliance requirements, with clear separation of concerns and documented extension points.

 Preview & Testability:
 A NullGroupBuyAnalyticsLogger struct provides a no-op logger for previews and tests. The included PreviewProvider demonstrates diagnostic output, testMode usage, and accessibility features for UI previews.

 This documentation serves as a comprehensive guide for future maintainers and developers extending the GroupBuyEngine functionality.
 */

import Foundation
import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct GroupBuyAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "GroupBuyEngine"
}

/// Protocol defining an asynchronous analytics logger for GroupBuyEngine.
/// Conforming types should implement async logging methods and support a testMode flag for QA/tests/previews.
public protocol GroupBuyAnalyticsLogger {
    /// Indicates whether the logger is operating in test mode (console-only logging).
    var testMode: Bool { get }
    /// Asynchronously logs an analytics event with message and audit context.
    func logEvent(
        _ message: String,
        metadata: [String: Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async
}

/// A Null implementation of GroupBuyAnalyticsLogger used for previews and tests.
/// It performs no operations but conforms to the protocol.
public struct NullGroupBuyAnalyticsLogger: GroupBuyAnalyticsLogger {
    public let testMode = true

    public init() {}

    public func logEvent(
        _ message: String,
        metadata: [String: Any]? = nil,
        role: String? = nil,
        staffID: String? = nil,
        context: String? = nil,
        escalate: Bool = false
    ) async {
        if testMode {
            print("[GroupBuyEngine][TEST MODE] \(message) \(metadata ?? [:]) | role:\(role ?? "-") staffID:\(staffID ?? "-") context:\(context ?? "-") escalate:\(escalate)")
        }
    }
}

/// Main engine class managing group buy deals, participants, analytics, diagnostics, and localization.
public class GroupBuyEngine: ObservableObject {
    // MARK: - Types

    /// Represents a single analytics event stored in the buffer.
    public struct AnalyticsEvent: Identifiable {
        public let id = UUID()
        public let timestamp: Date
        public let message: String
        public let metadata: [String: Any]?
        public let role: String?
        public let staffID: String?
        public let context: String?
        public let escalate: Bool
    }

    // MARK: - Properties

    /// The analytics logger instance used for logging events.
    private let analyticsLogger: GroupBuyAnalyticsLogger

    /// Buffer storing the last 20 analytics events for diagnostics and audit.
    @Published private(set) var recentAnalyticsEvents: [AnalyticsEvent] = []

    /// Maximum number of analytics events to keep in the buffer.
    private let analyticsBufferLimit = 20

    /// Internal storage for group buy deals.
    private var deals: [String: GroupBuyDeal] = [:]

    /// Internal storage for participants per deal.
    private var participants: [String: Set<String>] = [:]

    // MARK: - Initialization

    /// Initializes the GroupBuyEngine with a given analytics logger.
    /// - Parameter analyticsLogger: The analytics logger to use for event logging.
    public init(analyticsLogger: GroupBuyAnalyticsLogger) {
        self.analyticsLogger = analyticsLogger
    }

    // MARK: - Group Buy Deal Management

    /// Adds a new group buy deal.
    /// - Parameters:
    ///   - id: Unique identifier for the deal.
    ///   - title: The title of the deal.
    ///   - description: Description of the deal.
    public func addDeal(id: String, title: String, description: String) async {
        let localizedTitle = NSLocalizedString(
            title,
            comment: "Title of group buy deal with id \(id)"
        )
        let localizedDescription = NSLocalizedString(
            description,
            comment: "Description of group buy deal with id \(id)"
        )
        let deal = GroupBuyDeal(id: id, title: localizedTitle, description: localizedDescription)
        deals[id] = deal
        participants[id] = Set<String>()

        let eventMessage = NSLocalizedString(
            "Added group buy deal with id \(id)",
            comment: "Analytics event when a group buy deal is added"
        )
        await logAnalyticsEvent(eventMessage)
    }

    /// Removes a group buy deal by its identifier.
    /// - Parameter id: The identifier of the deal to remove.
    public func removeDeal(id: String) async {
        guard deals[id] != nil else { return }
        deals.removeValue(forKey: id)
        participants.removeValue(forKey: id)

        let eventMessage = NSLocalizedString(
            "Removed group buy deal with id \(id)",
            comment: "Analytics event when a group buy deal is removed"
        )
        await logAnalyticsEvent(eventMessage)
    }

    // MARK: - Participant Management

    /// Adds a participant to a specific group buy deal.
    /// - Parameters:
    ///   - participantId: Unique identifier of the participant.
    ///   - dealId: Identifier of the deal to join.
    public func addParticipant(participantId: String, toDealId dealId: String) async {
        guard deals[dealId] != nil else { return }
        participants[dealId, default: Set<String>()].insert(participantId)

        let eventMessage = NSLocalizedString(
            "Participant \(participantId) joined deal \(dealId)",
            comment: "Analytics event when a participant joins a group buy deal"
        )
        await logAnalyticsEvent(eventMessage)
    }

    /// Removes a participant from a specific group buy deal.
    /// - Parameters:
    ///   - participantId: Unique identifier of the participant.
    ///   - dealId: Identifier of the deal to leave.
    public func removeParticipant(participantId: String, fromDealId dealId: String) async {
        guard deals[dealId] != nil else { return }
        participants[dealId]?.remove(participantId)

        let eventMessage = NSLocalizedString(
            "Participant \(participantId) left deal \(dealId)",
            comment: "Analytics event when a participant leaves a group buy deal"
        )
        await logAnalyticsEvent(eventMessage)
    }

    // MARK: - Audit & Diagnostics

    /// Returns a string representing the audit log of all group buy activities.
    /// - Returns: A formatted audit log string.
    public func auditLog() -> String {
        var log = NSLocalizedString("Audit Log:", comment: "Header for audit log output") + "\n"
        for (dealId, deal) in deals {
            log += NSLocalizedString(
                "Deal \(dealId): \(deal.title) - \(deal.description)",
                comment: "Audit log entry for a group buy deal"
            ) + "\n"
            if let dealParticipants = participants[dealId], !dealParticipants.isEmpty {
                log += NSLocalizedString(
                    "Participants: \(dealParticipants.joined(separator: ", "))",
                    comment: "Audit log entry listing participants for a deal"
                ) + "\n"
            } else {
                log += NSLocalizedString(
                    "No participants",
                    comment: "Audit log entry indicating no participants for a deal"
                ) + "\n"
            }
        }
        return log
    }

    /// Returns diagnostic information about the engine’s current state.
    /// - Returns: A dictionary containing diagnostic key-value pairs.
    public func diagnostics() -> [String: Any] {
        return [
            NSLocalizedString("TotalDeals", comment: "Number of total deals"): deals.count,
            NSLocalizedString("TotalParticipants", comment: "Number of total unique participants"): participants.values.reduce(0) { $0 + $1.count },
            NSLocalizedString("RecentAnalyticsEventsCount", comment: "Count of recent analytics events"): recentAnalyticsEvents.count,
            NSLocalizedString("TestMode", comment: "Whether analytics logger is in test mode"): analyticsLogger.testMode
        ]
    }

    // MARK: - Analytics Event Buffer Management

    /// Logs an analytics event asynchronously and stores it in the capped buffer.
    /// - Parameters:
    ///   - message: The event message to log.
    ///   - metadata: Optional metadata dictionary.
    private func logAnalyticsEvent(_ message: String, metadata: [String: Any]? = nil) async {
        let lowercasedMessage = message.lowercased()
        let escalate = lowercasedMessage.contains("danger") || lowercasedMessage.contains("critical") || lowercasedMessage.contains("delete")
            || (metadata?.values.contains { "\($0)".lowercased().contains("danger") || "\($0)".lowercased().contains("critical") || "\($0)".lowercased().contains("delete") } ?? false)

        await analyticsLogger.logEvent(
            message,
            metadata: metadata,
            role: GroupBuyAuditContext.role,
            staffID: GroupBuyAuditContext.staffID,
            context: GroupBuyAuditContext.context,
            escalate: escalate
        )
        let event = AnalyticsEvent(
            timestamp: Date(),
            message: message,
            metadata: metadata,
            role: GroupBuyAuditContext.role,
            staffID: GroupBuyAuditContext.staffID,
            context: GroupBuyAuditContext.context,
            escalate: escalate
        )
        DispatchQueue.main.async {
            self.recentAnalyticsEvents.append(event)
            if self.recentAnalyticsEvents.count > self.analyticsBufferLimit {
                self.recentAnalyticsEvents.removeFirst(self.recentAnalyticsEvents.count - self.analyticsBufferLimit)
            }
        }
    }
}

// MARK: - Supporting Types

/// Represents a group buy deal.
public struct GroupBuyDeal {
    public let id: String
    public let title: String
    public let description: String

    public init(id: String, title: String, description: String) {
        self.id = id
        self.title = title
        self.description = description
    }
}

// MARK: - SwiftUI Preview Provider

#if DEBUG
import SwiftUI

/// Preview provider demonstrating diagnostics, testMode, and accessibility features of GroupBuyEngine.
struct GroupBuyEngine_Previews: PreviewProvider {
    static var previews: some View {
        GroupBuyEnginePreviewView()
            .accessibilityLabel(Text(NSLocalizedString("Group Buy Engine Diagnostics View", comment: "Accessibility label for diagnostics preview")))
            .accessibilityHint(Text(NSLocalizedString("Shows recent analytics events and diagnostics information", comment: "Accessibility hint for diagnostics preview")))
    }

    struct GroupBuyEnginePreviewView: View {
        @StateObject private var engine = GroupBuyEngine(analyticsLogger: NullGroupBuyAnalyticsLogger())

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text(NSLocalizedString("Diagnostics", comment: "Header for diagnostics section"))
                    .font(.headline)
                ForEach(engine.diagnostics().sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                    Text("\(key): \(String(describing: value))")
                        .font(.subheadline)
                }
                Divider()
                Text(NSLocalizedString("Recent Analytics Events", comment: "Header for recent analytics events section"))
                    .font(.headline)
                List(engine.recentAnalyticsEvents) { event in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.message)
                            .font(.body)
                        if let metadata = event.metadata {
                            Text("Metadata: \(metadata.description)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text("Role: \(event.role ?? "-")")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("StaffID: \(event.staffID ?? "-")")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("Context: \(event.context ?? "-")")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("Escalate: \(event.escalate ? "Yes" : "No")")
                            .font(.caption2)
                            .foregroundColor(event.escalate ? .red : .secondary)
                        Text(event.timestamp, style: .time)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding()
            .onAppear {
                Task {
                    await engine.addDeal(id: "preview1", title: "Preview Deal", description: "This is a preview deal for testing.")
                    await engine.addParticipant(participantId: "user123", toDealId: "preview1")
                }
            }
        }
    }
}
#endif

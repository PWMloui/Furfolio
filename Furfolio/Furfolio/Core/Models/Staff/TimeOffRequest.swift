//
//  TimeOffRequest.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//


/**
 TimeOffRequest
 --------------
 A model representing a time-off request by a staff member in Furfolio.

 - **Architecture**: Struct conforming to Identifiable and Codable for SwiftUI and networking.
 - **Concurrency & Audit**: Provides async audit logging via `TimeOffRequestAuditManager` actor.
 - **Localization**: Date formatting and status display use NSLocalizedString for i18n.
 - **Accessibility**: Computed properties expose VoiceOver-friendly labels.
 - **Preview/Testability**: Includes SwiftUI preview demonstrating creation, status changes, and audit entries.
 */

import Foundation
import SwiftUI

public enum RequestStatus: String, Codable, CaseIterable, Identifiable {
    public var id: String { rawValue }
    case pending, approved, denied

    /// Localized display name
    public var displayName: String {
        switch self {
        case .pending: return NSLocalizedString("Pending", comment: "Time off status")
        case .approved: return NSLocalizedString("Approved", comment: "Time off status")
        case .denied: return NSLocalizedString("Denied", comment: "Time off status")
        }
    }

    /// Accessibility label
    public var accessibilityLabel: Text {
        Text(displayName)
    }
}

public struct TimeOffRequest: Identifiable, Codable {
    public let id: UUID
    /// The staff member’s identifier
    public var staffId: UUID
    /// Start of requested time off
    public var startDate: Date
    /// End of requested time off
    public var endDate: Date
    /// Reason for the request
    public var reason: String
    /// Current status
    public var status: RequestStatus
    public let createdAt: Date
    public var updatedAt: Date

    /// Formatted start date
    public var displayStart: String {
        DateFormatter.localizedString(from: startDate, dateStyle: .medium, timeStyle: .short)
    }
    /// Formatted end date
    public var displayEnd: String {
        DateFormatter.localizedString(from: endDate, dateStyle: .medium, timeStyle: .short)
    }
    /// Accessibility label combining fields
    public var accessibilityLabel: Text {
        Text(String(format: NSLocalizedString("Time off from %@ to %@: %@", comment: "Accessibility label"),
                    displayStart, displayEnd, reason))
    }

    /// Creates a new TimeOffRequest
    public init(id: UUID = UUID(),
                staffId: UUID,
                startDate: Date,
                endDate: Date,
                reason: String,
                status: RequestStatus = .pending) {
        self.id = id
        self.staffId = staffId
        self.startDate = startDate
        self.endDate = endDate
        self.reason = NSLocalizedString(reason, comment: "Time off reason")
        self.status = status
        let now = Date()
        self.createdAt = now
        self.updatedAt = now

        // Log creation
        Task {
            await TimeOffRequestAuditManager.shared.add(
                TimeOffRequestAuditEntry(requestId: id, event: NSLocalizedString("Request created", comment: "")))
        }
    }
}

/// A record of a TimeOffRequest audit event.
public struct TimeOffRequestAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let requestId: UUID
    public let event: String

    public init(id: UUID = UUID(), timestamp: Date = Date(), requestId: UUID, event: String) {
        self.id = id
        self.timestamp = timestamp
        self.requestId = requestId
        self.event = event
    }
}

/// Manages concurrency-safe audit logging for time-off requests.
public actor TimeOffRequestAuditManager {
    private var buffer: [TimeOffRequestAuditEntry] = []
    private let maxEntries = 100
    public static let shared = TimeOffRequestAuditManager()

    /// Add a new audit entry, capping to maxEntries
    public func add(_ entry: TimeOffRequestAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Fetch recent audit entries
    public func recent(limit: Int = 20) -> [TimeOffRequestAuditEntry] {
        Array(buffer.suffix(limit))
    }

    /// Export audit log as JSON
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

public extension TimeOffRequest {
    /// Record an audit event
    func addAudit(_ event: String) async {
        updatedAt = Date()
        let localized = NSLocalizedString(event, comment: "")
        await TimeOffRequestAuditManager.shared.add(
            TimeOffRequestAuditEntry(requestId: id, event: localized)
        )
    }

    /// Change status and log
    mutating func updateStatus(to newStatus: RequestStatus) async {
        status = newStatus
        updatedAt = Date()
        await addAudit("Status changed to \(newStatus.rawValue)")
    }

    /// Fetch recent audit entries
    func recentAuditEntries(limit: Int = 20) async -> [TimeOffRequestAuditEntry] {
        await TimeOffRequestAuditManager.shared.recent(limit: limit)
    }

    /// Export audit log JSON
    func exportAuditLogJSON() async -> String {
        await TimeOffRequestAuditManager.shared.exportJSON()
    }
}

#if DEBUG
import SwiftUI

struct TimeOffRequest_Previews: PreviewProvider {
    static var previews: some View {
        var request = TimeOffRequest(
            staffId: UUID(),
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600 * 24),
            reason: "Vacation"
        )
        VStack(spacing: 12) {
            Text(request.displayStart)
            Text(request.displayEnd)
            Text(request.reason)
            Text(request.status.displayName)
            Button("Approve") {
                Task {
                    await request.updateStatus(to: .approved)
                    let logs = await request.recentAuditEntries(limit: 5)
                    print(logs)
                }
            }
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(request.accessibilityLabel)
    }
}
#endif

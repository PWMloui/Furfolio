//
//  BookingRequest.swift
//  Furfolio
//
//  Created by mac on 6/25/25.
//


import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - BookingRequestAuditEvent: Represents a single audit event for a booking request.
/// Audit event for booking request operations.
struct BookingRequestAuditEvent: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let operation: String // e.g. "create", "approve", "reject", "cancel", "modify"
    let requestID: String
    let ownerName: String
    let dogName: String
    let requestedDate: Date
    let status: String
    let tags: [String]
    let actor: String // Who performed the operation
    let context: String // e.g. "user", "admin", etc.
    let detail: String // Additional details or reason
    
    init(
        operation: String,
        requestID: String,
        ownerName: String,
        dogName: String,
        requestedDate: Date,
        status: String,
        tags: [String],
        actor: String,
        context: String,
        detail: String
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.operation = operation
        self.requestID = requestID
        self.ownerName = ownerName
        self.dogName = dogName
        self.requestedDate = requestedDate
        self.status = status
        self.tags = tags
        self.actor = actor
        self.context = context
        self.detail = detail
    }
}

// MARK: - BookingRequestAudit: Singleton logger for booking request events.
/// Audit log for booking request operations. Provides analytics and event storage.
class BookingRequestAudit {
    static let shared = BookingRequestAudit()
    
    private(set) var events: [BookingRequestAuditEvent] = []
    private let queue = DispatchQueue(label: "BookingRequestAudit.queue")
    
    private init() {}
    
    /// Log a new audit event.
    func log(
        operation: String,
        requestID: String,
        ownerName: String,
        dogName: String,
        requestedDate: Date,
        status: String,
        tags: [String],
        actor: String,
        context: String,
        detail: String
    ) {
        let event = BookingRequestAuditEvent(
            operation: operation,
            requestID: requestID,
            ownerName: ownerName,
            dogName: dogName,
            requestedDate: requestedDate,
            status: status,
            tags: tags,
            actor: actor,
            context: context,
            detail: detail
        )
        queue.sync {
            events.append(event)
            // Limit to last 500 events for memory safety
            if events.count > 500 {
                events.removeFirst(events.count - 500)
            }
        }
        // Accessibility: Announce event for VoiceOver users if relevant
        if ["create", "approve", "reject", "cancel"].contains(operation) {
            BookingRequestAudit.announceEvent(event)
        }
    }
    
    /// VoiceOver announcement for key booking events.
    private static func announceEvent(_ event: BookingRequestAuditEvent) {
#if os(iOS)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let dateString = formatter.string(from: event.requestedDate)
        var message = ""
        switch event.operation {
        case "create":
            message = "Booking for \(event.dogName) requested for \(dateString)."
        case "approve":
            message = "Booking for \(event.dogName) approved for \(dateString)."
        case "reject":
            message = "Booking for \(event.dogName) was rejected for \(dateString)."
        case "cancel":
            message = "Booking for \(event.dogName) was cancelled for \(dateString)."
        default:
            break
        }
        if !message.isEmpty {
            DispatchQueue.main.async {
                UIAccessibility.post(notification: .announcement, argument: message)
            }
        }
#endif
    }
    
    // MARK: - Analytics
    /// Total number of requests logged.
    static var totalRequests: Int {
        return shared.queue.sync { shared.events.count }
    }
    /// Number of requests with status "pending".
    static var pendingRequests: Int {
        return shared.queue.sync { shared.events.filter { $0.status.lowercased() == "pending" }.count }
    }
    /// Number of requests with status "approved".
    static var approvedRequests: Int {
        return shared.queue.sync { shared.events.filter { $0.status.lowercased() == "approved" }.count }
    }
    /// Number of requests with status "rejected".
    static var rejectedRequests: Int {
        return shared.queue.sync { shared.events.filter { $0.status.lowercased() == "rejected" }.count }
    }
}

// MARK: - BookingRequestAuditAdmin: Public admin utility for audit log.
/// Provides summary, export, and access to recent audit events.
public class BookingRequestAuditAdmin {
    public static var lastSummary: String {
        guard let event = BookingRequestAudit.shared.queue.sync(execute: { BookingRequestAudit.shared.events.last }) else {
            return "No audit events."
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let dateString = formatter.string(from: event.timestamp)
        return "[\(dateString)] \(event.operation.capitalized) (\(event.status)) for \(event.dogName) (\(event.ownerName)) by \(event.actor): \(event.detail)"
    }
    
    public static var lastJSON: String {
        guard let event = BookingRequestAudit.shared.queue.sync(execute: { BookingRequestAudit.shared.events.last }) else {
            return ""
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(event), let str = String(data: data, encoding: .utf8) {
            return str
        }
        return ""
    }
    
    public static func recentEvents(limit: Int = 10) -> [BookingRequestAuditEvent] {
        return BookingRequestAudit.shared.queue.sync {
            let events = BookingRequestAudit.shared.events
            return Array(events.suffix(limit))
        }
    }
    
    /// Export all events to CSV format.
    public static func exportCSV() -> String {
        let header = "timestamp,operation,requestID,ownerName,dogName,requestedDate,status,tags,actor,context,detail"
        let formatter = ISO8601DateFormatter()
        let rows: [String] = BookingRequestAudit.shared.queue.sync {
            BookingRequestAudit.shared.events.map { event in
                let fields: [String] = [
                    formatter.string(from: event.timestamp),
                    event.operation,
                    event.requestID,
                    event.ownerName,
                    event.dogName,
                    formatter.string(from: event.requestedDate),
                    event.status,
                    event.tags.joined(separator: ";"),
                    event.actor,
                    event.context,
                    event.detail.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: ",", with: ";")
                ]
                return fields.map { "\"\($0)\"" }.joined(separator: ",")
            }
        }
        return ([header] + rows).joined(separator: "\n")
    }
}

#if DEBUG
// MARK: - BookingRequestAuditSummaryView: SwiftUI overlay for development/debugging.
/// SwiftUI overlay showing recent audit events and request analytics (DEBUG only).
@available(iOS 13.0, *)
struct BookingRequestAuditSummaryView: View {
    @State private var events: [BookingRequestAuditEvent] = []
    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Booking Audit Summary")
                .font(.headline)
            HStack {
                Text("Total: \(BookingRequestAudit.totalRequests)")
                Text("Pending: \(BookingRequestAudit.pendingRequests)")
                Text("Approved: \(BookingRequestAudit.approvedRequests)")
                Text("Rejected: \(BookingRequestAudit.rejectedRequests)")
            }
            .font(.subheadline)
            Divider()
            ForEach(events) { event in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(event.operation.capitalized): \(event.dogName) (\(event.status))")
                        .bold()
                    Text("By \(event.actor) on \(event.ownerName)")
                        .font(.caption)
                    Text(event.detail)
                        .font(.caption2)
                }
                .padding(.vertical, 2)
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.95))
        .cornerRadius(12)
        .onAppear(perform: reload)
        .onReceive(timer) { _ in reload() }
        .shadow(radius: 4)
        .padding()
    }
    private func reload() {
        events = BookingRequestAuditAdmin.recentEvents(limit: 3).reversed()
    }
}
#endif

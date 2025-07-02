
//  BookingRequestListView.swift
//  Furfolio
//
//  Created by mac on 6/25/25.
//

import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Audit Event Model
/// Represents an audit event for booking request list operations.
struct BookingRequestListAuditEvent: Codable, Identifiable {
    /// Unique identifier for the event (UUID).
    let id: String
    /// ISO8601 timestamp of the event.
    let timestamp: String
    /// Operation type (e.g., "load", "filter", "tap", "approve", "reject", "cancel", "exportCSV").
    let operation: String
    /// The booking request's unique ID (if applicable).
    let requestID: String?
    /// Owner's name (if applicable).
    let ownerName: String?
    /// Dog's name (if applicable).
    let dogName: String?
    /// The date requested (if applicable).
    let requestedDate: String?
    /// Current request status (if applicable).
    let status: String?
    /// Current filter applied (if applicable).
    let filter: String?
    /// Tags associated with the request (if applicable).
    let tags: [String]?
    /// The user/actor performing the action (if applicable).
    let actor: String?
    /// Context (e.g., "list", "detail", etc).
    let context: String?
    /// Additional details, if any.
    let detail: String?
    
    /// Convenience initializer for most operations.
    init(
        operation: String,
        requestID: String? = nil,
        ownerName: String? = nil,
        dogName: String? = nil,
        requestedDate: String? = nil,
        status: String? = nil,
        filter: String? = nil,
        tags: [String]? = nil,
        actor: String? = nil,
        context: String? = nil,
        detail: String? = nil
    ) {
        self.id = UUID().uuidString
        self.timestamp = ISO8601DateFormatter().string(from: Date())
        self.operation = operation
        self.requestID = requestID
        self.ownerName = ownerName
        self.dogName = dogName
        self.requestedDate = requestedDate
        self.status = status
        self.filter = filter
        self.tags = tags
        self.actor = actor
        self.context = context
        self.detail = detail
    }
}

// MARK: - Audit Logger
/// Singleton logger for booking request list audit events.
final class BookingRequestListAudit {
    /// Shared singleton instance.
    static let shared = BookingRequestListAudit()
    
    /// Internal event storage.
    private(set) var events: [BookingRequestListAuditEvent] = []
    
    /// Serial queue for thread-safety.
    private let queue = DispatchQueue(label: "BookingRequestListAudit.queue")
    
    private init() { }
    
    /// Log a new audit event.
    func log(_ event: BookingRequestListAuditEvent) {
        queue.sync {
            events.append(event)
            // Keep only the last 500 events for memory.
            if events.count > 500 {
                events = Array(events.suffix(500))
            }
        }
    }
    
    /// Get recent events (most recent first).
    func recentEvents(limit: Int = 10) -> [BookingRequestListAuditEvent] {
        queue.sync {
            Array(events.suffix(limit)).reversed()
        }
    }
    
    /// Export all events as CSV string.
    func exportCSV() -> String {
        let header = [
            "timestamp","operation","requestID","ownerName","dogName","requestedDate","status","filter","tags","actor","context","detail"
        ]
        var rows = [header.joined(separator: ",")]
        for e in queue.sync(execute: { events }) {
            let tagsString = e.tags?.joined(separator: ";") ?? ""
            let row: [String] = [
                e.timestamp,
                e.operation,
                e.requestID ?? "",
                e.ownerName ?? "",
                e.dogName ?? "",
                e.requestedDate ?? "",
                e.status ?? "",
                e.filter ?? "",
                tagsString,
                e.actor ?? "",
                e.context ?? "",
                e.detail ?? ""
            ].map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }
            rows.append(row.joined(separator: ","))
        }
        return rows.joined(separator: "\n")
    }
    
    // MARK: - Analytics
    /// Total requests (from audit events with requestID).
    static var totalRequests: Int {
        shared.queue.sync {
            Set(shared.events.compactMap { $0.requestID }).count
        }
    }
    /// Total pending requests (status == "pending").
    static var pendingRequests: Int {
        shared.queue.sync {
            Set(shared.events.filter { $0.status?.lowercased() == "pending" }.compactMap { $0.requestID }).count
        }
    }
    /// Total approved requests (status == "approved").
    static var approvedRequests: Int {
        shared.queue.sync {
            Set(shared.events.filter { $0.status?.lowercased() == "approved" }.compactMap { $0.requestID }).count
        }
    }
    /// Total rejected requests (status == "rejected").
    static var rejectedRequests: Int {
        shared.queue.sync {
            Set(shared.events.filter { $0.status?.lowercased() == "rejected" }.compactMap { $0.requestID }).count
        }
    }
}

// MARK: - Audit Admin API
/// Public admin API for accessing audit events and exporting data.
public class BookingRequestListAuditAdmin {
    /// Last summary string (last event, or "No events").
    public static var lastSummary: String {
        guard let last = BookingRequestListAudit.shared.recentEvents(limit: 1).first else {
            return "No events"
        }
        return "[\(last.operation)] \(last.ownerName ?? "-") / \(last.dogName ?? "-") at \(last.timestamp)"
    }
    /// Last event as JSON string.
    public static var lastJSON: String {
        guard let last = BookingRequestListAudit.shared.recentEvents(limit: 1).first else {
            return "{}"
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(last), let json = String(data: data, encoding: .utf8) {
            return json
        }
        return "{}"
    }
    /// Get recent events (limit: Int).
    public static func recentEvents(limit: Int = 10) -> [BookingRequestListAuditEvent] {
        BookingRequestListAudit.shared.recentEvents(limit: limit)
    }
    /// Export all events as CSV string.
    public static func exportCSV() -> String {
        BookingRequestListAudit.shared.exportCSV()
    }
}

#if DEBUG
// MARK: - DEV Overlay View
/// Shows last 3 audit events and request counts as a developer overlay.
struct BookingRequestListAuditSummaryView: View {
    @State private var events: [BookingRequestListAuditEvent] = []
    @State private var timer: Timer?
    
    private func updateEvents() {
        events = BookingRequestListAudit.shared.recentEvents(limit: 3)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("🔍 Booking List Audit")
                .font(.headline)
            HStack(spacing: 8) {
                Text("Total: \(BookingRequestListAudit.totalRequests)")
                Text("Pending: \(BookingRequestListAudit.pendingRequests)")
                Text("Approved: \(BookingRequestListAudit.approvedRequests)")
                Text("Rejected: \(BookingRequestListAudit.rejectedRequests)")
            }
            .font(.caption)
            ForEach(events) { e in
                Text("\(e.timestamp.suffix(8)) [\(e.operation)] \(e.ownerName ?? "-")/\(e.dogName ?? "-") (\(e.status ?? "-"))")
                    .font(.caption2)
            }
        }
        .padding(8)
        .background(Color(.systemGray6).opacity(0.95))
        .cornerRadius(10)
        .shadow(radius: 2)
        .onAppear {
            updateEvents()
            timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                updateEvents()
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}
#endif

// MARK: - Accessibility Helper
/// Posts a VoiceOver accessibility announcement (iOS only).
func postBookingListAccessibilityAnnouncement(_ message: String) {
#if canImport(UIKit)
    UIAccessibility.post(notification: .announcement, argument: message)
#endif
}

// MARK: - Example Integration in BookingRequestListView
/// NOTE: Integrate the following patterns at the appropriate places in your BookingRequestListView logic:
/*
// Example: When the list loads
let event = BookingRequestListAuditEvent(
    operation: "load",
    filter: currentFilter,
    actor: currentUserName,
    context: "list",
    detail: "Loaded booking requests"
)
BookingRequestListAudit.shared.log(event)
postBookingListAccessibilityAnnouncement("Booking requests loaded. \(BookingRequestListAudit.totalRequests) total.")

// Example: When a filter is applied
let event = BookingRequestListAuditEvent(
    operation: "filter",
    filter: selectedFilter,
    actor: currentUserName,
    context: "list",
    detail: "Filter applied"
)
BookingRequestListAudit.shared.log(event)
postBookingListAccessibilityAnnouncement("Filter applied: \(selectedFilter)")

// Example: When a request is tapped
let event = BookingRequestListAuditEvent(
    operation: "tap",
    requestID: req.id,
    ownerName: req.owner,
    dogName: req.dog,
    requestedDate: req.dateString,
    status: req.status,
    actor: currentUserName,
    context: "list",
    detail: "Tapped request"
)
BookingRequestListAudit.shared.log(event)
postBookingListAccessibilityAnnouncement("Tapped request for \(req.owner)'s \(req.dog)")

// Example: When a request is approved/rejected/canceled
let event = BookingRequestListAuditEvent(
    operation: "approve", // or "reject" or "cancel"
    requestID: req.id,
    ownerName: req.owner,
    dogName: req.dog,
    requestedDate: req.dateString,
    status: "approved", // or "rejected" or "canceled"
    actor: currentUserName,
    context: "detail",
    detail: "Request approved"
)
BookingRequestListAudit.shared.log(event)
postBookingListAccessibilityAnnouncement("Request approved for \(req.owner)'s \(req.dog)")

// Example: When exporting CSV
let event = BookingRequestListAuditEvent(
    operation: "exportCSV",
    actor: currentUserName,
    context: "list",
    detail: "Exported audit events as CSV"
)
BookingRequestListAudit.shared.log(event)
postBookingListAccessibilityAnnouncement("Audit log exported as CSV")

#if DEBUG
// Overlay in your BookingRequestListView:
.overlay(
    BookingRequestListAuditSummaryView()
        .padding(.bottom, 8),
    alignment: .bottom
)
#endif
*/

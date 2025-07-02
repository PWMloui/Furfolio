//
//  CheckInConfirmationView.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//


//
//  CheckInConfirmationView.swift - Enhanced: Audit, Analytics, Accessibility, and DEV overlay
//
//  Business, analytics, and accessibility enhancements.
//
//  - Audit/event logging: See `CheckInConfirmationAuditEvent` and `CheckInConfirmationAudit`.
//  - Audit admin: See `CheckInConfirmationAuditAdmin`.
//  - Analytics: Provided via `CheckInConfirmationAudit` and surfaced in admin.
//  - Accessibility: VoiceOver announcements for check-in actions.
//  - DEV overlay: Shows audit summary in DEBUG builds.
//

import Foundation
import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

/// Represents an audit event for check-in confirmation actions.
struct CheckInConfirmationAuditEvent: Codable, Identifiable {
    /// Unique identifier for the event.
    let id: UUID
    /// Timestamp of the event.
    let timestamp: Date
    /// Operation performed: e.g. "confirm", "edit", "cancel", "exportCSV"
    let operation: String
    /// Appointment ID involved in the action.
    let appointmentID: String
    /// Dog's name.
    let dogName: String
    /// Owner's name.
    let ownerName: String
    /// Check-in time.
    let checkInTime: Date?
    /// Tags associated with the check-in.
    let tags: [String]
    /// Actor performing the action (e.g., staff name, "user").
    let actor: String
    /// Context of the action (e.g., "CheckInConfirmationView").
    let context: String
    /// Additional detail or notes.
    let detail: String

    /// Readable summary string for display.
    var summary: String {
        let dateFmt = DateFormatter()
        dateFmt.dateStyle = .short
        dateFmt.timeStyle = .medium
        let ts = dateFmt.string(from: timestamp)
        let tagsStr = tags.isEmpty ? "" : " [\(tags.joined(separator: ","))]"
        return "\(ts): \(operation.capitalized) '\(dogName)' (\(ownerName)) by \(actor)\(tagsStr)"
    }
}

/// Audit log for check-in confirmation actions.
final class CheckInConfirmationAudit: ObservableObject {
    /// Singleton instance (shared for app-wide use).
    static let shared = CheckInConfirmationAudit()
    /// All audit events.
    @Published private(set) var events: [CheckInConfirmationAuditEvent] = []
    /// Add a new audit event.
    func log(operation: String,
             appointmentID: String,
             dogName: String,
             ownerName: String,
             checkInTime: Date?,
             tags: [String],
             actor: String,
             context: String,
             detail: String = "") {
        let event = CheckInConfirmationAuditEvent(
            id: UUID(),
            timestamp: Date(),
            operation: operation,
            appointmentID: appointmentID,
            dogName: dogName,
            ownerName: ownerName,
            checkInTime: checkInTime,
            tags: tags,
            actor: actor,
            context: context,
            detail: detail
        )
        events.append(event)
        // Keep only the most recent 1000 events for memory efficiency
        if events.count > 1000 {
            events.removeFirst(events.count - 1000)
        }
    }
    /// Computed: total number of "confirm" check-ins.
    var totalCheckIns: Int {
        events.filter { $0.operation == "confirm" }.count
    }
    /// Computed: dogName most frequently checked-in.
    var mostFrequentDog: String? {
        let names = events.filter { $0.operation == "confirm" }.map { $0.dogName }
        let freq = names.reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }
        return freq.max(by: { $0.value < $1.value })?.key
    }
    /// Computed: timestamp of last "confirm" event.
    var lastCheckInTime: Date? {
        events.last(where: { $0.operation == "confirm" })?.timestamp
    }
}

/// Public admin interface for audit and analytics.
public class CheckInConfirmationAuditAdmin {
    public static let shared = CheckInConfirmationAuditAdmin()
    private let audit = CheckInConfirmationAudit.shared

    /// Returns the last audit event as a readable string, or nil if none.
    public var lastSummary: String? {
        audit.events.last?.summary
    }
    /// Returns the last audit event as JSON string, or nil if none.
    public var lastJSON: String? {
        guard let last = audit.events.last else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    /// Returns up to `limit` recent events, most recent first.
    public func recentEvents(limit: Int = 10) -> [CheckInConfirmationAuditEvent] {
        Array(audit.events.suffix(limit)).reversed()
    }
    /// Returns CSV export of all audit events. Headers: timestamp,operation,appointmentID,dogName,ownerName,checkInTime,tags,actor,context,detail
    public func exportCSV() -> String {
        let header = "timestamp,operation,appointmentID,dogName,ownerName,checkInTime,tags,actor,context,detail"
        let dateFmt = ISO8601DateFormatter()
        let rows = audit.events.map { e in
            let ts = dateFmt.string(from: e.timestamp)
            let checkin = e.checkInTime.map { dateFmt.string(from: $0) } ?? ""
            let tags = e.tags.joined(separator: "|")
            let csvFields = [
                ts, e.operation, e.appointmentID, e.dogName, e.ownerName, checkin,
                tags, e.actor, e.context, e.detail
            ]
            return csvFields.map { $0.replacingOccurrences(of: "\"", with: "\"\"") }
                .map { "\"\($0)\"" }
                .joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }
    /// Exposes analytics: total number of check-ins.
    public var totalCheckIns: Int { audit.totalCheckIns }
    /// Exposes analytics: most frequent dog checked in.
    public var mostFrequentDog: String? { audit.mostFrequentDog }
    /// Exposes analytics: timestamp of last check-in.
    public var lastCheckInTime: Date? { audit.lastCheckInTime }
}

#if canImport(UIKit)
/// Posts a VoiceOver accessibility announcement.
func postAccessibilityAnnouncement(_ message: String) {
    UIAccessibility.post(notification: .announcement, argument: message)
}
#else
func postAccessibilityAnnouncement(_ message: String) { /* no-op for non-UIKit */ }
#endif

// MARK: - Example usage in CheckInConfirmationView

// Example placeholder for the check-in confirmation view.
struct CheckInConfirmationView: View {
    // Example properties (replace with actual model/data)
    var appointmentID: String = "A123"
    var dogName: String = "Bella"
    var ownerName: String = "Sam Lee"
    var checkInTime: Date? = Date()
    var tags: [String] = ["VIP"]
    var actor: String = "user"
    var context: String = "CheckInConfirmationView"

    @ObservedObject private var audit = CheckInConfirmationAudit.shared

    var body: some View {
        VStack(spacing: 24) {
            Text("Check-In Confirmation for \(dogName)")
                .font(.title)
            HStack(spacing: 20) {
                Button("Confirm") {
                    handleAction(operation: "confirm", detail: "Check-in confirmed")
                }
                Button("Edit") {
                    handleAction(operation: "edit", detail: "Check-in edited")
                }
                Button("Cancel") {
                    handleAction(operation: "cancel", detail: "Check-in cancelled")
                }
                Button("Export CSV") {
                    handleAction(operation: "exportCSV", detail: "Audit log exported as CSV")
                    // Example: Use CheckInConfirmationAuditAdmin.shared.exportCSV()
                }
            }
        }
#if DEBUG
        // DEV overlay: shows last 3 audit events, total check-ins, most frequent dog.
        .overlay(alignment: .bottom) {
            DevAuditOverlay()
        }
#endif
    }

    /// Handles an action, logs audit, posts accessibility announcement.
    private func handleAction(operation: String, detail: String) {
        audit.log(
            operation: operation,
            appointmentID: appointmentID,
            dogName: dogName,
            ownerName: ownerName,
            checkInTime: checkInTime,
            tags: tags,
            actor: actor,
            context: context,
            detail: detail
        )
        // Accessibility: announce action for VoiceOver.
        let announcement: String
        switch operation {
        case "confirm":
            announcement = "Check-in confirmed for \(dogName)"
        case "edit":
            announcement = "Check-in edited for \(dogName)"
        case "cancel":
            announcement = "Check-in cancelled for \(dogName)"
        case "exportCSV":
            announcement = "Audit log exported as CSV"
        default:
            announcement = "\(operation.capitalized) performed for \(dogName)"
        }
        postAccessibilityAnnouncement(announcement)
    }
}

#if DEBUG
/// DEV overlay showing last 3 audit events and analytics.
private struct DevAuditOverlay: View {
    @ObservedObject private var audit = CheckInConfirmationAudit.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider()
            Text("AUDIT DEV OVERLAY").font(.caption).foregroundColor(.secondary)
            ForEach(audit.events.suffix(3).reversed()) { event in
                Text(event.summary).font(.caption2)
            }
            HStack(spacing: 12) {
                Text("Total check-ins: \(audit.totalCheckIns)")
                    .font(.caption2)
                if let dog = audit.mostFrequentDog {
                    Text("Most frequent dog: \(dog)").font(.caption2)
                }
            }
        }
        .padding(8)
        .background(Color(.systemGray6).opacity(0.85))
        .cornerRadius(10)
        .padding(.bottom, 8)
    }
}
#endif

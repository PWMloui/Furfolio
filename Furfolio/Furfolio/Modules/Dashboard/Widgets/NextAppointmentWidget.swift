
//  NextAppointmentWidget.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import Foundation
import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Audit/Event Logging Enhancements

/// Represents an audit event for the NextAppointmentWidget.
/// Conforms to Codable for serialization.
struct NextAppointmentAuditEvent: Codable {
    let timestamp: Date
    let operation: String // e.g., "load", "appear", "tap", "exportCSV"
    let appointmentID: String
    let ownerName: String
    let dogName: String
    let date: String
    let status: String
    let tags: [String]
    let actor: String
    let context: String
    let detail: String
}

/// Singleton class for logging and managing audit events for NextAppointmentWidget.
final class NextAppointmentAudit {
    static let shared = NextAppointmentAudit()
    private let queue = DispatchQueue(label: "NextAppointmentAuditQueue")
    private(set) var events: [NextAppointmentAuditEvent] = []

    private init() {}

    /// Log an audit event.
    func logEvent(
        operation: String,
        appointmentID: String,
        ownerName: String,
        dogName: String,
        date: String,
        status: String,
        tags: [String],
        actor: String,
        context: String,
        detail: String
    ) {
        let event = NextAppointmentAuditEvent(
            timestamp: Date(),
            operation: operation,
            appointmentID: appointmentID,
            ownerName: ownerName,
            dogName: dogName,
            date: date,
            status: status,
            tags: tags,
            actor: actor,
            context: context,
            detail: detail
        )
        queue.sync {
            events.append(event)
            // Limit to last 100 events for memory efficiency
            if events.count > 100 {
                events.removeFirst(events.count - 100)
            }
        }
    }

    /// Computed property: Number of 'appear' events (analytics).
    var totalAppointmentsDisplayed: Int {
        queue.sync {
            events.filter { $0.operation == "appear" }.count
        }
    }

    /// Computed property: Most frequent status displayed (analytics).
    var mostFrequentStatus: String? {
        queue.sync {
            let statuses = events.map { $0.status }
            let freq = Dictionary(statuses.map { ($0, 1) }, uniquingKeysWith: +)
            return freq.max(by: { $0.value < $1.value })?.key
        }
    }

    /// Computed property: Most frequent ownerName displayed (analytics).
    var mostFrequentOwner: String? {
        queue.sync {
            let owners = events.map { $0.ownerName }
            let freq = Dictionary(owners.map { ($0, 1) }, uniquingKeysWith: +)
            return freq.max(by: { $0.value < $1.value })?.key
        }
    }
}

// MARK: - Audit Admin API
/// Public API for accessing audit events, summaries, analytics, and CSV export.
public class NextAppointmentAuditAdmin {
    public static var lastSummary: String {
        guard let last = NextAppointmentAudit.shared.events.last else { return "No events" }
        return "[\(last.timestamp)] \(last.operation): \(last.dogName) (\(last.status)) for \(last.ownerName)"
    }
    public static var lastJSON: String {
        guard let last = NextAppointmentAudit.shared.events.last else { return "{}" }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(last) {
            return String(data: data, encoding: .utf8) ?? "{}"
        }
        return "{}"
    }
    public static func recentEvents(limit: Int = 10) -> [NextAppointmentAuditEvent] {
        let events = NextAppointmentAudit.shared.events
        return Array(events.suffix(limit))
    }
    /// Export audit events as CSV string.
    public static func exportCSV() -> String {
        let header = "timestamp,operation,appointmentID,ownerName,dogName,date,status,tags,actor,context,detail"
        let rows = NextAppointmentAudit.shared.events.map { event in
            let tagString = event.tags.joined(separator: "|")
            let fields = [
                iso8601(event.timestamp),
                event.operation,
                event.appointmentID,
                event.ownerName,
                event.dogName,
                event.date,
                event.status,
                tagString,
                event.actor,
                event.context,
                event.detail
            ]
            // Escape commas and quotes
            return fields.map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }.joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }
    /// ISO8601 date string helper
    private static func iso8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }
    /// Analytics
    public static var totalAppointmentsDisplayed: Int {
        NextAppointmentAudit.shared.totalAppointmentsDisplayed
    }
    public static var mostFrequentStatus: String? {
        NextAppointmentAudit.shared.mostFrequentStatus
    }
    public static var mostFrequentOwner: String? {
        NextAppointmentAudit.shared.mostFrequentOwner
    }
}

// MARK: - Accessibility Enhancements
/// Helper to post VoiceOver announcements for accessibility.
func postVoiceOverAnnouncement(_ message: String) {
#if canImport(UIKit)
    UIAccessibility.post(notification: .announcement, argument: message)
#endif
}

// MARK: - Example Widget SwiftUI View
/// Example View: Replace this with actual widget implementation as needed.
struct NextAppointmentWidget: View {
    // Example appointment data for demonstration.
    var appointmentID: String = "appt-123"
    var ownerName: String = "Alex Kim"
    var dogName: String = "Buddy"
    var date: String = "2025-06-30 14:00"
    var status: String = "Confirmed"
    var tags: [String] = ["grooming"]
    var actor: String = "user"
    var context: String = "widget"
    var detail: String = ""
    @State private var overlayVisible: Bool = false

    var body: some View {
        VStack {
            Text("Next appointment for \(dogName)")
                .font(.headline)
            Text("Owner: \(ownerName)")
            Text("Status: \(status)")
            Text("Date: \(date)")
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            // Log 'appear' event.
            NextAppointmentAudit.shared.logEvent(
                operation: "appear",
                appointmentID: appointmentID,
                ownerName: ownerName,
                dogName: dogName,
                date: date,
                status: status,
                tags: tags,
                actor: actor,
                context: context,
                detail: detail
            )
            // Accessibility: Announce on appear.
            let announcement = "Next appointment for \(dogName) with \(ownerName), status: \(status)."
            postVoiceOverAnnouncement(announcement)
        }
        .onTapGesture {
            // Log 'tap' event.
            NextAppointmentAudit.shared.logEvent(
                operation: "tap",
                appointmentID: appointmentID,
                ownerName: ownerName,
                dogName: dogName,
                date: date,
                status: status,
                tags: tags,
                actor: actor,
                context: context,
                detail: detail
            )
            // Accessibility: Announce on tap.
            let announcement = "Next appointment for \(dogName) with \(ownerName), status: \(status)."
            postVoiceOverAnnouncement(announcement)
            // For dev overlay demonstration.
            #if DEBUG
            overlayVisible.toggle()
            #endif
        }
        // DEV overlay in DEBUG builds
        #if DEBUG
        .overlay(
            VStack(alignment: .leading, spacing: 2) {
                Text("DEV: Last 3 Audit Events")
                    .font(.caption).bold()
                ForEach(Array(NextAppointmentAudit.shared.events.suffix(3).reversed()), id: \.timestamp) { event in
                    Text("[\(event.operation)] \(event.dogName) (\(event.status))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Divider()
                Text("Total Displayed: \(NextAppointmentAudit.shared.totalAppointmentsDisplayed)")
                    .font(.caption2)
                Text("Most Frequent Status: \(NextAppointmentAudit.shared.mostFrequentStatus ?? "-")")
                    .font(.caption2)
                Text("Most Frequent Owner: \(NextAppointmentAudit.shared.mostFrequentOwner ?? "-")")
                    .font(.caption2)
            }
            .padding(6)
            .background(Color(.systemYellow).opacity(0.8))
            .cornerRadius(8)
            .padding([.bottom, .horizontal], 8)
            , alignment: .bottom
        )
        #endif
    }
}

#if DEBUG
struct NextAppointmentWidget_Previews: PreviewProvider {
    static var previews: some View {
        NextAppointmentWidget()
    }
}
#endif

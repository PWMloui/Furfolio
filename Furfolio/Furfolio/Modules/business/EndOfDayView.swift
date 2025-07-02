//
//  EndOfDayView.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//


// MARK: - EndOfDayAudit: Business, Analytics, and Accessibility Enhancements

import Foundation
import SwiftUI
import Combine

/// Represents an audit log entry for end-of-day operations.
struct EndOfDayAudit: Identifiable {
    let id = UUID()
    let timestamp: Date
    let operation: String // e.g., "processDay", "closeDay"
    let day: Date
    let totalRevenue: Double
    let appointmentsCompleted: Int
    let chargesProcessed: Int
    let notes: String
    let tags: [String]
    let actor: String
    let context: String
    let detail: String

    /// CSV export of all audit log entries.
    /// - Parameter logs: Array of EndOfDayAudit to export.
    /// - Returns: CSV string with headers.
    static func exportCSV(_ logs: [EndOfDayAudit]) -> String {
        let header = "timestamp,operation,day,totalRevenue,appointmentsCompleted,chargesProcessed,notes,tags,actor,context,detail"
        let dateFormatter = ISO8601DateFormatter()
        let rows = logs.map { log in
            [
                dateFormatter.string(from: log.timestamp),
                log.operation,
                dateFormatter.string(from: log.day),
                String(format: "%.2f", log.totalRevenue),
                "\(log.appointmentsCompleted)",
                "\(log.chargesProcessed)",
                "\"\(log.notes.replacingOccurrences(of: "\"", with: "\"\""))\"",
                "\"\(log.tags.joined(separator: ";").replacingOccurrences(of: "\"", with: "\"\""))\"",
                log.actor,
                log.context,
                "\"\(log.detail.replacingOccurrences(of: "\"", with: "\"\""))\""
            ].joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }
}

/// Admin utility for EndOfDayAudit log analytics and export.
class EndOfDayAuditAdmin: ObservableObject {
    /// The audit log.
    @Published var log: [EndOfDayAudit] = []

    /// Export the audit log to CSV.
    /// - Returns: CSV string.
    func exportCSV() -> String {
        EndOfDayAudit.exportCSV(log)
    }

    /// Average revenue of all audit events.
    var averageRevenue: Double {
        guard !log.isEmpty else { return 0 }
        return log.map { $0.totalRevenue }.reduce(0, +) / Double(log.count)
    }

    /// The most frequent note entered in the audit log.
    var mostFrequentNote: String? {
        let notes = log.map { $0.notes }.filter { !$0.isEmpty }
        let freq = Dictionary(grouping: notes, by: { $0 }).mapValues { $0.count }
        return freq.max(by: { $0.value < $1.value })?.key
    }

    /// Count of "processDay" or "closeDay" events.
    var totalDaysProcessed: Int {
        log.filter { $0.operation == "processDay" || $0.operation == "closeDay" }.count
    }
}

// MARK: - VoiceOver Announcement on Day Close/Process

import AVFoundation

/// Posts a VoiceOver announcement summarizing the day's stats.
func postDaySummaryAccessibilityAnnouncement(revenue: Double, appointments: Int, operation: String) {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    let revenueStr = formatter.string(from: NSNumber(value: revenue)) ?? "$\(revenue)"
    let op = (operation == "closeDay") ? "Day closed" : "Day processed"
    let announcement = "\(op): \(revenueStr) revenue, \(appointments) appointments completed."
    UIAccessibility.post(notification: .announcement, argument: announcement)
}

// MARK: - DEV Overlay for Audit Analytics (DEBUG only)

#if DEBUG
/// Overlay view showing last 3 audit events and analytics.
struct EndOfDayAuditDevOverlay: View {
    @ObservedObject var admin: EndOfDayAuditAdmin

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DEV: Last 3 Audit Events")
                .font(.caption).bold()
            ForEach(admin.log.suffix(3).reversed()) { entry in
                HStack {
                    Text(entry.operation)
                        .font(.caption2)
                    Text(entry.timestamp, style: .time)
                        .font(.caption2)
                    Text("$\(String(format: "%.2f", entry.totalRevenue))")
                        .font(.caption2)
                    if !entry.notes.isEmpty {
                        Text("Note: \(entry.notes)").font(.caption2)
                    }
                }
            }
            Divider()
            Text("Average Revenue: $\(String(format: "%.2f", admin.averageRevenue))").font(.caption2)
            if let note = admin.mostFrequentNote {
                Text("Most Frequent Note: “\(note)”").font(.caption2)
            }
        }
        .padding(8)
        .background(Color(.systemGray6).opacity(0.95))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10).stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
        .shadow(radius: 2)
        .padding(.bottom, 8)
    }
}
#endif

// MARK: - Usage Example (Integrate in EndOfDayView)

/*
// Example pseudocode for integration:
struct EndOfDayView: View {
    @StateObject private var auditAdmin = EndOfDayAuditAdmin()
    // ... other state

    var body: some View {
        ZStack(alignment: .bottom) {
            // ... main UI

            #if DEBUG
            EndOfDayAuditDevOverlay(admin: auditAdmin)
                .transition(.move(edge: .bottom))
            #endif
        }
    }

    func closeDay() {
        // ... perform close
        let audit = EndOfDayAudit(
            timestamp: Date(),
            operation: "closeDay",
            day: Date(),
            totalRevenue: 740,
            appointmentsCompleted: 8,
            chargesProcessed: 7,
            notes: "All done",
            tags: [],
            actor: "admin",
            context: "EndOfDayView",
            detail: "Closed via UI"
        )
        auditAdmin.log.append(audit)
        // Accessibility announcement
        postDaySummaryAccessibilityAnnouncement(
            revenue: audit.totalRevenue,
            appointments: audit.appointmentsCompleted,
            operation: audit.operation
        )
    }
}
*/

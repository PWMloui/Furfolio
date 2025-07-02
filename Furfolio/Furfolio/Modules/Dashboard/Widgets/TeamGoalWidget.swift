//
//  TeamGoalWidget.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import SwiftUI
import Combine
import AVFoundation

// Assuming TeamGoalWidgetAudit and TeamGoalWidgetAuditAdmin are defined somewhere in this file or imported.
// Adding required enhancements and extensions here:

extension TeamGoalWidgetAudit {
    /// Compute the average percentComplete from all audit events.
    var averagePercentComplete: Double {
        guard !log.isEmpty else { return 0.0 }
        let total = log.reduce(0.0) { $0 + $1.percentComplete }
        return total / Double(log.count)
    }

    /// Compute the most frequent status string from all audit events.
    var mostFrequentStatus: String {
        guard !log.isEmpty else { return "" }
        let frequency = log.reduce(into: [String: Int]()) { counts, event in
            counts[event.status, default: 0] += 1
        }
        return frequency.max(by: { $0.value < $1.value })?.key ?? ""
    }

    /// Total number of audit events.
    var totalDisplays: Int {
        return log.count
    }

    /// Export the audit log as CSV string with columns:
    /// timestamp,goalTitle,goalValue,currentValue,percentComplete,status,tags
    static func exportCSV(from audit: TeamGoalWidgetAudit) -> String {
        let header = "timestamp,goalTitle,goalValue,currentValue,percentComplete,status,tags"
        let rows = audit.log.map { event in
            let timestampString = ISO8601DateFormatter().string(from: event.timestamp)
            let tagsString = event.tags.joined(separator: ";")
            return "\(timestampString),\(event.goalTitle),\(event.goalValue),\(event.currentValue),\(event.percentComplete),\(event.status),\(tagsString)"
        }
        return ([header] + rows).joined(separator: "\n")
    }
}

extension TeamGoalWidgetAuditAdmin {
    /// Expose averagePercentComplete from TeamGoalWidgetAudit.
    var averagePercentComplete: Double {
        audit.averagePercentComplete
    }

    /// Expose mostFrequentStatus from TeamGoalWidgetAudit.
    var mostFrequentStatus: String {
        audit.mostFrequentStatus
    }

    /// Expose totalDisplays from TeamGoalWidgetAudit.
    var totalDisplays: Int {
        audit.totalDisplays
    }

    /// Expose CSV export from TeamGoalWidgetAudit.
    func exportCSV() -> String {
        TeamGoalWidgetAudit.exportCSV(from: audit)
    }
}

extension TeamGoalWidget {
    /// Posts a VoiceOver announcement if percentComplete is below 50%.
    func postAccessibilityWarningIfNeeded(percentComplete: Double) {
        if percentComplete < 0.5 {
            let announcement = "Warning: Team goal progress below 50 percent."
            UIAccessibility.post(notification: .announcement, argument: announcement)
        }
    }
}

#if DEBUG
/// SwiftUI overlay view for DEV mode showing last 3 audit events and analytics.
struct TeamGoalWidgetDevOverlay: View {
    @ObservedObject var auditAdmin: TeamGoalWidgetAuditAdmin

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DEV Overlay")
                .font(.headline)
            Text("Last 3 Audit Events:")
                .font(.subheadline)
            ForEach(auditAdmin.audit.log.suffix(3).reversed(), id: \.timestamp) { event in
                Text("\(event.timestamp, formatter: dateFormatter): \(event.goalTitle) - \(Int(event.percentComplete * 100))% - \(event.status)")
                    .font(.caption)
            }
            Text("Average % Complete: \(Int(auditAdmin.averagePercentComplete * 100))%")
                .font(.caption)
            Text("Most Frequent Status: \(auditAdmin.mostFrequentStatus)")
                .font(.caption)
            Text("Total Displays: \(auditAdmin.totalDisplays)")
                .font(.caption)
        }
        .padding(8)
        .background(Color.black.opacity(0.7))
        .foregroundColor(.white)
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm:ss"
        return formatter
    }
}

extension TeamGoalWidget {
    /// Overlay the DEV overlay view at bottom in DEBUG builds.
    @ViewBuilder
    func devOverlay(auditAdmin: TeamGoalWidgetAuditAdmin) -> some View {
        self
            .overlay(
                VStack {
                    Spacer()
                    TeamGoalWidgetDevOverlay(auditAdmin: auditAdmin)
                        .frame(maxWidth: .infinity)
                }
            )
    }
}
#endif

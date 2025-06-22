//
//  OwnerAuditLogView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

struct OwnerAuditLogEntry: Identifiable {
    let id = UUID()
    let date: Date
    let action: String
    let performedBy: String
    let details: String?
}

struct OwnerAuditLogView: View {
    let logEntries: [OwnerAuditLogEntry]

    var body: some View {
        NavigationStack {
            List {
                if logEntries.isEmpty {
                    ContentUnavailableView("No audit log entries.", systemImage: "doc.badge.gearshape")
                        .padding(.top, 40)
                } else {
                    ForEach(logEntries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(entry.action)
                                    .font(.headline)
                                Spacer()
                                Text(entry.date, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let details = entry.details, !details.isEmpty {
                                Text(details)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Text("By \(entry.performedBy)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .navigationTitle("Owner Audit Log")
            .background(Color(.systemGroupedBackground))
        }
    }
}

#if DEBUG
struct OwnerAuditLogView_Previews: PreviewProvider {
    static var previews: some View {
        OwnerAuditLogView(
            logEntries: [
                OwnerAuditLogEntry(date: Date().addingTimeInterval(-3600 * 3), action: "Edited Owner Info", performedBy: "Admin", details: "Changed phone number."),
                OwnerAuditLogEntry(date: Date().addingTimeInterval(-3600 * 24 * 2), action: "Added Appointment", performedBy: "Staff1", details: "Scheduled full groom for Bella."),
                OwnerAuditLogEntry(date: Date().addingTimeInterval(-3600 * 24 * 7), action: "Deleted Charge", performedBy: "Admin", details: "Removed duplicate charge for Max.")
            ]
        )
    }
}
#endif

//
//  OwnerHistoryTabView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//


import SwiftUI

struct OwnerHistoryTabView: View {
    let activityEvents: [OwnerActivityEvent]
    let auditLogEntries: [OwnerAuditLogEntry]
    let changeHistoryEntries: [OwnerChangeHistoryEntry]

    @State private var selectedTab: Int = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("History Tab", selection: $selectedTab) {
                    Text("Timeline").tag(0)
                    Text("Audit Log").tag(1)
                    Text("Changes").tag(2)
                }
                .pickerStyle(.segmented)
                .padding([.horizontal, .top])

                Divider()
                    .padding(.bottom, 4)

                TabView(selection: $selectedTab) {
                    OwnerActivityTimelineView(events: activityEvents)
                        .tag(0)
                    OwnerAuditLogView(logEntries: auditLogEntries)
                        .tag(1)
                    OwnerChangeHistoryView(changes: changeHistoryEntries)
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("Owner History")
            .background(Color(.systemGroupedBackground))
        }
    }
}

#if DEBUG
struct OwnerHistoryTabView_Previews: PreviewProvider {
    static var previews: some View {
        OwnerHistoryTabView(
            activityEvents: [
                OwnerActivityEvent(date: Date().addingTimeInterval(-3600 * 3), title: "Appointment Booked", description: "Full Groom for Bella", icon: "calendar.badge.plus", color: .blue),
                OwnerActivityEvent(date: Date().addingTimeInterval(-3600 * 24 * 2), title: "Payment Received", description: "Charge for Max - $85", icon: "dollarsign.circle.fill", color: .green),
                OwnerActivityEvent(date: Date().addingTimeInterval(-3600 * 24 * 7), title: "Owner Info Updated", description: "Changed address", icon: "pencil.circle.fill", color: .orange)
            ],
            auditLogEntries: [
                OwnerAuditLogEntry(date: Date().addingTimeInterval(-3600 * 3), action: "Edited Owner Info", performedBy: "Admin", details: "Changed phone number."),
                OwnerAuditLogEntry(date: Date().addingTimeInterval(-3600 * 24 * 2), action: "Added Appointment", performedBy: "Staff1", details: "Scheduled full groom for Bella."),
                OwnerAuditLogEntry(date: Date().addingTimeInterval(-3600 * 24 * 7), action: "Deleted Charge", performedBy: "Admin", details: "Removed duplicate charge for Max.")
            ],
            changeHistoryEntries: [
                OwnerChangeHistoryEntry(date: Date().addingTimeInterval(-3600 * 2), fieldChanged: "Phone Number", oldValue: "555-123-4567", newValue: "555-987-6543", changedBy: "Admin"),
                OwnerChangeHistoryEntry(date: Date().addingTimeInterval(-3600 * 24 * 1), fieldChanged: "Address", oldValue: "123 Main St", newValue: "321 Bark Ave", changedBy: "Staff1"),
                OwnerChangeHistoryEntry(date: Date().addingTimeInterval(-3600 * 24 * 3), fieldChanged: "Email", oldValue: "jane@old.com", newValue: "jane@new.com", changedBy: "Admin")
            ]
        )
    }
}
#endif

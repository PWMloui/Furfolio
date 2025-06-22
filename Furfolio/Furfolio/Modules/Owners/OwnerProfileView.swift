//
//  OwnerProfileView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

struct OwnerProfileView: View {
    let ownerName: String
    let phoneNumber: String?
    let email: String?
    let address: String?
    @State var notes: String
    @State var favoriteGroomingStyle: String
    @State var preferredShampoo: String
    @State var specialRequests: String
    let dogCount: Int
    let appointmentCount: Int
    let totalSpent: Double
    let lastVisit: Date?
    let isTopSpender: Bool

    // History and logs
    let activityEvents: [OwnerActivityEvent]
    let auditLogEntries: [OwnerAuditLogEntry]
    let changeHistoryEntries: [OwnerChangeHistoryEntry]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Contact quick actions
                OwnerContactQuickActionsView(
                    phoneNumber: phoneNumber,
                    email: email,
                    address: address
                )

                // Owner summary row
                DogOwnerRowView(
                    ownerName: ownerName,
                    phoneNumber: phoneNumber,
                    email: email,
                    address: address,
                    dogCount: dogCount,
                    upcomingAppointmentDate: lastVisit
                )

                // Lifetime Value summary
                OwnerLifetimeValueView(
                    ownerName: ownerName,
                    totalSpent: totalSpent,
                    appointmentCount: appointmentCount,
                    lastVisit: lastVisit,
                    isTopSpender: isTopSpender
                )

                // Notes section
                OwnerNotesView(notes: $notes)

                // Preferences section
                OwnerPreferencesView(
                    favoriteGroomingStyle: $favoriteGroomingStyle,
                    preferredShampoo: $preferredShampoo,
                    specialRequests: $specialRequests
                )

                // Owner history (timeline/audit/changes)
                OwnerHistoryTabView(
                    activityEvents: activityEvents,
                    auditLogEntries: auditLogEntries,
                    changeHistoryEntries: changeHistoryEntries
                )
            }
            .padding()
        }
        .navigationTitle(ownerName)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
    }
}

#if DEBUG
struct OwnerProfileView_Previews: PreviewProvider {
    @State static var notes = "Loves discounts, usually comes with 2 dogs."
    @State static var style = "Poodle Clip"
    @State static var shampoo = "Oatmeal"
    @State static var requests = "Text before appointment."

    static var previews: some View {
        OwnerProfileView(
            ownerName: "Jane Doe",
            phoneNumber: "555-987-6543",
            email: "jane@example.com",
            address: "321 Bark Ave",
            notes: notes,
            favoriteGroomingStyle: style,
            preferredShampoo: shampoo,
            specialRequests: requests,
            dogCount: 2,
            appointmentCount: 16,
            totalSpent: 1525.50,
            lastVisit: Date().addingTimeInterval(-86400 * 14),
            isTopSpender: true,
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

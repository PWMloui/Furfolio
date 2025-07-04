//
//  OwnerProfileView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Enterprise-Grade Owner Profile
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

    @State private var appearedOnce: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Contact quick actions
                SectionCard {
                    OwnerContactQuickActionsView(
                        phoneNumber: phoneNumber,
                        email: email,
                        address: address
                    )
                }
                .accessibilityIdentifier("OwnerProfileView-QuickActions")

                // Owner summary row
                SectionCard {
                    DogOwnerRowView(
                        ownerName: ownerName,
                        phoneNumber: phoneNumber,
                        email: email,
                        address: address,
                        dogCount: dogCount,
                        upcomingAppointmentDate: lastVisit
                    )
                }
                .accessibilityIdentifier("OwnerProfileView-SummaryRow")

                // Lifetime Value summary
                SectionCard {
                    OwnerLifetimeValueView(
                        ownerName: ownerName,
                        totalSpent: totalSpent,
                        appointmentCount: appointmentCount,
                        lastVisit: lastVisit,
                        isTopSpender: isTopSpender
                    )
                }
                .accessibilityIdentifier("OwnerProfileView-LifetimeValue")

                // Notes section
                SectionCard {
                    OwnerNotesView(notes: $notes)
                }
                .accessibilityIdentifier("OwnerProfileView-Notes")

                // Preferences section
                SectionCard {
                    OwnerPreferencesView(
                        favoriteGroomingStyle: $favoriteGroomingStyle,
                        preferredShampoo: $preferredShampoo,
                        specialRequests: $specialRequests
                    )
                }
                .accessibilityIdentifier("OwnerProfileView-Preferences")

                // Owner history (timeline/audit/changes)
                SectionCard {
                    OwnerHistoryTabView(
                        activityEvents: activityEvents,
                        auditLogEntries: auditLogEntries,
                        changeHistoryEntries: changeHistoryEntries
                    )
                }
                .accessibilityIdentifier("OwnerProfileView-History")
            }
            .padding()
        }
        .background(
            LinearGradient(
                colors: [Color(.systemGroupedBackground), Color(.secondarySystemGroupedBackground).opacity(0.7)],
                startPoint: .top, endPoint: .bottom)
        )
        .navigationTitle(ownerName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !appearedOnce {
                OwnerProfileAudit.record(action: "Appear", ownerName: ownerName)
                appearedOnce = true
            }
        }
        .accessibilityIdentifier("OwnerProfileView-Root")
    }
}

// MARK: - Section Card Helper

fileprivate struct SectionCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .shadow(color: Color(.black).opacity(0.05), radius: 3, x: 0, y: 1)
            )
            .padding(.vertical, 2)
    }
}

// MARK: - Audit/Event Logging

fileprivate struct OwnerProfileAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let ownerName: String
    var summary: String {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return "[OwnerProfileView] \(action): \(ownerName) at \(df.string(from: timestamp))"
    }
}
fileprivate final class OwnerProfileAudit {
    static private(set) var log: [OwnerProfileAuditEvent] = []
    static func record(action: String, ownerName: String) {
        let event = OwnerProfileAuditEvent(timestamp: Date(), action: action, ownerName: ownerName)
        log.append(event)
        if log.count > 20 { log.removeFirst() }
    }
    static func recentSummaries(limit: Int = 6) -> [String] {
        log.suffix(limit).map(\.summary)
    }
}
public enum OwnerProfileAuditAdmin {
    public static func lastSummary() -> String { OwnerProfileAudit.log.last?.summary ?? "No events yet." }
    public static func recentEvents(limit: Int = 6) -> [String] { OwnerProfileAudit.recentSummaries(limit: limit) }
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

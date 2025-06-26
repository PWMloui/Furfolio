//
//  OwnerHistoryTabView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Enterprise-Grade Tabbed Owner History
//

import SwiftUI

struct OwnerHistoryTabView: View {
    let activityEvents: [OwnerActivityEvent]
    let auditLogEntries: [OwnerAuditLogEntry]
    let changeHistoryEntries: [OwnerChangeHistoryEntry]

    @State private var selectedTab: Int = 0
    @State private var appearedOnce = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("History Tab", selection: $selectedTab) {
                    Label("Timeline", systemImage: "clock.arrow.circlepath").tag(0)
                    Label("Audit Log", systemImage: "doc.badge.gearshape").tag(1)
                    Label("Changes", systemImage: "arrow.triangle.swap").tag(2)
                }
                .pickerStyle(.segmented)
                .padding([.horizontal, .top])
                .accessibilityIdentifier("OwnerHistoryTabView-Picker")

                Divider().padding(.bottom, 4)

                TabView(selection: $selectedTab) {
                    OwnerActivityTimelineView(events: activityEvents)
                        .tag(0)
                        .accessibilityIdentifier("OwnerHistoryTabView-TimelineTab")
                        .accessibilityLabel("Owner timeline tab")

                    OwnerAuditLogView(logEntries: auditLogEntries)
                        .tag(1)
                        .accessibilityIdentifier("OwnerHistoryTabView-AuditTab")
                        .accessibilityLabel("Owner audit log tab")

                    OwnerChangeHistoryView(changes: changeHistoryEntries)
                        .tag(2)
                        .accessibilityIdentifier("OwnerHistoryTabView-ChangesTab")
                        .accessibilityLabel("Owner changes tab")
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .accessibilityIdentifier("OwnerHistoryTabView-TabView")
                .animation(.easeInOut(duration: 0.24), value: selectedTab)
            }
            .navigationTitle("Owner History")
            .background(Color(.systemGroupedBackground))
            .onAppear {
                // Audit only first appearance (QA/analytics)
                if !appearedOnce {
                    OwnerHistoryTabAudit.record(action: "Appear", tab: selectedTab)
                    appearedOnce = true
                }
            }
            .onChange(of: selectedTab) { tab in
                OwnerHistoryTabAudit.record(action: "TabSwitch", tab: tab)
            }
        }
    }
}

// MARK: - Audit/Event Logging

fileprivate struct OwnerHistoryTabAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let tab: Int
    var summary: String {
        let df = DateFormatter(); df.dateStyle = .short; df.timeStyle = .short
        let tabName = tab == 0 ? "Timeline" : (tab == 1 ? "Audit Log" : "Changes")
        return "[OwnerHistoryTabView] \(action): \(tabName) tab at \(df.string(from: timestamp))"
    }
}
fileprivate final class OwnerHistoryTabAudit {
    static private(set) var log: [OwnerHistoryTabAuditEvent] = []
    static func record(action: String, tab: Int) {
        let event = OwnerHistoryTabAuditEvent(timestamp: Date(), action: action, tab: tab)
        log.append(event)
        if log.count > 20 { log.removeFirst() }
    }
    static func recentSummaries(limit: Int = 6) -> [String] {
        log.suffix(limit).map { $0.summary }
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

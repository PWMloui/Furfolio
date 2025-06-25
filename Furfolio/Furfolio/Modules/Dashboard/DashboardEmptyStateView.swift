//
//  DashboardEmptyStateView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Tokenized, Modular Empty State View
//

import SwiftUI

// MARK: - Audit/Event Logging

fileprivate struct DashboardEmptyAuditEvent: Codable {
    let timestamp: Date
    let message: String
    let showAddButton: Bool
    let action: String? // "appear", "addAppointment"
    let tags: [String]
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        let btn = showAddButton ? "AddButton" : "NoButton"
        let base = "[\(action ?? "appear")] \(message) (\(btn)) [\(tags.joined(separator: ","))] at \(dateStr)"
        return base
    }
}

fileprivate final class DashboardEmptyAudit {
    static private(set) var log: [DashboardEmptyAuditEvent] = []

    static func record(
        message: String,
        showAddButton: Bool,
        action: String,
        tags: [String] = []
    ) {
        let event = DashboardEmptyAuditEvent(
            timestamp: Date(),
            message: message,
            showAddButton: showAddButton,
            action: action,
            tags: tags
        )
        log.append(event)
        if log.count > 30 { log.removeFirst() }
    }

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No empty state events recorded."
    }
}

// MARK: - DashboardEmptyStateView

struct DashboardEmptyStateView: View {
    var message: String = "No appointments or data available."
    var showAddAppointmentButton: Bool = false
    var onAddAppointment: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "calendar.badge.exclamationmark")
                .resizable()
                .scaledToFit()
                .symbolRenderingMode(.hierarchical)
                .frame(width: 90, height: 90)
                .foregroundColor(.accentColor)
                .accessibilityHidden(true)

            Text(message)
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .accessibilityLabel(message)

            if showAddAppointmentButton, let action = onAddAppointment {
                Button(action: {
                    DashboardEmptyAudit.record(
                        message: message,
                        showAddButton: showAddAppointmentButton,
                        action: "addAppointment",
                        tags: ["add", "appointment"]
                    )
                    action()
                }) {
                    Text("Add Appointment")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: 200)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .shadow(radius: 4)
                }
                .accessibilityLabel("Add an appointment")
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(), value: showAddAppointmentButton)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
        .accessibilityElement(children: .contain)
        .onAppear {
            DashboardEmptyAudit.record(
                message: message,
                showAddButton: showAddAppointmentButton,
                action: "appear",
                tags: ["empty", "dashboard"]
            )
        }
    }
}

// MARK: - Audit/Admin Accessors

public enum DashboardEmptyAuditAdmin {
    public static var lastSummary: String { DashboardEmptyAudit.accessibilitySummary }
    public static var lastJSON: String? { DashboardEmptyAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        DashboardEmptyAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
}

#if DEBUG
struct DashboardEmptyStateView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            DashboardEmptyStateView()

            DashboardEmptyStateView(
                showAddAppointmentButton: true,
                onAddAppointment: {
                    print("Add Appointment tapped")
                }
            )
        }
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
#endif

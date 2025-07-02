//
//  DashboardEmptyStateView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Tokenized, Modular Empty State View
//

import SwiftUI
import Combine

#if canImport(UIKit)
import UIKit
#endif

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

    /// Records a new audit event with the given parameters.
    /// Also posts a VoiceOver announcement for accessibility.
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
        
        // Accessibility: Post VoiceOver announcement on appear and addAppointment
        #if canImport(UIKit)
        if action == "appear" {
            UIAccessibility.post(notification: .announcement, argument: "Empty state: \(message).")
        } else if action == "addAppointment" {
            UIAccessibility.post(notification: .announcement, argument: "Add appointment triggered.")
        }
        #endif
    }

    /// Exports the last audit event as a pretty-printed JSON string.
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    
    /// Exports all audit events as a CSV string with headers: timestamp,message,showAddButton,action,tags
    /// Each event is one line.
    static func exportCSV() -> String {
        let header = "timestamp,message,showAddButton,action,tags"
        let formatter = ISO8601DateFormatter()
        let rows = log.map { event in
            let timestamp = formatter.string(from: event.timestamp)
            // Escape quotes and commas in message and tags
            let escapedMessage = "\"\(event.message.replacingOccurrences(of: "\"", with: "\"\""))\""
            let showAddButton = event.showAddButton ? "true" : "false"
            let action = event.action ?? ""
            let escapedTags = "\"\(event.tags.joined(separator: ",").replacingOccurrences(of: "\"", with: "\"\""))\""
            return [timestamp, escapedMessage, showAddButton, action, escapedTags].joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }
    
    /// Returns the action string that appears most frequently in the log.
    static var mostFrequentAction: String {
        let actions = log.compactMap { $0.action }
        let frequency = Dictionary(grouping: actions, by: { $0 }).mapValues { $0.count }
        let mostFrequent = frequency.max { a, b in a.value < b.value }
        return mostFrequent?.key ?? "none"
    }
    
    /// Returns the total number of audit events recorded.
    static var totalEmptyStates: Int {
        log.count
    }
    
    /// Returns the accessibility label of the last event or a default message.
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
        // DEV overlay showing audit info in DEBUG builds
        .overlay(
            Group {
                #if DEBUG
                DashboardEmptyAuditDevOverlay()
                    .padding()
                    .background(Color(UIColor.systemBackground).opacity(0.9))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                #else
                EmptyView()
                #endif
            }
        )
    }
}

// MARK: - Audit/Admin Accessors

public enum DashboardEmptyAuditAdmin {
    /// Returns the accessibility summary of the last audit event.
    public static var lastSummary: String { DashboardEmptyAudit.accessibilitySummary }
    
    /// Returns the last audit event as JSON string.
    public static var lastJSON: String? { DashboardEmptyAudit.exportLastJSON() }
    
    /// Returns the last `limit` audit events as accessibility labels.
    public static func recentEvents(limit: Int = 5) -> [String] {
        DashboardEmptyAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
    
    /// Exports all audit events as CSV string.
    public static func exportCSV() -> String {
        DashboardEmptyAudit.exportCSV()
    }
    
    /// Returns the most frequent action string in the audit log.
    public static var mostFrequentAction: String {
        DashboardEmptyAudit.mostFrequentAction
    }
    
    /// Returns the total number of audit events recorded.
    public static var totalEmptyStates: Int {
        DashboardEmptyAudit.totalEmptyStates
    }
}

#if DEBUG
/// A SwiftUI view overlay showing recent audit events and statistics for development/debugging purposes.
private struct DashboardEmptyAuditDevOverlay: View {
    @State private var recentEvents: [String] = []
    @State private var mostFrequentAction: String = ""
    @State private var totalEmptyStates: Int = 0
    
    private let maxEventsToShow = 3
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Audit Log (last \(maxEventsToShow)):")
                .font(.caption)
                .bold()
            ForEach(recentEvents, id: \.self) { event in
                Text(event)
                    .font(.caption2)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Divider()
            HStack {
                Text("Most Frequent Action:")
                    .font(.caption)
                    .bold()
                Spacer()
                Text(mostFrequentAction)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            HStack {
                Text("Total Empty States:")
                    .font(.caption)
                    .bold()
                Spacer()
                Text("\(totalEmptyStates)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(Color(UIColor.secondarySystemBackground).opacity(0.85))
        .cornerRadius(8)
        .onAppear(perform: refreshData)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            refreshData()
        }
    }
    
    /// Refreshes the data displayed in the overlay from the audit log.
    private func refreshData() {
        recentEvents = DashboardEmptyAudit.log.suffix(maxEventsToShow).map { $0.accessibilityLabel }
        mostFrequentAction = DashboardEmptyAudit.mostFrequentAction
        totalEmptyStates = DashboardEmptyAudit.totalEmptyStates
    }
}

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

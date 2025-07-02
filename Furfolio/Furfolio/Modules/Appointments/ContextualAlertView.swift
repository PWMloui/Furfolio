//
//  ContextualAlertView.swift
//  Furfolio
//
//  Created by mac on 6/25/25.
//

import SwiftUI
import Combine
import AVFoundation

/// Struct representing an action button in the alert.
public struct AlertAction {
    public let label: String
    public let color: Color
    public let icon: String?
    public let role: ButtonRole?
    public let action: () -> Void
    
    public init(label: String, color: Color, icon: String? = nil, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.label = label
        self.color = color
        self.icon = icon
        self.role = role
        self.action = action
    }
}

/// A SwiftUI view that displays a contextual alert with enhanced UX, accessibility, and analytics.
public struct ContextualAlertView: View {
    public let title: String
    public let message: String
    public let actions: [AlertAction] // Up to 3 action buttons
    public let isCritical: Bool
    public let infoText: String?
    
    @State private var isInfoExpanded: Bool = false
    @State private var showAlert: Bool = true
    @State private var pulseAnimation: Bool = false
    
    /// Accessibility notification for VoiceOver announcements
    private let announcement = PassthroughSubject<String, Never>()
    
    public init(title: String,
                message: String,
                actions: [AlertAction],
                isCritical: Bool = false,
                infoText: String? = nil) {
        self.title = title
        self.message = message
        self.actions = Array(actions.prefix(3)) // Limit to 3 actions
        self.isCritical = isCritical
        self.infoText = infoText
    }
    
    public var body: some View {
        if showAlert {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    
                    // Optional info icon button to toggle expandable info text
                    if let infoText = infoText {
                        Button(action: {
                            withAnimation {
                                isInfoExpanded.toggle()
                            }
                        }) {
                            Image(systemName: "info.circle")
                                .imageScale(.large)
                                .accessibilityLabel(Text("More information"))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                Text(message)
                    .font(.body)
                
                // Expandable info text area
                if isInfoExpanded, let infoText = infoText {
                    Text(infoText)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .accessibilityLabel(Text("Additional information: \(infoText)"))
                }
                
                // Action buttons row
                HStack(spacing: 12) {
                    ForEach(Array(actions.enumerated()), id: \.offset) { _, action in
                        Button(role: action.role) {
                            action.action()
                        } label: {
                            HStack {
                                if let icon = action.icon {
                                    Image(systemName: icon)
                                }
                                Text(action.label)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(action.color.opacity(0.2))
                            .foregroundColor(action.color)
                            .cornerRadius(8)
                        }
                        .accessibilityHint(Text("Activates \(action.label)"))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(radius: 8)
                    // Animated pulse for critical alerts
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.red.opacity(pulseAnimation ? 0.6 : 0.2), lineWidth: 2)
                            .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                            .opacity(pulseAnimation ? 0 : 1)
                            .animation(isCritical ? Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true) : .default, value: pulseAnimation)
                    )
            )
            .onAppear {
                // Start pulse animation if critical
                if isCritical {
                    pulseAnimation = true
                    // Post VoiceOver announcement for critical alert
                    let announcementText = "Critical alert: \(title)"
                    UIAccessibility.post(notification: .announcement, argument: announcementText)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(isCritical ? .isSelected : [])
            .accessibilityHint(Text(isCritical ? "Critical alert" : "Alert"))
            .toolbar {
                // Add a dismiss button in the toolbar if needed
                ToolbarItem(placement: .confirmationAction) {
                    Button("Dismiss") {
                        dismissAlert()
                    }
                    .accessibilityLabel(Text("Dismiss alert"))
                }
            }
        }
    }
    
    /// Dismiss the alert and record dismissal audit event
    private func dismissAlert() {
        showAlert = false
        // Audit the dismissal event with timestamp, title, and all action labels
        let actionLabels = actions.map { $0.label }
        ContextualAlertAudit.recordDismiss(title: title, actionLabels: actionLabels, info: infoText)
    }
}

/// Static class responsible for auditing alert dismissals and exporting audit data.
public enum ContextualAlertAudit {
    private static var auditEvents: [AuditEvent] = []
    private static let auditQueue = DispatchQueue(label: "ContextualAlertAuditQueue")
    
    /// Struct representing a single audit event.
    private struct AuditEvent {
        let timestamp: Date
        let operation: String
        let title: String
        let actions: [String]
        let info: String?
        let actor: String? // Optional actor info
        let context: String? // Optional context info
        let detail: String? // Optional detail info
        
        /// Converts the audit event to a CSV row string.
        func toCSVRow() -> String {
            let dateFormatter = ISO8601DateFormatter()
            let timestampString = dateFormatter.string(from: timestamp)
            let actionsJoined = actions.joined(separator: ";")
            // Escape commas and quotes in text fields
            func escapeCSV(_ text: String?) -> String {
                guard let text = text else { return "" }
                var escaped = text.replacingOccurrences(of: "\"", with: "\"\"")
                if escaped.contains(",") || escaped.contains("\"") || escaped.contains("\n") {
                    escaped = "\"\(escaped)\""
                }
                return escaped
            }
            return [
                timestampString,
                escapeCSV(operation),
                escapeCSV(title),
                escapeCSV(actionsJoined),
                escapeCSV(info),
                escapeCSV(actor),
                escapeCSV(context),
                escapeCSV(detail)
            ].joined(separator: ",")
        }
    }
    
    /// Records a dismissal event with relevant details.
    public static func recordDismiss(title: String, actionLabels: [String], info: String? = nil, actor: String? = nil, context: String? = nil, detail: String? = nil) {
        auditQueue.async {
            let event = AuditEvent(timestamp: Date(),
                                   operation: "dismiss",
                                   title: title,
                                   actions: actionLabels,
                                   info: info,
                                   actor: actor,
                                   context: context,
                                   detail: detail)
            auditEvents.append(event)
        }
    }
}

/// Admin utility class to export audit data.
public enum ContextualAlertAuditAdmin {
    /// Exports all recorded audit events as CSV string.
    /// CSV headers: timestamp,operation,title,actions,info,actor,context,detail
    public static func exportCSV() -> String {
        let header = "timestamp,operation,title,actions,info,actor,context,detail"
        var csvRows: [String] = [header]
        let dateFormatter = ISO8601DateFormatter()
        
        // Access audit events synchronously
        var eventsCopy: [ContextualAlertAudit.AuditEvent] = []
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            ContextualAlertAudit.auditQueue.sync {
                eventsCopy = ContextualAlertAudit.auditEvents
            }
            semaphore.signal()
        }
        semaphore.wait()
        
        for event in eventsCopy {
            csvRows.append(event.toCSVRow())
        }
        return csvRows.joined(separator: "\n")
    }
}

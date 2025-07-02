//
//  DashboardTipBanner.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Modular Tip Banner
//

import SwiftUI
import Combine

// MARK: - Audit/Event Logging

fileprivate struct DashboardTipBannerAuditEvent: Codable {
    let timestamp: Date
    let message: String
    let action: String // "appear" or "dismiss"
    let tags: [String]
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[\(action.capitalized)] Tip: \(message) [\(tags.joined(separator: ","))] at \(dateStr)"
    }
}

fileprivate final class DashboardTipBannerAudit {
    static private(set) var log: [DashboardTipBannerAuditEvent] = []

    /// Records an audit event with a message, action, and optional tags.
    static func record(
        message: String,
        action: String,
        tags: [String] = ["tipBanner"]
    ) {
        let event = DashboardTipBannerAuditEvent(
            timestamp: Date(),
            message: message,
            action: action,
            tags: tags
        )
        log.append(event)
        if log.count > 30 { log.removeFirst() }
    }

    /// Exports the last audit event as a pretty-printed JSON string.
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    
    /// Exports all audit events as CSV with columns: timestamp,message,action,tags.
    static func exportCSV() -> String {
        let header = "timestamp,message,action,tags"
        let rows = log.map { event -> String in
            let dateStr = ISO8601DateFormatter().string(from: event.timestamp)
            // Escape quotes and commas in message and tags
            let escapedMessage = event.message.replacingOccurrences(of: "\"", with: "\"\"")
            let escapedTags = event.tags.joined(separator: ";").replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(dateStr)\",\"\(escapedMessage)\",\"\(event.action)\",\"\(escapedTags)\""
        }
        return ([header] + rows).joined(separator: "\n")
    }
    
    /// The most frequent tip message that appears in audit events.
    static var mostFrequentMessage: String? {
        let messages = log.map { $0.message }
        guard !messages.isEmpty else { return nil }
        let counts = Dictionary(grouping: messages, by: { $0 }).mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key
    }
    
    /// The most frequent action ("appear" or "dismiss") in audit events.
    static var mostFrequentAction: String? {
        let actions = log.map { $0.action }
        guard !actions.isEmpty else { return nil }
        let counts = Dictionary(grouping: actions, by: { $0 }).mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key
    }
    
    /// Total number of audit events recorded.
    static var totalTipsShown: Int {
        log.count
    }
    
    /// Accessibility summary for the last event.
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No tip banner events recorded."
    }
}

// MARK: - DashboardTipBanner

struct DashboardTipBanner: View {
    @Binding var isVisible: Bool
    let message: String
    
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    var body: some View {
        if isVisible {
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                    .accessibilityHidden(true)
                    .accessibilityIdentifier("DashboardTipBanner-Icon")

                Text(message)
                    .font(.body)
                    .foregroundColor(.primary)
                    .accessibilityIdentifier("DashboardTipBanner-Message")

                Spacer()

                Button(action: {
                    withAnimation {
                        isVisible = false
                        DashboardTipBannerAudit.record(
                            message: message,
                            action: "dismiss",
                            tags: ["dismiss", "tip"]
                        )
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.primary)
                        .padding(4)
                        .background(Color(UIColor.tertiarySystemFill))
                        .clipShape(Circle())
                        .accessibilityLabel("Dismiss tip")
                        .accessibilityIdentifier("DashboardTipBanner-DismissButton")
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
            )
            .padding(.horizontal)
            .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale),
                                    removal: .opacity))
            .animation(.easeInOut(duration: 0.3), value: isVisible)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Tip: \(message)")
            .accessibilityIdentifier("DashboardTipBanner-Container")
            .onAppear {
                DashboardTipBannerAudit.record(
                    message: message,
                    action: "appear",
                    tags: ["show", "tip"]
                )
                // Post VoiceOver announcement for accessibility when tip appears
                if voiceOverEnabled {
                    UIAccessibility.post(notification: .announcement, argument: "Tip: \(message)")
                }
            }
        }
    }
}

// MARK: - Audit/Admin Accessors

public enum DashboardTipBannerAuditAdmin {
    public static var lastSummary: String { DashboardTipBannerAudit.accessibilitySummary }
    public static var lastJSON: String? { DashboardTipBannerAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        DashboardTipBannerAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
    /// Expose CSV export of audit events.
    public static func exportCSV() -> String {
        DashboardTipBannerAudit.exportCSV()
    }
    /// The most frequent tip message recorded.
    public static var mostFrequentMessage: String? {
        DashboardTipBannerAudit.mostFrequentMessage
    }
    /// The most frequent action recorded.
    public static var mostFrequentAction: String? {
        DashboardTipBannerAudit.mostFrequentAction
    }
    /// Total number of tip audit events recorded.
    public static var totalTipsShown: Int {
        DashboardTipBannerAudit.totalTipsShown
    }
}

#if DEBUG
/// Developer overlay showing recent audit events and stats for debugging and analytics.
private struct DashboardTipBannerAuditOverlay: View {
    @State private var isExpanded = true
    
    private let maxEventsToShow = 3
    
    var body: some View {
        VStack(spacing: 6) {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                Text(isExpanded ? "Hide Tip Audit Info ▲" : "Show Tip Audit Info ▼")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            }
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last \(maxEventsToShow) Audit Events:")
                        .font(.caption).bold()
                    ForEach(Array(DashboardTipBannerAudit.log.suffix(maxEventsToShow).enumerated()), id: \.offset) { _, event in
                        Text("• \(event.accessibilityLabel)")
                            .font(.caption2)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    Divider()
                    Text("Most Frequent Message: \(DashboardTipBannerAudit.mostFrequentMessage ?? "N/A")")
                        .font(.caption2)
                    Text("Most Frequent Action: \(DashboardTipBannerAudit.mostFrequentAction ?? "N/A")")
                        .font(.caption2)
                    Text("Total Tips Shown: \(DashboardTipBannerAudit.totalTipsShown)")
                        .font(.caption2)
                }
                .padding(8)
                .background(Color(UIColor.systemBackground).opacity(0.9))
                .cornerRadius(10)
                .shadow(radius: 4)
                .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemBackground).opacity(0.8))
    }
}

extension DashboardTipBanner {
    /// Overlay the audit info at the bottom in DEBUG builds.
    func debugAuditOverlay() -> some View {
        self
            .overlay(
                VStack {
                    Spacer()
                    DashboardTipBannerAuditOverlay()
                }
            )
    }
}

struct DashboardTipBanner_Previews: PreviewProvider {
    @State static var visible = true
    static var previews: some View {
        VStack {
            DashboardTipBanner(isVisible: $visible, message: "Remember to follow up with customers after their appointment.")
            Spacer()
        }
        .padding()
        .previewLayout(.sizeThatFits)
        // Show audit overlay in debug preview
        .if(DEBUG) { view in
            view.debugAuditOverlay()
        }
    }
}
#endif

// MARK: - View Modifier for Conditional Modifier

extension View {
    /// Applies the given transform if the condition is true.
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

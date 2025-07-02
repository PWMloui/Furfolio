//
//  ComplianceDashboardView.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import SwiftUI
import Combine
import AVFoundation

/// Struct representing an audit event for the Compliance Dashboard.
/// Logs timestamp, operation performed, section affected, detail info, tags, actor, and context.
public struct ComplianceDashboardAuditEvent: Codable, Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let operation: String
    public let section: String
    public let detail: String
    public let tags: [String]
    public let actor: String
    public let context: String
}

/// Class responsible for managing audit events of the Compliance Dashboard.
/// Supports logging events and provides analytics on the audit data.
public class ComplianceDashboardAudit: ObservableObject {
    @Published private(set) var events: [ComplianceDashboardAuditEvent] = []
    
    /// Logs a new audit event with given parameters.
    public func logEvent(operation: String, section: String, detail: String = "", tags: [String] = [], actor: String = "unknown", context: String = "") {
        let event = ComplianceDashboardAuditEvent(timestamp: Date(), operation: operation, section: section, detail: detail, tags: tags, actor: actor, context: context)
        DispatchQueue.main.async {
            self.events.append(event)
        }
    }
    
    /// Computed property returning total number of "load" or "viewDetail" events.
    public var totalViews: Int {
        events.filter { $0.operation == "load" || $0.operation == "viewDetail" }.count
    }
    
    /// Computed property returning the section most frequently viewed.
    public var mostViewedSection: String {
        let viewEvents = events.filter { $0.operation == "load" || $0.operation == "viewDetail" }
        let counts = Dictionary(grouping: viewEvents, by: { $0.section }).mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key ?? "None"
    }
    
    /// Computed property returning total number of "export" events.
    public var totalExports: Int {
        events.filter { $0.operation == "export" }.count
    }
}

/// Public admin interface for accessing audit summaries and exporting audit data.
public class ComplianceDashboardAuditAdmin {
    private let audit: ComplianceDashboardAudit
    
    public init(audit: ComplianceDashboardAudit) {
        self.audit = audit
    }
    
    /// Returns a string summary of the last audit event.
    public var lastSummary: String {
        guard let last = audit.events.last else { return "No events logged" }
        return "[\(last.timestamp)] \(last.operation) in \(last.section) by \(last.actor)"
    }
    
    /// Returns the last audit event as JSON string.
    public var lastJSON: String {
        guard let last = audit.events.last else { return "{}" }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(last), let json = String(data: data, encoding: .utf8) {
            return json
        }
        return "{}"
    }
    
    /// Returns the most recent audit events up to the specified limit.
    public func recentEvents(limit: Int) -> [ComplianceDashboardAuditEvent] {
        Array(audit.events.suffix(limit))
    }
    
    /// Exports all audit events as CSV string with columns:
    /// timestamp,operation,section,detail,tags,actor,context
    public func exportCSV() -> String {
        var csv = "timestamp,operation,section,detail,tags,actor,context\n"
        for event in audit.events {
            let tagsString = event.tags.joined(separator: ";")
            let line = "\"\(event.timestamp)\",\"\(event.operation)\",\"\(event.section)\",\"\(event.detail)\",\"\(tagsString)\",\"\(event.actor)\",\"\(event.context)\"\n"
            csv.append(line)
        }
        return csv
    }
    
    /// Expose analytics properties
    public var totalViews: Int { audit.totalViews }
    public var mostViewedSection: String { audit.mostViewedSection }
    public var totalExports: Int { audit.totalExports }
}

/// SwiftUI View representing the Compliance Dashboard.
/// Includes audit logging, analytics, accessibility announcements, and a debug overlay.
struct ComplianceDashboardView: View {
    @StateObject private var audit = ComplianceDashboardAudit()
    private var auditAdmin: ComplianceDashboardAuditAdmin
    
    init() {
        let auditInstance = ComplianceDashboardAudit()
        _audit = StateObject(wrappedValue: auditInstance)
        auditAdmin = ComplianceDashboardAuditAdmin(audit: auditInstance)
    }
    
    var body: some View {
        VStack {
            // Example compliance sections
            List {
                Button("Load Compliance Section A") {
                    logAndAnnounce(operation: "load", section: "Section A")
                }
                Button("View Detail in Section A") {
                    logAndAnnounce(operation: "viewDetail", section: "Section A")
                }
                Button("Export Compliance Report") {
                    logAndAnnounce(operation: "export", section: "Section A")
                }
                Button("Acknowledge Compliance Issue") {
                    logAndAnnounce(operation: "acknowledge", section: "Section A")
                }
            }
            #if DEBUG
            DebugAuditOverlay(auditAdmin: auditAdmin)
                .frame(height: 120)
                .background(Color.black.opacity(0.7))
                .foregroundColor(.white)
            #endif
        }
    }
    
    /// Logs an audit event and posts a VoiceOver announcement summarizing the action.
    private func logAndAnnounce(operation: String, section: String) {
        audit.logEvent(operation: operation, section: section, actor: "user", context: "ComplianceDashboardView")
        let announcement = announcementMessage(operation: operation, section: section)
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }
    
    /// Generates a VoiceOver announcement message based on operation and section.
    private func announcementMessage(operation: String, section: String) -> String {
        switch operation {
        case "load":
            return "Compliance section \(section) loaded"
        case "viewDetail":
            return "Compliance section \(section) viewed"
        case "export":
            return "Compliance section \(section) exported"
        case "acknowledge":
            return "Compliance issue in section \(section) acknowledged"
        default:
            return "Compliance section \(section) operation \(operation) performed"
        }
    }
}

/// Debug overlay view showing recent audit events and analytics.
/// Only visible in DEBUG builds.
#if DEBUG
struct DebugAuditOverlay: View {
    let auditAdmin: ComplianceDashboardAuditAdmin
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Audit Debug Overlay")
                .font(.headline)
            Text("Total Views: \(auditAdmin.totalViews)")
            Text("Most Viewed Section: \(auditAdmin.mostViewedSection)")
            Text("Recent Events:")
                .font(.subheadline)
            ForEach(auditAdmin.recentEvents(limit: 3)) { event in
                Text("\(event.timestamp, formatter: dateFormatter): \(event.operation) in \(event.section)")
                    .font(.caption)
                    .lineLimit(1)
            }
        }
        .padding(8)
    }
    
    private var dateFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss"
        return df
    }
}
#endif

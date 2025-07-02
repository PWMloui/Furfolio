//
//  IncidentReportFormView.swift
//  Furfolio
//
//  Business, Compliance, and Analytics Enhancements:
//  - Audit/event logging (IncidentReportAuditEvent, IncidentReportAudit)
//  - Audit admin (IncidentReportAuditAdmin)
//  - Analytics (totalReports, mostFrequentIncidentType, lastSevereIncidentDate)
//  - Accessibility (VoiceOver announcements on submit/cancel/edit)
//  - DEV overlay (shows recent audit events, analytics)
//
//  See inline documentation for details.
//
//
//  IncidentReportFormView.swift
//  Furfolio
//
//  Created by mac on 6/25/25.
//



import SwiftUI
import Combine

// MARK: - Audit/Event Logging

/// Represents a single audit/event log for incident report form actions.
/// Conforms to Codable for persistence or export.
struct IncidentReportAuditEvent: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let operation: String // e.g., "start", "edit", "submit", "cancel", "exportCSV"
    let reportID: String?
    let incidentType: String?
    let ownerName: String?
    let dogName: String?
    let date: Date?
    let severity: String?
    let notes: String?
    let tags: [String]?
    let actor: String? // e.g., username or device owner
    let context: String? // e.g., "IncidentReportFormView"
    let detail: String? // extra info
    
    /// Readable summary for display or accessibility
    var summary: String {
        let base = "\(operation.capitalized) [\(incidentType ?? "-")], \(dogName ?? "-") (\(severity ?? "-"))"
        return "\(base) at \(timestamp.formatted())"
    }
}

/// Singleton audit logger for incident report form actions.
/// Stores events in memory; can be extended to persist.
final class IncidentReportAudit: ObservableObject {
    static let shared = IncidentReportAudit()
    @Published private(set) var events: [IncidentReportAuditEvent] = []
    private let queue = DispatchQueue(label: "IncidentReportAudit")
    
    private init() {}
    
    /// Log an audit event.
    func log(operation: String,
             reportID: String? = nil,
             incidentType: String? = nil,
             ownerName: String? = nil,
             dogName: String? = nil,
             date: Date? = nil,
             severity: String? = nil,
             notes: String? = nil,
             tags: [String]? = nil,
             actor: String? = nil,
             context: String? = nil,
             detail: String? = nil)
    {
        let event = IncidentReportAuditEvent(
            id: UUID(),
            timestamp: Date(),
            operation: operation,
            reportID: reportID,
            incidentType: incidentType,
            ownerName: ownerName,
            dogName: dogName,
            date: date,
            severity: severity,
            notes: notes,
            tags: tags,
            actor: actor,
            context: context,
            detail: detail
        )
        queue.async {
            DispatchQueue.main.async {
                self.events.append(event)
            }
        }
    }
    
    /// Computed: total submitted reports.
    var totalReports: Int {
        events.filter { $0.operation == "submit" }.count
    }
    
    /// Computed: most frequent incidentType among submitted reports.
    var mostFrequentIncidentType: String? {
        let submitted = events.compactMap { $0.operation == "submit" ? $0.incidentType : nil }
        let freq = Dictionary(grouping: submitted, by: { $0 }).mapValues(\.count)
        return freq.max(by: { $0.value < $1.value })?.key
    }
    
    /// Computed: date of the last "Critical" or "High" severity submitted incident.
    var lastSevereIncidentDate: Date? {
        events
            .filter { $0.operation == "submit" && ($0.severity == "Critical" || $0.severity == "High") }
            .sorted(by: { $0.timestamp > $1.timestamp })
            .first?.timestamp
    }
}

// MARK: - Audit Admin

/// Admin interface to audit log and analytics.
public class IncidentReportAuditAdmin {
    public static let shared = IncidentReportAuditAdmin()
    private let audit = IncidentReportAudit.shared
    
    /// Last event as readable summary.
    public var lastSummary: String? {
        audit.events.last?.summary
    }
    /// Last event as JSON.
    public var lastJSON: String? {
        guard let last = audit.events.last else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    /// Recent events (default limit 10)
    public func recentEvents(limit: Int = 10) -> [IncidentReportAuditEvent] {
        Array(audit.events.suffix(limit))
    }
    /// Export all events as CSV.
    public func exportCSV() -> String {
        var csv = "timestamp,operation,reportID,incidentType,ownerName,dogName,date,severity,notes,tags,actor,context,detail\n"
        let df = ISO8601DateFormatter()
        for e in audit.events {
            let row: [String] = [
                df.string(from: e.timestamp),
                e.operation,
                e.reportID ?? "",
                e.incidentType ?? "",
                e.ownerName ?? "",
                e.dogName ?? "",
                e.date.map { df.string(from: $0) } ?? "",
                e.severity ?? "",
                e.notes?.replacingOccurrences(of: "\n", with: " ") ?? "",
                e.tags?.joined(separator: ";") ?? "",
                e.actor ?? "",
                e.context ?? "",
                e.detail ?? ""
            ].map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }
            csv.append(row.joined(separator: ",") + "\n")
        }
        return csv
    }
    /// Analytics: total submitted reports.
    public var totalReports: Int { audit.totalReports }
    /// Analytics: most frequent incident type.
    public var mostFrequentIncidentType: String? { audit.mostFrequentIncidentType }
    /// Analytics: last severe incident date.
    public var lastSevereIncidentDate: Date? { audit.lastSevereIncidentDate }
}

// MARK: - Accessibility (VoiceOver Announcements)

import AVFoundation

/// Posts a VoiceOver announcement for accessibility.
func postVoiceOverAnnouncement(_ message: String) {
    UIAccessibility.post(notification: .announcement, argument: message)
}

// MARK: - SwiftUI IncidentReportFormView (Sample Usage)

/// Example form view with audit logging, accessibility, and DEV overlay.
struct IncidentReportFormView: View {
    @ObservedObject private var audit = IncidentReportAudit.shared
    // Example form fields (replace with actual model/binding as needed)
    @State private var reportID: String = UUID().uuidString
    @State private var incidentType: String = ""
    @State private var ownerName: String = ""
    @State private var dogName: String = ""
    @State private var date: Date = Date()
    @State private var severity: String = ""
    @State private var notes: String = ""
    @State private var tags: String = ""
    @State private var actor: String = "user"
    @State private var context: String = "IncidentReportFormView"
    @State private var showExportSheet = false
    
    var body: some View {
        VStack {
            Form {
                Section(header: Text("Incident Details")) {
                    TextField("Incident Type", text: $incidentType)
                    TextField("Owner Name", text: $ownerName)
                    TextField("Dog Name", text: $dogName)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Severity", text: $severity)
                    TextField("Notes", text: $notes)
                    TextField("Tags (comma separated)", text: $tags)
                }
                Section {
                    Button("Submit") {
                        // Log submit event
                        audit.log(
                            operation: "submit",
                            reportID: reportID,
                            incidentType: incidentType,
                            ownerName: ownerName,
                            dogName: dogName,
                            date: date,
                            severity: severity,
                            notes: notes,
                            tags: tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) },
                            actor: actor,
                            context: context,
                            detail: nil
                        )
                        // Accessibility: VoiceOver announcement
                        let msg = "Incident report submitted for \(dogName): \(incidentType), \(severity) severity."
                        postVoiceOverAnnouncement(msg)
                    }
                    Button("Cancel") {
                        // Log cancel event
                        audit.log(
                            operation: "cancel",
                            reportID: reportID,
                            incidentType: incidentType,
                            ownerName: ownerName,
                            dogName: dogName,
                            date: date,
                            severity: severity,
                            notes: notes,
                            tags: tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) },
                            actor: actor,
                            context: context,
                            detail: nil
                        )
                        // Accessibility: VoiceOver announcement
                        let msg = "Incident report cancelled for \(dogName): \(incidentType)."
                        postVoiceOverAnnouncement(msg)
                    }
                    Button("Edit") {
                        // Log edit event
                        audit.log(
                            operation: "edit",
                            reportID: reportID,
                            incidentType: incidentType,
                            ownerName: ownerName,
                            dogName: dogName,
                            date: date,
                            severity: severity,
                            notes: notes,
                            tags: tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) },
                            actor: actor,
                            context: context,
                            detail: nil
                        )
                        // Accessibility: VoiceOver announcement
                        let msg = "Incident report edited for \(dogName): \(incidentType), \(severity) severity."
                        postVoiceOverAnnouncement(msg)
                    }
                    Button("Export CSV") {
                        // Log export event
                        audit.log(
                            operation: "exportCSV",
                            reportID: nil,
                            incidentType: nil,
                            ownerName: nil,
                            dogName: nil,
                            date: nil,
                            severity: nil,
                            notes: nil,
                            tags: nil,
                            actor: actor,
                            context: context,
                            detail: "Exported audit log CSV"
                        )
                        showExportSheet = true
                    }
                }
            }
        }
#if DEBUG
        // DEV overlay: shows last 3 audit events, analytics at the bottom
        .overlay(
            VStack(alignment: .leading, spacing: 4) {
                Divider()
                Text("DEV Audit Overlay")
                    .font(.caption).bold()
                ForEach(audit.events.suffix(3)) { event in
                    Text(event.summary)
                        .font(.caption2)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Text("Total Reports: \(audit.totalReports)")
                    .font(.caption2)
                if let freq = audit.mostFrequentIncidentType {
                    Text("Most Frequent: \(freq)")
                        .font(.caption2)
                }
            }
            .padding(8)
            .background(Color(.systemGray6).opacity(0.85))
            .cornerRadius(8)
            .shadow(radius: 2)
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            , alignment: .bottom
        )
#endif
        // Export CSV sheet (for demonstration)
        .sheet(isPresented: $showExportSheet) {
            let csv = IncidentReportAuditAdmin.shared.exportCSV()
            ScrollView {
                Text(csv)
                    .font(.system(.footnote, design: .monospaced))
                    .padding()
            }
        }
    }
}

// MARK: - SwiftUI Preview

#if DEBUG
struct IncidentReportFormView_Previews: PreviewProvider {
    static var previews: some View {
        IncidentReportFormView()
    }
}
#endif

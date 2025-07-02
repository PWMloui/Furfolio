//
//  ExpiredDocumentsView.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import SwiftUI
import Combine
import AVFoundation

// MARK: - Audit Event Model
/// Represents a single audit event related to expired document operations.
/// Conforms to Codable for easy serialization and deserialization.
struct ExpiredDocumentAuditEvent: Codable, Identifiable {
    let id = UUID()
    let timestamp: Date
    let operation: String // e.g., "load", "view", "export", "delete", "renew"
    let documentID: String
    let documentType: String
    let ownerName: String
    let petName: String
    let expiryDate: Date
    let status: String // e.g., "expired", "valid"
    let tags: [String]
    let actor: String // user performing the action
    let context: String // additional context info
    let detail: String // detailed description or notes
}

// MARK: - Audit Manager
/// Manages audit events for expired documents, including logging and analytics.
class ExpiredDocumentAudit: ObservableObject {
    /// Published list of all audit events.
    @Published private(set) var events: [ExpiredDocumentAuditEvent] = []
    
    /// Singleton instance for global access.
    static let shared = ExpiredDocumentAudit()
    
    private init() {}
    
    /// Logs a new audit event.
    /// - Parameter event: The audit event to log.
    func logEvent(_ event: ExpiredDocumentAuditEvent) {
        DispatchQueue.main.async {
            self.events.append(event)
        }
    }
    
    /// Computed property returning the number of "load" or "view" events with status "expired".
    var totalExpired: Int {
        events.filter {
            ($0.operation == "load" || $0.operation == "view") && $0.status.lowercased() == "expired"
        }.count
    }
    
    /// Computed property returning the most frequent document type among "load" and "view" events.
    var mostFrequentDocumentType: String? {
        let filtered = events.filter { $0.operation == "load" || $0.operation == "view" }
        let typesCount = Dictionary(grouping: filtered, by: { $0.documentType })
            .mapValues { $0.count }
        return typesCount.max(by: { $0.value < $1.value })?.key
    }
    
    /// Computed property returning the documentID of the last "export" event.
    var lastExportedDocumentID: String? {
        events.last(where: { $0.operation == "export" })?.documentID
    }
}

// MARK: - Audit Admin Interface
/// Provides admin access to audit summaries, recent events, and export functionality.
public class ExpiredDocumentAuditAdmin {
    private let audit = ExpiredDocumentAudit.shared
    
    /// Returns the last audit event as a formatted string summary.
    public var lastSummary: String {
        guard let last = audit.events.last else { return "No audit events logged." }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        let dateStr = formatter.string(from: last.timestamp)
        return "[\(dateStr)] \(last.operation.capitalized) \(last.documentType) for \(last.petName)"
    }
    
    /// Returns the last audit event serialized as JSON string.
    public var lastJSON: String {
        guard let last = audit.events.last else { return "{}" }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(last) {
            return String(data: data, encoding: .utf8) ?? "{}"
        }
        return "{}"
    }
    
    /// Returns recent audit events limited by the specified count.
    /// - Parameter limit: Maximum number of events to return.
    /// - Returns: Array of recent audit events.
    public func recentEvents(limit: Int) -> [ExpiredDocumentAuditEvent] {
        let count = audit.events.count
        guard count > 0 else { return [] }
        let start = max(count - limit, 0)
        return Array(audit.events[start..<count])
    }
    
    /// Exports all audit events to CSV format.
    /// CSV columns: timestamp,operation,documentID,documentType,ownerName,petName,expiryDate,status,tags,actor,context,detail
    /// - Returns: CSV string of all audit events.
    public func exportCSV() -> String {
        let formatter = ISO8601DateFormatter()
        let header = "timestamp,operation,documentID,documentType,ownerName,petName,expiryDate,status,tags,actor,context,detail"
        let rows = audit.events.map { event in
            let timestamp = formatter.string(from: event.timestamp)
            let expiryDate = formatter.string(from: event.expiryDate)
            let tags = event.tags.joined(separator: "|") // use pipe to separate tags
            // Escape commas and quotes in text fields
            func escape(_ text: String) -> String {
                var escaped = text.replacingOccurrences(of: "\"", with: "\"\"")
                if escaped.contains(",") || escaped.contains("\n") || escaped.contains("\"") {
                    escaped = "\"\(escaped)\""
                }
                return escaped
            }
            return [
                timestamp,
                escape(event.operation),
                escape(event.documentID),
                escape(event.documentType),
                escape(event.ownerName),
                escape(event.petName),
                expiryDate,
                escape(event.status),
                escape(tags),
                escape(event.actor),
                escape(event.context),
                escape(event.detail)
            ].joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }
    
    /// Exposes total expired count from audit.
    public var totalExpired: Int {
        audit.totalExpired
    }
    
    /// Exposes most frequent document type from audit.
    public var mostFrequentDocumentType: String? {
        audit.mostFrequentDocumentType
    }
    
    /// Exposes last exported document ID from audit.
    public var lastExportedDocumentID: String? {
        audit.lastExportedDocumentID
    }
}

// MARK: - Accessibility Helper
/// Posts a VoiceOver announcement summarizing an audit event action.
/// - Parameters:
///   - documentType: The type of the document involved.
///   - petName: The name of the pet.
///   - operation: The operation performed (e.g., "exported").
///   - additionalInfo: Optional additional info to include.
func postVoiceOverAnnouncement(documentType: String, petName: String, operation: String, additionalInfo: String? = nil) {
    var announcement = "\(documentType.capitalized) for \(petName) \(operation)."
    if let info = additionalInfo {
        announcement += " \(info)"
    }
    DispatchQueue.main.async {
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }
}

// MARK: - ExpiredDocumentsView
/// Main view displaying expired documents and handling user actions with audit logging and accessibility.
struct ExpiredDocumentsView: View {
    @State private var expiredDocuments: [ExpiredDocument] = [] // Assuming ExpiredDocument is defined elsewhere
    @ObservedObject private var audit = ExpiredDocumentAudit.shared
    
    // For demo purposes, simulate owner and pet info
    private let ownerName = "John Doe"
    private let actor = "John Doe" // current user
    
    var body: some View {
        VStack {
            List(expiredDocuments) { document in
                VStack(alignment: .leading) {
                    Text(document.documentType)
                        .font(.headline)
                    Text("Pet: \(document.petName)")
                    Text("Expires: \(document.expiryDate, formatter: dateFormatter)")
                }
                .onAppear {
                    logEvent(operation: "view", document: document, detail: "Document viewed in list")
                }
                .contextMenu {
                    Button("Export") {
                        exportDocument(document)
                    }
                    Button("Delete") {
                        deleteDocument(document)
                    }
                    Button("Renew") {
                        renewDocument(document)
                    }
                }
            }
#if DEBUG
            // DEV overlay showing last 3 audit events, total expired, and most frequent document type.
            VStack(alignment: .leading, spacing: 4) {
                Divider()
                Text("Audit DEV Overlay")
                    .font(.headline)
                ForEach(audit.events.suffix(3)) { event in
                    Text("\(event.timestamp, formatter: dateFormatter): \(event.operation.capitalized) \(event.documentType) for \(event.petName)")
                        .font(.caption)
                        .lineLimit(1)
                }
                Text("Total Expired Docs: \(audit.totalExpired)")
                    .font(.caption)
                Text("Most Frequent Document Type: \(audit.mostFrequentDocumentType ?? "N/A")")
                    .font(.caption)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
#endif
        }
        .onAppear(perform: loadDocuments)
    }
    
    // MARK: - Helper Methods
    
    /// Loads expired documents and logs the load event for each.
    private func loadDocuments() {
        // Simulate loading documents
        // expiredDocuments = ... load from data source
        
        // For each document loaded, log the "load" event
        for document in expiredDocuments {
            logEvent(operation: "load", document: document, detail: "Documents loaded on view appear")
        }
    }
    
    /// Logs an audit event for a given operation and document.
    private func logEvent(operation: String, document: ExpiredDocument, detail: String) {
        let event = ExpiredDocumentAuditEvent(
            timestamp: Date(),
            operation: operation,
            documentID: document.id,
            documentType: document.documentType,
            ownerName: ownerName,
            petName: document.petName,
            expiryDate: document.expiryDate,
            status: document.status,
            tags: document.tags,
            actor: actor,
            context: "ExpiredDocumentsView",
            detail: detail
        )
        audit.logEvent(event)
        
        // Post accessibility announcement for relevant operations
        if ["view", "export", "delete", "renew"].contains(operation) {
            postVoiceOverAnnouncement(documentType: document.documentType, petName: document.petName, operation: operation)
        }
    }
    
    /// Handles exporting a document.
    private func exportDocument(_ document: ExpiredDocument) {
        // Perform export logic here
        
        logEvent(operation: "export", document: document, detail: "Document exported by user")
    }
    
    /// Handles deleting a document.
    private func deleteDocument(_ document: ExpiredDocument) {
        // Perform delete logic here
        if let index = expiredDocuments.firstIndex(where: { $0.id == document.id }) {
            expiredDocuments.remove(at: index)
        }
        logEvent(operation: "delete", document: document, detail: "Document deleted by user")
    }
    
    /// Handles renewing a document.
    private func renewDocument(_ document: ExpiredDocument) {
        // Perform renew logic here
        
        logEvent(operation: "renew", document: document, detail: "Document renewed by user")
    }
    
    /// DateFormatter for display
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
}

// MARK: - ExpiredDocument Model Placeholder
/// Placeholder struct representing an expired document.
/// Replace or extend this with the real model as needed.
struct ExpiredDocument: Identifiable {
    let id: String
    let documentType: String
    let petName: String
    let expiryDate: Date
    let status: String
    let tags: [String]
}

// MARK: - Preview
struct ExpiredDocumentsView_Previews: PreviewProvider {
    static var previews: some View {
        ExpiredDocumentsView(expiredDocuments: sampleDocuments)
    }
    
    static var sampleDocuments: [ExpiredDocument] = [
        ExpiredDocument(id: "doc1", documentType: "Rabies Certificate", petName: "Bailey", expiryDate: Date().addingTimeInterval(-86400), status: "expired", tags: ["vaccination"]),
        ExpiredDocument(id: "doc2", documentType: "License", petName: "Max", expiryDate: Date().addingTimeInterval(-172800), status: "expired", tags: ["license"]),
        ExpiredDocument(id: "doc3", documentType: "Microchip", petName: "Luna", expiryDate: Date().addingTimeInterval(-3600), status: "expired", tags: ["microchip"])
    ]
}

//
//  TopClientsView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Modular Top Clients View
//

import SwiftUI
import Combine
import AVFoundation

// MARK: - Audit/Event Logging

fileprivate struct TopClientsAuditEvent: Codable {
    let timestamp: Date
    let action: String    // "appear", "search", "load"
    let searchText: String?
    let clientCount: Int
    let visibleClientNames: [String]
    let tags: [String]
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        var base = "[\(action.capitalized)] \(clientCount) clients"
        if let text = searchText, !text.isEmpty { base += ", search: \"\(text)\"" }
        if !visibleClientNames.isEmpty { base += ", names: [\(visibleClientNames.joined(separator: ", "))]" }
        if !tags.isEmpty { base += " [\(tags.joined(separator: ","))]" }
        base += " at \(dateStr)"
        return base
    }
}

fileprivate final class TopClientsAudit {
    static private(set) var log: [TopClientsAuditEvent] = []

    /// Records a new audit event with provided details.
    static func record(
        action: String,
        searchText: String? = nil,
        clientCount: Int,
        visibleClientNames: [String],
        tags: [String] = ["topClients"]
    ) {
        let event = TopClientsAuditEvent(
            timestamp: Date(),
            action: action,
            searchText: searchText,
            clientCount: clientCount,
            visibleClientNames: visibleClientNames,
            tags: tags
        )
        log.append(event)
        if log.count > 40 { log.removeFirst() }
    }

    /// Exports the last audit event as a pretty-printed JSON string.
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    /// Accessibility summary for the last event.
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No top clients events recorded."
    }

    // MARK: - New Enhancements

    /// Exports the entire audit log as CSV string with columns:
    /// timestamp,action,searchText,clientCount,visibleClientNames,tags
    static func exportCSV() -> String {
        let header = "timestamp,action,searchText,clientCount,visibleClientNames,tags"
        let rows = log.map { event -> String in
            // Escape commas and quotes for CSV format
            func escape(_ str: String) -> String {
                var escaped = str.replacingOccurrences(of: "\"", with: "\"\"")
                if escaped.contains(",") || escaped.contains("\"") || escaped.contains("\n") {
                    escaped = "\"\(escaped)\""
                }
                return escaped
            }
            let dateStr = ISO8601DateFormatter().string(from: event.timestamp)
            let action = escape(event.action)
            let searchText = escape(event.searchText ?? "")
            let clientCount = String(event.clientCount)
            let visibleNames = escape(event.visibleClientNames.joined(separator: ";"))
            let tags = escape(event.tags.joined(separator: ";"))
            return [dateStr, action, searchText, clientCount, visibleNames, tags].joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }

    /// Returns the action string that appears most frequently in the log.
    static var mostFrequentAction: String? {
        guard !log.isEmpty else { return nil }
        let counts = Dictionary(grouping: log, by: { $0.action }).mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    /// Returns the most frequently searched text (ignores nil or empty).
    static var mostSearchedText: String? {
        let filtered = log.compactMap { $0.searchText?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !filtered.isEmpty else { return nil }
        let counts = Dictionary(grouping: filtered, by: { $0 }).mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    /// Total number of audit events recorded.
    static var totalEvents: Int {
        log.count
    }
}

// MARK: - Model

struct Client: Identifiable {
    var id: UUID
    var name: String
    var totalRevenue: Double
    var appointmentsCount: Int
}

// MARK: - TopClientsView

struct TopClientsView: View {
    @State private var searchText: String = ""
    @State private var clients: [Client] = []

    private var filteredClients: [Client] {
        if searchText.isEmpty {
            return clients
        } else {
            return clients.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if filteredClients.isEmpty {
                    Text("No clients found.")
                        .foregroundColor(.secondary)
                        .accessibilityLabel("No clients found")
                        .accessibilityIdentifier("TopClientsView-Empty")
                } else {
                    ForEach(filteredClients) { client in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(client.name)
                                    .font(.headline)
                                    .accessibilityIdentifier("TopClientsView-Name-\(client.name)")
                                Text("\(client.appointmentsCount) appointments")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .accessibilityIdentifier("TopClientsView-Appointments-\(client.name)")
                            }
                            Spacer()
                            Text("$\(String(format: "%.2f", client.totalRevenue))")
                                .font(.headline)
                                .foregroundColor(.green)
                                .accessibilityIdentifier("TopClientsView-Revenue-\(client.name)")
                        }
                        .padding(.vertical, 6)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(client.name), \(client.appointmentsCount) appointments, total revenue \(String(format: "%.2f", client.totalRevenue)) dollars")
                        .accessibilityIdentifier("TopClientsView-Row-\(client.name)")
                    }
                }
            }
            .navigationTitle("Top Clients")
            .searchable(text: $searchText, prompt: "Search clients")
            .accessibilityIdentifier("TopClientsView-List")
            .onAppear {
                loadSampleClients()
                TopClientsAudit.record(
                    action: "appear",
                    searchText: nil,
                    clientCount: filteredClients.count,
                    visibleClientNames: filteredClients.map { $0.name }
                )
                // Accessibility: Post VoiceOver announcement on appear
                postVoiceOverAnnouncement(clientCount: filteredClients.count, action: "appear")
            }
            .onChange(of: searchText) { newValue in
                TopClientsAudit.record(
                    action: "search",
                    searchText: newValue,
                    clientCount: filteredClients.count,
                    visibleClientNames: filteredClients.map { $0.name },
                    tags: ["search"]
                )
                // Accessibility: Post VoiceOver announcement on search
                postVoiceOverAnnouncement(clientCount: filteredClients.count, action: "search")
            }
            // DEV overlay showing audit info in DEBUG builds
            .overlay(
                Group {
                    #if DEBUG
                    AuditDebugOverlay()
                        .padding()
                        .background(Color(.systemBackground).opacity(0.9))
                        .cornerRadius(10)
                        .shadow(radius: 4)
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    #endif
                }
            )
        }
    }

    /// Loads sample clients and records a load event.
    private func loadSampleClients() {
        clients = [
            Client(id: UUID(), name: "Alice Johnson", totalRevenue: 1200.50, appointmentsCount: 5),
            Client(id: UUID(), name: "Bob Smith", totalRevenue: 950.75, appointmentsCount: 4),
            Client(id: UUID(), name: "Carol Davis", totalRevenue: 870.00, appointmentsCount: 3),
            Client(id: UUID(), name: "David Brown", totalRevenue: 650.25, appointmentsCount: 2),
            Client(id: UUID(), name: "Eva Wilson", totalRevenue: 500.00, appointmentsCount: 1)
        ]
        TopClientsAudit.record(
            action: "load",
            clientCount: clients.count,
            visibleClientNames: clients.map { $0.name },
            tags: ["load"]
        )
    }

    /// Posts a VoiceOver announcement with the given client count and action.
    /// - Parameters:
    ///   - clientCount: Number of visible clients.
    ///   - action: The action that triggered the announcement.
    private func postVoiceOverAnnouncement(clientCount: Int, action: String) {
        #if os(iOS)
        let announcement = "Top Clients updated: \(clientCount) visible. Action: \(action)."
        UIAccessibility.post(notification: .announcement, argument: announcement)
        #endif
    }
}

// MARK: - Audit/Admin Accessors

public enum TopClientsAuditAdmin {
    public static var lastSummary: String { TopClientsAudit.accessibilitySummary }
    public static var lastJSON: String? { TopClientsAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        TopClientsAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }

    // MARK: - New Exposed Analytics

    /// Exports the entire audit log as CSV.
    public static func exportCSV() -> String {
        TopClientsAudit.exportCSV()
    }

    /// Most frequent action string in the audit log.
    public static var mostFrequentAction: String? {
        TopClientsAudit.mostFrequentAction
    }

    /// Most frequently searched text in the audit log.
    public static var mostSearchedText: String? {
        TopClientsAudit.mostSearchedText
    }

    /// Total number of audit events recorded.
    public static var totalEvents: Int {
        TopClientsAudit.totalEvents
    }
}

// MARK: - DEV Overlay View

#if DEBUG
/// A SwiftUI overlay view showing recent audit events and analytics for development/debugging purposes.
private struct AuditDebugOverlay: View {
    private let recentEvents: [String] = TopClientsAudit.log.suffix(3).map { $0.accessibilityLabel }
    private let mostFrequentAction: String = TopClientsAudit.mostFrequentAction ?? "N/A"
    private let mostSearchedText: String = TopClientsAudit.mostSearchedText ?? "N/A"
    private let totalEvents: Int = TopClientsAudit.totalEvents

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("🛠️ Audit Debug Info")
                .font(.headline)
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                Text("Recent Events:")
                    .font(.subheadline).bold()
                ForEach(recentEvents.indices, id: \.self) { idx in
                    Text("\(idx + 1). \(recentEvents[idx])")
                        .font(.caption)
                        .lineLimit(2)
                        .minimumScaleFactor(0.5)
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 2) {
                Text("Most Frequent Action: \(mostFrequentAction)")
                    .font(.caption)
                Text("Most Searched Text: \(mostSearchedText)")
                    .font(.caption)
                Text("Total Events: \(totalEvents)")
                    .font(.caption)
            }
        }
        .padding(8)
        .background(Color(.secondarySystemBackground).opacity(0.95))
        .cornerRadius(8)
        .shadow(radius: 4)
        .frame(maxWidth: 350)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Audit debug overlay showing recent events and analytics.")
    }
}
#endif

#if DEBUG
struct TopClientsView_Previews: PreviewProvider {
    static var previews: some View {
        TopClientsView()
    }
}
#endif

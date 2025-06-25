//
//  TopClientsView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Modular Top Clients View
//

import SwiftUI

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

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No top clients events recorded."
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
            }
            .onChange(of: searchText) { newValue in
                TopClientsAudit.record(
                    action: "search",
                    searchText: newValue,
                    clientCount: filteredClients.count,
                    visibleClientNames: filteredClients.map { $0.name },
                    tags: ["search"]
                )
            }
        }
    }

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
}

// MARK: - Audit/Admin Accessors

public enum TopClientsAuditAdmin {
    public static var lastSummary: String { TopClientsAudit.accessibilitySummary }
    public static var lastJSON: String? { TopClientsAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        TopClientsAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
}

#if DEBUG
struct TopClientsView_Previews: PreviewProvider {
    static var previews: some View {
        TopClientsView()
    }
}
#endif

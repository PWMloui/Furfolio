//
//  TopClientsView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//


import SwiftUI

struct Client: Identifiable {
    var id: UUID
    var name: String
    var totalRevenue: Double
    var appointmentsCount: Int
}

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
                } else {
                    ForEach(filteredClients) { client in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(client.name)
                                    .font(.headline)
                                Text("\(client.appointmentsCount) appointments")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("$\(String(format: "%.2f", client.totalRevenue))")
                                .font(.headline)
                                .foregroundColor(.green)
                        }
                        .padding(.vertical, 6)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(client.name), \(client.appointmentsCount) appointments, total revenue \(String(format: "%.2f", client.totalRevenue)) dollars")
                    }
                }
            }
            .navigationTitle("Top Clients")
            .searchable(text: $searchText, prompt: "Search clients")
            .onAppear {
                loadSampleClients()
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
    }
}

#if DEBUG
struct TopClientsView_Previews: PreviewProvider {
    static var previews: some View {
        TopClientsView()
    }
}
#endif

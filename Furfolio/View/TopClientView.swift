//
//  TopClientsView.swift
//  Furfolio
//
//  Highlights top-spending customers for loyalty recognition and business insights.

import SwiftUI

struct TopClientsView: View {
    let dogOwners: [DogOwner]

    var topClients: [DogOwner] {
        dogOwners.filter { $0.totalCharges > 0 }
            .sorted { $0.totalCharges > $1.totalCharges }
    }

    var body: some View {
        List {
            Section(header: Text("Top Clients by Lifetime Value")) {
                ForEach(topClients) { owner in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(owner.ownerName)
                                .font(.headline)
                            if let tag = owner.lifetimeValueTag {
                                Text(tag)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 4)
                                    .background(Color.yellow.opacity(0.2))
                                    .cornerRadius(6)
                                    .foregroundColor(.orange)
                            }
                        }
                        Text("$\(owner.totalCharges, specifier: "%.2f") spent")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("\(owner.appointments.count) appointments")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .navigationTitle("Top Clients")
    }
}

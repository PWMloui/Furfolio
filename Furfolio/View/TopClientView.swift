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
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(owner.ownerName)
                                .font(.headline)

                            if let tag = owner.lifetimeValueTag {
                                Label(tag, systemImage: "dollarsign.circle")
                                    .font(.caption2)
                                    .padding(6)
                                    .background(Color.yellow.opacity(0.2))
                                    .cornerRadius(6)
                                    .foregroundColor(.orange)
                            }

                            if owner.hasBirthdayThisMonth {
                                Label("🎂 Birthday Month", systemImage: "gift")
                                    .font(.caption2)
                                    .padding(6)
                                    .background(Color.purple.opacity(0.2))
                                    .cornerRadius(6)
                                    .foregroundColor(.purple)
                            }
                        }

                        Text("$\(owner.totalCharges, specifier: "%.2f") spent")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text("\(owner.appointments.count) appointments")
                            .font(.caption)
                            .foregroundColor(.gray)

                        HStack(spacing: 8) {
                            if !owner.loyaltyProgressTag.isEmpty {
                                Label(owner.loyaltyProgressTag, systemImage: "star.fill")
                                    .font(.caption2)
                                    .padding(6)
                                    .background(Color.green.opacity(0.2))
                                    .cornerRadius(6)
                                    .foregroundColor(.green)
                            }

                            if !owner.behaviorTrendBadge.isEmpty {
                                Label(owner.behaviorTrendBadge, systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption2)
                                    .padding(6)
                                    .background(Color.orange.opacity(0.2))
                                    .cornerRadius(6)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .navigationTitle("Top Clients")
    }
}

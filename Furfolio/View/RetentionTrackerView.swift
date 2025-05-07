//
//  RetentionTrackerView.swift
//  Furfolio
//
//  Lists clients who haven’t returned in 60+ days to help improve retention.

import SwiftUI

struct RetentionTrackerView: View {
    let dogOwners: [DogOwner]

    var retentionRisks: [DogOwner] {
        dogOwners.filter { $0.retentionRisk }
            .sorted { ($0.lastActivityDate ?? .distantPast) < ($1.lastActivityDate ?? .distantPast) }
    }

    var body: some View {
        List {
            Section(header: Text("Retention Risks (60+ days inactive)")) {
                if retentionRisks.isEmpty {
                    Text("No clients are currently at risk.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(retentionRisks) { owner in
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
                            }

                            if let last = owner.lastActivityDate {
                                Text("Last Visit: \(last.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            } else {
                                Text("No visits recorded")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }

                            HStack(spacing: 8) {
                                if owner.hasBirthdayThisMonth {
                                    Label("🎂 Birthday Month", systemImage: "gift")
                                        .font(.caption2)
                                        .padding(6)
                                        .background(Color.purple.opacity(0.2))
                                        .cornerRadius(6)
                                        .foregroundColor(.purple)
                                }

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
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .navigationTitle("Retention Tracker")
    }
}

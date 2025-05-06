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
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(owner.ownerName)
                                    .font(.headline)
                                if let tag = owner.lifetimeValueTag {
                                    Text(tag)
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

                            if owner.hasBirthdayThisMonth {
                                Text("🎂 Birthday Month")
                                    .font(.caption2)
                                    .padding(6)
                                    .background(Color.purple.opacity(0.2))
                                    .cornerRadius(6)
                                    .foregroundColor(.purple)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
        .navigationTitle("Retention Tracker")
    }
}


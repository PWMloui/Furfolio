//
//  RetentionTrackerView.swift
//  Furfolio
//
//  Lists clients who haven’t returned in 60+ days to help improve retention.

import SwiftUI

// TODO: Move retention-risk filtering and presentation into a dedicated ViewModel; cache formatters for performance.

@MainActor
/// View showing dog owners at risk of churn (60+ days inactive), with key status badges.
struct RetentionTrackerView: View {
  let dogOwners: [DogOwner]

  /// Shared formatter for displaying last-visit dates.
  private static let dateFormatter: DateFormatter = {
    let fmt = DateFormatter()
    fmt.dateStyle = .medium
    fmt.timeStyle = .none
    return fmt
  }()

  /// Dog owners filtered to those inactive 60+ days, sorted by last activity.
  var retentionRisks: [DogOwner] {
    dogOwners.filter { $0.retentionRisk }
      .sorted { ($0.lastActivityDate ?? .distantPast) < ($1.lastActivityDate ?? .distantPast) }
  }

  var body: some View {
    NavigationStack {
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
                    TagLabelView(text: tag, backgroundColor: .yellow, textColor: .orange)
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
                    TagLabelView(text: "🎂 Birthday Month", backgroundColor: .purple, textColor: .white)
                  }

                  if !owner.loyaltyProgressTag.isEmpty {
                    TagLabelView(text: owner.loyaltyProgressTag, backgroundColor: .green, textColor: .white)
                  }

                  if !owner.behaviorTrendBadge.isEmpty {
                    TagLabelView(text: owner.behaviorTrendBadge, backgroundColor: .orange, textColor: .white)
                  }
                }
              }
              .padding(.vertical, 8)
              .cardStyle()
            }
          }
        }
      }
      .listStyle(.insetGrouped)
      .navigationTitle("Retention Tracker")
      .navigationBarTitleDisplayMode(.inline)
    }
  }
}

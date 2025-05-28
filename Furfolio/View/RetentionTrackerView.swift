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
  @StateObject private var viewModel: RetentionTrackerViewModel

  init(dogOwners: [DogOwner]) {
    _viewModel = StateObject(wrappedValue: RetentionTrackerViewModel(dogOwners: dogOwners))
  }

  var body: some View {
    NavigationStack {
      List {
        Section(header: Text("Retention Risks (60+ days inactive)")) {
          if viewModel.retentionRisks.isEmpty {
            Text("No clients are currently at risk.")
              .foregroundColor(.secondary)
          } else {
            ForEach(viewModel.retentionRisks) { owner in
              VStack(alignment: .leading, spacing: 8) {
                HStack {
                  Text(owner.ownerName)
                    .font(.headline)

                  if let tag = owner.lifetimeValueTag {
                    TagLabelView(text: tag, backgroundColor: .yellow, textColor: .orange)
                  }
                }

                Text("Last Visit: \(viewModel.formattedDate(owner.lastActivityDate))")
                  .font(.caption)
                  .foregroundColor(.gray)

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

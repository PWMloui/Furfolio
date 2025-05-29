//
//  RetentionTrackerView.swift
//  Furfolio
//
//  Lists clients who haven’t returned in 60+ days to help improve retention.

import SwiftUI
import os

// TODO: Move retention-risk filtering and presentation into a dedicated ViewModel; cache formatters for performance.

@MainActor
/// View showing dog owners at risk of churn (60+ days inactive), with key status badges.
struct RetentionTrackerView: View {
  @StateObject private var viewModel: RetentionTrackerViewModel
  private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "RetentionTrackerView")

  init(dogOwners: [DogOwner]) {
    _viewModel = StateObject(wrappedValue: RetentionTrackerViewModel(dogOwners: dogOwners))
  }

  var body: some View {
    NavigationStack {
      List {
        Section(header: Text("Retention Risks (60+ days inactive)")
          .font(AppTheme.title)
          .foregroundColor(AppTheme.primaryText)
        ) {
          if viewModel.retentionRisks.isEmpty {
            Text("No clients are currently at risk.")
              .foregroundColor(AppTheme.secondaryText)
              .font(AppTheme.body)
          } else {
            ForEach(viewModel.retentionRisks) { owner in
              VStack(alignment: .leading, spacing: 8) {
                HStack {
                  Text(owner.ownerName)
                    .font(AppTheme.body)
                    .foregroundColor(AppTheme.primaryText)

                  if let tag = owner.lifetimeValueTag {
                    TagLabelView(text: tag, backgroundColor: AppTheme.info, textColor: AppTheme.primaryText)
                  }
                }

                Text("Last Visit: \(viewModel.formattedDate(owner.lastActivityDate))")
                  .font(AppTheme.caption)
                  .foregroundColor(AppTheme.secondaryText)

                HStack(spacing: 8) {
                  if owner.hasBirthdayThisMonth {
                    TagLabelView(text: "🎂 Birthday Month", backgroundColor: AppTheme.accent, textColor: AppTheme.primaryText)
                  }

                  if !owner.loyaltyProgressTag.isEmpty {
                    TagLabelView(text: owner.loyaltyProgressTag, backgroundColor: AppTheme.success, textColor: AppTheme.primaryText)
                  }

                  if !owner.behaviorTrendBadge.isEmpty {
                    TagLabelView(text: owner.behaviorTrendBadge, backgroundColor: AppTheme.warning, textColor: AppTheme.primaryText)
                  }
                }
              }
              .padding(.vertical, 8)
              .cardStyle()
              .onAppear {
                logger.log("Displaying at-risk owner: \(owner.ownerName), lastActivity: \(String(describing: owner.lastActivityDate))")
              }
            }
          }
        }
      }
      .listStyle(.insetGrouped)
      .navigationTitle("Retention Tracker")
      .navigationBarTitleDisplayMode(.inline)
    }
    .onAppear {
      logger.log("RetentionTrackerView appeared; \(viewModel.retentionRisks.count) at-risk clients")
    }
  }
}

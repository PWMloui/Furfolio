//
//  LoyaltyProgressView.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on Jun 25, 2025 — fixed progressViewStyle invocation and explicit Color reference.
//

import SwiftUI
import os


// TODO: Move loyalty logic into a dedicated ViewModel and use theme colors for consistency

@MainActor
class LoyaltyProgressViewModel: ObservableObject {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "LoyaltyProgressViewModel")
    let owner: DogOwner
    private var stats: ClientStats { ClientStats(owner: owner) }
    @Published var visits: Int
    @Published var threshold: Int

    var progressFraction: Double {
        let fraction = min(Double(visits) / Double(threshold), 1.0)
        logger.log("Computed progressFraction: \(fraction)")
        return fraction
    }

    var loyaltyStatus: String {
        stats.loyaltyStatus
    }

    var loyaltyProgressTag: String {
        stats.loyaltyProgressTag
    }

    init(owner: DogOwner) {
        self.owner = owner
        self.visits = stats.totalAppointments
        self.threshold = ClientStats.loyaltyThreshold
        logger.log("Initialized LoyaltyProgressViewModel for owner id: \(owner.id), visits: \(visits), threshold: \(threshold)")
    }
}

/// Shows a client’s loyalty status and progress toward their next free bath.
struct LoyaltyProgressView: View {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "LoyaltyProgressView")
    @StateObject private var viewModel: LoyaltyProgressViewModel

    init(owner: DogOwner) {
        _viewModel = StateObject(wrappedValue: LoyaltyProgressViewModel(owner: owner))
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Loyalty Status")
                    .font(AppTheme.title)
                    .foregroundColor(AppTheme.primaryText)
                Spacer()
                Text(viewModel.loyaltyStatus)
                    .foregroundColor(AppTheme.accent)
                    .font(AppTheme.body).fontWeight(.semibold)
            }

            // Progress bar
            VStack(alignment: .leading) {
                ProgressView(value: viewModel.progressFraction) {
                    Text("Visits: \(viewModel.visits)/\(viewModel.threshold)")
                }
                .progressViewStyle(LinearProgressViewStyle(tint: AppTheme.accent))

                Text(viewModel.loyaltyProgressTag)
                    .font(AppTheme.caption)
                    .foregroundColor(
                        viewModel.progressFraction >= 1.0
                            ? AppTheme.success
                            : AppTheme.secondaryText
                    )
            }
        }
        .padding()
        .cardStyle()
        .background(AppTheme.background)
        .accessibilityElement(children: .combine)
        .onAppear {
            logger.log("LoyaltyProgressView appeared for owner id: \(viewModel.owner.id)")
        }
    }
}

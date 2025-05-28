//
//  LoyaltyProgressView.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on Jun 25, 2025 — fixed progressViewStyle invocation and explicit Color reference.
//

import SwiftUI


// TODO: Move loyalty logic into a dedicated ViewModel and use theme colors for consistency

@MainActor
class LoyaltyProgressViewModel: ObservableObject {
    let owner: DogOwner
    private var stats: ClientStats { ClientStats(owner: owner) }
    @Published var visits: Int
    @Published var threshold: Int

    var progressFraction: Double {
        min(Double(visits) / Double(threshold), 1.0)
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
    }
}

/// Shows a client’s loyalty status and progress toward their next free bath.
struct LoyaltyProgressView: View {
    @StateObject private var viewModel: LoyaltyProgressViewModel

    init(owner: DogOwner) {
        _viewModel = StateObject(wrappedValue: LoyaltyProgressViewModel(owner: owner))
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Loyalty Status")
                    .font(.headline)
                Spacer()
                Text(viewModel.loyaltyStatus)
                    .foregroundColor(.accentColor)
                    .fontWeight(.semibold)
            }

            // Progress bar
            VStack(alignment: .leading) {
                ProgressView(value: viewModel.progressFraction) {
                    Text("Visits: \(viewModel.visits)/\(viewModel.threshold)")
                }
                .progressViewStyle(LinearProgressViewStyle(tint: .appPrimary))

                Text(viewModel.loyaltyProgressTag)
                    .font(.subheadline)
                    .foregroundColor(
                        viewModel.progressFraction >= 1.0
                            ? Color.green
                            : Color.secondary
                    )
            }
        }
        .padding()
        .cardStyle()
        .accessibilityElement(children: .combine)
    }
}

//
//  LoyaltyProgressView.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on Jun 25, 2025 — fixed progressViewStyle invocation and explicit Color reference.
//

import SwiftUI
import SwiftData

// TODO: Move loyalty logic into a dedicated ViewModel and use theme colors for consistency

@MainActor
/// Shows a client’s loyalty status and progress toward their next free bath.
struct LoyaltyProgressView: View {
    let owner: DogOwner

    /// ClientStats helper for computing loyalty-related values.
    private var stats: ClientStats {
        ClientStats(owner: owner)
    }

    /// Total number of completed visits.
    private var visits: Int { stats.totalAppointments }

    /// Number of visits required to earn the next reward.
    private let threshold = ClientStats.loyaltyThreshold

    /// Progress toward the reward as a fraction between 0 and 1.
    private var progressFraction: Double {
        min(Double(visits) / Double(threshold), 1.0)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Loyalty Status")
                    .font(.headline)
                Spacer()
                Text(stats.loyaltyStatus)
                    .foregroundColor(.accentColor)
                    .fontWeight(.semibold)
            }

            // Progress bar
            VStack(alignment: .leading) {
                ProgressView(value: progressFraction) {
                    Text("Visits: \(visits)/\(threshold)")
                }
                .progressViewStyle(LinearProgressViewStyle(tint: .appPrimary))

                Text(stats.loyaltyProgressTag)
                    .font(.subheadline)
                    .foregroundColor(
                        progressFraction >= 1.0
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

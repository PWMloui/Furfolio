//
//  LoyaltyRewardEngine.swift
//  Furfolio
//
//  Created by ChatGPT on 05/15/2025.
//  Updated on 07/05/2025 — added custom thresholds, localization, and preview helpers.
//

import Foundation
import SwiftUI

// TODO: Allow injection of custom thresholds, badge formats, and localization for enhanced flexibility and testing.

@MainActor
/// Provides loyalty reward computations for a DogOwner, producing a badge and summary.
struct LoyaltyRewardEngine {
    
    /// Encapsulates the resulting badge and summary text for loyalty status.
    struct Status {
        /// The badge string (emoji + text).
        let badge: String
        /// A human‐readable summary.
        let summary: String
    }
    
    /// Default number of visits required to earn a free reward.
    nonisolated static var defaultThreshold: Int { ClientStats.loyaltyThreshold }
    /// Computes loyalty status directly from a visit count, for preview/testing.
    nonisolated static func status(visits: Int, threshold: Int = defaultThreshold) -> Status {
      if visits >= threshold {
        return .init(
          badge: NSLocalizedString("🎁 Free Bath Earned!", comment: ""),
          summary: NSLocalizedString("You’ve earned a free bath—enjoy!", comment: "")
        )
      } else {
        let remaining = threshold - visits
        return .init(
          badge: visitsRemainingBadge(remaining),
          summary: visitsRemainingSummary(remaining)
        )
      }
    }
    
    /// Helper to format a localized string with visit count and plural suffix.
    nonisolated private static func visitsRemainingBadge(_ remaining: Int) -> String {
      String(
        format: NSLocalizedString("🏆 %d more to free bath", comment: "Badge showing visits remaining"),
        remaining
      )
    }

    nonisolated private static func visitsRemainingSummary(_ remaining: Int) -> String {
      let suffix = (remaining == 1 ? "" : "s")
      return String(
        format: NSLocalizedString("Just %d visit%@ away from your reward!", comment: "Summary when visits remain"),
        remaining, suffix
      )
    }
    
    /// Computes the loyalty status for a given owner.
    ///
    /// - Parameters:
    ///   - owner: The DogOwner whose visit history is evaluated.
    ///   - threshold: Visits required to earn a free reward (defaults to `defaultThreshold`).
    /// - Returns: A `Status` struct containing a localized badge and summary.
    static func status(
        for owner: DogOwner,
        threshold: Int = defaultThreshold
    ) -> Status {
        let stats  = ClientStats(owner: owner)
        let visits = stats.totalAppointments
        
        if visits >= threshold {
            return .init(
                badge: NSLocalizedString("🎁 Free Bath Earned!", comment: "Loyalty badge when user has earned reward"),
                summary: NSLocalizedString("You’ve earned a free bath—enjoy!", comment: "Loyalty summary when reward earned")
            )
        } else {
            let remaining = threshold - visits
            let badge = visitsRemainingBadge(remaining)
            let summary = visitsRemainingSummary(remaining)
            return .init(badge: badge, summary: summary)
        }
    }
}


#if DEBUG
import SwiftUI

/// SwiftUI previews to visualize various loyalty states.
struct LoyaltyRewardEngine_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            previewRow(visits: 0)
            previewRow(visits: 3)
            previewRow(visits: LoyaltyRewardEngine.defaultThreshold - 1)
            previewRow(visits: LoyaltyRewardEngine.defaultThreshold)
            previewRow(visits: LoyaltyRewardEngine.defaultThreshold + 5)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
    
    private static func previewRow(visits: Int) -> some View {
      let status = LoyaltyRewardEngine.status(visits: visits)
      
      return HStack {
        Text("Visits: \(visits)")
          .frame(width: 80, alignment: .leading)
        Text(status.badge)
          .font(.headline)
        Spacer()
        Text(status.summary)
          .font(.subheadline)
          .foregroundColor(.secondary)
      }
    }
}
#endif

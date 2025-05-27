//
//  LoyaltyRewardEngine.swift
//  Furfolio
//
//  Created by ChatGPT on 05/15/2025.
//  Updated on 07/05/2025 — added custom thresholds, localization, and preview helpers.
//

import Foundation

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
    static var defaultThreshold: Int { ClientStats.loyaltyThreshold }
    
    @MainActor
    static func status(visits: Int, threshold: Int = defaultThreshold) -> Status {
        let badge: String
        if visits >= threshold {
            badge = NSLocalizedString("🎁 Free Bath Earned!", comment: "")
        } else {
            badge = String(
                format: NSLocalizedString("🏆 %d more to free bath", comment: "Badge showing visits remaining"),
                threshold - visits
            )
        }
        let summary: String
        if visits >= threshold {
            summary = NSLocalizedString("You’ve earned a free bath—enjoy!", comment: "")
        } else {
            let rem = threshold - visits
            let suffix = (rem == 1 ? "" : "s")
            summary = String(
                format: NSLocalizedString("Just %d visit%@ away from your reward!", comment: "Summary when visits remain"),
                rem, suffix
            )
        }
        return .init(badge: badge, summary: summary)
    }
    
    @MainActor
    static func status(for owner: DogOwner, threshold: Int = defaultThreshold) -> Status {
        let stats = ClientStats(owner: owner)
        return status(visits: stats.totalAppointments, threshold: threshold)
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

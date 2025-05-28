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
    
    /// Cached loyalty threshold to avoid repeated UserDefaults lookups.
    private static let cachedThreshold: Int = SettingsManager.shared.loyaltyThreshold
    static var defaultThreshold: Int { cachedThreshold }

    /// Preloaded localized format strings for badge and summary.
    private static let moreBadgeFmt = NSLocalizedString(
        "🏆 %d more to free bath",
        comment: "Badge showing visits remaining"
    )
    private static let moreSummaryFmt = NSLocalizedString(
        "Just %d visit%@ away from your reward!",
        comment: "Summary when visits remain"
    )
    private static let earnedBadge = NSLocalizedString(
        "🎁 Free Bath Earned!",
        comment: "Badge when threshold reached"
    )
    private static let earnedSummary = NSLocalizedString(
        "You’ve earned a free bath—enjoy!",
        comment: "Summary when threshold reached"
    )
    
    static func status(visits: Int, threshold: Int = defaultThreshold) -> Status {
        let badge: String
        let summary: String

        if visits >= threshold {
            badge = earnedBadge
            summary = earnedSummary
        } else {
            let rem = threshold - visits
            let suffix = rem == 1 ? "" : "s"
            badge = String(format: moreBadgeFmt, rem)
            summary = String(format: moreSummaryFmt, rem, suffix)
        }
        return .init(badge: badge, summary: summary)
    }
    
    @MainActor static func status(for owner: DogOwner, threshold: Int = defaultThreshold) -> Status {
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

//
//  BadgeEngine.swift
//  Furfolio
//
//  Created by ChatGPT on 05/18/2025.
//  Updated on 07/06/2025 — added localization, Identifiable/CustomStringConvertible conformance,
//                        combined badge API, and refactored keyword storage.
//

import Foundation

struct BadgeEngine {
  // TODO: Allow injection of custom keyword maps and loyalty thresholds for flexibility and testing.
    
    // MARK: — Behavior Badges
    
  @MainActor
  /// Represents a behavior badge with associated display text and matching keywords.
    enum BehaviorBadge: String, CaseIterable, Identifiable, CustomStringConvertible {
        case aggressive = "🔴 Aggressive Behavior"
        case anxious    = "🟠 Anxious"
        case calm       = "🟢 Calm Pet"
        case neutral    = "😐 Neutral"
        
        var id: String { rawValue }
        
        /// Localized display
        var description: String {
            NSLocalizedString(rawValue, comment: "Behavior badge")
        }
        
        /// Mapping from badges to lowercase keywords for note matching.
        fileprivate static let keywordMap: [BehaviorBadge: [String]] = [
            .aggressive: ["aggressive", "bite", "attacked", "snapped"],
            .anxious:    ["anxious", "nervous", "fearful", "skittish"],
            .calm:       ["calm", "friendly", "relaxed", "gentle"],
            .neutral:    []
        ]
        
        /// Returns true if any of this badge’s keywords appear in the text.
        func matches(_ text: String) -> Bool {
          guard let keywords = BehaviorBadge.keywordMap[self] else { return false }
          return keywords.contains { text.lowercased().contains($0) }
        }
    }
    
    /// Determines the highest-priority behavior badge for the given notes.
    /// Scans notes and returns the highest-priority badge.
    /// Priority order: aggressive → anxious → calm → neutral.
    @MainActor static func behaviorBadge(from notes: String) -> BehaviorBadge {
        let text = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if BehaviorBadge.aggressive.matches(text) { return .aggressive }
        if BehaviorBadge.anxious.matches(text)    { return .anxious }
        if BehaviorBadge.calm.matches(text)       { return .calm }
        return .neutral
    }
    
    
    // MARK: — Loyalty Badges
    
  @MainActor
  /// Represents loyalty status: earned or progress toward next reward.
    enum LoyaltyBadge: Identifiable, CustomStringConvertible {
        case earned
        case progress(remaining: Int)
        
        var id: String {
            switch self {
            case .earned:            return "earned"
            case .progress(let rem): return "progress-\(rem)"
            }
        }
        
        var description: String {
            switch self {
            case .earned:
                return NSLocalizedString("🎁 Free Bath Earned!", comment: "Loyalty badge when reward earned")
            case .progress(let remaining):
                let fmt = NSLocalizedString("🏆 %d more to free bath", comment: "Loyalty badge showing visits remaining")
                return String(format: fmt, remaining)
            }
        }
    }
    
    /// Number of visits required to earn a free bath reward.
    /// Visits needed to earn a reward.
    static var loyaltyThreshold: Int = 10
    
    /// Returns the appropriate loyalty badge based on visit count and threshold.
    /// Returns a loyalty badge enum for the given count.
    static func loyaltyBadge(for visits: Int, threshold: Int = loyaltyThreshold) -> LoyaltyBadge {
        let rem = max(0, threshold - visits)
        return rem <= 0 ? .earned : .progress(remaining: rem)
    }
    
    
    // MARK: — Combined API
    
    /// Returns an array containing both behavior and loyalty badges for given inputs.
    /// Returns both the behavior and loyalty badges for a given notes + visit count.
    @MainActor static func allBadges(from notes: String, visits: Int) -> [any CustomStringConvertible & Identifiable] {
        let behavior = behaviorBadge(from: notes)
        let loyalty  = loyaltyBadge(for: visits)
        return [behavior, loyalty]
    }
    
    
    // MARK: — Debug Helpers
    
    #if DEBUG
      /// Debug helper: prints sample badge mappings and examples to the console.
    @MainActor static func runDebugChecks() {
        // Behavior
        for badge in BehaviorBadge.allCases {
          print("Keywords for \(badge.rawValue):", BehaviorBadge.keywordMap[badge]!)
        }
        // Examples
        print("Behavior(‘friendly pup’) →", behaviorBadge(from: "friendly pup").rawValue)
        print("Behavior(‘bit me’) →", behaviorBadge(from: "bit me").rawValue)

        // Loyalty
        for visits in [0, 3, loyaltyThreshold, loyaltyThreshold + 2] {
          let lb = loyaltyBadge(for: visits)
          print("Visits \(visits) →", lb.description)
        }
      }

    #endif
}

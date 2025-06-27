//
//  OnboardingSecurityReview.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import Foundation

/// Tracks legal and compliance-related onboarding acceptance
struct OnboardingSecurityReview: Codable {
    var hasAcceptedTerms: Bool
    var hasReviewedPrivacyPolicy: Bool
    var consentTimestamp: Date?
    
    static let storageKey = "onboarding_security_review"

    /// Load the stored state from UserDefaults
    static func load() -> OnboardingSecurityReview {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(OnboardingSecurityReview.self, from: data) else {
            return OnboardingSecurityReview(hasAcceptedTerms: false, hasReviewedPrivacyPolicy: false, consentTimestamp: nil)
        }
        return decoded
    }

    /// Save the current state to UserDefaults
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    /// Mark as accepted and timestamped
    mutating func acceptAll() {
        hasAcceptedTerms = true
        hasReviewedPrivacyPolicy = true
        consentTimestamp = Date()
        save()
    }

    /// Reset to default state
    static func reset() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}

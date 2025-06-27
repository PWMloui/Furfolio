//
//  OfflineOnboardingFallback.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import Foundation

/// Provides a fallback onboarding path when remote or dynamic config fails
struct OfflineOnboardingFallback {
    /// Returns a fallback set of onboarding steps if needed
    static func defaultSteps(for role: OnboardingRole) -> [OnboardingStep] {
        switch role {
        case .manager:
            return [.welcome, .tutorial, .permissions, .completion]
        case .staff:
            return [.welcome, .tutorial, .faq, .completion]
        case .receptionist:
            return [.welcome, .tutorial, .completion]
        }
    }

    /// Returns a message to show when fallback is activated
    static var explanation: String {
        return "You're offline, so we're showing the default onboarding experience. You can access all features once you're connected again."
    }

    /// Returns whether we are currently offline (basic check)
    static var isOffline: Bool {
        !Reachability.isConnectedToNetwork()
    }
}

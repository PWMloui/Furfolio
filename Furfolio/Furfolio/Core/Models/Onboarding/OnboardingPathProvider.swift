//
//  OnboardingPathProvider.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import Foundation

// MARK: - OnboardingPathProvider

/// Provides a list of onboarding steps for a given user role
struct OnboardingPathProvider {
    
    /// Returns steps dynamically filtered from step descriptors.
    /// Falls back to offline defaults if descriptors are missing.
    static func steps(for role: OnboardingRole, includeSkippable: Bool = true) -> [OnboardingStep] {
        let descriptors = OnboardingStepDescriptor.defaultDescriptors()
            .filter { $0.rolesApplicable.contains(role) && (includeSkippable || !$0.isSkippable) }

        if descriptors.isEmpty {
            let fallback = OfflineOnboardingFallback.defaultSteps(for: role)
            print("⚠️ Using offline fallback for role: \(role.rawValue)")
            return fallback
        }

        let result = descriptors.map { $0.id }
        print("✅ Loaded \(result.count) steps for role: \(role.rawValue)")
        return result
    }
}

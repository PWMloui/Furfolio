//
//  OnboardingStateStore.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

// MARK: - OnboardingStateStore.swift

final class OnboardingStateStore {
    static let shared = OnboardingStateStore()
    private init() {}

    func hasCompleted(role: OnboardingRole, userId: String) -> Bool {
        UserDefaults.standard.bool(forKey: key(for: role, userId: userId))
    }

    func markCompleted(role: OnboardingRole, userId: String) {
        UserDefaults.standard.set(true, forKey: key(for: role, userId: userId))
    }

    private func key(for role: OnboardingRole, userId: String) -> String {
        "onboarding_complete_\(userId)_\(role.rawValue)"
    }
}

//
//  RemoteOnboardingConfig.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import Foundation

/// Represents a remote onboarding configuration response
struct RemoteOnboardingConfig: Decodable {
    let role: OnboardingRole
    let steps: [OnboardingStep]

    enum CodingKeys: String, CodingKey {
        case role
        case steps
    }
}

extension RemoteOnboardingConfig {
    /// Decodes config from remote JSON data
    static func load(from data: Data) -> RemoteOnboardingConfig? {
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(RemoteOnboardingConfig.self, from: data)
        } catch {
            print("❌ Failed to decode RemoteOnboardingConfig: \(error)")
            return nil
        }
    }

    /// Simulated example for development
    static func mock(for role: OnboardingRole) -> RemoteOnboardingConfig {
        switch role {
        case .manager:
            return RemoteOnboardingConfig(role: .manager, steps: [.welcome, .dataImport, .tutorial, .permissions, .completion])
        case .staff:
            return RemoteOnboardingConfig(role: .staff, steps: [.welcome, .tutorial, .faq, .completion])
        case .receptionist:
            return RemoteOnboardingConfig(role: .receptionist, steps: [.welcome, .tutorial, .completion])
        }
    }
}

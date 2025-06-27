//
//  OnboardingRole.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import Foundation

/// Represents the user roles in the app and their onboarding metadata
enum OnboardingRole: String, CaseIterable, Codable, Hashable {
    case manager
    case staff
    case receptionist

    /// Human-readable role name
    var displayName: String {
        switch self {
        case .manager: return "Manager"
        case .staff: return "Staff"
        case .receptionist: return "Receptionist"
        }
    }

    /// Role description for onboarding screens or settings
    var description: String {
        switch self {
        case .manager: return "Full access to scheduling, data import, permissions, and business management."
        case .staff: return "Focused access for groomers including tutorials and client interaction help."
        case .receptionist: return "Simplified onboarding focused on appointments and communication features."
        }
    }

    /// Optional SF Symbol icon for role-specific UI (onboarding, profile)
    var iconName: String {
        switch self {
        case .manager: return "person.crop.rectangle.stack"
        case .staff: return "scissors"
        case .receptionist: return "phone.fill"
        }
    }
}

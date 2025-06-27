//
//  OnboardingStepDescriptor.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import Foundation

/// Describes metadata and configuration for an onboarding step
struct OnboardingStepDescriptor: Identifiable, Hashable {
    /// Unique step ID
    let id: OnboardingStep

    /// Display title of the step
    let title: String

    /// Indicates if this step can be skipped
    let isSkippable: Bool

    /// Roles for which this step should be shown
    let rolesApplicable: [OnboardingRole]

    /// Optional note or instruction about the step
    let notes: String?

    /// Optional accessibility label or hint for screen readers
    let accessibilityHint: String?

    /// Unique identifier required by Identifiable
    var identityKey: String {
        "\(id.rawValue)_\(rolesApplicable.map(\.rawValue).joined(separator: \",\"))"
    }

    var id: String {
        identityKey
    }

    /// Default step metadata used throughout the app
    static func defaultDescriptors() -> [OnboardingStepDescriptor] {
        return [
            OnboardingStepDescriptor(
                id: .welcome,
                title: "Welcome",
                isSkippable: false,
                rolesApplicable: OnboardingRole.allCases,
                notes: "Initial intro screen",
                accessibilityHint: "Start onboarding and learn about Furfolio"
            ),
            OnboardingStepDescriptor(
                id: .dataImport,
                title: "Import Data",
                isSkippable: true,
                rolesApplicable: [.manager],
                notes: "Managers can preload sample business data",
                accessibilityHint: "Import demo or existing data"
            ),
            OnboardingStepDescriptor(
                id: .tutorial,
                title: "Tutorial",
                isSkippable: false,
                rolesApplicable: [.manager, .staff, .receptionist],
                notes: "Visual swipe-through of app features",
                accessibilityHint: "Swipe to explore core features"
            ),
            OnboardingStepDescriptor(
                id: .faq,
                title: "FAQ",
                isSkippable: true,
                rolesApplicable: [.staff],
                notes: "Answers common onboarding questions",
                accessibilityHint: "Frequently asked questions about using the app"
            ),
            OnboardingStepDescriptor(
                id: .permissions,
                title: "Permissions",
                isSkippable: true,
                rolesApplicable: [.manager, .receptionist],
                notes: "Prompt for notifications, access, etc.",
                accessibilityHint: "Enable permissions like notifications"
            ),
            OnboardingStepDescriptor(
                id: .completion,
                title: "All Set",
                isSkippable: false,
                rolesApplicable: OnboardingRole.allCases,
                notes: "Final screen before entering app",
                accessibilityHint: "Finish onboarding and begin using the app"
            )
        ]
    }
}

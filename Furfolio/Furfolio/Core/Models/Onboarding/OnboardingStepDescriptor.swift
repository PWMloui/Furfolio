//
//  OnboardingStepDescriptor.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import Foundation

/**
 OnboardingStepDescriptor
 -------------------------
 Describes metadata and configuration for each onboarding step in Furfolio.

 - **Architecture**: Value-type descriptor conforming to Identifiable, Hashable, and Codable for SwiftUI and networking.
 - **Localization**: All display strings are localized via NSLocalizedString for internationalization.
 - **Accessibility**: Provides accessibility hints for VoiceOver.
 - **Preview/Testability**: Includes a SwiftUI PreviewProvider rendering default descriptors.
 */

/// Describes metadata and configuration for an onboarding step
public struct OnboardingStepDescriptor: Identifiable, Hashable, Codable {
    /// Unique step ID token.
    public let id: OnboardingStep

    /// Localized display title of the step.
    public let title: String

    /// Indicates whether this step can be skipped.
    public let isSkippable: Bool

    /// User roles for which this step should be shown.
    public let rolesApplicable: [OnboardingRole]

    /// Optional localized note or instruction about the step.
    public let notes: String?

    /// Optional localized accessibility hint for screen readers.
    public let accessibilityHint: String?

    /// Synthesized unique identity string for Identifiable.
    public var identity: String {
        "\(id.rawValue)_\(rolesApplicable.map(\.rawValue).joined(separator: \",\"))"
    }

    /// Default step metadata used throughout the app
    public static func defaultDescriptors() -> [OnboardingStepDescriptor] {
        return [
            OnboardingStepDescriptor(
                id: .welcome,
                title: NSLocalizedString("Welcome", comment: "Onboarding step title - Welcome"),
                isSkippable: false,
                rolesApplicable: OnboardingRole.allCases,
                notes: NSLocalizedString("Initial intro screen", comment: "Onboarding step notes - Welcome"),
                accessibilityHint: NSLocalizedString("Start onboarding and learn about Furfolio", comment: "Accessibility hint - Welcome step")
            ),
            OnboardingStepDescriptor(
                id: .dataImport,
                title: NSLocalizedString("Import Data", comment: "Onboarding step title - Import Data"),
                isSkippable: true,
                rolesApplicable: [.manager],
                notes: NSLocalizedString("Managers can preload sample business data", comment: "Onboarding step notes - Import Data"),
                accessibilityHint: NSLocalizedString("Import demo or existing data", comment: "Accessibility hint - Import Data step")
            ),
            OnboardingStepDescriptor(
                id: .tutorial,
                title: NSLocalizedString("Tutorial", comment: "Onboarding step title - Tutorial"),
                isSkippable: false,
                rolesApplicable: [.manager, .staff, .receptionist],
                notes: NSLocalizedString("Visual swipe-through of app features", comment: "Onboarding step notes - Tutorial"),
                accessibilityHint: NSLocalizedString("Swipe to explore core features", comment: "Accessibility hint - Tutorial step")
            ),
            OnboardingStepDescriptor(
                id: .faq,
                title: NSLocalizedString("FAQ", comment: "Onboarding step title - FAQ"),
                isSkippable: true,
                rolesApplicable: [.staff],
                notes: NSLocalizedString("Answers common onboarding questions", comment: "Onboarding step notes - FAQ"),
                accessibilityHint: NSLocalizedString("Frequently asked questions about using the app", comment: "Accessibility hint - FAQ step")
            ),
            OnboardingStepDescriptor(
                id: .permissions,
                title: NSLocalizedString("Permissions", comment: "Onboarding step title - Permissions"),
                isSkippable: true,
                rolesApplicable: [.manager, .receptionist],
                notes: NSLocalizedString("Prompt for notifications, access, etc.", comment: "Onboarding step notes - Permissions"),
                accessibilityHint: NSLocalizedString("Enable permissions like notifications", comment: "Accessibility hint - Permissions step")
            ),
            OnboardingStepDescriptor(
                id: .completion,
                title: NSLocalizedString("All Set", comment: "Onboarding step title - Completion"),
                isSkippable: false,
                rolesApplicable: OnboardingRole.allCases,
                notes: NSLocalizedString("Final screen before entering app", comment: "Onboarding step notes - Completion"),
                accessibilityHint: NSLocalizedString("Finish onboarding and begin using the app", comment: "Accessibility hint - Completion step")
            )
        ]
    }
}

#if DEBUG
import SwiftUI

struct OnboardingStepDescriptor_Previews: PreviewProvider {
    static var previews: some View {
        List(OnboardingStepDescriptor.defaultDescriptors()) { descriptor in
            VStack(alignment: .leading, spacing: 4) {
                Text(descriptor.title)
                    .font(.headline)
                if let notes = descriptor.notes {
                    Text(notes)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
            .accessibilityHint(descriptor.accessibilityHint ?? "")
        }
        .navigationTitle(Text(NSLocalizedString("Onboarding Steps", comment: "Preview title")))
    }
}
#endif

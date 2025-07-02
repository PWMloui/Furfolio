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
 A model describing the metadata for each step in the Furfolio onboarding flow.

 - **Architecture**: Public, value-type descriptor conforming to Identifiable, Hashable, Codable for SwiftUI and networking.
 - **Localization**: All user-facing text is localized via NSLocalizedString.
 - **Accessibility**: Step titles and notes designed for VoiceOver via SwiftUI views.
 - **Preview/Testability**: Includes a SwiftUI PreviewProvider rendering the default descriptor list.
 */
public struct OnboardingStepDescriptor: Identifiable, Hashable, Codable {
    /// The unique step identifier.
    public let id: OnboardingStep
    /// Localized title of the onboarding step.
    public let title: String
    /// Indicates whether this step can be skipped.
    public let isSkippable: Bool
    /// The roles for which this step is applicable.
    public let rolesApplicable: [OnboardingRole]
    /// Optional localized notes for this step.
    public let notes: String?

    static func defaultDescriptors() -> [OnboardingStepDescriptor] {
        return [
            .init(id: .welcome,
                  title: NSLocalizedString("Welcome", comment: "Onboarding step title - Welcome"),
                  isSkippable: false,
                  rolesApplicable: OnboardingRole.allCases,
                  notes: NSLocalizedString("Always the first step", comment: "Onboarding step notes - Welcome")),

            .init(id: .dataImport,
                  title: NSLocalizedString("Data Import", comment: "Onboarding step title - Data Import"),
                  isSkippable: true,
                  rolesApplicable: [.manager],
                  notes: NSLocalizedString("Optional for managers to preload demo data", comment: "Onboarding step notes - Data Import")),

            .init(id: .tutorial,
                  title: NSLocalizedString("Interactive Tutorial", comment: "Onboarding step title - Interactive Tutorial"),
                  isSkippable: false,
                  rolesApplicable: [.manager, .staff, .receptionist],
                  notes: NSLocalizedString("Swipe-based feature overview", comment: "Onboarding step notes - Interactive Tutorial")),

            .init(id: .faq,
                  title: NSLocalizedString("FAQ", comment: "Onboarding step title - FAQ"),
                  isSkippable: true,
                  rolesApplicable: [.staff],
                  notes: NSLocalizedString("Answer common user questions", comment: "Onboarding step notes - FAQ")),

            .init(id: .permissions,
                  title: NSLocalizedString("Permissions", comment: "Onboarding step title - Permissions"),
                  isSkippable: true,
                  rolesApplicable: [.manager, .receptionist],
                  notes: NSLocalizedString("Notifications, etc.", comment: "Onboarding step notes - Permissions")),

            .init(id: .completion,
                  title: NSLocalizedString("Finish", comment: "Onboarding step title - Finish"),
                  isSkippable: false,
                  rolesApplicable: OnboardingRole.allCases,
                  notes: NSLocalizedString("Wrap-up screen", comment: "Onboarding step notes - Finish"))
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
        }
        .navigationTitle(Text(NSLocalizedString("Onboarding Steps", comment: "Preview title")))
    }
}
#endif

//
//  OnboardingStepDescriptor.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import Foundation

/// Describes metadata for each onboarding step
struct OnboardingStepDescriptor: Identifiable, Hashable {
    let id: OnboardingStep
    let title: String
    let isSkippable: Bool
    let rolesApplicable: [OnboardingRole]
    let notes: String?

    static func defaultDescriptors() -> [OnboardingStepDescriptor] {
        return [
            .init(id: .welcome,
                  title: "Welcome",
                  isSkippable: false,
                  rolesApplicable: OnboardingRole.allCases,
                  notes: "Always the first step"),

            .init(id: .dataImport,
                  title: "Data Import",
                  isSkippable: true,
                  rolesApplicable: [.manager],
                  notes: "Optional for managers to preload demo data"),

            .init(id: .tutorial,
                  title: "Interactive Tutorial",
                  isSkippable: false,
                  rolesApplicable: [.manager, .staff, .receptionist],
                  notes: "Swipe-based feature overview"),

            .init(id: .faq,
                  title: "FAQ",
                  isSkippable: true,
                  rolesApplicable: [.staff],
                  notes: "Answer common user questions"),

            .init(id: .permissions,
                  title: "Permissions",
                  isSkippable: true,
                  rolesApplicable: [.manager, .receptionist],
                  notes: "Notifications, etc."),

            .init(id: .completion,
                  title: "Finish",
                  isSkippable: false,
                  rolesApplicable: OnboardingRole.allCases,
                  notes: "Wrap-up screen")
        ]
    }
}

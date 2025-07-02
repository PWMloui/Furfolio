//
//  RoleBasedOnboardingCoordinator.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

/**
 RoleBasedOnboardingCoordinator
 ------------------------------
 A SwiftUI view that orchestrates role-specific onboarding flows in Furfolio.

 - **Purpose**: Routes manager, staff, and receptionist users through their respective onboarding sequences.
 - **Architecture**: SwiftUI `View` using `OnboardingRole` & `OnboardingStateStore`; leverages dependency injection for analytics and audit.
 - **Concurrency & Async Logging**: Wraps state persistence and event tracking in non-blocking async `Task`.
 - **Audit/Analytics Ready**: Uses `OnboardingViewModelAuditManager` (or appropriate actor) and `AnalyticsServiceProtocol` for diagnostics.
 - **Localization**: Role selection and flow transitions can be localized via `NSLocalizedString` or `LocalizedStringKey`.
 - **Accessibility**: Provides identifiers on root views to support UI testing.
 - **Preview/Testability**: Includes a SwiftUI preview simulating each role’s flow.
 */
import SwiftUI

struct RoleBasedOnboardingCoordinator: View {
    let role: OnboardingRole
    let userId: String
    @State private var completed: Bool = false

    @EnvironmentObject var analytics: AnalyticsServiceProtocol
    @EnvironmentObject var audit: AuditLoggerProtocol

    var body: some View {
        if completed {
            MainAppView()
                .accessibilityIdentifier("MainAppView")
        } else {
            switch role {
            case .manager:
                ManagerOnboardingFlow {
                    Task {
                        // Audit the completion event
                        await OnboardingViewModelAuditManager.shared.add(
                            OnboardingViewModelAuditEntry(event: "role_\(role.rawValue)_completed", step: nil)
                        )
                        // Optionally log analytics
                        await analytics.log(event: "onboarding_\(role.rawValue)_completed", parameters: ["userId": userId])
                        OnboardingStateStore.shared.markCompleted(role: role, userId: userId)
                        completed = true
                    }
                }
                .accessibilityIdentifier("ManagerOnboardingFlow")
            case .staff:
                StaffOnboardingFlow {
                    Task {
                        // Audit the completion event
                        await OnboardingViewModelAuditManager.shared.add(
                            OnboardingViewModelAuditEntry(event: "role_\(role.rawValue)_completed", step: nil)
                        )
                        // Optionally log analytics
                        await analytics.log(event: "onboarding_\(role.rawValue)_completed", parameters: ["userId": userId])
                        OnboardingStateStore.shared.markCompleted(role: role, userId: userId)
                        completed = true
                    }
                }
                .accessibilityIdentifier("StaffOnboardingFlow")
            case .receptionist:
                ReceptionistOnboardingFlow {
                    Task {
                        // Audit the completion event
                        await OnboardingViewModelAuditManager.shared.add(
                            OnboardingViewModelAuditEntry(event: "role_\(role.rawValue)_completed", step: nil)
                        )
                        // Optionally log analytics
                        await analytics.log(event: "onboarding_\(role.rawValue)_completed", parameters: ["userId": userId])
                        OnboardingStateStore.shared.markCompleted(role: role, userId: userId)
                        completed = true
                    }
                }
                .accessibilityIdentifier("ReceptionistOnboardingFlow")
            }
        }
    }
}

#if DEBUG
struct RoleBasedOnboardingCoordinator_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            RoleBasedOnboardingCoordinator(role: .manager, userId: "test")
                .environmentObject(MockAnalytics())
                .environmentObject(MockAuditLogger())
            RoleBasedOnboardingCoordinator(role: .staff, userId: "test")
                .environmentObject(MockAnalytics())
                .environmentObject(MockAuditLogger())
            RoleBasedOnboardingCoordinator(role: .receptionist, userId: "test")
                .environmentObject(MockAnalytics())
                .environmentObject(MockAuditLogger())
        }
    }
}
#endif

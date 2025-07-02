//
//  OnboardingDI.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

/// Dependency Injection container for the Onboarding module.
/// 
/// This container centralizes the creation and provision of all dependencies required by onboarding-related views and components.
/// It manages shared services such as analytics, audit logging, and demo data management, and provides factory methods to instantiate views with their required dependencies injected.
/// 
/// The container supports creating views for onboarding completion, interactive tutorials, data import, permission requests, security reviews, and widget suggestion previews.
/// It also provides a method to retrieve offline fallback onboarding steps based on the user's role, facilitating robust onboarding experiences in offline scenarios.
public struct OnboardingDIContainer {
    // Shared singletons or injected dependencies
    let analytics: AnalyticsServiceProtocol
    let audit: AuditLoggerProtocol
    let demoDataManager: DemoDataManagerProtocol

    // Factory methods to create onboarding views with DI
    func makeOnboardingCompletionView(onGetStarted: @escaping () -> Void) -> OnboardingCompletionView {
        return OnboardingCompletionView(
            onGetStarted: onGetStarted,
            analytics: analytics,
            audit: audit
        )
    }

    func makeInteractiveTutorialView() -> InteractiveTutorialView {
        return InteractiveTutorialView(
            analytics: analytics,
            audit: audit
        )
    }

    func makeOnboardingDataImportView() -> OnboardingDataImportView {
        return OnboardingDataImportView(
            analytics: analytics,
            audit: audit,
            demoDataManager: demoDataManager
        )
    }

    func makeOnboardingPermissionView() -> NotificationPermissionView {
        return NotificationPermissionView(
            analytics: analytics,
            audit: audit
        )
    }

    func makeOnboardingSecurityReviewView() -> OnboardingSecurityReview {
        return OnboardingSecurityReview()
    }

    func makeOfflineOnboardingFallbackSteps(for role: OnboardingRole) -> [OnboardingStep] {
        return OfflineOnboardingFallback.defaultSteps(for: role)
    }

    func makeOnboardingWidgetSuggestionPreview() -> some View {
        return OnboardingWidgetSupport_Previews()
    }

    // Placeholder for additional onboarding view factories
    // e.g., makeOnboardingPermissionView(), makeOnboardingWelcomeView()
}

// MARK: - Default Container for App Use

extension OnboardingDIContainer {
    /// Shared production container with default service instances
    static var `default`: OnboardingDIContainer {
        return OnboardingDIContainer(
            analytics: AnalyticsService.shared,
            audit: AuditLogger.shared,
            demoDataManager: DemoDataManager.shared
        )
    }
}

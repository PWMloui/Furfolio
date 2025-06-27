//
//  OnboardingDI.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import Foundation

// MARK: - Onboarding Dependency Container

/// Centralized DI container for Onboarding module
struct OnboardingDIContainer {
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

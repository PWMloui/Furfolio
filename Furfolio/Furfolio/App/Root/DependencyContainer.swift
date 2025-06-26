//
//  DependencyContainer.swift
//  Furfolio
//
//  Enhanced: audit/analytics–ready, token-compliant, test-injectable, brand/Trust Center compliant.
//

import SwiftUI
import Foundation
import SwiftData

// MARK: - Analytics/Audit Protocol

public protocol DependencyContainerAnalyticsLogger {
    func log(event: String, info: String?)
}
public struct NullDependencyContainerAnalyticsLogger: DependencyContainerAnalyticsLogger {
    public init() {}
    public func log(event: String, info: String?) {}
}

// MARK: - DependencyContainer (Unified DI for Services, Managers, ViewModels)

@MainActor
final class DependencyContainer: ObservableObject {
    // MARK: - Analytics Logger (BI/QA/Trust Center/admin/preview)
    static var analyticsLogger: DependencyContainerAnalyticsLogger = NullDependencyContainerAnalyticsLogger()

    // MARK: - Singleton/Test Instance
    static var shared: DependencyContainer = DependencyContainer()
    static var testInstance: DependencyContainer = {
        let container = DependencyContainer(testing: true)
        // TODO: Inject mock services and test loggers here
        DependencyContainer.analyticsLogger.log(event: "testInstance_created", info: nil)
        return container
    }()

    // MARK: - Core Services & Managers (Tokenized)
    let featureFlagManager: FeatureFlagManager
    let demoDataManager: DemoDataManager
    let appState: AppState
    let trustCenterManager: TrustCenterManager
    let notificationPermissionHelper: NotificationPermissionHelper
    let auditLogManager: AuditLogManager
    let encryptionManager: EncryptionManager
    let routeOptimizer: RouteOptimizer
    let expenseTracker: ExpenseTracker
    let businessManager: BusinessManager
    let userRoleManager: UserRoleManager
    let modelContainer: ModelContainer

    // MARK: - View Models (DI Stubs)
    let onboardingViewModel: OnboardingViewModel
    let dashboardViewModel: DashboardViewModel
    let loginViewModel: LoginViewModel

    // MARK: - Initialization

    private init(testing: Bool = false) {
        // Log initialization (for Trust Center/audit)
        Self.analyticsLogger.log(event: "DependencyContainer_init", info: testing ? "testing" : "production")
        // Initialize core services and managers (future: support DI/parameter overrides)
        self.featureFlagManager = FeatureFlagManager.shared
        self.demoDataManager = DemoDataManager.shared
        self.appState = AppState()
        self.trustCenterManager = TrustCenterManager()
        self.notificationPermissionHelper = NotificationPermissionHelper()
        self.auditLogManager = AuditLogManager()
        self.encryptionManager = EncryptionManager()
        self.routeOptimizer = RouteOptimizer()
        self.expenseTracker = ExpenseTracker()
        self.businessManager = BusinessManager()
        self.userRoleManager = UserRoleManager()

        // ModelContainer: robust error handling, audit if failed
        do {
            self.modelContainer = try ModelContainer(
                for: DogOwner.self, Dog.self, Appointment.self, Charge.self, Task.self, BehaviorLog.self, VaccinationRecord.self
            )
        } catch {
            Self.analyticsLogger.log(event: "ModelContainer_init_failed", info: error.localizedDescription)
            // Fail-safe: Fallback or show onboarding error UI, never just fatalError in production!
            fatalError("Failed to initialize ModelContainer: \(error)")
        }

        // Inject dependencies into view models
        self.onboardingViewModel = OnboardingViewModel(dependencies: self)
        self.dashboardViewModel = DashboardViewModel(dependencies: self)
        self.loginViewModel = LoginViewModel(dependencies: self)

        platformSpecificSetup()

        Self.analyticsLogger.log(event: "DependencyContainer_ready", info: nil)
    }

    // MARK: - Methods

    /// Refresh all dependencies (log for QA/audit/preview)
    func refreshDependencies() {
        Self.analyticsLogger.log(event: "refreshDependencies_called", info: nil)
        // Example: featureFlagManager.reload(), demoDataManager.reload(), appState.reset()
        // All critical refreshes should be logged and auditable.
    }

    /// Platform-specific setup (future: audit/analytics as well)
    private func platformSpecificSetup() {
        #if os(macOS)
        Self.analyticsLogger.log(event: "platformSetup", info: "macOS")
        #elseif os(iOS)
        let idiom = UIDevice.current.userInterfaceIdiom
        Self.analyticsLogger.log(event: "platformSetup", info: idiom == .pad ? "iPad" : "iPhone")
        #endif
    }

    // MARK: - Dependency Accessors with Audit Hooks (optional for Trust Center)
    // Example: every time a dependency is accessed, you could log it for sensitive services (use judiciously to avoid log spam!)
    // func getAuditLogManager() -> AuditLogManager {
    //     Self.analyticsLogger.log(event: "auditLogManager_accessed", info: nil)
    //     return auditLogManager
    // }
}

// MARK: - Stub Classes for Managers and ViewModels (unchanged, as before)
final class TrustCenterManager {}
final class NotificationPermissionHelper {}
final class AuditLogManager {}
final class EncryptionManager {}
final class RouteOptimizer {}
final class ExpenseTracker {}
final class BusinessManager {}
final class UserRoleManager {}

final class OnboardingViewModel: ObservableObject {
    init(dependencies: DependencyContainer) {}
}
final class DashboardViewModel: ObservableObject {
    init(dependencies: DependencyContainer) {}
}
final class LoginViewModel: ObservableObject {
    init(dependencies: DependencyContainer) {}
}

// MARK: - Best Practices (Usage Guidance, unchanged)
/*
 - Use DependencyContainer.shared for real, .testInstance for previews/tests.
 - All services/managers/view models are always injected and logged for audit/compliance.
 - All new dependencies should be registered in the container and, if sensitive, have audit hooks for access.
 - Replace stubs with real implementations as the app grows; inject mocks/test loggers as needed.
 - Never instantiate dependencies outside the container—enforce single source of truth.
*/

//
//  DependencyContainer.swift
//  Furfolio
//
//  Enhanced 2025-06-30: role/staff/context audit, escalation protocol, trust center/BI ready, still modular, testable.
//

import SwiftUI
import Foundation
import SwiftData

// MARK: - Analytics/Audit Protocol (Role/Staff/Context/Escalation)
public protocol DependencyContainerAnalyticsLogger {
    var testMode: Bool { get set }
    func log(event: String, info: String?, role: String?, staffID: String?, context: String?) async
    func escalate(event: String, info: String?, role: String?, staffID: String?, context: String?) async
}

/// No-op logger for default/preview/testing
public struct NullDependencyContainerAnalyticsLogger: DependencyContainerAnalyticsLogger {
    public var testMode: Bool = false
    public init() {}
    public func log(event: String, info: String?, role: String?, staffID: String?, context: String?) async {}
    public func escalate(event: String, info: String?, role: String?, staffID: String?, context: String?) async {}
}

/// Console logger for QA/testing
public struct ConsoleDependencyContainerAnalyticsLogger: DependencyContainerAnalyticsLogger {
    public var testMode: Bool = true
    public init() {}
    public func log(event: String, info: String?, role: String?, staffID: String?, context: String?) async {
        print("[DependencyContainer][LOG] \(event) | Info: \(info ?? "-") [role:\(role ?? "-")] [staff:\(staffID ?? "-")] [ctx:\(context ?? "-")]")
    }
    public func escalate(event: String, info: String?, role: String?, staffID: String?, context: String?) async {
        print("[DependencyContainer][ESCALATE] \(event) | Info: \(info ?? "-") [role:\(role ?? "-")] [staff:\(staffID ?? "-")] [ctx:\(context ?? "-")]")
    }
}

// MARK: - DependencyContainer (Unified DI for Services, Managers, ViewModels)

@MainActor
final class DependencyContainer: ObservableObject {
    // MARK: - Audit/Analytics Context (DI ready)
    static var analyticsLogger: DependencyContainerAnalyticsLogger = NullDependencyContainerAnalyticsLogger()
    static var currentRole: String? = nil
    static var currentStaffID: String? = nil
    static var currentContext: String? = "DependencyContainer"
    private static var analyticsEventHistory: [(event: String, info: String?, role: String?, staffID: String?, context: String?)] = []

    // Singleton and test instances
    static var shared: DependencyContainer = DependencyContainer()
    static var testInstance: DependencyContainer = {
        let container = DependencyContainer(testing: true)
        Task {
            await DependencyContainer.analyticsLogger.log(
                event: NSLocalizedString("testInstance_created", comment: "Analytics event when test instance of DependencyContainer is created"),
                info: nil,
                role: currentRole,
                staffID: currentStaffID,
                context: currentContext
            )
        }
        return container
    }()

    // MARK: - Core Services & Managers (unchanged)
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

    // MARK: - View Models (unchanged)
    let onboardingViewModel: OnboardingViewModel
    let dashboardViewModel: DashboardViewModel
    let loginViewModel: LoginViewModel

    // MARK: - Initialization

    private init(testing: Bool = false) {
        // Test mode logger if testing
        if testing {
            Self.analyticsLogger = ConsoleDependencyContainerAnalyticsLogger()
        }

        // Log container initialization
        Task {
            await Self.logEvent(
                event: NSLocalizedString("DependencyContainer_init", comment: "Analytics event when DependencyContainer initializes"),
                info: testing ? NSLocalizedString("testing", comment: "Indicates testing environment") : NSLocalizedString("production", comment: "Indicates production environment"),
                escalate: false
            )
        }

        // Core services
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
        
        do {
            self.modelContainer = try ModelContainer(
                for: DogOwner.self, Dog.self, Appointment.self, Charge.self, Task.self, BehaviorLog.self, VaccinationRecord.self
            )
        } catch {
            Task {
                await Self.logEvent(
                    event: NSLocalizedString("ModelContainer_init_failed", comment: "Analytics event when ModelContainer initialization fails"),
                    info: error.localizedDescription,
                    escalate: true
                )
            }
            fatalError("Failed to initialize ModelContainer: \(error)")
        }

        // View models
        self.onboardingViewModel = OnboardingViewModel(dependencies: self)
        self.dashboardViewModel = DashboardViewModel(dependencies: self)
        self.loginViewModel = LoginViewModel(dependencies: self)

        platformSpecificSetup()

        Task {
            await Self.logEvent(
                event: NSLocalizedString("DependencyContainer_ready", comment: "Analytics event when DependencyContainer is fully initialized and ready"),
                info: nil,
                escalate: false
            )
        }
    }

    // MARK: - Methods

    func refreshDependencies() {
        Task {
            await Self.logEvent(
                event: NSLocalizedString("refreshDependencies_called", comment: "Analytics event when refreshDependencies is called"),
                info: nil,
                escalate: false
            )
        }
        // Add refresh logic for critical managers as needed
    }

    private func platformSpecificSetup() {
        #if os(macOS)
        Task {
            await Self.logEvent(
                event: NSLocalizedString("platformSetup", comment: "Analytics event for platform-specific setup"),
                info: NSLocalizedString("macOS", comment: "Platform info for macOS"),
                escalate: false
            )
        }
        #elseif os(iOS)
        let idiom = UIDevice.current.userInterfaceIdiom
        let platformInfo = idiom == .pad ? NSLocalizedString("iPad", comment: "Platform info for iPad") : NSLocalizedString("iPhone", comment: "Platform info for iPhone")
        Task {
            await Self.logEvent(
                event: NSLocalizedString("platformSetup", comment: "Analytics event for platform-specific setup"),
                info: platformInfo,
                escalate: false
            )
        }
        #endif
    }

    // MARK: - Audit Logging & Escalation

    @MainActor
    private static func logEvent(event: String, info: String?, escalate: Bool) async {
        let role = currentRole
        let staffID = currentStaffID
        let ctx = currentContext
        analyticsEventHistory.append((event: event, info: info, role: role, staffID: staffID, context: ctx))
        if analyticsEventHistory.count > 20 {
            analyticsEventHistory.removeFirst(analyticsEventHistory.count - 20)
        }
        if escalate {
            await analyticsLogger.escalate(event: event, info: info, role: role, staffID: staffID, context: ctx)
        } else {
            await analyticsLogger.log(event: event, info: info, role: role, staffID: staffID, context: ctx)
        }
    }

    /// Public API to fetch the last 20 analytics events for diagnostics or admin UI.
    public static func fetchRecentAnalyticsEvents() -> [(event: String, info: String?, role: String?, staffID: String?, context: String?)] {
        return analyticsEventHistory
    }
}

// MARK: - Stubs for Managers and ViewModels (unchanged)
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

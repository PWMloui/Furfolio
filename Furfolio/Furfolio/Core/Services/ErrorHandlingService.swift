//
//  ErrorHandlingService.swift
//  Furfolio
//
//  Enhanced: Analytics/audit-ready, token-compliant, modular, extensible, business/enterprise-ready.
//  All new audit/analytics and diagnostics hooks, tokens, and protocols are drop-in.

/**
 ErrorHandlingService
 --------------------
 Centralized service for handling and presenting errors in Furfolio, with async audit logging and diagnostics.

 - **Purpose**: Processes AppError instances, logs diagnostics, and presents user alerts.
 - **Architecture**: Singleton @MainActor class with dependency-injected async audit logger.
 - **Concurrency & Async Logging**: Wraps all audit calls in non-blocking Tasks and uses await.
 - **Audit/Analytics Ready**: Defines async audit protocol and integrates a dedicated audit manager actor.
 - **Localization**: Alert titles and messages use LocalizedStringKey and NSLocalizedString.
 - **Diagnostics & Preview/Testability**: Exposes methods to fetch and export recent audit entries.
 */
//

import Foundation
import SwiftData

/// A record of an error handling audit event.
public struct ErrorAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let event: String
    public let errorType: String
    public let context: [String: String]?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        event: String,
        errorType: String,
        context: [String: String]?
    ) {
        self.id = id
        self.timestamp = timestamp
        self.event = event
        self.errorType = errorType
        self.context = context
    }
}

/// Concurrency-safe actor for logging error audit entries.
public actor ErrorAuditManager {
    private var buffer: [ErrorAuditEntry] = []
    private let maxEntries = 100
    public static let shared = ErrorAuditManager()

    /// Add a new audit entry, trimming older entries beyond maxEntries.
    public func add(_ entry: ErrorAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Fetch recent audit entries up to the specified limit.
    public func recent(limit: Int = 20) -> [ErrorAuditEntry] {
        Array(buffer.suffix(limit))
    }

    /// Export audit entries as pretty-printed JSON.
    public func exportJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(buffer),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }
}

// MARK: - Audit/Analytics Protocol

public protocol ErrorAuditLogger {
    /// Log an error event asynchronously.
    func log(event: String, error: AppError, context: [String: String]?) async
}
public struct NullErrorAuditLogger: ErrorAuditLogger {
    public init() {}
    public func log(event: String, error: AppError, context: [String: String]?) async {}
}

/// A centralized service for handling, logging, and presenting errors throughout the Furfolio app.
/// This service acts as the single funnel for all thrown `AppError` types.
/// Now supports enterprise diagnostics, analytics, and full token compliance.
@MainActor
final class ErrorHandlingService {

    /// Shared singleton instance for easy access.
    static let shared = ErrorHandlingService()

    /// Dependency-injectable audit/analytics logger (preview/test/enterprise/Trust Center).
    public static var auditLogger: ErrorAuditLogger = NullErrorAuditLogger()

    /// Private initializer to enforce the singleton pattern.
    private init() {}

    /// The main public method for processing an error.
    /// - Parameters:
    ///   - error: The `AppError` that occurred.
    ///   - appState: The shared `AppState` object used to trigger UI alerts.
    ///   - modelContext: The `ModelContext` needed for logging the error to the database.
    ///   - extraContext: Additional analytics/audit context (file, function, etc).
    func handle(
        error: AppError,
        in appState: AppState,
        modelContext: ModelContext,
        extraContext: [String: String]? = nil
    ) {
        // --- Step 1: Log every error for diagnostics ---
        logError(error, context: modelContext)

        // --- Step 2: Call audit/analytics for business/Trust Center compliance ---
        Task {
            let ctx = mergedAuditContext(error: error, extra: extraContext)
            await Self.auditLogger.log(
                event: "error_occurred",
                error: error,
                context: ctx
            )
            await ErrorAuditManager.shared.add(
                ErrorAuditEntry(
                    event: "error_occurred",
                    errorType: String(describing: error),
                    context: ctx
                )
            )
        }

        // --- Step 3: Determine the appropriate UI action ---
        switch error {

        case .dataLoadFailed, .saveFailed, .dataEncryptionFailed, .unknown:
            let alert = FurfolioAlert(
                title: LocalizedStringKey("An Error Occurred"),
                message: LocalizedStringKey(error.localizedDescription),
                role: .error,
                font: AppFonts.body ?? .body,
                foregroundColor: AppColors.error ?? .red
            )
            appState.presentAlert(alert)
            Task {
                let ctx = mergedAuditContext(error: error, extra: extraContext)
                await Self.auditLogger.log(event: "alert_critical", error: error, context: ctx)
                await ErrorAuditManager.shared.add(
                    ErrorAuditEntry(
                        event: "alert_critical",
                        errorType: String(describing: error),
                        context: ctx
                    )
                )
            }

        case .invalidInput(let reason):
            let messageKey = reason ?? NSLocalizedString("Please check the highlighted fields and try again.", comment: "Fallback message for invalid input error")
            let alert = FurfolioAlert(
                title: LocalizedStringKey("Invalid Input"),
                message: LocalizedStringKey(messageKey),
                role: .warning,
                font: AppFonts.body ?? .body,
                foregroundColor: AppColors.warning ?? .yellow
            )
            appState.presentAlert(alert)
            Task {
                let ctx = mergedAuditContext(error: error, extra: extraContext)
                await Self.auditLogger.log(event: "alert_invalid_input", error: error, context: ctx)
                await ErrorAuditManager.shared.add(
                    ErrorAuditEntry(
                        event: "alert_invalid_input",
                        errorType: String(describing: error),
                        context: ctx
                    )
                )
            }

        case .permissionDenied(let type):
            let formatString = NSLocalizedString("Furfolio does not have permission for %@. Please grant permission in your device's Settings app.", comment: "Message shown when permission is denied, %@ is the feature type")
            let permissionType = type ?? NSLocalizedString("this feature", comment: "Fallback permission type description")
            let message = String(format: formatString, permissionType)
            let alert = FurfolioAlert(
                title: LocalizedStringKey("Permission Denied"),
                message: LocalizedStringKey(message),
                primaryButton: .default(Text(LocalizedStringKey("Settings")), action: {
                    NotificationPermissionHelper.shared.openSettings()
                }),
                secondaryButton: .cancel(),
                role: .warning,
                font: AppFonts.body ?? .body,
                foregroundColor: AppColors.warning ?? .yellow
            )
            appState.presentAlert(alert)
            Task {
                let ctx = mergedAuditContext(error: error, extra: extraContext)
                await Self.auditLogger.log(event: "alert_permission_denied", error: error, context: ctx)
                await ErrorAuditManager.shared.add(
                    ErrorAuditEntry(
                        event: "alert_permission_denied",
                        errorType: String(describing: error),
                        context: ctx
                    )
                )
            }

        case .networkUnavailable:
            let alert = FurfolioAlert(
                title: LocalizedStringKey("Network Unavailable"),
                message: LocalizedStringKey(NSLocalizedString("Please check your internet connection and try again.", comment: "Message shown when network is unavailable")),
                role: .info,
                font: AppFonts.body ?? .body,
                foregroundColor: AppColors.info ?? .blue
            )
            appState.presentAlert(alert)
            Task {
                let ctx = mergedAuditContext(error: error, extra: extraContext)
                await Self.auditLogger.log(event: "alert_network_unavailable", error: error, context: ctx)
                await ErrorAuditManager.shared.add(
                    ErrorAuditEntry(
                        event: "alert_network_unavailable",
                        errorType: String(describing: error),
                        context: ctx
                    )
                )
            }

        case .tspRouteError(let reason):
            let messageKey = reason ?? NSLocalizedString("Could not generate an optimized route.", comment: "Fallback message for route error")
            let alert = FurfolioAlert(
                title: LocalizedStringKey("Route Error"),
                message: LocalizedStringKey(messageKey),
                role: .error,
                font: AppFonts.body ?? .body,
                foregroundColor: AppColors.error ?? .red
            )
            appState.presentAlert(alert)
            Task {
                let ctx = mergedAuditContext(error: error, extra: extraContext)
                await Self.auditLogger.log(event: "alert_route_error", error: error, context: ctx)
                await ErrorAuditManager.shared.add(
                    ErrorAuditEntry(
                        event: "alert_route_error",
                        errorType: String(describing: error),
                        context: ctx
                    )
                )
            }

        case .unauthorizedAccess:
            let alert = FurfolioAlert(
                title: LocalizedStringKey("Access Denied"),
                message: LocalizedStringKey(NSLocalizedString("You do not have the required permissions for this action.", comment: "Message shown when user tries unauthorized action")),
                role: .destructive,
                font: AppFonts.body ?? .body,
                foregroundColor: AppColors.destructive ?? .red
            )
            appState.presentAlert(alert)
            Task {
                let ctx = mergedAuditContext(error: error, extra: extraContext)
                await Self.auditLogger.log(event: "alert_unauthorized_access", error: error, context: ctx)
                await ErrorAuditManager.shared.add(
                    ErrorAuditEntry(
                        event: "alert_unauthorized_access",
                        errorType: String(describing: error),
                        context: ctx
                    )
                )
            }

        default:
            let alert = FurfolioAlert(
                title: LocalizedStringKey("Alert"),
                message: LocalizedStringKey(error.localizedDescription),
                role: .info,
                font: AppFonts.body ?? .body,
                foregroundColor: AppColors.info ?? .blue
            )
            appState.presentAlert(alert)
            Task {
                let ctx = mergedAuditContext(error: error, extra: extraContext)
                await Self.auditLogger.log(event: "alert_generic_error", error: error, context: ctx)
                await ErrorAuditManager.shared.add(
                    ErrorAuditEntry(
                        event: "alert_generic_error",
                        errorType: String(describing: error),
                        context: ctx
                    )
                )
            }
        }
    }

    /// Private helper to log the error using the existing CrashReporter service.
    private func logError(_ error: AppError, context: ModelContext) {
        CrashReporter.shared.logCrash(
            type: String(describing: error),
            message: error.localizedDescription,
            stackTrace: CrashReporter.captureStackTrace(),
            deviceInfo: CrashReporter.deviceInfo(),
            context: context
        )
    }

    /// Helper to merge audit context from error and extra info.
    private func mergedAuditContext(error: AppError, extra: [String: String]?) -> [String: String] {
        var context: [String: String] = [
            "errorType": String(describing: error),
            "localizedDescription": error.localizedDescription,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        if let extra = extra {
            context.merge(extra) { (_, new) in new }
        }
        return context
    }
}

// MARK: - Example Usage

/*
func someRiskyOperation() {
    do {
        // try someThrowingFunction()
    } catch {
        let appError = AppError.from(error)
        ErrorHandlingService.shared.handle(
            error: appError,
            in: appState,
            modelContext: modelContext,
            extraContext: [
                "file": #file,
                "function": #function,
                "line": "\(#line)"
            ]
        )
    }
}
*/


// MARK: - Diagnostics

public extension ErrorHandlingService {
    /// Fetch recent error audit entries.
    static func recentAuditEntries(limit: Int = 20) async -> [ErrorAuditEntry] {
        await ErrorAuditManager.shared.recent(limit: limit)
    }

    /// Export error audit log as JSON string.
    static func exportAuditLogJSON() async -> String {
        await ErrorAuditManager.shared.exportJSON()
    }
}

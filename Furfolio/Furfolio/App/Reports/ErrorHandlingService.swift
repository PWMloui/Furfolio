//
//  ErrorHandlingService.swift
//  Furfolio
//
//  Enhanced: Analytics/audit-ready, token-compliant, modular, extensible, business/enterprise-ready.
//  All new audit/analytics and diagnostics hooks, tokens, and protocols are drop-in.
//

import Foundation
import SwiftData

// MARK: - Audit/Analytics Protocol

public protocol ErrorAuditLogger {
    func log(event: String, error: AppError, context: [String: String]?)
}
public struct NullErrorAuditLogger: ErrorAuditLogger {
    public init() {}
    public func log(event: String, error: AppError, context: [String: String]?) {}
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
        Self.auditLogger.log(
            event: "error_occurred",
            error: error,
            context: mergedAuditContext(error: error, extra: extraContext)
        )

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
            Self.auditLogger.log(event: "alert_critical", error: error, context: mergedAuditContext(error: error, extra: extraContext))

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
            Self.auditLogger.log(event: "alert_invalid_input", error: error, context: mergedAuditContext(error: error, extra: extraContext))

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
            Self.auditLogger.log(event: "alert_permission_denied", error: error, context: mergedAuditContext(error: error, extra: extraContext))

        case .networkUnavailable:
            let alert = FurfolioAlert(
                title: LocalizedStringKey("Network Unavailable"),
                message: LocalizedStringKey(NSLocalizedString("Please check your internet connection and try again.", comment: "Message shown when network is unavailable")),
                role: .info,
                font: AppFonts.body ?? .body,
                foregroundColor: AppColors.info ?? .blue
            )
            appState.presentAlert(alert)
            Self.auditLogger.log(event: "alert_network_unavailable", error: error, context: mergedAuditContext(error: error, extra: extraContext))

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
            Self.auditLogger.log(event: "alert_route_error", error: error, context: mergedAuditContext(error: error, extra: extraContext))

        case .unauthorizedAccess:
            let alert = FurfolioAlert(
                title: LocalizedStringKey("Access Denied"),
                message: LocalizedStringKey(NSLocalizedString("You do not have the required permissions for this action.", comment: "Message shown when user tries unauthorized action")),
                role: .destructive,
                font: AppFonts.body ?? .body,
                foregroundColor: AppColors.destructive ?? .red
            )
            appState.presentAlert(alert)
            Self.auditLogger.log(event: "alert_unauthorized_access", error: error, context: mergedAuditContext(error: error, extra: extraContext))

        default:
            let alert = FurfolioAlert(
                title: LocalizedStringKey("Alert"),
                message: LocalizedStringKey(error.localizedDescription),
                role: .info,
                font: AppFonts.body ?? .body,
                foregroundColor: AppColors.info ?? .blue
            )
            appState.presentAlert(alert)
            Self.auditLogger.log(event: "alert_generic_error", error: error, context: mergedAuditContext(error: error, extra: extraContext))
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

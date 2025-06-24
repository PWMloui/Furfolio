//
//  ErrorHandlingService.swift
//  Furfolio
//
//  Created by mac on 6/21/25.
//

import Foundation
import SwiftData

/// A centralized service for handling, logging, and presenting errors throughout the Furfolio app.
/// This service acts as the single funnel for all thrown `AppError` types.
///
/// Best Practices:
/// - Extend this service cautiously; centralize error handling to maintain consistency.
/// - All alert titles and messages should be localized using `LocalizedStringKey` or `NSLocalizedString` with comments for translators.
/// - Integrate audit and analytics calls in the `handle(error:in:modelContext:)` method where indicated to track error occurrences.
/// - Use design tokens such as `AppFonts` and `AppColors` for alert appearances to maintain UI consistency.
@MainActor
final class ErrorHandlingService {
    
    /// Shared singleton instance for easy access.
    static let shared = ErrorHandlingService()
    
    /// Private initializer to enforce the singleton pattern.
    private init() {}

    /// The main public method for processing an error.
    /// It logs the error for diagnostics and then determines the appropriate user-facing action.
    /// - Parameters:
    ///   - error: The `AppError` that occurred.
    ///   - appState: The shared `AppState` object used to trigger UI alerts.
    ///   - modelContext: The `ModelContext` needed for logging the error to the database.
    func handle(error: AppError, in appState: AppState, modelContext: ModelContext) {
        // --- Step 1: Log every error for diagnostics ---
        // Every error, regardless of how it's presented to the user,
        // should be logged for developer review using the CrashReporter service.
        logError(error, context: modelContext)
        
        // --- Step 2: Determine the appropriate UI action ---
        // Based on the error type, we decide how to inform the user.
        switch error {
            
        // For critical, non-recoverable errors, show a modal alert.
        case .dataLoadFailed, .saveFailed, .dataEncryptionFailed, .unknown:
            let alert = FurfolioAlert(
                title: LocalizedStringKey("An Error Occurred"),
                message: LocalizedStringKey(error.localizedDescription),
                role: .error
            )
            // Note: Use design tokens (AppFonts, AppColors) for alert appearance, not system defaults.
            appState.presentAlert(alert)
            // TODO: Call audit/analytics event for critical error
            
        // For user-correctable errors, provide a helpful recovery suggestion.
        case .invalidInput(let reason):
            let messageKey = reason ?? NSLocalizedString("Please check the highlighted fields and try again.", comment: "Fallback message for invalid input error")
            let alert = FurfolioAlert(
                title: LocalizedStringKey("Invalid Input"),
                message: LocalizedStringKey(messageKey),
                role: .warning
            )
            // Note: Use design tokens (AppFonts, AppColors) for alert appearance, not system defaults.
            appState.presentAlert(alert)
            // TODO: Call audit/analytics event for invalid input error
            
        case .permissionDenied(let type):
            // Localized format string with comment for translators
            let formatString = NSLocalizedString("Furfolio does not have permission for %@. Please grant permission in your device's Settings app.", comment: "Message shown when permission is denied, %@ is the feature type")
            let permissionType = type ?? NSLocalizedString("this feature", comment: "Fallback permission type description")
            let message = String(format: formatString, permissionType)
            let alert = FurfolioAlert(
                title: LocalizedStringKey("Permission Denied"),
                message: LocalizedStringKey(message),
                primaryButton: .default(Text(LocalizedStringKey("Settings")), action: {
                    // Deep link to settings
                    NotificationPermissionHelper.shared.openSettings()
                }),
                secondaryButton: .cancel(),
                role: .warning
            )
            // Note: Use design tokens (AppFonts, AppColors) for alert appearance, not system defaults.
            appState.presentAlert(alert)
            // TODO: Call audit/analytics event for permission denied error
            
        // For temporary or environmental issues.
        case .networkUnavailable:
            let alert = FurfolioAlert(
                title: LocalizedStringKey("Network Unavailable"),
                message: LocalizedStringKey(NSLocalizedString("Please check your internet connection and try again.", comment: "Message shown when network is unavailable")),
                role: .info
            )
            // Note: Use design tokens (AppFonts, AppColors) for alert appearance, not system defaults.
            appState.presentAlert(alert)
            // TODO: Call audit/analytics event for network unavailable error

        // For business logic failures.
        case .tspRouteError(let reason):
             let messageKey = reason ?? NSLocalizedString("Could not generate an optimized route.", comment: "Fallback message for route error")
             let alert = FurfolioAlert(
                title: LocalizedStringKey("Route Error"),
                message: LocalizedStringKey(messageKey),
                role: .error
            )
            // Note: Use design tokens (AppFonts, AppColors) for alert appearance, not system defaults.
            appState.presentAlert(alert)
            // TODO: Call audit/analytics event for route error
            
        // For security issues.
        case .unauthorizedAccess:
             let alert = FurfolioAlert(
                title: LocalizedStringKey("Access Denied"),
                message: LocalizedStringKey(NSLocalizedString("You do not have the required permissions for this action.", comment: "Message shown when user tries unauthorized action")),
                role: .destructive
            )
            // Note: Use design tokens (AppFonts, AppColors) for alert appearance, not system defaults.
            appState.presentAlert(alert)
            // TODO: Call audit/analytics event for unauthorized access
            
        // Default for any other case
        default:
            let alert = FurfolioAlert(
                title: LocalizedStringKey("Alert"),
                message: LocalizedStringKey(error.localizedDescription),
                role: .info
            )
            // Note: Use design tokens (AppFonts, AppColors) for alert appearance, not system defaults.
            appState.presentAlert(alert)
            // TODO: Call audit/analytics event for generic error
        }
    }
    
    /// Private helper to log the error using the existing CrashReporter service.
    private func logError(_ error: AppError, context: ModelContext) {
        // Use the existing CrashReporter to persist a record of the error.
        // This is crucial for debugging issues that users experience in the wild.
        CrashReporter.shared.logCrash(
            type: String(describing: error),
            message: error.localizedDescription,
            stackTrace: CrashReporter.captureStackTrace(),
            deviceInfo: CrashReporter.deviceInfo(),
            context: context
        )
    }
}


// MARK: - Example Usage

/*
 // In any ViewModel or service where you might have a `do-catch` block:

 func someRiskyOperation() {
     do {
         // try someThrowingFunction()
     } catch {
         // Instead of handling the UI logic here, just pass the error
         // to the centralized service.
         let appError = AppError.from(error) // Wrap the unknown error
         
         // Assuming you have access to appState and modelContext
         // ErrorHandlingService.shared.handle(error: appError, in: appState, modelContext: modelContext)
     }
 }
*/

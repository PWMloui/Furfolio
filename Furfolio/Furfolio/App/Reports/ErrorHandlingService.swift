
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
                title: "An Error Occurred",
                message: LocalizedStringKey(error.localizedDescription),
                role: .error
            )
            appState.presentAlert(alert)
            
        // For user-correctable errors, provide a helpful recovery suggestion.
        case .invalidInput(let reason):
            let alert = FurfolioAlert(
                title: "Invalid Input",
                message: LocalizedStringKey(reason ?? "Please check the highlighted fields and try again."),
                role: .warning
            )
            appState.presentAlert(alert)
            
        case .permissionDenied(let type):
            let message = "Furfolio does not have permission for \(type ?? "this feature"). Please grant permission in your device's Settings app."
            let alert = FurfolioAlert(
                title: "Permission Denied",
                message: LocalizedStringKey(message),
                primaryButton: .default(Text("Settings"), action: {
                    // Deep link to settings
                    NotificationPermissionHelper.shared.openSettings()
                }),
                secondaryButton: .cancel(),
                role: .warning
            )
            appState.presentAlert(alert)
            
        // For temporary or environmental issues.
        case .networkUnavailable:
            let alert = FurfolioAlert(
                title: "Network Unavailable",
                message: "Please check your internet connection and try again.",
                role: .info
            )
            appState.presentAlert(alert)

        // For business logic failures.
        case .tspRouteError(let reason):
             let alert = FurfolioAlert(
                title: "Route Error",
                message: LocalizedStringKey(reason ?? "Could not generate an optimized route."),
                role: .error
            )
            appState.presentAlert(alert)
            
        // For security issues.
        case .unauthorizedAccess:
             let alert = FurfolioAlert(
                title: "Access Denied",
                message: "You do not have the required permissions for this action.",
                role: .destructive
            )
            appState.presentAlert(alert)
            
        // Default for any other case
        default:
            let alert = FurfolioAlert(
                title: "Alert",
                message: LocalizedStringKey(error.localizedDescription),
                role: .info
            )
            appState.presentAlert(alert)
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

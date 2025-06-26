//
//  AppError.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import Foundation

// MARK: - AppError (Centralized Error Handling for Furfolio)
// Add at the top, after imports:
public protocol AppErrorAnalyticsLogger {
    func log(event: String, error: AppError)
}
public struct NullAppErrorAnalyticsLogger: AppErrorAnalyticsLogger {
    public init() {}
    public func log(event: String, error: AppError) {}
}

// MARK: - AppError Analytics Logger (DI for audit/BI/QA)
extension AppError {
    // Analytics logger (injectable for BI/QA/Trust Center)
    public static var analyticsLogger: AppErrorAnalyticsLogger = NullAppErrorAnalyticsLogger()
}
// MARK: - Application Error Handling
/// Defines centralized error types for Furfolio's business management operations,
/// facilitating consistent error reporting, user feedback, and debugging across the app.
///
/// This enum serves as the single source of truth for all error scenarios encountered in the app.
/// Best practices include:
/// - Use descriptive, user-friendly localized descriptions for UI feedback.
/// - Provide recovery suggestions when possible to guide user remediation.
/// - Utilize the `id` property for error tracking and analytics.
/// - Wrap unknown errors to maintain consistent error handling.
/// - Use the `demo` initializer and `allCases` array for UI previews and testing.
///
/// Usage patterns:
/// - Instantiate errors with context-specific reasons to aid debugging.
/// - Leverage `isRecoverable` to determine if user action can resolve the issue.
/// - Use `from(_:)` to convert generic Errors into AppError for unified handling.
/// - Implement UI components that consume `LocalizedError` properties for display.

/// Represents all possible error cases encountered in Furfolio's business management workflows.
/// Each case is documented for clarity and future maintenance, describing its role in the app's domain.
enum AppError: Error, LocalizedError, Identifiable {
    /// Error when loading data fails, optionally including a reason.
    case dataLoadFailed(reason: String? = nil)
    /// Error when saving data fails, optionally including a reason.
    case saveFailed(reason: String? = nil)
    /// Error indicating invalid user input, with optional details.
    case invalidInput(reason: String? = nil)
    /// Error indicating an attempt to add a duplicate entry.
    case duplicateEntry
    /// Error indicating network connectivity is unavailable.
    case networkUnavailable
    /// Error indicating permission was denied, optionally specifying the permission type.
    case permissionDenied(type: String? = nil)
    /// Error indicating unauthorized access attempt, optionally specifying the user role.
    case unauthorizedAccess(role: String? = nil)
    /// Error related to Traveling Salesman Problem or route optimization failures.
    case tspRouteError(reason: String? = nil)
    /// Error occurring during data encryption or security operations.
    case dataEncryptionFailed(reason: String? = nil)
    /// Represents an unknown or external error, optionally wrapping an underlying Error.
    case unknown(error: Error? = nil)
    
    /// Unique identifier for the error instance, combining the case name and a UUID for analytics and audit purposes.
    var id: String {
        let caseName = String(describing: self).components(separatedBy: "(").first ?? "unknown"
        return "\(caseName)-\(UUID().uuidString)"
    }
    
    /// Provides a user-friendly localized description of the error.
    var errorDescription: String? {
        switch self {
        case .dataLoadFailed(let reason):
            return "Failed to load data." + (reason.map { "\n\($0)" } ?? "")
        case .saveFailed(let reason):
            return "Could not save your changes." + (reason.map { "\n\($0)" } ?? "")
        case .invalidInput(let reason):
            return "Invalid input." + (reason.map { "\n\($0)" } ?? "")
        case .duplicateEntry:
            return "This item already exists."
        case .networkUnavailable:
            return "No internet connection. Please try again later."
        case .permissionDenied(let type):
            return "Permission denied." + (type.map { " (\($0))" } ?? "")
        case .unauthorizedAccess(let role):
            return "Unauthorized access." + (role.map { " (Role: \($0))" } ?? "")
        case .tspRouteError(let reason):
            return "Route optimization failed." + (reason.map { "\n\($0)" } ?? "")
        case .dataEncryptionFailed(let reason):
            return "Data encryption failed." + (reason.map { "\n\($0)" } ?? "")
        case .unknown(let error):
            if let error = error {
                return "An unexpected error occurred: \(error.localizedDescription)"
            }
            return "An unexpected error occurred."
        }
    }
    
    /// Provides an optional suggestion to help the user recover from the error.
    var recoverySuggestion: String? {
        switch self {
        case .networkUnavailable:
            return "Check your internet connection and try again."
        case .permissionDenied:
            return "Please update your app permissions in Settings."
        case .invalidInput:
            return "Please review the highlighted fields."
        default:
            return nil
        }
    }
    
    /// Indicates whether the error is recoverable by the user or system.
    var isRecoverable: Bool {
        switch self {
        case .invalidInput, .networkUnavailable, .permissionDenied, .unauthorizedAccess:
            return true
        case .dataLoadFailed, .saveFailed, .duplicateEntry, .tspRouteError, .dataEncryptionFailed, .unknown:
            return false
        }
    }
    
    /// Initializes an AppError from any Error instance, wrapping unknown errors and preserving AppError types.
    /// Logs the error initialization for debugging and auditing purposes.
    static func from(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            print("AppError initialized from existing AppError: \(appError)")
            return appError
        } else {
            print("AppError wrapping unknown error: \(error.localizedDescription)")
            return .unknown(error: error)
        }
    }
    
    /// An array of all AppError cases with demo data, useful for UI previews and testing.
    static let allCases: [AppError] = [
        .dataLoadFailed(reason: "Demo data load failure"),
        .saveFailed(reason: "Demo save failure"),
        .invalidInput(reason: "Demo invalid input"),
        .duplicateEntry,
        .networkUnavailable,
        .permissionDenied(type: "Camera Access"),
        .unauthorizedAccess(role: "Guest User"),
        .tspRouteError(reason: "Demo route optimization error"),
        .dataEncryptionFailed(reason: "Demo encryption failure"),
        .unknown(error: nil)
    ]
    
    /// Enum representing each error type for demo purposes.
    enum DemoType {
        case dataLoadFailed
        case saveFailed
        case invalidInput
        case duplicateEntry
        case networkUnavailable
        case permissionDenied
        case unauthorizedAccess
        case tspRouteError
        case dataEncryptionFailed
        case unknown
    }
    
    static func demo(_ type: DemoType) -> AppError {
        let demoErr: AppError
        switch type {
        case .dataLoadFailed:
            demoErr = .dataLoadFailed(reason: "Demo data load failure")
        case .saveFailed:
            demoErr = .saveFailed(reason: "Demo save failure")
        case .invalidInput:
            demoErr = .invalidInput(reason: "Demo invalid input")
        case .duplicateEntry:
            demoErr = .duplicateEntry
        case .networkUnavailable:
            demoErr = .networkUnavailable
        case .permissionDenied:
            demoErr = .permissionDenied(type: "Camera Access")
        case .unauthorizedAccess:
            demoErr = .unauthorizedAccess(role: "Guest User")
        case .tspRouteError:
            demoErr = .tspRouteError(reason: "Demo route optimization error")
        case .dataEncryptionFailed:
            demoErr = .dataEncryptionFailed(reason: "Demo encryption failure")
        case .unknown:
            demoErr = .unknown(error: nil)
        }
        AppError.analyticsLogger.log(event: "demo", error: demoErr)
        return demoErr
    }

// Usage Example:
//
// In SwiftUI, you can present error feedback using an AppError instance:
//
// @State private var currentError: AppError?
//
// var body: some View {
//     VStack {
//         // Your UI here
//     }
//     .alert(item: $currentError) { error in
//         Alert(
//             title: Text("Error"),
//             message: Text(error.errorDescription ?? "An error occurred."),
//             dismissButton: .default(Text("OK"))
//         )
//     }
// }
//
// To trigger an error:
// currentError = AppError.demo(.networkUnavailable)
//
// This approach ensures consistent and user-friendly error presentation throughout the app.

// End of AppError.swift – Furfolio Business Management App

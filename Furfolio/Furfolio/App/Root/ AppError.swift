//
//  AppError.swift
//  Furfolio
//
//  Updated 2025-06-30: Role-aware, audit/compliance-ready, escalatable error architecture.
//

import Foundation

// MARK: - Error Analytics/Audit Event Struct

public struct AppErrorEvent: Codable, Identifiable {
    public let id: String
    public let timestamp: Date
    public let event: String
    public let error: AppError
    public let role: String?
    public let staffID: String?
    public let context: String?
    public let escalate: Bool

    public init(event: String, error: AppError, role: String?, staffID: String?, context: String?, escalate: Bool = false) {
        self.id = UUID().uuidString
        self.timestamp = Date()
        self.event = event
        self.error = error
        self.role = role
        self.staffID = staffID
        self.context = context
        self.escalate = escalate
    }
}

// MARK: - Analytics & Audit Protocol

public protocol AppErrorAnalyticsLogger {
    func log(event: AppErrorEvent) async
    /// Optional: escalate to Trust Center/compliance if needed
    func escalate(event: AppErrorEvent) async
}
public struct NullAppErrorAnalyticsLogger: AppErrorAnalyticsLogger {
    public init() {}
    public func log(event: AppErrorEvent) async {}
    public func escalate(event: AppErrorEvent) async {}
}

// MARK: - Error Logger Configuration

extension AppError {
    /// Injectable analytics logger (for BI/QA/Trust Center).
    public static var analyticsLogger: AppErrorAnalyticsLogger = NullAppErrorAnalyticsLogger()
    public static var testMode: Bool = false
    /// Optional current role and staff context, for audit/event logs.
    public static var currentRole: String? = nil
    public static var currentStaffID: String? = nil
    public static var currentContext: String? = nil
}

// MARK: - AppError Enum (Role-aware, Escalatable)

public enum AppError: Error, LocalizedError, Identifiable {
    case dataLoadFailed(reason: String? = nil)
    case saveFailed(reason: String? = nil)
    case invalidInput(reason: String? = nil)
    case duplicateEntry
    case networkUnavailable
    case permissionDenied(type: String? = nil)
    case unauthorizedAccess(role: String? = nil)
    case tspRouteError(reason: String? = nil)
    case dataEncryptionFailed(reason: String? = nil)
    case unknown(error: Error? = nil)

    public var id: String {
        let caseName = String(describing: self).components(separatedBy: "(").first ?? "unknown"
        return "\(caseName)-\(UUID().uuidString)"
    }

    public var errorDescription: String? {
        switch self {
        case .dataLoadFailed(let reason):
            return NSLocalizedString(
                "Failed to load data." + (reason.map { "\n\($0)" } ?? ""),
                comment: "Error description for data load failure")
        case .saveFailed(let reason):
            return NSLocalizedString(
                "Could not save your changes." + (reason.map { "\n\($0)" } ?? ""),
                comment: "Error description for save failure")
        case .invalidInput(let reason):
            return NSLocalizedString(
                "Invalid input." + (reason.map { "\n\($0)" } ?? ""),
                comment: "Error description for invalid user input")
        case .duplicateEntry:
            return NSLocalizedString("This item already exists.", comment: "Error description for duplicate entry")
        case .networkUnavailable:
            return NSLocalizedString("No internet connection. Please try again later.", comment: "Error description for network unavailable")
        case .permissionDenied(let type):
            return NSLocalizedString(
                "Permission denied." + (type.map { " (\($0))" } ?? ""),
                comment: "Error description for permission denied")
        case .unauthorizedAccess(let role):
            return NSLocalizedString(
                "Unauthorized access." + (role.map { " (Role: \($0))" } ?? ""),
                comment: "Error description for unauthorized access")
        case .tspRouteError(let reason):
            return NSLocalizedString(
                "Route optimization failed." + (reason.map { "\n\($0)" } ?? ""),
                comment: "Error description for TSP route error")
        case .dataEncryptionFailed(let reason):
            return NSLocalizedString(
                "Data encryption failed." + (reason.map { "\n\($0)" } ?? ""),
                comment: "Error description for data encryption failure")
        case .unknown(let error):
            if let error = error {
                return NSLocalizedString(
                    "An unexpected error occurred: \(error.localizedDescription)",
                    comment: "Error description for unknown error with underlying error")
            }
            return NSLocalizedString("An unexpected error occurred.", comment: "Error description for unknown error without underlying error")
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .networkUnavailable:
            return NSLocalizedString("Check your internet connection and try again.", comment: "Recovery suggestion for network unavailable")
        case .permissionDenied:
            return NSLocalizedString("Please update your app permissions in Settings.", comment: "Recovery suggestion for permission denied")
        case .invalidInput:
            return NSLocalizedString("Please review the highlighted fields.", comment: "Recovery suggestion for invalid input")
        default:
            return nil
        }
    }

    public var isRecoverable: Bool {
        switch self {
        case .invalidInput, .networkUnavailable, .permissionDenied, .unauthorizedAccess:
            return true
        default:
            return false
        }
    }

    /// Indicates if error is severe and should be escalated to compliance/trust center.
    public var shouldEscalate: Bool {
        switch self {
        case .permissionDenied, .unauthorizedAccess, .dataEncryptionFailed, .unknown:
            return true
        default:
            return false
        }
    }

    /// Logs an error event (optionally escalates if needed).
    public func log(event: String = "app_error", escalate: Bool? = nil, context: String? = nil) {
        guard !AppError.testMode else { return }
        let eventObj = AppErrorEvent(
            event: event,
            error: self,
            role: AppError.currentRole,
            staffID: AppError.currentStaffID,
            context: context ?? AppError.currentContext,
            escalate: escalate ?? shouldEscalate
        )
        Task {
            await AppError.analyticsLogger.log(event: eventObj)
            if eventObj.escalate {
                await AppError.analyticsLogger.escalate(event: eventObj)
            }
        }
    }

    /// Convert any error into AppError (logs event automatically).
    public static func from(_ error: Error, context: String? = nil) -> AppError {
        if let appError = error as? AppError {
            appError.log(event: "app_error_from", context: context)
            return appError
        } else {
            let wrapped = AppError.unknown(error: error)
            wrapped.log(event: "app_error_from_unknown", context: context)
            return wrapped
        }
    }

    // Demo/Test/Preview utilities
    public static let allCases: [AppError] = [
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
    public static var allDemoLocalizedErrors: [LocalizedError] {
        return allCases
    }
    public enum DemoType {
        case dataLoadFailed, saveFailed, invalidInput, duplicateEntry, networkUnavailable, permissionDenied, unauthorizedAccess, tspRouteError, dataEncryptionFailed, unknown
    }
    public static func demo(_ type: DemoType, role: String? = nil, staffID: String? = nil, context: String? = nil) -> AppError {
        let demoErr: AppError
        switch type {
        case .dataLoadFailed:        demoErr = .dataLoadFailed(reason: "Demo data load failure")
        case .saveFailed:            demoErr = .saveFailed(reason: "Demo save failure")
        case .invalidInput:          demoErr = .invalidInput(reason: "Demo invalid input")
        case .duplicateEntry:        demoErr = .duplicateEntry
        case .networkUnavailable:    demoErr = .networkUnavailable
        case .permissionDenied:      demoErr = .permissionDenied(type: "Camera Access")
        case .unauthorizedAccess:    demoErr = .unauthorizedAccess(role: "Guest User")
        case .tspRouteError:         demoErr = .tspRouteError(reason: "Demo route optimization error")
        case .dataEncryptionFailed:  demoErr = .dataEncryptionFailed(reason: "Demo encryption failure")
        case .unknown:               demoErr = .unknown(error: nil)
        }
        if !AppError.testMode {
            let prevRole = AppError.currentRole
            let prevStaff = AppError.currentStaffID
            let prevContext = AppError.currentContext
            AppError.currentRole = role
            AppError.currentStaffID = staffID
            AppError.currentContext = context
            demoErr.log(event: "app_error_demo", escalate: demoErr.shouldEscalate)
            AppError.currentRole = prevRole
            AppError.currentStaffID = prevStaff
            AppError.currentContext = prevContext
        }
        return demoErr
    }
}

// Usage Example:
//
// @State private var currentError: AppError?
//
// .alert(item: $currentError) { error in
//     Alert(
//         title: Text("Error"),
//         message: Text(error.errorDescription ?? "An error occurred."),
//         dismissButton: .default(Text("OK"))
//     )
// }
//
// To trigger with role/context for audit trail:
// currentError = AppError.demo(.networkUnavailable, role: "groomer", staffID: "staff123", context: "AppointmentScheduler")
//

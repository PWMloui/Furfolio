//
//  CrashReporter.swift
//  Furfolio
//
//  Enhanced: Audit/analytics-ready, token-compliant, modular, extensible, and enterprise-ready.
//

import Foundation
import SwiftUI

/// Represents a logged crash, fatal error, or serious exception within the Furfolio app.
/// This model captures critical error information for diagnostics and user support.
/// All user-facing strings, especially `type` values, must be localized before display in UI.
/// This class integrates with audit/analytics systems for Trust Center compliance and business intelligence.
///
/// - Extensible: Designed for more device/environment data and automated audit logging.
/// - Token Compliance: All UI rendering of this data must use design tokens (e.g., `AppFonts.caption`, `AppColors.textSecondary`).
/// - Accessible: All UI that presents crash data should include accessibility labels/hints.
/// - Preview/Testable: Fully testable with dependency injection for analytics/logging.

@Model
final class CrashReport: Identifiable, ObservableObject {

    // MARK: - Constants

    static let typeCrash = NSLocalizedString("Crash", comment: "Crash type label")
    static let typeFatalError = NSLocalizedString("Fatal Error", comment: "Fatal error type label")
    static let typeDataCorruption = NSLocalizedString("Data Corruption", comment: "Data corruption type label")

    // MARK: - Properties

    /// Unique identifier for the report.
    @Attribute(.unique)
    var id: UUID

    /// The date and time when the issue occurred.
    var date: Date

    /// The classification of the crash (e.g., Crash, Fatal Error).
    /// Always localize before UI display.
    var type: String

    /// A brief summary or message describing the error.
    var message: String

    /// The call stack at the time of the crash (if available).
    var stackTrace: String?

    /// Summary of the device environment at the time.
    var deviceInfo: String?

    /// Whether the issue has been resolved or acknowledged by the user or system.
    var resolved: Bool

    // MARK: - Extra Device/Build Info for Diagnostics

    /// The app version when the crash occurred.
    var appVersion: String? = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String

    /// The build number when the crash occurred.
    var buildNumber: String? = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

    /// The iOS version at the time of the crash.
    var osVersion: String = UIDevice.current.systemVersion

    /// The device model at the time of the crash.
    var deviceModel: String = UIDevice.current.model

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        type: String,
        message: String,
        stackTrace: String? = nil,
        deviceInfo: String? = nil,
        resolved: Bool = false,
        appVersion: String? = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
        buildNumber: String? = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
        osVersion: String = UIDevice.current.systemVersion,
        deviceModel: String = UIDevice.current.model
    ) {
        self.id = id
        self.date = date
        self.type = type
        self.message = message
        self.stackTrace = stackTrace
        self.deviceInfo = deviceInfo
        self.resolved = resolved
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.osVersion = osVersion
        self.deviceModel = deviceModel

        // Automatic audit/analytics log on creation
        CrashReport.auditLogger?.logCrash(report: self)
    }

    // MARK: - Computed Properties

    /// A human-readable timestamp for UI display.
    /// Any display in the UI must use design tokens for fonts/colors.
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// A concise, accessible description for admin/QA views.
    var accessibilitySummary: String {
        let status = resolved ? NSLocalizedString("Resolved", comment: "") : NSLocalizedString("Unresolved", comment: "")
        return String(format: NSLocalizedString("%@ occurred at %@: %@ (%@)", comment: "Crash report accessibility summary"), type, formattedDate, message, status)
    }

    // MARK: - Audit/Analytics Integration

    /// Analytics/audit logger for crash reporting (protocol-based for test/preview/enterprise compliance).
    public static var auditLogger: CrashAuditLogger? = nil
}

/// Audit logger protocol for crash reports (inject for business/analytics/Trust Center compliance).
public protocol CrashAuditLogger {
    func logCrash(report: CrashReport)
}

/// Default no-op logger (for preview/test).
public struct NullCrashAuditLogger: CrashAuditLogger {
    public init() {}
    public func logCrash(report: CrashReport) {}
}

// MARK: - Example UI View (Token/Accessibility Compliant)

struct CrashReportRowView: View {
    let report: CrashReport

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small ?? 8) {
            HStack {
                Text(report.type)
                    .font(AppFonts.body ?? .body)
                    .foregroundColor(AppColors.error ?? .red)
                if report.resolved {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(AppColors.success ?? .green)
                        .accessibilityLabel(Text(NSLocalizedString("Resolved", comment: "")))
                }
                Spacer()
                Text(report.formattedDate)
                    .font(AppFonts.caption ?? .caption)
                    .foregroundColor(AppColors.textSecondary ?? .secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text(report.accessibilitySummary))

            Text(report.message)
                .font(AppFonts.body ?? .body)
                .foregroundColor(AppColors.textPrimary ?? .primary)
        }
        .padding(.vertical, AppSpacing.small ?? 8)
        .accessibilityElement(children: .contain)
    }
}

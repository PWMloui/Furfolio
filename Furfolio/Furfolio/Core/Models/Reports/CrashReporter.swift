//
//  CrashReporter.swift
//  Furfolio
//
//  Enhanced: Audit/analytics-ready, token-compliant, modular, extensible, and enterprise-ready.
//

/**
 CrashReporter
 -------------
 A robust crash reporting model for Furfolio, capturing and presenting critical error data.

 - **Purpose**: Records crashes, fatal errors, and serious exceptions with full context for diagnostics.
 - **Architecture**: Uses @Model for persistence, ObservableObject for SwiftUI binding.
 - **Concurrency & Audit**: Integrates async audit logging via `CrashReportAuditManager` actor.
 - **Analytics Ready**: Supports injection of async audit/analytics loggers conforming to `CrashAuditLogger`.
 - **Localization & Accessibility**: All user-facing strings are localized; UI elements include accessibility summaries.
 - **Diagnostics & Preview/Testability**: Provides async methods to fetch and export audit entries for testing and monitoring.
 */

import Foundation
import SwiftUI

/// Represents a single audit entry for crash reporting events.
public struct CrashReportAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let reportID: UUID
    public let type: String
    public let message: String

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        reportID: UUID,
        type: String,
        message: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.reportID = reportID
        self.type = type
        self.message = message
    }
}

/// Concurrency-safe actor for auditing crash report events.
public actor CrashReportAuditManager {
    private var buffer: [CrashReportAuditEntry] = []
    private let maxEntries = 100
    public static let shared = CrashReportAuditManager()

    /// Add a new audit entry, trimming oldest if exceeding maxEntries.
    public func add(_ entry: CrashReportAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Fetch recent entries up to the specified limit.
    public func recent(limit: Int = 20) -> [CrashReportAuditEntry] {
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
        Task {
            if let logger = CrashReport.auditLogger {
                await logger.logCrash(report: self)
            }
            await CrashReportAuditManager.shared.add(
                CrashReportAuditEntry(
                    reportID: id,
                    type: type,
                    message: message
                )
            )
        }
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
    /// Asynchronously logs a crash report for audit/analytics.
    func logCrash(report: CrashReport) async
}

/// Default no-op logger (for preview/test).
public struct NullCrashAuditLogger: CrashAuditLogger {
    public init() {}
    public func logCrash(report: CrashReport) async {}
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

public extension CrashReport {
    /// Fetch recent crash report audit entries for diagnostics.
    static func recentAuditEntries(limit: Int = 20) async -> [CrashReportAuditEntry] {
        await CrashReportAuditManager.shared.recent(limit: limit)
    }

    /// Export crash report audit entries as a JSON string.
    static func exportAuditLogJSON() async -> String {
        await CrashReportAuditManager.shared.exportJSON()
    }
}

//
//  FeedbackCategory.swift
//  Furfolio
//
//

/// `FeedbackCategory` represents user feedback and support request types with a robust architecture designed for concurrency safety, audit and analytics readiness, buffer management, diagnostics, localization, accessibility, and preview/testability.
///
/// Architecture & Concurrency:
/// - Uses a dedicated serial dispatch queue for analytics and audit logging to ensure thread safety.
/// - Introduces an actor-based audit manager to asynchronously manage audit log entries in a buffer capped at a maximum size.
///
/// Audit & Analytics Readiness:
/// - Provides asynchronous methods for logging analytics and audit events.
/// - Audit events are stored in a structured buffer with timestamped entries, facilitating export and inspection.
///
/// Buffer Management:
/// - Audit entries are retained up to a configurable maximum (default 100), with oldest entries discarded first.
///
/// Diagnostics & Localization:
/// - All user-facing strings are localized for internationalization.
/// - Accessibility labels provide descriptive context for UI elements.
///
/// Accessibility:
/// - Each category includes an accessibility label for screen readers.
/// - SF Symbols are validated for availability on the current OS.
///
/// Preview & Testability:
/// - Includes SwiftUI previews demonstrating async logging.
/// - Provides unit test stubs for async analytics and audit logging verification.
import Foundation
import SwiftUI
import SwiftData

/// Represents an audit log entry for feedback category selections.
@Model public
struct FeedbackAuditEntry: Identifiable {
    @Attribute(.unique) var id: UUID
    let timestamp: Date
    let category: FeedbackCategory
    let analyticsKey: String
}

actor FeedbackCategoryAuditManager {
    private var buffer: [FeedbackAuditEntry] = []
    private let maxEntries = 100

    static let shared = FeedbackCategoryAuditManager()

    /// Adds a new audit entry to the buffer, maintaining a maximum buffer size.
    /// - Parameter entry: The `FeedbackAuditEntry` to add.
    func add(_ entry: FeedbackAuditEntry) async {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Returns the most recent audit entries up to the specified limit.
    /// - Parameter limit: Maximum number of entries to return (default 20).
    /// - Returns: Array of recent `FeedbackAuditEntry` instances.
    func recent(limit: Int = 20) async -> [FeedbackAuditEntry] {
        let count = buffer.count
        guard count > 0 else { return [] }
        let start = max(0, count - limit)
        return Array(buffer[start..<count])
    }

    /// Exports the entire audit log buffer as a JSON string.
    /// - Returns: JSON string representation of audit entries, or `"[]"` on encoding failure.
    func exportJSON() async -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(buffer)
            return String(data: data, encoding: .utf8) ?? "[]"
        } catch {
            return "[]"
        }
    }
}

// MARK: - Async Analytics & Audit Logging Extensions
extension FeedbackCategory {
    /// A dedicated serial queue for analytics and audit logging to ensure concurrency safety.
    private static let analyticsLogQueue = DispatchQueue(label: "com.furfolio.feedbackCategory.analyticsLogQueue")

    /// Logs the selection of a feedback category to the analytics system asynchronously.
    ///
    /// - Parameter category: The selected `FeedbackCategory`.
    /// - Note: Uses a private serial queue for concurrency safety. Logging is localized.
    /// - Usage:
    ///   ```
    ///   await FeedbackCategory.logSelection(.bugReport)
    ///   ```
    public static func logSelection(_ category: FeedbackCategory) async {
        await withCheckedContinuation { continuation in
            analyticsLogQueue.async {
                let eventName = NSLocalizedString("Feedback Category Selected", comment: "Analytics event name for feedback category selection")
                let eventDescription = String(
                    format: NSLocalizedString("User selected feedback category: %@", comment: "Analytics event description with feedback category"),
                    category.displayName
                )
                // Create audit entry for analytics event
                let entry = FeedbackAuditEntry(id: UUID(), timestamp: Date(), category: category, analyticsKey: category.analyticsKey)
                Task {
                    await FeedbackCategoryAuditManager.shared.add(entry)
                }
                // TODO: Replace with real analytics system call.
                print("[Analytics] \(eventName): \(eventDescription) [key: \(category.analyticsKey)]")
                continuation.resume()
            }
        }
    }

    /// Logs the selection of a feedback category to the audit log asynchronously.
    ///
    /// - Parameter category: The selected `FeedbackCategory`.
    /// - Note: Uses a private serial queue for concurrency safety. Logging is localized.
    /// - Usage:
    ///   ```
    ///   await FeedbackCategory.auditLogSelection(.bugReport)
    ///   ```
    public static func auditLogSelection(_ category: FeedbackCategory) async {
        await withCheckedContinuation { continuation in
            analyticsLogQueue.async {
                let eventName = NSLocalizedString("Audit: Feedback Category Selected", comment: "Audit event name for feedback category selection")
                let eventDescription = String(
                    format: NSLocalizedString("Audit log - user selected feedback category: %@", comment: "Audit event description with feedback category"),
                    category.displayName
                )
                // Create audit entry
                let entry = FeedbackAuditEntry(id: UUID(), timestamp: Date(), category: category, analyticsKey: category.analyticsKey)
                Task {
                    await FeedbackCategoryAuditManager.shared.add(entry)
                }
                // Console output for diagnostics (if test mode)
                print("[Audit] \(eventName): \(eventDescription) [key: \(category.analyticsKey)]")
                continuation.resume()
            }
        }
    }

    /// Asynchronously maps an analytics key to a `FeedbackCategory`, if possible.
    ///
    /// - Parameter key: The analytics key (case-insensitive).
    /// - Returns: The matching `FeedbackCategory`, or `nil` if not found.
    /// - Usage:
    ///   ```
    ///   let cat = await FeedbackCategory.category(forAnalyticsKey: "bug")
    ///   ```
    public static func category(forAnalyticsKey key: String) async -> FeedbackCategory? {
        // No async work, but for interface symmetry and possible future I/O.
        return from(analyticsKey: key)
    }

    /// Returns the most recent audit log entries up to a specified limit.
    ///
    /// - Parameter limit: Maximum number of entries to retrieve (default is 20).
    /// - Returns: Array of recent `FeedbackAuditEntry` instances.
    public static func recentAuditEntries(limit: Int = 20) async -> [FeedbackAuditEntry] {
        await FeedbackCategoryAuditManager.shared.recent(limit: limit)
    }

    /// Exports the entire audit log as a JSON string.
    ///
    /// - Returns: JSON string representing the audit log entries.
    public static func exportAuditLogJSON() async -> String {
        await FeedbackCategoryAuditManager.shared.exportJSON()
    }
}

//
//  FeedbackCategory.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//  Enhanced for internationalization, accessibility, analytics, and UI.
//

import Foundation
import SwiftUI

/// Categories for user feedback and support requests.
/// Use these for analytics, triage, and routing.
enum FeedbackCategory: String, CaseIterable, Identifiable, Codable {
    case bugReport = "Bug Report"
    case featureRequest = "Feature Request"
    case generalFeedback = "General Feedback"
    case billingIssue = "Billing Issue"
    case accountHelp = "Account Help"
    case dataExport = "Data Export"
    case compliance = "Compliance"
    case other = "Other"

    // MARK: - Display Name (Localized)
    var displayName: String {
        NSLocalizedString(self.rawValue, comment: "Feedback category: \(self.rawValue)")
    }

    // MARK: - Accessibility Label
    var accessibilityLabel: String {
        switch self {
        case .bugReport: return NSLocalizedString("Report an app bug or technical issue.", comment: "")
        case .featureRequest: return NSLocalizedString("Suggest a new feature or improvement.", comment: "")
        case .generalFeedback: return NSLocalizedString("Share your thoughts about Furfolio.", comment: "")
        case .billingIssue: return NSLocalizedString("Get help with billing or payments.", comment: "")
        case .accountHelp: return NSLocalizedString("Account or login help.", comment: "")
        case .dataExport: return NSLocalizedString("Request a data export.", comment: "")
        case .compliance: return NSLocalizedString("Privacy, legal, or audit concerns.", comment: "")
        case .other: return NSLocalizedString("Other feedback or inquiry.", comment: "")
        }
    }

    // MARK: - Developer-friendly identifier.
    var id: String { rawValue }

    // MARK: - Analytics/Event Key (short, lowercase)
    var analyticsKey: String {
        switch self {
        case .bugReport: return "bug"
        case .featureRequest: return "feature"
        case .generalFeedback: return "feedback"
        case .billingIssue: return "billing"
        case .accountHelp: return "account"
        case .dataExport: return "export"
        case .compliance: return "compliance"
        case .other: return "other"
        }
    }

    // MARK: - SF Symbol for visual context in the UI.
    var icon: String {
        switch self {
        case .bugReport: return "ladybug"
        case .featureRequest: return "lightbulb"
        case .generalFeedback: return "bubble.left.and.bubble.right"
        case .billingIssue: return "creditcard"
        case .accountHelp: return "person.crop.circle.badge.questionmark"
        case .dataExport: return "square.and.arrow.up"
        case .compliance: return "checkmark.shield"
        case .other: return "ellipsis.bubble"
        }
    }

    /// Returns true if the SF Symbol exists on this OS (future-proofing).
    var isValidSymbol: Bool {
        UIImage(systemName: icon) != nil
    }

    // MARK: - Localized Description
    var description: String {
        switch self {
        case .bugReport:
            return NSLocalizedString("Report an app bug or technical issue.", comment: "")
        case .featureRequest:
            return NSLocalizedString("Suggest a new feature or improvement.", comment: "")
        case .generalFeedback:
            return NSLocalizedString("Share your thoughts about Furfolio.", comment: "")
        case .billingIssue:
            return NSLocalizedString("Get help with billing, payments, or invoices.", comment: "")
        case .accountHelp:
            return NSLocalizedString("Issues accessing your account, settings, or data.", comment: "")
        case .dataExport:
            return NSLocalizedString("Request your business or customer data export.", comment: "")
        case .compliance:
            return NSLocalizedString("Report privacy, audit, or legal concerns.", comment: "")
        case .other:
            return NSLocalizedString("Any other inquiry or feedback.", comment: "")
        }
    }

    // MARK: - Category grouping (for sectioned picker/future UX)
    var group: String {
        switch self {
        case .bugReport, .featureRequest, .generalFeedback, .other:
            return NSLocalizedString("General", comment: "")
        case .billingIssue, .accountHelp, .dataExport, .compliance:
            return NSLocalizedString("Account & Compliance", comment: "")
        }
    }

    // MARK: - For sorting categories in pickers
    var order: Int {
        switch self {
        case .bugReport: return 0
        case .featureRequest: return 1
        case .generalFeedback: return 2
        case .billingIssue: return 3
        case .accountHelp: return 4
        case .dataExport: return 5
        case .compliance: return 6
        case .other: return 99
        }
    }

    // MARK: - Section headers for grouped UI
    static var grouped: [(group: String, items: [FeedbackCategory])] {
        Dictionary(grouping: allCases, by: { $0.group })
            .sorted { $0.value.first?.order ?? 0 < $1.value.first?.order ?? 0 }
            .map { ($0.key, $0.value.sorted { $0.order < $1.order }) }
    }

    // MARK: - Helper for analytics mapping (case-insensitive)
    static func from(analyticsKey: String) -> FeedbackCategory? {
        FeedbackCategory.allCases.first { $0.analyticsKey.lowercased() == analyticsKey.lowercased() }
    }

    // MARK: - For pickers and filtering (sorted)
    static var allCasesSorted: [FeedbackCategory] {
        FeedbackCategory.allCases.sorted { $0.order < $1.order }
    }

    // MARK: - Test/mock/demo support
    static var preview: FeedbackCategory { .featureRequest }
    static func random() -> FeedbackCategory { allCases.randomElement() ?? .generalFeedback }
}

// MARK: - SwiftUI Preview & Async Logging Demo
#if DEBUG
import XCTest
import SwiftUI

/// SwiftUI PreviewProvider demonstrating async logging.
struct FeedbackCategory_AsyncLogging_Previews: PreviewProvider {
    struct DemoView: View {
        @State private var lastLog: String = ""
        var body: some View {
            VStack(spacing: 16) {
                Text("Async Logging Demo")
                    .font(.headline)
                Button("Log Analytics") {
                    Task {
                        await FeedbackCategory.logSelection(.featureRequest)
                        lastLog = "Analytics logged: \(FeedbackCategory.featureRequest.displayName)"
                    }
                }
                Button("Log Audit") {
                    Task {
                        await FeedbackCategory.auditLogSelection(.featureRequest)
                        lastLog = "Audit logged: \(FeedbackCategory.featureRequest.displayName)"
                    }
                }
                Text(lastLog)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
    static var previews: some View {
        DemoView()
    }
}

/// Unit test stub demonstrating async logging calls.
final class FeedbackCategoryAsyncLoggingTests: XCTestCase {
    func testAsyncAnalyticsLogging() async {
        await FeedbackCategory.logSelection(.bugReport)
        await FeedbackCategory.auditLogSelection(.bugReport)
        let mapped = await FeedbackCategory.category(forAnalyticsKey: "bug")
        XCTAssertEqual(mapped, .bugReport)
    }
}
#endif

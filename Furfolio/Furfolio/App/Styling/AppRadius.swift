//
//  AppRadius.swift
//  Furfolio
//
//  Created by mac on 6/27/25.
//
//
//  # AppRadius.swift – Architecture & Maintainer Guide
//
//  ## Overview
//  This file encapsulates the definition and management of "radius tokens" (corner radii) for the Furfolio app, providing a single source of truth for consistent rounded UI elements across the app. It also implements an extensible, async/await-ready analytics logging protocol for Trust Center, auditing, diagnostics, and preview/testability.
//
//  ## Architecture
//  - **AppRadius struct:** Defines all common radius tokens (e.g., small, medium, large, button, card, etc.) as optional `CGFloat` properties for theme flexibility. Each token exposes a `displayName` property, localized for UI/Accessibility.
//  - **Analytics/Audit/Trust Center:** The `AppRadiusAnalyticsLogger` protocol enables async event logging with audit context, with support for test/preview mode and a capped buffer for diagnostics. Pluggable loggers allow integration with production analytics or Trust Center compliance systems.
//  - **Diagnostics:** The analytics logger buffers the last 20 audit events, retrievable via the public API for admin/diagnostics screens or debugging.
//  - **Localization:** All display names are localized using `NSLocalizedString`, with clear keys and comments for translators.
//  - **Accessibility:** Tokens are described with accessible display names, and the preview demonstrates VoiceOver and test mode.
//  - **Compliance:** This module is designed for privacy compliance: analytics logging is opt-in, supports test/preview-only logging, includes audit context, and is easily auditable.
//  - **Preview/Testability:** Includes a `NullAppRadiusAnalyticsLogger` for previews/tests, and a `PreviewProvider` demonstrating accessibility, testMode, diagnostics, and audit context.
//
//  ## Extensibility
//  - Add new radius tokens by extending the `AppRadius` struct and updating the localization table.
//  - Integrate with new analytics backends by implementing `AppRadiusAnalyticsLogger`.
//
//  ## Maintenance
//  - Update the localization keys/values as new tokens are added.
//  - Use the diagnostics API to monitor event logging and Trust Center integration.
//
//  ## Example Usage
//      let radius = AppRadius.shared.button ?? 8
//      let logger = MyAnalyticsLogger()
//      await logger.log(
//          event: .radiusTokenUsed("button"),
//          role: AppRadiusAuditContext.role,
//          staffID: AppRadiusAuditContext.staffID,
//          context: AppRadiusAuditContext.context,
//          escalate: false
//      )
//
//  ---

import Foundation
import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct AppRadiusAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "AppRadius"
}

/// Protocol for async/await-ready analytics logging for AppRadius usage/events with audit context.
/// Implement this protocol to hook into Trust Center, analytics, or auditing systems.
/// - testMode: If true, logs only to console (used in tests/previews).
@MainActor
public protocol AppRadiusAnalyticsLogger: AnyObject {
    /// If true, logger only logs to console (no network/persistence). Used for QA/tests/previews.
    var testMode: Bool { get set }
    /// Log an analytics event asynchronously with audit context and escalation flag.
    func log(
        event: AppRadius.AnalyticsEvent,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async
    /// Fetch the most recent audit events (capped buffer, e.g., last 20).
    func recentEvents() -> [AppRadiusAnalyticsAuditEvent]
}

/// Audit event wrapper for analytics events with context and escalation, for Trust Center compliance.
public struct AppRadiusAnalyticsAuditEvent: Identifiable, CustomStringConvertible {
    public let id = UUID()
    public let timestamp: Date
    public let event: AppRadius.AnalyticsEvent
    public let role: String?
    public let staffID: String?
    public let context: String?
    public let escalate: Bool

    public var description: String {
        "\(event) [role:\(role ?? "-") staffID:\(staffID ?? "-") context:\(context ?? "-") escalate:\(escalate) @\(timestamp)]"
    }
}

/// Null logger for previews/tests: does nothing but stores audit events with context.
public final class NullAppRadiusAnalyticsLogger: AppRadiusAnalyticsLogger {
    public var testMode: Bool = true
    private var buffer: [AppRadiusAnalyticsAuditEvent] = []
    public init() {}
    public func log(
        event: AppRadius.AnalyticsEvent,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async {
        let auditEvent = AppRadiusAnalyticsAuditEvent(
            timestamp: Date(),
            event: event,
            role: role,
            staffID: staffID,
            context: context,
            escalate: escalate
        )
        buffer.append(auditEvent)
        if testMode {
            print("AppRadiusAuditLog: \(auditEvent.description)")
        }
        if buffer.count > 20 { buffer.removeFirst() }
    }
    public func recentEvents() -> [AppRadiusAnalyticsAuditEvent] { buffer }
}

/// Central struct for app-wide corner radius tokens.
/// Allows for theme overrides (nil means use system default).
public struct AppRadius {
    /// Singleton instance for global radius configuration.
    public static var shared = AppRadius()

    // MARK: - Radius Tokens
    /// Smallest radius, for subtle rounding.
    public var small: CGFloat? = 4
    /// Medium radius, for general UI elements.
    public var medium: CGFloat? = 8
    /// Large radius, for prominent cards/containers.
    public var large: CGFloat? = 16
    /// Button-specific radius.
    public var button: CGFloat? = 12
    /// Card-specific radius.
    public var card: CGFloat? = 20
    /// Avatar/profile image radius.
    public var avatar: CGFloat? = 40
    /// Pills/chips radius.
    public var pill: CGFloat? = 999 // large enough for full rounding

    // MARK: - Localized Display Names
    /// Localized display name for each token, for accessibility/UI.
    public var smallDisplayName: String { AppRadius.localizedDisplayName(for: "small") }
    public var mediumDisplayName: String { AppRadius.localizedDisplayName(for: "medium") }
    public var largeDisplayName: String { AppRadius.localizedDisplayName(for: "large") }
    public var buttonDisplayName: String { AppRadius.localizedDisplayName(for: "button") }
    public var cardDisplayName: String { AppRadius.localizedDisplayName(for: "card") }
    public var avatarDisplayName: String { AppRadius.localizedDisplayName(for: "avatar") }
    public var pillDisplayName: String { AppRadius.localizedDisplayName(for: "pill") }

    /// Helper for localized display names.
    private static func localizedDisplayName(for token: String) -> String {
        NSLocalizedString(
            "AppRadius.\(token)",
            value: token.capitalized,
            comment: "Display name for the '\(token)' radius token"
        )
    }

    // MARK: - Analytics Event
    /// Analytics events for AppRadius usage/audit.
    public enum AnalyticsEvent: Codable, Equatable, CustomStringConvertible {
        /// A radius token was used (e.g., for a UI element).
        case radiusTokenUsed(token: String, value: CGFloat?)
        /// Diagnostics event (e.g., admin viewing buffer).
        case diagnosticsViewed(timestamp: Date)
        /// Custom event.
        case custom(name: String, meta: [String: String])

        public var description: String {
            switch self {
            case let .radiusTokenUsed(token, value):
                return "RadiusTokenUsed: \(token) = \(value.map { "\($0)" } ?? "nil")"
            case let .diagnosticsViewed(ts):
                return "DiagnosticsViewed: \(ts)"
            case let .custom(name, meta):
                return "Custom: \(name) meta: \(meta)"
            }
        }
    }

    // MARK: - Analytics Logger
    /// The logger instance for analytics/audit. Defaults to null logger.
    public static var analyticsLogger: AppRadiusAnalyticsLogger = NullAppRadiusAnalyticsLogger()

    /// Log a radius token usage event with audit context and escalation flag.
    public static func logTokenUsage(_ token: String, value: CGFloat?) async {
        await analyticsLogger.log(
            event: .radiusTokenUsed(token: token, value: value),
            role: AppRadiusAuditContext.role,
            staffID: AppRadiusAuditContext.staffID,
            context: AppRadiusAuditContext.context,
            escalate: token.lowercased().contains("danger") || token.lowercased().contains("critical")
        )
    }

    /// Fetch recent analytics audit events (last 20).
    public static func recentAnalyticsEvents() -> [AppRadiusAnalyticsAuditEvent] {
        analyticsLogger.recentEvents()
    }
}

#if DEBUG
import Combine

/// SwiftUI Preview demonstrating accessibility, testMode, diagnostics, and audit context.
struct AppRadius_Preview: View {
    @State private var diagnostics: [AppRadiusAnalyticsAuditEvent] = []
    @State private var logger: AppRadiusAnalyticsLogger = {
        let l = NullAppRadiusAnalyticsLogger()
        l.testMode = true
        AppRadius.analyticsLogger = l
        return l
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Group {
                Text("AppRadius Preview")
                    .font(.title)
                    .accessibilityAddTraits(.isHeader)
                radiusRow(token: "small", value: AppRadius.shared.small, displayName: AppRadius.shared.smallDisplayName)
                radiusRow(token: "medium", value: AppRadius.shared.medium, displayName: AppRadius.shared.mediumDisplayName)
                radiusRow(token: "large", value: AppRadius.shared.large, displayName: AppRadius.shared.largeDisplayName)
                radiusRow(token: "button", value: AppRadius.shared.button, displayName: AppRadius.shared.buttonDisplayName)
                radiusRow(token: "card", value: AppRadius.shared.card, displayName: AppRadius.shared.cardDisplayName)
            }
            Divider()
            Button("View Diagnostics (last 20 events)") {
                Task {
                    await logger.log(
                        event: .diagnosticsViewed(timestamp: Date()),
                        role: AppRadiusAuditContext.role,
                        staffID: AppRadiusAuditContext.staffID,
                        context: AppRadiusAuditContext.context,
                        escalate: false
                    )
                    diagnostics = logger.recentEvents()
                }
            }
            .accessibilityLabel("View Diagnostics")
            .accessibilityHint("Shows the last 20 analytics events for admin/diagnostics")
            .padding(.vertical)
            .foregroundColor(.accentColor)
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(diagnostics) { event in
                        Text(event.description)
                            .font(.caption)
                            .accessibilityLabel(event.description)
                    }
                }
            }
            Spacer()
            Text("TestMode: \(logger.testMode ? "ON" : "OFF")")
                .font(.footnote)
                .foregroundColor(.secondary)
                .accessibilityLabel("Test Mode \(logger.testMode ? "on" : "off")")
        }
        .padding()
        .onAppear {
            // Simulate token usage for diagnostics.
            Task {
                await AppRadius.logTokenUsage("small", value: AppRadius.shared.small)
                await AppRadius.logTokenUsage("medium", value: AppRadius.shared.medium)
                await AppRadius.logTokenUsage("large", value: AppRadius.shared.large)
                await AppRadius.logTokenUsage("button", value: AppRadius.shared.button)
                await AppRadius.logTokenUsage("card", value: AppRadius.shared.card)
            }
        }
    }

    /// Helper for displaying a radius token row.
    func radiusRow(token: String, value: CGFloat?, displayName: String) -> some View {
        HStack {
            RoundedRectangle(cornerRadius: value ?? 0)
                .fill(Color.accentColor.opacity(0.3))
                .frame(width: 48, height: 24)
                .accessibilityHidden(true)
            Text("\(displayName): \(value.map { String(format: "%.0f", $0) } ?? "nil")")
                .accessibilityLabel("\(displayName), \(value.map { "\($0)" } ?? "system default")")
            Spacer()
            Button("Log Usage") {
                Task { await AppRadius.logTokenUsage(token, value: value) }
            }
            .font(.caption)
            .accessibilityLabel("Log \(displayName) usage")
        }
    }
}

struct AppRadius_PreviewProvider: PreviewProvider {
    static var previews: some View {
        AppRadius_Preview()
            .environment(\.locale, .init(identifier: "en"))
    }
}
#endif

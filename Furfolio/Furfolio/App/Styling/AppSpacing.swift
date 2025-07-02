//
//  AppSpacing.swift
//  Furfolio
//
//  Architecture:
//  AppSpacing.swift centralizes all standard spacing tokens used throughout the Furfolio app. It provides a robust, tokenized spacing system designed for extensibility, brand/theme customization, and consistent usage across the UI. The architecture supports future-proofing by allowing new tokens and overrides without breaking existing code.
//
//  Extensibility:
//  The spacing tokens are defined as static constants with fallback values, but the fetch mechanism allows integration with brand or theme providers. This enables dynamic spacing adjustments per brand or user preferences.
//
//  Analytics/Audit/Trust Center Hooks:
//  Every spacing token access and custom spacing usage is logged asynchronously through the AppSpacingAnalyticsLogger protocol. This facilitates audit trails, usage analytics, and compliance monitoring. A capped buffer stores recent events for diagnostics and admin review.
//
//  Diagnostics:
//  The module maintains a capped buffer of the last 20 analytics events. This buffer is exposed via a public API to assist in debugging, QA, and admin diagnostics.
//
//  Localization:
//  All user-facing strings, including token names and preview labels, are localized using NSLocalizedString with explicit keys and comments to support internationalization.
//
//  Accessibility:
//  The preview includes accessibility considerations, such as dynamic text sizing and clear labeling, to ensure the spacing tokens and their representations are accessible.
//
//  Compliance:
//  The design supports compliance with audit and trust center requirements by providing detailed logging and traceability of spacing usage.
//
//  Preview/Testability:
//  The preview provider demonstrates the spacing tokens with localized labels, analytics logging in test mode, accessibility support, and diagnostics buffer display. The analytics logger supports a testMode property to enable console-only logging during QA and previews.
//
//  Usage:
//  Use AppSpacing tokens via the `.appPadding(_:)` view extension or directly with `.padding(AppSpacing.token)` for consistent, token-compliant spacing.
//
//  Example:
//      .padding(AppSpacing.medium)
//      .appPadding(AppSpacing.large)
//

import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct AppSpacingAuditContext {
    /// Role of the current user (set at login/session for trust center/audit).
    public static var role: String? = nil
    /// Staff ID of the current user (set at login/session for trust center/audit).
    public static var staffID: String? = nil
    /// Audit context for compliance/trust center.
    public static var context: String? = "AppSpacing"
}

// MARK: - Analytics/Audit/Trust Center Protocols & Event

/// Analytics event struct for AppSpacing audit/trust center/compliance logging.
public struct AppSpacingAnalyticsEvent: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let event: String
    public let value: CGFloat
    public let token: String
    public let role: String?
    public let staffID: String?
    public let context: String?
    public let escalate: Bool
}

/// Protocol defining asynchronous analytics logging for AppSpacing usage, with full audit context for trust center/compliance.
public protocol AppSpacingAnalyticsLogger {
    /// Indicates if the logger is in test mode (console-only logging).
    var testMode: Bool { get }
    /// Logs an analytics event asynchronously with full audit fields.
    /// - Parameters:
    ///   - event: The event name (e.g., "spacing_access").
    ///   - value: The CGFloat value associated with the event.
    ///   - token: The token name or label.
    ///   - role: User role for audit/compliance.
    ///   - staffID: Staff/user ID for audit/compliance.
    ///   - context: Audit context for trust center/compliance.
    ///   - escalate: Should this event be escalated for compliance (e.g., "danger", "delete", "critical").
    func log(
        event: String,
        value: CGFloat,
        token: String,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async
    /// Returns recent analytics events (if available).
    func recentEvents() -> [AppSpacingAnalyticsEvent]
}

/// Null logger implementation for previews and tests that performs no logging, but prints all audit fields if testMode is true.
public struct NullAppSpacingAnalyticsLogger: AppSpacingAnalyticsLogger {
    public let testMode: Bool = false
    public init() {}
    public func log(
        event: String,
        value: CGFloat,
        token: String,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async {
        if testMode {
            print("[NullAppSpacingAnalyticsLogger] event: \(event), token: \(token), value: \(value), role: \(role ?? "nil"), staffID: \(staffID ?? "nil"), context: \(context ?? "nil"), escalate: \(escalate)")
        }
    }
    public func recentEvents() -> [AppSpacingAnalyticsEvent] { [] }
}

// MARK: - AppSpacing (Centralized Spacing Tokens)

/// Central place for all standard spacing values in Furfolio.
/// Tokenized, asynchronous analytics/audit–ready, brand/theme–extensible, localized, and preview/test–injectable.
enum AppSpacing {
    // MARK: - Analytics Logger & Event Buffer (trust center/compliance)

    /// Analytics logger instance (default is Null logger).
    static var analyticsLogger: AppSpacingAnalyticsLogger = NullAppSpacingAnalyticsLogger()

    /// Internal capped buffer for recent analytics events (max 20).
    private static var eventBuffer: [AppSpacingAnalyticsEvent] = []

    /// Maximum number of events to keep in buffer.
    private static let maxBufferSize = 20

    /// Adds an event to the capped event buffer.
    /// - Parameter event: The AppSpacingAnalyticsEvent to add.
    private static func addEventToBuffer(_ event: AppSpacingAnalyticsEvent) {
        eventBuffer.append(event)
        if eventBuffer.count > maxBufferSize {
            eventBuffer.removeFirst(eventBuffer.count - maxBufferSize)
        }
    }

    /// Public API to fetch recent analytics events for diagnostics/admin/trust center.
    /// - Returns: Array of recent AppSpacingAnalyticsEvent objects.
    public static func recentAnalyticsEvents() -> [AppSpacingAnalyticsEvent] {
        return eventBuffer
    }

    // MARK: - Spacing Tokens (with robust fallback and localization)

    /// Localized token names for display and logging.
    private static let localizedTokens: [String: String] = [
        "none": NSLocalizedString("spacing_token_none", value: "None", comment: "Spacing token name: none"),
        "xxs": NSLocalizedString("spacing_token_xxs", value: "XXS", comment: "Spacing token name: extra extra small"),
        "xs": NSLocalizedString("spacing_token_xs", value: "XS", comment: "Spacing token name: extra small"),
        "xsmall": NSLocalizedString("spacing_token_xsmall", value: "XSmall", comment: "Spacing token name: alias for very small spacing"),
        "small": NSLocalizedString("spacing_token_small", value: "Small", comment: "Spacing token name: small"),
        "medium": NSLocalizedString("spacing_token_medium", value: "Medium", comment: "Spacing token name: medium"),
        "large": NSLocalizedString("spacing_token_large", value: "Large", comment: "Spacing token name: large"),
        "xl": NSLocalizedString("spacing_token_xl", value: "XL", comment: "Spacing token name: extra large"),
        "xxl": NSLocalizedString("spacing_token_xxl", value: "XXL", comment: "Spacing token name: extra extra large"),
        "section": NSLocalizedString("spacing_token_section", value: "Section", comment: "Spacing token name: section spacing"),
        "listItem": NSLocalizedString("spacing_token_listItem", value: "List Item", comment: "Spacing token name: vertical spacing in lists"),
        "card": NSLocalizedString("spacing_token_card", value: "Card", comment: "Spacing token name: card padding"),
        "avatar": NSLocalizedString("spacing_token_avatar", value: "Avatar", comment: "Spacing token name: avatar size"),
        "pulseButtonScale": NSLocalizedString("spacing_token_pulseButtonScale", value: "Pulse Button Scale", comment: "Spacing token name: pulse button scale factor"),
        "progressRingSize": NSLocalizedString("spacing_token_progressRingSize", value: "Progress Ring Size", comment: "Spacing token name: progress ring size"),
        "progressRingStroke": NSLocalizedString("spacing_token_progressRingStroke", value: "Progress Ring Stroke", comment: "Spacing token name: progress ring stroke width"),
        "skeletonPrimary": NSLocalizedString("spacing_token_skeletonPrimary", value: "Skeleton Primary", comment: "Spacing token name: skeleton primary width"),
        "skeletonSecondaryMin": NSLocalizedString("spacing_token_skeletonSecondaryMin", value: "Skeleton Secondary Min", comment: "Spacing token name: skeleton secondary minimum width"),
        "skeletonSecondaryVar": NSLocalizedString("spacing_token_skeletonSecondaryVar", value: "Skeleton Secondary Var", comment: "Spacing token name: skeleton secondary variable width"),
        "skeletonPrimaryHeight": NSLocalizedString("spacing_token_skeletonPrimaryHeight", value: "Skeleton Primary Height", comment: "Spacing token name: skeleton primary height"),
        "skeletonSecondaryHeight": NSLocalizedString("spacing_token_skeletonSecondaryHeight", value: "Skeleton Secondary Height", comment: "Spacing token name: skeleton secondary height"),
        "iconOffset": NSLocalizedString("spacing_token_iconOffset", value: "Icon Offset", comment: "Spacing token name: icon offset"),
    ]

    /// Returns the localized display name for a given token key.
    /// - Parameter token: The token key string.
    /// - Returns: Localized token name.
    static func localizedTokenName(_ token: String) -> String {
        localizedTokens[token] ?? token
    }

    static let none: CGFloat         = fetch("none", 0)
    static let xxs: CGFloat          = fetch("xxs", 2)
    static let xs: CGFloat           = fetch("xs", 4)
    static let small: CGFloat        = fetch("small", 8)
    static let medium: CGFloat       = fetch("medium", 16)
    static let large: CGFloat        = fetch("large", 24)
    static let xl: CGFloat           = fetch("xl", 32)
    static let xxl: CGFloat          = fetch("xxl", 40)
    static let section: CGFloat      = fetch("section", 48)
    static let listItem: CGFloat     = fetch("listItem", 12)  // e.g., vertical spacing in lists
    static let card: CGFloat         = fetch("card", 20)      // card padding

    // MARK: - Extendable tokens (future-proofed for components)
    static let avatar: CGFloat           = fetch("avatar", 42)
    static let pulseButtonScale: CGFloat = fetch("pulseButtonScale", 1.09)
    static let progressRingSize: CGFloat = fetch("progressRingSize", 86)
    static let progressRingStroke: CGFloat = fetch("progressRingStroke", 14)
    static let skeletonPrimary: CGFloat  = fetch("skeletonPrimary", 140)
    static let skeletonSecondaryMin: CGFloat = fetch("skeletonSecondaryMin", 90)
    static let skeletonSecondaryVar: CGFloat = fetch("skeletonSecondaryVar", 30)
    static let skeletonPrimaryHeight: CGFloat = fetch("skeletonPrimaryHeight", 15)
    static let skeletonSecondaryHeight: CGFloat = fetch("skeletonSecondaryHeight", 11)
    static let iconOffset: CGFloat       = fetch("iconOffset", 22)
    static let xsmall: CGFloat           = fetch("xsmall", 2) // Alias for very small spacing

    // MARK: - All values (for design system preview)

    /// Dictionary of all spacing tokens and their values.
    static let all: [String: CGFloat] = [
        "none": none,
        "xxs": xxs,
        "xs": xs,
        "xsmall": xsmall,
        "small": small,
        "medium": medium,
        "large": large,
        "xl": xl,
        "xxl": xxl,
        "section": section,
        "listItem": listItem,
        "card": card,
        "avatar": avatar,
        "pulseButtonScale": pulseButtonScale,
        "progressRingSize": progressRingSize,
        "progressRingStroke": progressRingStroke,
        "skeletonPrimary": skeletonPrimary,
        "skeletonSecondaryMin": skeletonSecondaryMin,
        "skeletonSecondaryVar": skeletonSecondaryVar,
        "skeletonPrimaryHeight": skeletonPrimaryHeight,
        "skeletonSecondaryHeight": skeletonSecondaryHeight,
        "iconOffset": iconOffset
    ]

    /// Unified API for custom spacing (still logs and future–brand–ready, with audit context).
    /// - Parameters:
    ///   - value: The custom spacing value.
    ///   - label: A descriptive label for the custom spacing.
    /// - Returns: The input spacing value.
    static func custom(_ value: CGFloat, label: String = NSLocalizedString("spacing_custom_label", value: "custom", comment: "Custom spacing label")) -> CGFloat {
        Task {
            await logAndBuffer(event: "custom_spacing", value: value, token: label)
        }
        return value
    }

    /// Robust, brand/theme–aware fetch with asynchronous logging and audit context.
    /// - Parameters:
    ///   - token: The spacing token key.
    ///   - fallback: The fallback CGFloat value.
    /// - Returns: The fallback value (future: lookup from brand/theme).
    private static func fetch(_ token: String, _ fallback: CGFloat) -> CGFloat {
        Task {
            await logAndBuffer(event: "spacing_access", value: fallback, token: token)
        }
        return fallback
    }

    /// Logs the event asynchronously with audit/trust center context and adds it to the diagnostics buffer.
    /// - Parameters:
    ///   - event: Event name.
    ///   - value: Value associated with event.
    ///   - token: Token or label.
    private static func logAndBuffer(event: String, value: CGFloat, token: String) async {
        let eventLower = event.lowercased()
        let tokenLower = token.lowercased()
        let escalate =
            eventLower.contains("danger") ||
            eventLower.contains("delete") ||
            eventLower.contains("critical") ||
            tokenLower.contains("danger")
        await analyticsLogger.log(
            event: event,
            value: value,
            token: token,
            role: AppSpacingAuditContext.role,
            staffID: AppSpacingAuditContext.staffID,
            context: AppSpacingAuditContext.context,
            escalate: escalate
        )
        let newEvent = AppSpacingAnalyticsEvent(
            timestamp: Date(),
            event: event,
            value: value,
            token: token,
            role: AppSpacingAuditContext.role,
            staffID: AppSpacingAuditContext.staffID,
            context: AppSpacingAuditContext.context,
            escalate: escalate
        )
        addEventToBuffer(newEvent)
    }
}

// MARK: - View Extension (Tokenized Padding)

extension View {
    /// Applies uniform padding using a named AppSpacing token (never a magic number).
    /// - Parameter spacing: Token from AppSpacing (default: .medium).
    /// - Returns: View with the specified padding.
    func appPadding(_ spacing: CGFloat = AppSpacing.medium) -> some View {
        self.padding(spacing)
    }
}

// MARK: - Preview (Design System/QA Review)

#if DEBUG
struct AppSpacingPreview: View {
    /// Spy logger implementation that logs asynchronously and supports testMode, prints all audit fields if testMode.
    class SpyLogger: AppSpacingAnalyticsLogger {
        let testMode: Bool
        private var buffer: [AppSpacingAnalyticsEvent] = []

        init(testMode: Bool = true) {
            self.testMode = testMode
        }

        func log(
            event: String,
            value: CGFloat,
            token: String,
            role: String?,
            staffID: String?,
            context: String?,
            escalate: Bool
        ) async {
            if testMode {
                print("[SpyLogger] event: \(event), token: \(token), value: \(value), role: \(role ?? "nil"), staffID: \(staffID ?? "nil"), context: \(context ?? "nil"), escalate: \(escalate)")
            }
            // No buffer storage (AppSpacing stores buffer)
        }

        func recentEvents() -> [AppSpacingAnalyticsEvent] {
            // Not used: AppSpacing handles buffer
            return []
        }
    }

    @State private var recentEvents: [AppSpacingAnalyticsEvent] = []
    @State private var logger = SpyLogger(testMode: true)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("spacing_preview_title", value: "AppSpacing Tokens", comment: "Preview title"))
                .font(.title2)
                .bold()
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, 4)

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(AppSpacing.all.keys.sorted()), id: \.self) { key in
                        let value = AppSpacing.all[key] ?? 0
                        HStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.blue.opacity(0.22))
                                .frame(width: value, height: 18)
                                .accessibilityHidden(true)
                            Text("\(AppSpacing.localizedTokenName(key)): \(value, specifier: "%.1f")pt")
                                .font(.callout)
                                .foregroundColor(.primary)
                                .accessibilityLabel("\(AppSpacing.localizedTokenName(key))")
                                .accessibilityValue("\(value, specifier: "%.1f") points")
                        }
                        .frame(height: 24)
                    }
                }
                .padding(.bottom, 12)
            }
            .frame(maxHeight: 300)
            .background(Color(.systemGroupedBackground))
            .cornerRadius(8)
            .accessibilityElement(children: .contain)

            // Diagnostics Buffer Display
            Group {
                Text(NSLocalizedString("spacing_preview_diagnostics_title", value: "Recent Analytics Events", comment: "Diagnostics buffer title"))
                    .font(.headline)
                    .padding(.top, 8)
                    .accessibilityAddTraits(.isHeader)

                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        if recentEvents.isEmpty {
                            Text(NSLocalizedString("spacing_preview_diagnostics_empty", value: "No events logged yet.", comment: "No diagnostics events message"))
                                .italic()
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(recentEvents.reversed()) { event in
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("\(event.timestamp, formatter: dateFormatter)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text("event: \(event.event), token: \(AppSpacing.localizedTokenName(event.token)), value: \(event.value, specifier: "%.2f")")
                                        .font(.caption2)
                                    Text("role: \(event.role ?? "nil"), staffID: \(event.staffID ?? "nil"), context: \(event.context ?? "nil"), escalate: \(event.escalate ? "true" : "false")")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 2)
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("\(event.event) event for \(AppSpacing.localizedTokenName(event.token)) with value \(event.value, specifier: "%.2f") at \(dateFormatter.string(from: event.timestamp)), role \(event.role ?? "none"), staff ID \(event.staffID ?? "none"), context \(event.context ?? "none"), escalate \(event.escalate ? "true" : "false")")
                            }
                        }
                    }
                    .padding(4)
                }
                .frame(maxHeight: 150)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
            }

            // Toggle to demonstrate testMode
            Toggle(isOn: Binding(
                get: { logger.testMode },
                set: { newValue in
                    logger = SpyLogger(testMode: newValue)
                    AppSpacing.analyticsLogger = logger
                    // Clear buffer on toggle
                    recentEvents = []
                }
            )) {
                Text(NSLocalizedString("spacing_preview_testmode_toggle", value: "Enable Test Mode Logging", comment: "Toggle label for test mode"))
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding()
        .onAppear {
            AppSpacing.analyticsLogger = logger

            // Trigger some spacing accesses to populate buffer
            _ = AppSpacing.none
            _ = AppSpacing.small
            _ = AppSpacing.custom(25, label: NSLocalizedString("spacing_custom_label", value: "custom", comment: "Custom spacing label"))

            // Fetch recent events asynchronously after small delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                recentEvents = AppSpacing.recentAnalyticsEvents()
            }
        }
    }

    /// Shared date formatter for event timestamps.
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }
}

#Preview {
    AppSpacingPreview()
}
#endif

/// Usage example:
/// .padding(AppSpacing.medium)
/// .appPadding(AppSpacing.large)

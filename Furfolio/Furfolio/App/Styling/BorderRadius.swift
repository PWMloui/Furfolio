//
//  BorderRadius.swift
//  Furfolio
//
//  Architecture & Extensibility:
//  -----------------------------
//  BorderRadius.swift centralizes all corner radius values as theme-aware tokens for consistent UI design across Furfolio.
//  It supports extensibility by allowing integration with brand themes and future dynamic token resolution.
//  The architecture cleanly separates analytics/audit hooks and UI preview/testability concerns.
//
//  Analytics/Audit/Trust Center Hooks:
//  -----------------------------------
//  BorderRadiusAnalyticsLogger protocol provides async logging of radius access events with token names and values.
//  It includes a 'testMode' property to enable console-only logging during QA, tests, and previews.
//  An internal capped buffer stores the last 20 events for diagnostics and admin inspection via a public API.
//
//  Diagnostics & Accessibility:
//  ----------------------------
//  The public API exposes recent analytics events for diagnostics and auditing.
//  The preview demonstrates accessibility by showing radius tokens with localized labels.
//  Accessibility considerations include localized strings and consistent token usage.
//
//  Localization:
//  -------------
//  All user-facing strings (token names, preview labels, analytics event keys) are localized using NSLocalizedString
//  with explicit keys and descriptive comments to ease internationalization.
//
//  Compliance & Preview/Testability:
//  ---------------------------------
//  The design supports compliance requirements by logging and auditing radius usage.
//  PreviewProvider demonstrates usage with real-time logging, testMode toggling, and diagnostics buffer display.
//  NullBorderRadiusAnalyticsLogger is provided for silent logging in non-analytic contexts like previews/tests.
//
//  This file aims to provide a robust, scalable, and maintainable border radius system that integrates
//  seamlessly with Furfolio’s design system, analytics infrastructure, and localization strategy.
//

import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct BorderRadiusAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "BorderRadius"
}

// MARK: - Analytics/Audit Protocol and Event Model

/// Protocol defining async analytics logging for border radius usage events with audit context.
/// Includes a `testMode` property to enable console-only logging during QA/tests/previews.
public protocol BorderRadiusAnalyticsLogger {
    /// Indicates whether the logger is in test mode (console-only logging).
    var testMode: Bool { get }

    /// Asynchronously logs an analytics event with the given parameters and audit context.
    /// - Parameters:
    ///   - event: The event name key (localized).
    ///   - value: The CGFloat value associated with the event.
    ///   - token: The token name key (localized).
    ///   - role: The user role (audit context).
    ///   - staffID: The staff identifier (audit context).
    ///   - context: The contextual string (audit context).
    ///   - escalate: Flag indicating if the event should be escalated for compliance.
    func log(
        event: String,
        value: CGFloat,
        token: String,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async

    /// Returns recent analytics events for diagnostics and auditing.
    func recentEvents() -> [BorderRadiusAnalyticsEvent]
}

/// Analytics event model capturing audit context and event details.
public struct BorderRadiusAnalyticsEvent: Identifiable {
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

/// Null logger implementation for use in previews and tests to suppress analytics side effects.
/// Prints audit fields if testMode is enabled, but stores no events.
public struct NullBorderRadiusAnalyticsLogger: BorderRadiusAnalyticsLogger {
    public let testMode: Bool = true
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
            print("[BorderRadiusAnalytics TEST MODE] event:\(event) value:\(value) token:\(token) role:\(role ?? "nil") staffID:\(staffID ?? "nil") context:\(context ?? "nil") escalate:\(escalate)")
        }
    }

    public func recentEvents() -> [BorderRadiusAnalyticsEvent] {
        []
    }
}

// MARK: - BorderRadius (Centralized Corner Radius Tokens)

/// Centralized, theme-aware border radius values for consistent, accessible design throughout Furfolio.
/// Fully brand/white-label ready, analytics/audit–compliant, and drop-in for all UI.
/// Supports async analytics logging with a capped event buffer for diagnostics.
/// Localizes all user-facing strings for internationalization.
///
enum BorderRadius {
    // MARK: - Analytics Logger and Diagnostics Buffer

    /// Analytics logger for BI/QA/Trust Center.
    /// Defaults to NullBorderRadiusAnalyticsLogger.
    static var analyticsLogger: BorderRadiusAnalyticsLogger = NullBorderRadiusAnalyticsLogger()

    /// Internal capped buffer storing last 20 analytics events with audit context for diagnostics.
    private static var analyticsEventBuffer: [BorderRadiusAnalyticsEvent] = []

    /// Maximum number of stored analytics events.
    private static let maxBufferCount = 20

    /// Appends an analytics event to the internal buffer, maintaining the capped size.
    /// - Parameter event: The analytics event with audit context.
    private static func appendToBuffer(event: BorderRadiusAnalyticsEvent) {
        analyticsEventBuffer.append(event)
        if analyticsEventBuffer.count > maxBufferCount {
            analyticsEventBuffer.removeFirst(analyticsEventBuffer.count - maxBufferCount)
        }
    }

    /// Public API: Fetches recent analytics events for diagnostics and admin review.
    /// - Returns: Array of BorderRadiusAnalyticsEvent containing event details and audit context.
    static func recentAnalyticsEvents() -> [BorderRadiusAnalyticsEvent] {
        analyticsEventBuffer
    }

    // MARK: - Tokens (with robust fallback and localization)

    /// Small radius token localized key.
    static let smallTokenKey = "BorderRadius.small"
    /// Medium radius token localized key.
    static let mediumTokenKey = "BorderRadius.medium"
    /// Large radius token localized key.
    static let largeTokenKey = "BorderRadius.large"
    /// Capsule radius token localized key.
    static let capsuleTokenKey = "BorderRadius.capsule"
    /// Button radius token localized key.
    static let buttonTokenKey = "BorderRadius.button"
    /// Full radius token localized key (circle).
    static let fullTokenKey = "BorderRadius.full"

    /// Small radius value.
    static let small: CGFloat     = fetch(smallTokenKey, 6)
    /// Medium radius value.
    static let medium: CGFloat    = fetch(mediumTokenKey, 12)
    /// Large radius value.
    static let large: CGFloat     = fetch(largeTokenKey, 20)
    /// Capsule radius value.
    static let capsule: CGFloat   = fetch(capsuleTokenKey, 30)
    /// Button radius value.
    static let button: CGFloat    = fetch(buttonTokenKey, 13)
    /// Full radius value for circles (avatars/buttons).
    static let full: CGFloat      = fetch(fullTokenKey, 999)

    /// All predefined border radius values for UI preview/audit.
    static let all: [CGFloat] = [small, medium, large, capsule, button, full]

    /// Fetches a radius from the current theme/brand (future: theme support),
    /// logs the access asynchronously with audit context and escalation for compliance,
    /// and returns a robust fallback.
    /// - Parameters:
    ///   - token: The localized token key.
    ///   - fallback: The default radius value to use if no theme override exists.
    /// - Returns: The resolved radius value.
    private static func fetch(_ token: String, _ fallback: CGFloat) -> CGFloat {
        let eventKey = NSLocalizedString("BorderRadius.radius_access_event", value: "radius_access", comment: "Radius access event key")
        let tokenName = NSLocalizedString(token, value: token.components(separatedBy: ".").last ?? token, comment: "Border radius token name")
        let lowercasedToken = token.lowercased()
        let escalate = lowercasedToken.contains("danger") || lowercasedToken.contains("delete") || lowercasedToken.contains("critical")

        Task {
            await analyticsLogger.log(
                event: eventKey,
                value: fallback,
                token: tokenName,
                role: BorderRadiusAuditContext.role,
                staffID: BorderRadiusAuditContext.staffID,
                context: BorderRadiusAuditContext.context,
                escalate: escalate
            )
            let analyticsEvent = BorderRadiusAnalyticsEvent(
                timestamp: Date(),
                event: eventKey,
                value: fallback,
                token: tokenName,
                role: BorderRadiusAuditContext.role,
                staffID: BorderRadiusAuditContext.staffID,
                context: BorderRadiusAuditContext.context,
                escalate: escalate
            )
            appendToBuffer(event: analyticsEvent)
        }
        // Future: Theme/brand lookup. For now, use fallback.
        return fallback
    }

    /// Returns a rounded CGFloat value (for pixel-perfect rendering).
    /// - Parameter value: The input CGFloat.
    /// - Returns: The rounded CGFloat.
    static func rounded(_ value: CGFloat) -> CGFloat {
        CGFloat(round(value))
    }
}

/// Usage example:
/// ```swift
/// struct ExampleView: View {
///     var body: some View {
///         Text("Hello, Furfolio!")
///             .padding()
///             .background(Color.blue)
///             .cornerRadius(BorderRadius.medium)
///     }
/// }
/// ```

// MARK: - Preview (Design/QA Review)

#if DEBUG
struct BorderRadiusPreview: View {
    @State private var demoText: String = NSLocalizedString("BorderRadius.demo_text", value: "Furfolio Radius", comment: "Demo text for BorderRadius preview")
    @State private var showDiagnostics: Bool = false
    @State private var testModeEnabled: Bool = false

    /// Spy logger implementation that prints to console and respects testMode.
    struct SpyLogger: BorderRadiusAnalyticsLogger {
        let testMode: Bool
        private var storedEvents: [BorderRadiusAnalyticsEvent] = []

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
                print("[BorderRadiusAnalytics TEST MODE] event:\(event) value:\(value) token:\(token) role:\(role ?? "nil") staffID:\(staffID ?? "nil") context:\(context ?? "nil") escalate:\(escalate)")
            } else {
                // Simulate async logging delay
                try? await Task.sleep(nanoseconds: 50_000_000)
                print("[BorderRadiusAnalytics] event:\(event) value:\(value) token:\(token) role:\(role ?? "nil") staffID:\(staffID ?? "nil") context:\(context ?? "nil") escalate:\(escalate)")
            }
        }

        func recentEvents() -> [BorderRadiusAnalyticsEvent] {
            []
        }
    }

    /// Localized labels for preview tokens.
    private let previewLabels: [(key: String, radius: CGFloat)] = [
        (NSLocalizedString("BorderRadius.preview.small", value: "Small", comment: "Small radius label"), BorderRadius.small),
        (NSLocalizedString("BorderRadius.preview.medium", value: "Medium", comment: "Medium radius label"), BorderRadius.medium),
        (NSLocalizedString("BorderRadius.preview.large", value: "Large", comment: "Large radius label"), BorderRadius.large),
        (NSLocalizedString("BorderRadius.preview.capsule", value: "Capsule", comment: "Capsule radius label"), BorderRadius.capsule),
        (NSLocalizedString("BorderRadius.preview.button", value: "Button", comment: "Button radius label"), BorderRadius.button),
        (NSLocalizedString("BorderRadius.preview.full", value: "Full (Circle)", comment: "Full radius label"))
            , BorderRadius.full)
    ]

    var body: some View {
        VStack(spacing: 24) {
            Toggle(isOn: $testModeEnabled) {
                Text(NSLocalizedString("BorderRadius.preview.toggle_test_mode", value: "Enable Test Mode Logging", comment: "Toggle for test mode logging"))
            }
            .padding(.horizontal)

            ScrollView {
                VStack(spacing: 16) {
                    ForEach(previewLabels, id: \.key) { label, radius in
                        Text("\(label) - \(Int(radius))")
                            .padding()
                            .frame(width: 200, height: 50)
                            .background(Color.blue.opacity(0.23))
                            .cornerRadius(radius)
                            .accessibilityLabel(Text(String(format: NSLocalizedString("BorderRadius.accessibility.radius_label", value: "%@ radius: %d points", comment: "Accessibility label for radius tokens"), label, Int(radius))))
                    }
                }
            }
            Button {
                showDiagnostics.toggle()
            } label: {
                Text(showDiagnostics
                     ? NSLocalizedString("BorderRadius.preview.hide_diagnostics", value: "Hide Diagnostics", comment: "Button label to hide diagnostics")
                     : NSLocalizedString("BorderRadius.preview.show_diagnostics", value: "Show Diagnostics", comment: "Button label to show diagnostics"))
            }
            .padding()

            if showDiagnostics {
                DiagnosticsView()
                    .frame(maxHeight: 200)
                    .padding(.horizontal)
            }
        }
        .padding()
        .onAppear {
            BorderRadius.analyticsLogger = SpyLogger(testMode: testModeEnabled)
        }
        .onChange(of: testModeEnabled) { newValue in
            BorderRadius.analyticsLogger = SpyLogger(testMode: newValue)
        }
    }

    /// Diagnostics view showing recent analytics events with audit context.
    @ViewBuilder
    private func DiagnosticsView() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("BorderRadius.diagnostics.title", value: "Recent Analytics Events", comment: "Title for diagnostics section"))
                .font(.headline)
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(BorderRadius.recentAnalyticsEvents().enumerated()), id: \.offset) { index, event in
                        Text("""
                            \(index + 1). \(event.timestamp.formatted(date: .numeric, time: .standard)) - \
                            event: \(event.event) - value: \(String(format: "%.1f", event.value)) - token: \(event.token) - \
                            role: \(event.role ?? "nil") - staffID: \(event.staffID ?? "nil") - context: \(event.context ?? "nil") - \
                            escalate: \(event.escalate)
                            """)
                            .font(.caption)
                            .accessibilityLabel(Text(String(format: NSLocalizedString("BorderRadius.diagnostics.accessibility_event", value: "Event %d at %@: %@ token with value %.1f, role %@, staff ID %@, context %@, escalate flag %@", comment: "Accessibility label for diagnostics event"), index + 1, event.timestamp.formatted(date: .numeric, time: .standard), event.token, event.value, event.role ?? "nil", event.staffID ?? "nil", event.context ?? "nil", String(event.escalate))))
                    }
                }
            }
            .background(Color.gray.opacity(0.1))
            .cornerRadius(BorderRadius.small)
        }
    }
}
#Preview {
    BorderRadiusPreview()
}
#endif

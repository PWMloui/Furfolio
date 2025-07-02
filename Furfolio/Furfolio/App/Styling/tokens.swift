//
//  tokens.swift
//  Furfolio
//
//  Furfolio Token System
//
//  Architecture & Extensibility:
//  This file serves as the single source of truth for all design tokens (colors, fonts, spacing, radii, animations, etc.).
//  The Tokens struct is modular and extensible, allowing easy addition of new token categories and values.
//
//  Analytics/Audit/Trust Center Hooks:
//  The TokensAnalyticsLogger protocol enables asynchronous logging of token usage for BI, QA, Trust Center, and design system diagnostics.
//  It supports a `testMode` property to enable console-only logging during testing, previews, or QA sessions.
//  A capped buffer stores the last 20 analytics events, accessible via a public API for diagnostics and admin review.
//
//  Diagnostics & Buffering:
//  The internal buffer maintains recent token usage events with timestamps, token names, and values.
//  This facilitates audit trails, debugging, and compliance monitoring.
//
//  Localization:
//  All user-facing strings, including token names and preview labels, are localized using NSLocalizedString with appropriate keys and comments.
//
//  Accessibility:
//  Preview examples demonstrate accessibility features and how tokens integrate with accessibility settings.
//
//  Compliance:
//  The token system supports enterprise-grade compliance by enabling thorough analytics, audit trails, and modular design.
//
//  Preview & Testability:
//  The provided PreviewProvider showcases token usage, analytics logging in test mode, accessibility adaptations, and diagnostics buffer inspection.
//
//  Future maintainers should extend tokens by adding new enums or properties within the Tokens struct,
//  implement custom TokensAnalyticsLogger conformances for production analytics,
//  and utilize the diagnostics APIs for monitoring token usage and system health.
//

import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct TokensAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "Tokens"
}

// MARK: - Analytics/Audit Protocols

/// Audit/Trust Center: Analytics event structure for compliance and diagnostics.
public struct TokensAnalyticsEvent: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let token: String
    public let value: Any
    public let role: String?
    public let staffID: String?
    public let context: String?
    public let escalate: Bool
}

/// Audit/Trust Center: Protocol defining asynchronous analytics logging for token usage, including audit fields.
public protocol TokensAnalyticsLogger {
    /// Indicates whether the logger is operating in test mode (console-only logging).
    var testMode: Bool { get set }
    /// Asynchronously logs a token usage event with all audit fields.
    func log(
        token: String,
        value: Any,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async
    /// Returns a snapshot of recent events (for in-memory loggers).
    func recentEvents() -> [TokensAnalyticsEvent]
}

/// A no-operation logger used for previews and tests that prints in testMode and stores nothing.
public struct NullTokensAnalyticsLogger: TokensAnalyticsLogger {
    public var testMode: Bool = false
    public init(testMode: Bool = false) { self.testMode = testMode }
    public func log(
        token: String,
        value: Any,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async {
        if testMode {
            print("[Tokens NullLogger] token: \(token), value: \(value), role: \(role ?? "nil"), staffID: \(staffID ?? "nil"), context: \(context ?? "nil"), escalate: \(escalate)")
        }
    }
    public func recentEvents() -> [TokensAnalyticsEvent] { [] }
}

// MARK: - Central Tokens Struct

enum Tokens {
    // Analytics logger for BI/QA/Trust Center/design system with audit fields.
    /// The global analytics logger instance. Defaults to NullTokensAnalyticsLogger.
    static var analyticsLogger: TokensAnalyticsLogger = NullTokensAnalyticsLogger()
    
    /// Internal diagnostics buffer for recent analytics events (max 20), including audit fields.
    private static var diagnosticsBuffer: [TokensAnalyticsEvent] = []
    private static let diagnosticsBufferMaxCount = 20
    private static let diagnosticsBufferQueue = DispatchQueue(label: "com.furfolio.tokens.diagnosticsBufferQueue")
    
    // MARK: - Color Tokens
    enum Colors {
        /// Primary brand color.
        static let primary: Color = Color(NSLocalizedString("PrimaryColor", value: "Primary brand color", comment: "Primary brand color token"))
        /// Secondary brand color.
        static let secondary: Color = Color(NSLocalizedString("SecondaryColor", value: "Secondary brand color", comment: "Secondary brand color token"))
        /// Background color for main views.
        static let background: Color = Color(NSLocalizedString("BackgroundColor", value: "Background color", comment: "Background color token"))
        /// Card background color.
        static let card: Color = Color(.secondarySystemGroupedBackground)
        /// Success state color.
        static let success: Color = .green
        /// Warning state color.
        static let warning: Color = .orange
        /// Danger or error state color.
        static let danger: Color = .red
        /// Informational color.
        static let info: Color = .blue
        /// Overlay color with opacity.
        static let overlay: Color = Color.black.opacity(0.36)
        /// Base color for shimmer effects.
        static let shimmerBase: Color = Color.gray.opacity(0.23)
        /// Highlight color for shimmer effects.
        static let shimmerHighlight: Color = Color.gray.opacity(0.42)
        /// Primary text color.
        static let textPrimary: Color = .primary
        /// Secondary text color.
        static let textSecondary: Color = .secondary
        /// Placeholder text color.
        static let textPlaceholder: Color = Color.gray.opacity(0.54)
        /// Separator line color.
        static let separator: Color = Color(.separator)
        /// Tag color for new items.
        static let tagNew: Color = .blue
        /// Tag color for active items.
        static let tagActive: Color = .green
        /// Tag color for returning users.
        static let tagReturning: Color = .purple
        /// Tag color indicating risk.
        static let tagRisk: Color = .orange
        /// Tag color for inactive items.
        static let tagInactive: Color = .gray
        /// Button background color.
        static let button: Color = Color(NSLocalizedString("PrimaryColor", value: "Primary brand color", comment: "Primary brand color token"))
        /// Disabled button background color.
        static let buttonDisabled: Color = Color.gray.opacity(0.33)
        /// Button text color.
        static let buttonText: Color = .white
    }

    // MARK: - Font Tokens
    enum Fonts {
        /// Large title font.
        static let largeTitle: Font = .system(size: 34, weight: .bold, design: .rounded)
        /// Title font.
        static let title: Font = .system(size: 28, weight: .semibold, design: .rounded)
        /// Headline font.
        static let headline: Font = .system(size: 20, weight: .semibold, design: .rounded)
        /// Subheadline font.
        static let subheadline: Font = .system(size: 17, weight: .medium, design: .rounded)
        /// Body font.
        static let body: Font = .system(size: 17, weight: .regular, design: .rounded)
        /// Callout font.
        static let callout: Font = .system(size: 16, weight: .regular, design: .rounded)
        /// Caption font.
        static let caption: Font = .system(size: 13, weight: .regular, design: .rounded)
        /// Secondary caption font.
        static let caption2: Font = .system(size: 11, weight: .regular, design: .rounded)
        /// Footnote font.
        static let footnote: Font = .system(size: 12, weight: .medium, design: .rounded)
        /// Button font.
        static let button: Font = .system(size: 18, weight: .semibold, design: .rounded)
        /// Tab bar font.
        static let tabBar: Font = .system(size: 14, weight: .medium, design: .rounded)
        /// Badge font.
        static let badge: Font = .system(size: 12, weight: .bold, design: .rounded)
    }

    // MARK: - Spacing Tokens
    enum Spacing {
        /// No spacing.
        static let none: CGFloat = 0
        /// Extra extra small spacing.
        static let xxs: CGFloat = 2
        /// Extra small spacing.
        static let xs: CGFloat = 4
        /// Small spacing.
        static let small: CGFloat = 8
        /// Medium spacing.
        static let medium: CGFloat = 16
        /// Large spacing.
        static let large: CGFloat = 24
        /// Extra large spacing.
        static let xl: CGFloat = 32
        /// Extra extra large spacing.
        static let xxl: CGFloat = 40
        /// Section spacing.
        static let section: CGFloat = 48
        /// List item spacing.
        static let listItem: CGFloat = 12
        /// Card padding spacing.
        static let card: CGFloat = 20
        /// Avatar size spacing.
        static let avatar: CGFloat = 42
        /// Pulse button scale factor.
        static let pulseButtonScale: CGFloat = 1.09
        /// Progress ring size.
        static let progressRingSize: CGFloat = 86
        /// Progress ring stroke width.
        static let progressRingStroke: CGFloat = 14
        /// Primary skeleton width.
        static let skeletonPrimary: CGFloat = 140
        /// Minimum secondary skeleton width.
        static let skeletonSecondaryMin: CGFloat = 90
        /// Variable secondary skeleton width.
        static let skeletonSecondaryVar: CGFloat = 30
        /// Primary skeleton height.
        static let skeletonPrimaryHeight: CGFloat = 15
        /// Secondary skeleton height.
        static let skeletonSecondaryHeight: CGFloat = 11
        /// Icon offset spacing.
        static let iconOffset: CGFloat = 22
        /// Extra small spacing alias.
        static let xsmall: CGFloat = 2
    }

    // MARK: - Corner Radius Tokens
    enum Radius {
        /// Small corner radius.
        static let small: CGFloat = 6
        /// Medium corner radius.
        static let medium: CGFloat = 12
        /// Large corner radius.
        static let large: CGFloat = 20
        /// Capsule corner radius.
        static let capsule: CGFloat = 30
        /// Button corner radius.
        static let button: CGFloat = 13
        /// Full corner radius (circle).
        static let full: CGFloat = 999
    }

    // MARK: - Shadow Tokens
    /// Represents a shadow style with color, radius, and offset.
    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
    enum Shadows {
        /// Card shadow style.
        static let card = Shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 3)
        /// Modal shadow style.
        static let modal = Shadow(color: .black.opacity(0.14), radius: 16, x: 0, y: 8)
        /// Thin shadow style.
        static let thin = Shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
        /// Inner shadow style.
        static let inner = Shadow(color: .black.opacity(0.10), radius: 6, x: 0, y: 2)
        /// Avatar shadow style.
        static let avatar = Shadow(color: .black.opacity(0.10), radius: 4, x: 0, y: 1)
        /// Button shadow style.
        static let button = Shadow(color: .black.opacity(0.09), radius: 5, x: 0, y: 2)
    }

    // MARK: - Animation/Duration Tokens
    enum Animation {
        /// Ultra fast animation duration.
        static let ultraFast: Double = 0.10
        /// Fast animation duration.
        static let fast: Double = 0.18
        /// Standard animation duration.
        static let standard: Double = 0.35
        /// Slow animation duration.
        static let slow: Double = 0.60
        /// Extra slow animation duration.
        static let extraSlow: Double = 0.98
        /// Pulse animation duration.
        static let pulse: Double = 0.21
        /// Spinner animation duration.
        static let spinnerDuration: Double = 0.8
        // Add more animation/duration tokens as needed.
    }

    // MARK: - Line Width Tokens
    enum LineWidth {
        /// Hairline width.
        static let hairline: CGFloat = 0.5
        /// Thin line width.
        static let thin: CGFloat = 1
        /// Standard line width.
        static let standard: CGFloat = 2
        /// Thick line width.
        static let thick: CGFloat = 4
    }
    
    // MARK: - Token Access Logging & Diagnostics (Audit/Compliance)
    
    /// Asynchronously logs a token usage event and updates diagnostics buffer (with audit/trust context).
    /// - Parameters:
    ///   - token: The token name.
    ///   - value: The token value.
    static func logToken(_ token: String, _ value: Any) async {
        // Audit/Trust Center: escalate if token or value contains "danger"/"critical"
        let tokenLower = token.lowercased()
        let valueString = "\(value)".lowercased()
        let escalate = tokenLower.contains("danger") || tokenLower.contains("critical") || valueString.contains("danger") || valueString.contains("critical")
        let role = TokensAuditContext.role
        let staffID = TokensAuditContext.staffID
        let context = TokensAuditContext.context
        await analyticsLogger.log(
            token: token,
            value: value,
            role: role,
            staffID: staffID,
            context: context,
            escalate: escalate
        )
        let event = TokensAnalyticsEvent(
            timestamp: Date(),
            token: token,
            value: value,
            role: role,
            staffID: staffID,
            context: context,
            escalate: escalate
        )
        diagnosticsBufferQueue.sync {
            diagnosticsBuffer.append(event)
            if diagnosticsBuffer.count > diagnosticsBufferMaxCount {
                diagnosticsBuffer.removeFirst(diagnosticsBuffer.count - diagnosticsBufferMaxCount)
            }
        }
    }
    
    /// Returns a snapshot of recent analytics events for diagnostics or admin review, including audit fields.
    /// - Returns: An array of TokensAnalyticsEvent.
    static func recentAnalyticsEvents() -> [TokensAnalyticsEvent] {
        diagnosticsBufferQueue.sync {
            return diagnosticsBuffer
        }
    }
}

// MARK: - Usage Example & Preview

struct TokensPreviewView: View {
    @State private var loggedEvents: [TokensAnalyticsEvent] = []
    @State private var isTestMode: Bool = true
    
    var body: some View {
        VStack(spacing: Tokens.Spacing.medium) {
            Text(NSLocalizedString("FurfolioTokensPreviewTitle", value: "Furfolio Tokens Preview", comment: "Preview screen title"))
                .font(Tokens.Fonts.largeTitle)
                .foregroundColor(Tokens.Colors.primary)
            
            Text(NSLocalizedString("TestModeStatus", value: "Test Mode Enabled", comment: "Indicates test mode status"))
                .font(Tokens.Fonts.body)
                .foregroundColor(isTestMode ? Tokens.Colors.success : Tokens.Colors.danger)
                .accessibilityLabel(isTestMode ? NSLocalizedString("AccessibilityTestModeOn", value: "Test mode is on", comment: "Accessibility label") : NSLocalizedString("AccessibilityTestModeOff", value: "Test mode is off", comment: "Accessibility label"))
            
            Button(action: {
                Task {
                    await Tokens.logToken(NSLocalizedString("PreviewButtonToken", value: "PreviewButton", comment: "Button token name"), "Tapped")
                    loggedEvents = Tokens.recentAnalyticsEvents()
                }
            }) {
                Text(NSLocalizedString("LogTokenButtonLabel", value: "Log Token Event", comment: "Button label for logging token event"))
                    .font(Tokens.Fonts.button)
                    .foregroundColor(Tokens.Colors.buttonText)
                    .padding()
                    .background(Tokens.Colors.button)
                    .cornerRadius(Tokens.Radius.button)
                    .shadow(color: Tokens.Shadows.button.color, radius: Tokens.Shadows.button.radius, x: Tokens.Shadows.button.x, y: Tokens.Shadows.button.y)
            }
            .accessibilityHint(NSLocalizedString("LogTokenButtonHint", value: "Logs a token event for diagnostics", comment: "Accessibility hint for log token button"))
            
            List {
                Section(header: Text(NSLocalizedString("RecentEventsSectionHeader", value: "Recent Analytics Events", comment: "Section header for recent analytics events"))) {
                    ForEach(loggedEvents) { event in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text("Token:").bold() + Text(" \(event.token)")
                            }
                            HStack {
                                Text("Value:").bold() + Text(" \(String(describing: event.value))")
                            }
                            if let role = event.role {
                                HStack {
                                    Text("Role:").bold() + Text(" \(role)")
                                }
                            }
                            if let staffID = event.staffID {
                                HStack {
                                    Text("StaffID:").bold() + Text(" \(staffID)")
                                }
                            }
                            if let context = event.context {
                                HStack {
                                    Text("Context:").bold() + Text(" \(context)")
                                }
                            }
                            HStack {
                                Text("Escalate:").bold() + Text(" \(event.escalate ? "Yes" : "No")")
                            }
                            HStack {
                                Text("Timestamp:").bold() + Text(" \(event.timestamp.formatted(date: .omitted, time: .standard))")
                            }
                        }
                        .font(Tokens.Fonts.caption)
                        .foregroundColor(Tokens.Colors.textPrimary)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(
                            "\(event.token), \(event.value), role \(event.role ?? "none"), staffID \(event.staffID ?? "none"), context \(event.context ?? "none"), escalate \(event.escalate ? "yes" : "no"), \(event.timestamp.formatted(date: .omitted, time: .standard))"
                        )
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .frame(maxHeight: 300)
        }
        .padding(Tokens.Spacing.large)
        .background(Tokens.Colors.background)
        .cornerRadius(Tokens.Radius.medium)
        .shadow(color: Tokens.Shadows.card.color, radius: Tokens.Shadows.card.radius, x: Tokens.Shadows.card.x, y: Tokens.Shadows.card.y)
        .onAppear {
            // Set testMode if supported.
            if var logger = Tokens.analyticsLogger as? NullTokensAnalyticsLogger {
                logger.testMode = isTestMode
                Tokens.analyticsLogger = logger
            }
            loggedEvents = Tokens.recentAnalyticsEvents()
        }
    }
}

struct Tokens_Previews: PreviewProvider {
    static var previews: some View {
        // Use NullTokensAnalyticsLogger with testMode enabled for preview (audit/trust center).
        Tokens.analyticsLogger = NullTokensAnalyticsLogger(testMode: true)
        return TokensPreviewView()
    }
}

//
//  AppTheme.swift
//  Furfolio
//
//  ENHANCED: Enterprise-level single source of truth for all design tokens.
//  Modular, audit/diagnostics/localization/preview/test ready, brand/white-label, robust.
//  Last updated: 2025-06-27
//
/**
 # AppTheme Architecture & Compliance

 - **Centralized Token Management:** All design tokens (colors, fonts, spacing, radius, shadows, animation, etc.) are accessed through `AppTheme`, enabling instant theme swapping and robust admin/diagnostics review.
 - **Extensibility:** Add/override tokens, brands, or categories by expanding enums. Previews and test loggers are modular.
 - **Analytics/Audit/Trust Center:** All token reads are logged via async/await analytics logger (with testMode, event buffer, admin diagnostics API, Trust Center–ready).
 - **Diagnostics:** Recent token events are buffered (last 20) and available via a public API for admin/QA troubleshooting.
 - **Localization/Compliance:** All token names are localized via `NSLocalizedString`, ready for international admin UIs and regulatory review.
 - **Preview/Testability:** Built-in Null logger, PreviewProvider supports testMode, diagnostics buffer, and full a11y/localization coverage.
 */

import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct AppThemeAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "AppTheme"
}

// MARK: - Analytics/Audit Protocol

/// Async/await analytics logger for token usage, with testMode and diagnostics buffer, including audit context and escalation flag.
public protocol AppThemeAnalyticsLogger {
    var testMode: Bool { get set }
    func log(
        token: String,
        value: Any,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async
    func recentEvents() -> [AppThemeAnalyticsEvent]
}

public struct AppThemeAnalyticsEvent: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let token: String
    public let valueDescription: String
    public let role: String?
    public let staffID: String?
    public let context: String?
    public let escalate: Bool
}

public struct NullAppThemeAnalyticsLogger: AppThemeAnalyticsLogger {
    public init() {}
    public var testMode: Bool = false
    public func log(
        token: String,
        value: Any,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async {
        if testMode {
            print("[AppTheme][TESTMODE] Token: \(token), Value: \(value), Role: \(role ?? "nil"), StaffID: \(staffID ?? "nil"), Context: \(context ?? "nil"), Escalate: \(escalate)")
        }
    }
    public func recentEvents() -> [AppThemeAnalyticsEvent] { [] }
}

public final class DefaultAppThemeAnalyticsLogger: AppThemeAnalyticsLogger {
    public var testMode: Bool = false
    private var buffer: [AppThemeAnalyticsEvent] = []
    private let lock = NSLock()
    public init() {}
    public func log(
        token: String,
        value: Any,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async {
        let valueDesc = String(describing: value)
        let msg = String(
            format: NSLocalizedString("apptheme_event_format", value: "Token: %@ — %@", comment: "AppTheme event log format"),
            NSLocalizedString("apptheme_\(token)", value: token, comment: "Token name for admin/diagnostics"),
            valueDesc
        )
        let event = AppThemeAnalyticsEvent(
            timestamp: Date(),
            token: token,
            valueDescription: valueDesc,
            role: role,
            staffID: staffID,
            context: context,
            escalate: escalate
        )
        lock.lock()
        if buffer.count >= 20 { buffer.removeFirst() }
        buffer.append(event)
        lock.unlock()
        if testMode {
            print("[AppTheme][TESTMODE] \(msg), Role: \(role ?? "nil"), StaffID: \(staffID ?? "nil"), Context: \(context ?? "nil"), Escalate: \(escalate)")
        }
    }
    public func recentEvents() -> [AppThemeAnalyticsEvent] {
        lock.lock()
        let copy = buffer
        lock.unlock()
        return copy
    }
}

// MARK: - AppTheme: Single Source of Truth for Design Tokens

public enum AppTheme {
    // MARK: - Analytics DI (for BI/QA/Trust Center)
    public static var analyticsLogger: AppThemeAnalyticsLogger = DefaultAppThemeAnalyticsLogger()

    // MARK: - Colors
    public enum Colors {
        public static var primary: Color         { log("primary", AppColors.primary);         return AppColors.primary }
        public static var secondary: Color       { log("secondary", AppColors.secondary);     return AppColors.secondary }
        public static var background: Color      { log("background", AppColors.background);   return AppColors.background }
        public static var card: Color            { log("card", AppColors.card);               return AppColors.card }
        public static var success: Color         { log("success", AppColors.success);         return AppColors.success }
        public static var warning: Color         { log("warning", AppColors.warning);         return AppColors.warning }
        public static var danger: Color          { log("danger", AppColors.danger);           return AppColors.danger }
        public static var info: Color            { log("info", AppColors.info);               return AppColors.info }
        public static var textPrimary: Color     { log("textPrimary", AppColors.textPrimary); return AppColors.textPrimary }
        public static var textSecondary: Color   { log("textSecondary", AppColors.textSecondary); return AppColors.textSecondary }
        public static var overlay: Color         { log("overlay", AppColors.overlay);         return AppColors.overlay }
        public static var shimmerBase: Color     { log("shimmerBase", AppColors.shimmerBase); return AppColors.shimmerBase }
        public static var shimmerHighlight: Color{ log("shimmerHighlight", AppColors.shimmerHighlight); return AppColors.shimmerHighlight }
        public static var tagNew: Color          { log("tagNew", AppColors.tagNew);           return AppColors.tagNew }
        public static var tagActive: Color       { log("tagActive", AppColors.tagActive);     return AppColors.tagActive }
        public static var tagReturning: Color    { log("tagReturning", AppColors.tagReturning); return AppColors.tagReturning }
        public static var tagRisk: Color         { log("tagRisk", AppColors.tagRisk);         return AppColors.tagRisk }
        public static var tagInactive: Color     { log("tagInactive", AppColors.tagInactive); return AppColors.tagInactive }
        public static var button: Color          { log("button", AppColors.button);           return AppColors.button }
        public static var buttonDisabled: Color  { log("buttonDisabled", AppColors.buttonDisabled); return AppColors.buttonDisabled }
        public static var buttonText: Color      { log("buttonText", AppColors.buttonText);   return AppColors.buttonText }
    }

    // MARK: - Fonts
    public enum Fonts {
        public static var largeTitle: Font   { log("largeTitle", AppFonts.largeTitle);   return AppFonts.largeTitle }
        public static var title: Font        { log("title", AppFonts.title);             return AppFonts.title }
        public static var headline: Font     { log("headline", AppFonts.headline);       return AppFonts.headline }
        public static var body: Font         { log("body", AppFonts.body);               return AppFonts.body }
        public static var caption: Font      { log("caption", AppFonts.caption);         return AppFonts.caption }
        public static var button: Font       { log("button", AppFonts.button);           return AppFonts.button }
        public static var tabBar: Font       { log("tabBar", AppFonts.tabBar);           return AppFonts.tabBar }
        public static var badge: Font        { log("badge", AppFonts.badge);             return AppFonts.badge }
        public static var dynamicBody: Font  { log("dynamicBody", AppFonts.dynamicBody); return AppFonts.dynamicBody }
        public static var dynamicTitle: Font { log("dynamicTitle", AppFonts.dynamicTitle); return AppFonts.dynamicTitle }
    }

    // MARK: - Spacing
    public enum Spacing {
        public static var xsmall: CGFloat    { log("xsmall", AppSpacing.xsmall); return AppSpacing.xsmall }
        public static var small: CGFloat     { log("small", AppSpacing.small);   return AppSpacing.small }
        public static var medium: CGFloat    { log("medium", AppSpacing.medium); return AppSpacing.medium }
        public static var large: CGFloat     { log("large", AppSpacing.large);   return AppSpacing.large }
        public static var xLarge: CGFloat    { log("xLarge", AppSpacing.xLarge); return AppSpacing.xLarge }
        public static var card: CGFloat      { log("card", AppSpacing.card);     return AppSpacing.card }
        public static var avatar: CGFloat    { log("avatar", AppSpacing.avatar); return AppSpacing.avatar }
        public static var pulseButtonScale: CGFloat { log("pulseButtonScale", AppSpacing.pulseButtonScale); return AppSpacing.pulseButtonScale }
    }

    // MARK: - Corner Radius
    public enum CornerRadius {
        public static var small: CGFloat     { log("small", AppRadius.small);     return AppRadius.small }
        public static var medium: CGFloat    { log("medium", AppRadius.medium);   return AppRadius.medium }
        public static var large: CGFloat     { log("large", AppRadius.large);     return AppRadius.large }
        public static var capsule: CGFloat   { log("capsule", AppRadius.capsule); return AppRadius.capsule }
        public static var button: CGFloat    { log("button", AppRadius.button);   return AppRadius.button }
    }

    // MARK: - Shadows
    public enum Shadows {
        public static var card: Shadow     { log("card", AppShadows.card);     return AppShadows.card }
        public static var modal: Shadow    { log("modal", AppShadows.modal);   return AppShadows.modal }
        public static var avatar: Shadow   { log("avatar", AppShadows.avatar); return AppShadows.avatar }
        public static var button: Shadow   { log("button", AppShadows.button); return AppShadows.button }
        public static var thin: Shadow     { log("thin", AppShadows.thin);     return AppShadows.thin }
        public static var inner: Shadow    { log("inner", AppShadows.inner);   return AppShadows.inner }
    }

    // MARK: - Animation Durations & Curves
    public enum Animation {
        public static var ultraFast: Double  { log("ultraFast", AppThemeDurations.ultraFast); return AppThemeDurations.ultraFast }
        public static var fast: Double       { log("fast", AppThemeDurations.fast);      return AppThemeDurations.fast }
        public static var standard: Double   { log("standard", AppThemeDurations.standard);  return AppThemeDurations.standard }
        public static var slow: Double       { log("slow", AppThemeDurations.slow);      return AppThemeDurations.slow }
        public static var extraSlow: Double  { log("extraSlow", AppThemeDurations.extraSlow); return AppThemeDurations.extraSlow }
        public static var pulse: Double      { log("pulse", AppThemeDurations.pulse);    return AppThemeDurations.pulse }
        public static var spinnerDuration: Double { log("spinnerDuration", AppThemeDurations.spinnerDuration); return AppThemeDurations.spinnerDuration }
    }

    // MARK: - Line Widths
    public enum LineWidth {
        public static var hairline: CGFloat  { log("hairline", AppLineWidths.hairline); return AppLineWidths.hairline }
        public static var thin: CGFloat      { log("thin", AppLineWidths.thin);         return AppLineWidths.thin }
        public static var standard: CGFloat  { log("standard", AppLineWidths.standard); return AppLineWidths.standard }
        public static var thick: CGFloat     { log("thick", AppLineWidths.thick);       return AppLineWidths.thick }
    }

    // MARK: - Utility: Token Logging (async/await) with audit context and escalation
    private static func log(_ token: String, _ value: Any) {
        let escalate = token.lowercased().contains("danger") ||
                       String(describing: value).lowercased().contains("danger") ||
                       token.lowercased().contains("delete") ||
                       token.lowercased().contains("critical")
        Task {
            await analyticsLogger.log(
                token: token,
                value: value,
                role: AppThemeAuditContext.role,
                staffID: AppThemeAuditContext.staffID,
                context: AppThemeAuditContext.context,
                escalate: escalate
            )
        }
    }

    // MARK: - Diagnostics API (returns audit events)
    public static func recentEvents() -> [AppThemeAnalyticsEvent] {
        analyticsLogger.recentEvents()
    }
}

// MARK: - Example Usage
/*
struct ContentView: View {
    var body: some View {
        Text("Hello, World!")
            .font(AppTheme.Fonts.title)
            .foregroundColor(AppTheme.Colors.textPrimary)
            .padding(AppTheme.Spacing.medium)
            .background(AppTheme.Colors.card)
            .cornerRadius(AppTheme.CornerRadius.medium)
            .shadow(color: AppTheme.Shadows.card.color,
                    radius: AppTheme.Shadows.card.radius,
                    x: AppTheme.Shadows.card.x,
                    y: AppTheme.Shadows.card.y)
    }
}
*/

// MARK: - Preview/Diagnostics UI

#if DEBUG
struct AppThemePreview: View {
    @State private var events: [AppThemeAnalyticsEvent] = []
    var analyticsLogger: AppThemeAnalyticsLogger = DefaultAppThemeAnalyticsLogger()
    var body: some View {
        VStack(spacing: 30) {
            Text(NSLocalizedString("apptheme_token_preview", value: "AppTheme Token Preview", comment: "Token preview title"))
                .font(.headline)
            Button(NSLocalizedString("show_recent_apptheme_events", value: "Show Recent Events", comment: "Show diagnostics log")) {
                events = analyticsLogger.recentEvents()
            }
            .padding(.top, 6)
            if !events.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(events) { event in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Token: \(event.token)").font(.caption).bold()
                                Text("Value: \(event.valueDescription)").font(.caption2)
                                Text("Role: \(event.role ?? "nil")").font(.caption2)
                                Text("StaffID: \(event.staffID ?? "nil")").font(.caption2)
                                Text("Context: \(event.context ?? "nil")").font(.caption2)
                                Text("Escalate: \(event.escalate ? "Yes" : "No")").font(.caption2)
                                Text("Timestamp: \(event.timestamp.formatted(date: .numeric, time: .standard))").font(.caption2)
                                Divider()
                            }
                        }
                    }
                    .padding()
                }
                .frame(maxHeight: 180)
                .background(Color(.systemGray6))
                .cornerRadius(7)
            }
        }
        .padding()
        .background(AppTheme.Colors.background)
    }
}

#Preview {
    AppThemePreview(analyticsLogger: DefaultAppThemeAnalyticsLogger())
}
#endif

//
//  AppTheme.swift
//  Furfolio
//
//  ENHANCED: Single source of truth for all design tokens.
//  Modular, audit-ready, preview/test-injectable, brand/white-label, robust.
//

import SwiftUI

// MARK: - Analytics/Audit Protocol

public protocol AppThemeAnalyticsLogger {
    func log(token: String, value: Any)
}
public struct NullAppThemeAnalyticsLogger: AppThemeAnalyticsLogger {
    public init() {}
    public func log(token: String, value: Any) {}
}

public enum AppTheme {
    // MARK: - Analytics DI (for BI/QA/Trust Center)
    public static var analyticsLogger: AppThemeAnalyticsLogger = NullAppThemeAnalyticsLogger()

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
        public static var small: CGFloat     { log("small", BorderRadius.small);     return BorderRadius.small }
        public static var medium: CGFloat    { log("medium", BorderRadius.medium);   return BorderRadius.medium }
        public static var large: CGFloat     { log("large", BorderRadius.large);     return BorderRadius.large }
        public static var capsule: CGFloat   { log("capsule", BorderRadius.capsule); return BorderRadius.capsule }
        public static var button: CGFloat    { log("button", BorderRadius.button);   return BorderRadius.button }
    }

    // MARK: - Shadows
    public enum Shadows {
        public static var card: AppShadow    { log("card", AppShadows.card);     return AppShadows.card }
        public static var modal: AppShadow   { log("modal", AppShadows.modal);   return AppShadows.modal }
        public static var avatar: AppShadow  { log("avatar", AppShadows.avatar); return AppShadows.avatar }
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
        // Add more animation tokens as needed.
    }

    // MARK: - Line Widths
    public enum LineWidth {
        public static var hairline: CGFloat  { log("hairline", AppLineWidths.hairline); return AppLineWidths.hairline }
        public static var thin: CGFloat      { log("thin", AppLineWidths.thin);         return AppLineWidths.thin }
        public static var standard: CGFloat  { log("standard", AppLineWidths.standard); return AppLineWidths.standard }
        public static var thick: CGFloat     { log("thick", AppLineWidths.thick);       return AppLineWidths.thick }
    }

    // MARK: - Utility: Token Logging
    private static func log(_ token: String, _ value: Any) {
        analyticsLogger.log(token: token, value: value)
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

//
//  Theme.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

// MARK: - DEPRECATED Theme.swift (Replace with AppColors, AppFonts, AppSpacing, BorderRadius, AppShadows)

import SwiftUI

/// **DEPRECATED:** This file centralizes app-wide style constants but is now replaced by a modular design token system.
/// Please migrate to use the following instead:
/// - Colors: `AppColors`
/// - Fonts: `AppFonts`
/// - Spacing: `AppSpacing`
/// - Corner Radii: `BorderRadius`
/// - Shadows: `AppShadows`
enum Theme {
    // MARK: - Colors

    static let primaryColor = Color("PrimaryColor")           // Define in Assets.xcassets → Use AppColors.primary instead
    static let secondaryColor = Color("SecondaryColor")       // Define in Assets.xcassets → Use AppColors.secondary instead
    static let backgroundColor = Color("BackgroundColor")     // Define in Assets.xcassets → Use AppColors.background instead
    static let cardColor = Color(.secondarySystemBackground)  // → Use AppColors.card instead
    static let accentColor = Color("AccentColor")             // Define in Assets.xcassets → Use AppColors.accent instead

    static let successColor = Color.green                      // → Use AppColors.success instead
    static let warningColor = Color.orange                     // → Use AppColors.warning instead
    static let errorColor = Color.red                           // → Use AppColors.error instead

    static let textPrimary = Color.primary                      // → Use AppColors.textPrimary instead
    static let textSecondary = Color.secondary                  // → Use AppColors.textSecondary instead

    // For gradients, shimmer, overlays, etc.
    static let shimmerBase = Color.gray.opacity(0.23)          // → Use AppColors.shimmerBase instead
    static let shimmerHighlight = Color.gray.opacity(0.42)     // → Use AppColors.shimmerHighlight instead
    static let overlay = Color.black.opacity(0.36)              // → Use AppColors.overlay instead

    // MARK: - Typography

    /// Fonts are now managed via AppFonts.
    static func font(_ style: FontStyle) -> Font {
        switch style {
        case .largeTitle: return .system(size: 34, weight: .bold, design: .rounded)
        case .title: return .system(size: 28, weight: .semibold, design: .rounded)
        case .headline: return .system(size: 20, weight: .semibold, design: .rounded)
        case .subheadline: return .system(size: 17, weight: .medium, design: .rounded)
        case .body: return .system(size: 17, weight: .regular, design: .rounded)
        case .callout: return .system(size: 16, weight: .regular, design: .rounded)
        case .caption: return .system(size: 13, weight: .regular, design: .rounded)
        case .caption2: return .system(size: 11, weight: .regular, design: .rounded)
        case .footnote: return .system(size: 12, weight: .medium, design: .rounded)
        case .button: return .system(size: 18, weight: .semibold, design: .rounded)
        case .badge: return .system(size: 12, weight: .bold, design: .rounded)
        }
    }

    enum FontStyle {
        case largeTitle, title, headline, subheadline, body, callout, caption, caption2, footnote, button, badge
    }

    // MARK: - Corner Radius

    /// Corner radii are now managed via BorderRadius.
    static let cornerRadiusLarge: CGFloat = 20
    static let cornerRadiusMedium: CGFloat = 12
    static let cornerRadiusSmall: CGFloat = 7

    // MARK: - Shadows

    /// Shadows are now managed via AppShadows.
    static let cardShadow = Color.black.opacity(0.05)
    static let shadowRadius: CGFloat = 4

    // MARK: - Spacing

    /// Spacing constants are now managed via AppSpacing.
    static let verticalSpacing: CGFloat = 16
    static let horizontalSpacing: CGFloat = 20

    // MARK: - Dynamic Support

    /// Returns the current color scheme (for dynamic/dark mode handling).
    static func colorScheme(_ environment: EnvironmentValues) -> ColorScheme {
        environment.colorScheme
    }

    /// Returns a dynamic card color depending on light/dark mode.
    static func dynamicCardColor(_ environment: EnvironmentValues) -> Color {
        environment.colorScheme == .dark ? Color(.systemGray6) : cardColor
    }
}

// MARK: - SwiftUI Preview

#if DEBUG
struct ThemePreview: View {
    var body: some View {
        VStack(spacing: Theme.verticalSpacing) {
            Group {
                Text("Primary Color").foregroundColor(Theme.primaryColor)
                Text("Secondary Color").foregroundColor(Theme.secondaryColor)
                Text("Success").foregroundColor(Theme.successColor)
                Text("Warning").foregroundColor(Theme.warningColor)
                Text("Error").foregroundColor(Theme.errorColor)
            }
            .font(Theme.font(.headline))

            RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium)
                .fill(Theme.cardColor)
                .frame(width: 180, height: 44)
                .shadow(color: Theme.cardShadow, radius: Theme.shadowRadius)

            Text("Large Title Font").font(Theme.font(.largeTitle))
            Text("Caption2 Font").font(Theme.font(.caption2))
        }
        .padding()
        .background(Theme.backgroundColor)
    }
}

#Preview {
    ThemePreview()
}
#endif

/*
 MIGRATION CHECKLIST:

 Theme Property           → New Design Token File / Property
 ---------------------------------------------------------
 primaryColor            → AppColors.primary
 secondaryColor          → AppColors.secondary
 backgroundColor         → AppColors.background
 cardColor               → AppColors.card
 accentColor             → AppColors.accent
 successColor            → AppColors.success
 warningColor            → AppColors.warning
 errorColor              → AppColors.error
 textPrimary             → AppColors.textPrimary
 textSecondary           → AppColors.textSecondary
 shimmerBase             → AppColors.shimmerBase
 shimmerHighlight        → AppColors.shimmerHighlight
 overlay                 → AppColors.overlay

 font(_:)                → AppFonts (use respective font styles)
 cornerRadiusLarge       → BorderRadius.large
 cornerRadiusMedium      → BorderRadius.medium
 cornerRadiusSmall       → BorderRadius.small

 cardShadow              → AppShadows.cardShadow
 shadowRadius            → AppShadows.shadowRadius

 verticalSpacing         → AppSpacing.vertical
 horizontalSpacing       → AppSpacing.horizontal

 Please replace all usages of Theme with the corresponding modular tokens to ensure consistency and future maintainability.
*/

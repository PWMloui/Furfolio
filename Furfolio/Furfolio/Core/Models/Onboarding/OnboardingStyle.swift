//
//  OnboardingStyle.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

/**
 OnboardingStyle
 ---------------
 Centralized styling tokens for Furfolio’s onboarding flow.

 - **Purpose**: Defines consistent colors, fonts, spacing, radii, and icon sizes for onboarding components.
 - **Architecture**: Static nested structs under the `OnboardingStyle` enum for logical grouping.
 - **Localization & Theming**: Colors and fonts can be overridden via `AppColors`, `AppFonts`, and adapt to system settings.
 - **Accessibility**: Tokens are chosen to meet contrast and sizing guidelines for dynamic type and high‑contrast modes.
 - **Preview/Testability**: Styling tokens are deterministic, enabling reliable SwiftUI previews and snapshot tests.
 */

import SwiftUI

// MARK: - Centralized Onboarding Styling Tokens

public enum OnboardingStyle {
    // MARK: Colors

    /// Color palette used throughout onboarding screens.
    struct Colors {
        static let accent: Color = AppColors.accent ?? .accentColor           /// Accent color for buttons and highlights
        static let secondary: Color = AppColors.secondary ?? .secondary       /// Secondary color for less prominent elements
        static let background: Color = AppColors.background ?? Color(.systemBackground) /// Background color for onboarding screens
        static let error: Color = AppColors.red ?? .red                       /// Error color for validation and alerts
        static let success: Color = AppColors.green ?? .green                 /// Success color for confirmations
        static let textSecondary: Color = AppColors.textSecondary ?? .secondary /// Secondary text color
        static let inactive: Color = AppColors.inactive ?? Color.gray.opacity(0.3) /// Inactive/disabled state color
    }

    // MARK: Fonts

    /// Font styles for titles, headings, and body text in onboarding.
    struct Fonts {
        static let title: Font = AppFonts.title ?? .title                     /// Main title font
        static let titleBold: Font = AppFonts.title.bold() ?? .title.bold()   /// Bolded title font for emphasis
        static let body: Font = AppFonts.body ?? .body                        /// Standard body text font
        static let headline: Font = AppFonts.headline ?? .headline            /// Headline font for key sections
        static let sectionHeader: Font = AppFonts.title2 ?? .title2.bold()    /// Section header font
    }

    // MARK: Spacing

    /// Standard spacing values for padding and layout in onboarding.
    struct Spacing {
        static let small: CGFloat = AppSpacing.small ?? 8                     /// Small spacing for tight elements
        static let medium: CGFloat = AppSpacing.medium ?? 16                  /// Medium spacing for standard gaps
        static let large: CGFloat = AppSpacing.large ?? 24                    /// Large spacing for major sections
        static let extraLarge: CGFloat = AppSpacing.extraLarge ?? 36          /// Extra large spacing for separation
        static let xxLarge: CGFloat = AppSpacing.xxLarge ?? 48                /// 2x extra large spacing
        static let xxxLarge: CGFloat = AppSpacing.xxxLarge ?? 72              /// 3x extra large spacing
    }

    // MARK: Radius

    /// Corner radius values for buttons and cards in onboarding.
    struct Radius {
        static let small: CGFloat = AppRadius.small ?? 8                      /// Small corner radius for minor elements
        static let medium: CGFloat = AppRadius.medium ?? 16                   /// Medium corner radius for buttons
        static let large: CGFloat = AppRadius.large ?? 24                     /// Large corner radius for cards/modals
    }

    // MARK: Icon Sizes

    /// Standard icon sizes for tutorial, permission, and header icons.
    struct Icons {
        static let tutorial: CGFloat = 90                                     /// Icon size for onboarding tutorial screens
        static let permission: CGFloat = 70                                   /// Icon size for permission prompts
        static let header: CGFloat = 64                                       /// Icon size for onboarding headers
    }
}

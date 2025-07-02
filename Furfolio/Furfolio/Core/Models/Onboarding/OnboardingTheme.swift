//
//  OnboardingTheme.swift
//  Furfolio
//
//  Created by mac on 6/27/25.

/**
 OnboardingTheme
 ---------------
 Centralized theming tokens for the Furfolio onboarding flow, providing consistent styling across views.

 - **Purpose**: Defines colors, fonts, spacing, corner radii, and icon sizes for onboarding screens.
 - **Architecture**: Public enum with nested static structs for logical grouping of style tokens.
 - **Localization & Theming**: Colors adapt to light/dark mode via Asset Catalog; fonts respond to Dynamic Type.
 - **Accessibility**: Spacing and sizes follow guidelines for tappable areas and legibility.
 - **Preview/Testability**: Deterministic tokens enable reliable SwiftUI previews and snapshot tests.
 */

import SwiftUI

public enum OnboardingTheme {
    /// Color palette for onboarding screens.
    public struct Colors {
        /// Background color for onboarding views.
        public static let background = Color("OnboardingBackground")
        /// Primary text color.
        public static let textPrimary = Color("OnboardingTextPrimary")
        /// Secondary text color.
        public static let textSecondary = Color("OnboardingTextSecondary")
        /// Accent color for buttons and highlights.
        public static let accent = Color("OnboardingAccent")
        /// Tint color for icons.
        public static let iconTint = Color("OnboardingIconTint")
    }

    /// Font styles for onboarding text.
    public struct Fonts {
        /// Font for titles.
        public static var title: Font { .system(.largeTitle, weight: .bold) }
        /// Font for headings.
        public static var heading: Font { .system(.title2, weight: .semibold) }
        /// Font for body text.
        public static var body: Font { .system(.body) }
        /// Font for captions and footnotes.
        public static var caption: Font { .system(.caption) }
    }

    /// Spacing metrics for layout and padding.
    public struct Spacing {
        /// Small spacing (e.g., between buttons).
        public static let small: CGFloat = 8
        /// Medium spacing (e.g., between form fields).
        public static let medium: CGFloat = 16
        /// Large spacing (e.g., around sections).
        public static let large: CGFloat = 24
    }

    /// Corner radius values for UI elements.
    public struct CornerRadius {
        /// Small corner radius (e.g., icons).
        public static let small: CGFloat = 4
        /// Medium corner radius (e.g., buttons).
        public static let medium: CGFloat = 8
        /// Large corner radius (e.g., cards).
        public static let large: CGFloat = 16
    }

    /// Standard icon sizes for onboarding illustrations.
    public struct IconSize {
        /// Small icon size.
        public static let small: CGFloat = 24
        /// Medium icon size.
        public static let medium: CGFloat = 48
        /// Large icon size.
        public static let large: CGFloat = 96
    }
}


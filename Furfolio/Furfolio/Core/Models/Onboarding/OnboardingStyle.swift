//
//  OnboardingStyle.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import SwiftUI

// MARK: - Centralized Onboarding Styling Tokens

enum OnboardingStyle {
    // MARK: Colors

    struct Colors {
        static let accent: Color = AppColors.accent ?? .accentColor
        static let secondary: Color = AppColors.secondary ?? .secondary
        static let background: Color = AppColors.background ?? Color(.systemBackground)
        static let error: Color = AppColors.red ?? .red
        static let success: Color = AppColors.green ?? .green
        static let textSecondary: Color = AppColors.textSecondary ?? .secondary
        static let inactive: Color = AppColors.inactive ?? Color.gray.opacity(0.3)
    }

    // MARK: Fonts

    struct Fonts {
        static let title: Font = AppFonts.title ?? .title
        static let titleBold: Font = AppFonts.title.bold() ?? .title.bold()
        static let body: Font = AppFonts.body ?? .body
        static let headline: Font = AppFonts.headline ?? .headline
        static let sectionHeader: Font = AppFonts.title2 ?? .title2.bold()
    }

    // MARK: Spacing

    struct Spacing {
        static let small: CGFloat = AppSpacing.small ?? 8
        static let medium: CGFloat = AppSpacing.medium ?? 16
        static let large: CGFloat = AppSpacing.large ?? 24
        static let extraLarge: CGFloat = AppSpacing.extraLarge ?? 36
        static let xxLarge: CGFloat = AppSpacing.xxLarge ?? 48
        static let xxxLarge: CGFloat = AppSpacing.xxxLarge ?? 72
    }

    // MARK: Radius

    struct Radius {
        static let small: CGFloat = AppRadius.small ?? 8
        static let medium: CGFloat = AppRadius.medium ?? 16
        static let large: CGFloat = AppRadius.large ?? 24
    }

    // MARK: Icon Sizes

    struct Icons {
        static let tutorial: CGFloat = 90
        static let permission: CGFloat = 70
        static let header: CGFloat = 64
    }
}

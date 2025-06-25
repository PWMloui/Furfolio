
//
//  tokens.swift
//  Furfolio
//
//  ENHANCED: Enterprise-grade, modular, analytics/audit–ready, future-proof token system.
//  Use this file as the single source of truth for all design tokens (colors, fonts, spacing, radii, animations, etc).
//

import SwiftUI

// MARK: - Analytics/Audit Protocols

public protocol TokensAnalyticsLogger {
    func log(token: String, value: Any)
}
public struct NullTokensAnalyticsLogger: TokensAnalyticsLogger {
    public init() {}
    public func log(token: String, value: Any) {}
}

// MARK: - Central Tokens Struct

enum Tokens {
    // Analytics logger for BI/QA/Trust Center/design system.
    static var analyticsLogger: TokensAnalyticsLogger = NullTokensAnalyticsLogger()

    // MARK: - Color Tokens
    enum Colors {
        static let primary: Color = Color("PrimaryColor")
        static let secondary: Color = Color("SecondaryColor")
        static let background: Color = Color("BackgroundColor")
        static let card: Color = Color(.secondarySystemGroupedBackground)
        static let success: Color = .green
        static let warning: Color = .orange
        static let danger: Color = .red
        static let info: Color = .blue
        static let overlay: Color = Color.black.opacity(0.36)
        static let shimmerBase: Color = Color.gray.opacity(0.23)
        static let shimmerHighlight: Color = Color.gray.opacity(0.42)
        static let textPrimary: Color = .primary
        static let textSecondary: Color = .secondary
        static let textPlaceholder: Color = Color.gray.opacity(0.54)
        static let separator: Color = Color(.separator)
        static let tagNew: Color = .blue
        static let tagActive: Color = .green
        static let tagReturning: Color = .purple
        static let tagRisk: Color = .orange
        static let tagInactive: Color = .gray
        static let button: Color = Color("PrimaryColor")
        static let buttonDisabled: Color = Color.gray.opacity(0.33)
        static let buttonText: Color = .white
    }

    // MARK: - Font Tokens
    enum Fonts {
        static let largeTitle: Font = .system(size: 34, weight: .bold, design: .rounded)
        static let title: Font = .system(size: 28, weight: .semibold, design: .rounded)
        static let headline: Font = .system(size: 20, weight: .semibold, design: .rounded)
        static let subheadline: Font = .system(size: 17, weight: .medium, design: .rounded)
        static let body: Font = .system(size: 17, weight: .regular, design: .rounded)
        static let callout: Font = .system(size: 16, weight: .regular, design: .rounded)
        static let caption: Font = .system(size: 13, weight: .regular, design: .rounded)
        static let caption2: Font = .system(size: 11, weight: .regular, design: .rounded)
        static let footnote: Font = .system(size: 12, weight: .medium, design: .rounded)
        static let button: Font = .system(size: 18, weight: .semibold, design: .rounded)
        static let tabBar: Font = .system(size: 14, weight: .medium, design: .rounded)
        static let badge: Font = .system(size: 12, weight: .bold, design: .rounded)
    }

    // MARK: - Spacing Tokens
    enum Spacing {
        static let none: CGFloat = 0
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 40
        static let section: CGFloat = 48
        static let listItem: CGFloat = 12
        static let card: CGFloat = 20
        static let avatar: CGFloat = 42
        static let pulseButtonScale: CGFloat = 1.09
        static let progressRingSize: CGFloat = 86
        static let progressRingStroke: CGFloat = 14
        static let skeletonPrimary: CGFloat = 140
        static let skeletonSecondaryMin: CGFloat = 90
        static let skeletonSecondaryVar: CGFloat = 30
        static let skeletonPrimaryHeight: CGFloat = 15
        static let skeletonSecondaryHeight: CGFloat = 11
        static let iconOffset: CGFloat = 22
        static let xsmall: CGFloat = 2
    }

    // MARK: - Corner Radius Tokens
    enum Radius {
        static let small: CGFloat = 6
        static let medium: CGFloat = 12
        static let large: CGFloat = 20
        static let capsule: CGFloat = 30
        static let button: CGFloat = 13
        static let full: CGFloat = 999
    }

    // MARK: - Shadow Tokens
    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
    enum Shadows {
        static let card = Shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 3)
        static let modal = Shadow(color: .black.opacity(0.14), radius: 16, x: 0, y: 8)
        static let thin = Shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
        static let inner = Shadow(color: .black.opacity(0.10), radius: 6, x: 0, y: 2)
        static let avatar = Shadow(color: .black.opacity(0.10), radius: 4, x: 0, y: 1)
        static let button = Shadow(color: .black.opacity(0.09), radius: 5, x: 0, y: 2)
    }

    // MARK: - Animation/Duration Tokens
    enum Animation {
        static let ultraFast: Double = 0.10
        static let fast: Double = 0.18
        static let standard: Double = 0.35
        static let slow: Double = 0.60
        static let extraSlow: Double = 0.98
        static let pulse: Double = 0.21
        static let spinnerDuration: Double = 0.8
        // Add more animation/duration tokens as needed.
    }

    // MARK: - Line Width Tokens
    enum LineWidth {
        static let hairline: CGFloat = 0.5
        static let thin: CGFloat = 1
        static let standard: CGFloat = 2
        static let thick: CGFloat = 4
    }

    // MARK: - Token Access Logging Example
    static func logToken(_ token: String, _ value: Any) {
        analyticsLogger.log(token: token, value: value)
    }
}

// MARK: - Usage Example

/*
struct ExampleView: View {
    var body: some View {
        Text("Hello, Furfolio!")
            .font(Tokens.Fonts.headline)
            .foregroundColor(Tokens.Colors.primary)
            .padding(Tokens.Spacing.medium)
            .background(Tokens.Colors.card)
            .cornerRadius(Tokens.Radius.medium)
            .shadow(color: Tokens.Shadows.card.color, radius: Tokens.Shadows.card.radius, x: Tokens.Shadows.card.x, y: Tokens.Shadows.card.y)
    }
}
*/


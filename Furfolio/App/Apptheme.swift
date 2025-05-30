//
//  AppTheme.swift
//  Furfolio
//
//  Created by mac on 5/28/25.
//

import SwiftUI

/// Centralized color, font, and style definitions for Furfolio.
struct AppTheme {
    // MARK: - Colors
    static let accent = Color("AccentColor", bundle: nil)
    static let background = Color("BackgroundColor", bundle: nil)
    static let surface = Color("SurfaceColor", bundle: nil)
    static let primaryText = Color("PrimaryTextColor", bundle: nil)
    static let secondaryText = Color("SecondaryTextColor", bundle: nil)
    static let error = Color.red
    static let warning = Color.orange
    static let success = Color.green
    static let disabled = Color("DisabledColor", bundle: nil)
    static let info = Color.blue

    // MARK: - Fonts
    static var header: Font {
        Font.system(size: 24, weight: .bold, design: .default)
    }
    static var title: Font {
        Font.system(size: 20, weight: .semibold, design: .default)
    }
    static var body: Font {
        Font.system(size: 16, weight: .regular, design: .default)
    }
    static var caption: Font {
        Font.system(size: 12, weight: .regular, design: .default)
    }
    /// Font style for subtitles, medium weight and size 18.
    static var subtitle: Font {
        Font.system(size: 18, weight: .medium, design: .default)
    }
    /// Font style for footnotes, regular weight and size 10.
    static var footnote: Font {
        Font.system(size: 10, weight: .regular, design: .default)
    }

    // MARK: - Corners & Shadows
    static let cornerRadius: CGFloat = 8
    static let shadowRadius: CGFloat = 4
    /// Default padding for cards.
    static let cardPadding: CGFloat = 12
    /// Default shadow color for cards with low opacity.
    static let cardShadowColor = Color.black.opacity(0.1)

    // MARK: - Spacing
    struct Spacing {
        static let tiny: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
    }
}

/// A View extension to apply a default background and primary text color.
extension View {
    func furfolioStyle() -> some View {
        self
            .foregroundColor(AppTheme.primaryText)
            .background(AppTheme.background)
    }

    func furfolioAccent() -> some View {
        self.accentColor(AppTheme.accent)
    }
    /// Applies a card style with padding, background, corner radius, and shadow.
    func cardStyle() -> some View {
        self
            .padding(AppTheme.cardPadding)
            .background(AppTheme.surface)
            .cornerRadius(AppTheme.cornerRadius)
            .shadow(color: AppTheme.cardShadowColor, radius: AppTheme.shadowRadius)
    }
}

struct FurfolioButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(AppTheme.Spacing.small)
            .background(AppTheme.accent)
            .foregroundColor(.white)
            .cornerRadius(AppTheme.cornerRadius)
            .opacity(configuration.isPressed ? 0.8 : (configuration.isEnabled ? 1.0 : 0.5))
    }
}

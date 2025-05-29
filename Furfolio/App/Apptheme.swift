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

    // MARK: - Corners & Shadows
    static let cornerRadius: CGFloat = 8
    static let shadowRadius: CGFloat = 4

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
}

struct FurfolioButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(AppTheme.Spacing.small)
            .background(AppTheme.accent)
            .foregroundColor(.white)
            .cornerRadius(AppTheme.cornerRadius)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

//
//   View+Modifiers.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//


import SwiftUI
import os
private let viewModifierLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "ViewModifiers")

// MARK: - Environment Keys for Theming

private struct CardCornerRadiusKey: EnvironmentKey {
    static let defaultValue: CGFloat = AppTheme.cornerRadius
}
extension EnvironmentValues {
    /// Corner radius to use for `cardStyle`.
    var cardCornerRadius: CGFloat {
        get { self[CardCornerRadiusKey.self] }
        set { self[CardCornerRadiusKey.self] = newValue }
    }
}

private struct CardShadowRadiusKey: EnvironmentKey {
    static let defaultValue: CGFloat = AppTheme.cornerRadius
}
extension EnvironmentValues {
    /// Shadow radius to use for `cardStyle`.
    var cardShadowRadius: CGFloat {
        get { self[CardShadowRadiusKey.self] }
        set { self[CardShadowRadiusKey.self] = newValue }
    }
}

/// Common view modifiers for consistent styling across the app.
extension View {
    /// Applies a card style with background, corner radius, and shadow.
    func cardStyle(
        cornerRadius: CGFloat,
        shadowRadius: CGFloat
    ) -> some View {
        self
            .onAppear { viewModifierLogger.log("Applied cardStyle with cornerRadius \(cornerRadius), shadowRadius \(shadowRadius)") }
            .padding()
            .background(AppTheme.background)
            .cornerRadius(cornerRadius)
            .shadow(color: Color.black.opacity(0.1),
                    radius: shadowRadius,
                    x: 0,
                    y: 2)
    }

    func cardStyle() -> some View {
        cardStyle(
            cornerRadius: Environment(\.cardCornerRadius).wrappedValue,
            shadowRadius: Environment(\.cardShadowRadius).wrappedValue
        )
    }

    /// Applies an animated card style with fade-in effect.
    func animatedCardStyle() -> some View {
        self
            .cardStyle()
            .opacity(0.01)
            .onAppear {
                withAnimation(.easeIn(duration: 0.3)) {
                    // Trigger fade-in
                    .opacity(1)
                }
            }
    }

    /// Applies an error card style with red border.
    func errorCardStyle() -> some View {
        self
            .padding()
            .background(AppTheme.background)
            .cornerRadius(Environment(\.cardCornerRadius).wrappedValue)
            .overlay(
                RoundedRectangle(cornerRadius: Environment(\.cardCornerRadius).wrappedValue)
                    .stroke(Color.warning, lineWidth: 2)
            )
    }

    /// Styles a view as the primary app button.
    func primaryButtonStyle(cornerRadius: CGFloat = 8) -> some View {
        self
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(AppTheme.accent)
            .cornerRadius(cornerRadius)
            .onAppear { viewModifierLogger.log("Applied primaryButtonStyle") }
    }

    /// Styles a view as the secondary app button.
    func secondaryButtonStyle(cornerRadius: CGFloat = 8) -> some View {
        self
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(AppTheme.info)
            .cornerRadius(cornerRadius)
            .onAppear { viewModifierLogger.log("Applied secondaryButtonStyle") }
    }

    /// Applies styling for input fields.
    func inputFieldStyle(borderColor: Color = Color.disabled) -> some View {
        self
            .padding(10)
            .background(AppTheme.background)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(borderColor, lineWidth: 1)
            )
    }

    /// Styles a section header text.
    func sectionHeaderStyle() -> some View {
        self
            .font(AppTheme.title)
            .foregroundColor(AppTheme.primaryText)
            .padding(.vertical, 4)
    }

    /// Styles informational text.
    func infoTextStyle() -> some View {
        self
            .font(AppTheme.body)
            .foregroundColor(AppTheme.info)
    }

    /// Styles warning text.
    func warningTextStyle() -> some View {
        self
            .font(AppTheme.body)
            .foregroundColor(AppTheme.warning)
    }

    /// Styles a view to indicate a disabled state with reduced opacity.
    func disabledStyle() -> some View {
        self
            .opacity(0.5)
            .onAppear { viewModifierLogger.log("Applied disabledStyle") }
    }

    /// Styles an input field to indicate an error with a red border.
    func errorFieldStyle() -> some View {
        self
            .padding(10)
            .background(AppTheme.background)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.warning, lineWidth: 1)
            )
    }
}

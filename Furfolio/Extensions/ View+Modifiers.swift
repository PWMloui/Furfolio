//
//   View+Modifiers.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//


import SwiftUI

// MARK: - Environment Keys for Theming

private struct CardCornerRadiusKey: EnvironmentKey {
    static let defaultValue: CGFloat = 10
}
extension EnvironmentValues {
    /// Corner radius to use for `cardStyle`.
    var cardCornerRadius: CGFloat {
        get { self[CardCornerRadiusKey.self] }
        set { self[CardCornerRadiusKey.self] = newValue }
    }
}

private struct CardShadowRadiusKey: EnvironmentKey {
    static let defaultValue: CGFloat = 5
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
            .padding()
            .background(Color.cardBackground)
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
            .opacity(0)
            .onAppear {
                withAnimation(.easeIn(duration: 0.3)) {
                    // Trigger fade-in
                }
            }
    }

    /// Applies an error card style with red border.
    func errorCardStyle() -> some View {
        self
            .padding()
            .background(Color.cardBackground)
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
            .background(Color.appPrimary)
            .cornerRadius(cornerRadius)
    }

    /// Styles a view as the secondary app button.
    func secondaryButtonStyle(cornerRadius: CGFloat = 8) -> some View {
        self
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.appSecondary)
            .cornerRadius(cornerRadius)
    }

    /// Applies styling for input fields.
    func inputFieldStyle(borderColor: Color = Color.disabled) -> some View {
        self
            .padding(10)
            .background(Color.background)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(borderColor, lineWidth: 1)
            )
    }

    /// Styles a section header text.
    func sectionHeaderStyle() -> some View {
        self
            .font(.title3)
            .foregroundColor(.appPrimary)
            .padding(.vertical, 4)
    }

    /// Styles informational text.
    func infoTextStyle() -> some View {
        self
            .font(.subheadline)
            .foregroundColor(.info)
    }

    /// Styles warning text.
    func warningTextStyle() -> some View {
        self
            .font(.subheadline)
            .foregroundColor(.warning)
    }

    /// Styles a view to indicate a disabled state with reduced opacity.
    func disabledStyle() -> some View {
        self
            .opacity(0.5)
    }

    /// Styles an input field to indicate an error with a red border.
    func errorFieldStyle() -> some View {
        self
            .padding(10)
            .background(Color.background)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.warning, lineWidth: 1)
            )
    }
}

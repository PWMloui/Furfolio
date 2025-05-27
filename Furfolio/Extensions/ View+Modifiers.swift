
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
    func cardStyle() -> some View {
        self
            .padding()
            .background(Color.cardBackground)
            .cornerRadius(Environment(\.cardCornerRadius).wrappedValue)
            .shadow(color: Color.black.opacity(0.1),
                    radius: Environment(\.cardShadowRadius).wrappedValue,
                    x: 0,
                    y: 2)
    }

    /// Styles a view as the primary app button.
    func primaryButtonStyle() -> some View {
        self
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.appPrimary)
            .cornerRadius(8)
    }

    /// Styles a view as the secondary app button.
    func secondaryButtonStyle() -> some View {
        self
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.appSecondary)
            .cornerRadius(8)
    }

    /// Applies styling for input fields.
    func inputFieldStyle() -> some View {
        self
            .padding(10)
            .background(Color.background)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.disabled, lineWidth: 1)
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

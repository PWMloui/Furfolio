//
//  Spacing.swift
//  Furfolio
//
//  Created by mac on 6/21/25.
//

import SwiftUI

// MARK: - AppSpacing (Centralized Spacing Tokens)

/// Central place for all standard spacing values in Furfolio.
/// Using these constants ensures consistent paddings and margins across the app,
/// which improves accessibility by maintaining predictable touch targets and layout rhythm,
/// supports responsive design by providing scalable spacing values,
/// and enhances code maintainability by avoiding magic numbers scattered throughout the codebase.
enum AppSpacing {
    static let none: CGFloat        = 0
    static let xxs: CGFloat         = 2
    static let xs: CGFloat          = 4
    static let small: CGFloat       = 8
    static let medium: CGFloat      = 16
    static let large: CGFloat       = 24
    static let xl: CGFloat          = 32
    static let xxl: CGFloat         = 40
    static let section: CGFloat     = 48
    static let listItem: CGFloat    = 12   // e.g., vertical spacing in lists
    static let card: CGFloat        = 20   // card padding

    /// An array containing all spacing values in defined order.
    static let all: [CGFloat] = [
        none, xxs, xs, small, medium, large, xl, xxl, section, listItem, card
    ]

    /// Provides a unified API for custom spacing values.
    /// - Parameter value: The custom spacing value.
    /// - Returns: The custom spacing value unchanged.
    static func custom(_ value: CGFloat) -> CGFloat {
        return value
    }
}

extension View {
    /// Applies uniform padding to the view using the given AppSpacing value.
    ///
    /// This modifier promotes consistency by encouraging the use of centralized spacing tokens,
    /// making layout adjustments easier and improving maintainability.
    /// - Parameter spacing: The spacing value from AppSpacing to apply as padding.
    /// - Returns: A view with the specified padding applied.
    func appPadding(_ spacing: CGFloat = AppSpacing.medium) -> some View {
        self.padding(spacing)
    }
}

/// Usage example:
/// ```swift
/// .padding(AppSpacing.medium)
/// .appPadding(AppSpacing.large)
/// ```

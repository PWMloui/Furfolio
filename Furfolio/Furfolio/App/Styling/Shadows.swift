//
//  Shadows.swift
//  Furfolio

import SwiftUI

// MARK: - AppShadows (Centralized Shadow Styles)

/// Central place for all standard drop shadow styles in Furfolio.
/// These shadows are designed to enhance accessibility and legibility by providing consistent depth cues,
/// improving visual hierarchy, and ensuring a cohesive design language across the app.
/// Use these constants in your Views for consistency and to maintain a polished, professional look.
struct AppShadows {
    /// Subtle shadow for cards, cells, buttons
    static let card = Shadow(
        color: Color.black.opacity(0.07),
        radius: 8,
        x: 0,
        y: 3
    )
    
    /// Heavier shadow for modals or popups
    static let modal = Shadow(
        color: Color.black.opacity(0.14),
        radius: 16,
        x: 0,
        y: 8
    )
    
    /// Minimal shadow for borders or pressed states
    static let thin = Shadow(
        color: Color.black.opacity(0.04),
        radius: 2,
        x: 0,
        y: 1
    )
    
    /// Inner shadow for pressed/selected effect (not native in SwiftUI, but useful for custom drawing)
    static let inner = Shadow(
        color: Color.black.opacity(0.10),
        radius: 6,
        x: 0,
        y: 2
    )
    
    /// All available shadows for preview, testing, or iteration
    static let all: [Shadow] = [card, modal, thin, inner]
}

/// Helper struct for shadow configuration
struct Shadow {
    /// The color of the shadow
    let color: Color
    /// The blur radius of the shadow
    let radius: CGFloat
    /// The horizontal offset of the shadow
    let x: CGFloat
    /// The vertical offset of the shadow
    let y: CGFloat
}

extension View {
    /// Applies a custom AppShadows style to any View.
    ///
    /// Use this modifier to apply Furfolio’s standardized shadow styles,
    /// ensuring consistent visual depth and design language throughout the app.
    /// - Parameter shadow: The `Shadow` style from `AppShadows` to apply.
    /// - Returns: A view with the specified shadow applied.
    func appShadow(_ shadow: Shadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}

// Usage example:
// Text("Hello, Furfolio!")
//     .padding()
//     .background(Color.white)
//     .appShadow(AppShadows.card)

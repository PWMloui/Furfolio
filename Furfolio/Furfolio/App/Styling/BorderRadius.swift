//
//  BorderRadius.swift
//  Furfolio
//
//  Created by mac on 6/21/25.
//

import Foundation
import SwiftUI

// MARK: - BorderRadius (Centralized Corner Radius Values)

/// Centralized border radius values for consistent corner rounding throughout Furfolio.
/// 
/// Use these predefined radius values to maintain a consistent and accessible design language across the app.
/// This helps ensure UI elements have uniform corner rounding, improving visual cohesion and user experience.
/// 
/// Usage:
/// ```swift
/// .cornerRadius(BorderRadius.medium)
/// ```
///
/// Accessibility:
/// Consider the size of the radius in relation to the UI element size to maintain clarity and usability.
enum BorderRadius {
    static let small: CGFloat = 6
    static let medium: CGFloat = 12
    static let large: CGFloat = 20
    static let full: CGFloat = 999 // For circular avatars/buttons
    
    /// An array of all predefined border radius values.
    static let all: [CGFloat] = [small, medium, large, full]
    
    /// Convenience method to return a rounded CGFloat value.
    /// - Parameter value: The radius value to round.
    /// - Returns: The rounded CGFloat value.
    static func rounded(_ value: CGFloat) -> CGFloat {
        return CGFloat(round(value))
    }
}

/// Usage example:
/// ```swift
/// struct ExampleView: View {
///     var body: some View {
///         Text("Hello, Furfolio!")
///             .padding()
///             .background(Color.blue)
///             .cornerRadius(BorderRadius.medium)
///     }
/// }
/// ```

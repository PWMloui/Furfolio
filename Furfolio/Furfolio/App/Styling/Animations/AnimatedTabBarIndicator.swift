//
//  AnimatedTabBarIndicator.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//
import SwiftUI

/// Animated bar indicator for a custom tab bar.
/// Use inside a ZStack beneath tab buttons to show selection.
struct AnimatedTabBarIndicator: View {
    /// Total number of tabs in the bar.
    var tabCount: Int

    /// Currently selected tab index.
    var selectedIndex: Int

    /// Color of the indicator bar.
    var color: Color = .accentColor

    /// Height of the indicator line.
    var height: CGFloat = 4

    /// Corner radius for the indicator bar.
    var cornerRadius: CGFloat = 2.5

    /// Padding inside each tab cell.
    var padding: CGFloat = 14

    /// Alignment position for the indicator (.top or .bottom)
    var alignment: VerticalAlignment = .bottom

    /// Layout direction (LTR or RTL)
    @Environment(\.layoutDirection) private var layoutDirection

    private enum Constants {
        static let animation: Animation = .spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0.1)
        static let offsetYPadding: CGFloat = 2
    }

    var body: some View {
        GeometryReader { geo in
            let tabWidth = geo.size.width / CGFloat(tabCount)
            let xOffset = CGFloat(layoutDirection == .leftToRight ? selectedIndex : (tabCount - 1 - selectedIndex)) * tabWidth + padding / 2
            let yOffset = alignment == .top ? Constants.offsetYPadding : geo.size.height - height - Constants.offsetYPadding

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(color)
                .frame(width: tabWidth - padding, height: height)
                .offset(x: xOffset, y: yOffset)
                .animation(Constants.animation, value: selectedIndex)
                .accessibilityHidden(true)
        }
    }
}

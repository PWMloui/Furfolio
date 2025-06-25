//
//  AnimatedTabBarIndicator.swift
//  Furfolio
//
//  Enhanced: Analytics/audit-ready, token-compliant, modular, accessible, preview/testable, and robust.
//
import SwiftUI

// MARK: - Analytics/Audit Logger Protocol

public protocol TabBarIndicatorAnalyticsLogger {
    func log(event: String, selectedIndex: Int, tabCount: Int)
}
public struct NullTabBarIndicatorAnalyticsLogger: TabBarIndicatorAnalyticsLogger {
    public init() {}
    public func log(event: String, selectedIndex: Int, tabCount: Int) {}
}

/// Animated bar indicator for a custom tab bar.
/// Use inside a ZStack beneath tab buttons to show selection.
/// Now with analytics/audit hooks, full token compliance, and advanced accessibility.
struct AnimatedTabBarIndicator: View {
    /// Total number of tabs in the bar.
    var tabCount: Int

    /// Currently selected tab index.
    var selectedIndex: Int

    /// Color of the indicator bar.
    var color: Color = AppColors.accent ?? .accentColor

    /// Height of the indicator line.
    var height: CGFloat = AppSpacing.tabBarIndicatorHeight ?? 4

    /// Corner radius for the indicator bar.
    var cornerRadius: CGFloat = AppRadius.small ?? 2.5

    /// Padding inside each tab cell.
    var padding: CGFloat = AppSpacing.medium ?? 14

    /// Alignment position for the indicator (.top or .bottom)
    var alignment: VerticalAlignment = .bottom

    /// Analytics/audit logger (DI for preview/test/enterprise)
    var analyticsLogger: TabBarIndicatorAnalyticsLogger = NullTabBarIndicatorAnalyticsLogger()

    /// Layout direction (LTR or RTL)
    @Environment(\.layoutDirection) private var layoutDirection

    private enum Tokens {
        static let animation: Animation = .spring(response: 0.28, dampingFraction: 0.88, blendDuration: 0.12)
        static let offsetYPadding: CGFloat = AppSpacing.xsmall ?? 2
    }

    var body: some View {
        GeometryReader { geo in
            let tabWidth = geo.size.width / CGFloat(max(tabCount, 1))
            let safeIndex = min(max(selectedIndex, 0), tabCount-1)
            let xOffset = CGFloat(layoutDirection == .leftToRight ? safeIndex : (tabCount - 1 - safeIndex)) * tabWidth + padding / 2
            let yOffset = alignment == .top ? Tokens.offsetYPadding : geo.size.height - height - Tokens.offsetYPadding

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(color)
                .frame(width: tabWidth - padding, height: height)
                .offset(x: xOffset, y: yOffset)
                .animation(Tokens.animation, value: safeIndex)
                .accessibilityElement()
                .accessibilityLabel(Text("Selected tab indicator"))
                .accessibilityValue(Text("Tab \(safeIndex + 1) of \(tabCount) selected"))
                .accessibilityAddTraits(.isSelected)
                .onAppear {
                    analyticsLogger.log(event: "indicator_appear", selectedIndex: safeIndex, tabCount: tabCount)
                }
                .onChange(of: safeIndex) { newValue in
                    analyticsLogger.log(event: "indicator_changed", selectedIndex: newValue, tabCount: tabCount)
                }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Tab bar indicator"))
    }
}

// MARK: - Preview

#if DEBUG
struct AnimatedTabBarIndicator_Previews: PreviewProvider {
    struct SpyLogger: TabBarIndicatorAnalyticsLogger {
        func log(event: String, selectedIndex: Int, tabCount: Int) {
            print("TabBarAnalytics: \(event) index:\(selectedIndex) count:\(tabCount)")
        }
    }
    static var previews: some View {
        VStack {
            ZStack(alignment: .bottom) {
                Color.gray.opacity(0.11)
                AnimatedTabBarIndicator(
                    tabCount: 4,
                    selectedIndex: 1,
                    color: .blue,
                    analyticsLogger: SpyLogger()
                )
            }
            .frame(height: 56)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif

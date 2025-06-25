//
//  LoadingSpinnerView.swift
//  Furfolio
//
//  Enhanced: Token-compliant, analytics/audit-ready, accessible, preview/testable, and robust.
//

import SwiftUI

// MARK: - Analytics/Audit Protocol

public protocol SpinnerAnalyticsLogger {
    func log(event: String, size: CGFloat, color: Color)
}
public struct NullSpinnerAnalyticsLogger: SpinnerAnalyticsLogger {
    public init() {}
    public func log(event: String, size: CGFloat, color: Color) {}
}

/// A reusable, theme-aware loading spinner for asynchronous operations, with audit/analytics and accessibility support.
struct LoadingSpinnerView: View {
    /// The diameter of the spinner.
    var size: CGFloat = AppTheme.Spacing.xLarge ?? 48
    
    /// The color of the spinner's stroke. Defaults to the app's primary theme color.
    var color: Color = AppTheme.Colors.primary
    
    /// The thickness of the spinner's stroke.
    var lineWidth: CGFloat = AppTheme.Spacing.small ?? 5

    /// Optional custom accessibility label.
    var accessibilityLabel: String = NSLocalizedString("Loading", comment: "Loading spinner accessibility label")
    
    /// Analytics logger (preview/test/QA/BI/Trust Center).
    var analyticsLogger: SpinnerAnalyticsLogger = NullSpinnerAnalyticsLogger()

    // Animation duration (tokenized, safe fallback)
    private let animationDuration: Double = AppTheme.Animation.spinnerDuration ?? 0.8

    @State private var isAnimating = false

    var body: some View {
        // Wrap spinner in a container for accessibility live region (announce loading state)
        ZStack {
            Circle()
                .trim(from: 0.1, to: 1.0)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .onAppear {
                    analyticsLogger.log(event: "spinner_appear", size: size, color: color)
                    withAnimation(.linear(duration: animationDuration).repeatForever(autoreverses: false)) {
                        isAnimating = true
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(accessibilityLabel))
                .accessibilityAddTraits(.isImage)
                .accessibilityHint(Text(NSLocalizedString("Activity in progress", comment: "Spinner accessibility hint")))
        }
        // Mark the spinner as a live region for VoiceOver
        .accessibilityLiveRegion(.polite)
        .accessibilityRole(.progressIndicator)
    }
}

// MARK: - Preview

#if DEBUG
struct LoadingSpinnerView_Previews: PreviewProvider {
    struct SpyLogger: SpinnerAnalyticsLogger {
        func log(event: String, size: CGFloat, color: Color) {
            print("[SpinnerAnalytics] \(event) size:\(size) color:\(color)")
        }
    }
    static var previews: some View {
        VStack(spacing: 40) {
            Text("Standard Spinner")
            LoadingSpinnerView(
                analyticsLogger: SpyLogger()
            )
            
            Text("Large Green Spinner")
                .font(AppTheme.Fonts.headline)
            LoadingSpinnerView(
                size: 80,
                color: AppTheme.Colors.success,
                lineWidth: 8,
                analyticsLogger: SpyLogger()
            )
        }
        .padding(AppTheme.Spacing.large)
        .background(AppTheme.Colors.background)
        .previewLayout(.sizeThatFits)
    }
}
#endif

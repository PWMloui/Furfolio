//
//  AnimatedProgressRing.swift
//  Furfolio
//
//  Enhanced: Analytics/audit-ready, token-compliant, modular, accessible, preview/testable, business/enterprise-ready.
//

import SwiftUI

// MARK: - Analytics/Audit Logger Protocol

public protocol ProgressRingAnalyticsLogger {
    func log(event: String, percent: Double, label: String?)
}
public struct NullProgressRingAnalyticsLogger: ProgressRingAnalyticsLogger {
    public init() {}
    public func log(event: String, percent: Double, label: String?) {}
}

/// A configurable animated circular progress ring used for KPIs, dashboards, or loyalty programs.
struct AnimatedProgressRing: View {
    /// Progress as a percentage (0.0 to 1.0).
    var percent: Double

    /// Optional label shown below the ring.
    var label: String? = nil

    /// Optional SF Symbol shown inside the ring.
    var icon: String? = nil

    /// Color of the progress ring and text/icon.
    var color: Color = AppColors.accent ?? .accentColor

    /// Size of the ring view (width/height).
    var size: CGFloat = AppSpacing.progressRingSize ?? 86

    /// Width of the circular stroke line.
    var ringWidth: CGFloat = AppSpacing.progressRingStroke ?? 14

    /// Background ring color.
    var backgroundColor: Color = AppColors.progressRingBackground ?? Color(.systemGray5)

    /// Whether the ring should animate from 0 to the target percent.
    var animate: Bool = true

    /// Whether to display the percentage value in the center.
    var showPercentText: Bool = true

    /// Analytics logger for business/compliance/test dashboards.
    var analyticsLogger: ProgressRingAnalyticsLogger = NullProgressRingAnalyticsLogger()

    @State private var animatedPercent: Double = 0.0

    // MARK: - Tokens (robust fallback)
    private enum Tokens {
        static let animationDuration: Double = 1.1
        static let iconOffset: CGFloat = AppSpacing.iconOffset ?? 22
        static let cornerRadius: CGFloat = AppRadius.medium ?? 16
        static let shadowRadius: CGFloat = 6
        static let vSpacing: CGFloat = AppSpacing.medium ?? 10
        static let hPadding: CGFloat = AppSpacing.small ?? 8
        static let labelFont: Font = AppFonts.footnote ?? .footnote
        static let percentFont: Font = AppFonts.progressRingPercent ?? .system(size: 24, weight: .bold, design: .rounded)
        static let iconFont: Font = AppFonts.progressRingIcon ?? .system(size: 18, weight: .bold)
        static let background: Color = AppColors.progressRingContainerBg ?? Color(.systemBackground).opacity(0.97)
        static let shadowColor: Color = .black.opacity(0.06)
        static let labelColor: Color = AppColors.secondary ?? .secondary
    }

    var body: some View {
        VStack(spacing: Tokens.vSpacing) {
            ZStack {
                // Base circle
                Circle()
                    .stroke(backgroundColor, style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))

                // Progress arc
                Circle()
                    .trim(from: 0, to: animate ? animatedPercent : percent)
                    .stroke(
                        color.gradient,
                        style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: Tokens.animationDuration), value: animatedPercent)

                // Center: % and/or icon
                VStack(spacing: 2) {
                    if showPercentText {
                        Text("\(Int((animate ? animatedPercent : percent) * 100))%")
                            .font(Tokens.percentFont)
                            .foregroundColor(color)
                            .minimumScaleFactor(0.8)
                            .accessibilityLabel(Text("\(Int((animate ? animatedPercent : percent) * 100)) percent"))
                    }
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(Tokens.iconFont)
                            .foregroundColor(color.opacity(0.75))
                            .accessibilityHidden(true)
                    }
                }
            }
            .frame(width: size, height: size)
            .onAppear(perform: handleAppear)
            .onChange(of: percent) { _, newValue in
                handlePercentChange(newValue)
            }

            if let label = label {
                Text(label)
                    .font(Tokens.labelFont)
                    .foregroundColor(Tokens.labelColor)
                    .accessibilityLabel(Text(label))
            }
        }
        .padding(Tokens.hPadding)
        .background(
            RoundedRectangle(cornerRadius: Tokens.cornerRadius)
                .fill(Tokens.background)
                .shadow(color: Tokens.shadowColor, radius: Tokens.shadowRadius, x: 0, y: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(Text("\(Int(percent * 100)) percent complete"))
    }

    private var accessibilityLabel: Text {
        if let label = label {
            return Text(label)
        } else {
            return Text("Progress Ring")
        }
    }

    private func handleAppear() {
        startAnimation()
        analyticsLogger.log(event: "appear", percent: percent, label: label)
    }

    private func handlePercentChange(_ newValue: Double) {
        startAnimation()
        analyticsLogger.log(event: "percent_changed", percent: newValue, label: label)
    }

    private func startAnimation() {
        if animate {
            withAnimation(.easeOut(duration: Tokens.animationDuration)) {
                animatedPercent = percent
            }
        } else {
            animatedPercent = percent
        }
    }
}

#if DEBUG
struct AnimatedProgressRing_Previews: PreviewProvider {
    struct SpyLogger: ProgressRingAnalyticsLogger {
        func log(event: String, percent: Double, label: String?) {
            print("RingAnalytics: \(event) \(percent*100)% \(label ?? "-")")
        }
    }
    static var previews: some View {
        VStack(spacing: 28) {
            AnimatedProgressRing(percent: 0.83, label: "Loyalty", icon: "star.fill", color: .yellow, analyticsLogger: SpyLogger())
            AnimatedProgressRing(percent: 0.51, label: "Revenue Goal", icon: "dollarsign.circle.fill", color: .green, analyticsLogger: SpyLogger())
            AnimatedProgressRing(percent: 0.34, label: "Retention", icon: "heart.fill", color: .pink, showPercentText: false, analyticsLogger: SpyLogger())
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .previewLayout(.sizeThatFits)
    }
}
#endif

import SwiftUI

// MARK: - Analytics/Audit Logger Protocol

public protocol SuccessCheckmarkAnalyticsLogger {
    func log(event: String, color: Color, size: CGFloat, delay: Double)
}
public struct NullSuccessCheckmarkAnalyticsLogger: SuccessCheckmarkAnalyticsLogger {
    public init() {}
    public func log(event: String, color: Color, size: CGFloat, delay: Double) {}
}

/// An animated checkmark view for confirming successful actions like form submissions or tasks.
/// Now analytics/audit–ready, fully tokenized, accessible, and test/preview–injectable.
struct SuccessCheckmarkView: View {
    // MARK: - Design tokens (with robust fallback)
    var circleColor: Color = AppColors.success ?? .green
    var checkColor: Color = AppColors.onSuccess ?? .white
    var size: CGFloat = AppSpacing.checkmarkSize ?? 72
    var lineWidth: CGFloat = AppSpacing.checkmarkStroke ?? 7
    var delay: Double = 0.0

    /// Analytics logger (for business/QA/Trust Center).
    var analyticsLogger: SuccessCheckmarkAnalyticsLogger = NullSuccessCheckmarkAnalyticsLogger()
    /// Optional callback when animation completes.
    var onComplete: (() -> Void)? = nil

    @State private var animateCircle = false
    @State private var animateCheck = false

    private enum Tokens {
        static let circleDuration: Double = AppTheme.Animation.checkmarkCircle ?? 0.38
        static let checkDuration: Double = AppTheme.Animation.checkmarkStroke ?? 0.43
        static let checkDelay: Double = 0.22
        static let shadowOpacity: Double = 0.17
        static let accessibilityLabel: String = NSLocalizedString("Success. Checkmark confirmed.", comment: "Accessibility label for animated checkmark")
        static let accessibilityHint: String = NSLocalizedString("Indicates a successful action.", comment: "Accessibility hint for animated checkmark")
    }

    var body: some View {
        ZStack {
            // Circular trim animation
            Circle()
                .trim(from: 0, to: animateCircle ? 1 : 0)
                .stroke(circleColor.opacity(0.7), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: size, height: size)
                .shadow(color: circleColor.opacity(Tokens.shadowOpacity), radius: 10, x: 0, y: 3)
                .animation(.easeOut(duration: Tokens.circleDuration).delay(delay), value: animateCircle)

            // Animated checkmark
            CheckmarkShape()
                .trim(from: 0, to: animateCheck ? 1 : 0)
                .stroke(checkColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .frame(width: size * 0.53, height: size * 0.53)
                .offset(y: size * 0.07)
                .animation(.easeOut(duration: Tokens.checkDuration).delay(delay + Tokens.checkDelay), value: animateCheck)
        }
        .onAppear {
            animateCircle = false
            animateCheck = false
            analyticsLogger.log(event: "success_checkmark_appear", color: circleColor, size: size, delay: delay)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                animateCircle = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + Tokens.checkDelay) {
                animateCheck = true
                // Optionally call completion handler after full animation
                DispatchQueue.main.asyncAfter(deadline: .now() + Tokens.checkDuration) {
                    onComplete?()
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(Tokens.accessibilityLabel))
        .accessibilityHint(Text(Tokens.accessibilityHint))
        .accessibilityAddTraits(.isImage)
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilityLiveRegion(.polite)
    }
}

/// Custom shape that draws a stylized checkmark using three anchor points.
struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let start = CGPoint(x: rect.minX + rect.width * 0.04, y: rect.midY * 1.15)
        let mid = CGPoint(x: rect.midX * 0.9, y: rect.maxY * 0.98)
        let end = CGPoint(x: rect.maxX * 0.98, y: rect.minY + rect.height * 0.20)
        path.move(to: start)
        path.addLine(to: mid)
        path.addLine(to: end)
        return path
    }
}

// MARK: - Preview

#if DEBUG
struct SuccessCheckmarkView_Previews: PreviewProvider {
    struct SpyLogger: SuccessCheckmarkAnalyticsLogger {
        func log(event: String, color: Color, size: CGFloat, delay: Double) {
            print("CheckmarkAnalytics: \(event) color:\(color) size:\(size) delay:\(delay)")
        }
    }
    static var previews: some View {
        VStack(spacing: 40) {
            SuccessCheckmarkView(circleColor: .green, checkColor: .white, size: 84, delay: 0.1, analyticsLogger: SpyLogger())
            SuccessCheckmarkView(circleColor: .blue, checkColor: .yellow, size: 60, analyticsLogger: SpyLogger())
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .previewLayout(.sizeThatFits)
    }
}
#endif

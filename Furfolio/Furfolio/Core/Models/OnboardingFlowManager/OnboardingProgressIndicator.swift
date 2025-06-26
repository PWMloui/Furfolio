//
//  OnboardingProgressIndicator.swift
//  Furfolio
//
//  Enhanced: Analytics/audit-ready, token-compliant, modular, accessible, testable, business/enterprise-ready.
//

import SwiftUI

// MARK: - Analytics/Audit Logger Protocol

public protocol ProgressAnalyticsLogger {
    func log(event: String, currentStep: Int, totalSteps: Int)
}
public struct NullProgressAnalyticsLogger: ProgressAnalyticsLogger {
    public init() {}
    public func log(event: String, currentStep: Int, totalSteps: Int) {}
}

// MARK: - Main Indicator

struct OnboardingProgressIndicator: View {
    let currentStep: Int
    let totalSteps: Int
    var onProgressChange: ((Int) -> Void)? = nil
    let analyticsLogger: ProgressAnalyticsLogger
    // Tokens (with safe fallback)
    let accent: Color
    let inactive: Color
    let spacing: CGFloat
    let widthActive: CGFloat
    let widthInactive: CGFloat
    let capsuleHeight: CGFloat
    let paddingY: CGFloat

    // MARK: - Dependency Injection for modular/test/preview
    init(
        currentStep: Int,
        totalSteps: Int,
        onProgressChange: ((Int) -> Void)? = nil,
        analyticsLogger: ProgressAnalyticsLogger = NullProgressAnalyticsLogger(),
        accent: Color = AppColors.accent ?? .accentColor,
        inactive: Color = AppColors.inactive ?? .gray.opacity(0.3),
        spacing: CGFloat = AppSpacing.medium ?? 8,
        widthActive: CGFloat = 28,
        widthInactive: CGFloat = 10,
        capsuleHeight: CGFloat = 10,
        paddingY: CGFloat = AppSpacing.medium ?? 8
    ) {
        self.currentStep = currentStep
        self.totalSteps = totalSteps
        self.onProgressChange = onProgressChange
        self.analyticsLogger = analyticsLogger
        self.accent = accent
        self.inactive = inactive
        self.spacing = spacing
        self.widthActive = widthActive
        self.widthInactive = widthInactive
        self.capsuleHeight = capsuleHeight
        self.paddingY = paddingY
    }

    // Defensive clamping for safe rendering
    private var safeCurrentStep: Int {
        guard totalSteps > 0 else { return 0 }
        return min(max(currentStep, 0), totalSteps - 1)
    }

    var body: some View {
        if totalSteps <= 0 {
            EmptyView()
        } else {
            HStack(spacing: spacing) {
                ForEach(0..<totalSteps, id: \.self) { idx in
                    Capsule()
                        .fill(idx == safeCurrentStep ? accent : inactive)
                        .frame(width: idx == safeCurrentStep ? widthActive : widthInactive, height: capsuleHeight)
                        .accessibilityElement()
                        .accessibilityLabel(Text("Step \(idx + 1) of \(totalSteps)"))
                        .accessibilityValue(
                            idx == safeCurrentStep
                            ? Text("Current step")
                            : Text("Not current step")
                        )
                        .accessibilityAddTraits(idx == safeCurrentStep ? .isSelected : [])
                }
            }
            .padding(.vertical, paddingY)
            .frame(maxWidth: .infinity)
            .animation(.easeInOut(duration: 0.25), value: safeCurrentStep)
            .accessibilityElement(children: .contain)
            .accessibilityHint(Text("Indicates your progress through the onboarding steps."))
            .onChange(of: safeCurrentStep) { newValue in
                onProgressChange?(newValue)
                analyticsLogger.log(event: "progress_changed", currentStep: newValue, totalSteps: totalSteps)
            }
        }
    }
}

// MARK: - Previews

#Preview {
    struct SpyLogger: ProgressAnalyticsLogger {
        func log(event: String, currentStep: Int, totalSteps: Int) {
            print("Analytics: \(event), Step: \(currentStep + 1)/\(totalSteps)")
        }
    }
    return Group {
        VStack {
            OnboardingProgressIndicator(
                currentStep: 2,
                totalSteps: 5,
                analyticsLogger: SpyLogger()
            )
            .padding()
            Text("Example step content goes here.")
                .padding(.bottom, 40)
        }
        .previewDisplayName("Light Mode")

        VStack {
            OnboardingProgressIndicator(
                currentStep: 2,
                totalSteps: 5,
                analyticsLogger: SpyLogger()
            )
            .padding()
            Text("Example step content goes here.")
                .padding(.bottom, 40)
        }
        .preferredColorScheme(.dark)
        .previewDisplayName("Dark Mode")

        VStack {
            OnboardingProgressIndicator(
                currentStep: 2,
                totalSteps: 5,
                analyticsLogger: SpyLogger()
            )
            .padding()
            Text("Example step content goes here.")
                .padding(.bottom, 40)
        }
        .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
        .previewDisplayName("Accessibility Extra Large Font")

        VStack {
            OnboardingProgressIndicator(
                currentStep: 0,
                totalSteps: 0,
                analyticsLogger: SpyLogger()
            )
            .padding()
            Text("No steps to display (totalSteps = 0).")
                .padding(.bottom, 40)
        }
        .previewDisplayName("Zero Steps")

        VStack {
            OnboardingProgressIndicator(
                currentStep: 10,
                totalSteps: 5,
                analyticsLogger: SpyLogger()
            )
            .padding()
            Text("currentStep out of bounds (clamped to valid range).")
                .padding(.bottom, 40)
        }
        .previewDisplayName("Current Step Out of Bounds")
    }
}

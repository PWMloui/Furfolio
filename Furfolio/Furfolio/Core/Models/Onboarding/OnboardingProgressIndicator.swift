//
//  OnboardingProgressIndicator.swift
//  Furfolio
//
//  Enhanced: Analytics/audit-ready, token-compliant, modular, accessible, testable, business/enterprise-ready.
//

import SwiftUI

// MARK: - Centralized Analytics + Audit Logging

public protocol AnalyticsServiceProtocol {
    func log(event: String, parameters: [String: Any]?)
    func screenView(_ name: String)
}

public protocol AuditLoggerProtocol {
    func record(_ message: String, metadata: [String: String]?)
    func recordSensitive(_ action: String, userId: String)
}

// MARK: - OnboardingProgressIndicator View

struct OnboardingProgressIndicator: View {
    let currentStep: Int
    let totalSteps: Int
    var onProgressChange: ((Int) -> Void)? = nil
    let analytics: AnalyticsServiceProtocol
    let audit: AuditLoggerProtocol

    // Tokens (with safe fallback)
    let accent: Color
    let inactive: Color
    let spacing: CGFloat
    let widthActive: CGFloat
    let widthInactive: CGFloat
    let capsuleHeight: CGFloat
    let paddingY: CGFloat

    // MARK: - Dependency Injection
    init(
        currentStep: Int,
        totalSteps: Int,
        onProgressChange: ((Int) -> Void)? = nil,
        analytics: AnalyticsServiceProtocol = AnalyticsService.shared,
        audit: AuditLoggerProtocol = AuditLogger.shared,
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
        self.analytics = analytics
        self.audit = audit
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
                analytics.log(event: "onboarding_progress_changed", parameters: [
                    "step": newValue,
                    "total": totalSteps
                ])
                audit.record("Progress indicator moved to step \(newValue + 1) of \(totalSteps)", metadata: nil)
            }
        }
    }
}

// MARK: - Previews

#Preview {
    struct MockAnalytics: AnalyticsServiceProtocol {
        func log(event: String, parameters: [String: Any]?) {
            print("[Analytics] \(event): \(parameters ?? [:])")
        }
        func screenView(_ name: String) {}
    }

    struct MockAudit: AuditLoggerProtocol {
        func record(_ message: String, metadata: [String: String]?) {
            print("[Audit] \(message)")
        }
        func recordSensitive(_ action: String, userId: String) {}
    }

    return Group {
        VStack {
            OnboardingProgressIndicator(
                currentStep: 2,
                totalSteps: 5,
                analytics: MockAnalytics(),
                audit: MockAudit()
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
                analytics: MockAnalytics(),
                audit: MockAudit()
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
                analytics: MockAnalytics(),
                audit: MockAudit()
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
                analytics: MockAnalytics(),
                audit: MockAudit()
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
                analytics: MockAnalytics(),
                audit: MockAudit()
            )
            .padding()
            Text("currentStep out of bounds (clamped to valid range).")
                .padding(.bottom, 40)
        }
        .previewDisplayName("Current Step Out of Bounds")
    }
}

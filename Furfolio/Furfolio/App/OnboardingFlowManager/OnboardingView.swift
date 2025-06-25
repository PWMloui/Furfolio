//
//  OnboardingView.swift
//  Furfolio
//
//  Enhanced: Analytics/audit–ready, modular, token-compliant, accessible, and preview/testable.
//

import SwiftUI

// MARK: - Analytics/Audit Logger Protocol

public protocol OnboardingViewAnalyticsLogger {
    func log(event: String, step: OnboardingStep?)
}
public struct NullOnboardingViewAnalyticsLogger: OnboardingViewAnalyticsLogger {
    public init() {}
    public func log(event: String, step: OnboardingStep?) {}
}

struct OnboardingView: View {
    // MARK: - Injectables (for preview/test/branding)
    @StateObject private var flowManager: OnboardingFlowManager
    private let analyticsLogger: OnboardingViewAnalyticsLogger

    // Tokens with fallback
    private let spacingM: CGFloat
    private let spacingL: CGFloat
    private let spacingXL: CGFloat
    private let fontBody: Font
    private let colorBackground: Color
    private let colorSecondaryBackground: Color

    // MARK: - Default initializer (prod)
    init(
        flowManager: @autoclosure @escaping () -> OnboardingFlowManager = OnboardingFlowManager(),
        analyticsLogger: OnboardingViewAnalyticsLogger = NullOnboardingViewAnalyticsLogger(),
        spacingM: CGFloat = AppSpacing.medium ?? 20,
        spacingL: CGFloat = AppSpacing.large ?? 24,
        spacingXL: CGFloat = AppSpacing.extraLarge ?? 28,
        fontBody: Font = AppFonts.body ?? .body,
        colorBackground: Color = AppColors.background ?? Color(.systemBackground),
        colorSecondaryBackground: Color = AppColors.secondaryBackground ?? Color(.secondarySystemBackground)
    ) {
        _flowManager = StateObject(wrappedValue: flowManager())
        self.analyticsLogger = analyticsLogger
        self.spacingM = spacingM
        self.spacingL = spacingL
        self.spacingXL = spacingXL
        self.fontBody = fontBody
        self.colorBackground = colorBackground
        self.colorSecondaryBackground = colorSecondaryBackground
    }

    var body: some View {
        VStack(spacing: spacingM) {
            // MARK: Progress Indicator
            OnboardingProgressIndicator(
                currentStep: flowManager.currentStep.rawValue,
                totalSteps: OnboardingStep.allCases.count,
                analyticsLogger: analyticsLogger
            )
            .accessibilityLabel(Text("Onboarding progress: step \(flowManager.currentStep.rawValue + 1) of \(OnboardingStep.allCases.count)"))
            .accessibilityHint(Text(flowManager.currentStep.localizedDescription))
            .accessibilityAddTraits(.isHeader)

            Spacer(minLength: spacingM)

            // MARK: Main Onboarding Content
            Group {
                switch flowManager.currentStep {
                case .welcome:
                    OnboardingSlideView(
                        imageName: "pawprint.fill",
                        title: LocalizedStringKey("Welcome to Furfolio!"),
                        description: LocalizedStringKey("All-in-one business management for dog groomers. Organize your appointments, clients, and business insights, all in one secure app."),
                        analyticsLogger: analyticsLogger
                    )
                case .dataImport:
                    OnboardingDataImportView()
                case .tutorial:
                    InteractiveTutorialView()
                case .faq:
                    OnboardingFAQView()
                case .permissions:
                    OnboardingPermissionView {
                        analyticsLogger.log(event: "onboarding_permission_continue", step: flowManager.currentStep)
                        flowManager.goToNextStep()
                    }
                case .finish:
                    OnboardingCompletionView {
                        analyticsLogger.log(event: "onboarding_complete", step: flowManager.currentStep)
                        flowManager.skipOnboarding()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut, value: flowManager.currentStep)

            Spacer(minLength: spacingL)

            // MARK: Navigation Controls
            if flowManager.currentStep != .finish {
                HStack {
                    if flowManager.currentStep != .welcome {
                        Button {
                            analyticsLogger.log(event: "onboarding_back", step: flowManager.currentStep)
                            flowManager.goToPreviousStep()
                        } label: {
                            Text(LocalizedStringKey("Back"))
                                .font(fontBody)
                        }
                        .padding(.horizontal, spacingL)
                        .accessibilityLabel(Text("Go back to previous step"))
                        .accessibilityHint(Text("Navigates to the previous onboarding step"))
                    }

                    Spacer()

                    Button {
                        analyticsLogger.log(event: "onboarding_next", step: flowManager.currentStep)
                        flowManager.goToNextStep()
                    } label: {
                        Text(flowManager.currentStep == .permissions ? LocalizedStringKey("Finish") : LocalizedStringKey("Next"))
                            .font(fontBody)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, spacingL)
                    .accessibilityLabel(
                        Text(flowManager.currentStep == .permissions ? "Finish onboarding" : "Go to next onboarding step")
                    )
                    .accessibilityHint(
                        Text(flowManager.currentStep == .permissions ? "Completes the onboarding process" : "Navigates to the next onboarding step")
                    )
                }
                .padding(.bottom, spacingXL)
                .transition(.opacity)
                .animation(.easeInOut, value: flowManager.currentStep)
            }
        }
        .onAppear {
            flowManager.loadOnboardingState()
            analyticsLogger.log(event: "onboarding_appear", step: flowManager.currentStep)
        }
        .fullScreenCover(isPresented: .constant(flowManager.isOnboardingComplete)) {
            // TODO: Handle onboarding completion here (e.g., show main app entry)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [colorBackground, colorSecondaryBackground]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Preview

#Preview {
    struct SpyLogger: OnboardingViewAnalyticsLogger {
        func log(event: String, step: OnboardingStep?) {
            print("Analytics Event: \(event), Step: \(step?.description ?? "-")")
        }
    }
    return Group {
        OnboardingView(
            flowManager: OnboardingFlowManager(),
            analyticsLogger: SpyLogger()
        )
        .preferredColorScheme(.light)
        .environment(\.sizeCategory, .medium)
        .previewDisplayName("Light Mode")

        OnboardingView(
            flowManager: OnboardingFlowManager(),
            analyticsLogger: SpyLogger()
        )
        .preferredColorScheme(.dark)
        .environment(\.sizeCategory, .medium)
        .previewDisplayName("Dark Mode")

        OnboardingView(
            flowManager: OnboardingFlowManager(),
            analyticsLogger: SpyLogger()
        )
        .preferredColorScheme(.light)
        .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
        .previewDisplayName("Accessibility Large Text")
    }
}

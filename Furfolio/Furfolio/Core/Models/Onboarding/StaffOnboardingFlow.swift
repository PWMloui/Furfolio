//
//  StaffOnboardingFlow.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

/**
 StaffOnboardingFlow
 -------------------
 A SwiftUI view guiding staff users through their role-specific onboarding sequence in Furfolio.

 - **Architecture**: MVVM-compatible View with internal @State for step tracking; injects `OnboardingTelemetryTracker` for analytics and audit.
 - **Concurrency & Async Logging**: Wraps telemetry calls in non-blocking async `Task` blocks to avoid UI delays.
 - **Audit/Analytics Ready**: Uses `telemetry` for centralized event logging; all user navigation actions are recorded.
 - **Localization**: All button titles and static text use `LocalizedStringKey`.
 - **Accessibility**: Navigation buttons include identifiers and labels for VoiceOver and UI testing.
 - **Diagnostics & Preview/Testability**: Can fetch and export audit logs via TelemetryTracker’s diagnostics APIs.
 */

import SwiftUI

/// A complete onboarding flow for users with the `.staff` role
public struct StaffOnboardingFlow: View {
    @State private var currentStepIndex = 0
    @State private var isComplete = false

    private let steps = OnboardingPathProvider.steps(for: .staff)
    private let telemetry = OnboardingTelemetryTracker(userId: "staff-user-id")

    var onFinish: () -> Void = {}

    var body: some View {
        if isComplete {
            onFinish()
        } else {
            VStack {
                // Optional Progress Indicator
                OnboardingProgressIndicator(
                    currentStep: currentStepIndex,
                    totalSteps: steps.count,
                    analytics: telemetry.analytics,
                    audit: telemetry.audit
                )

                Spacer()

                currentStepView(for: steps[currentStepIndex])

                Spacer()

                HStack {
                    if currentStepIndex > 0 {
                        Button(action: {
                            Task {
                                let step = steps[currentStepIndex]
                                await telemetry.logAction("onboarding_back", step: step)
                                await MainActor.run {
                                    currentStepIndex -= 1
                                }
                            }
                        }) {
                            Text(LocalizedStringKey("Back"))
                        }
                        .accessibilityIdentifier("StaffOnboarding_BackButton")
                        .accessibilityLabel(LocalizedStringKey("Back"))
                    }

                    Spacer()

                    Button(action: {
                        Task {
                            let step = steps[currentStepIndex]
                            if currentStepIndex == steps.count - 1 {
                                await telemetry.logCompletion(finalStep: step)
                                await MainActor.run {
                                    isComplete = true
                                }
                            } else {
                                await telemetry.logAction("onboarding_next", step: step)
                                await MainActor.run {
                                    currentStepIndex += 1
                                }
                            }
                        }
                    }) {
                        Text(LocalizedStringKey(currentStepIndex == steps.count - 1 ? "Finish" : "Next"))
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("StaffOnboarding_NextButton")
                    .accessibilityLabel(LocalizedStringKey(currentStepIndex == steps.count - 1 ? "Finish" : "Next"))
                }
                .padding()
            }
            .onAppear {
                Task {
                    let step = steps[currentStepIndex]
                    await telemetry.logStepView(step)
                }
            }
        }
    }

    @ViewBuilder
    private func currentStepView(for step: OnboardingStep) -> some View {
        switch step {
        case .welcome:
            OnboardingWelcomeView(
                onContinue: { advance() },
                analytics: telemetry.analytics,
                audit: telemetry.audit
            )
        case .tutorial:
            InteractiveTutorialView(
                analytics: telemetry.analytics,
                audit: telemetry.audit
            )
        case .faq:
            OnboardingFAQView(
                analytics: telemetry.analytics,
                audit: telemetry.audit
            )
        case .completion:
            OnboardingCompletionView(onFinish: { advance() })
        default:
            Text("Unsupported step for staff")
        }
    }

    private func advance() {
        if currentStepIndex < steps.count - 1 {
            currentStepIndex += 1
        } else {
            isComplete = true
        }
    }
}

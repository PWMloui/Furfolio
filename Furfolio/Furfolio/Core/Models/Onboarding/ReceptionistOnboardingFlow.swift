//
//  ReceptionistOnboardingFlow.swift
//  Furfolio
//
//  Created by mac on 6/27/25.
//


// MARK: - ReceptionistOnboardingFlow.swift

/**
 ReceptionistOnboardingFlow
 ---------------------------
 A SwiftUI view guiding receptionist users through onboarding steps in Furfolio.

 - **Architecture**: MVVM-compatible View using @State for local step tracking.
 - **Dependencies**: Injects `OnboardingTelemetryTracker` for analytics and audit logging.
 - **Concurrency & Async Logging**: Wraps telemetry.log and telemetry.audit.record calls in non-blocking `Task` blocks.
 - **Accessibility**: Buttons include accessibility identifiers and localized labels for VoiceOver.
 - **Localization**: All static text should use `LocalizedStringKey` or `NSLocalizedString`.
 - **Preview/Testability**: The flow can be tested by simulating state changes and inspecting audit entries.
 */

import SwiftUI

struct ReceptionistOnboardingFlow: View {
    @State private var currentStepIndex = 0
    @State private var isComplete = false

    private let steps = OnboardingPathProvider.steps(for: .receptionist)
    private let telemetry = OnboardingTelemetryTracker(userId: "receptionist-user-id")

    var onFinish: () -> Void = {}

    var body: some View {
        if isComplete {
            onFinish()
        } else {
            VStack {
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
                                await telemetry.analytics.log(event: "onboarding_back", parameters: ["step": step.rawValue])
                                await telemetry.audit.record("Receptionist went back from step \(step.rawValue)", metadata: nil)
                                currentStepIndex -= 1
                            }
                        }) {
                            Text(LocalizedStringKey("Back"))
                        }
                        .accessibilityIdentifier("ReceptionistOnboarding_BackButton")
                        .accessibilityLabel(LocalizedStringKey("Back"))
                    }

                    Spacer()

                    Button(action: {
                        Task {
                            let step = steps[currentStepIndex]
                            if currentStepIndex == steps.count - 1 {
                                await telemetry.analytics.log(event: "onboarding_complete", parameters: ["step": step.rawValue])
                                await telemetry.audit.record("Receptionist completed onboarding at step \(step.rawValue)", metadata: nil)
                                isComplete = true
                            } else {
                                await telemetry.analytics.log(event: "onboarding_next", parameters: ["step": step.rawValue])
                                await telemetry.audit.record("Receptionist advanced from step \(step.rawValue)", metadata: nil)
                                currentStepIndex += 1
                            }
                        }
                    }) {
                        Text(LocalizedStringKey(currentStepIndex == steps.count - 1 ? "Finish" : "Next"))
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("ReceptionistOnboarding_NextButton")
                    .accessibilityLabel(LocalizedStringKey(currentStepIndex == steps.count - 1 ? "Finish" : "Next"))
                }
                .padding()
            }
            .onAppear {
                Task {
                    let step = steps[currentStepIndex]
                    await telemetry.analytics.screenView("receptionist_onboarding_step_\(step.rawValue)")
                    await telemetry.analytics.log(event: "onboarding_step_viewed", parameters: ["step": step.rawValue])
                    await telemetry.audit.record("Viewed receptionist onboarding step \(step.rawValue)", metadata: nil)
                }
            }
        }
    }

    @ViewBuilder
    private func currentStepView(for step: OnboardingStep) -> some View {
        switch step {
        case .welcome:
            OnboardingWelcomeView(onContinue: { advance() }, analytics: telemetry.analytics, audit: telemetry.audit)
        case .tutorial:
            InteractiveTutorialView(analytics: telemetry.analytics, audit: telemetry.audit)
        case .permissions:
            OnboardingPermissionView(analytics: telemetry.analytics, audit: telemetry.audit)
        case .completion:
            OnboardingCompletionView(onFinish: { advance() })
        default:
            Text(LocalizedStringKey("Unsupported step"))
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

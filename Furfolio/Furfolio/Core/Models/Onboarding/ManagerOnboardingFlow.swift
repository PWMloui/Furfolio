//
//  ManagerOnboardingFlow.swift
//  Furfolio
//
//  Created by mac on 6/27/25.
//

/**
 ManagerOnboardingFlow
 ---------------------
 A SwiftUI view orchestrating the onboarding steps for manager users in Furfolio.

 - **Architecture**: MVVM-capable, using `OnboardingTelemetryTracker` for analytics and audit.
 - **Concurrency & Async Logging**: Wraps analytics and audit calls in async Tasks to avoid blocking the UI.
 - **Localization**: All button titles and static text should be localized using `LocalizedStringKey` or `NSLocalizedString`.
 - **Accessibility**: Navigation buttons include accessibility identifiers and labels.
 - **Preview/Testability**: The flow can be injected with mock telemetry for testing and previews.
 */

// MARK: - ManagerOnboardingFlow.swift

import SwiftUI

struct ManagerOnboardingFlow: View {
    @State private var currentStepIndex = 0
    @State private var isComplete = false

    private let steps = OnboardingPathProvider.steps(for: .manager)
    private let telemetry = OnboardingTelemetryTracker(userId: "manager-user-id")

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
                        Button(LocalizedStringKey("Back")) { currentStepIndex -= 1 }
                            .accessibilityIdentifier("OnboardingFlow_BackButton")
                            .accessibilityLabel(LocalizedStringKey("Back"))
                    }

                    Spacer()

                    Button(currentStepIndex == steps.count - 1 ? LocalizedStringKey("Finish") : LocalizedStringKey("Next")) {
                        Task {
                            if currentStepIndex == steps.count - 1 {
                                await telemetry.analytics.log(event: "onboarding_finish", parameters: ["step": steps[currentStepIndex].rawValue])
                                await telemetry.audit.record("Completed onboarding at step \(steps[currentStepIndex].rawValue)", metadata: ["step": "\(currentStepIndex)"])
                                isComplete = true
                            } else {
                                await telemetry.analytics.log(event: "onboarding_next", parameters: ["step": steps[currentStepIndex].rawValue])
                                await telemetry.audit.record("Advanced to next onboarding step from \(steps[currentStepIndex].rawValue)", metadata: ["step": "\(currentStepIndex)"])
                                currentStepIndex += 1
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("OnboardingFlow_NextButton")
                    .accessibilityLabel(LocalizedStringKey(currentStepIndex == steps.count - 1 ? "Finish" : "Next"))
                }
                .padding()
            }
            .onAppear {
                Task {
                    await telemetry.analytics.screenView("onboarding_step_\(steps[currentStepIndex].rawValue)")
                    await telemetry.audit.record("Viewed onboarding step \(steps[currentStepIndex].rawValue)", metadata: ["step": "\(currentStepIndex)"])
                }
            }
        }
    }

    @ViewBuilder
    private func currentStepView(for step: OnboardingStep) -> some View {
        switch step {
        case .welcome:
            OnboardingWelcomeView(onContinue: { advance() }, analytics: telemetry.analytics, audit: telemetry.audit)
        case .dataImport:
            OnboardingDataImportView(analytics: telemetry.analytics, audit: telemetry.audit)
        case .tutorial:
            InteractiveTutorialView(analytics: telemetry.analytics, audit: telemetry.audit)
        case .permissions:
            OnboardingPermissionView(analytics: telemetry.analytics, audit: telemetry.audit)
        case .completion:
            OnboardingCompletionView(onFinish: { advance() })
        default:
            Text("Unsupported step")
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


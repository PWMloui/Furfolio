//
//  ReceptionistOnboardingFlow.swift
//  Furfolio
//
//  Created by mac on 6/27/25.
//

// MARK: - ReceptionistOnboardingFlow.swift

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
                        Button("Back") { currentStepIndex -= 1 }
                    }

                    Spacer()

                    Button(currentStepIndex == steps.count - 1 ? "Finish" : "Next") {
                        if currentStepIndex == steps.count - 1 {
                            telemetry.logCompletion(finalStep: steps[currentStepIndex])
                            isComplete = true
                        } else {
                            telemetry.logAction("next", step: steps[currentStepIndex])
                            currentStepIndex += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .onAppear {
                telemetry.logStepView(steps[currentStepIndex])
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

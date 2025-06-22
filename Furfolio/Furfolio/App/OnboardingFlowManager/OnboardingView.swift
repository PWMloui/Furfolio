//
//  OnboardingView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

/// Root view for displaying the multi-step onboarding flow in Furfolio.
struct OnboardingView: View {
    @StateObject private var flowManager = OnboardingFlowManager()

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Progress Indicator
            OnboardingProgressIndicator(
                currentStep: flowManager.currentStep.rawValue,
                totalSteps: OnboardingStep.allCases.count
            )
            .accessibilityHidden(true)

            Spacer(minLength: 20)

            // MARK: Main Onboarding Content
            Group {
                switch flowManager.currentStep {
                case .welcome:
                    OnboardingSlideView(
                        imageName: "pawprint.fill",
                        title: "Welcome to Furfolio!",
                        description: "All-in-one business management for dog groomers. Organize your appointments, clients, and business insights, all in one secure app."
                    )
                case .dataImport:
                    OnboardingDataImportView()
                case .tutorial:
                    InteractiveTutorialView()
                case .faq:
                    OnboardingFAQView()
                case .permissions:
                    OnboardingPermissionView {
                        flowManager.goToNextStep()
                    }
                case .finish:
                    OnboardingCompletionView {
                        flowManager.skipOnboarding()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut, value: flowManager.currentStep)

            Spacer(minLength: 24)

            // MARK: Navigation Controls
            if flowManager.currentStep != .finish {
                HStack {
                    if flowManager.currentStep != .welcome {
                        Button("Back") {
                            flowManager.goToPreviousStep()
                        }
                        .padding(.horizontal, 24)
                        .accessibilityLabel("Go back to previous step")
                    }

                    Spacer()

                    Button(flowManager.currentStep == .permissions ? "Finish" : "Next") {
                        flowManager.goToNextStep()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, 24)
                    .accessibilityLabel("Go to next onboarding step")
                }
                .padding(.bottom, 28)
                .transition(.opacity)
            }
        }
        .onAppear {
            flowManager.loadOnboardingState()
        }
        .fullScreenCover(isPresented: .constant(flowManager.isOnboardingComplete)) {
            // Replace with main app entry point or dismiss logic.
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color(.systemBackground), Color(.secondarySystemBackground)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .accessibilityElement(children: .contain)
    }
}

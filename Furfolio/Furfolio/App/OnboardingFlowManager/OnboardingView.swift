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
        VStack(spacing: AppSpacing.medium) { // TODO: Define AppSpacing.medium = 20
            // MARK: Progress Indicator
            OnboardingProgressIndicator(
                currentStep: flowManager.currentStep.rawValue,
                totalSteps: OnboardingStep.allCases.count
            )
            .accessibilityHidden(true)

            Spacer(minLength: AppSpacing.medium) // TODO: Define AppSpacing.medium = 20

            // MARK: Main Onboarding Content
            Group {
                switch flowManager.currentStep {
                case .welcome:
                    OnboardingSlideView(
                        imageName: "pawprint.fill",
                        title: LocalizedStringKey("Welcome to Furfolio!"),
                        description: LocalizedStringKey("All-in-one business management for dog groomers. Organize your appointments, clients, and business insights, all in one secure app.")
                    )
                    .accessibilityElement(children: .contain)
                case .dataImport:
                    OnboardingDataImportView()
                        .accessibilityElement(children: .contain)
                case .tutorial:
                    InteractiveTutorialView()
                        .accessibilityElement(children: .contain)
                case .faq:
                    OnboardingFAQView()
                        .accessibilityElement(children: .contain)
                case .permissions:
                    OnboardingPermissionView {
                        flowManager.goToNextStep()
                    }
                    .accessibilityElement(children: .contain)
                case .finish:
                    OnboardingCompletionView {
                        flowManager.skipOnboarding()
                    }
                    .accessibilityElement(children: .contain)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut, value: flowManager.currentStep)

            Spacer(minLength: AppSpacing.large) // TODO: Define AppSpacing.large = 24

            // MARK: Navigation Controls
            if flowManager.currentStep != .finish {
                HStack {
                    if flowManager.currentStep != .welcome {
                        Button {
                            flowManager.goToPreviousStep()
                        } label: {
                            Text(LocalizedStringKey("Back"))
                                .font(AppFonts.body) // TODO: Define AppFonts.body
                        }
                        .padding(.horizontal, AppSpacing.large) // TODO: Define AppSpacing.large = 24
                        .accessibilityLabel(LocalizedStringKey("Go back to previous step"))
                        .accessibilityHint(LocalizedStringKey("Navigates to the previous onboarding step"))
                    }

                    Spacer()

                    Button {
                        flowManager.goToNextStep()
                    } label: {
                        Text(flowManager.currentStep == .permissions ? LocalizedStringKey("Finish") : LocalizedStringKey("Next"))
                            .font(AppFonts.body) // TODO: Define AppFonts.body
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, AppSpacing.large) // TODO: Define AppSpacing.large = 24
                    .accessibilityLabel(LocalizedStringKey(flowManager.currentStep == .permissions ? "Finish onboarding" : "Go to next onboarding step"))
                    .accessibilityHint(LocalizedStringKey(flowManager.currentStep == .permissions ? "Completes the onboarding process" : "Navigates to the next onboarding step"))
                }
                .padding(.bottom, AppSpacing.extraLarge) // TODO: Define AppSpacing.extraLarge = 28
                .transition(.opacity)
                .animation(.easeInOut, value: flowManager.currentStep)
            }
        }
        .onAppear {
            flowManager.loadOnboardingState()
        }
        .fullScreenCover(isPresented: .constant(flowManager.isOnboardingComplete)) {
            // TODO: Handle onboarding completion here.
            // For example, dismiss this view or show the main app entry point.
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    AppColors.background, // TODO: Define AppColors.background
                    AppColors.secondaryBackground // TODO: Define AppColors.secondaryBackground
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .accessibilityElement(children: .contain)
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            OnboardingView()
                .preferredColorScheme(.light)
                .environment(\.sizeCategory, .medium)
                .previewDisplayName("Light Mode")

            OnboardingView()
                .preferredColorScheme(.dark)
                .environment(\.sizeCategory, .medium)
                .previewDisplayName("Dark Mode")

            OnboardingView()
                .preferredColorScheme(.light)
                .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
                .previewDisplayName("Accessibility Large Text")
        }
    }
}

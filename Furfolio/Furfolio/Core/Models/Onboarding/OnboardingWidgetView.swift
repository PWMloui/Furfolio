//
//  OnboardingWidgetView.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//
/**
 OnboardingWidgetView
 --------------------
 A SwiftUI view prompting users to enable the Furfolio home screen widget during onboarding.

 - **Architecture**: MVVM-capable View with dependency injection of `OnboardingTelemetryTracker`.
 - **Concurrency & Async Logging**: Wraps telemetry and audit calls in `Task` for non-blocking execution.
 - **Audit & Analytics Ready**: Uses async methods from `OnboardingTelemetryTracker` and `OnboardingWidgetSupport` for logging and widget flow.
 - **Localization**: All user-facing text uses `LocalizedStringKey` or `NSLocalizedString`.
 - **Accessibility**: Provides identifiers, labels, and hints for VoiceOver.
 - **Preview/Testability**: Preview injects a real tracker and prints events for testing.
 */

import SwiftUI

struct OnboardingWidgetView: View {
    let onContinue: () -> Void
    let telemetry: OnboardingTelemetryTracker

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "rectangle.stack.fill.badge.plus")
                .resizable()
                .scaledToFit()
                .frame(height: 80)
                .foregroundColor(.accentColor)
                .accessibilityHidden(true)

            Text("Stay Informed at a Glance")
                .font(.title.bold())
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text("Add the Furfolio home screen widget to view today's appointments and key stats without opening the app.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            Button {
                Task {
                    // Async telemetry logging
                    await telemetry.logAction("enable_widget", step: .completion)
                    // Async audit/widget support
                    await OnboardingWidgetSupport.markSuggestionShownAsync()
                    await OnboardingWidgetSupport.openWidgetConfigurationAsync()
                    // Continue flow on main actor
                    await MainActor.run {
                        onContinue()
                    }
                }
            } label: {
                Text("Enable Widget")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            .accessibilityIdentifier("OnboardingWidgetView_EnableButton")

            Button {
                Task {
                    await telemetry.logAction("skip_widget", step: .completion)
                    await OnboardingWidgetSupport.markSuggestionShownAsync()
                    await MainActor.run {
                        onContinue()
                    }
                }
            } label: {
                Text(LocalizedStringKey("Skip for Now"))
                    .foregroundColor(.accentColor)
            }
            .accessibilityIdentifier("OnboardingWidgetView_SkipButton")
            .accessibilityLabel("Skip widget setup")
            .padding(.bottom)
        }
        .padding()
        .onAppear {
            Task {
                await telemetry.logStepView(.completion)
                // Audit widget prompt shown
                await OnboardingWidgetSupport.markSuggestionShownAsync()
            }
        }
    }
}

#Preview {
    OnboardingWidgetView(
        onContinue: { print("Continue tapped") },
        telemetry: OnboardingTelemetryTracker()
    )
}

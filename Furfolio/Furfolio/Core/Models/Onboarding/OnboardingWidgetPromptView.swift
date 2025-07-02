
//
//  OnboardingWidgetPromptView.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

/**
 OnboardingWidgetPromptView
 --------------------------
 A SwiftUI view prompting users to enable the Furfolio home screen widget.

 - **Architecture**: MVVM-capable View, dependency-injectable `OnboardingTelemetryTracker` for analytics and audit.
 - **Concurrency & Async Logging**: Wraps telemetry and audit calls in async Tasks to avoid blocking.
 - **Audit/Analytics Ready**: Uses async methods from `OnboardingTelemetryTracker` and `OnboardingWidgetSupport` for logging and widget flow.
 - **Localization**: All user-facing text uses `LocalizedStringKey` or `NSLocalizedString`.
 - **Accessibility**: Provides identifiers, labels, and hints for VoiceOver.
 - **Preview/Testability**: Preview injects a real tracker and prints events for testing.
 */

import SwiftUI

struct OnboardingWidgetPromptView: View {
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

            Text(LocalizedStringKey("Add Furfolio Widget"))
                .font(.title.bold())
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text(LocalizedStringKey("Enable the home screen widget to quickly view today’s schedule, recent clients, or revenue summaries."))
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
                Text(LocalizedStringKey("Enable Widget"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            .accessibilityIdentifier("OnboardingWidgetPrompt_EnableButton")

            Button {
                Task {
                    await telemetry.logAction("skip_widget", step: .completion)
                    await OnboardingWidgetSupport.markSuggestionShownAsync()
                    await MainActor.run {
                        onContinue()
                    }
                }
            } label: {
                Text(LocalizedStringKey("Maybe Later"))
                    .foregroundColor(.accentColor)
            }
            .accessibilityIdentifier("OnboardingWidgetPrompt_SkipButton")
            .accessibilityLabel(LocalizedStringKey("Skip widget setup"))
            .padding(.bottom)
        }
        .padding()
        .onAppear {
            Task {
                await telemetry.logStepView(.completion)
                // Audit the prompt view appearance
                await OnboardingWidgetSupport.markSuggestionShownAsync()
                _ = await OnboardingWidgetSupport.recentAuditEntries(limit: 1)
            }
        }
    }
}

#Preview {
    OnboardingWidgetPromptView(
        onContinue: { print("Continue tapped") },
        telemetry: OnboardingTelemetryTracker()
    )
}

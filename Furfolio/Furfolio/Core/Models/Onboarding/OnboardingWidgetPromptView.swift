//
//  OnboardingWidgetPromptView.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

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

            Text("Add Furfolio Widget")
                .font(.title.bold())
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text("Enable the home screen widget to quickly view today’s schedule, recent clients, or revenue summaries.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            Button {
                telemetry.logAction("enable_widget", step: .completion)
                OnboardingWidgetSupport.markSuggestionShown()
                OnboardingWidgetSupport.openWidgetConfiguration()
                onContinue()
            } label: {
                Text("Enable Widget")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)

            Button {
                telemetry.logAction("skip_widget", step: .completion)
                OnboardingWidgetSupport.markSuggestionShown()
                onContinue()
            } label: {
                Text("Maybe Later")
                    .foregroundColor(.accentColor)
            }
            .accessibilityLabel("Skip widget setup")
            .padding(.bottom)
        }
        .padding()
        .onAppear {
            telemetry.logStepView(.completion)
        }
    }
}

#Preview {
    OnboardingWidgetPromptView(
        onContinue: { print("Continue tapped") },
        telemetry: OnboardingTelemetryTracker()
    )
}

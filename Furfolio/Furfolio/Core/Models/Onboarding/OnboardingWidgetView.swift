//
//  OnboardingWidgetView.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

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
                Text("Skip for Now")
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
    OnboardingWidgetView(
        onContinue: { print("Continue tapped") },
        telemetry: OnboardingTelemetryTracker()
    )
}

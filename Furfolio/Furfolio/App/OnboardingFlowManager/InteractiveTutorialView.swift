//
//  InteractiveTutorialView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

/// Represents a single tutorial step.
struct TutorialStep: Identifiable {
    let id = UUID()
    let imageName: String
    let titleKey: LocalizedStringKey
    let descriptionKey: LocalizedStringKey
}

/// The interactive, swipeable tutorial for onboarding new users.
struct InteractiveTutorialView: View {
    private static let tutorialSteps: [TutorialStep] = [
        .init(imageName: "pawprint.fill",
              titleKey: "Welcome to Furfolio!",
              descriptionKey: "Easily manage all your pet clients, appointments, and business metrics in one place."),
        .init(imageName: "calendar.badge.clock",
              titleKey: "Schedule Appointments",
              descriptionKey: "Quickly add, view, and reschedule grooming appointments with a drag-and-drop calendar."),
        .init(imageName: "person.2.badge.gearshape",
              titleKey: "Owner & Pet Profiles",
              descriptionKey: "Store detailed records, grooming history, and notes for every pet and owner."),
        .init(imageName: "chart.bar.doc.horizontal",
              titleKey: "Business Insights",
              descriptionKey: "Track revenue, popular services, customer retention, and more with visual dashboards.")
    ]

    @State private var currentStep = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicators
            HStack(spacing: 8) {
                ForEach(Self.tutorialSteps.indices, id: \.self) { idx in
                    Capsule()
                        .fill(idx == currentStep ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: idx == currentStep ? 24 : 8, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                        .accessibilityLabel(idx == currentStep ? "Current step" : "Step")
                }
            }
            .padding(.top, 24)

            Spacer()

            // Tutorial content
            TabView(selection: $currentStep) {
                ForEach(Array(Self.tutorialSteps.enumerated()), id: \.1.id) { index, step in
                    VStack(spacing: 28) {
                        Image(systemName: step.imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 90)
                            .foregroundColor(.accentColor)
                            .padding(.top, 20)
                            .accessibilityLabel(Text(step.titleKey))

                        Text(step.titleKey)
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Text(step.descriptionKey)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Spacer()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 380)

            Spacer()

            // Navigation controls
            HStack {
                if currentStep > 0 {
                    Button(action: { withAnimation { currentStep -= 1 } }) {
                        Text("Back")
                    }
                    .padding(.horizontal, 24)
                    .accessibilityLabel("Back to previous step")
                }

                Spacer()

                if currentStep < Self.tutorialSteps.count - 1 {
                    Button(action: { withAnimation { currentStep += 1 } }) {
                        Text("Next")
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, 24)
                    .accessibilityLabel("Next step")
                } else {
                    Button(action: dismiss.callAsFunction) {
                        Text("Get Started")
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, 24)
                    .accessibilityLabel("Finish tutorial and start app")
                }
            }
            .padding(.bottom, 28)
        }
        .padding(.horizontal, 16)
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

// MARK: - Preview

#Preview {
    InteractiveTutorialView()
}

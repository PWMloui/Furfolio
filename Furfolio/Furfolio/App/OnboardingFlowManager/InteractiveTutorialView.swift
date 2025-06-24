//
//  InteractiveTutorialView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

/// An interactive onboarding tutorial for new users of Furfolio.
/// This view provides a swipeable, accessible, and localizable tutorial experience,
/// guiding users through key features of the app. It includes progress indicators,
/// navigation controls with accessibility labels and hints, and is prepared for analytics tracking.
/// 
/// All user-facing strings are localized using `LocalizedStringKey`.
/// Design tokens such as `AppFonts` and `AppColors` should be integrated for consistent styling.
/// TODO: Integrate analytics hooks on step changes and tutorial completion for business insights.
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
              titleKey: LocalizedStringKey("Welcome to Furfolio!"),
              descriptionKey: LocalizedStringKey("Easily manage all your pet clients, appointments, and business metrics in one place.")),
        .init(imageName: "calendar.badge.clock",
              titleKey: LocalizedStringKey("Schedule Appointments"),
              descriptionKey: LocalizedStringKey("Quickly add, view, and reschedule grooming appointments with a drag-and-drop calendar.")),
        .init(imageName: "person.2.badge.gearshape",
              titleKey: LocalizedStringKey("Owner & Pet Profiles"),
              descriptionKey: LocalizedStringKey("Store detailed records, grooming history, and notes for every pet and owner.")),
        .init(imageName: "chart.bar.doc.horizontal",
              titleKey: LocalizedStringKey("Business Insights"),
              descriptionKey: LocalizedStringKey("Track revenue, popular services, customer retention, and more with visual dashboards."))
    ]

    @State private var currentStep = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicators
            HStack(spacing: 8) {
                ForEach(Self.tutorialSteps.indices, id: \.self) { idx in
                    Capsule()
                        .fill(idx == currentStep ? AppColors.accent : Color.gray.opacity(0.3)) // TODO: Replace Color.gray with AppColors.grayLight if available
                        .frame(width: idx == currentStep ? 24 : 8, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                        .accessibilityLabel(idx == currentStep ? NSLocalizedString("Current step", comment: "Accessibility label for current tutorial step") : NSLocalizedString("Step", comment: "Accessibility label for tutorial step"))
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
                            .foregroundColor(AppColors.accent) // TODO: Use design token for accent color
                            .padding(.top, 20)
                            .accessibilityLabel(Text(step.titleKey))

                        Text(step.titleKey)
                            .font(AppFonts.title2.bold()) // TODO: Define AppFonts.title2
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .accessibilityAddTraits(.isHeader)

                        Text(step.descriptionKey)
                            .font(AppFonts.body) // TODO: Define AppFonts.body
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
                    Button(action: {
                        withAnimation {
                            currentStep -= 1
                            // TODO: Analytics - log back navigation in tutorial with currentStep
                        }
                    }) {
                        Text(LocalizedStringKey("Back"))
                    }
                    .padding(.horizontal, 24)
                    .accessibilityLabel(Text("Back to previous step"))
                    .accessibilityHint(Text("Navigates to the previous tutorial step"))
                }

                Spacer()

                if currentStep < Self.tutorialSteps.count - 1 {
                    Button(action: {
                        withAnimation {
                            currentStep += 1
                            // TODO: Analytics - log next navigation in tutorial with currentStep
                        }
                    }) {
                        Text(LocalizedStringKey("Next"))
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, 24)
                    .accessibilityLabel(Text("Next step"))
                    .accessibilityHint(Text("Navigates to the next tutorial step"))
                } else {
                    Button(action: {
                        dismiss.callAsFunction()
                        // TODO: Analytics - log tutorial completion event
                    }) {
                        Text(LocalizedStringKey("Get Started"))
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, 24)
                    .accessibilityLabel(Text("Finish tutorial and start app"))
                    .accessibilityHint(Text("Completes the tutorial and opens the app"))
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
        .previewDisplayName("Light Mode")
}

#Preview {
    InteractiveTutorialView()
        .preferredColorScheme(.dark)
        .previewDisplayName("Dark Mode")
}

#Preview {
    InteractiveTutorialView()
        .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
        .previewDisplayName("Accessibility - Extra Large Text")
}

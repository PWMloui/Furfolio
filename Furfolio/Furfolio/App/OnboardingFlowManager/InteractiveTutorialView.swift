//
//  InteractiveTutorialView.swift
//  Furfolio
//
//  Enhanced: Fully tokenized, analytics/audit-ready, modular, previewable, and accessible.
//

import SwiftUI

// MARK: - Analytics/Audit Logger Protocol

public protocol TutorialAnalyticsLogger {
    func log(event: String, step: Int?)
}
public struct NullTutorialAnalyticsLogger: TutorialAnalyticsLogger {
    public init() {}
    public func log(event: String, step: Int?) {}
}

// MARK: - Tutorial Step

struct TutorialStep: Identifiable {
    let id = UUID()
    let imageName: String
    let titleKey: LocalizedStringKey
    let descriptionKey: LocalizedStringKey
}

// MARK: - InteractiveTutorialView

struct InteractiveTutorialView: View {
    // MARK: - Dependencies (Inject for test/preview)
    let analyticsLogger: TutorialAnalyticsLogger

    // MARK: - Design Tokens (with safe fallback)
    let accent: Color
    let secondary: Color
    let background: Color
    let grayLight: Color
    let titleFont: Font
    let bodyFont: Font
    let spacing: CGFloat
    let stepHeight: CGFloat
    let capsuleWidthActive: CGFloat
    let capsuleWidthInactive: CGFloat
    let capsuleHeight: CGFloat
    let cornerRadius: CGFloat

    // MARK: - Steps Data
    static let defaultSteps: [TutorialStep] = [
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
    let steps: [TutorialStep]

    // MARK: - State
    @State private var currentStep = 0
    @Environment(\.dismiss) private var dismiss

    // MARK: - Initializer (Dependency injection + tokenization)
    init(
        steps: [TutorialStep] = Self.defaultSteps,
        analyticsLogger: TutorialAnalyticsLogger = NullTutorialAnalyticsLogger(),
        accent: Color = AppColors.accent ?? .accentColor,
        secondary: Color = AppColors.secondary ?? .secondary,
        background: Color = AppColors.background ?? Color(.systemBackground),
        grayLight: Color = AppColors.grayLight ?? Color.gray.opacity(0.3),
        titleFont: Font = AppFonts.title2 ?? .title2.bold(),
        bodyFont: Font = AppFonts.body ?? .body,
        spacing: CGFloat = AppSpacing.xLarge ?? 28,
        stepHeight: CGFloat = AppSpacing.xxxLarge ?? 380,
        capsuleWidthActive: CGFloat = 24,
        capsuleWidthInactive: CGFloat = 8,
        capsuleHeight: CGFloat = 8,
        cornerRadius: CGFloat = AppRadius.medium ?? 16
    ) {
        self.steps = steps
        self.analyticsLogger = analyticsLogger
        self.accent = accent
        self.secondary = secondary
        self.background = background
        self.grayLight = grayLight
        self.titleFont = titleFont
        self.bodyFont = bodyFont
        self.spacing = spacing
        self.stepHeight = stepHeight
        self.capsuleWidthActive = capsuleWidthActive
        self.capsuleWidthInactive = capsuleWidthInactive
        self.capsuleHeight = capsuleHeight
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicators
            HStack(spacing: AppSpacing.xSmall ?? 8) {
                ForEach(steps.indices, id: \.self) { idx in
                    Capsule()
                        .fill(idx == currentStep ? accent : grayLight)
                        .frame(width: idx == currentStep ? capsuleWidthActive : capsuleWidthInactive, height: capsuleHeight)
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                        .accessibilityLabel(idx == currentStep
                            ? NSLocalizedString("Current step", comment: "Current tutorial step indicator")
                            : NSLocalizedString("Step", comment: "Tutorial step indicator"))
                }
            }
            .padding(.top, AppSpacing.xLarge ?? 24)

            Spacer()

            // Tutorial content
            TabView(selection: $currentStep) {
                ForEach(Array(steps.enumerated()), id: \.1.id) { index, step in
                    VStack(spacing: spacing) {
                        Image(systemName: step.imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(height: AppSpacing.xxxLarge ?? 90)
                            .foregroundColor(accent)
                            .padding(.top, AppSpacing.large ?? 20)
                            .accessibilityLabel(Text(step.titleKey))

                        Text(step.titleKey)
                            .font(titleFont)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .accessibilityAddTraits(.isHeader)

                        Text(step.descriptionKey)
                            .font(bodyFont)
                            .multilineTextAlignment(.center)
                            .foregroundColor(secondary)
                            .padding(.horizontal)

                        Spacer()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: stepHeight)

            Spacer()

            // Navigation controls
            HStack {
                if currentStep > 0 {
                    Button(action: {
                        withAnimation {
                            currentStep -= 1
                            analyticsLogger.log(event: "tutorial_back", step: currentStep)
                        }
                    }) {
                        Text(LocalizedStringKey("Back"))
                    }
                    .padding(.horizontal, AppSpacing.xLarge ?? 24)
                    .accessibilityLabel(Text("Back to previous step"))
                    .accessibilityHint(Text("Navigates to the previous tutorial step"))
                }

                Spacer()

                if currentStep < steps.count - 1 {
                    Button(action: {
                        withAnimation {
                            currentStep += 1
                            analyticsLogger.log(event: "tutorial_next", step: currentStep)
                        }
                    }) {
                        Text(LocalizedStringKey("Next"))
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, AppSpacing.xLarge ?? 24)
                    .accessibilityLabel(Text("Next step"))
                    .accessibilityHint(Text("Navigates to the next tutorial step"))
                } else {
                    Button(action: {
                        analyticsLogger.log(event: "tutorial_complete", step: currentStep)
                        dismiss()
                    }) {
                        Text(LocalizedStringKey("Get Started"))
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, AppSpacing.xLarge ?? 24)
                    .accessibilityLabel(Text("Finish tutorial and start app"))
                    .accessibilityHint(Text("Completes the tutorial and opens the app"))
                }
            }
            .padding(.bottom, AppSpacing.xLarge ?? 28)
        }
        .padding(.horizontal, AppSpacing.large ?? 16)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [background, AppColors.secondaryBackground ?? Color(.secondarySystemBackground)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .cornerRadius(cornerRadius)
        .accessibilityElement(children: .contain)
        .onAppear { analyticsLogger.log(event: "tutorial_start", step: 0) }
    }
}

// MARK: - Previews

struct InteractiveTutorialView_Previews: PreviewProvider {
    struct AnalyticsSpy: TutorialAnalyticsLogger {
        func log(event: String, step: Int?) {
            print("Analytics Event: \(event), step: \(step ?? -1)")
        }
    }

    static var previews: some View {
        Group {
            InteractiveTutorialView(analyticsLogger: AnalyticsSpy())
                .previewDisplayName("Light Mode")
            InteractiveTutorialView(analyticsLogger: AnalyticsSpy())
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
            InteractiveTutorialView(analyticsLogger: AnalyticsSpy())
                .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
                .previewDisplayName("Accessibility - Extra Large Text")
        }
    }
}

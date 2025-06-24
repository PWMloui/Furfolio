//
//   OnboardingCompletionView.swift
//  Furfolio
//
//  Created by mac on 6/21/25.
//

import SwiftUI

/// The final screen displayed at the end of the onboarding flow.
/// This view is fully accessible, supports localization, and is prepared for integration with business analytics and audit logging.
/// 
/// - Accessibility:
///   - The main title is marked as a header for assistive technologies.
///   - The "Get Started" button includes accessibility labels and hints.
/// 
/// - Localization:
///   - All user-facing strings are localized.
/// 
/// - Design Tokens:
///   - Fonts, colors, and other style elements use design tokens where available.
/// 
/// - Analytics:
///   - The "Get Started" action is a hook for business analytics and audit logs.
struct OnboardingCompletionView: View {
    let onGetStarted: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "checkmark.seal.fill")
                .resizable()
                .scaledToFit()
                .frame(height: 80)
                .foregroundColor(AppColors.accent) // Using design token for accent color
                .accessibilityLabel(LocalizedStringKey("Onboarding complete"))

            Text(LocalizedStringKey("You're all set!"))
                .font(AppFonts.titleBold) // Using design token for title bold font
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text(LocalizedStringKey("Start using Furfolio to grow and simplify your grooming business."))
                .font(AppFonts.body) // Using design token for body font
                .multilineTextAlignment(.center)
                .foregroundStyle(AppColors.secondary) // Using design token for secondary color

            Button(action: {
                // TODO: Call business analytics/audit log here before proceeding
                onGetStarted()
            }) {
                Text(LocalizedStringKey("Get Started"))
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 20)
            .accessibilityLabel(LocalizedStringKey("Get Started"))
            .accessibilityHint(LocalizedStringKey("Begin using the app and complete onboarding"))

            // Note: The padding and spacing values are currently hardcoded and should be replaced with design tokens in the future.
        }
        .padding()
        .accessibilityElement(children: .combine)
        .background(AppColors.background) // Using design token for background color
    }
}

struct OnboardingCompletionView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            OnboardingCompletionView(onGetStarted: {})
                .previewDisplayName("Light Mode")
                .environment(\.colorScheme, .light)

            OnboardingCompletionView(onGetStarted: {})
                .previewDisplayName("Dark Mode")
                .environment(\.colorScheme, .dark)

            OnboardingCompletionView(onGetStarted: {})
                .previewDisplayName("Accessibility Large Text")
                .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
        }
    }
}

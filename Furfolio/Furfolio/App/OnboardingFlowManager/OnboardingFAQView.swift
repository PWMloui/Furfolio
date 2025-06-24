//
//  OnboardingFAQView.swift
//  Furfolio

import SwiftUI

/// Onboarding FAQ - fully accessible, localizable, and business-audit ready.
/// This view presents frequently asked questions during onboarding with
/// enhanced accessibility traits and design token usage.
struct FAQItem: Identifiable {
    let id = UUID()
    let question: LocalizedStringKey
    let answer: LocalizedStringKey

    static var onboardingFAQs: [FAQItem] = [
        FAQItem(
            question: LocalizedStringKey("What is Furfolio?"),
            answer: LocalizedStringKey("Furfolio is an all-in-one business tool for dog groomers. Manage clients, appointments, pet records, and business insights, all in one secure app.")
        ),
        FAQItem(
            question: LocalizedStringKey("Is my data safe and private?"),
            answer: LocalizedStringKey("Yes! Furfolio keeps your data stored locally on your device and uses iOS security features. No information is shared unless you choose to export it.")
        ),
        FAQItem(
            question: LocalizedStringKey("Can I use Furfolio offline?"),
            answer: LocalizedStringKey("Absolutely. Furfolio is designed to work offline, so you can manage your business anywhere, even without an internet connection.")
        ),
        FAQItem(
            question: LocalizedStringKey("How do I add pets and owners?"),
            answer: LocalizedStringKey("Tap the '+' button in the dashboard or owners screen to quickly add new clients and their pets. You can enter names, contact details, pet info, and more.")
        ),
        FAQItem(
            question: LocalizedStringKey("What support is available?"),
            answer: LocalizedStringKey("You’ll find tips throughout the app. For further help, visit our website or contact support from the app’s settings page.")
        )
    ]
}

/// Onboarding FAQ View – presented as part of the onboarding flow.
struct OnboardingFAQView: View {
    @State private var expandedID: UUID?

    var body: some View {
        NavigationView {
            List {
                ForEach(FAQItem.onboardingFAQs) { item in
                    Section {
                        FAQDisclosureGroup(
                            item: item,
                            isExpanded: expandedID == item.id
                        ) {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                expandedID = expandedID == item.id ? nil : item.id
                                // TODO: Add audit logging/analytics for FAQ toggle here
                            }
                        }
                    } header: {
                        Text(LocalizedStringKey("FAQ Section"))
                            .font(AppFonts.header) // TODO: Define AppFonts.header
                            .foregroundColor(AppColors.primary) // TODO: Define AppColors.primary
                            .accessibilityAddTraits(.isHeader)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(LocalizedStringKey("FAQ"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// Disclosure group for each FAQ item
private struct FAQDisclosureGroup: View {
    let item: FAQItem
    let isExpanded: Bool
    let toggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                toggle()
                // TODO: Add audit logging/analytics for FAQ toggle here
            }) {
                HStack {
                    Text(item.question)
                        .font(AppFonts.headline) // TODO: Define AppFonts.headline
                        .foregroundColor(AppColors.primary) // TODO: Define AppColors.primary
                        .multilineTextAlignment(.leading)
                        .accessibilityAddTraits(.isHeader)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(AppColors.accent) // TODO: Define AppColors.accent
                        .imageScale(.small)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(item.question)
            .accessibilityHint(isExpanded ? NSLocalizedString("Tap to collapse the answer.", comment: "Accessibility hint for collapsing FAQ answer") : NSLocalizedString("Tap to expand the answer.", comment: "Accessibility hint for expanding FAQ answer"))

            if isExpanded {
                Text(item.answer)
                    .font(AppFonts.body) // TODO: Define AppFonts.body
                    .foregroundColor(AppColors.secondary) // TODO: Define AppColors.secondary
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    Group {
        OnboardingFAQView()
            .previewDisplayName("Light Mode")
            .environment(\.colorScheme, .light)
        OnboardingFAQView()
            .previewDisplayName("Dark Mode")
            .environment(\.colorScheme, .dark)
        OnboardingFAQView()
            .previewDisplayName("Large Text")
            .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
    }
}

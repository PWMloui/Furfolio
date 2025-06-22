//
//  OnboardingFAQView.swift
//  Furfolio

import SwiftUI

/// FAQ entry model
struct FAQItem: Identifiable {
    let id = UUID()
    let question: LocalizedStringKey
    let answer: LocalizedStringKey

    static var onboardingFAQs: [FAQItem] = [
        FAQItem(
            question: "What is Furfolio?",
            answer: "Furfolio is an all-in-one business tool for dog groomers. Manage clients, appointments, pet records, and business insights, all in one secure app."
        ),
        FAQItem(
            question: "Is my data safe and private?",
            answer: "Yes! Furfolio keeps your data stored locally on your device and uses iOS security features. No information is shared unless you choose to export it."
        ),
        FAQItem(
            question: "Can I use Furfolio offline?",
            answer: "Absolutely. Furfolio is designed to work offline, so you can manage your business anywhere, even without an internet connection."
        ),
        FAQItem(
            question: "How do I add pets and owners?",
            answer: "Tap the '+' button in the dashboard or owners screen to quickly add new clients and their pets. You can enter names, contact details, pet info, and more."
        ),
        FAQItem(
            question: "What support is available?",
            answer: "You’ll find tips throughout the app. For further help, visit our website or contact support from the app’s settings page."
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
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("FAQ")
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
            Button(action: toggle) {
                HStack {
                    Text(item.question)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.accentColor)
                        .imageScale(.small)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(item.question)
            .accessibilityHint(isExpanded ? "Tap to collapse the answer." : "Tap to expand the answer.")

            if isExpanded {
                Text(item.answer)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    OnboardingFAQView()
}

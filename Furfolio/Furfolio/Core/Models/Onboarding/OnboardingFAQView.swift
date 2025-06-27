//
//  OnboardingFAQView.swift
//  Furfolio
//
//  Enhanced: Fully tokenized, audit/analytics-ready, accessible, modular, preview/testable.
//

import SwiftUI

// MARK: - Centralized Logging Protocols

public protocol AnalyticsServiceProtocol {
    func log(event: String, parameters: [String: Any]?)
    func screenView(_ name: String)
}

public protocol AuditLoggerProtocol {
    func record(_ message: String, metadata: [String: String]?)
    func recordSensitive(_ action: String, userId: String)
}

// MARK: - FAQ Data

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

// MARK: - OnboardingFAQView

struct OnboardingFAQView: View {
    @State private var expandedID: UUID?
    private let analytics: AnalyticsServiceProtocol
    private let audit: AuditLoggerProtocol

    // Tokens
    private let sectionFont: Font
    private let sectionColor: Color
    private let listBg: Color
    private let spacing: CGFloat

    // Init (inject logger/tokens for preview/testing)
    init(
        analytics: AnalyticsServiceProtocol = AnalyticsService.shared,
        audit: AuditLoggerProtocol = AuditLogger.shared,
        sectionFont: Font = AppFonts.header ?? .title2.bold(),
        sectionColor: Color = AppColors.primary ?? .primary,
        listBg: Color = AppColors.background ?? Color(UIColor.systemGroupedBackground),
        spacing: CGFloat = AppSpacing.medium ?? 16
    ) {
        self.analytics = analytics
        self.audit = audit
        self.sectionFont = sectionFont
        self.sectionColor = sectionColor
        self.listBg = listBg
        self.spacing = spacing
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(FAQItem.onboardingFAQs) { item in
                        FAQDisclosureGroup(
                            item: item,
                            isExpanded: expandedID == item.id,
                            onToggle: { expanded in
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    expandedID = expanded ? item.id : nil
                                    let question = String(localized: item.question)
                                    analytics.log(
                                        event: expanded ? "faq_expand" : "faq_collapse",
                                        parameters: ["question": question]
                                    )
                                    audit.record(
                                        "User \(expanded ? "expanded" : "collapsed") FAQ: \(question)",
                                        metadata: nil
                                    )
                                }
                            }
                        )
                    }
                } header: {
                    Text("FAQ Section")
                        .font(sectionFont)
                        .foregroundColor(sectionColor)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityLabel(Text(NSLocalizedString("Frequently Asked Questions", comment: "FAQ section header")))
                }
            }
            .listStyle(.insetGrouped)
            .background(listBg)
            .navigationTitle(Text("FAQ"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Disclosure Group for Each FAQ

private struct FAQDisclosureGroup: View {
    let item: FAQItem
    let isExpanded: Bool
    let onToggle: (Bool) -> Void

    // Tokens
    private let qFont: Font
    private let aFont: Font
    private let qColor: Color
    private let aColor: Color
    private let iconColor: Color
    private let verticalPad: CGFloat

    init(
        item: FAQItem,
        isExpanded: Bool,
        onToggle: @escaping (Bool) -> Void,
        qFont: Font = AppFonts.headline ?? .headline,
        aFont: Font = AppFonts.body ?? .body,
        qColor: Color = AppColors.primary ?? .primary,
        aColor: Color = AppColors.secondary ?? .secondary,
        iconColor: Color = AppColors.accent ?? .accentColor,
        verticalPad: CGFloat = AppSpacing.small ?? 8
    ) {
        self.item = item
        self.isExpanded = isExpanded
        self.onToggle = onToggle
        self.qFont = qFont
        self.aFont = aFont
        self.qColor = qColor
        self.aColor = aColor
        self.iconColor = iconColor
        self.verticalPad = verticalPad
    }

    var body: some View {
        VStack(alignment: .leading, spacing: verticalPad) {
            Button(action: { onToggle(!isExpanded) }) {
                HStack {
                    Text(item.question)
                        .font(qFont)
                        .foregroundColor(qColor)
                        .multilineTextAlignment(.leading)
                        .accessibilityAddTraits(.isHeader)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(iconColor)
                        .imageScale(.small)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(item.question)
            .accessibilityHint(isExpanded
                ? NSLocalizedString("Tap to collapse the answer.", comment: "Accessibility hint for collapsing FAQ answer")
                : NSLocalizedString("Tap to expand the answer.", comment: "Accessibility hint for expanding FAQ answer")
            )

            if isExpanded {
                Text(item.answer)
                    .font(aFont)
                    .foregroundColor(aColor)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .padding(.top, 4)
                    .accessibilityLabel(item.answer)
            }
        }
        .padding(.vertical, verticalPad)
    }
}

// MARK: - Preview

#Preview {
    struct MockAnalytics: AnalyticsServiceProtocol {
        func log(event: String, parameters: [String : Any]?) {
            print("[Analytics] \(event) -> \(parameters ?? [:])")
        }
        func screenView(_ name: String) {}
    }

    struct MockAudit: AuditLoggerProtocol {
        func record(_ message: String, metadata: [String : String]?) {
            print("[Audit] \(message)")
        }
        func recordSensitive(_ action: String, userId: String) {}
    }

    return Group {
        OnboardingFAQView(analytics: MockAnalytics(), audit: MockAudit())
            .previewDisplayName("Light Mode")
            .environment(\.colorScheme, .light)

        OnboardingFAQView(analytics: MockAnalytics(), audit: MockAudit())
            .previewDisplayName("Dark Mode")
            .environment(\.colorScheme, .dark)

        OnboardingFAQView(analytics: MockAnalytics(), audit: MockAudit())
            .previewDisplayName("Accessibility Large Text")
            .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
    }
}

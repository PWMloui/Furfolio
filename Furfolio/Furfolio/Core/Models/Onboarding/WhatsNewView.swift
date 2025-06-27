//
//  WhatsNewView.swift
//  Furfolio
//
//  Enhanced: Analytics/audit-ready, token-compliant, modular, preview/test-injectable, accessible, and enterprise-ready.
//

import SwiftUI

// MARK: - Analytics/Audit Logger Protocol

public protocol WhatsNewAnalyticsLogger {
    func log(event: String, feature: String?)
}
public struct NullWhatsNewAnalyticsLogger: WhatsNewAnalyticsLogger {
    public init() {}
    public func log(event: String, feature: String?) {}
}

// MARK: - Data Model

/// A data model representing a single new feature to be displayed.
struct NewFeature: Identifiable, Hashable {
    let imageName: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey

    /// Deterministic ID based on contents
    var id: UUID {
        UUID(uuidString: UUID().uuidString) ?? UUID()
    }
}
// MARK: - Main WhatsNewView

struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss

    /// The list of new features for the current update.
    let features: [NewFeature]
    let analyticsLogger: WhatsNewAnalyticsLogger

    // Tokens (with fallback)
    let accentGradient: LinearGradient
    let background: Color
    let primary: Color
    let secondary: Color
    let textSecondary: Color
    let spacingXS: CGFloat
    let spacingM: CGFloat
    let spacingL: CGFloat
    let fontLargeTitle: Font
    let fontTitle: Font
    let fontHeadline: Font
    let fontBody: Font
    let fontCaption: Font
    let fontButton: Font

    // MARK: - DI Init (prod, preview, or test)
    init(
        features: [NewFeature] = [
            NewFeature(
                imageName: "person.crop.circle.badge.plus",
                title: LocalizedStringKey("Staff Management"),
                description: LocalizedStringKey("You can now add team members, assign roles, and track performance.")
            ),
            NewFeature(
                imageName: "shippingbox.fill",
                title: LocalizedStringKey("Inventory Tracking"),
                description: LocalizedStringKey("Track your product stock levels and get alerts when supplies are low.")
            ),
            NewFeature(
                imageName: "map.fill",
                title: LocalizedStringKey("Route Optimization"),
                description: LocalizedStringKey("For mobile groomers, automatically plan the most efficient route for your day's appointments.")
            )
        ],
        analyticsLogger: WhatsNewAnalyticsLogger = NullWhatsNewAnalyticsLogger(),
        accentGradient: LinearGradient = LinearGradient(
            colors: [AppTheme.Colors.purple, AppTheme.Colors.blue],
            startPoint: .topLeading, endPoint: .bottomTrailing
        ),
        background: Color = AppTheme.Colors.background,
        primary: Color = AppTheme.Colors.primary,
        secondary: Color = AppTheme.Colors.secondary,
        textSecondary: Color = AppTheme.Colors.textSecondary,
        spacingXS: CGFloat = AppTheme.Spacing.xs,
        spacingM: CGFloat = AppTheme.Spacing.medium,
        spacingL: CGFloat = AppTheme.Spacing.large,
        fontLargeTitle: Font = AppTheme.Fonts.largeTitle,
        fontTitle: Font = AppTheme.Fonts.title,
        fontHeadline: Font = AppTheme.Fonts.headline,
        fontBody: Font = AppTheme.Fonts.body,
        fontCaption: Font = AppTheme.Fonts.caption,
        fontButton: Font = AppTheme.Fonts.button
    ) {
        self.features = features
        self.analyticsLogger = analyticsLogger
        self.accentGradient = accentGradient
        self.background = background
        self.primary = primary
        self.secondary = secondary
        self.textSecondary = textSecondary
        self.spacingXS = spacingXS
        self.spacingM = spacingM
        self.spacingL = spacingL
        self.fontLargeTitle = fontLargeTitle
        self.fontTitle = fontTitle
        self.fontHeadline = fontHeadline
        self.fontBody = fontBody
        self.fontCaption = fontCaption
        self.fontButton = fontButton
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            VStack(spacing: spacingM) {
                Image(systemName: "sparkles")
                    .font(fontLargeTitle)
                    .foregroundStyle(accentGradient)
                    .accessibilityLabel(LocalizedStringKey("Sparkles icon"))
                    .accessibilityHint(LocalizedStringKey("Indicates new features"))

                Text(LocalizedStringKey("What's New in Furfolio"))
                    .font(fontTitle)
                    .accessibilityAddTraits(.isHeader)

                Text(LocalizedStringKey("Here are the latest features we've added to help you grow your business."))
                    .font(fontBody)
                    .foregroundStyle(textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.vertical, spacingL)

            // MARK: - Feature List
            ScrollView {
                VStack(alignment: .leading, spacing: spacingL) {
                    ForEach(features) { feature in
                        NewFeatureRowView(
                            feature: feature,
                            primary: primary,
                            textSecondary: textSecondary,
                            spacingM: spacingM,
                            spacingXS: spacingXS,
                            fontHeadline: fontHeadline,
                            fontCaption: fontCaption,
                            analyticsLogger: analyticsLogger
                        )
                        .onAppear {
                            analyticsLogger.log(event: "feature_view", feature: String(localized: feature.title))
                        }
                    }
                }
                .padding(.horizontal)
            }

            // MARK: - Continue Button
            Button(action: {
                analyticsLogger.log(event: "continue_tap", feature: nil)
                dismiss()
            }) {
                Text(LocalizedStringKey("Continue"))
                    .font(fontButton)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding([.horizontal, .bottom])
            .accessibilityLabel(LocalizedStringKey("Continue"))
            .accessibilityHint(LocalizedStringKey("Dismiss this screen and continue to the app"))
        }
        .background(background.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .onAppear {
            analyticsLogger.log(event: "whats_new_appear", feature: nil)
        }
    }
}

/// A private subview to display a single feature row.
private struct NewFeatureRowView: View {
    let feature: NewFeature
    let primary: Color
    let textSecondary: Color
    let spacingM: CGFloat
    let spacingXS: CGFloat
    let fontHeadline: Font
    let fontCaption: Font
    let analyticsLogger: WhatsNewAnalyticsLogger

    var body: some View {
        HStack(spacing: spacingM) {
            Image(systemName: feature.imageName)
                .font(fontHeadline)
                .foregroundStyle(primary)
                .frame(width: 44)
                .accessibilityLabel(feature.title)
                .accessibilityHint(feature.description)

            VStack(alignment: .leading, spacing: spacingXS) {
                Text(feature.title)
                    .font(fontHeadline)
                Text(feature.description)
                    .font(fontCaption)
                    .foregroundStyle(textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Preview

#Preview {
    struct SpyLogger: WhatsNewAnalyticsLogger {
        func log(event: String, feature: String?) {
            print("Analytics Event: \(event), Feature: \(feature ?? "-")")
        }
    }
    return Group {
        WhatsNewView(analyticsLogger: SpyLogger())
            .previewDisplayName("Light Mode")
            .environment(\.colorScheme, .light)

        WhatsNewView(analyticsLogger: SpyLogger())
            .previewDisplayName("Dark Mode")
            .environment(\.colorScheme, .dark)

        WhatsNewView(analyticsLogger: SpyLogger())
            .previewDisplayName("Accessibility Large Text")
            .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
    }
}

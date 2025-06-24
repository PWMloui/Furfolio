//
//  WhatsNewView.swift
//  Furfolio
//
//  Created by mac on 6/21/25.
//

import SwiftUI

/// A data model representing a single new feature to be displayed.
struct NewFeature: Identifiable {
    let id = UUID()
    let imageName: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey
}

/// A view that is presented once after an app update to highlight new features.
/// It is designed to be shown as a sheet or full-screen cover.
struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss

    /// The list of new features for the current update. This would typically be populated
    /// from a remote config or a local JSON file to be easily updatable.
    let features: [NewFeature] = [
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
    ]

    var body: some View {
        VStack(spacing: AppTheme.Spacing.none) {
            // MARK: - Header
            VStack(spacing: AppTheme.Spacing.medium) {
                Image(systemName: "sparkles")
                    .font(AppTheme.Fonts.largeTitle) // TODO: Confirm largeTitle matches 48pt bold
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.Colors.purple, AppTheme.Colors.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .accessibilityLabel(LocalizedStringKey("Sparkles icon"))
                    .accessibilityHint(LocalizedStringKey("Indicates new features"))

                Text(LocalizedStringKey("What's New in Furfolio"))
                    .font(AppTheme.Fonts.title)
                    .accessibilityAddTraits(.isHeader)

                Text(LocalizedStringKey("Here are the latest features we've added to help you grow your business."))
                    .font(AppTheme.Fonts.body)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.vertical, AppTheme.Spacing.large)

            // MARK: - Feature List
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.large) {
                    ForEach(features) { feature in
                        NewFeatureRowView(feature: feature)
                    }
                }
                .padding()
            }

            // MARK: - Continue Button
            Button(action: {
                dismiss()
            }) {
                Text(LocalizedStringKey("Continue"))
                    .font(AppTheme.Fonts.button)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding([.horizontal, .bottom])
            .accessibilityLabel(LocalizedStringKey("Continue"))
            .accessibilityHint(LocalizedStringKey("Dismiss this screen and continue to the app"))
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
    }
}

/// A private subview to display a single feature row.
private struct NewFeatureRowView: View {
    let feature: NewFeature

    var body: some View {
        HStack(spacing: AppTheme.Spacing.medium) {
            Image(systemName: feature.imageName)
                .font(AppTheme.Fonts.title)
                .foregroundStyle(AppTheme.Colors.primary)
                .frame(width: 44)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text(feature.title)
                    .font(AppTheme.Fonts.headline)
                Text(feature.description)
                    .font(AppTheme.Fonts.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Preview
#Preview {
    Group {
        WhatsNewView()
            .previewDisplayName("Light Mode")
            .environment(\.colorScheme, .light)

        WhatsNewView()
            .previewDisplayName("Dark Mode")
            .environment(\.colorScheme, .dark)

        WhatsNewView()
            .previewDisplayName("Accessibility Large Text")
            .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
    }
}

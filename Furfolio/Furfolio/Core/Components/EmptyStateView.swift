//
//  EmptyStateView.swift
//  Furfolio
//
//  Updated for architectural unification and modern design system
//

import SwiftUI

// MARK: - EmptyStateView (Reusable, Tokenized, Accessible)

/// A reusable, adaptive empty state view for Furfolio’s owner-focused UX.
///
/// This view uses only modular tokens: AppColors, AppFonts, AppSpacing, BorderRadius, AppShadows,
/// ensuring architectural consistency and accessibility.
///
/// - Supports SF Symbols or asset images as icons.
/// - Customizable action button for onboarding and calls to action.
/// - Uses design system colors, fonts, and spacings.
/// - Ready for iPad, Mac, and all accessibility sizes.
struct EmptyStateView: View {
    /// SF Symbol name (preferred) or nil to use an asset image.
    var icon: String? = "pawprint.fill"
    /// Asset image name (optional, used if icon is nil).
    var assetName: String? = nil
    var title: String = "No Data Yet"
    var message: String = "There’s nothing here right now. Add something new to get started!"
    /// Optional button text (default: nil = no button shown).
    var actionTitle: String? = nil
    /// Optional action for button tap.
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: AppSpacing.medium) {
            Spacer()
            // Icon/image
            Group {
                if let icon = icon {
                    Image(systemName: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(height: AppSpacing.xxxLarge)
                        .foregroundColor(AppColors.accent)
                        .opacity(0.82)
                        .appShadow(AppShadows.card)
                        .accessibility(hidden: true)
                } else if let asset = assetName {
                    Image(asset)
                        .resizable()
                        .scaledToFit()
                        .frame(height: AppSpacing.xxxLarge)
                        .appShadow(AppShadows.card)
                        .accessibility(hidden: true)
                }
            }
            .padding(.bottom, AppSpacing.xSmall)
            
            // Title
            Text(title)
                .font(AppFonts.title2Bold)
                .foregroundColor(AppColors.primaryText)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("emptyStateTitle")
            
            // Message
            Text(message)
                .font(AppFonts.body)
                .foregroundColor(AppColors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.medium)
                .accessibilityIdentifier("emptyStateMessage")
            
            // Optional Action Button
            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .font(AppFonts.button)
                    .padding(.top, AppSpacing.small)
                    .accessibilityIdentifier("emptyStateActionButton")
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.background.ignoresSafeArea())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("emptyStateView")
    }
}

#Preview("Default") {
    EmptyStateView(
        icon: "calendar.badge.clock",
        title: "No Appointments",
        message: "You haven’t added any appointments yet. Tap the + to schedule your first grooming session.",
        actionTitle: "Add Appointment",
        action: { print("Tapped Add") }
    )
}

#Preview("Asset Image & Custom Button") {
    EmptyStateView(
        icon: nil,
        assetName: "furfolioDog",
        title: "No Dogs Yet",
        message: "Add your first dog profile to start tracking grooming history, health, and photos.",
        actionTitle: "Add Dog",
        action: { print("Tapped Add Dog") }
    )
}

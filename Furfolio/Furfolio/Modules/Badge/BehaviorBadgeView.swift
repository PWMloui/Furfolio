//
//  BehaviorBadgeView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

// MARK: - BehaviorBadgeView (Tokenized, Modular, Auditable Behavior Badge Display)

import SwiftUI

/// Displays a list of behavior and status badges for a Dog, Owner, or Appointment.
/// These views are modular, tokenized, and auditable components designed for displaying behavior and status badges.
/// Designed to support accessibility, localization, and UI design system integration.
/// Pass in the relevant badges and the view renders icons with tooltips.
struct BehaviorBadgeView: View {
    let badges: [Badge]
    var showLabels: Bool = false // Show icon only, or icon + label

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(badges) { badge in
                    BadgeItemView(badge: badge, showLabel: showLabels)
                }
            }
            .padding(.vertical, 6)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Behavior and status badges")
        }
    }
}

private struct BadgeItemView: View {
    let badge: Badge
    let showLabel: Bool

    @State private var showInfo: Bool = false

    /// Modular, tokenized, and auditable badge item view for displaying individual behavior/status badges.
    /// Designed with accessibility, localization, and UI design system tokens for fonts and colors.
    var body: some View {
        VStack(spacing: 6) {
            Button(action: { withAnimation { showInfo.toggle() } }) {
                Text(badge.type.icon)
                    // Use design token for large icon font
                    .font(AppFonts.iconLarge)
                    .accessibilityLabel(badge.type.label)
                    .accessibilityHint(badge.type.description)
                    // Accessibility improvement: add isButton trait
                    .accessibilityAddTraits(.isButton)
                    // Accessibility improvement: add identifier for UI testing
                    .accessibilityIdentifier("badge-\(badge.type.label)")
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            // Replace hardcoded color with design token
                            .fill(AppColors.backgroundSecondary)
                            // Replace shadow color with design token, conditional on showInfo state
                            .shadow(color: showInfo ? AppColors.primary.opacity(0.25) : .clear, radius: 4)
                    )
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showInfo) {
                VStack(spacing: 10) {
                    Text(badge.type.icon)
                        // Use design token for large title font
                        .font(AppFonts.title1)
                    Text(badge.type.label)
                        // Use design token for headline font
                        .font(AppFonts.headline)
                    Text(badge.type.description)
                        // Use design token for subheadline font
                        .font(AppFonts.subheadline)
                        .multilineTextAlignment(.center)
                }
                .padding(16)
                .frame(width: 200)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        // Replace hardcoded background color with design token
                        .fill(AppColors.background)
                        .shadow(radius: 5)
                )
            }

            if showLabel {
                Text(badge.type.label)
                    // Use design token for caption font
                    .font(AppFonts.caption)
                    // Replace hardcoded secondary foreground color with design token
                    .foregroundColor(AppColors.secondaryText)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Preview

// Demo/business/tokenized preview for BehaviorBadgeView
#Preview {
    BehaviorBadgeView(
        badges: [
            Badge(type: .behaviorGood),
            Badge(type: .behaviorChallenging),
            Badge(type: .birthday),
            Badge(type: .retentionRisk),
            Badge(type: .topSpender)
        ],
        showLabels: true
    )
    .padding()
    // Replace hardcoded background color with design token
    .background(AppColors.backgroundSecondary)
}

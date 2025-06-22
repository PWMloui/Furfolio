//
//  LoyaltyTagView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

// MARK: - LoyaltyTagView (Tokenized, Modular, Auditable Loyalty Badge View)

import SwiftUI

/// A modular, tokenized, and auditable view for displaying loyalty badges based on a client's visit and spending history.
/// This view uses design tokens for colors, fonts, spacing, and shadows to ensure consistency and maintainability.
/// Customize thresholds and tags as needed.
struct LoyaltyTagView: View {
    /// Number of completed visits
    let visitCount: Int
    /// Total spent by this owner (optional)
    var totalSpent: Double? = nil
    /// Is this a top spender?
    var isTopSpender: Bool = false
    /// Is the client enrolled in the loyalty program?
    var isLoyalty: Bool = false

    /// Threshold constants for tags
    private let loyaltyThreshold = 5
    private let vipThreshold = 10
    private let newClientThreshold = 2

    var body: some View {
        HStack(spacing: 10) {
            if isLoyalty || visitCount >= loyaltyThreshold {
                TagLabel(text: "Loyalty Star", icon: "star.fill", color: AppColors.loyalty)
                    .accessibilityLabel("Loyalty Star Tag")
                    // Accessibility role: static text representing a loyalty badge
                    .accessibilityAddTraits(.isStaticText)
            }
            if visitCount >= vipThreshold {
                TagLabel(text: "VIP", icon: "crown.fill", color: AppColors.vip)
                    .accessibilityLabel("VIP Client Tag")
                    // Accessibility role: static text representing VIP status
                    .accessibilityAddTraits(.isStaticText)
            }
            if isTopSpender {
                TagLabel(text: "Top Spender", icon: "dollarsign.circle.fill", color: AppColors.topSpender)
                    .accessibilityLabel("Top Spender Tag")
                    // Accessibility role: static text representing top spender badge
                    .accessibilityAddTraits(.isStaticText)
            }
            if visitCount < newClientThreshold {
                TagLabel(text: "New Client", icon: "sparkles", color: AppColors.newClient)
                    .accessibilityLabel("New Client Tag")
                    // Accessibility role: static text representing new client badge
                    .accessibilityAddTraits(.isStaticText)
            }
            // Additional custom tags can be added here.
        }
        .padding(.vertical, 6)
        // Group all tags as a single accessibility element for better screen reader experience
        .accessibilityElement(children: .contain)
    }

    /// A reusable tag label view
    struct TagLabel: View {
        var text: String
        var icon: String
        var color: Color

        var body: some View {
            Label {
                Text(text)
                    // Use app's caption font token for consistency
                    .font(AppFonts.caption)
                    // Use app's primary text color token for maintainability
                    .foregroundColor(AppColors.textPrimary)
            } icon: {
                Image(systemName: icon)
                    // Use the passed color token for icon color
                    .foregroundColor(color)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 14)
            // Use app's secondary background color token for consistent backgrounds
            .background(AppColors.backgroundSecondary)
            // Use app's medium border radius token for consistent corner rounding
            .cornerRadius(BorderRadius.medium)
            // Use app's small shadow token with opacity for consistent shadows
            .shadow(color: color.opacity(0.3), radius: AppShadows.small.radius, x: 0, y: AppShadows.small.y)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        LoyaltyTagView(visitCount: 12, totalSpent: 720, isTopSpender: true, isLoyalty: true)
        LoyaltyTagView(visitCount: 5)
        LoyaltyTagView(visitCount: 1)
        LoyaltyTagView(visitCount: 8, totalSpent: 200, isLoyalty: false, isTopSpender: false)
    }
    .padding()
    // Use app's background color token for consistent background styling
    .background(AppColors.background)
}

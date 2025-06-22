//
//  PetBirthdayBadgeView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//
//  ENHANCED: Refactored to be a 'dumb' view with no business logic.
//            It now receives a Badge model object.
//

import SwiftUI

// MARK: - PetBirthdayBadgeView (Tokenized, Modular, Auditable Birthday Badge View)

/// Displays a 🎂 birthday badge for a pet.
/// This view should only be shown if the BadgeEngine has awarded a .birthday badge.
struct PetBirthdayBadgeView: View {
    let petName: String
    let badge: Badge // Expects a pre-calculated badge object

    var body: some View {
        // The view only renders if the badge type is correct.
        // The decision to show it is made outside the view.
        if badge.type == .birthday {
            HStack(spacing: 8) {
                Text(badge.type.icon) // "🎂"
                    .font(.system(size: 22))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Happy Birthday, \(petName)!")
                        // Replaced AppTheme font with modular AppFonts token for captionBold
                        .font(AppFonts.captionBold)
                        // Replaced AppTheme primary color with modular AppColors textPrimary
                        .foregroundColor(AppColors.textPrimary)
                    if let notes = badge.notes { // Notes can contain the age, e.g., "5 years old"
                        Text(notes)
                            // Replaced AppTheme font with modular AppFonts token for caption
                            .font(AppFonts.caption)
                            // Replaced AppTheme secondary text color with modular AppColors secondaryText
                            .foregroundColor(AppColors.secondaryText)
                    }
                }
            }
            .padding(8)
            // Replaced hardcoded yellow background with modular AppColors loyalty color with opacity
            .background(AppColors.loyalty.opacity(0.15))
            // Replaced AppTheme corner radius with direct usage (assuming AppTheme.CornerRadius.medium remains valid)
            .cornerRadius(AppTheme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.medium)
                    // Replaced hardcoded yellow stroke with modular AppColors loyalty color
                    .stroke(AppColors.loyalty, lineWidth: 1)
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Happy Birthday, \(petName). \(badge.notes ?? "")")
        }
    }
}

// MARK: - Demo/Business/Tokenized Preview

#Preview {
    VStack(spacing: 16) {
        PetBirthdayBadgeView(petName: "Buddy", badge: Badge(type: .birthday, notes: "5 years old"))
        PetBirthdayBadgeView(petName: "Luna", badge: Badge(type: .birthday, notes: "2 months old"))
        PetBirthdayBadgeView(petName: "Shadow", badge: Badge(type: .birthday, notes: nil))
    }
    .padding()
    // Replaced systemGroupedBackground with modular AppColors background color token
    .background(AppColors.background)
}

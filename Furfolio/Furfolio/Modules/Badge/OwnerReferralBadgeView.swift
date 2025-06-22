//
// MARK: - OwnerReferralBadgeView (Tokenized, Modular, Auditable Referral Badge UI)
//
//  OwnerReferralBadgeView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//
//  A modular, tokenized, and auditable referral badge UI component designed to support business workflows,
//  accessibility, localization, and seamless integration with the app's UI design system.

import SwiftUI

struct OwnerReferralBadgeView: View {
    let referralCount: Int
    let lastReferralDate: Date?

    var body: some View {
        HStack(spacing: AppSpacing.medium) { // Use modular spacing token
            referralIcon
            referralDetails
            Spacer()
            referralStar
        }
        .padding(AppSpacing.medium) // Use modular spacing token
        .background(AppColors.background) // Use design system background color token
        .clipShape(RoundedRectangle(cornerRadius: BorderRadius.medium, style: .continuous)) // Use design system border radius token
        .shadow(color: AppShadows.light.color, radius: AppShadows.light.radius, x: AppShadows.light.x, y: AppShadows.light.y) // Use design system shadow token
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var referralIcon: some View {
        ZStack {
            Circle()
                .fill(AppColors.accent.opacity(0.12)) // Use accent color token with opacity for background
                .frame(width: 40, height: 40)
            Image(systemName: "person.3.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(AppColors.accent) // Use accent color token for icon
        }
    }

    private var referralDetails: some View {
        VStack(alignment: .leading, spacing: 2) {
            if referralCount > 0 {
                Text("Referred \(referralCount) \(referralCount == 1 ? "client" : "clients")")
                    .font(AppFonts.headline) // Use headline font token
                    .foregroundColor(AppColors.accent) // Use accent color token
                if let date = lastReferralDate {
                    Text("Last referral: \(date, style: .date)")
                        .font(AppFonts.caption) // Use caption font token
                        .foregroundColor(AppColors.secondaryText) // Use secondary text color token
                }
            } else {
                Text("No referrals yet")
                    .font(AppFonts.caption) // Use caption font token
                    .foregroundColor(AppColors.secondaryText) // Use secondary text color token
            }
        }
    }

    private var referralStar: some View {
        Group {
            if referralCount >= 5 {
                Label("Referral Star", systemImage: "star.fill")
                    .font(AppFonts.caption2Bold) // Use bold caption2 font token
                    .foregroundColor(AppColors.loyalty) // Use loyalty color token
                    .padding(AppSpacing.small) // Use small spacing token for padding
                    .background(AppColors.loyalty.opacity(0.13)) // Use loyalty color token with opacity for background
                    .clipShape(Capsule())
                    .accessibilityLabel("Referral star awarded")
            }
        }
    }

    private var accessibilityLabel: String {
        if referralCount == 0 {
            return "No referrals yet"
        } else {
            var label = "Referred \(referralCount) \(referralCount == 1 ? "client" : "clients")"
            if let date = lastReferralDate {
                label += ", last referral on \(DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none))"
            }
            if referralCount >= 5 {
                label += ". Referral star awarded."
            }
            return label
        }
    }
}

// Demo/business/tokenized preview for OwnerReferralBadgeView
#Preview {
    VStack(spacing: AppSpacing.medium) { // Use modular spacing token
        OwnerReferralBadgeView(referralCount: 7, lastReferralDate: Date().addingTimeInterval(-86400 * 10))
        OwnerReferralBadgeView(referralCount: 2, lastReferralDate: Date().addingTimeInterval(-86400 * 45))
        OwnerReferralBadgeView(referralCount: 0, lastReferralDate: nil)
    }
    .padding()
    .background(AppColors.background) // Use design system background color token
}

//
//  PrivacyPolicyView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

// MARK: - PrivacyPolicyView (Business Privacy, Modular Token Styling)

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    private let policyText = """
    **Privacy Policy**

    At Furfolio, your privacy is our top priority. We’re dedicated to keeping your information safe, secure, and private. Here’s how we handle your data:

    **1. Information Collection**
    - We collect only the information you provide directly, including pet, owner, and appointment details.
    - No personal data is ever shared with third parties without your explicit consent.
    - All your data is securely stored locally on your device, giving you full control.

    **2. Security & Encryption**
    - Furfolio uses industry-standard encryption to protect your data on your device.
    - We leverage iOS security features, including device encryption and secure storage.
    - We recommend enabling your device’s passcode or biometric security for added protection.

    **3. Use of Information**
    - Your data helps us provide a seamless experience managing your dog grooming business.
    - We do not sell, share, or transmit your information outside the app.

    **4. Transparency & Trust**
    - We believe in full transparency. Visit our Trust Center anytime to learn how we protect your data and uphold your rights.
    - We regularly review and update our privacy practices to maintain the highest standards.

    **Contact Us**
    If you have questions or concerns, please reach out at support@furfolio.app. We’re here to help!
    """

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.large) {
                    Image(systemName: "pawprint.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .foregroundStyle(AppColors.accent)
                        .accessibilityHidden(true)

                    Text("Privacy Policy")
                        .font(AppFonts.title)
                        .foregroundStyle(AppColors.accent)
                        .accessibilityAddTraits(.isHeader)

                    Text("Your privacy matters to us")
                        .font(AppFonts.subheadline)
                        .foregroundStyle(AppColors.secondary)

                    Divider()

                    Text(try! AttributedString(markdown: policyText))
                        .font(AppFonts.body)
                        .foregroundStyle(AppColors.text)
                        .padding(AppSpacing.medium)
                        .background(
                            RoundedRectangle(cornerRadius: BorderRadius.medium, style: .continuous)
                                .fill(AppColors.card)
                        )
                        .appShadow(AppShadows.card)
                        .accessibilityLabel("Privacy policy details")

                    Button {
                        // Placeholder action for Trust Center
                    } label: {
                        Label("View Trust Center", systemImage: "lock.shield")
                            .font(AppFonts.headline)
                            .foregroundStyle(AppColors.accent)
                            .padding(.vertical, AppSpacing.small)
                            .padding(.horizontal, AppSpacing.medium)
                            .background(
                                RoundedRectangle(cornerRadius: BorderRadius.medium)
                                    .stroke(AppColors.accent, lineWidth: 2)
                            )
                    }
                    .accessibilityLabel("View Trust Center")
                }
                .padding(AppSpacing.medium)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .ignoresSafeArea(.keyboard)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Close", systemImage: "xmark.circle")
                    }
                    .accessibilityLabel("Close Privacy Policy")
                }
            }
        }
    }
}

#Preview {
    PrivacyPolicyView()
}

// TODO:
// - Link the “View Trust Center” button to the actual Trust Center page when available.
// - Customize the privacy policy text further based on legal review and real business practices.
// - Ensure .furfolio color and font extensions are implemented or adjust fallback colors/fonts accordingly.

//
//  PrivacyPolicyView.swift
//  Furfolio
//
//  Enhanced: analytics/audit–ready, token-compliant, Trust Center–compliant, accessibility, preview/test–injectable.
//

import SwiftUI

// MARK: - Analytics/Audit Protocol

public protocol PrivacyPolicyAnalyticsLogger {
    func log(event: String, info: String?)
}
public struct NullPrivacyPolicyAnalyticsLogger: PrivacyPolicyAnalyticsLogger {
    public init() {}
    public func log(event: String, info: String?) {}
}

// MARK: - PrivacyPolicyView (Business Privacy, Modular Token Styling, Audit/Analytics Ready)

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showTrustCenter = false

    static var analyticsLogger: PrivacyPolicyAnalyticsLogger = NullPrivacyPolicyAnalyticsLogger()

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
                        .accessibilityLabel("Privacy statement subtitle")

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
                        .accessibilityLabel("Privacy policy details. " + policyText.replacingOccurrences(of: "**", with: ""))

                    Button {
                        showTrustCenter = true
                        Self.analyticsLogger.log(event: "tap_trust_center", info: nil)
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
                    .accessibilityHint("Opens the Furfolio Trust Center for more privacy information.")
                    .sheet(isPresented: $showTrustCenter) {
                        TrustCenterView()
                            .onAppear {
                                Self.analyticsLogger.log(event: "trust_center_view_presented", info: nil)
                            }
                    }
                }
                .padding(AppSpacing.medium)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .ignoresSafeArea(.keyboard)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                        Self.analyticsLogger.log(event: "close_privacy_policy", info: nil)
                    } label: {
                        Label("Close", systemImage: "xmark.circle")
                    }
                    .accessibilityLabel("Close Privacy Policy")
                }
            }
            .onAppear {
                Self.analyticsLogger.log(event: "privacy_policy_view_appear", info: nil)
            }
        }
    }
}

// MARK: - Trust Center View Stub (for demo, unchanged)
struct TrustCenterView: View {
    var body: some View {
        VStack(spacing: AppSpacing.large) {
            Text("Trust Center")
                .font(AppFonts.title)
                .foregroundStyle(AppColors.primary)
            Text("Data Security & Audit Log features will be implemented here.")
                .font(AppFonts.body)
                .foregroundStyle(AppColors.secondary)
            Spacer()
        }
        .padding(AppSpacing.large)
        .background(AppColors.card)
        .cornerRadius(BorderRadius.large)
        .appShadow(AppShadows.card)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Preview with analytics print logger
#Preview {
    struct SpyLogger: PrivacyPolicyAnalyticsLogger {
        func log(event: String, info: String?) {
            print("[PrivacyPolicyAnalytics] \(event): \(info ?? "")")
        }
    }
    PrivacyPolicyView.analyticsLogger = SpyLogger()
    return PrivacyPolicyView()
}

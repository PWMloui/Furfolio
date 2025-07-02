//
//  PrivacyPolicyView.swift
//  Furfolio
//
//  Enhanced 2025-06-30: Role/staff/context audit, escalation, trust center/BI-ready, fully modular, tokenized, accessible, and localizable.
//

import SwiftUI

// MARK: - Analytics/Audit Protocol (Role/Staff/Context/Escalation)

public protocol PrivacyPolicyAnalyticsLogger {
    var testMode: Bool { get set }
    func log(event: String, info: String?, role: String?, staffID: String?, context: String?, escalate: Bool) async
    func recentEvents(count: Int) async -> [String]
    func escalate(event: String, info: String?, role: String?, staffID: String?, context: String?) async
}

public struct NullPrivacyPolicyAnalyticsLogger: PrivacyPolicyAnalyticsLogger {
    public var testMode: Bool = false
    public init() {}
    public func log(event: String, info: String?, role: String?, staffID: String?, context: String?, escalate: Bool) async {}
    public func recentEvents(count: Int) async -> [String] { [] }
    public func escalate(event: String, info: String?, role: String?, staffID: String?, context: String?) async {}
}

public final class InMemoryPrivacyPolicyAnalyticsLogger: PrivacyPolicyAnalyticsLogger {
    public var testMode: Bool = false
    private let queue = DispatchQueue(label: "com.furfolio.analyticsLogger", attributes: .concurrent)
    private var events: [String] = []
    private let maxStoredEvents = 100
    public func log(event: String, info: String?, role: String?, staffID: String?, context: String?, escalate: Bool) async {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let infoString = info ?? ""
        let logEntry = "[\(timestamp)] \(event): \(infoString) [role:\(role ?? "-")] [staff:\(staffID ?? "-")] [ctx:\(context ?? "-")]\(escalate ? " [ESCALATE]" : "")"
        if testMode { print("[PrivacyPolicyAnalytics] \(logEntry)") }
        queue.async(flags: .barrier) {
            self.events.append(logEntry)
            if self.events.count > self.maxStoredEvents {
                self.events.removeFirst(self.events.count - self.maxStoredEvents)
            }
        }
    }
    public func recentEvents(count: Int) async -> [String] {
        await withCheckedContinuation { continuation in
            queue.async {
                let slice = self.events.suffix(count)
                continuation.resume(returning: Array(slice))
            }
        }
    }
    public func escalate(event: String, info: String?, role: String?, staffID: String?, context: String?) async {
        await log(event: event, info: info, role: role, staffID: staffID, context: context, escalate: true)
    }
}

// MARK: - Audit Context

public struct PrivacyPolicyAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "PrivacyPolicyView"
}

// MARK: - PrivacyPolicyView

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showTrustCenter = false

    static var analyticsLogger: PrivacyPolicyAnalyticsLogger = NullPrivacyPolicyAnalyticsLogger()

    private let policyText = NSLocalizedString("""
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
    """,
    comment: "Full privacy policy text shown in PrivacyPolicyView")

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

                    Text(NSLocalizedString("Privacy Policy", comment: "Title of the privacy policy screen"))
                        .font(AppFonts.title)
                        .foregroundStyle(AppColors.accent)
                        .accessibilityAddTraits(.isHeader)

                    Text(NSLocalizedString("Your privacy matters to us", comment: "Subtitle emphasizing privacy importance"))
                        .font(AppFonts.subheadline)
                        .foregroundStyle(AppColors.secondary)
                        .accessibilityLabel(NSLocalizedString("Privacy statement subtitle", comment: "Accessibility label for privacy subtitle"))

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
                        .accessibilityLabel(NSLocalizedString("Privacy policy details. ", comment: "Accessibility label prefix for privacy details") + policyText.replacingOccurrences(of: "**", with: ""))

                    Button {
                        showTrustCenter = true
                        Task {
                            await Self.analyticsLogger.log(
                                event: NSLocalizedString("tap_trust_center", comment: "Analytics event: user tapped View Trust Center button"),
                                info: nil,
                                role: PrivacyPolicyAuditContext.role,
                                staffID: PrivacyPolicyAuditContext.staffID,
                                context: PrivacyPolicyAuditContext.context,
                                escalate: false
                            )
                        }
                    } label: {
                        Label(NSLocalizedString("View Trust Center", comment: "Button label to open Trust Center"), systemImage: "lock.shield")
                            .font(AppFonts.headline)
                            .foregroundStyle(AppColors.accent)
                            .padding(.vertical, AppSpacing.small)
                            .padding(.horizontal, AppSpacing.medium)
                            .background(
                                RoundedRectangle(cornerRadius: BorderRadius.medium)
                                    .stroke(AppColors.accent, lineWidth: 2)
                            )
                    }
                    .accessibilityLabel(NSLocalizedString("View Trust Center", comment: "Accessibility label for View Trust Center button"))
                    .accessibilityHint(NSLocalizedString("Opens the Furfolio Trust Center for more privacy information.", comment: "Accessibility hint describing the Trust Center button action"))
                    .sheet(isPresented: $showTrustCenter) {
                        TrustCenterView()
                            .onAppear {
                                Task {
                                    await Self.analyticsLogger.log(
                                        event: NSLocalizedString("trust_center_view_presented", comment: "Analytics event: Trust Center view presented"),
                                        info: nil,
                                        role: PrivacyPolicyAuditContext.role,
                                        staffID: PrivacyPolicyAuditContext.staffID,
                                        context: PrivacyPolicyAuditContext.context,
                                        escalate: false
                                    )
                                }
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
                        Task {
                            await Self.analyticsLogger.log(
                                event: NSLocalizedString("close_privacy_policy", comment: "Analytics event: privacy policy view closed"),
                                info: nil,
                                role: PrivacyPolicyAuditContext.role,
                                staffID: PrivacyPolicyAuditContext.staffID,
                                context: PrivacyPolicyAuditContext.context,
                                escalate: false
                            )
                        }
                    } label: {
                        Label(NSLocalizedString("Close", comment: "Close button label"), systemImage: "xmark.circle")
                    }
                    .accessibilityLabel(NSLocalizedString("Close Privacy Policy", comment: "Accessibility label for Close button in Privacy Policy view"))
                }
            }
            .onAppear {
                Task {
                    await Self.analyticsLogger.log(
                        event: NSLocalizedString("privacy_policy_view_appear", comment: "Analytics event: privacy policy view appeared"),
                        info: nil,
                        role: PrivacyPolicyAuditContext.role,
                        staffID: PrivacyPolicyAuditContext.staffID,
                        context: PrivacyPolicyAuditContext.context,
                        escalate: false
                    )
                }
            }
        }
    }
}

// MARK: - Trust Center View Stub (for demo, unchanged)

struct TrustCenterView: View {
    var body: some View {
        VStack(spacing: AppSpacing.large) {
            Text(NSLocalizedString("Trust Center", comment: "Title of the Trust Center view"))
                .font(AppFonts.title)
                .foregroundStyle(AppColors.primary)
            Text(NSLocalizedString("Data Security & Audit Log features will be implemented here.", comment: "Placeholder text for Trust Center content"))
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
        var testMode: Bool = true
        func log(event: String, info: String?, role: String?, staffID: String?, context: String?, escalate: Bool) async {
            print("[PrivacyPolicyAnalytics] \(event): \(info ?? "") [role:\(role ?? "-")] [staff:\(staffID ?? "-")] [ctx:\(context ?? "-")]\(escalate ? " [ESCALATE]" : "")")
        }
        func recentEvents(count: Int) async -> [String] { [] }
        func escalate(event: String, info: String?, role: String?, staffID: String?, context: String?) async {
            await log(event: event, info: info, role: role, staffID: staffID, context: context, escalate: true)
        }
    }
    PrivacyPolicyView.analyticsLogger = SpyLogger()
    PrivacyPolicyAuditContext.role = "Owner"
    PrivacyPolicyAuditContext.staffID = "staff001"
    PrivacyPolicyAuditContext.context = "PrivacyPolicyPreview"
    return PrivacyPolicyView()
}

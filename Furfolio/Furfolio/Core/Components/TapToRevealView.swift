//
//  TapToRevealView.swift
//  Furfolio
//
//  Enhanced: analytics/audit–ready, Trust Center–capable, accessible, preview/test–injectable.
//

import SwiftUI
import UIKit

// MARK: - Analytics/Audit Protocol

public protocol TapToRevealAnalyticsLogger {
    func log(event: String, info: [String: Any]?)
}
public struct NullTapToRevealAnalyticsLogger: TapToRevealAnalyticsLogger {
    public init() {}
    public func log(event: String, info: [String: Any]?) {}
}

// MARK: - TapToRevealView (Enterprise Enhanced)

struct TapToRevealView<Content: View>: View {
    /// Placeholder or obscured text shown when content is hidden
    var placeholder: String = "Tap to reveal"
    /// The content to reveal
    @ViewBuilder var content: () -> Content
    /// Optional user role for access control (default allows all)
    var userRole: UserRole = .unrestricted
    /// Whether the content can be re-hidden (default false)
    var canRehide: Bool = false
    /// Callback executed when content is revealed (default nil)
    var onReveal: (() -> Void)? = nil
    /// Optional audit tag for BI/Trust Center/compliance
    var auditTag: String? = nil

    @State private var isRevealed: Bool = false

    // Analytics logger (swap for QA/print/Trust Center)
    static var analyticsLogger: TapToRevealAnalyticsLogger = NullTapToRevealAnalyticsLogger()

    var body: some View {
        Group {
            if isRevealed {
                content()
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.accent)
                    .accessibilityAddTraits(.isStaticText)
                    .accessibilityLabel("Revealed content")
                    .accessibilityValue(Text("Content revealed"))
                    .transition(.opacity.combined(with: .scale))
                    .overlay(
                        canRehide ? Button(action: toggleReveal) {
                            Image(systemName: "eye.fill")
                                .foregroundColor(AppColors.accent)
                                .accessibilityLabel("Hide content")
                                .accessibilityHint("Tap to re-hide sensitive content")
                                .font(AppFonts.body.weight(.semibold))
                                .padding(AppSpacing.small)
                                .background(RoundedRectangle(cornerRadius: BorderRadius.medium).fill(AppColors.card))
                        }
                        .buttonStyle(.plain)
                        .padding([.top, .trailing], AppSpacing.small)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        : nil
                    )
            } else {
                PlaceholderView(
                    placeholder: placeholder,
                    isEnabled: isUserAllowed,
                    action: toggleReveal
                )
                .accessibilityLabel(placeholder)
                .accessibilityValue(isUserAllowed ? Text("Tap to reveal hidden content") : Text("Access restricted"))
                .accessibilityHint(isUserAllowed ? "Tap to show sensitive info" : "Restricted by business policy")
            }
        }
        .animation(.easeInOut, value: isRevealed)
        .backgroundStyle()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("TapToRevealView_\(placeholder.replacingOccurrences(of: " ", with: "_"))")
    }

    private var isUserAllowed: Bool {
        switch userRole {
        case .unrestricted: true
        case .restricted:   false
        }
    }

    private func toggleReveal() {
        guard isUserAllowed else {
            Self.analyticsLogger.log(event: "reveal_blocked", info: [
                "placeholder": placeholder,
                "role": "\(userRole)",
                "auditTag": auditTag as Any
            ])
            return
        }
        withAnimation {
            isRevealed.toggle()
            Self.analyticsLogger.log(
                event: isRevealed ? "revealed" : "hidden",
                info: [
                    "placeholder": placeholder,
                    "role": "\(userRole)",
                    "canRehide": canRehide,
                    "auditTag": auditTag as Any
                ]
            )
            if isRevealed {
                onReveal?()
                #if os(iOS)
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                #endif
            }
        }
    }

    enum UserRole: CustomStringConvertible {
        case unrestricted
        case restricted
        var description: String {
            switch self {
            case .unrestricted: return "unrestricted"
            case .restricted:   return "restricted"
            }
        }
    }

    private struct PlaceholderView: View {
        let placeholder: String
        let isEnabled: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                HStack(spacing: AppSpacing.small) {
                    Image(systemName: "eye.slash.fill")
                        .foregroundColor(AppColors.gray)
                        .font(AppFonts.body)
                    Text(placeholder)
                        .foregroundColor(AppColors.gray)
                        .italic()
                        .font(AppFonts.body)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .padding(AppSpacing.medium)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: BorderRadius.medium)
                        .fill(AppColors.card)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(placeholder)
            .disabled(!isEnabled)
            .accessibilityHint(isEnabled ? "Tap to reveal hidden content" : "Access restricted")
        }
    }
}

// MARK: - Preview with Analytics Logger

#Preview {
    struct SpyLogger: TapToRevealAnalyticsLogger {
        func log(event: String, info: [String : Any]?) {
            print("[TapToRevealAnalytics] \(event): \(info ?? [:])")
        }
    }
    TapToRevealView.analyticsLogger = SpyLogger()
    return VStack(spacing: AppSpacing.large) {
        TapToRevealView(placeholder: "Tap to reveal phone") {
            Text("555-123-4567")
                .font(AppFonts.title3.bold())
                .foregroundColor(AppColors.accent)
        } onReveal: {
            print("Phone number revealed")
        }

        TapToRevealView(placeholder: "Tap to see secret note", canRehide: true, auditTag: "grooming_note") {
            Text("This dog dislikes loud dryers.")
                .padding(AppSpacing.medium)
                .background(
                    RoundedRectangle(cornerRadius: BorderRadius.medium)
                        .fill(AppColors.yellow)
                )
                .font(AppFonts.body)
        }

        TapToRevealView(placeholder: "Restricted info", userRole: .restricted, auditTag: "confidential_data") {
            Text("Sensitive data")
                .font(AppFonts.body)
                .foregroundColor(AppColors.accent)
        }

        TapToRevealView(placeholder: "Tap to reveal with accent", canRehide: true, auditTag: "confidential_business_info") {
            Text("Confidential business info")
                .font(AppFonts.body)
                .foregroundColor(AppColors.accent)
        }
        .onReveal {
            print("Confidential info revealed")
        }
    }
    .padding(AppSpacing.large)
    .background(AppColors.background)
}

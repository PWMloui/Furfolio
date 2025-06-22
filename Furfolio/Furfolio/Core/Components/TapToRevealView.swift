//
//  TapToRevealView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI
import UIKit

// MARK: - TapToRevealView (Reusable, Tokenized, Accessible Secure Reveal)

/// A reusable view that hides sensitive or business-related content until tapped,
/// such as notes, contact info, or other private data.
/// Supports optional role-based access control, re-hide capability, and analytics callbacks.
/// All styling uses ONLY modular design tokens (AppColors, AppFonts, AppSpacing, BorderRadius, AppShadows).
/// This view is intended for sensitive/business data, with role-based access and full accessibility.
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

    @State private var isRevealed: Bool = false

    var body: some View {
        Group {
            if isRevealed {
                content()
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.accent)
                    .accessibilityAddTraits(.isStaticText)
                    .accessibilityLabel("Revealed content")
                    .transition(.opacity.combined(with: .scale))
                    .overlay(
                        canRehide ? Button(action: toggleReveal) {
                            Image(systemName: "eye.fill")
                                .foregroundColor(AppColors.accent)
                                .accessibilityLabel("Hide content")
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
            }
        }
        .animation(.easeInOut, value: isRevealed)
        .backgroundStyle()
    }

    private var isUserAllowed: Bool {
        switch userRole {
        case .unrestricted:
            return true
        case .restricted:
            return false
        }
    }

    private func toggleReveal() {
        guard isUserAllowed else { return }
        withAnimation {
            isRevealed.toggle()
            if isRevealed {
                onReveal?()
                #if os(iOS)
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                #endif
            }
        }
    }

    enum UserRole {
        case unrestricted
        case restricted
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

// MARK: - Preview

#Preview {
    VStack(spacing: AppSpacing.large) {
        TapToRevealView(placeholder: "Tap to reveal phone") {
            Text("555-123-4567")
                .font(AppFonts.title3.bold())
                .foregroundColor(AppColors.accent)
        } onReveal: {
            print("Phone number revealed")
        }

        TapToRevealView(placeholder: "Tap to see secret note", canRehide: true) {
            Text("This dog dislikes loud dryers.")
                .padding(AppSpacing.medium)
                .background(
                    RoundedRectangle(cornerRadius: BorderRadius.medium)
                        .fill(AppColors.yellow)
                )
                .font(AppFonts.body)
        }

        TapToRevealView(placeholder: "Restricted info", userRole: .restricted) {
            Text("Sensitive data")
                .font(AppFonts.body)
                .foregroundColor(AppColors.accent)
        }

        TapToRevealView(placeholder: "Tap to reveal with accent", canRehide: true) {
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

//
//  ContextualHelpView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - ContextualHelpView (Inline Help, Modular Token Styling)

/// A reusable, accessible, and localized contextual help/info view consistent with Furfolio's design system.
/// This view provides modular inline help suitable for onboarding, tips, and inline guidance.
/// It uses only design tokens (AppColors, AppFonts, AppSpacing, BorderRadius, AppShadows) for styling,
/// ensuring consistency and theming across the app.
/// Supports inline tips, overlays, or popovers with customizable icon (system or asset),
/// primary message, optional secondary action, and dismiss handling.
/// Visibility can be controlled internally or externally via binding.
struct ContextualHelpView: View {
    let title: String
    let message: String
    
    /// Icon can be a system symbol name or an asset image name.
    enum IconType {
        case systemName(String)
        case assetName(String)
    }
    var icon: IconType = .systemName("questionmark.circle.fill")
    
    var showDismissButton: Bool = true
    
    /// Optional secondary action button label and handler.
    var secondaryActionLabel: String? = nil
    var secondaryActionHandler: (() -> Void)? = nil
    
    /// Optional external binding to control visibility.
    @Binding var externalIsVisible: Bool?
    @State private var internalIsVisible: Bool = true
    private var isVisibleBinding: Binding<Bool> {
        Binding<Bool>(
            get: { externalIsVisible ?? internalIsVisible },
            set: { newValue in
                if externalIsVisible != nil {
                    externalIsVisible = newValue
                } else {
                    internalIsVisible = newValue
                }
            }
        )
    }
    
    /// Haptic feedback generator for dismiss action.
    #if os(iOS) || os(tvOS)
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    #endif
    
    var body: some View {
        if isVisibleBinding.wrappedValue {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                HStack(spacing: AppSpacing.small) {
                    iconView
                        .font(AppFonts.title2)
                        .foregroundColor(AppColors.accent)
                        .accessibilityHidden(true)
                    Text(title)
                        .font(AppFonts.headline)
                        .foregroundColor(AppColors.primaryText)
                    Spacer()
                    if showDismissButton {
                        Button(action: dismiss) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppColors.secondaryText)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Dismiss Help")
                        .accessibilityIdentifier("ContextualHelpView_DismissButton")
                    }
                }
                Text(message)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.secondaryText)
                    .accessibilityAddTraits(.isStaticText)
                    .accessibilityIdentifier("ContextualHelpView_Message")
                
                if let label = secondaryActionLabel, let handler = secondaryActionHandler {
                    Button(action: handler) {
                        Text(label)
                            .font(AppFonts.subheadline)
                            .foregroundColor(AppColors.accent)
                            .padding(.vertical, AppSpacing.small)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: BorderRadius.medium)
                                    .stroke(AppColors.accent, lineWidth: 1)
                            )
                    }
                    .accessibilityIdentifier("ContextualHelpView_SecondaryActionButton")
                }
            }
            .padding(AppSpacing.medium)
            .background(
                RoundedRectangle(cornerRadius: BorderRadius.medium)
                    .fill(AppColors.card)
                    .appShadow(AppShadows.card)
            )
            .padding(.horizontal, AppSpacing.medium)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.easeInOut, value: isVisibleBinding.wrappedValue)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("ContextualHelpView_Root")
        }
    }
    
    @ViewBuilder
    private var iconView: some View {
        switch icon {
        case .systemName(let name):
            Image(systemName: name)
        case .assetName(let name):
            Image(name)
                .renderingMode(.template)
        }
    }
    
    private func dismiss() {
        #if os(iOS) || os(tvOS)
        feedbackGenerator.impactOccurred()
        #endif
        isVisibleBinding.wrappedValue = false
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: AppSpacing.large) {
        Spacer()
        
        ContextualHelpView(
            title: "Need a hand?",
            message: "Tap the '+' to add new clients or pets. For more tips, visit the FAQ in Settings.",
            icon: .systemName("questionmark.circle.fill"),
            showDismissButton: true,
            secondaryActionLabel: "Learn More",
            secondaryActionHandler: { print("Learn More tapped") },
            externalIsVisible: .constant(true)
        )
        
        ContextualHelpView(
            title: "Custom Icon Example",
            message: "This help view uses a custom asset icon and no dismiss button.",
            icon: .assetName("customHelpIcon"),
            showDismissButton: false,
            externalIsVisible: .constant(true)
        )
        
        ContextualHelpView(
            title: "Controlled Visibility",
            message: "This help view's visibility is controlled externally.",
            icon: .systemName("info.circle.fill"),
            showDismissButton: true,
            secondaryActionLabel: "Details",
            secondaryActionHandler: { print("Details tapped") },
            externalIsVisible: .constant(true)
        )
        
        Spacer()
    }
    .background(AppColors.background)
    .padding(AppSpacing.medium)
}

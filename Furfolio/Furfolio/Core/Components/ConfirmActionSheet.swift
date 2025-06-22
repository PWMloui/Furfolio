//
//  ConfirmActionSheet.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

// MARK: - ConfirmActionSheet (Reusable Confirmation Dialog, Modular Token Styling)
// A reusable confirmation dialog for Furfolio, supporting unified design system and consistent action handling.
// Applies architectural enhancements for testability, accessibility, and multi-platform readiness.

import SwiftUI
import UIKit

/// A generic, reusable confirmation dialog modifier for important user actions.
/// Supports adaptive presentation for iOS/iPadOS (confirmationDialog) and macOS (alert),
/// customizable button titles, haptic feedback, and accessibility enhancements.
struct ConfirmActionSheet: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let message: String?
    let confirmTitle: String
    let confirmRole: ButtonRole
    let cancelTitle: String
    let onConfirm: () -> Void
    let onCancel: (() -> Void)?
    let hapticFeedback: Bool

    private enum Defaults {
        static let defaultConfirmTitle = "Delete"
        static let defaultCancelTitle = "Cancel"
    }

    func body(content: Content) -> some View {
        #if os(macOS)
        content
            .alert(
                title,
                isPresented: $isPresented,
                presenting: nil,
                actions: {
                    Button(confirmTitle, role: confirmRole) {
                        performConfirm()
                    }
                    .font(AppFonts.button)
                    .foregroundColor(AppColors.accent)
                    .accessibilityLabel(Text(confirmTitle))
                    Button(cancelTitle, role: .cancel) {
                        performCancel()
                    }
                    .font(AppFonts.button)
                    .foregroundColor(AppColors.accent)
                    .accessibilityLabel(Text(cancelTitle))
                },
                message: {
                    if let message {
                        Text(message)
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.textPrimary)
                            .accessibilityLabel(Text(message))
                    }
                }
            )
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        #else
        content
            .confirmationDialog(
                title,
                isPresented: $isPresented,
                titleVisibility: .visible
            ) {
                Button(confirmTitle, role: confirmRole) {
                    performConfirm()
                }
                .font(AppFonts.button)
                .foregroundColor(AppColors.accent)
                .accessibilityLabel(Text(confirmTitle))
                Button(cancelTitle, role: .cancel) {
                    performCancel()
                }
                .font(AppFonts.button)
                .foregroundColor(AppColors.accent)
                .accessibilityLabel(Text(cancelTitle))
            } message: {
                if let message {
                    Text(message)
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.textPrimary)
                        .accessibilityLabel(Text(message))
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        #endif
    }

    private func performConfirm() {
        if hapticFeedback {
            triggerHapticFeedback()
        }
        onConfirm()
    }

    private func performCancel() {
        onCancel?()
    }

    private func triggerHapticFeedback() {
        #if os(iOS) || os(tvOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
        #endif
    }
}

extension View {
    /// Attaches a reusable confirmation dialog to this view.
    ///
    /// - Parameters:
    ///   - isPresented: Binding to control the presentation of the dialog.
    ///   - title: The title text of the confirmation dialog.
    ///   - message: Optional descriptive message providing more context.
    ///   - confirmTitle: Title for the confirm button. Defaults to "Delete".
    ///   - confirmRole: Role of the confirm button (e.g. destructive, cancel). Defaults to `.destructive`.
    ///   - cancelTitle: Title for the cancel button. Defaults to "Cancel".
    ///   - hapticFeedback: Whether to trigger haptic feedback on confirm action. Defaults to false.
    ///   - onConfirm: Closure executed when the confirm button is tapped.
    ///   - onCancel: Optional closure executed when the cancel button is tapped.
    /// - Returns: A view modified with the confirmation dialog behavior.
    func confirmActionSheet(
        isPresented: Binding<Bool>,
        title: String,
        message: String? = nil,
        confirmTitle: String = ConfirmActionSheet.Defaults.defaultConfirmTitle,
        confirmRole: ButtonRole = .destructive,
        cancelTitle: String = ConfirmActionSheet.Defaults.defaultCancelTitle,
        hapticFeedback: Bool = false,
        onConfirm: @escaping () -> Void,
        onCancel: (() -> Void)? = nil
    ) -> some View {
        self.modifier(
            ConfirmActionSheet(
                isPresented: isPresented,
                title: title,
                message: message,
                confirmTitle: confirmTitle,
                confirmRole: confirmRole,
                cancelTitle: cancelTitle,
                onConfirm: onConfirm,
                onCancel: onCancel,
                hapticFeedback: hapticFeedback
            )
        )
    }
}

// MARK: - Example Usage Preview

struct ConfirmActionSheet_Previews: PreviewProvider {
    struct Demo: View {
        @State private var showDestructiveSheet = false
        @State private var showNonDestructiveSheet = false
        @State private var lastAction = "None"

        var body: some View {
            VStack(spacing: AppSpacing.large) {
                Text("Last Action: \(lastAction)")
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.textPrimary)
                    .accessibilityLabel(Text("Last Action: \(lastAction)"))

                Button("Delete Item") {
                    showDestructiveSheet = true
                }
                .font(AppFonts.button)
                .foregroundColor(AppColors.accent)
                .confirmActionSheet(
                    isPresented: $showDestructiveSheet,
                    title: "Are you sure?",
                    message: "This action cannot be undone.",
                    confirmTitle: "Delete",
                    confirmRole: .destructive,
                    cancelTitle: "Cancel",
                    hapticFeedback: true,
                    onConfirm: {
                        lastAction = "Deleted"
                    },
                    onCancel: {
                        lastAction = "Delete Cancelled"
                    }
                )
                .accessibilityLabel(Text("Delete Item"))

                Button("Archive Item") {
                    showNonDestructiveSheet = true
                }
                .font(AppFonts.button)
                .foregroundColor(AppColors.accent)
                .confirmActionSheet(
                    isPresented: $showNonDestructiveSheet,
                    title: "Archive this item?",
                    message: "You can restore it later from archives.",
                    confirmTitle: "Archive",
                    confirmRole: .none,
                    cancelTitle: "Dismiss",
                    hapticFeedback: false,
                    onConfirm: {
                        lastAction = "Archived"
                    },
                    onCancel: {
                        lastAction = "Archive Cancelled"
                    }
                )
                .accessibilityLabel(Text("Archive Item"))
            }
            .padding(AppSpacing.medium)
        }
    }

    static var previews: some View {
        Group {
            Demo()
                .previewDisplayName("iOS / iPadOS")
                .previewDevice("iPhone 14")

            Demo()
                .previewDisplayName("macOS")
                .previewLayout(.sizeThatFits)
        }
    }
}

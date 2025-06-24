//
//  InlineErrorBanner.swift
//  Furfolio
//
//  Created by mac on 6/21/25.
//

import SwiftUI

/// A dismissible inline error banner suitable for list or page-level errors.
/// Usage: Place at the top of your View and bind to an optional error message.
struct InlineErrorBanner: View {
    @Binding var errorMessage: String?
    var onDismiss: (() -> Void)? = nil
    var iconName: String = "exclamationmark.triangle.fill"

    private enum Style {
        static let cornerRadius: CGFloat = AppRadius.medium // TODO: confirm AppRadius.medium matches 12
        static let padding: CGFloat = AppSpacing.large // TODO: confirm AppSpacing.large matches 16
        static let background = AppColors.error.gradient // TODO: confirm AppColors.error exists
        static let iconColor = AppColors.onError // TODO: confirm AppColors.onError exists
        static let textColor = AppColors.onError // TODO: confirm AppColors.onError exists
        static let shadowRadius: CGFloat = AppRadius.small // TODO: confirm AppRadius.small matches 4
        static let iconFont = AppFonts.headline
        static let textFont = AppFonts.subheadline
        static let buttonPadding: CGFloat = AppSpacing.small // TODO: confirm AppSpacing.small matches 8
    }

    var body: some View {
        if let error = errorMessage {
            HStack(spacing: AppSpacing.medium) { // TODO: confirm AppSpacing.medium matches 12
                Image(systemName: iconName)
                    .foregroundStyle(Style.iconColor, AppColors.error) // TODO: confirm AppColors.error exists
                    .font(Style.iconFont)
                    .accessibilityHidden(true)

                Text(error)
                    .font(Style.textFont)
                    .foregroundColor(Style.textColor)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .accessibilityLabel(Text(error))
                    .accessibilityHint(Text("An error message describing the issue.")) // TODO: localize if needed

                Spacer()

                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(Style.textFont.weight(.bold))
                        .foregroundColor(Style.textColor.opacity(0.7))
                        .padding(Style.buttonPadding)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(LocalizedStringKey("Dismiss error message")) // Comment: Accessibility label for dismiss button
            }
            .padding(Style.padding)
            .background(
                RoundedRectangle(cornerRadius: Style.cornerRadius, style: .continuous)
                    .fill(Style.background)
                    .shadow(radius: Style.shadowRadius, y: 2)
            )
            .padding(.horizontal)
            .padding(.top, AppSpacing.small) // TODO: confirm AppSpacing.small matches 8
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.easeInOut(duration: 0.3), value: errorMessage)
            .accessibilityElement(children: .combine)
            .accessibilityLiveRegion(.polite)
            .accessibilityAddTraits(.isHeader)
        }
    }

    private func dismiss() {
        withAnimation {
            errorMessage = nil
        }
        onDismiss?()
    }
}

#Preview {
    Group {
        VStack {
            InlineErrorBanner(errorMessage: .constant("Failed to load appointments. Please check your network connection."))
            Spacer()
        }
        .padding(.top)
        .previewDisplayName("Light Mode")

        VStack {
            InlineErrorBanner(errorMessage: .constant("Failed to load appointments. Please check your network connection."))
            Spacer()
        }
        .padding(.top)
        .preferredColorScheme(.dark)
        .previewDisplayName("Dark Mode")

        VStack {
            InlineErrorBanner(errorMessage: .constant("Failed to load appointments. Please check your network connection."))
            Spacer()
        }
        .padding(.top)
        .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
        .previewDisplayName("Large Accessibility Text")
    }
}

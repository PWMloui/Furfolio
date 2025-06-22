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
        static let cornerRadius: CGFloat = 12
        static let padding: CGFloat = 16
        static let background = Color.red.gradient
        static let iconColor = Color.white
        static let textColor = Color.white
        static let shadowRadius: CGFloat = 4
    }

    var body: some View {
        if let error = errorMessage {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .foregroundStyle(Style.iconColor, .red)
                    .font(.headline)
                    .accessibilityHidden(true)

                Text(error)
                    .font(.subheadline)
                    .foregroundColor(Style.textColor)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)

                Spacer()

                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(Style.textColor.opacity(0.7))
                        .padding(8)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Dismiss error message")
            }
            .padding(Style.padding)
            .background(
                RoundedRectangle(cornerRadius: Style.cornerRadius, style: .continuous)
                    .fill(Style.background)
                    .shadow(radius: Style.shadowRadius, y: 2)
            )
            .padding(.horizontal)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.easeInOut(duration: 0.3), value: errorMessage)
            .accessibilityElement(children: .combine)
            .accessibilityLiveRegion(.polite)
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
    @State var errorMessage: String? = "Failed to load appointments. Please check your network connection."
    return VStack {
        InlineErrorBanner(errorMessage: $errorMessage)
        Spacer()
    }
    .padding(.top)
}

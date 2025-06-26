//
//  InlineErrorBanner.swift
//  Furfolio
//
//  Enhanced: Analytics/audit-ready, token-compliant, modular, accessible, preview/testable, enterprise-ready.
//

import SwiftUI

// MARK: - Analytics/Audit Logger Protocol

public protocol ErrorBannerAnalyticsLogger {
    func log(event: String, message: String?)
}
public struct NullErrorBannerAnalyticsLogger: ErrorBannerAnalyticsLogger {
    public init() {}
    public func log(event: String, message: String?) {}
}

/// A dismissible inline error banner suitable for list or page-level errors.
/// Usage: Place at the top of your View and bind to an optional error message.
/// Now with analytics/audit logging, richer accessibility, and token fallback.
struct InlineErrorBanner: View {
    @Binding var errorMessage: String?
    var onDismiss: (() -> Void)? = nil
    var iconName: String = "exclamationmark.triangle.fill"
    var analyticsLogger: ErrorBannerAnalyticsLogger = NullErrorBannerAnalyticsLogger()

    // MARK: - Tokenized Style (with robust fallback)
    private enum Style {
        static let cornerRadius: CGFloat = AppRadius.medium ?? 12
        static let padding: CGFloat = AppSpacing.large ?? 16
        static let background = AppColors.error.gradient ?? LinearGradient(colors: [.red.opacity(0.9), .red], startPoint: .top, endPoint: .bottom)
        static let iconColor = AppColors.onError ?? .white
        static let textColor = AppColors.onError ?? .white
        static let shadowRadius: CGFloat = AppRadius.small ?? 4
        static let iconFont = AppFonts.headline ?? .headline
        static let textFont = AppFonts.subheadline ?? .subheadline
        static let buttonPadding: CGFloat = AppSpacing.small ?? 8
        static let spacing: CGFloat = AppSpacing.medium ?? 12
        static let topPad: CGFloat = AppSpacing.small ?? 8
    }

    var body: some View {
        if let error = errorMessage {
            HStack(spacing: Style.spacing) {
                Image(systemName: iconName)
                    .foregroundStyle(Style.iconColor, AppColors.error ?? .red)
                    .font(Style.iconFont)
                    .accessibilityHidden(true)

                Text(error)
                    .font(Style.textFont)
                    .foregroundColor(Style.textColor)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .accessibilityLabel(Text(error))
                    .accessibilityHint(Text(NSLocalizedString("An error message describing the issue.", comment: "Accessibility hint for error message")))

                Spacer()

                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(Style.textFont.weight(.bold))
                        .foregroundColor(Style.textColor.opacity(0.7))
                        .padding(Style.buttonPadding)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(LocalizedStringKey("Dismiss error message"))
            }
            .padding(Style.padding)
            .background(
                RoundedRectangle(cornerRadius: Style.cornerRadius, style: .continuous)
                    .fill(Style.background)
                    .shadow(radius: Style.shadowRadius, y: 2)
            )
            .padding(.horizontal)
            .padding(.top, Style.topPad)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.easeInOut(duration: 0.3), value: errorMessage)
            .accessibilityElement(children: .combine)
            .accessibilityLiveRegion(.polite)
            .accessibilityAddTraits(.isHeader)
            .onAppear {
                analyticsLogger.log(event: "banner_shown", message: error)
            }
        }
    }

    private func dismiss() {
        withAnimation {
            let oldMessage = errorMessage
            errorMessage = nil
            analyticsLogger.log(event: "banner_dismissed", message: oldMessage)
        }
        onDismiss?()
    }
}

#Preview {
    struct SpyLogger: ErrorBannerAnalyticsLogger {
        func log(event: String, message: String?) {
            print("ErrorBannerAnalytics: \(event), Message: \(message ?? "-")")
        }
    }
    return Group {
        VStack {
            InlineErrorBanner(
                errorMessage: .constant("Failed to load appointments. Please check your network connection."),
                analyticsLogger: SpyLogger()
            )
            Spacer()
        }
        .padding(.top)
        .previewDisplayName("Light Mode")

        VStack {
            InlineErrorBanner(
                errorMessage: .constant("Failed to load appointments. Please check your network connection."),
                analyticsLogger: SpyLogger()
            )
            Spacer()
        }
        .padding(.top)
        .preferredColorScheme(.dark)
        .previewDisplayName("Dark Mode")

        VStack {
            InlineErrorBanner(
                errorMessage: .constant("Failed to load appointments. Please check your network connection."),
                analyticsLogger: SpyLogger()
            )
            Spacer()
        }
        .padding(.top)
        .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
        .previewDisplayName("Large Accessibility Text")
    }
}

//
//  InlineErrorBanner.swift
//  Furfolio
//
//  Enhanced: Analytics/audit-ready, token-compliant, modular, accessible, preview/testable, enterprise-ready.
//

/**
 InlineErrorBanner
 -----------------
 A SwiftUI view presenting an inline, dismissible error banner with integrated async analytics and audit logging.

 - **Purpose**: Display list- or page-level errors prominently, with user dismissal.
 - **Architecture**: SwiftUI `View` with configurable analytics logger, MVVM-compatible.
 - **Concurrency & Async Logging**: All analytics and audit calls are wrapped in non-blocking `Task` blocks.
 - **Audit & Analytics Ready**: Defines async analytics protocol and concurrency-safe audit manager.
 - **Localization**: All user-facing labels use `LocalizedStringKey` or `NSLocalizedString`.
 - **Accessibility**: Combines children, marked as header and live region for VoiceOver.
 - **Diagnostics & Preview/Testability**: Exposes async methods to fetch and export audit entries.
 */

import SwiftUI

/// A record of an error banner audit event.
public struct ErrorBannerAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let event: String
    public let message: String?

    public init(id: UUID = UUID(), timestamp: Date = Date(), event: String, message: String?) {
        self.id = id
        self.timestamp = timestamp
        self.event = event
        self.message = message
    }
}

/// Manages concurrency-safe audit logging for error banner events.
public actor ErrorBannerAuditManager {
    private var buffer: [ErrorBannerAuditEntry] = []
    private let maxEntries = 100
    public static let shared = ErrorBannerAuditManager()

    /// Add a new audit entry, capping buffer at `maxEntries`.
    public func add(_ entry: ErrorBannerAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Fetch recent audit entries up to the specified limit.
    public func recent(limit: Int = 20) -> [ErrorBannerAuditEntry] {
        Array(buffer.suffix(limit))
    }

    /// Export all audit entries as a JSON string.
    public func exportJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(buffer),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }
}

// MARK: - Analytics/Audit Logger Protocol

public protocol ErrorBannerAnalyticsLogger {
    /// Log an error banner event asynchronously.
    func log(event: String, message: String?) async
}
public struct NullErrorBannerAnalyticsLogger: ErrorBannerAnalyticsLogger {
    public init() {}
    public func log(event: String, message: String?) async {}
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
                Task {
                    await analyticsLogger.log(event: "banner_shown", message: error)
                    await ErrorBannerAuditManager.shared.add(
                        ErrorBannerAuditEntry(event: "banner_shown", message: error)
                    )
                }
            }
        }
    }

    private func dismiss() {
        withAnimation {
            let oldMessage = errorMessage
            errorMessage = nil
            Task {
                await analyticsLogger.log(event: "banner_dismissed", message: oldMessage)
                await ErrorBannerAuditManager.shared.add(
                    ErrorBannerAuditEntry(event: "banner_dismissed", message: oldMessage)
                )
            }
        }
        onDismiss?()
    }
}

#Preview {
    struct SpyLogger: ErrorBannerAnalyticsLogger {
        func log(event: String, message: String?) async {
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

// MARK: - Diagnostics

public extension InlineErrorBanner {
    /// Fetch recent audit entries for error banners.
    static func recentAuditEntries(limit: Int = 20) async -> [ErrorBannerAuditEntry] {
        await ErrorBannerAuditManager.shared.recent(limit: limit)
    }

    /// Export the error banner audit log as JSON asynchronously.
    static func exportAuditLogJSON() async -> String {
        await ErrorBannerAuditManager.shared.exportJSON()
    }
}

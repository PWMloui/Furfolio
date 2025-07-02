//
//  OnboardingPermissionView.swift
//  Furfolio
//
//  Enhanced: Analytics/audit-ready, modular, fully tokenized, accessible, and preview/testable.
//

/**
 OnboardingPermissionView
 ------------------------
 A SwiftUI view that requests notification permissions during onboarding in Furfolio.

 - **Purpose**: Guides users to enable notifications for key business updates.
 - **Architecture**: MVVM-capable, dependency-injectable analytics and audit loggers.
 - **Concurrency & Async Logging**: Wraps analytics and audit calls in async `Task` to avoid blocking UI.
 - **Audit/Analytics Ready**: Defines protocols for async logging and provides hooks for permission events.
 - **Localization**: All user-facing strings use `LocalizedStringKey` or `NSLocalizedString`.
 - **Accessibility**: Accessibility labels, hints, and grouping ensure VoiceOver compatibility.
 - **Preview/Testability**: Previews inject mock async loggers and demonstrate light/dark and large-text modes.
 */

import SwiftUI
import UserNotifications
import OSLog

// MARK: - Centralized Analytics and Audit Protocols

public protocol AnalyticsServiceProtocol {
    /// Log an analytics event asynchronously.
    func log(event: String, parameters: [String: Any]?) async
    /// Record a screen view asynchronously.
    func screenView(_ name: String) async
}

public protocol AuditLoggerProtocol {
    /// Record an audit message asynchronously.
    func record(_ message: String, metadata: [String: String]?) async
    /// Record a sensitive audit action asynchronously.
    func recordSensitive(_ action: String, userId: String) async
}

// MARK: - OnboardingPermissionView

struct OnboardingPermissionView: View {
    enum PermissionState {
        case idle
        case requesting
        case granted
        case denied
        case error
    }

    @State private var permissionState: PermissionState = .idle

    // MARK: - Injectables/DI
    var onContinue: (() -> Void)? = nil
    let analytics: AnalyticsServiceProtocol
    let audit: AuditLoggerProtocol

    // Design tokens (with safe fallback)
    let accent: Color
    let secondary: Color
    let errorColor: Color
    let successColor: Color
    let background: Color
    let titleFont: Font
    let bodyFont: Font
    let iconSize: CGFloat
    let spacingXL: CGFloat
    let spacingL: CGFloat
    let spacingM: CGFloat

    private let logger = Logger(subsystem: "com.furfolio.permissions", category: "onboarding")

    // MARK: - DI Initializer (preview/test/branding)
    init(
        onContinue: (() -> Void)? = nil,
        analytics: AnalyticsServiceProtocol = AnalyticsService.shared,
        audit: AuditLoggerProtocol = AuditLogger.shared,
        accent: Color = AppColors.accent ?? .accentColor,
        secondary: Color = AppColors.secondary ?? .secondary,
        errorColor: Color = AppColors.red ?? .red,
        successColor: Color = AppColors.green ?? .green,
        background: Color = AppColors.background ?? Color(.systemBackground),
        titleFont: Font = AppFonts.title.bold() ?? .title.bold(),
        bodyFont: Font = AppFonts.body ?? .body,
        iconSize: CGFloat = 70,
        spacingXL: CGFloat = AppSpacing.extraLarge ?? 36,
        spacingL: CGFloat = AppSpacing.large ?? 24,
        spacingM: CGFloat = AppSpacing.medium ?? 16
    ) {
        self.onContinue = onContinue
        self.analytics = analytics
        self.audit = audit
        self.accent = accent
        self.secondary = secondary
        self.errorColor = errorColor
        self.successColor = successColor
        self.background = background
        self.titleFont = titleFont
        self.bodyFont = bodyFont
        self.iconSize = iconSize
        self.spacingXL = spacingXL
        self.spacingL = spacingL
        self.spacingM = spacingM
    }

    var body: some View {
        VStack(spacing: spacingXL) {
            Image(systemName: "bell.badge.fill")
                .resizable()
                .scaledToFit()
                .frame(height: iconSize)
                .foregroundStyle(accent)
                .padding(.top, spacingL)
                .accessibilityLabel(Text("Notification icon"))

            Text("Stay Informed")
                .font(titleFont)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text("Enable notifications so you never miss an appointment, reminder, or business insight from Furfolio.")
                .multilineTextAlignment(.center)
                .font(bodyFont)
                .foregroundStyle(secondary)
                .padding(.horizontal)

            Group {
                switch permissionState {
                case .granted:
                    Label {
                        Text("Notifications enabled!")
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    .foregroundStyle(successColor)
                    .accessibilityLabel(Text("Notifications enabled"))
                    .accessibilityValue(Text("Status: Granted"))
                case .denied:
                    Label {
                        Text("Notifications not enabled")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                    .foregroundStyle(errorColor)
                    .accessibilityLabel(Text("Notifications denied"))
                    .accessibilityValue(Text("Status: Denied"))
                case .error:
                    Text("Unable to request permissions. Please check your device settings.")
                        .foregroundColor(errorColor)
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                        .accessibilityHint(Text("Open settings to allow permissions manually."))
                default:
                    EmptyView()
                }
            }
            .transition(.opacity)

            VStack(spacing: spacingM) {
                Button(action: requestNotificationPermission) {
                    HStack {
                        if permissionState == .requesting {
                            ProgressView().padding(.trailing, 6)
                        }
                        Label("Enable Notifications", systemImage: "bell.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(permissionState == .requesting || permissionState == .granted)
                .accessibilityLabel(Text("Enable notifications"))
                .accessibilityHint(Text("Requests permission from the system"))

                Button(action: {
                    Task {
                        await analytics.log(event: "permission_skip", parameters: nil)
                        await audit.record("User skipped permission screen", metadata: nil)
                        onContinue?()
                    }
                }) {
                    Text("Skip for now")
                }
                .foregroundStyle(accent)
                .accessibilityLabel(Text("Skip permission step"))
                .accessibilityHint(Text("Skips the notification permission step"))
            }
            .padding(.top, spacingM)
        }
        .padding(spacingL)
        .background(background.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .animation(.easeInOut, value: permissionState)
    }

    private func requestNotificationPermission() {
        permissionState = .requesting
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    logger.error("Notification permission error: \(error.localizedDescription)")
                    permissionState = .error
                    Task {
                        await analytics.log(event: "permission_error", parameters: ["error": error.localizedDescription])
                        await audit.record("Permission error: \(error.localizedDescription)", metadata: nil)
                    }
                } else if granted {
                    permissionState = .granted
                    Task {
                        await analytics.log(event: "permission_granted", parameters: ["granted": true])
                        await audit.record("Notification permission granted", metadata: nil)
                        onContinue?()
                    }
                } else {
                    permissionState = .denied
                    Task {
                        await analytics.log(event: "permission_denied", parameters: ["granted": false])
                        await audit.record("Notification permission denied", metadata: nil)
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewAnalytics: AnalyticsServiceProtocol {
        func log(event: String, parameters: [String: Any]?) async {
            print("[Analytics] \(event) → \(parameters ?? [:])")
        }
        func screenView(_ name: String) async {}
    }

    struct PreviewAudit: AuditLoggerProtocol {
        func record(_ message: String, metadata: [String: String]?) async {
            print("[Audit] \(message)")
        }
        func recordSensitive(_ action: String, userId: String) async {}
    }

    return Group {
        OnboardingPermissionView(
            onContinue: {},
            analytics: PreviewAnalytics(),
            audit: PreviewAudit()
        )
        .previewDisplayName("Light Mode")
        .environment(\.colorScheme, .light)

        OnboardingPermissionView(
            onContinue: {},
            analytics: PreviewAnalytics(),
            audit: PreviewAudit()
        )
        .previewDisplayName("Dark Mode")
        .environment(\.colorScheme, .dark)

        OnboardingPermissionView(
            onContinue: {},
            analytics: PreviewAnalytics(),
            audit: PreviewAudit()
        )
        .previewDisplayName("Accessibility Large Text")
        .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
    }
}

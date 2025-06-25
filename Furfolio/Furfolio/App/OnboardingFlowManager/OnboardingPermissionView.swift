//
//  OnboardingPermissionView.swift
//  Furfolio
//
//  Enhanced: Analytics/audit-ready, modular, fully tokenized, accessible, and preview/testable.
//

import SwiftUI
import UserNotifications
import OSLog

// MARK: - Analytics/Audit Logger Protocol

public protocol PermissionAnalyticsLogger {
    func log(event: String, granted: Bool?, error: Error?)
}
public struct NullPermissionAnalyticsLogger: PermissionAnalyticsLogger {
    public init() {}
    public func log(event: String, granted: Bool?, error: Error?) {}
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
    let analyticsLogger: PermissionAnalyticsLogger

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

    // MARK: - DI Initializer (useful for preview/test/branding)
    init(
        onContinue: (() -> Void)? = nil,
        analyticsLogger: PermissionAnalyticsLogger = NullPermissionAnalyticsLogger(),
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
        self.analyticsLogger = analyticsLogger
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
                .accessibilityLabel(Text(NSLocalizedString("Notification icon", comment: "Accessibility label for notification icon")))

            Text(LocalizedStringKey("Stay Informed"))
                .font(titleFont)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text(LocalizedStringKey("Enable notifications so you never miss an appointment, reminder, or business insight from Furfolio."))
                .multilineTextAlignment(.center)
                .font(bodyFont)
                .foregroundStyle(secondary)
                .padding(.horizontal)

            Group {
                switch permissionState {
                case .granted:
                    Label {
                        Text(NSLocalizedString("Notifications enabled!", comment: "Notification permission granted message"))
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    .foregroundStyle(successColor)
                    .accessibilityLabel(Text(NSLocalizedString("Notifications enabled", comment: "Accessibility label for enabled notifications")))
                    .accessibilityValue(Text(NSLocalizedString("Status: Granted", comment: "Value for granted status")))
                case .denied:
                    Label {
                        Text(NSLocalizedString("Notifications not enabled", comment: "Notification permission denied message"))
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                    .foregroundStyle(errorColor)
                    .accessibilityLabel(Text(NSLocalizedString("Notifications denied", comment: "Accessibility label for denied notifications")))
                    .accessibilityValue(Text(NSLocalizedString("Status: Denied", comment: "Value for denied status")))
                case .error:
                    Text(NSLocalizedString("Unable to request permissions. Please check your device settings.", comment: "Error message when permission request fails"))
                        .foregroundColor(errorColor)
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                        .accessibilityHint(Text(NSLocalizedString("Open settings to allow permissions manually.", comment: "Accessibility hint for error message")))
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
                        Label {
                            Text(LocalizedStringKey("Enable Notifications"))
                        } icon: {
                            Image(systemName: "bell.fill")
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(permissionState == .requesting || permissionState == .granted)
                .accessibilityLabel(Text(NSLocalizedString("Enable notifications", comment: "Accessibility label for enable notifications button")))
                .accessibilityHint(Text(NSLocalizedString("Requests permission from the system", comment: "Accessibility hint for enable notifications button")))

                Button(action: {
                    analyticsLogger.log(event: "permission_skip", granted: nil, error: nil)
                    onContinue?()
                }) {
                    Text(LocalizedStringKey("Skip for now"))
                }
                .foregroundStyle(accent)
                .accessibilityLabel(Text(NSLocalizedString("Skip permission step", comment: "Accessibility label for skip permission button")))
                .accessibilityHint(Text(NSLocalizedString("Skips the notification permission step", comment: "Accessibility hint for skip permission button")))
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
                    analyticsLogger.log(event: "permission_error", granted: nil, error: error)
                } else if granted {
                    permissionState = .granted
                    analyticsLogger.log(event: "permission_granted", granted: true, error: nil)
                    onContinue?()
                } else {
                    permissionState = .denied
                    analyticsLogger.log(event: "permission_denied", granted: false, error: nil)
                }
            }
        }
    }
}

#Preview {
    struct PreviewLogger: PermissionAnalyticsLogger {
        func log(event: String, granted: Bool?, error: Error?) {
            print("Analytics Event: \(event), granted: \(String(describing: granted)), error: \(String(describing: error))")
        }
    }
    Group {
        OnboardingPermissionView(
            onContinue: {},
            analyticsLogger: PreviewLogger()
        )
        .previewDisplayName("Light Mode")
        .environment(\.colorScheme, .light)

        OnboardingPermissionView(
            onContinue: {},
            analyticsLogger: PreviewLogger()
        )
        .previewDisplayName("Dark Mode")
        .environment(\.colorScheme, .dark)

        OnboardingPermissionView(
            onContinue: {},
            analyticsLogger: PreviewLogger()
        )
        .previewDisplayName("Accessibility Large Text")
        .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
    }
}

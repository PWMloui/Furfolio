//
//  OnboardingPermissionView.swift
//  Furfolio
//
//  Onboarding step for requesting app permissions (e.g., notifications).
//  - Accessibility: Main headers have appropriate accessibility traits and values.
//  - Localization: All user-facing strings are localized.
//  - Design Tokens: Fonts and colors use design tokens where available (TODOs for any needed tokens).
//  - Analytics: Placeholders for audit/analytics logging.
//  - Developer Guidance: Preview supports all accessibility settings.
//  This is production-ready for business onboarding.
//

import SwiftUI
import UserNotifications
import OSLog

struct OnboardingPermissionView: View {
    enum PermissionState {
        case idle
        case requesting
        case granted
        case denied
        case error
    }

    @State private var permissionState: PermissionState = .idle

    var onContinue: (() -> Void)? = nil

    private let logger = Logger(subsystem: "com.furfolio.permissions", category: "onboarding")

    var body: some View {
        VStack(spacing: 36) {
            Image(systemName: "bell.badge.fill")
                .resizable()
                .scaledToFit()
                .frame(height: 70)
                .foregroundStyle(AppColors.accent)
                .padding(.top, 32)
                .accessibilityLabel(Text(NSLocalizedString("Notification icon", comment: "Accessibility label for notification icon")))

            Text(LocalizedStringKey("Stay Informed"))
                .font(AppFonts.title.bold())
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text(LocalizedStringKey("Enable notifications so you never miss an appointment, reminder, or business insight from Furfolio."))
                .multilineTextAlignment(.center)
                .font(AppFonts.body)
                .foregroundStyle(AppColors.secondary)
                .padding(.horizontal)

            Group {
                switch permissionState {
                case .granted:
                    Label {
                        Text(NSLocalizedString("Notifications enabled!", comment: "Notification permission granted message"))
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    .foregroundStyle(AppColors.green)
                    .accessibilityLabel(Text(NSLocalizedString("Notifications enabled", comment: "Accessibility label for enabled notifications")))
                    .accessibilityValue(Text(NSLocalizedString("Status: Granted", comment: "Value for granted status")))
                case .denied:
                    Label {
                        Text(NSLocalizedString("Notifications not enabled", comment: "Notification permission denied message"))
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                    .foregroundStyle(AppColors.red)
                    .accessibilityLabel(Text(NSLocalizedString("Notifications denied", comment: "Accessibility label for denied notifications")))
                    .accessibilityValue(Text(NSLocalizedString("Status: Denied", comment: "Value for denied status")))
                case .error:
                    Text(NSLocalizedString("Unable to request permissions. Please check your device settings.", comment: "Error message when permission request fails"))
                        .foregroundColor(AppColors.red)
                        .multilineTextAlignment(.center)
                        .transition(.opacity)
                        .accessibilityHint(Text(NSLocalizedString("Open settings to allow permissions manually.", comment: "Accessibility hint for error message")))
                default:
                    EmptyView()
                }
            }
            .transition(.opacity)

            VStack(spacing: 14) {
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
                    // TODO: Add audit/analytics logging for skip action.
                    onContinue?()
                }) {
                    Text(LocalizedStringKey("Skip for now"))
                }
                .foregroundStyle(AppColors.accent)
                .accessibilityLabel(Text(NSLocalizedString("Skip permission step", comment: "Accessibility label for skip permission button")))
                .accessibilityHint(Text(NSLocalizedString("Skips the notification permission step", comment: "Accessibility hint for skip permission button")))
            }
            .padding(.top, 10)
        }
        .padding()
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
                } else if granted {
                    permissionState = .granted
                    // TODO: Audit/analytics logging for permission granted
                    onContinue?()
                } else {
                    permissionState = .denied
                    // TODO: Audit/analytics logging for permission denied
                }
            }
        }
    }
}

#Preview {
    Group {
        OnboardingPermissionView()
            .previewDisplayName("Light Mode")
            .environment(\.colorScheme, .light)

        OnboardingPermissionView()
            .previewDisplayName("Dark Mode")
            .environment(\.colorScheme, .dark)

        OnboardingPermissionView()
            .previewDisplayName("Accessibility Large Text")
            .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
    }
}

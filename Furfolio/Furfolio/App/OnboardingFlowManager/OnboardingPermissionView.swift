//
//  OnboardingPermissionView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI
import UserNotifications
import OSLog

/// Onboarding step for requesting app permissions (e.g., notifications).
struct OnboardingPermissionView: View {
    @State private var isRequesting = false
    @State private var permissionGranted: Bool?
    @State private var showError = false

    var onContinue: (() -> Void)? = nil

    private let logger = Logger(subsystem: "com.furfolio.permissions", category: "onboarding")

    var body: some View {
        VStack(spacing: 36) {
            Image(systemName: "bell.badge.fill")
                .resizable()
                .scaledToFit()
                .frame(height: 70)
                .foregroundStyle(.accent)
                .padding(.top, 32)
                .accessibilityLabel("Notification icon")

            Text("Stay Informed")
                .font(.title.bold())
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text("Enable notifications so you never miss an appointment, reminder, or business insight from Furfolio.")
                .multilineTextAlignment(.center)
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            if let granted = permissionGranted {
                Label {
                    Text(granted ? "Notifications enabled!" : "Notifications not enabled")
                } icon: {
                    Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                }
                .foregroundStyle(granted ? .green : .red)
                .transition(.opacity)
                .accessibilityLabel(granted ? "Notifications enabled" : "Notifications denied")
            }

            if showError {
                Text("Unable to request permissions. Please check your device settings.")
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
                    .accessibilityHint("Open settings to allow permissions manually.")
            }

            VStack(spacing: 14) {
                Button(action: requestNotificationPermission) {
                    HStack {
                        if isRequesting {
                            ProgressView().padding(.trailing, 6)
                        }
                        Label("Enable Notifications", systemImage: "bell.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRequesting || permissionGranted == true)
                .accessibilityLabel("Enable notifications")
                .accessibilityHint("Requests permission from the system")

                Button("Skip for now") {
                    onContinue?()
                }
                .foregroundStyle(.accent)
                .accessibilityLabel("Skip permission step")
            }
            .padding(.top, 10)
        }
        .padding()
        .accessibilityElement(children: .contain)
        .animation(.easeInOut, value: permissionGranted)
        .animation(.easeInOut, value: showError)
    }

    /// Requests notification permissions from the user.
    private func requestNotificationPermission() {
        isRequesting = true
        showError = false

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                isRequesting = false
                permissionGranted = granted

                if let error = error {
                    logger.error("Notification permission error: \(error.localizedDescription)")
                    showError = true
                }

                if granted {
                    onContinue?()
                }
            }
        }
    }
}

#Preview {
    OnboardingPermissionView()
}

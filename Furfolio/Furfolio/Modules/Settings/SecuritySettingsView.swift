//
//  SecuritySettingsView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

struct SecuritySettingsView: View {
    @AppStorage("isBiometricEnabled") private var isBiometricEnabled: Bool = false
    @AppStorage("isAppLockEnabled") private var isAppLockEnabled: Bool = false
    @State private var showBiometricUnavailableAlert = false

    var body: some View {
        Form {
            Section(header: Text("App Lock")) {
                Toggle(isOn: $isAppLockEnabled) {
                    Label("Enable App Lock", systemImage: "lock.fill")
                }
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                .help("Require authentication on app launch.")
            }

            Section(header: Text("Biometric Authentication")) {
                Toggle(isOn: $isBiometricEnabled) {
                    Label("Enable Face ID / Touch ID", systemImage: "faceid")
                }
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                .help("Use biometrics for quick unlock.")
                .onChange(of: isBiometricEnabled) { enabled in
                    if enabled && !isBiometricsAvailable() {
                        isBiometricEnabled = false
                        showBiometricUnavailableAlert = true
                    }
                }
            }
        }
        .navigationTitle("Security")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Biometric Unavailable", isPresented: $showBiometricUnavailableAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your device does not support Face ID or Touch ID, or biometrics are not configured.")
        }
    }

    // Helper: check if biometric authentication is available
    private func isBiometricsAvailable() -> Bool {
        #if targetEnvironment(simulator)
        // Always return true for preview/simulator
        return true
        #else
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        #endif
    }
}

#Preview {
    NavigationStack { SecuritySettingsView() }
}

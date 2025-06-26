//
//  SecuritySettingsView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Enterprise-Grade Security Settings
//

import SwiftUI
import LocalAuthentication

struct SecuritySettingsView: View {
    @AppStorage("isBiometricEnabled") private var isBiometricEnabled: Bool = false
    @AppStorage("isAppLockEnabled") private var isAppLockEnabled: Bool = false
    @State private var showBiometricUnavailableAlert = false
    @State private var animateBadge: Bool = false
    @State private var appearedOnce: Bool = false
    @State private var showAuditLog = false

    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                SectionCard {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(isBiometricEnabled || isAppLockEnabled ? 0.17 : 0.09))
                                .frame(width: 38, height: 38)
                                .scaleEffect(animateBadge ? 1.13 : 1.0)
                                .animation(.spring(response: 0.32, dampingFraction: 0.53), value: animateBadge)
                            Image(systemName: isAppLockEnabled ? "lock.shield.fill" : (isBiometricEnabled ? "faceid" : "lock.open.fill"))
                                .font(.title2)
                                .foregroundStyle(isAppLockEnabled ? .accentColor : (isBiometricEnabled ? .blue : .secondary))
                                .accessibilityIdentifier("SecuritySettingsView-Icon")
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Security")
                                .font(.headline)
                                .accessibilityIdentifier("SecuritySettingsView-SummaryLabel")
                            Text(
                                isAppLockEnabled ? "App Lock and biometrics enabled." :
                                (isBiometricEnabled ? "Biometric unlock enabled." : "No security enabled.")
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("SecuritySettingsView-SummaryStatus")
                        }
                        Spacer()
                        Button {
                            showAuditLog = true
                        } label: {
                            Image(systemName: "doc.text.magnifyingglass")
                        }
                        .accessibilityIdentifier("SecuritySettingsView-AuditLogButton")
                    }
                }

                SectionCard {
                    Toggle(isOn: $isAppLockEnabled) {
                        Label("Enable App Lock", systemImage: "lock.fill")
                            .accessibilityIdentifier("SecuritySettingsView-AppLockLabel")
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    .accessibilityIdentifier("SecuritySettingsView-AppLockToggle")
                    .help("Require authentication each time the app launches.")
                    .onChange(of: isAppLockEnabled) { enabled in
                        animateToggle()
                        SecuritySettingsAudit.record(action: "ToggleAppLock", enabled: enabled)
                    }
                }

                SectionCard {
                    Toggle(isOn: $isBiometricEnabled) {
                        Label("Enable Face ID / Touch ID", systemImage: "faceid")
                            .accessibilityIdentifier("SecuritySettingsView-BiometricLabel")
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .accessibilityIdentifier("SecuritySettingsView-BiometricToggle")
                    .help("Allow biometric unlock for quick access.")
                    .onChange(of: isBiometricEnabled) { enabled in
                        if enabled && !isBiometricsAvailable() {
                            isBiometricEnabled = false
                            showBiometricUnavailableAlert = true
                            SecuritySettingsAudit.record(action: "BiometricUnavailable", enabled: enabled)
                        } else {
                            animateToggle()
                            SecuritySettingsAudit.record(action: "ToggleBiometric", enabled: enabled)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Security")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Biometric Unavailable", isPresented: $showBiometricUnavailableAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your device does not support Face ID or Touch ID, or biometrics are not configured.")
                .accessibilityIdentifier("SecuritySettingsView-BiometricErrorMessage")
        }
        .sheet(isPresented: $showAuditLog) {
            NavigationStack {
                List {
                    ForEach(SecuritySettingsAuditAdmin.recentEvents(limit: 14), id: \.self) { summary in
                        Text(summary)
                            .font(.caption)
                            .padding(.vertical, 2)
                    }
                }
                .navigationTitle("Security Audit Log")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Copy") {
                            UIPasteboard.general.string = SecuritySettingsAuditAdmin.recentEvents(limit: 14).joined(separator: "\n")
                        }
                        .accessibilityIdentifier("SecuritySettingsView-CopyAuditLogButton")
                    }
                }
            }
        }
        .onAppear {
            if !appearedOnce {
                SecuritySettingsAudit.record(action: "Appear", enabled: isAppLockEnabled || isBiometricEnabled)
                appearedOnce = true
            }
        }
    }

    private func animateToggle() {
        animateBadge = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { animateBadge = false }
    }

    // Helper: check if biometric authentication is available
    private func isBiometricsAvailable() -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        #endif
    }
}

// MARK: - Card Section Helper

fileprivate struct SectionCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .shadow(color: Color(.black).opacity(0.04), radius: 3, x: 0, y: 1)
            )
            .padding(.vertical, 2)
    }
}

// MARK: - Audit/Event Logging

fileprivate struct SecuritySettingsAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let enabled: Bool
    var summary: String {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return "[SecuritySettingsView] \(action): \(enabled ? "Enabled" : "Disabled") at \(df.string(from: timestamp))"
    }
}
fileprivate final class SecuritySettingsAudit {
    static private(set) var log: [SecuritySettingsAuditEvent] = []
    static func record(action: String, enabled: Bool) {
        let event = SecuritySettingsAuditEvent(timestamp: Date(), action: action, enabled: enabled)
        log.append(event)
        if log.count > 32 { log.removeFirst() }
    }
    static func recentSummaries(limit: Int = 10) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}
public enum SecuritySettingsAuditAdmin {
    public static func recentEvents(limit: Int = 10) -> [String] { SecuritySettingsAudit.recentSummaries(limit: limit) }
}

#Preview {
    NavigationStack { SecuritySettingsView() }
}

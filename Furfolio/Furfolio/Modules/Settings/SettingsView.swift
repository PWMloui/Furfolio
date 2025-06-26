//
//  SettingsView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Enterprise-Grade Settings
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false
    @AppStorage("selectedLanguage") private var selectedLanguage: String = Locale.current.language.languageCode?.identifier ?? "en"

    @State private var showNotificationSettings = false
    @State private var showPrivacyPolicy = false
    @State private var showTerms = false
    @State private var showResetAlert = false
    @State private var showAppInfo = false
    @State private var showAuditLog = false
    @State private var animateDarkMode = false
    @State private var appearedOnce = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 22) {
                    // Appearance & Language
                    SectionCard {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.accentColor.opacity(isDarkMode ? 0.15 : 0.07))
                                    .frame(width: 34, height: 34)
                                    .scaleEffect(animateDarkMode ? 1.11 : 1.0)
                                    .animation(.spring(response: 0.33, dampingFraction: 0.5), value: animateDarkMode)
                                Image(systemName: isDarkMode ? "moon.fill" : "sun.max.fill")
                                    .foregroundStyle(isDarkMode ? .yellow : .orange)
                                    .font(.title3)
                                    .accessibilityIdentifier("SettingsView-AppearanceIcon")
                            }
                            Toggle(isOn: $isDarkMode) {
                                Text("Dark Mode")
                                    .font(.headline)
                                    .accessibilityIdentifier("SettingsView-DarkModeLabel")
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                            .accessibilityIdentifier("SettingsView-DarkModeToggle")
                        }
                        .onChange(of: isDarkMode) { newValue in
                            animateDarkMode = true
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            SettingsAudit.record(action: "ToggleDarkMode", value: "\(newValue)")
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { animateDarkMode = false }
                        }
                        Divider().padding(.vertical, 4)
                        Picker("Language", selection: $selectedLanguage) {
                            Text("English").tag("en")
                            Text("Español").tag("es")
                            // Add more supported languages here
                        }
                        .pickerStyle(.menu)
                        .accessibilityIdentifier("SettingsView-LanguagePicker")
                        .onChange(of: selectedLanguage) { value in
                            SettingsAudit.record(action: "LanguageChange", value: value)
                        }
                    }

                    // Notifications
                    SectionCard {
                        Button {
                            showNotificationSettings = true
                            SettingsAudit.record(action: "ShowNotifications", value: "")
                        } label: {
                            Label("Notifications", systemImage: "bell.badge")
                                .font(.headline)
                                .accessibilityIdentifier("SettingsView-NotificationsButton")
                        }
                    }

                    // Data Management
                    SectionCard {
                        Button(role: .destructive) {
                            showResetAlert = true
                        } label: {
                            Label("Reset App Data", systemImage: "trash")
                                .font(.headline)
                                .accessibilityIdentifier("SettingsView-ResetButton")
                        }
                    }

                    // Info & Support
                    SectionCard {
                        VStack(spacing: 8) {
                            Button {
                                showPrivacyPolicy = true
                                SettingsAudit.record(action: "ShowPrivacyPolicy", value: "")
                            } label: {
                                Label("Privacy Policy", systemImage: "hand.raised.fill")
                                    .accessibilityIdentifier("SettingsView-PrivacyPolicyButton")
                            }
                            Button {
                                showTerms = true
                                SettingsAudit.record(action: "ShowTermsOfService", value: "")
                            } label: {
                                Label("Terms of Service", systemImage: "doc.plaintext")
                                    .accessibilityIdentifier("SettingsView-TermsButton")
                            }
                            Button {
                                showAppInfo = true
                                SettingsAudit.record(action: "ShowAppInfo", value: "")
                            } label: {
                                Label("About Furfolio", systemImage: "info.circle")
                                    .accessibilityIdentifier("SettingsView-AboutButton")
                            }
                        }
                    }

                    // Admin/QA Log
                    HStack {
                        Spacer()
                        Button {
                            showAuditLog = true
                        } label: {
                            Label("View Audit Log", systemImage: "doc.text.magnifyingglass")
                                .font(.caption)
                        }
                        .accessibilityIdentifier("SettingsView-AuditLogButton")
                    }
                }
                .padding()
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showNotificationSettings) {
                NotificationSettingsView()
            }
            .sheet(isPresented: $showPrivacyPolicy) {
                PrivacyPolicyView()
            }
            .sheet(isPresented: $showTerms) {
                TermsOfServiceView()
            }
            .sheet(isPresented: $showAppInfo) {
                AppInfoView()
            }
            .sheet(isPresented: $showAuditLog) {
                NavigationStack {
                    List {
                        ForEach(SettingsAuditAdmin.recentEvents(limit: 24), id: \.self) { summary in
                            Text(summary)
                                .font(.caption)
                                .padding(.vertical, 2)
                        }
                    }
                    .navigationTitle("Audit Log")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Copy") {
                                UIPasteboard.general.string = SettingsAuditAdmin.recentEvents(limit: 24).joined(separator: "\n")
                            }
                            .accessibilityIdentifier("SettingsView-CopyAuditLogButton")
                        }
                    }
                }
            }
            .alert("Reset All Data?", isPresented: $showResetAlert) {
                Button("Reset", role: .destructive) {
                    resetAppData()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently erase all Furfolio data from your device. This action cannot be undone.")
                    .accessibilityIdentifier("SettingsView-ResetWarning")
            }
            .onAppear {
                if !appearedOnce {
                    SettingsAudit.record(action: "Appear", value: "")
                    appearedOnce = true
                }
            }
        }
    }

    private func resetAppData() {
        // Implement your full app data reset logic here (clear all storage, files, etc)
        SettingsAudit.record(action: "Reset", value: "Triggered")
        // Example: AppStorage/UserDefaults reset...
        print("App data reset requested.")
    }
}

// MARK: - Section Card Helper

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

fileprivate struct SettingsAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let value: String
    var summary: String {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return "[SettingsView] \(action): \(value) at \(df.string(from: timestamp))"
    }
}
fileprivate final class SettingsAudit {
    static private(set) var log: [SettingsAuditEvent] = []
    static func record(action: String, value: String) {
        let event = SettingsAuditEvent(timestamp: Date(), action: action, value: value)
        log.append(event)
        if log.count > 48 { log.removeFirst() }
    }
    static func recentSummaries(limit: Int = 12) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}
public enum SettingsAuditAdmin {
    public static func recentEvents(limit: Int = 12) -> [String] { SettingsAudit.recentSummaries(limit: limit) }
}

#Preview {
    SettingsView()
}

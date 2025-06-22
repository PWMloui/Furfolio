//
//  SettingsView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
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

    var body: some View {
        NavigationView {
            Form {
                // Profile
                Section(header: Text("Profile")) {
                    // Optionally add owner info if relevant for business use
                    // Text("Owner: Jane Doe")
                }

                // Notifications
                Section {
                    Button {
                        showNotificationSettings = true
                    } label: {
                        Label("Notifications", systemImage: "bell.badge")
                    }
                }

                // Appearance & Language
                Section(header: Text("Appearance")) {
                    Toggle(isOn: $isDarkMode) {
                        Label("Dark Mode", systemImage: "moon.fill")
                    }
                }
                Section(header: Text("Language")) {
                    Picker("Language", selection: $selectedLanguage) {
                        Text("English").tag("en")
                        Text("Español").tag("es")
                        // Add more supported languages here
                    }
                    .pickerStyle(.menu)
                }

                // Data Management
                Section(header: Text("Data")) {
                    Button(role: .destructive) {
                        showResetAlert = true
                    } label: {
                        Label("Reset App Data", systemImage: "trash")
                    }
                }

                // Info & Support
                Section {
                    Button {
                        showPrivacyPolicy = true
                    } label: {
                        Label("Privacy Policy", systemImage: "hand.raised.fill")
                    }
                    Button {
                        showTerms = true
                    } label: {
                        Label("Terms of Service", systemImage: "doc.plaintext")
                    }
                    Button {
                        showAppInfo = true
                    } label: {
                        Label("About Furfolio", systemImage: "info.circle")
                    }
                }
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
            .alert("Reset All Data?", isPresented: $showResetAlert) {
                Button("Reset", role: .destructive) {
                    resetAppData()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently erase all Furfolio data from your device. This action cannot be undone.")
            }
        }
    }

    private func resetAppData() {
        // WARNING: Implement your full app data reset logic here
        // This is a placeholder.
        // For a real app, clear the data stores and reset @AppStorage values.
        print("App data reset requested.")
    }
}

#Preview {
    SettingsView()
}

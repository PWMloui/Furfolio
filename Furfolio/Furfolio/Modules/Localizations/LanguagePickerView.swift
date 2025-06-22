//
//  LanguagePickerView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

struct LanguageOption: Identifiable {
    let id: String    // Locale identifier, e.g., "en", "es"
    let displayName: String
    let flag: String
}

struct LanguagePickerView: View {
    @AppStorage("selectedLanguage") private var selectedLanguage: String = Locale.current.languageCode ?? "en"

    private let options: [LanguageOption] = [
        LanguageOption(id: "en", displayName: "English", flag: "🇺🇸"),
        LanguageOption(id: "es", displayName: "Español", flag: "🇪🇸"),
        // Add more languages here
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Choose App Language")
                .font(.title2)
                .bold()
                .padding(.bottom)

            Picker("Language", selection: $selectedLanguage) {
                ForEach(options) { option in
                    HStack {
                        Text(option.flag)
                        Text(option.displayName)
                    }
                    .tag(option.id)
                }
            }
            .pickerStyle(.inline)
            .accessibilityIdentifier("LanguagePicker")

            Text("Current language: \(displayName(for: selectedLanguage))")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Language")
        .onChange(of: selectedLanguage) { _ in
            updateAppLanguage()
        }
    }

    // Helper to display current language name
    private func displayName(for languageID: String) -> String {
        options.first(where: { $0.id == languageID })?.displayName ?? languageID
    }

    // Update language at runtime (works if your app supports dynamic language switching)
    private func updateAppLanguage() {
        // Here, you would trigger your app's logic to reload strings/bundle
        // This can involve NotificationCenter, AppState, or custom logic
        // For many apps, a restart or relaunch of the root view is needed
        // For advanced use: LocalizationManager.shared.setLanguage(selectedLanguage)
    }
}

#Preview {
    NavigationStack {
        LanguagePickerView()
    }
}

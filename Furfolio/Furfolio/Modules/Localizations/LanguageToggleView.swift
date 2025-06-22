//
//  LanguageToggleView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

struct LanguageToggleView: View {
    @AppStorage("selectedLanguage") private var selectedLanguage: String = Locale.current.languageCode ?? "en"

    private let languages: [(code: String, display: String, flag: String)] = [
        ("en", "English", "🇺🇸"),
        ("es", "Español", "🇪🇸"),
        // Add more languages if needed
    ]

    var body: some View {
        HStack(spacing: 16) {
            ForEach(languages, id: \.code) { lang in
                Button(action: {
                    selectedLanguage = lang.code
                    updateAppLanguage()
                }) {
                    VStack {
                        Text(lang.flag)
                            .font(.largeTitle)
                        Text(lang.display)
                            .font(.caption)
                            .foregroundStyle(selectedLanguage == lang.code ? .primary : .secondary)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(selectedLanguage == lang.code ? Color.accentColor.opacity(0.2) : Color(.systemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .accessibilityLabel(lang.display)
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func updateAppLanguage() {
        // Here, you would trigger your app's logic to reload strings/bundle.
        // For many apps, a restart or relaunch of the root view is needed.
        // Example placeholder:
        // LocalizationManager.shared.setLanguage(selectedLanguage)
    }
}

#Preview {
    LanguageToggleView()
}

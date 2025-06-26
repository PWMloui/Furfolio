//
//  LanguagePickerView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Enterprise-Grade Language Picker
//

import SwiftUI

struct LanguageOption: Identifiable, Codable {
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

    @State private var showExportAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Choose App Language")
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, 2)
                .accessibilityIdentifier("LanguagePickerView-Header")

            Picker("Language", selection: $selectedLanguage) {
                ForEach(options) { option in
                    HStack {
                        Text(option.flag)
                        Text(option.displayName)
                    }
                    .tag(option.id)
                    .accessibilityLabel(option.displayName)
                    .accessibilityIdentifier("LanguagePickerView-Option-\(option.id)")
                }
            }
            .pickerStyle(.inline)
            .accessibilityIdentifier("LanguagePickerView-Picker")

            Text("Current language: \(displayName(for: selectedLanguage))")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("LanguagePickerView-Current")

            Button {
                showExportAlert = true
            } label: {
                Label("Export Language Audit Log", systemImage: "square.and.arrow.up")
                    .font(.caption)
            }
            .padding(.top, 4)
            .accessibilityIdentifier("LanguagePickerView-ExportButton")
            .alert("Language Change Audit Log", isPresented: $showExportAlert, actions: {
                Button("OK", role: .cancel) { }
            }, message: {
                ScrollView {
                    Text(LanguagePickerAuditAdmin.recentEvents(limit: 10).joined(separator: "\n"))
                        .font(.caption2)
                        .multilineTextAlignment(.leading)
                }
            })

            Spacer()
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Language")
        .onAppear {
            LanguagePickerAudit.record(action: "Appear", language: selectedLanguage)
        }
        .onChange(of: selectedLanguage) { newLang in
            updateAppLanguage()
            LanguagePickerAudit.record(action: "Change", language: newLang)
        }
    }

    // Helper to display current language name
    private func displayName(for languageID: String) -> String {
        options.first(where: { $0.id == languageID })?.displayName ?? languageID
    }

    // Update language at runtime (works if your app supports dynamic language switching)
    private func updateAppLanguage() {
        // Your app's localization logic would go here
        // e.g., LocalizationManager.shared.setLanguage(selectedLanguage)
    }
}

// MARK: - Audit/Event Logging

fileprivate struct LanguagePickerAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let language: String
    var summary: String {
        let df = DateFormatter()
        df.dateStyle = .short; df.timeStyle = .short
        return "[LanguagePicker] \(action): \(language) at \(df.string(from: timestamp))"
    }
}
fileprivate final class LanguagePickerAudit {
    static private(set) var log: [LanguagePickerAuditEvent] = []
    static func record(action: String, language: String) {
        let event = LanguagePickerAuditEvent(timestamp: Date(), action: action, language: language)
        log.append(event)
        if log.count > 30 { log.removeFirst() }
    }
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0

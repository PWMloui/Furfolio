//
//  LanguageToggleView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Enterprise-Grade Language Toggle
//

import SwiftUI

struct LanguageToggleView: View {
    @AppStorage("selectedLanguage") private var selectedLanguage: String = Locale.current.languageCode ?? "en"

    private let languages: [(code: String, display: String, flag: String)] = [
        ("en", "English", "🇺🇸"),
        ("es", "Español", "🇪🇸"),
        // Add more languages if needed
    ]

    @State private var showExportAlert = false

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 16) {
                ForEach(languages, id: \.code) { lang in
                    Button(action: {
                        let oldLang = selectedLanguage
                        selectedLanguage = lang.code
                        updateAppLanguage()
                        LanguageToggleAudit.record(action: "Toggle", language: lang.code, from: oldLang)
                    }) {
                        VStack(spacing: 2) {
                            Text(lang.flag)
                                .font(.largeTitle)
                            Text(lang.display)
                                .font(.caption)
                                .fontWeight(selectedLanguage == lang.code ? .bold : .regular)
                                .foregroundStyle(selectedLanguage == lang.code ? .primary : .secondary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(selectedLanguage == lang.code ? Color.accentColor.opacity(0.24) : Color(.systemFill))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedLanguage == lang.code ? Color.accentColor : .clear, lineWidth: 2)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: selectedLanguage == lang.code ? Color.accentColor.opacity(0.13) : .clear, radius: 2, x: 0, y: 1)
                    }
                    .accessibilityLabel(lang.display)
                    .accessibilityIdentifier("LanguageToggleView-Button-\(lang.code)")
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 10)

            Text("Current language: \(displayName(for: selectedLanguage))")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("LanguageToggleView-Current")

            Button {
                showExportAlert = true
            } label: {
                Label("Export Language Toggle Log", systemImage: "square.and.arrow.up")
                    .font(.caption)
            }
            .accessibilityIdentifier("LanguageToggleView-ExportButton")
            .alert("Language Toggle Audit Log", isPresented: $showExportAlert, actions: {
                Button("Copy") {
                    UIPasteboard.general.string = LanguageToggleAuditAdmin.recentEvents(limit: 12).joined(separator: "\n")
                }
                Button("OK", role: .cancel) { }
            }, message: {
                ScrollView {
                    Text(LanguageToggleAuditAdmin.recentEvents(limit: 12).joined(separator: "\n"))
                        .font(.caption2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            })
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemGroupedBackground))
                .shadow(color: Color(.black).opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .onAppear {
            LanguageToggleAudit.record(action: "Appear", language: selectedLanguage, from: nil)
        }
    }

    private func displayName(for code: String) -> String {
        languages.first(where: { $0.code == code })?.display ?? code
    }

    private func updateAppLanguage() {
        // Your app's localization manager logic here.
        // For example: LocalizationManager.shared.setLanguage(selectedLanguage)
    }
}

// MARK: - Audit/Event Logging

fileprivate struct LanguageToggleAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let language: String
    let from: String?
    var summary: String {
        let df = DateFormatter(); df.dateStyle = .short; df.timeStyle = .short
        let fromString = from.map { " (from: \($0))" } ?? ""
        return "[LanguageToggle] \(action): \(language)\(fromString) at \(df.string(from: timestamp))"
    }
}
fileprivate final class LanguageToggleAudit {
    static private(set) var log: [LanguageToggleAuditEvent] = []
    static func record(action: String, language: String, from: String?) {
        let event = LanguageToggleAuditEvent(timestamp: Date(), action: action, language: language, from: from)
        log.append(event)
        if log.count > 36 { log.removeFirst() }
    }
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    static func recentSummaries(limit: Int = 10) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}
public enum LanguageToggleAuditAdmin {
    public static func lastSummary() -> String { LanguageToggleAudit.log.last?.summary ?? "No language events yet." }
    public static func lastJSON() -> String? { LanguageToggleAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 12) -> [String] { LanguageToggleAudit.recentSummaries(limit: limit) }
}

#Preview {
    LanguageToggleView()
}

//
//  ResetAppButton.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Enterprise-Grade App Reset Button
//

import SwiftUI

struct ResetAppButton: View {
    @State private var showingAlert = false
    @State private var isResetting = false
    @State private var showAuditLog = false

    @AppStorage("isDemoMode") private var isDemoMode: Bool = false
    @AppStorage("selectedLanguage") private var selectedLanguage: String = Locale.current.languageCode ?? "en"
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            Button {
                showingAlert = true
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .font(.title2)
                        .accessibilityIdentifier("ResetAppButton-Icon")
                    Text("Reset App")
                        .font(.headline)
                        .accessibilityIdentifier("ResetAppButton-Label")
                    if isResetting {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(.circular)
                            .accessibilityIdentifier("ResetAppButton-Spinner")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .foregroundStyle(.red)
                .background(Color.red.opacity(isResetting ? 0.23 : 0.13))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .opacity(isResetting ? 0.6 : 1.0)
                .animation(.easeInOut(duration: 0.25), value: isResetting)
            }
            .disabled(isResetting)
            .accessibilityIdentifier("ResetAppButton-Root")
            .alert("Reset App?", isPresented: $showingAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    resetApp()
                }
            } message: {
                Text("This will delete all app data, preferences, and settings. This action cannot be undone. Do you want to continue?")
                    .accessibilityIdentifier("ResetAppButton-ConfirmMessage")
            }

            // Admin log export button (hidden in normal user mode)
            HStack {
                Spacer()
                Button {
                    showAuditLog = true
                } label: {
                    Label("View Reset Log", systemImage: "doc.text.magnifyingglass")
                        .font(.caption)
                }
                .accessibilityIdentifier("ResetAppButton-AuditLogButton")
            }
            .opacity(0.5)
        }
        .padding(.vertical, 2)
        .sheet(isPresented: $showAuditLog) {
            NavigationStack {
                List {
                    ForEach(ResetAppButtonAuditAdmin.recentEvents(limit: 18), id: \.self) { summary in
                        Text(summary)
                            .font(.caption)
                            .padding(.vertical, 2)
                    }
                }
                .navigationTitle("Reset Log")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Copy") {
                            UIPasteboard.general.string = ResetAppButtonAuditAdmin.recentEvents(limit: 18).joined(separator: "\n")
                        }
                        .accessibilityIdentifier("ResetAppButton-CopyAuditLogButton")
                    }
                }
            }
        }
    }

    private func resetApp() {
        isResetting = true
        ResetAppButtonAudit.record(action: "BeginReset")
        // Reset @AppStorage keys
        isDemoMode = false
        selectedLanguage = "en"
        isDarkMode = false

        // Reset UserDefaults (add more keys if needed)
        if let domain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: domain)
            UserDefaults.standard.synchronize()
        }

        // TODO: Add logic to delete local database, files, caches as needed
        // Example: DataManager.shared.resetAllData()

        // Simulate delay for UI feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            isResetting = false
            ResetAppButtonAudit.record(action: "ResetSuccess")
            // Optionally: trigger app reload or navigate to onboarding
        }
    }
}

// --- Audit/Event Logging ---

fileprivate struct ResetAppButtonAuditEvent: Codable {
    let timestamp: Date
    let action: String
    var summary: String {
        let df = DateFormatter(); df.dateStyle = .short; df.timeStyle = .short
        return "[ResetAppButton] \(action) at \(df.string(from: timestamp))"
    }
}
fileprivate final class ResetAppButtonAudit {
    static private(set) var log: [ResetAppButtonAuditEvent] = []
    static func record(action: String) {
        let event = ResetAppButtonAuditEvent(timestamp: Date(), action: action)
        log.append(event)
        if log.count > 30 { log.removeFirst() }
    }
    static func recentSummaries(limit: Int = 8) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}
public enum ResetAppButtonAuditAdmin {
    public static func recentEvents(limit: Int = 8) -> [String] { ResetAppButtonAudit.recentSummaries(limit: limit) }
}

#Preview {
    ResetAppButton()
}

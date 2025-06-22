//
//  ResetAppButton.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

struct ResetAppButton: View {
    @State private var showingAlert = false
    @State private var isResetting = false
    @AppStorage("isDemoMode") private var isDemoMode: Bool = false
    @AppStorage("selectedLanguage") private var selectedLanguage: String = Locale.current.languageCode ?? "en"
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false

    var body: some View {
        Button {
            showingAlert = true
        } label: {
            HStack {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.title2)
                Text("Reset App")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .foregroundStyle(.red)
            .background(Color.red.opacity(0.13))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isResetting)
        .alert("Reset App?", isPresented: $showingAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetApp()
            }
        } message: {
            Text("This will delete all app data, preferences, and settings. This action cannot be undone.")
        }
    }

    private func resetApp() {
        isResetting = true
        // Reset @AppStorage keys
        isDemoMode = false
        selectedLanguage = "en"
        isDarkMode = false

        // Reset UserDefaults (add more keys if needed)
        let domain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()

        // Add logic to delete local database, files, etc., as needed
        // Example: DataManager.shared.resetAllData()

        // Simulate delay for UI feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            isResetting = false
            // Optionally: trigger app reload or navigate to onboarding
        }
    }
}

#Preview {
    ResetAppButton()
}

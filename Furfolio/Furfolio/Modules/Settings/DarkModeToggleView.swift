//
//  DarkModeToggleView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

struct DarkModeToggleView: View {
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: isDarkMode ? "moon.fill" : "sun.max.fill")
                .font(.title2)
                .foregroundStyle(isDarkMode ? .yellow : .orange)
            Toggle(isOn: $isDarkMode) {
                Text(isDarkMode ? "Dark Mode" : "Light Mode")
                    .font(.headline)
            }
            .toggleStyle(SwitchToggleStyle(tint: .accentColor))
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onChange(of: isDarkMode) { newValue in
            updateAppearance(dark: newValue)
        }
    }

    private func updateAppearance(dark: Bool) {
        // This uses the new iOS 18 AppKit/SwiftUI scene phase for global UI
        // For older iOS: use UIWindow or AppDelegate tricks if needed.
        UIApplication.shared.windows.first?.overrideUserInterfaceStyle = dark ? .dark : .light
    }
}

#Preview {
    DarkModeToggleView()
}

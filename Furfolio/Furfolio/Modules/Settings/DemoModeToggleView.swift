//
//  DemoModeToggleView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//


import SwiftUI

struct DemoModeToggleView: View {
    @AppStorage("isDemoMode") private var isDemoMode: Bool = false

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: isDemoMode ? "play.rectangle.fill" : "rectangle.slash")
                .font(.title2)
                .foregroundStyle(isDemoMode ? .blue : .secondary)
            Toggle(isOn: $isDemoMode) {
                Text(isDemoMode ? "Demo Mode On" : "Demo Mode Off")
                    .font(.headline)
            }
            .toggleStyle(SwitchToggleStyle(tint: .blue))
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onChange(of: isDemoMode) { newValue in
            updateDemoMode(demo: newValue)
        }
    }

    private func updateDemoMode(demo: Bool) {
        // Trigger logic for switching to/from demo mode (e.g., show demo data, block real data)
        // You can send notifications, update AppState, etc.
        // Example:
        // AppState.shared.isDemoMode = demo
    }
}

#Preview {
    DemoModeToggleView()
}

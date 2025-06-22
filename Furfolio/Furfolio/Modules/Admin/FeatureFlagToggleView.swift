//
//  FeatureFlagToggleView.swift
//  Furfolio
//
//  Created by mac on 6/21/25.
//
//  ENHANCED: A reusable view for displaying and controlling a single feature flag.
//

import SwiftUI

/// A tokenized, modular, and accessible view that presents a single `Toggle` switch for a specific feature flag.
/// This view binds directly to the `FeatureFlagManager` to get and set the flag's state,
/// utilizing the app’s design tokens for fonts, colors, and spacing to ensure consistency and theming.
 // MARK: - FeatureFlagToggleView (Tokenized Feature Flag Toggle UI)
struct FeatureFlagToggleView: View {
    /// The specific flag this view controls.
    let flag: FeatureFlagManager.Flag
    
    /// The shared manager that holds the state for all flags.
    @ObservedObject var manager: FeatureFlagManager

    var body: some View {
        Toggle(isOn: Binding(
            get: { manager.isEnabled(flag) },
            set: { isEnabled in
                manager.set(flag, enabled: isEnabled)
            }
        )) {
            // Use the StringUtils helper to make the flag name more readable
            Text(StringUtils.humanize(flag.rawValue))
                .font(AppFonts.body)
                .foregroundColor(AppColors.textPrimary)
        }
        .toggleStyle(SwitchToggleStyle(tint: AppColors.primary))
        .padding(.vertical, AppSpacing.small)
        .accessibilityIdentifier("featureFlagToggle_\(flag.rawValue)")
    }
}


// MARK: - Preview

#if DEBUG
struct FeatureFlagToggleView_Previews: PreviewProvider {
    
    // A wrapper view to simulate how this component would be used in a list.
    // This is a demo/business/tokenized preview using real feature flags.
    struct PreviewWrapper: View {
        @StateObject private var featureManager = FeatureFlagManager.shared

        var body: some View {
            Form {
                Section(LocalizedStringKey("Available Features")) {
                    // Loop through all defined flags and create a toggle for each.
                    ForEach(FeatureFlagManager.Flag.allCases) { flag in
                        FeatureFlagToggleView(flag: flag, manager: featureManager)
                    }
                }
            }
            .navigationTitle("Feature Flags")
        }
    }
    
    static var previews: some View {
        NavigationStack {
            PreviewWrapper()
        }
    }
}
#endif

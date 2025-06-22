
//
//  AppColors.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

/// Central palette for all Furfolio UI colors. Use only these in the app for consistency.
enum AppColors {
    // MARK: - Brand Colors

    static let primary = Color("PrimaryColor") // Define in Assets.xcassets (e.g., blue or green)
    static let secondary = Color("SecondaryColor") // Define in Assets.xcassets

    // MARK: - Status Colors

    static let success = Color.green
    static let warning = Color.orange
    static let danger = Color.red
    static let info = Color.blue

    // MARK: - Backgrounds

    static let background = Color("BackgroundColor") // Define in Assets.xcassets
    static let card = Color(.secondarySystemGroupedBackground)
    static let overlay = Color.black.opacity(0.36)
    static let shimmerBase = Color.gray.opacity(0.23)
    static let shimmerHighlight = Color.gray.opacity(0.42)

    // MARK: - Text

    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textPlaceholder = Color.gray.opacity(0.54)

    // MARK: - Separator

    static let separator = Color(.separator)

    // MARK: - Custom Badges/Tags

    static let tagNew = Color.blue
    static let tagActive = Color.green
    static let tagReturning = Color.purple
    static let tagRisk = Color.orange
    static let tagInactive = Color.gray

    // MARK: - Examples for Custom Buttons

    static let button = primary
    static let buttonDisabled = Color.gray.opacity(0.33)
    static let buttonText = Color.white
}

// MARK: - Animation Utilities

static let fadeInOut = Color.clear // Used as placeholder for animation reference if needed

// MARK: - SwiftUI Preview

#if DEBUG
struct AppColorsPreview: View {
    var body: some View {
        VStack(spacing: 16) {
            Group {
                ColorSwatch(label: "Primary", color: AppColors.primary)
                ColorSwatch(label: "Secondary", color: AppColors.secondary)
                ColorSwatch(label: "Success", color: AppColors.success)
                ColorSwatch(label: "Warning", color: AppColors.warning)
                ColorSwatch(label: "Danger", color: AppColors.danger)
                ColorSwatch(label: "Info", color: AppColors.info)
                ColorSwatch(label: "Background", color: AppColors.background)
                ColorSwatch(label: "Card", color: AppColors.card)
                ColorSwatch(label: "Overlay", color: AppColors.overlay)
                ColorSwatch(label: "Shimmer Base", color: AppColors.shimmerBase)
                ColorSwatch(label: "Shimmer Highlight", color: AppColors.shimmerHighlight)
            }
            Group {
                ColorSwatch(label: "Text Primary", color: AppColors.textPrimary)
                ColorSwatch(label: "Text Secondary", color: AppColors.textSecondary)
                ColorSwatch(label: "Text Placeholder", color: AppColors.textPlaceholder)
                ColorSwatch(label: "Separator", color: AppColors.separator)
                ColorSwatch(label: "Tag New", color: AppColors.tagNew)
                ColorSwatch(label: "Tag Active", color: AppColors.tagActive)
                ColorSwatch(label: "Tag Returning", color: AppColors.tagReturning)
                ColorSwatch(label: "Tag Risk", color: AppColors.tagRisk)
                ColorSwatch(label: "Tag Inactive", color: AppColors.tagInactive)
                ColorSwatch(label: "Button", color: AppColors.button)
                ColorSwatch(label: "Button Disabled", color: AppColors.buttonDisabled)
                ColorSwatch(label: "Button Text", color: AppColors.buttonText)
            }
        }
        .padding()
        .background(AppColors.background)
    }

    struct ColorSwatch: View {
        let label: String
        let color: Color

        var body: some View {
            HStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(color)
                    .frame(width: 48, height: 28)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                Text(label)
                    .font(.callout)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
            }
        }
    }
}

#Preview {
    AppColorsPreview()
}
#endif

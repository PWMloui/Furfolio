// MARK: - ChargeFilterBar (Tokenized, Modular, Auditable Filter Bar for Charges)
//
// ChargeFilterBar is a modular, tokenized, and auditable UI component for filtering displayed charges.
// Designed for business analytics, accessibility, localization, and seamless UI design system integration.
// All colors, fonts, and spacing are referenced via design tokens to ensure consistency and maintainability.
//
//  ChargeFilterBar.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

struct ChargeFilterBar: View {
    /// Selected charge type filter (nil means "All")
    @Binding var selectedChargeType: String?
    /// List of charge types to display as filter options
    var chargeTypes: [String]
    /// Callback when filters are cleared
    var onClearFilters: (() -> Void)? = nil

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.filterChipSpacing) { // Use spacing token for filter chips
                // "All" filter button
                Button(action: {
                    selectedChargeType = nil
                    onClearFilters?()
                }) {
                    Text("All")
                        .font(AppFonts.subheadline) // Tokenized font
                        .font(AppFonts.subheadlineSemibold) // Tokenized semibold variant
                        .padding(.vertical, AppSpacing.filterChipVertical) // Tokenized vertical padding
                        .padding(.horizontal, AppSpacing.filterChipHorizontal) // Tokenized horizontal padding
                        .background(
                            // Use accent and secondary background tokens
                            selectedChargeType == nil ? AppColors.accent : AppColors.backgroundSecondary
                        )
                        .foregroundColor(
                            // Use text on accent and primary text tokens
                            selectedChargeType == nil ? AppColors.textOnAccent : AppColors.textPrimary
                        )
                        .clipShape(Capsule())
                }
                .accessibilityLabel(Text("Show all charges"))

                // Individual charge type filter buttons
                ForEach(chargeTypes, id: \.self) { type in
                    Button(action: {
                        if selectedChargeType == type {
                            selectedChargeType = nil
                            onClearFilters?()
                        } else {
                            selectedChargeType = type
                        }
                    }) {
                        Text(type)
                            .font(AppFonts.subheadline) // Tokenized font
                            .font(AppFonts.subheadlineSemibold) // Tokenized semibold variant
                            .padding(.vertical, AppSpacing.filterChipVertical)
                            .padding(.horizontal, AppSpacing.filterChipHorizontal)
                            .background(
                                selectedChargeType == type ? AppColors.accent : AppColors.backgroundSecondary
                            )
                            .foregroundColor(
                                selectedChargeType == type ? AppColors.textOnAccent : AppColors.textPrimary
                            )
                            .clipShape(Capsule())
                    }
                    .accessibilityLabel(Text("Filter charges by \(type)"))
                }
            }
            .padding(.horizontal, AppSpacing.filterBarHorizontal) // Use horizontal padding token
            .padding(.vertical, AppSpacing.filterBarVertical) // Use vertical padding token
        }
        .background(AppColors.background) // Tokenized background color
        .accessibilityElement(children: .contain)
        // Accessibility: Treat filter bar as a group of controls
    }
}

// MARK: - Preview

#if DEBUG
struct ChargeFilterBar_Previews: PreviewProvider {
    @State static var selectedType: String? = nil
    static var previews: some View {
        // Demo/business/tokenized preview: uses design tokens for color, font, and spacing
        ChargeFilterBar(
            selectedChargeType: $selectedType,
            chargeTypes: ["Full Package", "Basic Package", "Nail Trim", "Bath Only"],
            onClearFilters: { print("Filters cleared") }
        )
        .previewLayout(.sizeThatFits)
        .padding(AppSpacing.previewPadding)
        .background(AppColors.background)
    }
}
#endif

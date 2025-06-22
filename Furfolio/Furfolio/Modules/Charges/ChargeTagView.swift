//
// MARK: - ChargeTagView (Tokenized, Modular, Auditable Charge Category Tag View)
//  ChargeTagView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

/// A reusable, modular, tokenized, and auditable view for displaying charge category tags.
/// This view supports business analytics, accessibility, localization, and integration with the UI design system.
struct ChargeTagView: View {
    let text: String
    var color: Color = AppColors.accent // Use tokenized accent color for consistency

    var body: some View {
        Text(text)
            .font(AppFonts.captionSemibold) // Use tokenized font for maintainability
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(color.opacity(0.15)) // Use tokenized opacity for background fill
            )
            .foregroundColor(color) // Use tokenized foreground color
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(text) tag")
    }
}

#if DEBUG
// Demo/business/tokenized preview for ChargeTagView
struct ChargeTagView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            ChargeTagView(text: "VIP", color: AppColors.accent)
            ChargeTagView(text: "Full Package", color: AppColors.blue)
            ChargeTagView(text: "Discount", color: AppColors.green)
            ChargeTagView(text: "First Visit", color: AppColors.orange)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif

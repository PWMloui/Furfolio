//
//  ChargeSummaryView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//
// MARK: - ChargeSummaryView (Tokenized, Modular, Auditable Charge Summary UI)

import SwiftUI

/// A modular, tokenized, and auditable view displaying financial charge summaries.
/// This view supports business analytics, accessibility, localization,
/// and integrates seamlessly with the app's UI design system via tokens.
struct ChargeSummaryView: View {
    let charges: [Charge]

    // MARK: - Computed Properties

    /// Total amount from all charges.
    private var totalAmount: Double {
        charges.reduce(0) { $0 + $1.amount }
    }

    /// Total count of charges.
    private var chargeCount: Int {
        charges.count
    }

    /// Dictionary grouping total amount by charge type.
    private var chargesByType: [String: Double] {
        Dictionary(grouping: charges, by: { $0.type })
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.large) { // Use token for spacing 20
            Text("Charge Summary")
                .font(AppFonts.title2Bold) // Tokenized font replacing .title2.bold()
                .accessibilityAddTraits(.isHeader)

            HStack {
                VStack(alignment: .leading, spacing: AppSpacing.small) { // Tokenized spacing 4
                    Text("Total Revenue")
                        .font(AppFonts.headline) // Tokenized font replacing .headline
                    Text("$\(totalAmount, specifier: "%.2f")")
                        .font(AppFonts.largeTitle) // Tokenized font replacing .largeTitle
                        .foregroundColor(AppColors.success) // Tokenized color replacing .green
                        .accessibilityLabel("Total Revenue $\(Int(totalAmount)) dollars")
                }
                Spacer()
                VStack(alignment: .leading, spacing: AppSpacing.small) { // Tokenized spacing 4
                    Text("Total Charges")
                        .font(AppFonts.headline) // Tokenized font replacing .headline
                    Text("\(chargeCount)")
                        .font(AppFonts.largeTitle) // Tokenized font replacing .largeTitle
                        .accessibilityLabel("Total Charges \(chargeCount)")
                }
            }

            Divider()

            Text("Revenue by Charge Type")
                .font(AppFonts.headline) // Tokenized font replacing .headline
                .padding(.bottom, AppSpacing.small) // Tokenized padding bottom 4

            ForEach(chargesByType.sorted(by: { $0.key < $1.key }), id: \.key) { type, amount in
                HStack {
                    Text(type)
                    Spacer()
                    Text("$\(amount, specifier: "%.2f")")
                        .foregroundColor(AppColors.textPrimary) // Tokenized color replacing .primary
                        .accessibilityLabel("\(type) revenue $\(Int(amount)) dollars")
                }
            }
        }
        .padding(AppSpacing.medium) // Tokenized padding replacing default
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.background) // Tokenized background color replacing systemBackground
                .shadow(
                    color: AppShadows.medium.color,
                    radius: AppShadows.medium.radius,
                    x: AppShadows.medium.x,
                    y: AppShadows.medium.y
                ) // Tokenized shadow replacing default black opacity shadow
        )
        .padding(AppSpacing.medium) // Tokenized padding replacing default
    }
}

// MARK: - Charge Model

/// Represents a financial charge.
struct Charge: Identifiable, Equatable {
    var id: UUID
    var type: String
    var amount: Double
}

// MARK: - Preview

#if DEBUG
struct ChargeSummaryView_Previews: PreviewProvider {
    static var previews: some View {
        // Demo preview demonstrating tokenized fonts, colors, and spacing for business and tokenized UI validation.
        ChargeSummaryView(charges: [
            Charge(id: UUID(), type: "Full Package", amount: 75),
            Charge(id: UUID(), type: "Basic Package", amount: 50),
            Charge(id: UUID(), type: "Nail Trim", amount: 15),
            Charge(id: UUID(), type: "Full Package", amount: 75)
        ])
        .previewLayout(.sizeThatFits)
    }
}
#endif

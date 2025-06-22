//
//  ChargeDetailView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

// MARK: - ChargeDetailView (Tokenized, Modular, Auditable Charge Detail UI)

import SwiftUI

/// A modular, tokenized, and auditable view displaying detailed information about a charge.
/// This view supports business workflows, accessibility features, localization, and integrates seamlessly with the app's UI design system.
struct ChargeDetailView: View {
    let charge: Charge
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.medium) { // Use design token for spacing
                headerSection
                dateSection
                notesSection
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Charge Details")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
                .accessibilityLabel("Close charge details")
            }
        }
    }

    // MARK: - View Sections

    private var headerSection: some View {
        HStack {
            Text(charge.type)
                .font(AppFonts.title2Bold) // Replaced .font(.title2.bold()) with token
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel("Charge type: \(charge.type)")
            Spacer()
            Text(charge.amountFormatted)
                .font(AppFonts.title2Semibold) // Replaced .font(.title2.weight(.semibold)) with token
                .foregroundColor(AppColors.success) // Replaced .foregroundColor(.green) with token
                .accessibilityLabel("Amount \(charge.amountFormatted)")
        }
        .padding(.bottom, AppSpacing.small) // Replaced .padding(.bottom, 8) with token
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) { // Replaced .spacing(4) with token
            Text("Date")
                .font(AppFonts.headline) // Replaced .font(.headline) with token
                .accessibilityLabel("Date label")
            Text(charge.dateFormatted)
                .font(AppFonts.body) // Replaced .font(.body) with token
                .accessibilityLabel("Date \(charge.dateFormatted)")
        }
    }

    private var notesSection: some View {
        Group {
            if let notes = charge.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.small) { // Use token for spacing
                    Text("Notes")
                        .font(AppFonts.headline) // Replaced .font(.headline) with token
                        .accessibilityLabel("Notes label")
                    Text(notes)
                        .font(AppFonts.body) // Replaced .font(.body) with token
                        .foregroundColor(AppColors.secondaryText) // Replaced .foregroundColor(.secondary) with token
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("Notes: \(notes)")
                }
                .padding(.top, AppSpacing.medium) // Replaced .padding(.top, 12) with token
            }
        }
    }
}

// MARK: - Charge Model Extension

extension Charge {
    var amountFormatted: String {
        String(format: "$%.2f", amount)
    }

    var dateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Preview

// Demo/business/tokenized preview for ChargeDetailView
#if DEBUG
struct ChargeDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleCharge = Charge(
            id: UUID(),
            type: "Full Package",
            amount: 75.00,
            date: Date(),
            notes: "Includes shampoo and styling."
        )
        NavigationStack {
            ChargeDetailView(charge: sampleCharge)
                .font(AppFonts.body) // Apply tokenized font for preview consistency
                .foregroundColor(AppColors.primaryText) // Use design token for primary text color
        }
    }
}
#endif

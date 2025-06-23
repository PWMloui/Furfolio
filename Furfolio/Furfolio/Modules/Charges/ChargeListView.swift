//
//  ChargeListView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//
//  ENHANCED: Refactored to use a ViewModel and be the single source of truth.
//

import SwiftUI

// MARK: - ChargeListView (Tokenized, Modular, Auditable Charge History List)

struct ChargeListView: View {
    @StateObject private var viewModel = ChargeListViewModel()
    @State private var showingAddCharge = false

    var body: some View {
        NavigationStack {
            List {
                if viewModel.filteredCharges.isEmpty {
                    ContentUnavailableView(
                        LocalizedStringKey("No Charges Found"),
                        systemImage: "creditcard.trianglebadge.exclamationmark",
                        description: Text(LocalizedStringKey("Add a charge to get started."))
                    )
                } else {
                    ForEach(viewModel.filteredCharges) { charge in
                        NavigationLink(destination: ChargeDetailView(charge: charge)) {
                            ChargeRowView(charge: charge) // Reusable row view
                                .accessibilityIdentifier("chargeRow_\(charge.id.uuidString)") // Accessibility ID for each row
                        }
                    }
                    .onDelete(perform: viewModel.deleteCharge)
                }
            }
            .navigationTitle(LocalizedStringKey("Charge History")) // Localized title
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddCharge = true }) {
                        Image(systemName: "plus.circle.fill")
                    }
                    .accessibilityIdentifier("addChargeButton") // Accessibility ID for Add Charge button
                }
            }
            .searchable(text: $viewModel.searchText, prompt: LocalizedStringKey("Search charge types"))
            .accessibilityIdentifier("chargeSearchBar") // Accessibility ID for search bar
            .sheet(isPresented: $showingAddCharge) {
                AddChargeView(viewModel: AddChargeViewModel()) {
                    Task { await viewModel.fetchCharges() } // Refresh on save
                }
            }
            .task { // Use .task for async onAppear
                await viewModel.fetchCharges()
            }
        }
    }
}

    // MARK: - Data handling

    private func loadCharges() {
        // TODO: Replace with real data loading from persistence layer
        charges = sampleCharges
    }

    private func addCharge(_ charge: Charge) {
        charges.append(charge)
        charges.sort { $0.date > $1.date }
        showingAddCharge = false
        // TODO: Save to persistence layer
    }

    private func deleteCharge(at offsets: IndexSet) {
        charges.remove(atOffsets: offsets)
        // TODO: Delete from persistence layer
    }


// MARK: - Charge Row View

struct ChargeRowView: View {
    let charge: Charge

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) { // Tokenized spacing
            HStack {
                Text(charge.type)
                    .font(AppFonts.headline) // Replaced .font(.headline) with design token
                Spacer()
                Text("$\(String(format: "%.2f", charge.amount))")
                    .font(AppFonts.headline) // Tokenized font
                    .foregroundColor(AppColors.success) // Replaced .foregroundColor(.green) with design token for success color
            }
            Text(charge.date, style: .date)
                .font(AppFonts.caption) // Replaced .font(.caption) with design token
                .foregroundColor(AppColors.secondaryText) // Replaced .foregroundColor(.secondary) with design token
            if let notes = charge.notes, !notes.isEmpty {
                Text(notes)
                    .font(AppFonts.caption2) // Replaced .font(.caption2) with design token
                    .italic()
                    .foregroundColor(AppColors.secondaryText) // Tokenized secondary text color
            }
        }
        .padding(.vertical, AppSpacing.small) // Replaced fixed padding 6 with tokenized spacing
    }
}


// MARK: - Sample Data for Preview & Testing

let sampleCharges: [Charge] = [
    Charge(id: UUID(), date: Date(), type: "Full Package", amount: 75.0, notes: "Includes shampoo and styling"),
    Charge(id: UUID(), date: Date().addingTimeInterval(-86400), type: "Bath Only", amount: 25.0, notes: nil),
    Charge(id: UUID(), date: Date().addingTimeInterval(-172800), type: "Nail Trim", amount: 15.0, notes: "Handled carefully")
]

// MARK: - Preview

#if DEBUG
struct ChargeListView_Previews: PreviewProvider {
    static var previews: some View {
        // Demo/business/tokenized preview with usage of design tokens for colors and fonts
        ChargeListView()
            .environment(\.colorScheme, .light)
    }
}
#endif

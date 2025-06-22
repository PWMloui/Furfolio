//
// MARK: - ChargeHistoryView (Tokenized, Modular, Auditable Charge History UI)
//
//  ChargeHistoryView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

/// A modular, tokenized, and auditable charge history UI component.
/// This view supports business analytics, accessibility, localization,
/// and integrates with the app's UI design system for consistent styling.
/// It provides a searchable, deletable list of charges with detailed views,
/// optimized for adaptability across devices via NavigationSplitView.
struct ChargeHistoryView: View {
    @State private var charges: [Charge] = []
    @State private var searchText: String = ""
    @State private var showingAddCharge = false

    // MARK: Filtered Charges based on search text
    var filteredCharges: [Charge] {
        if searchText.isEmpty {
            return charges.sorted { $0.date > $1.date }
        } else {
            return charges
                .filter { $0.type.localizedCaseInsensitiveContains(searchText) }
                .sorted { $0.date > $1.date }
        }
    }

    var body: some View {
        // Using NavigationSplitView for better adaptability on iPad and Mac
        NavigationSplitView {
            List {
                if filteredCharges.isEmpty {
                    VStack(spacing: AppSpacing.medium) { // Using tokenized spacing
                        Text(LocalizedStringKey("No charges found."))
                            .font(AppFonts.headline) // Tokenized font
                            .foregroundColor(AppColors.secondaryText) // Tokenized color
                        Text(LocalizedStringKey("Add a charge to get started."))
                            .font(AppFonts.subheadline) // Tokenized font
                            .foregroundColor(AppColors.secondaryText) // Tokenized color
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity) // Full frame
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(filteredCharges) { charge in
                        NavigationLink(value: charge) {
                            ChargeRowView(charge: charge)
                        }
                    }
                    .onDelete(perform: deleteCharge)
                    .accessibilityIdentifier("ChargeRowDeleteAction") // Accessibility ID for delete
                }
            }
            .navigationTitle(LocalizedStringKey("Charge History")) // Localized title
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddCharge = true }) {
                        // Tokenized system icon usage
                        Image(systemName: "plus.circle.fill")
                            .accessibilityIdentifier("AddChargeButtonIcon") // Accessibility ID for icon
                    }
                    .accessibilityLabel(LocalizedStringKey("Add Charge")) // Localized accessibility label
                    .accessibilityIdentifier("AddChargeButton") // Accessibility ID for button
                }
            }
            .searchable(text: $searchText, prompt: LocalizedStringKey("Search charge types"))
            .accessibilityIdentifier("ChargeSearchField") // Accessibility ID for search field
            .sheet(isPresented: $showingAddCharge) {
                AddChargeView(viewModel: AddChargeViewModel()) {
                    loadCharges() // Refresh charges after adding
                }
            }
            .onAppear(perform: loadCharges)
        } detail: {
            // Placeholder detail view when no selection is made
            Text(LocalizedStringKey("Select a charge to view details"))
                .font(AppFonts.subheadline)
                .foregroundColor(AppColors.tertiaryText)
        }
    }

    private func loadCharges() {
        // Replace with actual data fetching from persistent storage
        charges = sampleCharges
    }

    private func deleteCharge(at offsets: IndexSet) {
        charges.remove(atOffsets: offsets)
        // Implement data persistence deletion here
    }
}

// MARK: - Charge Row View

struct ChargeRowView: View {
    let charge: Charge

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xsmall) { // Tokenized spacing
            HStack(spacing: AppSpacing.medium) { // Tokenized spacing
                Text(charge.type)
                    .font(AppFonts.headline) // Tokenized font
                Spacer()
                Text("$\(String(format: "%.2f", charge.amount))")
                    .font(AppFonts.headline) // Tokenized font
                    .foregroundColor(AppColors.success) // Tokenized success color
            }
            Text(formattedDate)
                .font(AppFonts.caption) // Tokenized font
                .foregroundColor(AppColors.secondaryText) // Tokenized color
            if let notes = charge.notes, !notes.isEmpty {
                Text(notes)
                    .font(AppFonts.caption2) // Tokenized font
                    .foregroundColor(AppColors.secondaryText) // Tokenized color
                    .italic()
            }
        }
        .padding(.vertical, AppSpacing.small) // Tokenized vertical padding
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: charge.date)
    }
}

// MARK: - Models

struct Charge: Identifiable, Equatable {
    var id: UUID
    var date: Date
    var type: String
    var amount: Double
    var notes: String?
}

// MARK: - Sample Data

let sampleCharges: [Charge] = [
    Charge(id: UUID(), date: Date(), type: "Full Package", amount: 75.00, notes: "Includes shampoo and styling"),
    Charge(id: UUID(), date: Date().addingTimeInterval(-86400), type: "Bath Only", amount: 25.00, notes: nil),
    Charge(id: UUID(), date: Date().addingTimeInterval(-172800), type: "Nail Trim", amount: 15.00, notes: "Handled carefully")
]

// MARK: - AddChargeView & ViewModel

struct AddChargeView: View {
    @ObservedObject var viewModel: AddChargeViewModel
    var onSave: (() -> Void)? = nil
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationSplitView {
            Form {
                Section(header: Text(LocalizedStringKey("Charge Details"))) {
                    TextField(LocalizedStringKey("Type"), text: $viewModel.type)
                        .autocapitalization(.words)
                        .disableAutocorrection(true)
                    TextField(LocalizedStringKey("Amount"), value: $viewModel.amount, format: .currency(code: Locale.current.currencyCode ?? "USD"))
                        .keyboardType(.decimalPad)
                    DatePicker(LocalizedStringKey("Date"), selection: $viewModel.date, displayedComponents: .date)
                    TextField(LocalizedStringKey("Notes"), text: $viewModel.notes)
                }
            }
            .navigationTitle(LocalizedStringKey("Add Charge"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Save")) {
                        viewModel.save()
                        onSave?()
                        dismiss()
                    }
                    .disabled(!viewModel.canSave)
                }
            }
        }
    }
}

class AddChargeViewModel: ObservableObject {
    @Published var type: String = ""
    @Published var amount: Double = 0.0
    @Published var date: Date = Date()
    @Published var notes: String = ""

    var canSave: Bool {
        !type.trimmingCharacters(in: .whitespaces).isEmpty && amount > 0
    }

    func save() {
        // Persist charge data to database or data store
        // Currently left empty for demo purposes
    }
}

// MARK: - Charge Detail View

struct ChargeDetailView: View {
    let charge: Charge

    var body: some View {
        Form {
            Section(header: Text(LocalizedStringKey("Charge Information"))) {
                HStack {
                    Text(LocalizedStringKey("Type"))
                    Spacer()
                    Text(charge.type)
                        .foregroundColor(AppColors.secondaryText) // Tokenized color
                }
                HStack {
                    Text(LocalizedStringKey("Amount"))
                    Spacer()
                    Text("$\(String(format: "%.2f", charge.amount))")
                        .foregroundColor(AppColors.secondaryText) // Tokenized color
                }
                HStack {
                    Text(LocalizedStringKey("Date"))
                    Spacer()
                    Text(formattedDate)
                        .foregroundColor(AppColors.secondaryText) // Tokenized color
                }
                if let notes = charge.notes, !notes.isEmpty {
                    Section(header: Text(LocalizedStringKey("Notes"))) {
                        Text(notes)
                            .foregroundColor(AppColors.secondaryText) // Tokenized color
                    }
                }
            }
        }
        .navigationTitle(LocalizedStringKey("Charge Details"))
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: charge.date)
    }
}

// MARK: - Preview

#if DEBUG
struct ChargeHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        // Demo/business/tokenized preview intent with tokens for fonts and colors
        ChargeHistoryView()
            .environment(\.locale, .init(identifier: "en"))
            .accentColor(AppColors.success)
            .font(AppFonts.body)
    }
}
#endif

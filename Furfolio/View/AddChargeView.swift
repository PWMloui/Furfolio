//
//  AddChargeView.swift
//  Furfolio
//
//  Created by mac on 12/20/24.
//  Updated on [Today's Date] with enhanced animations, transitions, haptic feedback, and user feedback.

import SwiftUI

struct AddChargeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let dogOwner: DogOwner

    @State private var serviceType: ChargeType = .basic
    @State private var chargeAmount: Double? = nil
    @State private var chargeNotes = ""
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var isSaving = false
    @State private var showTooltip = false

    // Haptic feedback generator for successful actions.
    private let feedbackGenerator = UINotificationFeedbackGenerator()

    var body: some View {
        NavigationView {
            ZStack {
                Form {
                    chargeInformationSection()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .navigationTitle(NSLocalizedString("Add Charge", comment: "Navigation title for Add Charge view"))
                .toolbar { toolbarContent() }
                .alert(
                    NSLocalizedString("Invalid Charge", comment: "Alert title for invalid charge"),
                    isPresented: $showErrorAlert
                ) {
                    Button(NSLocalizedString("OK", comment: "OK button label"), role: .cancel) {}
                } message: {
                    Text(errorMessage)
                }
                
                // Show a ProgressView overlay when saving is in progress.
                if isSaving {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView(NSLocalizedString("Saving...", comment: "Progress indicator while saving"))
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemBackground)))
                        .shadow(radius: 10)
                }
            }
            .onAppear {
                // Optional: Display a tooltip once when the view appears (for onboarding/help).
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    withAnimation {
                        showTooltip = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        withAnimation {
                            showTooltip = false
                        }
                    }
                }
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func chargeInformationSection() -> some View {
        Section(header: Text(NSLocalizedString("Charge Information", comment: "Header for charge information section"))) {
            serviceTypePicker()
            chargeAmountInput()
            notesField()
        }
    }

    @ViewBuilder
    private func serviceTypePicker() -> some View {
        Picker(
            NSLocalizedString("Service Type", comment: "Picker label for service type"),
            selection: $serviceType
        ) {
            ForEach(ChargeType.allCases, id: \.self) { type in
                Text(type.localized)
            }
        }
        .pickerStyle(MenuPickerStyle())
    }

    @ViewBuilder
    private func chargeAmountInput() -> some View {
        TextField(
            NSLocalizedString("Amount Charged", comment: "Text field label for charge amount"),
            value: $chargeAmount,
            format: .currency(code: Locale.current.currency?.identifier ?? "USD")
        )
        .keyboardType(.decimalPad)
        .onChange(of: chargeAmount) { newValue in
            if let newValue {
                chargeAmount = max(newValue, 0.0) // Ensure non-negative
            }
        }
    }

    @ViewBuilder
    private func notesField() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(
                NSLocalizedString("Additional Notes (Optional)", comment: "Text field label for additional notes"),
                text: $chargeNotes
            )
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .autocapitalization(.sentences)
            .onChange(of: chargeNotes) { _ in
                limitNotesLength()
            }
            
            if showTooltip && chargeNotes.isEmpty {
                Text(NSLocalizedString("Enter any extra details (max 250 characters)", comment: "Tooltip for additional notes"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .transition(.opacity)
            }
            
            if chargeNotes.count > 250 {
                Text(NSLocalizedString("Notes must be 250 characters or less.", comment: "Warning for note length"))
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button(NSLocalizedString("Cancel", comment: "Cancel button label")) {
                withAnimation {
                    dismiss()
                }
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            Button(NSLocalizedString("Save", comment: "Save button label")) {
                handleSave()
            }
            .disabled(!isFormValid() || isSaving)
        }
    }

    // MARK: - Save Handling

    private func handleSave() {
        if validateCharge() {
            isSaving = true
            
            // Trigger haptic feedback for a successful save.
            feedbackGenerator.notificationOccurred(.success)
            
            // Save the charge with animation.
            withAnimation(.easeInOut(duration: 0.3)) {
                saveChargeHistory()
            }
            
            // Simulate a short delay for saving (e.g., for animation or async tasks).
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isSaving = false
                dismiss()
            }
        } else {
            showErrorAlert = true
        }
    }

    /// Saves the charge entry to the model context
    private func saveChargeHistory() {
        let newCharge = Charge(
            date: Date(),
            type: Charge.ServiceType(rawValue: serviceType.rawValue) ?? .custom,
            amount: chargeAmount ?? 0.0,
            dogOwner: dogOwner,
            notes: chargeNotes
        )

        withAnimation {
            modelContext.insert(newCharge)
            dogOwner.charges.append(newCharge)
        }
        print("Charge saved: \(newCharge.formattedAmount) on \(newCharge.formattedDate)")
    }

    // MARK: - Validation Methods

    /// Validates the charge and checks for errors
    private func validateCharge() -> Bool {
        guard let amount = chargeAmount, amount > 0.0 else {
            errorMessage = NSLocalizedString("Charge amount must be greater than 0.", comment: "Error message for zero or negative charge amount")
            return false
        }

        if serviceType.rawValue.isEmpty {
            errorMessage = NSLocalizedString("Please select a valid service type.", comment: "Error message for unselected service type")
            return false
        }

        return true
    }

    /// Checks if the form is valid for enabling the "Save" button
    private func isFormValid() -> Bool {
        guard let amount = chargeAmount else { return false }
        return amount > 0.0 && !serviceType.rawValue.isEmpty
    }

    /// Limits the length of the notes to 250 characters
    private func limitNotesLength() {
        if chargeNotes.count > 250 {
            chargeNotes = String(chargeNotes.prefix(250))
        }
    }
}

// MARK: - ChargeType Enum

/// Enum for predefined charge types
enum ChargeType: String, CaseIterable {
    case basic = "Basic Package"
    case full = "Full Package"
    case custom = "Custom Service"

    var localized: String {
        NSLocalizedString(self.rawValue, comment: "Localized description of \(self.rawValue)")
    }
}

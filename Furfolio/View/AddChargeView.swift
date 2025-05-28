//
//  AddChargeView.swift
//  Furfolio
//
//  Created by mac on 12/20/24.
//  Updated on Jun 13, 2025 — switched to Charge.create, Date.now, removed unsupported notes: argument.
//

import SwiftUI
import SwiftData


// TODO: Move business logic (validation and saving) into a dedicated ViewModel for better testability and separation of concerns.

@MainActor
struct AddChargeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let dogOwner: DogOwner

    /// All the computed stats for this owner.
    private var stats: ClientStats {
        ClientStats(owner: dogOwner)
    }

    @State private var serviceType: Charge.ServiceType = .basic
    @State private var paymentMethod: Charge.PaymentMethod = .cash
    @State private var chargeAmount: Double? = nil
    @State private var chargeNotes = ""
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var isSaving = false
    @State private var showTooltip = false
    @State private var selectedAddOns: Set<AddOnService> = []

    private let feedbackGenerator = UINotificationFeedbackGenerator()

    /// Shared currency format style to avoid recreating on each render.
    private static let amountFormat = FloatingPointFormatStyle<Double>.Currency(code: Locale.current.currency?.identifier ?? "USD")

    var body: some View {
        NavigationView {
            ZStack {
                Form {
                    chargeInformationSection()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    ownerLoyaltySection()
                        .transition(.opacity)
                }
                .navigationTitle("Add Charge")
                .toolbar { toolbarContent() }
                .alert("Invalid Charge", isPresented: $showErrorAlert) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(errorMessage)
                }

                if isSaving {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    ProgressView("Saving...")
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemBackground)))
                        .shadow(radius: 10)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    withAnimation { showTooltip = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        withAnimation { showTooltip = false }
                    }
                }
            }
        }
    }

    // MARK: – Charge Info

    /// Builds the section with charge input fields.
    @ViewBuilder
    private func chargeInformationSection() -> some View {
        Section(header: Text("Charge Information")) {
            serviceTypePicker()
            paymentMethodPicker()
            chargeAmountInput()
            notesField()
        }
        Section(header: Text("Add‑On Services")) {
            AddOnServicesListView(selectedAddOns: $selectedAddOns)
            HStack {
                Text("Add‑Ons Total")
                Spacer()
                let addOnTotal = selectedAddOns.reduce(0) { $0 + $1.minPrice }
                Text((addOnTotal) as Double?, format: Self.amountFormat)
                    .foregroundColor(.secondary)
            }
        }
    }

    /// Picker for selecting the service type.
    @ViewBuilder
    private func serviceTypePicker() -> some View {
        Picker("Service Type", selection: $serviceType) {
            ForEach(Charge.ServiceType.allCases) { type in
                Text(type.localized).tag(type)
            }
        }
        .pickerStyle(.menu)
    }

    /// Picker for selecting the payment method.
    @ViewBuilder
    private func paymentMethodPicker() -> some View {
        Picker("Payment Method", selection: $paymentMethod) {
            ForEach(Charge.PaymentMethod.allCases) { method in
                Text(method.localized).tag(method)
            }
        }
        .pickerStyle(.segmented)
    }

    /// TextField for entering the charge amount with currency format.
    @ViewBuilder
    private func chargeAmountInput() -> some View {
        TextField(
            "Amount Charged",
            value: $chargeAmount,
            format: Self.amountFormat
        )
        .keyboardType(.decimalPad)
        .onChange(of: chargeAmount) { newValue in
            if let v = newValue {
                chargeAmount = max(0, v)
            }
        }
    }

    /// Field for entering optional notes with character limit enforcement.
    @ViewBuilder
    private func notesField() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(
                "Additional Notes (Optional)",
                text: $chargeNotes
            )
            .textFieldStyle(.roundedBorder)
            .autocapitalization(.sentences)
            .onChange(of: chargeNotes) { _ in limitNotesLength() }

            if showTooltip && chargeNotes.isEmpty {
                Text("Enter any extra details (max 250 characters)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .transition(.opacity)
            }
            if chargeNotes.count > 250 {
                Text("Notes must be 250 characters or less.")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    // MARK: – Owner Stats

    /// Displays owner loyalty and behavior statistics.
    @ViewBuilder
    private func ownerLoyaltySection() -> some View {
        Section(header: Text("Owner Details")) {
            HStack {
                Text("Name")
                Spacer()
                Text(dogOwner.ownerName)
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("Loyalty Status")
                Spacer()
                Text(stats.loyaltyStatus)
                    .foregroundColor(.yellow)
                    .fontWeight(.semibold)
            }

            HStack {
                Text("Loyalty Reward")
                Spacer()
                Text(stats.loyaltyProgressTag)
                    .foregroundColor(.green)
                    .fontWeight(.semibold)
            }

            if let badge = stats.recentBehaviorBadges.first {
                HStack {
                    Text("Behavior")
                    Spacer()
                    Text(badge)
                        .foregroundColor(.orange)
                        .fontWeight(.semibold)
                }
            }

            if stats.isRetentionRisk {
                HStack {
                    Text("Status")
                    Spacer()
                    Text("⚠️ Retention Risk")
                        .foregroundColor(.red)
                        .fontWeight(.semibold)
                }
            }

            if stats.hasBirthdayThisMonth {
                HStack {
                    Text("Special")
                    Spacer()
                    Text("🎂 Birthday Month")
                        .foregroundColor(.purple)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: – Toolbar

    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Cancel") {
                withAnimation { dismiss() }
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button("Save") { handleSave() }
                .disabled(!isFormValid() || isSaving)
        }
    }

    // MARK: – Save

    /// Validates inputs and saves the charge record.
    private func handleSave() {
        guard validateCharge() else {
            showErrorAlert = true
            return
        }
        isSaving = true
        feedbackGenerator.notificationOccurred(.success)
        withAnimation(.easeInOut(duration: 0.3)) {
            saveChargeHistory()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isSaving = false
            dismiss()
        }
    }

    /// Creates and persists the new Charge entity in the model context.
    private func saveChargeHistory() {
        // Create without notes
        let newCharge = Charge.create(
          date: Date.now,
          serviceType: serviceType,
          amount: chargeAmount ?? 0.0,
          paymentMethod: paymentMethod,
          notes: nil,
          dogOwner: dogOwner,
          appointment: nil,
          in: modelContext
        )
        // Attach selected add‑ons to the charge
        newCharge.addOns = Array(selectedAddOns)
        // Apply notes if any
        let trimmed = chargeNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            newCharge.update(notes: trimmed)
        }

        print(
            "Charge saved: \(newCharge.formattedAmount) "
          + "via \(newCharge.paymentMethod.localized) "
          + "on \(newCharge.formattedDate)"
        )
    }

    // MARK: – Validation

    /// Validates that the charge amount is greater than zero.
    private func validateCharge() -> Bool {
        guard let amount = chargeAmount, amount > 0 else {
            errorMessage = "Charge amount must be greater than 0."
            return false
        }
        return true
    }

    /// Returns true when all required form fields are valid.
    private func isFormValid() -> Bool {
        ((chargeAmount ?? 0) + selectedAddOns.reduce(0) { $0 + $1.minPrice }) > 0
    }

    /// Enforces the maximum notes length by truncating excess characters.
    private func limitNotesLength() {
        if chargeNotes.count > 250 {
            chargeNotes = String(chargeNotes.prefix(250))
        }
    }
}

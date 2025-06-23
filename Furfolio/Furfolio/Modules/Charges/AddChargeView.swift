//
// MARK: - AddChargeView (Tokenized, Modular, Auditable Charge Entry UI)
//
//  AddChargeView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//  ENHANCED: Fully integrated with data models, design tokens, and payment method selection.
//

import SwiftUI
import SwiftData

/// ViewModel for AddChargeView, handles data sources, selections, and saving logic.
@MainActor
final class AddChargeViewModel: ObservableObject {
    @Published var owners: [DogOwner] = []
    @Published var dogsForSelectedOwner: [Dog] = []
    
    // In a real app, this would be fetched from a service or config
    let chargeTypes: [ChargeType] = ChargeType.allCases
    let paymentMethods: [PaymentMethod] = PaymentMethod.allCases
    
    private var dataStore: DataStoreService
    
    init(dataStore: DataStoreService = .shared) {
        self.dataStore = dataStore
        Task {
            await fetchOwners()
        }
    }
    
    func fetchOwners() async {
        self.owners = await dataStore.fetchAll(DogOwner.self).sorted { $0.ownerName < $1.ownerName }
    }
    
    func fetchDogs(for owner: DogOwner?) {
        guard let owner = owner else {
            self.dogsForSelectedOwner = []
            return
        }
        // Assuming DogOwner model has a 'dogs' relationship
        self.dogsForSelectedOwner = owner.dogs.sorted { $0.name < $1.name }
    }

    func saveCharge(date: Date, type: ChargeType, amount: Double, notes: String, owner: DogOwner, dog: Dog, paymentMethod: PaymentMethod, context: ModelContext) -> Bool {
        let newCharge = Charge(
            date: date,
            amount: amount,
            type: type,
            notes: notes.isEmpty ? nil : notes,
            owner: owner,
            dog: dog,
            isPaid: paymentMethod != .unpaid,
            paymentMethod: paymentMethod
        )
        context.insert(newCharge)
        // Audit logging would happen here via a service
        print("Saving charge: \(newCharge.id) for \(owner.ownerName)")
        return true
    }
}

/// View for adding a new charge record, now fully integrated with the data model and design system.
struct AddChargeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @StateObject private var viewModel: AddChargeViewModel
    
    @State private var selectedDate: Date = Date()
    @State private var selectedChargeType: ChargeType = .fullGroom
    @State private var selectedPaymentMethod: PaymentMethod = .creditCard
    @State private var selectedOwner: DogOwner?
    @State private var selectedDog: Dog?
    
    @State private var amountText: String = ""
    @State private var notes: String = ""
    
    @State private var showAmountError: Bool = false

    init() {
        _viewModel = StateObject(wrappedValue: AddChargeViewModel())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Client").font(AppFonts.headline)) {
                    Picker("Owner", selection: $selectedOwner) {
                        Text("Select Owner").tag(Optional<DogOwner>(nil))
                        ForEach(viewModel.owners) { owner in
                            Text(owner.ownerName).tag(Optional(owner))
                        }
                    }
                    .onChange(of: selectedOwner) { _, newOwner in
                        viewModel.fetchDogs(for: newOwner)
                        selectedDog = nil // Reset dog selection when owner changes
                    }
                    .accessibilityIdentifier("ownerPicker")
                    
                    if selectedOwner != nil {
                        Picker("Dog", selection: $selectedDog) {
                            Text("Select Dog").tag(Optional<Dog>(nil))
                            ForEach(viewModel.dogsForSelectedOwner) { dog in
                                Text(dog.name).tag(Optional(dog))
                            }
                        }
                        .disabled(viewModel.dogsForSelectedOwner.isEmpty)
                        .accessibilityIdentifier("dogPicker")
                    }
                }
                
                Section(header: Text("Charge Details").font(AppFonts.headline)) {
                    DatePicker("Charge Date", selection: $selectedDate, displayedComponents: .date)
                        .accessibilityIdentifier("chargeDatePicker")

                    Picker("Charge Type", selection: $selectedChargeType) {
                        ForEach(viewModel.chargeTypes, id: \.self) { type in
                            Text(type.displayName)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("chargeTypePicker")
                    
                    HStack {
                        Text("Amount")
                        Spacer()
                        Text("$")
                            .foregroundColor(AppColors.textSecondary)
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .accessibilityIdentifier("chargeAmountField")
                    }

                    if showAmountError {
                        Text("Please enter a valid amount.")
                            .foregroundColor(AppColors.danger)
                            .font(AppFonts.caption)
                    }
                }
                
                Section(header: Text("Payment").font(AppFonts.headline)) {
                    Picker("Payment Method", selection: $selectedPaymentMethod) {
                        ForEach(viewModel.paymentMethods) { method in
                            Text(method.rawValue).tag(method)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("paymentMethodPicker")
                }

                Section(header: Text("Notes").font(AppFonts.headline)) {
                    TextField("Optional notes...", text: $notes, axis: .vertical)
                        .lineLimit(3...)
                        .frame(minHeight: 80)
                        .accessibilityIdentifier("chargeNotesField")
                }
            }
            .navigationTitle("Add Charge")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveCharge() }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                if selectedChargeType == .custom { // Set a default if needed
                    selectedChargeType = viewModel.chargeTypes.first ?? .fullGroom
                }
            }
        }
    }

    /// Checks if all required inputs are valid to allow saving.
    private var canSave: Bool {
        guard selectedOwner != nil,
              selectedDog != nil,
              let amount = Double(amountText),
              amount > 0 else {
            return false
        }
        return true
    }

    /// Attempts to save the charge data.
    private func saveCharge() {
        guard let owner = selectedOwner,
              let dog = selectedDog,
              let amount = Double(amountText) else {
            // This case should be prevented by the disabled save button, but is good practice.
            return
        }

        let success = viewModel.saveCharge(
            date: selectedDate,
            type: selectedChargeType,
            amount: amount,
            notes: notes,
            owner: owner,
            dog: dog,
            paymentMethod: selectedPaymentMethod,
            context: modelContext
        )
        
        if success {
            dismiss()
        }
        // The view model could also publish an error to be shown here.
    }
}


// MARK: - Preview
#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: DogOwner.self, Dog.self, Charge.self, configurations: [config])

    // Create sample data for the preview
    let owner1 = DogOwner(ownerName: "Jane Smith")
    let dog1A = Dog(name: "Buddy", owner: owner1)
    let dog1B = Dog(name: "Shadow", owner: owner1)
    owner1.dogs = [dog1A, dog1B]
    
    let owner2 = DogOwner(ownerName: "Carlos Gomez")
    let dog2A = Dog(name: "Luna", owner: owner2)
    owner2.dogs = [dog2A]
    
    container.mainContext.insert(owner1)
    container.mainContext.insert(owner2)

    return AddChargeView()
        .modelContainer(container)
}//
// MARK: - AddChargeView (Tokenized, Modular, Auditable Charge Entry UI)
//
//  AddChargeView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//  ENHANCED: Fully integrated with data models, design tokens, and payment method selection.
//

import SwiftUI
import SwiftData

/// ViewModel for AddChargeView, handles data sources, selections, and saving logic.
@MainActor
final class AddChargeViewModel: ObservableObject {
    @Published var owners: [DogOwner] = []
    @Published var dogsForSelectedOwner: [Dog] = []
    
    // In a real app, this would be fetched from a service or config
    let chargeTypes: [ChargeType] = ChargeType.allCases
    let paymentMethods: [PaymentMethod] = PaymentMethod.allCases
    
    private var dataStore: DataStoreService
    
    init(dataStore: DataStoreService = .shared) {
        self.dataStore = dataStore
        Task {
            await fetchOwners()
        }
    }
    
    func fetchOwners() async {
        self.owners = await dataStore.fetchAll(DogOwner.self).sorted { $0.ownerName < $1.ownerName }
    }
    
    func fetchDogs(for owner: DogOwner?) {
        guard let owner = owner else {
            self.dogsForSelectedOwner = []
            return
        }
        // Assuming DogOwner model has a 'dogs' relationship
        self.dogsForSelectedOwner = owner.dogs.sorted { $0.name < $1.name }
    }

    func saveCharge(date: Date, type: ChargeType, amount: Double, notes: String, owner: DogOwner, dog: Dog, paymentMethod: PaymentMethod, context: ModelContext) -> Bool {
        let newCharge = Charge(
            date: date,
            amount: amount,
            type: type,
            notes: notes.isEmpty ? nil : notes,
            owner: owner,
            dog: dog,
            isPaid: paymentMethod != .unpaid,
            paymentMethod: paymentMethod
        )
        context.insert(newCharge)
        // Audit logging would happen here via a service
        print("Saving charge: \(newCharge.id) for \(owner.ownerName)")
        return true
    }
}

/// View for adding a new charge record, now fully integrated with the data model and design system.
struct AddChargeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @StateObject private var viewModel: AddChargeViewModel
    
    @State private var selectedDate: Date = Date()
    @State private var selectedChargeType: ChargeType = .fullGroom
    @State private var selectedPaymentMethod: PaymentMethod = .creditCard
    @State private var selectedOwner: DogOwner?
    @State private var selectedDog: Dog?
    
    @State private var amountText: String = ""
    @State private var notes: String = ""
    
    @State private var showAmountError: Bool = false

    init() {
        _viewModel = StateObject(wrappedValue: AddChargeViewModel())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Client").font(AppFonts.headline)) {
                    Picker("Owner", selection: $selectedOwner) {
                        Text("Select Owner").tag(Optional<DogOwner>(nil))
                        ForEach(viewModel.owners) { owner in
                            Text(owner.ownerName).tag(Optional(owner))
                        }
                    }
                    .onChange(of: selectedOwner) { _, newOwner in
                        viewModel.fetchDogs(for: newOwner)
                        selectedDog = nil // Reset dog selection when owner changes
                    }
                    .accessibilityIdentifier("ownerPicker")
                    
                    if selectedOwner != nil {
                        Picker("Dog", selection: $selectedDog) {
                            Text("Select Dog").tag(Optional<Dog>(nil))
                            ForEach(viewModel.dogsForSelectedOwner) { dog in
                                Text(dog.name).tag(Optional(dog))
                            }
                        }
                        .disabled(viewModel.dogsForSelectedOwner.isEmpty)
                        .accessibilityIdentifier("dogPicker")
                    }
                }
                
                Section(header: Text("Charge Details").font(AppFonts.headline)) {
                    DatePicker("Charge Date", selection: $selectedDate, displayedComponents: .date)
                        .accessibilityIdentifier("chargeDatePicker")

                    Picker("Charge Type", selection: $selectedChargeType) {
                        ForEach(viewModel.chargeTypes, id: \.self) { type in
                            Text(type.displayName)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("chargeTypePicker")
                    
                    HStack {
                        Text("Amount")
                        Spacer()
                        Text("$")
                            .foregroundColor(AppColors.textSecondary)
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .accessibilityIdentifier("chargeAmountField")
                    }

                    if showAmountError {
                        Text("Please enter a valid amount.")
                            .foregroundColor(AppColors.danger)
                            .font(AppFonts.caption)
                    }
                }
                
                Section(header: Text("Payment").font(AppFonts.headline)) {
                    Picker("Payment Method", selection: $selectedPaymentMethod) {
                        ForEach(viewModel.paymentMethods) { method in
                            Text(method.rawValue).tag(method)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("paymentMethodPicker")
                }

                Section(header: Text("Notes").font(AppFonts.headline)) {
                    TextField("Optional notes...", text: $notes, axis: .vertical)
                        .lineLimit(3...)
                        .frame(minHeight: 80)
                        .accessibilityIdentifier("chargeNotesField")
                }
            }
            .navigationTitle("Add Charge")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveCharge() }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                if selectedChargeType == .custom { // Set a default if needed
                    selectedChargeType = viewModel.chargeTypes.first ?? .fullGroom
                }
            }
        }
    }

    /// Checks if all required inputs are valid to allow saving.
    private var canSave: Bool {
        guard selectedOwner != nil,
              selectedDog != nil,
              let amount = Double(amountText),
              amount > 0 else {
            return false
        }
        return true
    }

    /// Attempts to save the charge data.
    private func saveCharge() {
        guard let owner = selectedOwner,
              let dog = selectedDog,
              let amount = Double(amountText) else {
            // This case should be prevented by the disabled save button, but is good practice.
            return
        }

        let success = viewModel.saveCharge(
            date: selectedDate,
            type: selectedChargeType,
            amount: amount,
            notes: notes,
            owner: owner,
            dog: dog,
            paymentMethod: selectedPaymentMethod,
            context: modelContext
        )
        
        if success {
            dismiss()
        }
        // The view model could also publish an error to be shown here.
    }
}


// MARK: - Preview
#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: DogOwner.self, Dog.self, Charge.self, configurations: [config])

    // Create sample data for the preview
    let owner1 = DogOwner(ownerName: "Jane Smith")
    let dog1A = Dog(name: "Buddy", owner: owner1)
    let dog1B = Dog(name: "Shadow", owner: owner1)
    owner1.dogs = [dog1A, dog1B]
    
    let owner2 = DogOwner(ownerName: "Carlos Gomez")
    let dog2A = Dog(name: "Luna", owner: owner2)
    owner2.dogs = [dog2A]
    
    container.mainContext.insert(owner1)
    container.mainContext.insert(owner2)

    return AddChargeView()
        .modelContainer(container)
}

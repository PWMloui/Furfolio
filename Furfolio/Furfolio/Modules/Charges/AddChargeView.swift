//
// MARK: - AddChargeView (Tokenized, Modular, Auditable Charge Entry UI)
//
//  AddChargeView.swift
//  Furfolio
//
//  ENHANCED 2025: Auditable, BI/Compliance-Ready Charge Entry UI
//

import SwiftUI
import SwiftData
import AVFoundation // For VoiceOver announcements

// MARK: - Audit/Event Logging

fileprivate struct AddChargeAuditEvent: Codable {
    let timestamp: Date
    let operation: String        // "selectOwner", "selectDog", "setChargeType", "setDate", "setAmount", "setPayment", "setNotes", "save", "saveFail", "cancel"
    let owner: String?
    let dog: String?
    let chargeType: String?
    let date: Date?
    let amount: String?
    let paymentMethod: String?
    let notes: String?
    let tags: [String]
    let detail: String?
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[\(operation.capitalized)]\(owner != nil ? " Owner: \(owner!)" : "")\(dog != nil ? " Dog: \(dog!)" : "")\(chargeType != nil ? " Type: \(chargeType!)" : "")\(amount != nil ? " $\(amount!)" : "")\(paymentMethod != nil ? " Method: \(paymentMethod!)" : "")\(date != nil ? " Date: \(dateStr)" : "")\(tags.isEmpty ? "" : " [\(tags.joined(separator: ","))]")\(detail != nil ? " : \(detail!)" : "")"
    }
}

fileprivate final class AddChargeAudit {
    static private(set) var log: [AddChargeAuditEvent] = []

    /// Records a new audit event with given parameters.
    static func record(
        operation: String,
        owner: String? = nil,
        dog: String? = nil,
        chargeType: String? = nil,
        date: Date? = nil,
        amount: String? = nil,
        paymentMethod: String? = nil,
        notes: String? = nil,
        tags: [String] = [],
        detail: String? = nil
    ) {
        let event = AddChargeAuditEvent(
            timestamp: Date(),
            operation: operation,
            owner: owner,
            dog: dog,
            chargeType: chargeType,
            date: date,
            amount: amount,
            paymentMethod: paymentMethod,
            notes: notes,
            tags: tags,
            detail: detail
        )
        log.append(event)
        if log.count > 200 { log.removeFirst() }
    }

    /// Exports the last audit event as a pretty-printed JSON string.
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    /// Provides an accessibility summary string for the last audit event.
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No add charge actions recorded."
    }
    
    /// ENHANCEMENT: Export audit log as CSV string with specified columns.
    static func exportCSV() -> String {
        let header = "timestamp,operation,owner,dog,chargeType,date,amount,paymentMethod,notes,tags,detail"
        let csvRows = log.map { event -> String in
            let dateFormatter = ISO8601DateFormatter()
            let timestampStr = dateFormatter.string(from: event.timestamp)
            let dateStr = event.date.map { dateFormatter.string(from: $0) } ?? ""
            let tagsStr = event.tags.joined(separator: ";")
            
            // Escape quotes and commas in fields by wrapping in quotes and doubling internal quotes
            func escapeCSV(_ field: String?) -> String {
                guard let field = field else { return "" }
                if field.contains(",") || field.contains("\"") || field.contains("\n") {
                    let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
                    return "\"\(escaped)\""
                }
                return field
            }
            
            return [
                escapeCSV(timestampStr),
                escapeCSV(event.operation),
                escapeCSV(event.owner),
                escapeCSV(event.dog),
                escapeCSV(event.chargeType),
                escapeCSV(dateStr),
                escapeCSV(event.amount),
                escapeCSV(event.paymentMethod),
                escapeCSV(event.notes),
                escapeCSV(tagsStr),
                escapeCSV(event.detail)
            ].joined(separator: ",")
        }
        return ([header] + csvRows).joined(separator: "\n")
    }
    
    /// ENHANCEMENT: Returns the most frequent charge type used in the audit log.
    static var mostFrequentChargeType: String? {
        let chargeTypes = log.compactMap { $0.chargeType }
        guard !chargeTypes.isEmpty else { return nil }
        let counts = chargeTypes.reduce(into: [:]) { counts, type in
            counts[type, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }
    
    /// ENHANCEMENT: Returns the total number of successful 'save' operations recorded.
    static var totalChargesAdded: Int {
        log.filter { $0.operation == "save" }.count
    }
}

// MARK: - ViewModel for AddChargeView

@MainActor
final class AddChargeViewModel: ObservableObject {
    @Published var owners: [DogOwner] = []
    @Published var dogsForSelectedOwner: [Dog] = []
    
    let chargeTypes: [ChargeType] = ChargeType.allCases
    let paymentMethods: [PaymentMethod] = PaymentMethod.allCases
    
    private var dataStore: DataStoreService
    
    init(dataStore: DataStoreService = .shared) {
        self.dataStore = dataStore
        Task { await fetchOwners() }
    }
    
    func fetchOwners() async {
        self.owners = await dataStore.fetchAll(DogOwner.self).sorted { $0.ownerName < $1.ownerName }
    }
    
    func fetchDogs(for owner: DogOwner?) {
        guard let owner = owner else {
            self.dogsForSelectedOwner = []
            return
        }
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
        AddChargeAudit.record(
            operation: "save",
            owner: owner.ownerName,
            dog: dog.name,
            chargeType: type.displayName,
            date: date,
            amount: String(format: "%.2f", amount),
            paymentMethod: paymentMethod.rawValue,
            notes: notes,
            tags: ["save"]
        )
        return true
    }
}

// MARK: - AddChargeView

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
                        selectedDog = nil
                        AddChargeAudit.record(
                            operation: "selectOwner",
                            owner: newOwner?.ownerName,
                            tags: ["ownerSelect"]
                        )
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
                        .onChange(of: selectedDog) { _, newDog in
                            AddChargeAudit.record(
                                operation: "selectDog",
                                owner: selectedOwner?.ownerName,
                                dog: newDog?.name,
                                tags: ["dogSelect"]
                            )
                        }
                        .accessibilityIdentifier("dogPicker")
                    }
                }
                
                Section(header: Text("Charge Details").font(AppFonts.headline)) {
                    DatePicker("Charge Date", selection: $selectedDate, displayedComponents: .date)
                        .onChange(of: selectedDate) { _, newDate in
                            AddChargeAudit.record(
                                operation: "setDate",
                                date: newDate,
                                tags: ["dateChange"]
                            )
                        }
                        .accessibilityIdentifier("chargeDatePicker")

                    Picker("Charge Type", selection: $selectedChargeType) {
                        ForEach(viewModel.chargeTypes, id: \.self) { type in
                            Text(type.displayName)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedChargeType) { _, newType in
                        AddChargeAudit.record(
                            operation: "setChargeType",
                            chargeType: newType.displayName,
                            tags: ["chargeTypeChange"]
                        )
                    }
                    .accessibilityIdentifier("chargeTypePicker")
                    
                    HStack {
                        Text("Amount")
                        Spacer()
                        Text("$").foregroundColor(AppColors.textSecondary)
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .onChange(of: amountText) { _, newAmount in
                                AddChargeAudit.record(
                                    operation: "setAmount",
                                    amount: newAmount,
                                    tags: ["amountChange"]
                                )
                            }
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
                    .onChange(of: selectedPaymentMethod) { _, newMethod in
                        AddChargeAudit.record(
                            operation: "setPayment",
                            paymentMethod: newMethod.rawValue,
                            tags: ["paymentMethodChange"]
                        )
                    }
                    .accessibilityIdentifier("paymentMethodPicker")
                }

                Section(header: Text("Notes").font(AppFonts.headline)) {
                    TextField("Optional notes...", text: $notes, axis: .vertical)
                        .lineLimit(3...)
                        .frame(minHeight: 80)
                        .onChange(of: notes) { _, newNotes in
                            AddChargeAudit.record(
                                operation: "setNotes",
                                notes: newNotes,
                                tags: ["notesChange"]
                            )
                        }
                        .accessibilityIdentifier("chargeNotesField")
                }
            }
            .navigationTitle("Add Charge")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        AddChargeAudit.record(
                            operation: "cancel",
                            owner: selectedOwner?.ownerName,
                            dog: selectedDog?.name,
                            chargeType: selectedChargeType.displayName,
                            date: selectedDate,
                            amount: amountText,
                            paymentMethod: selectedPaymentMethod.rawValue,
                            notes: notes,
                            tags: ["cancel"]
                        )
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveCharge() }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                if selectedChargeType == .custom {
                    selectedChargeType = viewModel.chargeTypes.first ?? .fullGroom
                }
            }
#if DEBUG
            // ENHANCEMENT: DEV overlay showing last 3 audit events and most frequent charge type.
            .overlay(
                VStack(alignment: .leading, spacing: 4) {
                    Divider()
                    Text("DEV AUDIT LOG (last 3 events):")
                        .font(.caption).bold()
                    ForEach(AddChargeAudit.log.suffix(3).reversed(), id: \.timestamp) { event in
                        Text(event.accessibilityLabel)
                            .font(.caption2)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    Text("Most Frequent Charge Type: \(AddChargeAudit.mostFrequentChargeType ?? "N/A")")
                        .font(.caption).italic()
                }
                .padding(8)
                .background(Color.black.opacity(0.6))
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(),
                alignment: .bottom
            )
#endif
        }
    }

    private var canSave: Bool {
        guard selectedOwner != nil,
              selectedDog != nil,
              let amount = Double(amountText),
              amount > 0 else {
            return false
        }
        return true
    }

    private func saveCharge() {
        guard let owner = selectedOwner,
              let dog = selectedDog,
              let amount = Double(amountText) else {
            AddChargeAudit.record(
                operation: "saveFail",
                owner: selectedOwner?.ownerName,
                dog: selectedDog?.name,
                chargeType: selectedChargeType.displayName,
                date: selectedDate,
                amount: amountText,
                paymentMethod: selectedPaymentMethod.rawValue,
                notes: notes,
                tags: ["saveFail"],
                detail: "Missing or invalid data"
            )
            showAmountError = true
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
            // ENHANCEMENT: Post VoiceOver announcement on successful save.
            let announcement = "Charge for \(dog.name) added for \(owner.ownerName)"
            UIAccessibility.post(notification: .announcement, argument: announcement)
            dismiss()
        }
    }
}

// MARK: - Audit/Admin Accessors

public enum AddChargeAuditAdmin {
    public static var lastSummary: String { AddChargeAudit.accessibilitySummary }
    public static var lastJSON: String? { AddChargeAudit.exportLastJSON() }
    /// ENHANCEMENT: Expose CSV export of audit log.
    public static var exportCSV: String { AddChargeAudit.exportCSV() }
    /// ENHANCEMENT: Expose most frequent charge type.
    public static var mostFrequentChargeType: String? { AddChargeAudit.mostFrequentChargeType }
    /// ENHANCEMENT: Expose total number of charges added.
    public static var totalChargesAdded: Int { AddChargeAudit.totalChargesAdded }
    public static func recentEvents(limit: Int = 5) -> [String] {
        AddChargeAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
}

// MARK: - Preview
#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: DogOwner.self, Dog.self, Charge.self, configurations: [config])

    let owner1 = DogOwner(ownerName: "Jane Smith")
    let dog1A = Dog(name: "Buddy", owner: owner1)
    let dog1B = Dog(name: "Shadow", owner: owner1)
    owner1.dogs = [dog1A, dog1B]
    let owner2 = DogOwner(ownerName: "Carlos Gomez")
    let dog2A = Dog(name: "Luna", owner: owner2)
    owner2.dogs = [dog2A]
    container.mainContext.insert(owner1)
    container.mainContext.insert(owner2)

    return AddChargeView().modelContainer(container)
}

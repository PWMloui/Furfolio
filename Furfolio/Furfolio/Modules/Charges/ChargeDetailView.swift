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

    /// Records an audit event with provided details.
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

    /// Exports the last audit event as pretty-printed JSON string.
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    
    /// ENHANCEMENT: Exports all audit events as CSV string with specified columns.
    static func exportCSV() -> String {
        let header = "timestamp,operation,owner,dog,chargeType,date,amount,paymentMethod,notes,tags,detail"
        let dateFormatter = ISO8601DateFormatter()
        let csvLines = log.map { event -> String in
            let timestamp = dateFormatter.string(from: event.timestamp)
            let operation = event.operation.csvEscaped
            let owner = event.owner?.csvEscaped ?? ""
            let dog = event.dog?.csvEscaped ?? ""
            let chargeType = event.chargeType?.csvEscaped ?? ""
            let date = event.date.map { dateFormatter.string(from: $0) } ?? ""
            let amount = event.amount?.csvEscaped ?? ""
            let paymentMethod = event.paymentMethod?.csvEscaped ?? ""
            let notes = event.notes?.csvEscaped ?? ""
            let tags = event.tags.joined(separator: ";").csvEscaped
            let detail = event.detail?.csvEscaped ?? ""
            return [timestamp, operation, owner, dog, chargeType, date, amount, paymentMethod, notes, tags, detail].joined(separator: ",")
        }
        return ([header] + csvLines).joined(separator: "\n")
    }
    
    /// ENHANCEMENT: Returns the chargeType string most frequently used in audit log (if any).
    static var mostFrequentChargeType: String? {
        let chargeTypes = log.compactMap { $0.chargeType }
        let counts = Dictionary(chargeTypes.map { ($0, 1) }, uniquingKeysWith: +)
        return counts.max(by: { $0.value < $1.value })?.key
    }
    
    /// ENHANCEMENT: Returns total number of 'save' operations recorded.
    static var totalChargesAdded: Int {
        log.filter { $0.operation == "save" }.count
    }

    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No add charge actions recorded."
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
            // ENHANCEMENT: DEV overlay showing last 3 audit events and most frequent charge type for debugging.
            .overlay(
                VStack(alignment: .leading, spacing: 4) {
                    Divider()
                    Text("DEV Audit Log (Last 3):")
                        .font(.caption).bold()
                    ForEach(AddChargeAudit.log.suffix(3).reversed(), id: \.timestamp) { event in
                        Text(event.accessibilityLabel)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    Text("Most Frequent Charge Type: \(AddChargeAudit.mostFrequentChargeType ?? "N/A")")
                        .font(.caption2).italic()
                }
                .padding(8)
                .background(Color.black.opacity(0.75))
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding()
                , alignment: .bottomLeading
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
            // ENHANCEMENT: Post VoiceOver announcement on successful charge save.
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
    public static func exportCSV() -> String { AddChargeAudit.exportCSV() }
    /// ENHANCEMENT: Expose most frequent charge type.
    public static var mostFrequentChargeType: String? { AddChargeAudit.mostFrequentChargeType }
    /// ENHANCEMENT: Expose total charges added count.
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

// MARK: - String extension for CSV escaping
fileprivate extension String {
    /// Escapes string for CSV output, wrapping in quotes if needed and escaping internal quotes.
    var csvEscaped: String {
        if self.contains(",") || self.contains("\"") || self.contains("\n") {
            let escaped = self.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        } else {
            return self
        }
    }
}

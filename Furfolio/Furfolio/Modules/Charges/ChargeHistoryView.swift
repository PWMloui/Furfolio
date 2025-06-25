//
// MARK: - ChargeHistoryView (Tokenized, Modular, Auditable Charge History UI)
//
//  ChargeHistoryView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Tokenized, Modular, Analytics-Ready
//

import SwiftUI

// MARK: - Audit/Event Logging

fileprivate struct ChargeHistoryAuditEvent: Codable {
    let timestamp: Date
    let operation: String    // "search", "add", "delete", "select"
    let chargeID: UUID?
    let type: String?
    let amount: Double?
    let notes: String?
    let searchText: String?
    let tags: [String]
    let detail: String?
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        var parts = [operation.capitalized]
        if let t = type { parts.append("Type: \(t)") }
        if let a = amount { parts.append("Amount: $\(String(format: "%.2f", a))") }
        if let s = searchText, !s.isEmpty { parts.append("Search: \(s)") }
        if let n = notes, !n.isEmpty { parts.append("Notes: \(n)") }
        if let id = chargeID { parts.append("ID: \(id.uuidString.prefix(8))") }
        if !tags.isEmpty { parts.append("[\(tags.joined(separator: ","))]") }
        parts.append("at \(dateStr)")
        if let d = detail, !d.isEmpty { parts.append(": \(d)") }
        return parts.joined(separator: " ")
    }
}

fileprivate final class ChargeHistoryAudit {
    static private(set) var log: [ChargeHistoryAuditEvent] = []

    static func record(
        operation: String,
        charge: Charge? = nil,
        searchText: String? = nil,
        tags: [String] = [],
        detail: String? = nil
    ) {
        let event = ChargeHistoryAuditEvent(
            timestamp: Date(),
            operation: operation,
            chargeID: charge?.id,
            type: charge?.type,
            amount: charge?.amount,
            notes: charge?.notes,
            searchText: searchText,
            tags: tags,
            detail: detail
        )
        log.append(event)
        if log.count > 150 { log.removeFirst() }
    }

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No charge history events recorded."
    }
}

// MARK: - ChargeHistoryView

struct ChargeHistoryView: View {
    @State private var charges: [Charge] = []
    @State private var searchText: String = ""
    @State private var showingAddCharge = false
    @State private var selectedCharge: Charge? = nil

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
        NavigationSplitView {
            List(selection: $selectedCharge) {
                if filteredCharges.isEmpty {
                    VStack(spacing: AppSpacing.medium) {
                        Text(LocalizedStringKey("No charges found."))
                            .font(AppFonts.headline)
                            .foregroundColor(AppColors.secondaryText)
                        Text(LocalizedStringKey("Add a charge to get started."))
                            .font(AppFonts.subheadline)
                            .foregroundColor(AppColors.secondaryText)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(filteredCharges) { charge in
                        NavigationLink(value: charge) {
                            ChargeRowView(charge: charge)
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                if let idx = charges.firstIndex(where: { $0.id == charge.id }) {
                                    deleteCharge(at: IndexSet(integer: idx))
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .onTapGesture {
                            ChargeHistoryAudit.record(
                                operation: "select",
                                charge: charge,
                                tags: ["select"],
                                detail: "Charge selected"
                            )
                        }
                    }
                    .onDelete(perform: deleteCharge)
                    .accessibilityIdentifier("ChargeRowDeleteAction")
                }
            }
            .navigationTitle(LocalizedStringKey("Charge History"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddCharge = true }) {
                        Image(systemName: "plus.circle.fill")
                            .accessibilityIdentifier("AddChargeButtonIcon")
                    }
                    .accessibilityLabel(LocalizedStringKey("Add Charge"))
                    .accessibilityIdentifier("AddChargeButton")
                }
            }
            .searchable(text: $searchText, prompt: LocalizedStringKey("Search charge types"))
            .onChange(of: searchText) { val in
                ChargeHistoryAudit.record(
                    operation: "search",
                    searchText: val,
                    tags: ["search"],
                    detail: "User searched"
                )
            }
            .accessibilityIdentifier("ChargeSearchField")
            .sheet(isPresented: $showingAddCharge) {
                AddChargeView(viewModel: AddChargeViewModel()) {
                    loadCharges()
                    ChargeHistoryAudit.record(
                        operation: "add",
                        tags: ["add"],
                        detail: "Charge added"
                    )
                }
            }
            .onAppear(perform: loadCharges)
        } detail: {
            if let charge = selectedCharge {
                ChargeDetailView(charge: charge)
            } else {
                Text(LocalizedStringKey("Select a charge to view details"))
                    .font(AppFonts.subheadline)
                    .foregroundColor(AppColors.tertiaryText)
            }
        }
    }

    private func loadCharges() {
        charges = sampleCharges
    }

    private func deleteCharge(at offsets: IndexSet) {
        let deleted = offsets.map { charges[$0] }
        charges.remove(atOffsets: offsets)
        for charge in deleted {
            ChargeHistoryAudit.record(
                operation: "delete",
                charge: charge,
                tags: ["delete"],
                detail: "Charge deleted"
            )
        }
    }
}

// MARK: - Audit/Admin Accessors

public enum ChargeHistoryAuditAdmin {
    public static var lastSummary: String { ChargeHistoryAudit.accessibilitySummary }
    public static var lastJSON: String? { ChargeHistoryAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        ChargeHistoryAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
}

// MARK: - Charge Row View

struct ChargeRowView: View {
    let charge: Charge

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
            HStack(spacing: AppSpacing.medium) {
                Text(charge.type)
                    .font(AppFonts.headline)
                Spacer()
                Text("$\(String(format: "%.2f", charge.amount))")
                    .font(AppFonts.headline)
                    .foregroundColor(AppColors.success)
            }
            Text(formattedDate)
                .font(AppFonts.caption)
                .foregroundColor(AppColors.secondaryText)
            if let notes = charge.notes, !notes.isEmpty {
                Text(notes)
                    .font(AppFonts.caption2)
                    .foregroundColor(AppColors.secondaryText)
                    .italic()
            }
        }
        .padding(.vertical, AppSpacing.small)
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
                        .foregroundColor(AppColors.secondaryText)
                }
                HStack {
                    Text(LocalizedStringKey("Amount"))
                    Spacer()
                    Text("$\(String(format: "%.2f", charge.amount))")
                        .foregroundColor(AppColors.secondaryText)
                }
                HStack {
                    Text(LocalizedStringKey("Date"))
                    Spacer()
                    Text(formattedDate)
                        .foregroundColor(AppColors.secondaryText)
                }
                if let notes = charge.notes, !notes.isEmpty {
                    Section(header: Text(LocalizedStringKey("Notes"))) {
                        Text(notes)
                            .foregroundColor(AppColors.secondaryText)
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
        ChargeHistoryView()
            .environment(\.locale, .init(identifier: "en"))
            .accentColor(AppColors.success)
            .font(AppFonts.body)
    }
}
#endif

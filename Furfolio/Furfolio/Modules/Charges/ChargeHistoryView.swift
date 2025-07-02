//
// MARK: - ChargeHistoryView (Tokenized, Modular, Auditable Charge History UI)
//
//  ChargeHistoryView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Tokenized, Modular, Analytics-Ready
//

import SwiftUI
import Combine
import AVFoundation

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

    // MARK: - Record an audit event with optional charge and search text
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

        // Accessibility: Post VoiceOver announcement on add, delete, or select
        if ["add", "delete", "select"].contains(operation), let chargeType = charge?.type {
            let announcement = "Charge for \(chargeType) \(operation)ed"
            UIAccessibility.post(notification: .announcement, argument: announcement)
        }
    }

    // MARK: - Export last event as JSON string
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    // MARK: - Export all audit events as CSV string
    /// CSV includes: timestamp,operation,chargeID,type,amount,notes,searchText,tags,detail
    static func exportCSV() -> String {
        let header = "timestamp,operation,chargeID,type,amount,notes,searchText,tags,detail"
        let rows = log.map { event -> String in
            let timestampStr = ISO8601DateFormatter().string(from: event.timestamp)
            let chargeIDStr = event.chargeID?.uuidString ?? ""
            let typeStr = event.type?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""
            let amountStr = event.amount != nil ? String(format: "%.2f", event.amount!) : ""
            let notesStr = event.notes?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""
            let searchTextStr = event.searchText?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""
            let tagsStr = event.tags.joined(separator: ";").replacingOccurrences(of: "\"", with: "\"\"")
            let detailStr = event.detail?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""

            // CSV fields are wrapped in quotes if they contain commas or quotes
            func csvField(_ str: String) -> String {
                if str.contains(",") || str.contains("\"") || str.contains("\n") {
                    return "\"\(str)\""
                } else {
                    return str
                }
            }

            return [
                csvField(timestampStr),
                csvField(event.operation),
                csvField(chargeIDStr),
                csvField(typeStr),
                csvField(amountStr),
                csvField(notesStr),
                csvField(searchTextStr),
                csvField(tagsStr),
                csvField(detailStr)
            ].joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }

    // MARK: - Accessibility summary of last event
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No charge history events recorded."
    }

    // MARK: - Analytics: Most frequent charge type among add/select/delete events
    static var mostFrequentChargeType: String? {
        let relevantEvents = log.filter { ["add", "select", "delete"].contains($0.operation) && $0.type != nil }
        let frequency = Dictionary(grouping: relevantEvents, by: { $0.type! }).mapValues { $0.count }
        return frequency.max(by: { $0.value < $1.value })?.key
    }

    // MARK: - Analytics: Total number of "add" events
    static var totalChargesAdded: Int {
        log.filter { $0.operation == "add" }.count
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
            // DEV overlay: Show last 3 audit events and most frequent charge type in DEBUG builds
            #if DEBUG
            .overlay(
                VStack(spacing: 4) {
                    Spacer()
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Audit Events (Last 3):")
                            .font(.caption)
                            .foregroundColor(.white)
                            .bold()
                        ForEach(Array(ChargeHistoryAudit.log.suffix(3).enumerated()), id: \.offset) { _, event in
                            Text(event.accessibilityLabel)
                                .font(.caption2)
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                        if let frequentType = ChargeHistoryAudit.mostFrequentChargeType {
                            Text("Most Frequent Charge Type: \(frequentType)")
                                .font(.caption)
                                .foregroundColor(.yellow)
                                .bold()
                        } else {
                            Text("Most Frequent Charge Type: None")
                                .font(.caption)
                                .foregroundColor(.yellow)
                                .bold()
                        }
                    }
                    .padding(8)
                    .background(Color.black.opacity(0.75))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            )
            #endif
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
    /// Export all audit events as CSV string
    public static func exportCSV() -> String { ChargeHistoryAudit.exportCSV() }
    /// Most frequent charge type among add/select/delete events
    public static var mostFrequentChargeType: String? { ChargeHistoryAudit.mostFrequentChargeType }
    /// Total number of "add" events recorded
    public static var totalChargesAdded: Int { ChargeHistoryAudit.totalChargesAdded }
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

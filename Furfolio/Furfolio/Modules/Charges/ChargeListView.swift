//
//  ChargeListView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Tokenized, Modular Charge History List
//

import SwiftUI

// MARK: - Audit/Event Logging

fileprivate struct ChargeListAuditEvent: Codable {
    let timestamp: Date
    let operation: String    // "search", "add", "delete", "tap"
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

fileprivate final class ChargeListAudit {
    static private(set) var log: [ChargeListAuditEvent] = []

    static func record(
        operation: String,
        charge: Charge? = nil,
        searchText: String? = nil,
        tags: [String] = [],
        detail: String? = nil
    ) {
        let event = ChargeListAuditEvent(
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
        log.last?.accessibilityLabel ?? "No charge list events recorded."
    }
}

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
                            ChargeRowView(charge: charge)
                                .accessibilityIdentifier("chargeRow_\(charge.id.uuidString)")
                                .onTapGesture {
                                    ChargeListAudit.record(
                                        operation: "tap",
                                        charge: charge,
                                        tags: ["rowTap"]
                                    )
                                }
                        }
                    }
                    .onDelete { offsets in
                        let deleted = offsets.map { viewModel.filteredCharges[$0] }
                        viewModel.deleteCharge(at: offsets)
                        for charge in deleted {
                            ChargeListAudit.record(
                                operation: "delete",
                                charge: charge,
                                tags: ["delete"],
                                detail: "Charge deleted"
                            )
                        }
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("Charge History"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddCharge = true }) {
                        Image(systemName: "plus.circle.fill")
                    }
                    .accessibilityIdentifier("addChargeButton")
                }
            }
            .searchable(text: $viewModel.searchText, prompt: LocalizedStringKey("Search charge types"))
            .onChange(of: viewModel.searchText) { val in
                ChargeListAudit.record(
                    operation: "search",
                    searchText: val,
                    tags: ["search"],
                    detail: "User searched"
                )
            }
            .accessibilityIdentifier("chargeSearchBar")
            .sheet(isPresented: $showingAddCharge) {
                AddChargeView(viewModel: AddChargeViewModel()) {
                    Task { await viewModel.fetchCharges() }
                    ChargeListAudit.record(
                        operation: "add",
                        tags: ["add"],
                        detail: "Charge added"
                    )
                }
            }
            .task {
                await viewModel.fetchCharges()
            }
        }
    }
}

// MARK: - Audit/Admin Accessors

public enum ChargeListAuditAdmin {
    public static var lastSummary: String { ChargeListAudit.accessibilitySummary }
    public static var lastJSON: String? { ChargeListAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        ChargeListAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
}

// MARK: - Charge Row View

struct ChargeRowView: View {
    let charge: Charge

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            HStack {
                Text(charge.type)
                    .font(AppFonts.headline)
                Spacer()
                Text("$\(String(format: "%.2f", charge.amount))")
                    .font(AppFonts.headline)
                    .foregroundColor(AppColors.success)
            }
            Text(charge.date, style: .date)
                .font(AppFonts.caption)
                .foregroundColor(AppColors.secondaryText)
            if let notes = charge.notes, !notes.isEmpty {
                Text(notes)
                    .font(AppFonts.caption2)
                    .italic()
                    .foregroundColor(AppColors.secondaryText)
            }
        }
        .padding(.vertical, AppSpacing.small)
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
        ChargeListView()
            .environment(\.colorScheme, .light)
    }
}
#endif

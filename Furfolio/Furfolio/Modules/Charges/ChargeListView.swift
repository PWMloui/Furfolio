//
//  ChargeListView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Tokenized, Modular Charge History List
//

import SwiftUI
import Combine
import AVFoundation

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
    
    // MARK: - Record audit event and post VoiceOver announcement for add/delete/tap
    
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
        
        // Accessibility: Post VoiceOver announcement on add, delete, or tap events
        if ["add", "delete", "tap"].contains(operation), let type = charge?.type {
            let announcement: String
            switch operation {
            case "add":
                announcement = "Charge for \(type) added"
            case "delete":
                announcement = "Charge for \(type) deleted"
            case "tap":
                announcement = "Charge for \(type) selected"
            default:
                announcement = ""
            }
            if !announcement.isEmpty {
                DispatchQueue.main.async {
                    UIAccessibility.post(notification: .announcement, argument: announcement)
                }
            }
        }
    }
    
    // MARK: - Export last event as JSON
    
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    
    // MARK: - Export all events as CSV
    
    /// Exports the entire audit log as a CSV string with headers:
    /// timestamp,operation,chargeID,type,amount,notes,searchText,tags,detail
    static func exportCSV() -> String {
        let header = "timestamp,operation,chargeID,type,amount,notes,searchText,tags,detail"
        let dateFormatter = ISO8601DateFormatter()
        let rows = log.map { event -> String in
            let timestamp = dateFormatter.string(from: event.timestamp)
            let operation = event.operation
            let chargeID = event.chargeID?.uuidString ?? ""
            let type = event.type?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""
            let amount = event.amount != nil ? String(format: "%.2f", event.amount!) : ""
            let notes = event.notes?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""
            let searchText = event.searchText?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""
            let tags = event.tags.joined(separator: ";").replacingOccurrences(of: "\"", with: "\"\"")
            let detail = event.detail?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""
            // Wrap fields that may contain commas or quotes in quotes
            func csvField(_ value: String) -> String {
                if value.contains(",") || value.contains("\"") || value.contains("\n") {
                    return "\"\(value)\""
                } else {
                    return value
                }
            }
            return [
                csvField(timestamp),
                csvField(operation),
                csvField(chargeID),
                csvField(type),
                csvField(amount),
                csvField(notes),
                csvField(searchText),
                csvField(tags),
                csvField(detail)
            ].joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }
    
    // MARK: - Analytics: Most frequent charge type among add/delete/tap events
    
    /// Returns the charge type with the highest frequency among add, delete, and tap events.
    /// If no such events or no types, returns nil.
    static var mostFrequentChargeType: String? {
        let relevantEvents = log.filter { ["add", "delete", "tap"].contains($0.operation) && $0.type != nil }
        let frequency = Dictionary(grouping: relevantEvents, by: { $0.type! })
            .mapValues { $0.count }
        return frequency.max(by: { $0.value < $1.value })?.key
    }
    
    // MARK: - Analytics: Total number of "add" events
    
    /// Returns the total count of "add" operations recorded in the audit log.
    static var totalChargesAdded: Int {
        log.filter { $0.operation == "add" }.count
    }
    
    // MARK: - Accessibility summary of last event
    
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No charge list events recorded."
    }
}

// MARK: - ChargeListView (Tokenized, Modular, Auditable Charge History List)

struct ChargeListView: View {
    @StateObject private var viewModel = ChargeListViewModel()
    @State private var showingAddCharge = false
    
    // DEBUG overlay state
    @State private var debugOverlayHeight: CGFloat = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
                
                // MARK: - DEBUG Overlay: Show last 3 audit events and most frequent charge type
                #if DEBUG
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("🛠️ Audit Log (last 3 events):")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    ForEach(ChargeListAudit.log.suffix(3).reversed(), id: \.timestamp) { event in
                        Text(event.accessibilityLabel)
                            .font(.caption2.monospaced())
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    if let mostFreq = ChargeListAudit.mostFrequentChargeType {
                        Text("Most Frequent Charge Type: \(mostFreq)")
                            .font(.caption)
                            .foregroundColor(.primary)
                            .padding(.top, 2)
                    } else {
                        Text("Most Frequent Charge Type: None")
                            .font(.caption)
                            .foregroundColor(.primary)
                            .padding(.top, 2)
                    }
                }
                .padding(8)
                .background(Color(UIColor.systemBackground).opacity(0.95))
                .transition(.move(edge: .bottom).combined(with: .opacity))
                #endif
            }
        }
    }
}

// MARK: - Audit/Admin Accessors

public enum ChargeListAuditAdmin {
    public static var lastSummary: String { ChargeListAudit.accessibilitySummary }
    public static var lastJSON: String? { ChargeListAudit.exportLastJSON() }
    
    /// Exposes the CSV export of the entire audit log.
    public static func exportCSV() -> String {
        ChargeListAudit.exportCSV()
    }
    
    /// Exposes the most frequent charge type among add/delete/tap events.
    public static var mostFrequentChargeType: String? {
        ChargeListAudit.mostFrequentChargeType
    }
    
    /// Exposes the total number of charges added.
    public static var totalChargesAdded: Int {
        ChargeListAudit.totalChargesAdded
    }
    
    /// Returns the last N audit event accessibility labels.
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

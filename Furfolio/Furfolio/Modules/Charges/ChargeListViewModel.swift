//
//  ChargeListViewModel.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Tokenized, Modular Charge List ViewModel
//

import Foundation
import Combine
import SwiftUI
import AVFoundation

// MARK: - Audit/Event Logging

fileprivate struct ChargeListViewModelAuditEvent: Codable {
    let timestamp: Date
    let operation: String      // "fetch", "search", "delete"
    let chargeID: UUID?
    let type: String?
    let amount: Double?
    let searchText: String?
    let tags: [String]
    let detail: String?
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        var parts = [operation.capitalized]
        if let t = type { parts.append("Type: \(t)") }
        if let a = amount { parts.append("Amount: $\(String(format: "%.2f", a))") }
        if let s = searchText, !s.isEmpty { parts.append("Search: \(s)") }
        if let id = chargeID { parts.append("ID: \(id.uuidString.prefix(8))") }
        if !tags.isEmpty { parts.append("[\(tags.joined(separator: ","))]") }
        parts.append("at \(dateStr)")
        if let d = detail, !d.isEmpty { parts.append(": \(d)") }
        return parts.joined(separator: " ")
    }
}

fileprivate final class ChargeListViewModelAudit {
    static private(set) var log: [ChargeListViewModelAuditEvent] = []

    /// Records an audit event with optional charge, searchText, tags, and detail.
    static func record(
        operation: String,
        charge: Charge? = nil,
        searchText: String? = nil,
        tags: [String] = [],
        detail: String? = nil
    ) {
        let event = ChargeListViewModelAuditEvent(
            timestamp: Date(),
            operation: operation,
            chargeID: charge?.id,
            type: charge?.type.displayName,
            amount: charge?.amount,
            searchText: searchText,
            tags: tags,
            detail: detail
        )
        log.append(event)
        if log.count > 150 { log.removeFirst() }
        
        // Accessibility: Post VoiceOver announcement on fetch, search, or delete events.
        if UIAccessibility.isVoiceOverRunning {
            var announcement = ""
            switch operation {
            case "fetch":
                announcement = "Charges loaded"
            case "search":
                if let text = searchText, !text.isEmpty {
                    announcement = "Charges filtered by \(text)"
                } else {
                    announcement = "Charges filtered"
                }
            case "delete":
                if let t = charge?.type.displayName {
                    announcement = "Charge for \(t) deleted"
                } else {
                    announcement = "Charge deleted"
                }
            default:
                break
            }
            if !announcement.isEmpty {
                UIAccessibility.post(notification: .announcement, argument: announcement)
            }
        }
    }

    /// Exports the last audit event as pretty-printed JSON string.
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    
    /// Accessibility summary of the last audit event.
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No charge list events recorded."
    }
    
    // MARK: - Business Analytics Enhancements
    
    /// The charge type with the highest frequency among fetch/delete/search events.
    static var mostFrequentChargeType: String? {
        let filteredEvents = log.filter { ["fetch", "delete", "search"].contains($0.operation) }
        let types = filteredEvents.compactMap { $0.type }
        let freq = Dictionary(grouping: types, by: { $0 }).mapValues { $0.count }
        return freq.max(by: { $0.value < $1.value })?.key
    }
    
    /// Total number of delete events recorded.
    static var totalChargesDeleted: Int {
        log.filter { $0.operation == "delete" }.count
    }
    
    // MARK: - CSV Export Enhancement
    
    /// Exports all audit events to CSV format with columns:
    /// timestamp,operation,chargeID,type,amount,searchText,tags,detail
    static func exportCSV() -> String {
        let header = "timestamp,operation,chargeID,type,amount,searchText,tags,detail"
        let rows = log.map { event -> String in
            let timestampStr = ISO8601DateFormatter().string(from: event.timestamp)
            let chargeIDStr = event.chargeID?.uuidString ?? ""
            let typeStr = event.type?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""
            let amountStr = event.amount != nil ? String(format: "%.2f", event.amount!) : ""
            let searchTextStr = event.searchText?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""
            let tagsStr = event.tags.joined(separator: ";").replacingOccurrences(of: "\"", with: "\"\"")
            let detailStr = event.detail?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""
            
            // CSV fields with commas or quotes are wrapped in quotes
            func csvField(_ field: String) -> String {
                if field.contains(",") || field.contains("\"") || field.contains("\n") {
                    return "\"\(field)\""
                }
                return field
            }
            
            return [
                csvField(timestampStr),
                csvField(event.operation),
                csvField(chargeIDStr),
                csvField(typeStr),
                csvField(amountStr),
                csvField(searchTextStr),
                csvField(tagsStr),
                csvField(detailStr)
            ].joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }
}

// MARK: - ChargeListViewModel (Modular, Tokenized, Auditable Charge List ViewModel)

@MainActor
final class ChargeListViewModel: ObservableObject {
    @Published var charges: [Charge] = []
    @Published var isLoading = false
    @Published var searchText = "" {
        didSet {
            if oldValue != searchText {
                ChargeListViewModelAudit.record(
                    operation: "search",
                    searchText: searchText,
                    tags: ["search"],
                    detail: "User searched"
                )
            }
        }
    }

    private let dataStore: DataStoreService
    private var cancellables = Set<AnyCancellable>()

    var filteredCharges: [Charge] {
        if searchText.isEmpty {
            return charges.sorted { $0.date > $1.date }
        } else {
            return charges
                .filter { $0.type.displayName.localizedCaseInsensitiveContains(searchText) }
                .sorted { $0.date > $1.date }
        }
    }

    init(dataStore: DataStoreService = .shared) {
        self.dataStore = dataStore

        // Debounced reactive search audit (Combine pipeline)
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] text in
                guard let self else { return }
                if !text.isEmpty {
                    ChargeListViewModelAudit.record(
                        operation: "search",
                        searchText: text,
                        tags: ["search", "debounced"],
                        detail: "Debounced search"
                    )
                }
            }
            .store(in: &cancellables)
    }

    /// Fetches all charges from the data store, with audit logging.
    func fetchCharges() async {
        isLoading = true
        charges = await dataStore.fetchAll(Charge.self)
        isLoading = false
        ChargeListViewModelAudit.record(
            operation: "fetch",
            tags: ["fetch"],
            detail: "Fetched \(charges.count) charges"
        )
    }

    /// Deletes charges at offsets from the filtered charges list, with audit trail.
    func deleteCharge(at offsets: IndexSet) {
        let chargesToDelete = offsets.map { filteredCharges[$0] }
        for charge in chargesToDelete {
            Task {
                await dataStore.delete(charge)
                ChargeListViewModelAudit.record(
                    operation: "delete",
                    charge: charge,
                    tags: ["delete"],
                    detail: "Charge deleted"
                )
                await fetchCharges()
            }
        }
    }
}

// MARK: - Audit/Admin Accessors

public enum ChargeListViewModelAuditAdmin {
    public static var lastSummary: String { ChargeListViewModelAudit.accessibilitySummary }
    public static var lastJSON: String? { ChargeListViewModelAudit.exportLastJSON() }
    
    /// Returns recent audit event labels, limited by `limit`.
    public static func recentEvents(limit: Int = 5) -> [String] {
        ChargeListViewModelAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
    
    /// Exports all audit events as CSV string.
    public static var exportCSV: String {
        ChargeListViewModelAudit.exportCSV()
    }
    
    /// The most frequent charge type among fetch/delete/search events.
    public static var mostFrequentChargeType: String? {
        ChargeListViewModelAudit.mostFrequentChargeType
    }
    
    /// Total number of charges deleted.
    public static var totalChargesDeleted: Int {
        ChargeListViewModelAudit.totalChargesDeleted
    }
}

#if DEBUG
import SwiftUI

/// A SwiftUI view displaying a summary of the last 3 audit events and analytics,
/// intended as a development overlay for quick inspection.
struct ChargeListViewModelAuditSummaryView: View {
    private let recentEvents: [ChargeListViewModelAuditEvent]
    private let mostFrequentType: String?
    private let totalDeleted: Int
    
    init() {
        recentEvents = Array(ChargeListViewModelAudit.log.suffix(3))
        mostFrequentType = ChargeListViewModelAudit.mostFrequentChargeType
        totalDeleted = ChargeListViewModelAudit.totalChargesDeleted
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Audit Summary").font(.headline)
            if recentEvents.isEmpty {
                Text("No audit events recorded yet.").italic()
            } else {
                ForEach(recentEvents.indices, id: \.self) { idx in
                    let event = recentEvents[idx]
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(event.operation.capitalized) @ \(event.timestamp, formatter: dateFormatter)")
                            .font(.subheadline).bold()
                        Text(event.accessibilityLabel).font(.caption)
                    }
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                Text("Analytics").font(.headline)
                Text("Most Frequent Charge Type: \(mostFrequentType ?? "N/A")")
                Text("Total Charges Deleted: \(totalDeleted)")
            }
        }
        .padding()
        .background(Color(.systemBackground).opacity(0.9))
        .cornerRadius(10)
        .shadow(radius: 5)
        .padding()
    }
    
    private var dateFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return df
    }
}
#endif

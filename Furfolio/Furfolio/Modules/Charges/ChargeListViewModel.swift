//
//  ChargeListViewModel.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Tokenized, Modular Charge List ViewModel
//

import Foundation
import Combine

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
    public static func recentEvents(limit: Int = 5) -> [String] {
        ChargeListViewModelAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
}

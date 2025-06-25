//
//  DogViewModel.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Modular Dog ViewModel
//

import Foundation
import Combine

@MainActor
final class DogViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var dogs: [Dog] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var searchQuery: String = ""

    // For selection, detail, or navigation
    @Published var selectedDog: Dog? = nil

    // MARK: - Dependencies
    private let dogService: DogServiceProtocol

    // MARK: - Audit/Event Logging
    private func audit(_ action: String, dogID: UUID? = nil, details: String) {
        DogViewModelAudit.record(action: action, dogID: dogID, details: details)
    }

    // MARK: - Init
    init(dogService: DogServiceProtocol = DogService()) {
        self.dogService = dogService
    }

    // MARK: - Actions

    func fetchDogs() async {
        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await dogService.fetchDogs()
            self.dogs = fetched
            audit("FetchDogs", details: "Fetched \(fetched.count) dogs")
        } catch {
            self.errorMessage = error.localizedDescription
            audit("FetchDogsFailed", details: error.localizedDescription)
        }
        isLoading = false
    }

    func addDog(_ dog: Dog) async {
        do {
            try await dogService.addDog(dog)
            await fetchDogs()
            audit("AddDog", dogID: dog.id, details: "Added dog: \(dog.name)")
        } catch {
            errorMessage = error.localizedDescription
            audit("AddDogFailed", dogID: dog.id, details: error.localizedDescription)
        }
    }

    func updateDog(_ dog: Dog) async {
        do {
            try await dogService.updateDog(dog)
            await fetchDogs()
            audit("UpdateDog", dogID: dog.id, details: "Updated dog: \(dog.name)")
        } catch {
            errorMessage = error.localizedDescription
            audit("UpdateDogFailed", dogID: dog.id, details: error.localizedDescription)
        }
    }

    func deleteDog(_ dog: Dog) async {
        do {
            try await dogService.deleteDog(dog)
            await fetchDogs()
            audit("DeleteDog", dogID: dog.id, details: "Deleted dog: \(dog.name)")
        } catch {
            errorMessage = error.localizedDescription
            audit("DeleteDogFailed", dogID: dog.id, details: error.localizedDescription)
        }
    }

    func searchDogs() async {
        isLoading = true
        errorMessage = nil
        let keyword = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            await fetchDogs()
            return
        }
        do {
            let results = try await dogService.searchDogs(keyword: keyword)
            self.dogs = results
            audit("SearchDogs", details: "Query: '\(keyword)', found: \(results.count)")
        } catch {
            self.errorMessage = error.localizedDescription
            audit("SearchDogsFailed", details: error.localizedDescription)
        }
        isLoading = false
    }

    func selectDog(_ dog: Dog?) {
        selectedDog = dog
        if let dog = dog {
            audit("SelectDog", dogID: dog.id, details: "Selected: \(dog.name)")
        }
    }
}

// MARK: - Audit/Event Logging

fileprivate struct DogViewModelAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let dogID: UUID?
    let details: String
    var summary: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[DogViewModel] \(action) \(dogID?.uuidString ?? "-") : \(details) at \(dateStr)"
    }
}

fileprivate final class DogViewModelAudit {
    static private(set) var log: [DogViewModelAuditEvent] = []
    static func record(action: String, dogID: UUID? = nil, details: String) {
        let event = DogViewModelAuditEvent(
            timestamp: Date(),
            action: action,
            dogID: dogID,
            details: details
        )
        log.append(event)
        if log.count > 40 { log.removeFirst() }
    }
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    static func recentSummaries(limit: Int = 8) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}

// MARK: - Admin/Audit Accessors

public enum DogViewModelAuditAdmin {
    public static func lastSummary() -> String { DogViewModelAudit.log.last?.summary ?? "No VM events yet." }
    public static func lastJSON() -> String? { DogViewModelAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 8) -> [String] { DogViewModelAudit.recentSummaries(limit: limit) }
}

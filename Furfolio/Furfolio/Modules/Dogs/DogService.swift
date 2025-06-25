//
//  DogService.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Modular, Extensible Dog Service Layer
//

import Foundation

// MARK: - Protocol

public protocol DogServiceProtocol: AnyObject {
    func fetchDogs() async throws -> [Dog]
    func addDog(_ dog: Dog) async throws
    func updateDog(_ dog: Dog) async throws
    func deleteDog(_ dog: Dog) async throws
    func searchDogs(keyword: String) async throws -> [Dog]
}

// MARK: - Dog Model

public struct Dog: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var breed: String
    public var birthdate: Date
    public var badges: [String]
    public var behaviorNotes: String
    public var totalVisits: Int
    public var lastVisitDate: Date
    public var vaccinationsUpToDate: Bool
    public var allergies: [String]
    public var photoURL: URL?

    public init(
        id: UUID = UUID(),
        name: String,
        breed: String,
        birthdate: Date,
        badges: [String] = [],
        behaviorNotes: String = "",
        totalVisits: Int = 0,
        lastVisitDate: Date = Date(),
        vaccinationsUpToDate: Bool = true,
        allergies: [String] = [],
        photoURL: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.breed = breed
        self.birthdate = birthdate
        self.badges = badges
        self.behaviorNotes = behaviorNotes
        self.totalVisits = totalVisits
        self.lastVisitDate = lastVisitDate
        self.vaccinationsUpToDate = vaccinationsUpToDate
        self.allergies = allergies
        self.photoURL = photoURL
    }
}

// MARK: - Audit/Event Logging

fileprivate struct DogServiceAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let dogID: UUID?
    let details: String
    var summary: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[DogService] \(action) \(dogID?.uuidString ?? "-") : \(details) at \(dateStr)"
    }
}

fileprivate final class DogServiceAudit {
    static private(set) var log: [DogServiceAuditEvent] = []
    static func record(action: String, dogID: UUID?, details: String) {
        let event = DogServiceAuditEvent(
            timestamp: Date(),
            action: action,
            dogID: dogID,
            details: details
        )
        log.append(event)
        if log.count > 50 { log.removeFirst() }
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

// MARK: - In-Memory Implementation (For MVP, replace with Cloud sync as needed)

public final class DogService: DogServiceProtocol {
    private var dogs: [Dog] = []

    public init() {
        // Optionally seed with mock/test dogs for preview/demo
        #if DEBUG
        self.dogs = [
            Dog(name: "Bella", breed: "Golden Retriever", birthdate: Date(timeIntervalSinceNow: -3 * 365 * 86400)),
            Dog(name: "Charlie", breed: "Poodle", birthdate: Date(timeIntervalSinceNow: -2 * 365 * 86400))
        ]
        #endif
    }

    public func fetchDogs() async throws -> [Dog] {
        DogServiceAudit.record(action: "FetchAll", dogID: nil, details: "Fetched all dogs (\(dogs.count))")
        return dogs
    }

    public func addDog(_ dog: Dog) async throws {
        dogs.append(dog)
        DogServiceAudit.record(action: "Add", dogID: dog.id, details: "Added dog: \(dog.name)")
    }

    public func updateDog(_ dog: Dog) async throws {
        guard let idx = dogs.firstIndex(where: { $0.id == dog.id }) else {
            throw NSError(domain: "DogService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Dog not found"])
        }
        dogs[idx] = dog
        DogServiceAudit.record(action: "Update", dogID: dog.id, details: "Updated dog: \(dog.name)")
    }

    public func deleteDog(_ dog: Dog) async throws {
        dogs.removeAll { $0.id == dog.id }
        DogServiceAudit.record(action: "Delete", dogID: dog.id, details: "Deleted dog: \(dog.name)")
    }

    public func searchDogs(keyword: String) async throws -> [Dog] {
        let lower = keyword.lowercased()
        let results = dogs.filter {
            $0.name.lowercased().contains(lower) ||
            $0.breed.lowercased().contains(lower)
        }
        DogServiceAudit.record(action: "Search", dogID: nil, details: "Searched: \(keyword), found \(results.count)")
        return results
    }
}

// MARK: - Admin/Audit Accessors

public enum DogServiceAuditAdmin {
    public static func lastSummary() -> String { DogServiceAudit.log.last?.summary ?? "No service events yet." }
    public static func lastJSON() -> String? { DogServiceAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 8) -> [String] { DogServiceAudit.recentSummaries(limit: limit) }
}

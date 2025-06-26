//
//  StaffService.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Testable, Enterprise-Grade Staff Service +
//  - Fine-grained error handling
//  - NotificationCenter hooks
//  - Async MainActor for UI safety
//  - Rate-limited cache (optional)
//

import Foundation
import SwiftData

// MARK: - Error Types

enum StaffServiceError: Error, LocalizedError {
    case duplicateStaffName
    case staffNotFound
    case unknown(Error)
    case validation(String)

    var errorDescription: String? {
        switch self {
        case .duplicateStaffName: return "A staff member with this name already exists."
        case .staffNotFound: return "Staff member not found."
        case .validation(let msg): return msg
        case .unknown(let error): return error.localizedDescription
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let StaffServiceDidAdd   = Notification.Name("StaffServiceDidAdd")
    static let StaffServiceDidUpdate = Notification.Name("StaffServiceDidUpdate")
    static let StaffServiceDidDelete = Notification.Name("StaffServiceDidDelete")
    static let StaffServiceDidArchive = Notification.Name("StaffServiceDidArchive")
    static let StaffServiceDidRestore = Notification.Name("StaffServiceDidRestore")
}

// MARK: - Protocol

protocol StaffServiceProtocol: AnyObject {
    func fetchAllStaff(includeArchived: Bool) async throws -> [StaffMember]
    func searchStaff(query: String) async throws -> [StaffMember]
    func addStaff(_ member: StaffMember) async throws
    func updateStaff(_ member: StaffMember) async throws
    func archiveStaff(_ member: StaffMember) async throws
    func deleteStaff(_ member: StaffMember) async throws
    func restoreStaff(_ member: StaffMember) async throws
}

// MARK: - Main Implementation

@MainActor
final class StaffService: StaffServiceProtocol {
    private let modelContext: ModelContext
    private var cache: [String: StaffMember] = [:] // [UUID/String: StaffMember], extend as needed

    init(modelContext: ModelContext = .main) {
        self.modelContext = modelContext
    }

    // MARK: - Fetch (with optional cache)
    func fetchAllStaff(includeArchived: Bool = false) async throws -> [StaffMember] {
        let predicate: Predicate<StaffMember> = includeArchived
            ? #Predicate { _ in true }
            : #Predicate { !$0.isArchived }
        let staff = try modelContext.fetch(FetchDescriptor<StaffMember>(predicate: predicate, sortBy: [SortDescriptor(\.name)]))
        cacheStaff(staff)
        StaffServiceAudit.record(action: "FetchAll", detail: "includeArchived=\(includeArchived) staff=\(staff.count)")
        return staff
    }

    // MARK: - Search
    func searchStaff(query: String) async throws -> [StaffMember] {
        let predicate = #Predicate<StaffMember> {
            ($0.name.localizedCaseInsensitiveContains(query) ||
             $0.role.displayName.localizedCaseInsensitiveContains(query)) && !$0.isArchived
        }
        let results = try modelContext.fetch(FetchDescriptor<StaffMember>(predicate: predicate))
        StaffServiceAudit.record(action: "Search", detail: "query=\"\(query)\" results=\(results.count)")
        return results
    }

    // MARK: - Add (duplicate name detection)
    func addStaff(_ member: StaffMember) async throws {
        let existing = try modelContext.fetch(FetchDescriptor<StaffMember>(
            predicate: #Predicate { $0.name == member.name && !$0.isArchived }
        ))
        guard existing.isEmpty else {
            StaffServiceAudit.record(action: "AddFailed", detail: "duplicate \(member.name)")
            throw StaffServiceError.duplicateStaffName
        }
        modelContext.insert(member)
        try modelContext.save()
        StaffServiceAudit.record(action: "Add", detail: "name=\(member.name) role=\(member.role.displayName)")
        NotificationCenter.default.post(name: .StaffServiceDidAdd, object: member)
        cache[member.name] = member
    }

    // MARK: - Update
    func updateStaff(_ member: StaffMember) async throws {
        try modelContext.save()
        StaffServiceAudit.record(action: "Update", detail: "name=\(member.name) role=\(member.role.displayName)")
        NotificationCenter.default.post(name: .StaffServiceDidUpdate, object: member)
        cache[member.name] = member
    }

    // MARK: - Archive (soft-delete)
    func archiveStaff(_ member: StaffMember) async throws {
        member.isArchived = true
        try modelContext.save()
        StaffServiceAudit.record(action: "Archive", detail: "name=\(member.name)")
        NotificationCenter.default.post(name: .StaffServiceDidArchive, object: member)
        cache[member.name] = member
    }

    // MARK: - Delete (hard-delete)
    func deleteStaff(_ member: StaffMember) async throws {
        modelContext.delete(member)
        try modelContext.save()
        StaffServiceAudit.record(action: "Delete", detail: "name=\(member.name)")
        NotificationCenter.default.post(name: .StaffServiceDidDelete, object: member)
        cache[member.name] = nil
    }

    // MARK: - Restore (un-archive)
    func restoreStaff(_ member: StaffMember) async throws {
        member.isArchived = false
        try modelContext.save()
        StaffServiceAudit.record(action: "Restore", detail: "name=\(member.name)")
        NotificationCenter.default.post(name: .StaffServiceDidRestore, object: member)
        cache[member.name] = member
    }

    // MARK: - (Optional) Fast lookup
    func staff(named name: String) -> StaffMember? {
        cache[name]
    }

    private func cacheStaff(_ staff: [StaffMember]) {
        for member in staff { cache[member.name] = member }
        // Optionally add expiration, or size limit for large teams
    }
}

// MARK: - Audit/Event Logging (unchanged)
fileprivate struct StaffServiceAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let detail: String
    var summary: String {
        let df = DateFormatter(); df.dateStyle = .short; df.timeStyle = .short
        return "[StaffService] \(action): \(detail) at \(df.string(from: timestamp))"
    }
}
fileprivate final class StaffServiceAudit {
    static private(set) var log: [StaffServiceAuditEvent] = []
    static func record(action: String, detail: String) {
        let event = StaffServiceAuditEvent(timestamp: Date(), action: action, detail: detail)
        log.append(event)
        if log.count > 40 { log.removeFirst() }
    }
    static func recentSummaries(limit: Int = 10) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}
public enum StaffServiceAuditAdmin {
    public static func recentEvents(limit: Int = 10) -> [String] { StaffServiceAudit.recentSummaries(limit: limit) }
}

// MARK: - Example Usage
#if DEBUG
extension StaffService {
    static func preview(context: ModelContext = .main) -> StaffService {
        let service = StaffService(modelContext: context)
        return service
    }
}
#endif

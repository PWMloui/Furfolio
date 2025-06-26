//
//  StaffViewModel.swift
//  Furfolio
//
//  Enhanced 2025: Enterprise, Robust, Auditable, User-Centric Staff ViewModel
//

import Foundation
import Combine
import SwiftData

// MARK: - Fine-Grained Error Types

enum StaffViewModelError: LocalizedError, Equatable {
    case duplicateName
    case validation(String)
    case service(underlying: Error)
    case unknown

    var errorDescription: String? {
        switch self {
        case .duplicateName:
            return "A staff member with this name already exists."
        case .validation(let msg):
            return msg
        case .service(let err):
            return err.localizedDescription
        case .unknown:
            return "An unknown error occurred."
        }
    }
}

// MARK: - StaffViewModel

@MainActor
final class StaffViewModel: ObservableObject {
    // Published state
    @Published private(set) var staff: [StaffMember] = []
    @Published var searchQuery: String = ""
    @Published var isLoading: Bool = false
    @Published var isSyncing: Bool = false // For refreshes or batch ops
    @Published var errorMessage: String?
    @Published var errorBannerVisible: Bool = false
    @Published var showAuditLog: Bool = false

    private let staffService: StaffServiceProtocol
    private var cancellables: Set<AnyCancellable> = []
    private var lastFetchTime: Date = .distantPast
    private let minFetchInterval: TimeInterval = 1.5 // seconds

    // MARK: - Init
    init(staffService: StaffServiceProtocol = StaffService()) {
        self.staffService = staffService
        StaffViewModelAudit.record(action: "Init", detail: "")
        setupSearchListener()
    }

    // MARK: - Fetch with Rate Limiting
    func fetchStaff(includeArchived: Bool = false, force: Bool = false) async {
        guard force || Date().timeIntervalSince(lastFetchTime) > minFetchInterval else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let results = try await staffService.fetchAllStaff(includeArchived: includeArchived)
            staff = results
            lastFetchTime = Date()
            StaffViewModelAudit.record(action: "Fetch", detail: "success, count=\(results.count)")
            NotificationCenter.default.post(name: .StaffViewModelDidUpdate, object: nil)
        } catch {
            handleError(error, context: "Fetch")
        }
    }

    // MARK: - Search
    private func setupSearchListener() {
        $searchQuery
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                Task { await self?.searchStaff(query: query) }
            }
            .store(in: &cancellables)
    }

    func searchStaff(query: String) async {
        guard !query.isEmpty else {
            await fetchStaff(force: true)
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let results = try await staffService.searchStaff(query: query)
            staff = results
            StaffViewModelAudit.record(action: "Search", detail: "\"\(query)\" found=\(results.count)")
        } catch {
            handleError(error, context: "Search")
        }
    }

    // MARK: - Add
    func addStaff(_ member: StaffMember) async {
        isSyncing = true
        defer { isSyncing = false }
        do {
            try await staffService.addStaff(member)
            StaffViewModelAudit.record(action: "Add", detail: member.name)
            await fetchStaff(force: true)
        } catch let error as StaffServiceError {
            if case .duplicateStaffName = error {
                handleError(StaffViewModelError.duplicateName, context: "Add")
            } else {
                handleError(error, context: "Add")
            }
        } catch {
            handleError(error, context: "Add")
        }
    }

    // MARK: - Update
    func updateStaff(_ member: StaffMember) async {
        isSyncing = true
        defer { isSyncing = false }
        do {
            try await staffService.updateStaff(member)
            StaffViewModelAudit.record(action: "Update", detail: member.name)
            await fetchStaff(force: true)
        } catch {
            handleError(error, context: "Update")
        }
    }

    // MARK: - Archive/Delete/Restore
    func archiveStaff(_ member: StaffMember) async {
        isSyncing = true
        defer { isSyncing = false }
        do {
            try await staffService.archiveStaff(member)
            StaffViewModelAudit.record(action: "Archive", detail: member.name)
            await fetchStaff(force: true)
        } catch {
            handleError(error, context: "Archive")
        }
    }

    func deleteStaff(_ member: StaffMember) async {
        isSyncing = true
        defer { isSyncing = false }
        do {
            try await staffService.deleteStaff(member)
            StaffViewModelAudit.record(action: "Delete", detail: member.name)
            await fetchStaff(force: true)
        } catch {
            handleError(error, context: "Delete")
        }
    }

    func restoreStaff(_ member: StaffMember) async {
        isSyncing = true
        defer { isSyncing = false }
        do {
            try await staffService.restoreStaff(member)
            StaffViewModelAudit.record(action: "Restore", detail: member.name)
            await fetchStaff(includeArchived: true, force: true)
        } catch {
            handleError(error, context: "Restore")
        }
    }

    // MARK: - Error Handling

    private func handleError(_ error: Error, context: String) {
        let viewModelError: StaffViewModelError
        if let vmError = error as? StaffViewModelError {
            viewModelError = vmError
        } else if let svcError = error as? StaffServiceError, case .duplicateStaffName = svcError {
            viewModelError = .duplicateName
        } else {
            viewModelError = .service(underlying: error)
        }
        errorMessage = viewModelError.errorDescription ?? "Unknown error"
        errorBannerVisible = true
        StaffViewModelAudit.record(action: context, detail: "error: \(errorMessage ?? "")")
        // Optionally post NotificationCenter event for analytics/UI
        NotificationCenter.default.post(name: .StaffViewModelDidError, object: viewModelError)
        // Auto-hide error banner after a delay (if used in SwiftUI View)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in
            self?.errorBannerVisible = false
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let StaffViewModelDidUpdate = Notification.Name("StaffViewModelDidUpdate")
    static let StaffViewModelDidError = Notification.Name("StaffViewModelDidError")
}

// MARK: - Audit/Event Logging

fileprivate struct StaffViewModelAuditEvent: Codable {
    let timestamp: Date
    let action: String
    let detail: String
    var summary: String {
        let df = DateFormatter(); df.dateStyle = .short; df.timeStyle = .short
        return "[StaffViewModel] \(action): \(detail) at \(df.string(from: timestamp))"
    }
}
fileprivate final class StaffViewModelAudit {
    static private(set) var log: [StaffViewModelAuditEvent] = []
    static func record(action: String, detail: String) {
        let event = StaffViewModelAuditEvent(timestamp: Date(), action: action, detail: detail)
        log.append(event)
        if log.count > 40 { log.removeFirst() }
    }
    static func recentSummaries(limit: Int = 12) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}
public enum StaffViewModelAuditAdmin {
    public static func recentEvents(limit: Int = 12) -> [String] { StaffViewModelAudit.recentSummaries(limit: limit) }
}

// MARK: - SwiftUI Preview Support

#if DEBUG
extension StaffViewModel {
    static let preview: StaffViewModel = {
        let vm = StaffViewModel(staffService: MockStaffService())
        Task { await vm.fetchStaff(force: true) }
        return vm
    }()
}

// Example mock for previews/tests
final class MockStaffService: StaffServiceProtocol {
    func fetchAllStaff(includeArchived: Bool) async throws -> [StaffMember] {
        [
            StaffMember(name: "Test Admin", role: .admin),
            StaffMember(name: "Test Groomer", role: .groomer)
        ]
    }
    func searchStaff(query: String) async throws -> [StaffMember] {
        try await fetchAllStaff(includeArchived: false).filter { $0.name.contains(query) }
    }
    func addStaff(_ member: StaffMember) async throws {
        if member.name == "Duplicate" { throw StaffServiceError.duplicateStaffName }
    }
    func updateStaff(_ member: StaffMember) async throws {}
    func archiveStaff(_ member: StaffMember) async throws {}
    func deleteStaff(_ member: StaffMember) async throws {}
    func restoreStaff(_ member: StaffMember) async throws {}
}
#endif

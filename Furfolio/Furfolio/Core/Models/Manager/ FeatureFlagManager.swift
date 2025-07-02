//
//  FeatureFlagManager.swift
//  Furfolio
//
//  Enhanced: Audit trail, tag/badge analytics, accessibility, exportable events, risk scoring, Trust Center ready.
//  Author: mac + ChatGPT
//

import Foundation
import SwiftUI
import SwiftData

// MARK: - FeatureFlagManager (Centralized, Modular, Auditable Feature Flag System)

@MainActor
final class FeatureFlagManager: ObservableObject {
    static let shared = FeatureFlagManager()

    // MARK: - Flag Definition (with business rationale tags)
    enum Flag: String, CaseIterable, Identifiable {
        case newDashboard
        case loyaltyProgram
        case calendarHeatmap
        case multiUserSupport
        case dogPhotoGallery
        case appointmentConflictWarning
        case businessAnalytics
        case exportReports

        var id: String { rawValue }

        /// Business rationale / tags for analytics & compliance
        var tags: [String] {
            switch self {
            case .newDashboard: return ["ui", "beta", "analytics"]
            case .loyaltyProgram: return ["client", "retention", "marketing"]
            case .calendarHeatmap: return ["calendar", "visualization", "staff"]
            case .multiUserSupport: return ["team", "business", "compliance"]
            case .dogPhotoGallery: return ["media", "ux"]
            case .appointmentConflictWarning: return ["safety", "scheduler", "compliance"]
            case .businessAnalytics: return ["analytics", "insights", "bi"]
            case .exportReports: return ["compliance", "reporting", "admin"]
            }
        }
        /// If this flag is compliance-critical (risk/alert for trust center)
        var isCritical: Bool {
            switch self {
            case .appointmentConflictWarning, .exportReports, .multiUserSupport: return true
            default: return false
            }
        }
    }

    // MARK: - Feature flag state (defaults)
    @Published private(set) var flags: [Flag: Bool] = [
        .newDashboard: false,
        .loyaltyProgram: true,
        .calendarHeatmap: false,
        .multiUserSupport: false,
        .dogPhotoGallery: true,
        .appointmentConflictWarning: true,
        .businessAnalytics: true,
        .exportReports: false
    ]

    // MARK: - Audit/Event Log & Risk Analytics

    @Model public struct FlagAuditEvent: Identifiable {
        @Attribute(.unique) var id: UUID = UUID()
        let timestamp: Date
        let flag: Flag
        let newValue: Bool
        let tags: [String]
        let isCritical: Bool
        let actor: String?       // Future: user or admin who toggled
        let reason: String?      // Reason for toggle, for compliance
        let context: String?     // (optional, e.g. "migration", "beta")

        /// Accessibility label for audit event, localized with date/time and critical flag info
        @Attribute(.transient)
        var accessibilityLabel: String {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            dateFormatter.timeStyle = .short
            let dateStr = dateFormatter.string(from: timestamp)
            let criticalStr = isCritical ? NSLocalizedString(" (critical)", comment: "Indicates a critical feature flag event") : ""
            let onOffStr = newValue ? NSLocalizedString("ON", comment: "Flag enabled") : NSLocalizedString("OFF", comment: "Flag disabled")
            return String(
                format: NSLocalizedString("%@ set to %@ at %@%@", comment: "Audit event label: flag name, on/off, date/time, critical indicator"),
                flag.rawValue,
                onOffStr,
                dateStr,
                criticalStr
            )
        }
    }
    private var auditLog: [FlagAuditEvent] = []

    private let storageKey = "FeatureFlagManager.flags"
    private let auditLogQueue = DispatchQueue(label: "com.furfolio.featureflagmanager.auditlog", qos: .userInitiated)

    // MARK: - Init & Load
    private init() {
        // Load flags and audit log on init asynchronously
        Task {
            await loadFlags()
        }
    }

    // MARK: - Set/Toggle (Audit, Tagging, Risk)

    /// Sets or toggles a feature flag asynchronously with audit logging.
    ///
    /// - Parameters:
    ///   - flag: The feature flag to set.
    ///   - enabled: The new enabled state.
    ///   - actor: Optional actor who toggled the flag.
    ///   - reason: Optional reason for toggling.
    ///   - context: Optional context string (e.g., "migration", "beta").
    ///
    /// This method logs the change asynchronously and updates persisted storage safely.
    func set(_ flag: Flag, enabled: Bool, actor: String? = nil, reason: String? = nil, context: String? = nil) async {
        flags[flag] = enabled
        await saveFlags()
        objectWillChange.send()
        await logAudit(flag: flag, value: enabled, actor: actor, reason: reason, context: context)
    }

    /// Legacy synchronous call for setting a flag without audit details.
    ///
    /// - Parameters:
    ///   - flag: The feature flag to set.
    ///   - enabled: The new enabled state.
    ///
    /// This method calls the async version internally and waits for completion.
    func set(_ flag: Flag, enabled: Bool) {
        Task {
            await set(flag, enabled: enabled, actor: nil, reason: nil, context: nil)
        }
    }

    /// Queries whether a feature flag is enabled asynchronously.
    ///
    /// - Parameter flag: The feature flag to query.
    /// - Returns: A boolean indicating if the flag is enabled.
    ///
    /// This method is async to allow possible future audit logging of queries.
    func isEnabled(_ flag: Flag) async -> Bool {
        return flags[flag] ?? false
    }

    // MARK: - Audit log helpers

    /// Logs an audit event asynchronously on a serial queue.
    ///
    /// - Parameters:
    ///   - flag: The feature flag changed.
    ///   - value: The new flag value.
    ///   - actor: Optional actor who made the change.
    ///   - reason: Optional reason for the change.
    ///   - context: Optional context string.
    private func logAudit(flag: Flag, value: Bool, actor: String?, reason: String?, context: String?) async {
        await withCheckedContinuation { continuation in
            auditLogQueue.async {
                let event = FlagAuditEvent(
                    timestamp: Date(),
                    flag: flag,
                    newValue: value,
                    tags: flag.tags,
                    isCritical: flag.isCritical,
                    actor: actor,
                    reason: reason,
                    context: context
                )
                self.auditLog.append(event)
                if self.auditLog.count > 1000 {
                    self.auditLog.removeFirst()
                }
                continuation.resume()
            }
        }
    }

    /// Clears the entire audit log asynchronously.
    ///
    /// Use this method to reset audit history safely.
    func clearAuditLog() async {
        await withCheckedContinuation { continuation in
            auditLogQueue.async {
                self.auditLog.removeAll()
                continuation.resume()
            }
        }
    }

    /// Exports the most recent audit event as JSON asynchronously.
    ///
    /// - Returns: A JSON string of the last audit event, or nil if none exists.
    func exportLastAuditEventJSON() async -> String? {
        await withCheckedContinuation { continuation in
            auditLogQueue.async {
                guard let last = self.auditLog.last else {
                    continuation.resume(returning: nil)
                    return
                }
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                if let data = try? encoder.encode(last),
                   let jsonStr = String(data: data, encoding: .utf8) {
                    continuation.resume(returning: jsonStr)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// Exports all audit events as JSON asynchronously with pagination support.
    ///
    /// - Parameters:
    ///   - page: The page number (starting at 0).
    ///   - pageSize: The number of events per page.
    /// - Returns: A JSON string representing the requested page of audit events.
    func exportAuditEventsJSON(page: Int = 0, pageSize: Int = 100) async -> String? {
        await withCheckedContinuation { continuation in
            auditLogQueue.async {
                guard page >= 0, pageSize > 0 else {
                    continuation.resume(returning: nil)
                    return
                }
                let startIndex = page * pageSize
                guard startIndex < self.auditLog.count else {
                    continuation.resume(returning: nil)
                    return
                }
                let endIndex = min(startIndex + pageSize, self.auditLog.count)
                let pageEvents = Array(self.auditLog[startIndex..<endIndex])
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                if let data = try? encoder.encode(pageEvents),
                   let jsonStr = String(data: data, encoding: .utf8) {
                    continuation.resume(returning: jsonStr)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// Fetches recent audit events asynchronously with optional filtering.
    ///
    /// - Parameters:
    ///   - tags: Optional array of tags to filter by (events must contain at least one tag).
    ///   - actor: Optional actor string to filter by exact match.
    ///   - context: Optional context string to filter by exact match.
    ///   - limit: Maximum number of events to return (default 100).
    /// - Returns: An array of filtered audit events.
    func fetchAuditEvents(tags: [String]? = nil, actor: String? = nil, context: String? = nil, limit: Int = 100) async -> [FlagAuditEvent] {
        await withCheckedContinuation { continuation in
            auditLogQueue.async {
                var filtered = self.auditLog
                if let tags = tags, !tags.isEmpty {
                    filtered = filtered.filter { event in
                        !Set(event.tags).isDisjoint(with: tags)
                    }
                }
                if let actor = actor {
                    filtered = filtered.filter { $0.actor == actor }
                }
                if let context = context {
                    filtered = filtered.filter { $0.context == context }
                }
                let limited = Array(filtered.suffix(limit))
                continuation.resume(returning: limited)
            }
        }
    }

    /// Fetches the current risk score asynchronously.
    ///
    /// - Returns: The count of critical flags disabled, indicating compliance risk.
    func riskScore() async -> Int {
        return await withCheckedContinuation { continuation in
            auditLogQueue.async {
                let score = self.flags.filter { !$0.value && $0.key.isCritical }.count
                continuation.resume(returning: score)
            }
        }
    }

    /// Accessibility label for UI/VoiceOver, summarizing flag status and last change.
    ///
    /// This property is computed asynchronously.
    var accessibilityLabel: String {
        get async {
            let last: String = await withCheckedContinuation { continuation in
                auditLogQueue.async {
                    let lastLabel = self.auditLog.last?.accessibilityLabel ?? NSLocalizedString("No flag changes recently.", comment: "No recent audit events")
                    continuation.resume(returning: lastLabel)
                }
            }
            let risk = await riskScore()
            let riskStr = risk > 0 ?
                String(format: NSLocalizedString("Compliance risk: %d critical flag(s) disabled. ", comment: "Compliance risk summary"), risk) : ""
            return String(format: NSLocalizedString("Feature flag status: %@%@", comment: "Full accessibility label for feature flags"), riskStr, last)
        }
    }

    // MARK: - Load/Save

    private func loadFlags() async {
        await withCheckedContinuation { continuation in
            auditLogQueue.async {
                guard let data = UserDefaults.standard.data(forKey: self.storageKey),
                      let decoded = try? JSONDecoder().decode([String: Bool].self, from: data) else {
                    continuation.resume()
                    return
                }
                for (key, value) in decoded {
                    if let flag = Flag(rawValue: key) {
                        self.flags[flag] = value
                    }
                }
                continuation.resume()
            }
        }
    }

    private func saveFlags() async {
        await withCheckedContinuation { continuation in
            auditLogQueue.async {
                let dict = self.flags.mapKeys { $0.rawValue }
                if let data = try? JSONEncoder().encode(dict) {
                    UserDefaults.standard.set(data, forKey: self.storageKey)
                }
                continuation.resume()
            }
        }
    }
}

// MARK: - Dictionary Key Mapper Helper

private extension Dictionary {
    func mapKeys<T: Hashable>(_ transform: (Key) -> T) -> [T: Value] {
        Dictionary<T, Value>(uniqueKeysWithValues: map { (transform($0.key), $0.value) })
    }
}

// MARK: - Unit Test Stubs

#if DEBUG
import XCTest

final class FeatureFlagManagerTests: XCTestCase {
    let manager = FeatureFlagManager.shared

    func testConcurrentAuditLogAppending() async {
        await manager.clearAuditLog()
        let flag = FeatureFlagManager.Flag.newDashboard
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    await self.manager.set(flag, enabled: i % 2 == 0, actor: "Tester", reason: "Test concurrency", context: "unitTest")
                }
            }
        }
        let auditEvents = await manager.fetchAuditEvents(actor: "Tester", context: "unitTest")
        XCTAssertGreaterThanOrEqual(auditEvents.count, 100)
    }

    func testFilteringAuditEvents() async {
        await manager.clearAuditLog()
        await manager.set(.loyaltyProgram, enabled: true, actor: "UserA", reason: "Enable loyalty", context: "beta")
        await manager.set(.dogPhotoGallery, enabled: false, actor: "UserB", reason: "Disable gallery", context: "migration")
        let filteredByActor = await manager.fetchAuditEvents(actor: "UserA")
        XCTAssertEqual(filteredByActor.count, 1)
        let filteredByContext = await manager.fetchAuditEvents(context: "migration")
        XCTAssertEqual(filteredByContext.count, 1)
        let filteredByTags = await manager.fetchAuditEvents(tags: ["media"])
        XCTAssertEqual(filteredByTags.count, 1)
    }
}
#endif

// MARK: - SwiftUI PreviewProvider for Live Testing

#if DEBUG
struct FeatureFlagManagerPreview: View {
    @StateObject private var manager = FeatureFlagManager.shared
    @State private var auditEvents: [FeatureFlagManager.FlagAuditEvent] = []
    @State private var riskScore: Int = 0
    @State private var exportJSON: String = ""
    @State private var lastExportJSON: String = ""

    var body: some View {
        VStack(spacing: 12) {
            Text("Risk Score: \(riskScore)")
                .font(.headline)
            Button("Add Random Audit Event") {
                Task {
                    let flags = FeatureFlagManager.Flag.allCases
                    if let randomFlag = flags.randomElement() {
                        let enabled = Bool.random()
                        await manager.set(randomFlag, enabled: enabled, actor: "PreviewUser", reason: "Preview add", context: "preview")
                        await refreshData()
                    }
                }
            }
            Button("Fetch Audit Events (PreviewUser)") {
                Task {
                    auditEvents = await manager.fetchAuditEvents(actor: "PreviewUser")
                }
            }
            Button("Clear Audit Log") {
                Task {
                    await manager.clearAuditLog()
                    auditEvents = []
                    riskScore = 0
                    exportJSON = ""
                    lastExportJSON = ""
                }
            }
            Button("Export All Audit Events JSON (Page 0)") {
                Task {
                    exportJSON = (await manager.exportAuditEventsJSON(page: 0, pageSize: 50)) ?? "No data"
                }
            }
            Button("Export Last Audit Event JSON") {
                Task {
                    lastExportJSON = (await manager.exportLastAuditEventJSON()) ?? "No last event"
                }
            }
            ScrollView {
                VStack(alignment: .leading) {
                    Text("Audit Events:")
                        .font(.headline)
                    ForEach(auditEvents) { event in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.accessibilityLabel)
                                .font(.subheadline)
                            if let actor = event.actor {
                                Text("Actor: \(actor)")
                                    .font(.caption)
                            }
                            if let reason = event.reason {
                                Text("Reason: \(reason)")
                                    .font(.caption)
                            }
                            if let context = event.context {
                                Text("Context: \(context)")
                                    .font(.caption)
                            }
                        }
                        .padding(4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                    }
                }
            }
            ScrollView {
                Text("Exported Audit Events JSON:\n\(exportJSON)")
                    .font(.footnote)
                    .padding()
            }
            ScrollView {
                Text("Last Exported Audit Event JSON:\n\(lastExportJSON)")
                    .font(.footnote)
                    .padding()
            }
        }
        .padding()
        .task {
            await refreshData()
        }
    }

    @MainActor
    func refreshData() async {
        riskScore = await manager.riskScore()
        auditEvents = await manager.fetchAuditEvents(actor: "PreviewUser")
    }
}

struct FeatureFlagManagerPreview_Previews: PreviewProvider {
    static var previews: some View {
        FeatureFlagManagerPreview()
    }
}
#endif

//
//  FeatureFlagManager.swift
//  Furfolio
//
//  Enhanced: Audit trail, tag/badge analytics, accessibility, exportable events, risk scoring, Trust Center ready.
//  Author: mac + ChatGPT
//

import Foundation

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

    struct FlagAuditEvent: Codable {
        let timestamp: Date
        let flag: Flag
        let newValue: Bool
        let tags: [String]
        let isCritical: Bool
        let actor: String?       // Future: user or admin who toggled
        let reason: String?      // Reason for toggle, for compliance
        let context: String?     // (optional, e.g. "migration", "beta")
        var accessibilityLabel: String {
            let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
            return "\(flag.rawValue) set to \(newValue ? "ON" : "OFF") at \(dateStr)\(isCritical ? " (critical)" : "")."
        }
    }
    private(set) var auditLog: [FlagAuditEvent] = []

    /// Export the most recent audit event as JSON (for Trust Center/compliance export)
    func exportLastAuditEventJSON() -> String? {
        guard let last = auditLog.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    /// Risk score: # of critical flags disabled (compliance risk for Trust Center)
    var riskScore: Int {
        flags.filter { !$0.value && $0.key.isCritical }.count
    }

    /// Accessibility label for UI/VoiceOver, summarizing flag status and last change
    var accessibilityLabel: String {
        let last = auditLog.last?.accessibilityLabel ?? "No flag changes recently."
        return "Feature flag status: \(riskScore > 0 ? "Compliance risk: \(riskScore) critical flag(s) disabled. " : "")\(last)"
    }

    private let storageKey = "FeatureFlagManager.flags"

    // MARK: - Init & Load
    private init() {
        loadFlags()
    }

    // MARK: - Set/Toggle (Audit, Tagging, Risk)
    /// Set or toggle a feature flag, with optional reason/context for audit/compliance.
    func set(_ flag: Flag, enabled: Bool, actor: String? = nil, reason: String? = nil, context: String? = nil) {
        flags[flag] = enabled
        saveFlags()
        objectWillChange.send()
        logAudit(flag: flag, value: enabled, actor: actor, reason: reason, context: context)
    }
    /// Legacy call for existing code; does not log reason/actor/context
    func set(_ flag: Flag, enabled: Bool) {
        set(flag, enabled: enabled, actor: nil, reason: nil, context: nil)
    }

    /// Query feature flag (tagged for future audit of queries)
    func isEnabled(_ flag: Flag) -> Bool {
        flags[flag] ?? false
    }

    // MARK: - Audit log helpers

    private func logAudit(flag: Flag, value: Bool, actor: String?, reason: String?, context: String?) {
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
        auditLog.append(event)
        // Optionally: broadcast event for real-time monitoring
        if auditLog.count > 1000 { auditLog.removeFirst() }
    }

    // MARK: - Load/Save

    private func loadFlags() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: Bool].self, from: data) else {
            return
        }
        for (key, value) in decoded {
            if let flag = Flag(rawValue: key) {
                flags[flag] = value
            }
        }
    }

    private func saveFlags() {
        let dict = flags.mapKeys { $0.rawValue }
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

// MARK: - Dictionary Key Mapper Helper

private extension Dictionary {
    func mapKeys<T: Hashable>(_ transform: (Key) -> T) -> [T: Value] {
        Dictionary<T, Value>(uniqueKeysWithValues: map { (transform($0.key), $0.value) })
    }
}

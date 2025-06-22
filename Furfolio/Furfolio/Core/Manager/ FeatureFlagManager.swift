//
//  FeatureFlagManager.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import Foundation

// MARK: - FeatureFlagManager (Centralized, Modular, Auditable Feature Flag System)

/// Centralized manager for feature flags in the Furfolio app.
/// FeatureFlagManager is designed to be modular, auditable, and extensible.
/// All flag changes must be auditable to meet compliance, business, and diagnostic requirements.
/// Future integration with the Trust Center and event logging systems is planned to enhance security and traceability.
@MainActor
final class FeatureFlagManager: ObservableObject {
    static let shared = FeatureFlagManager()

    /// Define all flags here.
    /// Each feature flag must be documented with clear business and compliance rationale.
    /// New feature flags should be added with appropriate documentation to maintain auditability and governance.
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
    }

    /// Flag values (defaults).
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

    private let storageKey = "FeatureFlagManager.flags"

    private init() {
        loadFlags()
    }

    /// Enable or disable a feature flag.
    /// This method ensures modular control of features and supports auditability of all changes.
    /// Planned integration with Trust Center will enforce permissions and event logging for compliance.
    func set(_ flag: Flag, enabled: Bool) {
        // TODO: Integrate audit/event logging and Trust Center permissions for flag changes.
        flags[flag] = enabled
        saveFlags()
        objectWillChange.send()
    }

    /// Check if a flag is enabled.
    /// Querying feature flags is modular and designed to support audit trails.
    /// Trust Center integration is planned to secure access to flag states.
    func isEnabled(_ flag: Flag) -> Bool {
        // TODO: Integrate audit/event logging and Trust Center permissions for flag changes.
        flags[flag] ?? false
    }

    /// Load persisted flag values.
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

    /// Save current flag values to UserDefaults.
    private func saveFlags() {
        // TODO: Ensure all flag changes are audited for compliance and traceability.
        let dict = flags.mapKeys { $0.rawValue }
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

// MARK: - Helper Extension

private extension Dictionary {
    /// Maps the keys of the dictionary to a new type.
    /// Use with care to maintain key type integrity and avoid collisions.
    /// This is a utility method to assist in transforming dictionary keys safely.
    func mapKeys<T: Hashable>(_ transform: (Key) -> T) -> [T: Value] {
        Dictionary<T, Value>(uniqueKeysWithValues: map { (transform($0.key), $0.value) })
    }
}

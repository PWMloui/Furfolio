//
//  HealthObservation.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import Foundation
import SwiftData

/**
 HealthObservationAuditEntry represents a single audit entry for tracking changes to HealthObservation instances.
 */
@Model public struct HealthObservationAuditEntry: Identifiable {
    @Attribute(.unique) public var id: UUID
    public let timestamp: Date
    public let entry: String
    
    public init(id: UUID = UUID(), timestamp: Date = Date(), entry: String) {
        self.id = id
        self.timestamp = timestamp
        self.entry = entry
    }
}

/// Actor for concurrency-safe audit logging of HealthObservation changes.
public actor HealthObservationAuditManager {
    private var buffer: [HealthObservationAuditEntry] = []
    private let maxEntries = 100
    public static let shared = HealthObservationAuditManager()

    /// Add a new audit entry, retaining only the most recent `maxEntries` entries.
    public func add(_ entry: HealthObservationAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Fetch recent audit entries up to the specified limit.
    public func recent(limit: Int = 20) -> [HealthObservationAuditEntry] {
        Array(buffer.suffix(limit))
    }

    /// Export all audit entries as a JSON string.
    public func exportJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(buffer),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        return "[]"
    }
}

/**
 HealthObservation represents a single recorded health data point for a dog within the Furfolio app.

 Architecture:
 - Designed as a value type (struct) for safety and concurrency readiness.
 - Conforms to Identifiable and Codable for seamless integration with SwiftUI lists and data persistence.

 Concurrency:
 - Immutable `id` and `createdAt` ensure thread-safe unique identification and creation timestamp.
 - Mutable properties can be safely updated on appropriate queues or via Swift’s concurrency mechanisms.

 Analytics / Audit:
 - Includes `createdAt` and `updatedAt` timestamps for audit trails and analytics tracking.
 - Enables monitoring of health data changes over time.

 Diagnostics:
 - Conforms to Codable for easy serialization and debugging.
 - Provides descriptive properties and localized display names for UI diagnostics.

 Localization:
 - All user-facing strings are localized using NSLocalizedString for internationalization support.

 Accessibility:
 - Designed to support accessibility by providing clear, localized descriptions of observation types and dates.

 Compliance:
 - Stores minimal personal data (dogID references) and avoids sensitive user info.

 Preview / Testability:
 - Includes a SwiftUI PreviewProvider with sample data for UI development and testing.

 */
@Model public struct HealthObservation: Identifiable {
    
    /// Unique identifier for the health observation.
    @Attribute(.unique) public var id: UUID
    
    /// Identifier of the associated dog.
    public var dogID: UUID
    
    /// Date and time when the observation was made.
    public var date: Date
    
    /// Type of the observation (e.g., weight, temperature).
    public var type: ObservationType
    
    /// The observed value as a string (e.g., "102.5°F", "75 lbs", "Lethargic").
    public var value: String
    
    /// Optional descriptive notes providing additional context.
    public var notes: String?
    
    /// Timestamp when the observation was created.
    public let createdAt: Date
    
    /// Timestamp when the observation was last updated.
    public var updatedAt: Date

    // --- Audit Logging ---

    /// Asynchronously logs an audit entry describing a change.
    public func addAudit(_ entry: String) async {
        let localized = NSLocalizedString(entry, comment: "HealthObservation audit log entry")
        let auditEntry = HealthObservationAuditEntry(timestamp: Date(), entry: localized)
        await HealthObservationAuditManager.shared.add(auditEntry)
    }

    /// Fetches recent audit entries asynchronously.
    public func recentAuditEntries(limit: Int = 5) async -> [HealthObservationAuditEntry] {
        await HealthObservationAuditManager.shared.recent(limit: limit)
    }

    /// Exports the audit log as a JSON string asynchronously.
    public func exportAuditLogJSON() async -> String {
        await HealthObservationAuditManager.shared.exportJSON()
    }
    
    /**
     Types of health observations supported.
     
     Localized display names provide user-friendly descriptions.
     */
    public enum ObservationType: String, Codable, CaseIterable {
        case weight
        case temperature
        case behavior
        case other
        
        /// Localized display name for the observation type.
        public var displayName: String {
            switch self {
            case .weight:
                return NSLocalizedString("Weight", comment: "Observation type: weight")
            case .temperature:
                return NSLocalizedString("Temperature", comment: "Observation type: temperature")
            case .behavior:
                return NSLocalizedString("Behavior", comment: "Observation type: behavior")
            case .other:
                return NSLocalizedString("Other", comment: "Observation type: other")
            }
        }
    }
    
    /**
     Creates a new HealthObservation instance.
     
     - Parameters:
       - dogID: The UUID of the dog associated with this observation.
       - date: The date and time of the observation. Defaults to current date/time.
       - type: The type of observation.
       - value: The observed value as a string.
       - notes: Optional notes for additional context.
     */
    public init(dogID: UUID, date: Date = Date(), type: ObservationType, value: String, notes: String? = nil) {
        self.id = UUID()
        self.dogID = dogID
        self.date = date
        self.type = type
        self.value = value
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = self.createdAt
    }
    
    @Attribute(.transient)
    /// Formatted string representation of the observation date for display.
    public var formattedDate: String {
        return DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short)
    }
    
    @Attribute(.transient)
    /// Localized description of the observation type.
    public var typeDescription: String {
        return type.displayName
    }
}

#if DEBUG
import SwiftUI

struct HealthObservation_Previews: PreviewProvider {
    static var previews: some View {
        List {
            Section(header: Text(NSLocalizedString("Sample Health Observations", comment: "Preview section header"))) {
                ForEach(sampleObservations) { observation in
                    VStack(alignment: .leading) {
                        Text(observation.typeDescription)
                            .font(.headline)
                        Text(observation.formattedDate)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(observation.value)
                            .font(.body)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    static var sampleObservations: [HealthObservation] {
        let dogID = UUID()
        return [
            HealthObservation(dogID: dogID, date: Date().addingTimeInterval(-3600), type: .temperature, value: "102.5°F", notes: NSLocalizedString("Slightly elevated temperature", comment: "Sample note")),
            HealthObservation(dogID: dogID, date: Date().addingTimeInterval(-86400), type: .weight, value: "75 lbs", notes: nil),
            HealthObservation(dogID: dogID, date: Date().addingTimeInterval(-7200), type: .behavior, value: NSLocalizedString("Lethargic", comment: "Sample behavior value"), notes: NSLocalizedString("Less active than usual", comment: "Sample note"))
        ]
    }
}
#endif

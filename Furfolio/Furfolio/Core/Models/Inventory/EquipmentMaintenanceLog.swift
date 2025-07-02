//
//  EquipmentMaintenanceLog.swift
//  Furfolio
//
//  Created by mac on 6/25/25.

/**
 EquipmentMaintenanceLog.swift
 =============================

 Purpose:
 --------
 Defines the data model for recording equipment maintenance events within the Furfolio app. This file encapsulates all necessary types and logic to track, audit, and present maintenance logs for equipment, ensuring robust record-keeping, compliance, and support for analytics.

 Architecture:
 -------------
 - The primary type is `EquipmentMaintenanceLog`, a struct conforming to `Identifiable` and `Codable` for seamless integration with SwiftUI and persistence layers.
 - Maintenance types are represented by a nested `MaintenanceType` enum, supporting localization and UI presentation.
 - An audit trail is provided by `EquipmentMaintenanceAuditEntry` and managed via the actor `EquipmentMaintenanceAuditManager`, ensuring thread-safe audit log operations.

 Concurrency Readiness:
 ----------------------
 - Audit management is handled by a Swift `actor` (`EquipmentMaintenanceAuditManager`) for safe concurrent usage.
 - Async methods are provided for audit log operations to integrate with modern Swift concurrency.

 Analytics & Audit Hooks:
 ------------------------
 - Every maintenance log supports audit trail entries for changes or important actions.
 - The audit manager supports exporting logs for compliance or analytics review.

 Diagnostics:
 ------------
 - Audit log export in JSON format for external diagnostics.
 - Timestamps for creation and updates are tracked for each log.

 Localization:
 -------------
 - All user-facing strings (including enum display names and property labels) are localized via `NSLocalizedString`.

 Accessibility:
 --------------
 - Date formatting and string representations are localized for user clarity.
 - Designed for use with SwiftUI, supporting accessibility modifiers in UI.

 Compliance:
 -----------
 - Audit trail supports regulatory and organizational compliance.
 - Data model is Codable for secure storage and export.

 Preview/Testability:
 --------------------
 - SwiftUI preview provider is included for rapid UI iteration and developer testing.
 - Sample data and audit logging are demonstrated in preview.
 */




import Foundation
import SwiftUI
import SwiftData



/// Represents a log entry for equipment maintenance in Furfolio.
@Model public struct EquipmentMaintenanceLog: Identifiable {
    /// Unique identifier for the maintenance log.
    @Attribute(.unique) public var id: UUID
    /// The ID of the equipment this log refers to.
    public var equipmentID: UUID
    /// The date when maintenance occurred.
    public var date: Date
    /// The type of maintenance performed.
    public var maintenanceType: MaintenanceType
    /// A description of the work done.
    public var description: String
    /// The name of the person who performed the maintenance.
    public var performedBy: String
    /// The optional next maintenance due date.
    public var nextDueDate: Date?
    /// Optional additional notes.
    public var notes: String?
    /// Timestamp when this log was created.
    public let createdAt: Date
    /// Timestamp when this log was last updated.
    public var updatedAt: Date

    /// Describes the type of maintenance performed.
    public enum MaintenanceType: String, Codable, CaseIterable {
        case routine
        case repair
        case inspection
        case other

        /// Returns a localized display name for the maintenance type.
        public var displayName: String {
            switch self {
            case .routine:
                return NSLocalizedString("Routine", comment: "Routine maintenance type")
            case .repair:
                return NSLocalizedString("Repair", comment: "Repair maintenance type")
            case .inspection:
                return NSLocalizedString("Inspection", comment: "Inspection maintenance type")
            case .other:
                return NSLocalizedString("Other", comment: "Other maintenance type")
            }
        }
    }

    /**
     Initializes a new equipment maintenance log.
     - Parameters:
        - equipmentID: The ID of the equipment.
        - date: The date when maintenance occurred. Defaults to now.
        - maintenanceType: The type of maintenance.
        - description: Description of work done.
        - performedBy: Name of person who performed the maintenance.
        - nextDueDate: Optional next maintenance due date.
        - notes: Optional additional notes.
     */
    public init(
        equipmentID: UUID,
        date: Date = Date(),
        maintenanceType: MaintenanceType,
        description: String,
        performedBy: String,
        nextDueDate: Date? = nil,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.equipmentID = equipmentID
        self.date = date
        self.maintenanceType = maintenanceType
        self.description = description
        self.performedBy = performedBy
        self.nextDueDate = nextDueDate
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = self.createdAt
    }

    /// Returns a localized, formatted date string for the maintenance date.
    @Attribute(.transient)
    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }

    /// Returns the localized description of the maintenance type.
    @Attribute(.transient)
    public var typeDescription: String {
        maintenanceType.displayName
    }

    // MARK: - Audit Logging

    /**
     Adds an audit entry for this maintenance log.
     - Parameter entry: The audit entry text.
     */
    public func addAudit(_ entry: String) async {
        let auditEntry = EquipmentMaintenanceAuditEntry(
            id: UUID(),
            timestamp: Date(),
            entry: entry
        )
        await EquipmentMaintenanceAuditManager.shared.add(auditEntry)
    }

    /**
     Returns the most recent audit entries for this maintenance log.
     - Parameter limit: Maximum number of entries to return (default: 5).
     */
    public func recentAuditEntries(limit: Int = 5) async -> [EquipmentMaintenanceAuditEntry] {
        await EquipmentMaintenanceAuditManager.shared.recent(limit: limit)
    }

    /**
     Exports the entire audit log as a JSON string.
     */
    public func exportAuditLogJSON() async -> String {
        await EquipmentMaintenanceAuditManager.shared.exportJSON()
    }
}

/// Represents a single audit entry for equipment maintenance operations.
@Model public struct EquipmentMaintenanceAuditEntry: Identifiable {
    /// Unique identifier for the audit entry.
    @Attribute(.unique) public var id: UUID
    /// Timestamp when the audit entry was created.
    public let timestamp: Date
    /// The audit entry text.
    public let entry: String
}

/// Manages the audit trail for equipment maintenance logs in a concurrency-safe way.
public actor EquipmentMaintenanceAuditManager {
    private var buffer: [EquipmentMaintenanceAuditEntry] = []
    private let maxEntries = 100

    /// Shared singleton instance for global audit logging.
    public static let shared = EquipmentMaintenanceAuditManager()

    /**
     Adds a new audit entry to the log.
     - Parameter entry: The audit entry to add.
     */
    public func add(_ entry: EquipmentMaintenanceAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer = Array(buffer.suffix(maxEntries))
        }
    }

    /**
     Returns the most recent audit entries, limited to the specified count.
     - Parameter limit: Maximum number of entries to return.
     */
    public func recent(limit: Int) -> [EquipmentMaintenanceAuditEntry] {
        Array(buffer.suffix(limit))
    }

    /**
     Exports the audit log as a JSON string.
     - Returns: JSON string representation of the audit log.
     */
    public func exportJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(buffer),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        return "[]"
    }
}


#if DEBUG
import SwiftUI

/// SwiftUI preview for EquipmentMaintenanceLog, demonstrating list and audit logging.
struct EquipmentMaintenanceLog_Previews: PreviewProvider {
    static var previews: some View {
        let logs: [EquipmentMaintenanceLog] = [
            EquipmentMaintenanceLog(
                equipmentID: UUID(),
                date: Date(),
                maintenanceType: .routine,
                description: NSLocalizedString("Changed oil and filter", comment: "Sample maintenance description"),
                performedBy: NSLocalizedString("Alex", comment: "Sample performer name"),
                nextDueDate: Calendar.current.date(byAdding: .month, value: 6, to: Date()),
                notes: NSLocalizedString("No issues found.", comment: "Sample notes")
            ),
            EquipmentMaintenanceLog(
                equipmentID: UUID(),
                date: Date().addingTimeInterval(-86400 * 30),
                maintenanceType: .inspection,
                description: NSLocalizedString("Annual safety inspection completed", comment: "Sample maintenance description"),
                performedBy: NSLocalizedString("Jamie", comment: "Sample performer name"),
                nextDueDate: Calendar.current.date(byAdding: .year, value: 1, to: Date()),
                notes: nil
            ),
            EquipmentMaintenanceLog(
                equipmentID: UUID(),
                date: Date().addingTimeInterval(-86400 * 90),
                maintenanceType: .repair,
                description: NSLocalizedString("Replaced worn brake pads", comment: "Sample maintenance description"),
                performedBy: NSLocalizedString("Casey", comment: "Sample performer name"),
                nextDueDate: nil,
                notes: NSLocalizedString("Parts ordered from supplier.", comment: "Sample notes")
            )
        ]
        List(logs) { log in
            VStack(alignment: .leading, spacing: 4) {
                Text(log.typeDescription)
                    .font(.headline)
                Text(log.formattedDate)
                    .font(.subheadline)
                Text(log.description)
                    .font(.body)
                if let notes = log.notes {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Button(NSLocalizedString("Add Audit Entry", comment: "Button to add audit entry")) {
                    Task {
                        await log.addAudit(NSLocalizedString("Preview: Viewed maintenance log in preview.", comment: "Sample audit entry"))
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .listStyle(InsetGroupedListStyle())
        .previewDisplayName(NSLocalizedString("Equipment Maintenance Log Preview", comment: "Preview name"))
    }
}
#endif

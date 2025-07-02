
/**
 StaffShift
 ----------
 A model representing a scheduled shift for a staff member in Furfolio, with full audit logging and localization support.

 - **Architecture**: Decodable and Identifiable for networking and SwiftUI.
 - **Concurrency & Audit**: Uses an async actor `StaffShiftAuditManager` to log shift events.
 - **Localization**: Date displays are localized via `DateFormatter`.
 - **Accessibility**: Computed properties expose accessible labels.
 - **Diagnostics & Preview/Testability**: Supports retrieving and exporting audit logs asynchronously.
 */

import Foundation

/// Represents a scheduled shift for a staff member.
public struct StaffShift: Identifiable, Codable {
    /// Unique identifier for the shift.
    public let id: UUID
    /// The staff member’s identifier.
    public var staffId: UUID
    /// Shift start date and time.
    public var startDate: Date
    /// Shift end date and time.
    public var endDate: Date
    /// Optional notes about the shift.
    public var notes: String?
    /// Creation timestamp.
    public let createdAt: Date
    /// Last updated timestamp.
    public var updatedAt: Date

    /// Localized, formatted start date string.
    public var displayStart: String {
        DateFormatter.localizedString(from: startDate, dateStyle: .medium, timeStyle: .short)
    }

    /// Localized, formatted end date string.
    public var displayEnd: String {
        DateFormatter.localizedString(from: endDate, dateStyle: .medium, timeStyle: .short)
    }

    /// Accessibility label combining start and end.
    public var accessibilityLabel: String {
        String(
            format: NSLocalizedString("Shift from %@ to %@", comment: "Shift accessibility label"),
            displayStart,
            displayEnd
        )
    }

    /// Initializes a new StaffShift.
    public init(
        id: UUID = UUID(),
        staffId: UUID,
        startDate: Date,
        endDate: Date,
        notes: String? = nil
    ) {
        self.id = id
        self.staffId = staffId
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
        // Log creation event
        Task {
            await StaffShiftAuditManager.shared.add(
                StaffShiftAuditEntry(shiftId: id, event: NSLocalizedString("Shift created", comment: "")))
        }
    }
}

// MARK: - Audit Entry & Manager

/// A record of a StaffShift audit event.
public struct StaffShiftAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let shiftId: UUID
    public let event: String

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        shiftId: UUID,
        event: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.shiftId = shiftId
        self.event = event
    }
}

/// Concurrency-safe actor for logging StaffShift events.
public actor StaffShiftAuditManager {
    private var buffer: [StaffShiftAuditEntry] = []
    private let maxEntries = 100
    public static let shared = StaffShiftAuditManager()

    /// Add a new audit entry, trimming oldest if exceeding capacity.
    public func add(_ entry: StaffShiftAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Fetch recent audit entries.
    public func recent(limit: Int = 20) -> [StaffShiftAuditEntry] {
        Array(buffer.suffix(limit))
    }

    /// Export audit entries as JSON.
    public func exportJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(buffer),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }
}

// MARK: - Async Audit Methods

public extension StaffShift {
    /// Log an arbitrary audit event for this shift.
    func logEvent(_ event: String) async {
        let localized = NSLocalizedString(event, comment: "")
        updatedAt = Date()
        await StaffShiftAuditManager.shared.add(
            StaffShiftAuditEntry(shiftId: id, event: localized)
        )
    }

    /// Fetch recent audit entries for this shift.
    func recentAuditEntries(limit: Int = 20) async -> [StaffShiftAuditEntry] {
        await StaffShiftAuditManager.shared.recent(limit: limit)
    }

    /// Export audit log for this shift as JSON.
    func exportAuditLogJSON() async -> String {
        await StaffShiftAuditManager.shared.exportJSON()
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

struct StaffShift_Previews: PreviewProvider {
    static var previews: some View {
        let sampleShift = StaffShift(
            staffId: UUID(),
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            notes: "Afternoon shift"
        )
        VStack(spacing: 8) {
            Text("Staff ID: \(sampleShift.staffId.uuidString)")
            Text("Start: \(sampleShift.displayStart)")
            Text("End: \(sampleShift.displayEnd)")
            Text(sampleShift.notes ?? "")
            Button("Log Change") {
                Task {
                    await sampleShift.logEvent("Notes updated")
                    let entries = await sampleShift.recentAuditEntries(limit: 5)
                    print(entries)
                }
            }
        }
        .padding()
        .accessibilityLabel(sampleShift.accessibilityLabel)
    }
}
#endif

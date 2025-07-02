//
//  RewardPool.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import Foundation
import SwiftUI
import SwiftData

/**
 RewardPool
 -----------
 A data model representing a reward pool for customer loyalty within the Furfolio app.

 - **Architecture**: Conforms to Identifiable and Codable for SwiftUI and networking.
 - **Concurrency & Audit**: Provides async audit logging via `RewardPoolAuditManager` actor.
 - **Fields**: Pool name, total points available, associated participants, and timestamps.
 - **Localization**: All user-facing strings use `NSLocalizedString`.
 - **Accessibility**: Computed properties expose formatted values for VoiceOver.
 - **Preview/Testability**: Includes SwiftUI preview demonstrating creation, point allocation, and audit logging.
 */

/// Represents a pool of reward points shared among participants.
@Model public struct RewardPool: Identifiable {
    /// Unique identifier for the pool
    @Attribute(.unique) public var id: UUID
    /// Human-readable name for the pool
    public var name: String
    /// Total points available in this pool
    public var totalPoints: Int
    /// Participant IDs associated with this pool
    public var participantIDs: [UUID]
    /// Creation timestamp
    public let createdAt: Date
    /// Last updated timestamp
    public var updatedAt: Date

    /// Localized display name for the pool.
    @Attribute(.transient) public var displayName: String {
        NSLocalizedString(name, comment: "Reward pool name")
    }

    /// Formatted total points string.
    @Attribute(.transient) public var formattedPoints: String {
        String(
            format: NSLocalizedString("%d points", comment: "Formatted total points"),
            totalPoints
        )
    }

    /// Number of participants.
    @Attribute(.transient) public var participantCount: Int {
        participantIDs.count
    }

    /// Initializes a new RewardPool.
    public init(
        id: UUID = UUID(),
        name: String,
        totalPoints: Int = 0,
        participantIDs: [UUID] = []
    ) {
        self.id = id
        self.name = NSLocalizedString(name, comment: "Reward pool name")
        self.totalPoints = totalPoints
        self.participantIDs = participantIDs
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }
}

// MARK: - Audit Entry & Manager

/// A record of a RewardPool audit event.
@Model public struct RewardPoolAuditEntry: Identifiable {
    @Attribute(.unique) public var id: UUID
    public let timestamp: Date
    public let entry: String

    public init(id: UUID = UUID(), timestamp: Date = Date(), entry: String) {
        self.id = id
        self.timestamp = timestamp
        self.entry = entry
    }
}

/// Manages concurrency-safe audit logging for RewardPool events.
public actor RewardPoolAuditManager {
    private var buffer: [RewardPoolAuditEntry] = []
    private let maxEntries = 100
    public static let shared = RewardPoolAuditManager()

    /// Add a new audit entry, capping buffer at `maxEntries`.
    public func add(_ entry: RewardPoolAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Fetch recent audit entries up to the specified limit.
    public func recent(limit: Int = 20) -> [RewardPoolAuditEntry] {
        Array(buffer.suffix(limit))
    }

    /// Export all audit entries as a JSON string.
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

public extension RewardPool {
    /// Asynchronously logs an audit entry for this reward pool.
    /// - Parameter entry: Description of the change.
    func addAudit(_ entry: String) async {
        let localized = NSLocalizedString(entry, comment: "RewardPool audit entry")
        let auditEntry = RewardPoolAuditEntry(timestamp: Date(), entry: localized)
        await RewardPoolAuditManager.shared.add(auditEntry)
        updatedAt = Date()
    }

    /// Fetches recent audit entries for this reward pool.
    /// - Parameter limit: Maximum number of entries to retrieve.
    func recentAuditEntries(limit: Int = 20) async -> [RewardPoolAuditEntry] {
        await RewardPoolAuditManager.shared.recent(limit: limit)
    }

    /// Exports the audit log as a JSON string.
    func exportAuditLogJSON() async -> String {
        await RewardPoolAuditManager.shared.exportJSON()
    }

    /// Allocate points from the pool to a participant.
    /// - Parameters:
    ///   - amount: Number of points to allocate.
    ///   - participantID: The participant receiving points.
    mutating func allocate(points amount: Int, to participantID: UUID) async {
        guard totalPoints >= amount else { return }
        totalPoints -= amount
        if !participantIDs.contains(participantID) {
            participantIDs.append(participantID)
        }
        updatedAt = Date()
        await addAudit("Allocated \(amount) points to \(participantID)")
    }
}

// MARK: - Preview

#if DEBUG
struct RewardPool_Previews: PreviewProvider {
    static var previews: some View {
        var pool = RewardPool(name: "Holiday Bonus", totalPoints: 1000)
        return VStack(spacing: 16) {
            Text(pool.displayName).font(.headline)
            Text(pool.formattedPoints).font(.subheadline)
            Button("Allocate 100 points") {
                Task {
                    await pool.allocate(points: 100, to: UUID())
                    let entries = await pool.recentAuditEntries(limit: 5)
                    print(entries)
                }
            }
            Button("Export Audit JSON") {
                Task {
                    let json = await pool.exportAuditLogJSON()
                    print(json)
                }
            }
        }.padding()
    }
}
#endif

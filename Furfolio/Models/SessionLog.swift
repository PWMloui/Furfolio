
//
//  SessionLog.swift
//  Furfolio
//
//  Created by mac on 5/26/25.
//

import Foundation
import SwiftData

/// Tracks an actual service session's start and end times for utilization reporting.
@Model
final class SessionLog: Identifiable, Codable, CustomStringConvertible {
    // MARK: – Persistent Properties

    @Attribute var id: UUID
    @Attribute var startedAt: Date
    @Attribute var endedAt: Date?
    @Relationship(deleteRule: .nullify) var appointment: Appointment?

    // MARK: – Init

    init(
        appointment: Appointment? = nil,
        startedAt: Date = Date(),
        endedAt: Date? = nil
    ) {
        self.id = UUID()
        self.appointment = appointment
        self.startedAt = startedAt
        self.endedAt = endedAt
    }

    // MARK: – Computed Properties

    /// Duration in seconds once the session has ended.
    @Transient
    var duration: TimeInterval? {
        guard let end = endedAt else { return nil }
        return end.timeIntervalSince(startedAt)
    }

    /// Duration in minutes once the session has ended.
    @Transient
    var durationMinutes: Double? {
        guard let seconds = duration else { return nil }
        return seconds / 60.0
    }

    /// True if the session is currently active (no end time recorded).
    @Transient
    var isActive: Bool {
        return endedAt == nil
    }

    // MARK: – Actions

    /// Marks the session as ended at the current time.
    func endSession(at date: Date = Date()) {
        guard endedAt == nil else { return }
        endedAt = date
    }

    /// Resets the session to active, clearing the end time.
    func restartSession() {
        endedAt = nil
        startedAt = Date()
    }

    /// Toggles the session: ends if active, restarts if ended.
    func toggleSession(at date: Date = Date()) {
        if isActive {
            endSession(at: date)
        } else {
            restartSession()
        }
    }

    // MARK: – Codable
    private enum CodingKeys: String, CodingKey {
        case id
        case startedAt
        case endedAt
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encode(endedAt, forKey: .endedAt)
    }

    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let startedAt = try container.decode(Date.self, forKey: .startedAt)
        let endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
        self.init(appointment: nil, startedAt: startedAt, endedAt: endedAt)
        self.id = id
    }

    // MARK: – CustomStringConvertible
    var description: String {
        let startString = ISO8601DateFormatter().string(from: startedAt)
        let endString = endedAt != nil ? ISO8601DateFormatter().string(from: endedAt!) : "active"
        let durationStr: String
        if let mins = durationMinutes {
            durationStr = String(format: "%.2f min", mins)
        } else {
            durationStr = "n/a"
        }
        return "SessionLog(id: \(id), start: \(startString), end: \(endString), duration: \(durationStr))"
    }
}

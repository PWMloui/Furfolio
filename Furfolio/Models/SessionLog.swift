//
//  SessionLog.swift
//  Furfolio
//
//  Created by mac on 5/26/25.
//

import Foundation
import SwiftData
import os

/// Tracks an actual service session's start and end times for utilization reporting.
@Model
final class SessionLog: Identifiable, Codable, CustomStringConvertible {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "SessionLog")

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
        logger.log("Initialized SessionLog id: \(id), startedAt: \(startedAt), endedAt: \(String(describing: endedAt))")
    }

    // MARK: – Computed Properties

    /// Duration in seconds once the session has ended.
    @Transient
    var duration: TimeInterval? {
        logger.log("Accessing duration for SessionLog id: \(id)")
        guard let end = endedAt else { return nil }
        return end.timeIntervalSince(startedAt)
    }

    /// Duration in minutes once the session has ended.
    @Transient
    var durationMinutes: Double? {
        logger.log("Accessing durationMinutes for SessionLog id: \(id)")
        guard let seconds = duration else { return nil }
        return seconds / 60.0
    }

    /// True if the session is currently active (no end time recorded).
    @Transient
    var isActive: Bool {
        logger.log("Accessing isActive for SessionLog id: \(id)")
        return endedAt == nil
    }

    // MARK: – Actions

    /// Marks the session as ended at the current time.
    func endSession(at date: Date = Date()) {
        logger.log("Ending session for SessionLog id: \(id) at date: \(date)")
        guard endedAt == nil else {
            logger.log("endSession skipped: already ended for SessionLog id: \(id)")
            return
        }
        endedAt = date
        logger.log("Session ended for SessionLog id: \(id), endedAt: \(endedAt!)")
    }

    /// Resets the session to active, clearing the end time.
    func restartSession() {
        logger.log("Restarting session for SessionLog id: \(id)")
        endedAt = nil
        startedAt = Date()
        logger.log("Session restarted for SessionLog id: \(id), startedAt: \(startedAt)")
    }

    /// Toggles the session: ends if active, restarts if ended.
    func toggleSession(at date: Date = Date()) {
        logger.log("Toggling session for SessionLog id: \(id), isActive: \(isActive)")
        if isActive {
            endSession(at: date)
        } else {
            restartSession()
        }
        logger.log("Session toggle complete for SessionLog id: \(id), new isActive: \(isActive)")
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
        logger.log("Generating description for SessionLog id: \(id)")
        let startString = ISO8601DateFormatter().string(from: startedAt)
        let endString = endedAt != nil ? ISO8601DateFormatter().string(from: endedAt!) : "active"
        let durationStr: String
        if let mins = durationMinutes {
            durationStr = String(format: "%.2f min", mins)
        } else {
            durationStr = "n/a"
        }
        logger.log("Description generated: \(description)")
        return "SessionLog(id: \(id), start: \(startString), end: \(endString), duration: \(durationStr))"
    }
}

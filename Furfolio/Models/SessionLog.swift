
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
final class SessionLog: Identifiable {
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
}

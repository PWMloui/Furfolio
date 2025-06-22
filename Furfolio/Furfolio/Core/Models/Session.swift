//
//  Session.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import Foundation
import SwiftData

// MARK: - Session (Modular, Tokenized, Auditable Session/Activity Model)

/// Session model representing user or staff login/activity tracking in Furfolio.
/// This is a modular, tokenized, auditable session/activity entity designed to support security, analytics, compliance, role-based access control (RBAC), and UI integration.
/// It facilitates comprehensive tracking and management of sessions across business, staff, device, and automation contexts.
/// The model supports detailed audit trails, session lifecycle management, and role-based permissions to enhance compliance and operational workflows.
@available(iOS 18.0, *)
@Model
final class Session: Identifiable, ObservableObject {
    
    // MARK: - Identity
    
    /// Unique identifier for the session.
    /// Used for audit trails, session correlation in analytics, and ensuring entity uniqueness in business workflows.
    @Attribute(.unique)
    var id: UUID
    
    /// Username, staff, or user identifier associated with this session.
    /// Critical for user-level audit, analytics segmentation, and enforcing business rules.
    var userID: String
    
    /// Staff role for RBAC (owner, assistant, admin, unknown).
    /// Defines access permissions and enforces role-based compliance policies.
    /// Essential for audit logging, security reviews, and analytics on staff activities.
    enum StaffRole: String, Codable, Sendable, CaseIterable {
        /// Owner role with highest privileges, typically for audit and compliance oversight.
        case owner
        /// Assistant role with limited permissions; tracked for role-based access and analytics.
        case assistant
        /// Admin role with elevated permissions; important for security audits and compliance.
        case admin
        /// Unknown or undefined role; flagged for audit and potential compliance review.
        case unknown
    }
    /// Role of the staff member associated with this session.
    /// Supports RBAC enforcement, audit trail classification, and compliance reporting.
    var staffRole: StaffRole?
    
    // MARK: - Metadata
    
    /// Device or platform information where the session originated.
    /// Used for security audits, device-based analytics, and compliance tracking.
    var deviceInfo: String?
    
    /// IP address associated with the session.
    /// Critical for security audits, anomaly detection, and regulatory compliance.
    var ipAddress: String?
    
    /// Location information tied to the session.
    /// Supports compliance with regional regulations, audit trails, and geo-analytics.
    var location: String?
    
    /// Optional session token or credential for local session identification.
    /// Facilitates secure session management, token-based authentication, and audit event correlation.
    var sessionToken: String?
    
    /// Notes or additional metadata related to the session.
    /// Useful for audit annotations, business workflow comments, and incident tracking.
    var notes: String?
    
    /// Type of session (e.g., device, user, automation).
    /// Enables segmentation in analytics, business logic branching, and compliance categorization.
    var sessionType: String?
    
    // MARK: - Session State
    
    /// Session start time.
    /// Key for audit timelines, session duration analytics, and compliance reporting.
    var startedAt: Date
    
    /// Session end time; nil if session is active.
    /// Used to determine session lifecycle, audit completeness, and compliance status.
    var endedAt: Date?
    
    /// Timestamp of the last activity within this session.
    /// Supports real-time analytics, session timeout enforcement, and security monitoring.
    var lastActivityAt: Date?
    
    /// Computed property indicating if the session is currently active.
    /// Used in UI workflows, security checks, and session management logic.
    var isActive: Bool {
        endedAt == nil
    }
    
    /// Initializes a new Session.
    /// - Parameters:
    ///   - id: Unique session identifier, ensuring audit traceability and entity uniqueness.
    ///   - userID: User or staff identifier, critical for audit, analytics, and business logic.
    ///   - staffRole: Role of the staff member, enabling RBAC enforcement and compliance.
    ///   - deviceInfo: Device or platform info for security audits and analytics.
    ///   - startedAt: Session start time for audit timelines and compliance.
    ///   - endedAt: Session end time to mark session lifecycle completion.
    ///   - sessionToken: Local session token for secure session management.
    ///   - ipAddress: IP address for security and compliance auditing.
    ///   - location: Location info to support geo-compliance and analytics.
    ///   - notes: Additional notes for audit annotations and business workflows.
    ///   - sessionType: Session type to classify session context in analytics and compliance.
    ///   - lastActivityAt: Last activity timestamp to monitor session activity and security.
    /// This initializer supports comprehensive audit logging, analytics tracking, and business process integration.
    init(
        id: UUID = UUID(),
        userID: String,
        staffRole: StaffRole? = nil,
        deviceInfo: String? = nil,
        startedAt: Date? = nil,
        endedAt: Date? = nil,
        sessionToken: String? = nil,
        ipAddress: String? = nil,
        location: String? = nil,
        notes: String? = nil,
        sessionType: String? = nil,
        lastActivityAt: Date? = nil
    ) {
        self.id = id
        self.userID = userID
        self.staffRole = staffRole
        self.deviceInfo = deviceInfo
        self.startedAt = startedAt ?? Date()
        self.endedAt = endedAt
        self.sessionToken = sessionToken
        self.ipAddress = ipAddress
        self.location = location
        self.notes = notes
        self.sessionType = sessionType
        self.lastActivityAt = lastActivityAt
    }
    
    /// Ends the session, updates the end time, optional note, and last activity timestamp.
    /// - Parameter note: Optional note to append to the session notes.
    /// This method is critical for audit/event logging, marking session completion for analytics,
    /// and ensuring security/compliance by formally closing the session lifecycle.
    func endSession(note: String? = nil) {
        objectWillChange.send()
        self.endedAt = Date()
        self.lastActivityAt = self.endedAt
        if let note = note, !note.isEmpty {
            if let existingNotes = self.notes, !existingNotes.isEmpty {
                self.notes = existingNotes + "\n" + note
            } else {
                self.notes = note
            }
        }
    }
    
    /// Checks if the session has exceeded a maximum allowed duration.
    /// - Parameter maxDuration: Maximum duration allowed for the session.
    /// - Returns: True if the session is expired, false otherwise.
    /// This method supports security and compliance policies by identifying stale or expired sessions,
    /// and assists in analytics on session durations and user behavior.
    func isExpired(maxDuration: TimeInterval) -> Bool {
        guard let ended = endedAt else {
            return Date().timeIntervalSince(startedAt) > maxDuration
        }
        return ended.timeIntervalSince(startedAt) > maxDuration
    }
    
    /// A static test/dummy session for previews or unit testing.
    /// Designed for demo, unit-test, business logic validation, and audit/preview purposes.
    /// Enables UI previews and test scenarios with realistic session data.
    static let testSession = Session(
        userID: "testUser",
        staffRole: .unknown,
        deviceInfo: "iPhone 14 Pro",
        startedAt: Date().addingTimeInterval(-3600),
        notes: "Test session for unit testing",
        sessionType: "user"
    )
}

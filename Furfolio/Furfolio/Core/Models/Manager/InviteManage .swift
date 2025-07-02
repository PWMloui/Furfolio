//
//  InviteManage .swift
//  Furfolio
//
//  Created by mac on 6/30/25.
//

import Foundation
import SwiftData

/// Roles that can be invited to the app.
public enum InviteRole: String, CaseIterable, Identifiable {
    public var id: String { rawValue }
    case groomer, receptionist, owner, admin

    public var displayName: String {
        switch self {
        case .groomer: return NSLocalizedString("Groomer", comment: "")
        case .receptionist: return NSLocalizedString("Receptionist", comment: "")
        case .owner: return NSLocalizedString("Owner", comment: "")
        case .admin: return NSLocalizedString("Administrator", comment: "")
        }
    }
}

/// Represents a pending or accepted invitation.
@Model public struct Invite: Identifiable {
    @Attribute(.unique) public var id: UUID = UUID()
    /// Email address of the invitee.
    public var email: String
    /// Role assigned upon acceptance.
    public var role: InviteRole
    /// When the invite was sent.
    public var sentAt: Date = Date()
    /// When the invite was accepted (nil if pending).
    public var acceptedAt: Date?

    /// Transient computed status.
    @Attribute(.transient)
    public var status: String {
        acceptedAt == nil
            ? NSLocalizedString("Pending", comment: "Invite status pending")
            : NSLocalizedString("Accepted", comment: "Invite status accepted")
    }
}

/// Audit log for invitation actions.
@Model public struct InviteAuditEvent: Identifiable {
    @Attribute(.unique) public var id: UUID = UUID()
    public var timestamp: Date = Date()
    public var action: String    // "sent", "accepted", "revoked"
    public var email: String
    public var role: InviteRole
    public var notes: String?

    @Attribute(.transient)
    public var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return String(
            format: NSLocalizedString("Invite %@ for %@ at %@", comment: "Audit label"),
            action, email, dateStr
        )
    }
}

/// Manages creating, tracking, and auditing invitations.
public class InviteManager: ObservableObject {
    public static let shared = InviteManager()
    private init() {}

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \.sentAt, order: .forward) public var invites: [Invite]
    @Query(sort: \.timestamp, order: .forward) public var auditLog: [InviteAuditEvent]

    /// Sends a new invitation.
    public func sendInvite(to email: String, role: InviteRole) {
        let invite = Invite(email: email, role: role)
        modelContext.insert(invite)
        logAction("sent", for: invite, notes: nil)
    }

    /// Marks an invite as accepted.
    public func acceptInvite(_ invite: Invite) {
        var updated = invite
        updated.acceptedAt = Date()
        modelContext.insert(updated)
        logAction("accepted", for: updated, notes: nil)
    }

    /// Revokes an existing invite.
    public func revokeInvite(_ invite: Invite, reason: String? = nil) {
        modelContext.delete(invite)
        logAction("revoked", for: invite, notes: reason)
    }

    /// Exports the last audit event to JSON.
    public func exportLastAuditJSON() async -> String? {
        guard let last = auditLog.last else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return (try? String(data: encoder.encode(last), encoding: .utf8))
    }

    /// Clears all invitations and audit history.
    public func clearAll() async {
        invites.forEach { modelContext.delete($0) }
        auditLog.forEach { modelContext.delete($0) }
    }

    private func logAction(_ action: String, for invite: Invite, notes: String?) {
        let event = InviteAuditEvent(
            action: action,
            email: invite.email,
            role: invite.role,
            notes: notes
        )
        modelContext.insert(event)
    }
}

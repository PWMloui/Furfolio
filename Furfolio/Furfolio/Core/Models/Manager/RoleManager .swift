//
//  RoleManager .swift
//  Furfolio
//
//  Created by mac on 6/30/25.
//

import Foundation
import SwiftUI
import SwiftData

/// Defines the various roles available to staff in the app.
public enum RoleType: String, CaseIterable, Identifiable {
    public var id: String { rawValue }
    case owner, groomer, receptionist, admin

    /// Human-readable display name.
    public var displayName: String {
        switch self {
        case .owner: return NSLocalizedString("Owner", comment: "")
        case .groomer: return NSLocalizedString("Groomer", comment: "")
        case .receptionist: return NSLocalizedString("Receptionist", comment: "")
        case .admin: return NSLocalizedString("Administrator", comment: "")
        }
    }
}

/// Associates a staff member with a role.
@Model public struct RoleAssignment: Identifiable {
    @Attribute(.unique) public var id: UUID = UUID()
    /// Identifier of the staff member.
    public var staffId: UUID
    /// Assigned role.
    public var role: RoleType
    /// Timestamp when the role was assigned.
    public var assignedAt: Date = Date()

    /// Accessibility label for VoiceOver.
    @Attribute(.transient)
    public var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: assignedAt, dateStyle: .medium, timeStyle: .short)
        return "\(role.displayName) assigned at \(dateStr)"
    }
}

/// Manages creating, querying, and revoking role assignments.
public class RoleManager: ObservableObject {
    public static let shared = RoleManager()
    private init() {}

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \.assignedAt, order: .forward) public var assignments: [RoleAssignment]

    /// Assigns a role to a staff member.
    public func assign(_ role: RoleType, to staffId: UUID) {
        let assignment = RoleAssignment(staffId: staffId, role: role)
        modelContext.insert(assignment)
    }

    /// Revokes a specific role assignment.
    public func revoke(_ assignment: RoleAssignment) {
        modelContext.delete(assignment)
    }

    /// Retrieves all roles assigned to a specific staff member.
    public func roles(for staffId: UUID) -> [RoleAssignment] {
        assignments.filter { $0.staffId == staffId }
    }

    /// Exports all role assignments as pretty-printed JSON.
    public func exportAssignmentsJSON() async -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(assignments) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Clears all role assignments.
    public func clearAllAssignments() async {
        assignments.forEach { modelContext.delete($0) }
    }
}

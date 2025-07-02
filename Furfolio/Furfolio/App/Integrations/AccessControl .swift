//
//  AccessControl.swift
//  Furfolio
//
//  Created by mac on 6/30/25.
//  Enhanced for modular role-based business, audit, and cross-module security.
//

import Foundation

// MARK: - Staff Roles in Furfolio

public enum FurfolioRole: String, Codable, CaseIterable, Equatable {
    case owner
    case receptionist
    case groomer
    case bather
    case admin
    case accountant
    case manager
    case guest
    case unknown
}

// MARK: - Permission Types

public enum FurfolioPermission: String, Codable, CaseIterable, Equatable {
    // General
    case viewDashboard
    case viewClients
    case editClients
    case viewAppointments
    case editAppointments
    case viewCharges
    case editCharges
    case manageStaff
    case viewReports
    case exportData
    case submitIncident
    case viewIncidents
    case manageInventory
    case editSettings
    case auditLogs
    case overrideRestrictions // Superuser/demo/dev only

    // Add as needed: e.g. .delete, .approve, .review, .assign, .archive, etc
}

// MARK: - Permission Set (Role ➔ Permissions)

public struct FurfolioPermissionSet: Codable, Equatable {
    public let role: FurfolioRole
    public let permissions: Set<FurfolioPermission>
}

// MARK: - Default Permission Matrix

public struct FurfolioAccessMatrix {
    // Customize for your business rules
    public static let defaults: [FurfolioPermissionSet] = [
        .init(role: .owner, permissions: Set(FurfolioPermission.allCases)),
        .init(role: .admin, permissions: Set(FurfolioPermission.allCases)),
        .init(role: .manager, permissions: [.viewDashboard, .viewClients, .editClients, .viewAppointments, .editAppointments, .viewCharges, .editCharges, .manageStaff, .viewReports, .submitIncident, .viewIncidents, .manageInventory, .editSettings]),
        .init(role: .receptionist, permissions: [.viewDashboard, .viewClients, .editClients, .viewAppointments, .editAppointments, .viewCharges, .editCharges, .submitIncident, .viewIncidents, .manageInventory]),
        .init(role: .groomer, permissions: [.viewClients, .viewAppointments, .editAppointments, .submitIncident, .viewIncidents]),
        .init(role: .bather, permissions: [.viewClients, .viewAppointments, .submitIncident]),
        .init(role: .accountant, permissions: [.viewDashboard, .viewCharges, .viewReports, .exportData]),
        .init(role: .guest, permissions: [.viewDashboard]),
        .init(role: .unknown, permissions: [])
    ]

    public static func permissions(for role: FurfolioRole) -> Set<FurfolioPermission> {
        defaults.first(where: { $0.role == role })?.permissions ?? []
    }
}

// MARK: - Access Control Engine (Singleton/Injectable)

public final class AccessControl: ObservableObject {
    public static let shared = AccessControl()

    // Role is determined by the current user/session
    @Published public private(set) var currentRole: FurfolioRole = .unknown

    // For audit logging (optional, can be nil for privacy)
    public var auditLogger: ((FurfolioAccessLogEvent) -> Void)?

    // Override for demo/superuser
    public var superuserEnabled: Bool = false

    // Assign current role (from login/session/etc)
    public func setRole(_ role: FurfolioRole) {
        self.currentRole = role
        auditLogger?(.roleChanged(newRole: role, timestamp: Date()))
    }

    // Core permission check
    public func can(_ permission: FurfolioPermission, forRole role: FurfolioRole? = nil, log: Bool = true) -> Bool {
        let checkRole = role ?? currentRole
        if superuserEnabled {
            auditLogger?(.accessGranted(role: checkRole, permission: permission, reason: "Superuser override", timestamp: Date()))
            return true
        }
        let allowed = FurfolioAccessMatrix.permissions(for: checkRole).contains(permission)
        if log {
            if allowed {
                auditLogger?(.accessGranted(role: checkRole, permission: permission, reason: nil, timestamp: Date()))
            } else {
                auditLogger?(.accessDenied(role: checkRole, permission: permission, reason: nil, timestamp: Date()))
            }
        }
        return allowed
    }

    // Helper: Assert or throw if not allowed (for business critical operations)
    public func require(_ permission: FurfolioPermission, file: StaticString = #file, line: UInt = #line) throws {
        guard can(permission) else {
            let msg = "Access denied: \(permission.rawValue) (\(currentRole.rawValue))"
            auditLogger?(.accessDenied(role: currentRole, permission: permission, reason: msg, timestamp: Date()))
            throw FurfolioAccessError.denied(reason: msg, file: file, line: line)
        }
    }
}

// MARK: - Audit/Event Logging

public enum FurfolioAccessLogEvent {
    case roleChanged(newRole: FurfolioRole, timestamp: Date)
    case accessGranted(role: FurfolioRole, permission: FurfolioPermission, reason: String?, timestamp: Date)
    case accessDenied(role: FurfolioRole, permission: FurfolioPermission, reason: String?, timestamp: Date)
}

// MARK: - Error

public enum FurfolioAccessError: LocalizedError {
    case denied(reason: String, file: StaticString, line: UInt)

    public var errorDescription: String? {
        switch self {
            case .denied(let reason, let file, let line):
                return "\(reason) at \(file):\(line)"
        }
    }
}

// MARK: - Example Usage

/*
 let ac = AccessControl.shared
 ac.setRole(.receptionist)

 if ac.can(.viewDashboard) {
     // show dashboard
 }
 
 do {
     try ac.require(.manageStaff)
     // staff management code
 } catch {
     // show error
 }
*/

// You can plug this engine into any View, Service, ViewModel, or use with your QuickActionsMenu, etc.

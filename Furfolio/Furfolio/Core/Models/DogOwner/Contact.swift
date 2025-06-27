//
//  Contact.swift
//  Furfolio
//
//  Enhanced: analytics/audit–ready, Trust Center–capable, preview/test–injectable.
//

import Foundation
import SwiftData

// MARK: - Analytics/Audit Protocol

public protocol ContactAnalyticsLogger {
    func log(event: String, info: [String: Any]?)
}
public struct NullContactAnalyticsLogger: ContactAnalyticsLogger {
    public init() {}
    public func log(event: String, info: [String: Any]?) {}
}

// MARK: - Trust Center Permission Protocol

public protocol ContactTrustCenterDelegate {
    func permission(for action: String, context: [String: Any]?) -> Bool
}
public struct NullContactTrustCenterDelegate: ContactTrustCenterDelegate {
    public init() {}
    public func permission(for action: String, context: [String: Any]?) -> Bool { true }
}

@MainActor
@Model
final class Contact: Identifiable, ObservableObject, Hashable {

    // MARK: - Static Analytics/Trust Center (Injectable)
    static var analyticsLogger: ContactAnalyticsLogger = NullContactAnalyticsLogger()
    static var trustCenterDelegate: ContactTrustCenterDelegate = NullContactTrustCenterDelegate()

    // MARK: - Properties
    @Attribute(.unique)
    var id: UUID = UUID()
    var address: String?
    var city: String?
    var country: String?
    var email: String?
    var emergencyContactName: String?
    var emergencyContactPhone: String?
    var firstName: String?
    var lastName: String?
    var notes: String?
    var phone: String?
    var relationship: String? // e.g., Owner, Staff, Vet, etc.
    var state: String?
    var zip: String?
    var createdAt: Date = Date()
    var lastModified: Date = Date()
    var isDeleted: Bool = false
    var auditLog: [ContactAuditEntry] = []

    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        firstName: String? = nil,
        lastName: String? = nil,
        phone: String? = nil,
        email: String? = nil,
        address: String? = nil,
        city: String? = nil,
        state: String? = nil,
        zip: String? = nil,
        country: String? = nil,
        emergencyContactName: String? = nil,
        emergencyContactPhone: String? = nil,
        relationship: String? = nil,
        notes: String? = nil,
        createdAt: Date = Date(),
        lastModified: Date = Date(),
        isDeleted: Bool = false,
        auditLog: [ContactAuditEntry] = []
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.phone = phone
        self.email = email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.address = address
        self.city = city
        self.state = state
        self.zip = zip
        self.country = country
        self.emergencyContactName = emergencyContactName
        self.emergencyContactPhone = emergencyContactPhone
        self.relationship = relationship
        self.notes = notes
        self.createdAt = createdAt
        self.lastModified = lastModified
        self.isDeleted = isDeleted
        self.auditLog = auditLog
        Self.analyticsLogger.log(event: "created", info: [
            "id": id.uuidString,
            "firstName": firstName as Any,
            "lastName": lastName as Any,
            "relationship": relationship as Any
        ])
    }

    // MARK: - Computed Properties

    var fullName: String {
        [firstName, lastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    var formattedAddress: String {
        [address, city, state, zip, country]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    var isEmergencyContactAvailable: Bool {
        guard let name = emergencyContactName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty,
              let phone = emergencyContactPhone?.trimmingCharacters(in: .whitespacesAndNewlines), !phone.isEmpty else {
            return false
        }
        return true
    }

    var accessibilityLabel: String {
        var desc = "Contact: \(fullName)"
        if let role = relationship { desc += ". Role: \(role)" }
        if let phone = formattedPhone { desc += ". Phone: \(phone)" }
        if let email = formattedEmail { desc += ". Email: \(email)" }
        return desc
    }

    var formattedPhone: String? {
        guard let phone = phone else { return nil }
        let digits = phone.filter { $0.isNumber }
        switch digits.count {
        case 10:
            let areaCode = digits.prefix(3)
            let prefix = digits.dropFirst(3).prefix(3)
            let lineNumber = digits.suffix(4)
            return "(\(areaCode)) \(prefix)-\(lineNumber)"
        default:
            return phone
        }
    }

    var formattedEmail: String? {
        email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // MARK: - Methods

    func update(with updated: Contact, by userID: String?, auditTag: String? = nil) {
        guard Self.trustCenterDelegate.permission(for: "update", context: [
            "contactID": id.uuidString,
            "userID": userID as Any,
            "auditTag": auditTag as Any
        ]) else {
            Self.analyticsLogger.log(event: "update_denied", info: [
                "contactID": id.uuidString,
                "userID": userID as Any,
                "auditTag": auditTag as Any
            ])
            return
        }
        let oldName = fullName
        self.firstName = updated.firstName
        self.lastName = updated.lastName
        self.phone = updated.phone
        self.email = updated.email
        self.address = updated.address
        self.city = updated.city
        self.state = updated.state
        self.zip = updated.zip
        self.country = updated.country
        self.emergencyContactName = updated.emergencyContactName
        self.emergencyContactPhone = updated.emergencyContactPhone
        self.relationship = updated.relationship
        self.notes = updated.notes
        updateLastModified()
        addAuditEntry(action: "Contact updated", details: "Updated from \(oldName) to \(updated.fullName)", userID: userID)
        Self.analyticsLogger.log(event: "updated", info: [
            "contactID": id.uuidString,
            "userID": userID as Any,
            "auditTag": auditTag as Any
        ])
    }

    func markDeleted(by userID: String?, auditTag: String? = nil) {
        guard !isDeleted else { return }
        guard Self.trustCenterDelegate.permission(for: "delete", context: [
            "contactID": id.uuidString,
            "userID": userID as Any,
            "auditTag": auditTag as Any
        ]) else {
            Self.analyticsLogger.log(event: "delete_denied", info: [
                "contactID": id.uuidString,
                "userID": userID as Any,
                "auditTag": auditTag as Any
            ])
            return
        }
        isDeleted = true
        updateLastModified()
        addAuditEntry(action: "Contact deleted", userID: userID)
        Self.analyticsLogger.log(event: "deleted", info: [
            "contactID": id.uuidString,
            "userID": userID as Any,
            "auditTag": auditTag as Any
        ])
    }

    func restore(by userID: String?, auditTag: String? = nil) {
        guard isDeleted else { return }
        guard Self.trustCenterDelegate.permission(for: "restore", context: [
            "contactID": id.uuidString,
            "userID": userID as Any,
            "auditTag": auditTag as Any
        ]) else {
            Self.analyticsLogger.log(event: "restore_denied", info: [
                "contactID": id.uuidString,
                "userID": userID as Any,
                "auditTag": auditTag as Any
            ])
            return
        }
        isDeleted = false
        updateLastModified()
        addAuditEntry(action: "Contact restored", userID: userID)
        Self.analyticsLogger.log(event: "restored", info: [
            "contactID": id.uuidString,
            "userID": userID as Any,
            "auditTag": auditTag as Any
        ])
    }

    func updateLastModified() {
        lastModified = Date()
        addAuditEntry(action: "Timestamp updated", userID: nil)
    }

    func addAuditEntry(action: String, details: String? = nil, userID: String?) {
        let entry = ContactAuditEntry(action: action, details: details, userID: userID)
        auditLog.append(entry)
        Self.analyticsLogger.log(event: "audit_entry_added", info: [
            "contactID": id.uuidString,
            "action": action,
            "details": details as Any,
            "userID": userID as Any
        ])
    }

    // MARK: - Hashable
    static func == (lhs: Contact, rhs: Contact) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    // MARK: - Sample Data
    static let sample = Contact(
        firstName: "Jane",
        lastName: "Doe",
        phone: "555-123-4567",
        email: "jane.doe@example.com",
        address: "123 Main St",
        city: "Springfield",
        state: "IL",
        zip: "62704",
        country: "USA",
        emergencyContactName: "John Doe",
        emergencyContactPhone: "555-987-6543",
        relationship: "Owner",
        notes: "Prefers email contact."
    )
}

// MARK: - ContactAuditEntry

struct ContactAuditEntry: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var date: Date = Date()
    var action: String
    var details: String?
    var userID: String?
}

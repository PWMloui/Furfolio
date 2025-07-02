//
//  Contact.swift
//  Furfolio
//
//  Enhanced: analytics/audit–ready, Trust Center–capable, preview/test–injectable.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Analytics/Audit Protocol

/// Protocol defining asynchronous analytics logging for Contact events.
/// Implementations should perform logging asynchronously to avoid blocking the main thread.
public protocol ContactAnalyticsLogger {
    /// Logs an event with optional additional information asynchronously.
    /// - Parameters:
    ///   - event: The name of the event to log.
    ///   - info: Optional dictionary containing additional event information.
    func log(event: String, info: [String: Any]?) async
}

/// No-op implementation of ContactAnalyticsLogger for default use.
/// All methods complete immediately without side effects.
public struct NullContactAnalyticsLogger: ContactAnalyticsLogger {
    public init() {}
    public func log(event: String, info: [String: Any]?) async {}
}

// MARK: - Trust Center Permission Protocol

/// Protocol defining asynchronous permission checks for Contact actions.
/// Implementations should perform permission checks asynchronously, potentially involving I/O or user interaction.
public protocol ContactTrustCenterDelegate {
    /// Determines asynchronously whether permission is granted for a given action in a specified context.
    /// - Parameters:
    ///   - action: The action to check permission for.
    ///   - context: Optional context information related to the permission check.
    /// - Returns: A Boolean indicating whether permission is granted.
    func permission(for action: String, context: [String: Any]?) async -> Bool
}

/// No-op implementation of ContactTrustCenterDelegate that always grants permission.
public struct NullContactTrustCenterDelegate: ContactTrustCenterDelegate {
    public init() {}
    public func permission(for action: String, context: [String: Any]?) async -> Bool { true }
}

@MainActor
@Model
final class Contact: Identifiable, ObservableObject, Hashable {

    // MARK: - Static Analytics/Trust Center (Injectable)
    /// Shared analytics logger instance. Defaults to a no-op logger.
    static var analyticsLogger: ContactAnalyticsLogger = NullContactAnalyticsLogger()
    /// Shared trust center delegate instance. Defaults to always grant permission.
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

    /// Audit log entries for this contact.
    /// Access and mutation are protected by a dedicated serial dispatch queue to ensure thread safety.
    private var _auditLog: [ContactAuditEntry] = []
    private let auditQueue = DispatchQueue(label: "com.furfolio.contact.auditQueue", qos: .userInitiated)

    /// Provides thread-safe access to auditLog.
    @Attribute(.transient)
    var auditLog: [ContactAuditEntry] {
        get async {
            await withCheckedContinuation { continuation in
                auditQueue.async {
                    continuation.resume(returning: self._auditLog)
                }
            }
        }
    }

    // MARK: - Initialization
    /// Initializes a new Contact instance.
    /// - Parameters: Various contact details.
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
        self._auditLog = auditLog
        Task {
            await Self.analyticsLogger.log(event: "created", info: [
                "id": id.uuidString,
                "firstName": firstName as Any,
                "lastName": lastName as Any,
                "relationship": relationship as Any
            ])
        }
    }

    // MARK: - Computed Properties

    @Attribute(.transient)
    var fullName: String {
        [firstName, lastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    @Attribute(.transient)
    var formattedAddress: String {
        [address, city, state, zip, country]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    @Attribute(.transient)
    var isEmergencyContactAvailable: Bool {
        guard let name = emergencyContactName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty,
              let phone = emergencyContactPhone?.trimmingCharacters(in: .whitespacesAndNewlines), !phone.isEmpty else {
            return false
        }
        return true
    }

    /// Asynchronously returns a localized accessibility label describing the contact.
    /// This includes localized role, phone, and email information.
    @Attribute(.transient)
    var accessibilityLabel: String {
        get async {
            var desc = NSLocalizedString("Contact: %@", comment: "Accessibility label prefix for contact name")
            desc = String(format: desc, fullName)
            if let role = relationship, !role.isEmpty {
                let roleLabel = NSLocalizedString("Role: %@", comment: "Accessibility label for contact role")
                desc += ". " + String(format: roleLabel, role)
            }
            if let phone = formattedPhone {
                let phoneLabel = NSLocalizedString("Phone: %@", comment: "Accessibility label for contact phone")
                desc += ". " + String(format: phoneLabel, phone)
            }
            if let email = formattedEmail {
                let emailLabel = NSLocalizedString("Email: %@", comment: "Accessibility label for contact email")
                desc += ". " + String(format: emailLabel, email)
            }
            return desc
        }
    }

    @Attribute(.transient)
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

    @Attribute(.transient)
    var formattedEmail: String? {
        email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // MARK: - Methods

    /// Updates the contact with new information asynchronously.
    /// This method checks permission asynchronously before applying changes.
    /// It also logs audit entries and analytics events asynchronously.
    /// - Parameters:
    ///   - updated: The updated Contact instance containing new data.
    ///   - userID: Optional user identifier performing the update.
    ///   - auditTag: Optional tag for auditing purposes.
    func update(with updated: Contact, by userID: String?, auditTag: String? = nil) async {
        let permissionGranted = await Self.trustCenterDelegate.permission(for: "update", context: [
            "contactID": id.uuidString,
            "userID": userID as Any,
            "auditTag": auditTag as Any
        ])
        guard permissionGranted else {
            await Self.analyticsLogger.log(event: "update_denied", info: [
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
        await updateLastModified()
        let details = String(format: NSLocalizedString("Updated from %@ to %@", comment: "Audit entry detail for contact update"), oldName, updated.fullName)
        await addAuditEntry(action: NSLocalizedString("Contact updated", comment: "Audit entry action for contact update"), details: details, userID: userID)
        await Self.analyticsLogger.log(event: "updated", info: [
            "contactID": id.uuidString,
            "userID": userID as Any,
            "auditTag": auditTag as Any
        ])
    }

    /// Marks the contact as deleted asynchronously.
    /// Checks permission and logs audit and analytics asynchronously.
    /// - Parameters:
    ///   - userID: Optional user identifier performing the deletion.
    ///   - auditTag: Optional tag for auditing purposes.
    func markDeleted(by userID: String?, auditTag: String? = nil) async {
        guard !isDeleted else { return }
        let permissionGranted = await Self.trustCenterDelegate.permission(for: "delete", context: [
            "contactID": id.uuidString,
            "userID": userID as Any,
            "auditTag": auditTag as Any
        ])
        guard permissionGranted else {
            await Self.analyticsLogger.log(event: "delete_denied", info: [
                "contactID": id.uuidString,
                "userID": userID as Any,
                "auditTag": auditTag as Any
            ])
            return
        }
        isDeleted = true
        await updateLastModified()
        await addAuditEntry(action: NSLocalizedString("Contact deleted", comment: "Audit entry action for contact deletion"), userID: userID)
        await Self.analyticsLogger.log(event: "deleted", info: [
            "contactID": id.uuidString,
            "userID": userID as Any,
            "auditTag": auditTag as Any
        ])
    }

    /// Restores a previously deleted contact asynchronously.
    /// Checks permission and logs audit and analytics asynchronously.
    /// - Parameters:
    ///   - userID: Optional user identifier performing the restoration.
    ///   - auditTag: Optional tag for auditing purposes.
    func restore(by userID: String?, auditTag: String? = nil) async {
        guard isDeleted else { return }
        let permissionGranted = await Self.trustCenterDelegate.permission(for: "restore", context: [
            "contactID": id.uuidString,
            "userID": userID as Any,
            "auditTag": auditTag as Any
        ])
        guard permissionGranted else {
            await Self.analyticsLogger.log(event: "restore_denied", info: [
                "contactID": id.uuidString,
                "userID": userID as Any,
                "auditTag": auditTag as Any
            ])
            return
        }
        isDeleted = false
        await updateLastModified()
        await addAuditEntry(action: NSLocalizedString("Contact restored", comment: "Audit entry action for contact restoration"), userID: userID)
        await Self.analyticsLogger.log(event: "restored", info: [
            "contactID": id.uuidString,
            "userID": userID as Any,
            "auditTag": auditTag as Any
        ])
    }

    /// Updates the last modified timestamp asynchronously and logs an audit entry.
    func updateLastModified() async {
        lastModified = Date()
        await addAuditEntry(action: NSLocalizedString("Timestamp updated", comment: "Audit entry action for timestamp update"), userID: nil)
    }

    /// Adds an audit entry asynchronously.
    /// This method is concurrency-safe and appends to the audit log on a dedicated serial queue.
    /// It also logs the audit event asynchronously.
    /// - Parameters:
    ///   - action: The action description for the audit entry.
    ///   - details: Optional detailed description.
    ///   - userID: Optional user identifier associated with the action.
    func addAuditEntry(action: String, details: String? = nil, userID: String?) async {
        await withCheckedContinuation { continuation in
            auditQueue.async {
                let entry = ContactAuditEntry(action: action, details: details, userID: userID)
                self._auditLog.append(entry)
                continuation.resume()
            }
        }
        await Self.analyticsLogger.log(event: "audit_entry_added", info: [
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
    /// Creates a sample Contact instance asynchronously.
    /// This initializer is synchronous but any async setup should be done after creation.
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
        notes: NSLocalizedString("Prefers email contact.", comment: "Sample contact note")
    )
}

// MARK: - ContactAuditEntry

/// Represents an audit entry for contact changes.
/// Conforms to Codable, Identifiable, and Hashable.
struct ContactAuditEntry: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var date: Date = Date()
    var action: String
    var details: String?
    var userID: String?
}

// MARK: - SwiftUI PreviewProvider demonstrating async usage

#if DEBUG
struct Contact_Previews: PreviewProvider {
    struct PreviewView: View {
        @StateObject private var contact = Contact.sample
        @State private var auditEntries: [ContactAuditEntry] = []
        @State private var accessibilityLabel: String = ""

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Contact: \(contact.fullName)")
                    .font(.headline)
                Text("Accessibility Label:")
                    .font(.subheadline)
                Text(accessibilityLabel)
                    .font(.caption)
                    .foregroundColor(.gray)
                Button(NSLocalizedString("Update Contact", comment: "Button to update contact")) {
                    Task {
                        var updated = contact
                        updated.phone = "555-000-1111"
                        await contact.update(with: updated, by: "previewUser", auditTag: "previewUpdate")
                        auditEntries = await contact.auditLog
                        accessibilityLabel = await contact.accessibilityLabel
                    }
                }
                Button(NSLocalizedString("Mark Deleted", comment: "Button to mark contact deleted")) {
                    Task {
                        await contact.markDeleted(by: "previewUser", auditTag: "previewDelete")
                        auditEntries = await contact.auditLog
                        accessibilityLabel = await contact.accessibilityLabel
                    }
                }
                Button(NSLocalizedString("Restore Contact", comment: "Button to restore contact")) {
                    Task {
                        await contact.restore(by: "previewUser", auditTag: "previewRestore")
                        auditEntries = await contact.auditLog
                        accessibilityLabel = await contact.accessibilityLabel
                    }
                }
                Divider()
                Text(NSLocalizedString("Audit Log:", comment: "Label for audit log list"))
                    .font(.headline)
                List(auditEntries) { entry in
                    VStack(alignment: .leading) {
                        Text(entry.action)
                            .font(.subheadline)
                        if let details = entry.details {
                            Text(details)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text("\(entry.date, formatter: dateFormatter)")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding()
            .task {
                auditEntries = await contact.auditLog
                accessibilityLabel = await contact.accessibilityLabel
            }
        }

        private var dateFormatter: DateFormatter {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter
        }
    }

    static var previews: some View {
        PreviewView()
    }
}
#endif

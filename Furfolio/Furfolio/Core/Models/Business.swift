//
//  Business.swift
//  Furfolio
//
//  Enhanced: analytics/audit–ready, Trust Center–capable, preview/test–injectable.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Analytics/Audit Protocol

public protocol BusinessAnalyticsLogger {
    func log(event: String, info: [String: Any]?)
}
public struct NullBusinessAnalyticsLogger: BusinessAnalyticsLogger {
    public init() {}
    public func log(event: String, info: [String: Any]?) {}
}

// MARK: - Trust Center Permission Protocol

public protocol BusinessTrustCenterDelegate {
    func permission(for action: String, context: [String: Any]?) -> Bool
}
public struct NullBusinessTrustCenterDelegate: BusinessTrustCenterDelegate {
    public init() {}
    public func permission(for action: String, context: [String: Any]?) -> Bool { true }
}

// MARK: - AuditLoggable Protocol

protocol AuditLoggable {
    func logChange(description: String)
}

// MARK: - Business (Enterprise Enhanced)

@Model
final class Business: Identifiable, ObservableObject, AuditLoggable {
    // MARK: - Audit/Analytics/Trust Center Injectables
    static var analyticsLogger: BusinessAnalyticsLogger = NullBusinessAnalyticsLogger()
    static var trustCenterDelegate: BusinessTrustCenterDelegate = NullBusinessTrustCenterDelegate()

    // MARK: - Unique Identifier
    @Attribute(.unique)
    var id: UUID

    // MARK: - Core Business Details
    @Published @Attribute(.indexed)
    var name: String

    @Published @Attribute(.indexed)
    var ownerName: String

    @Published
    var address: String?

    @Published
    var phone: String?

    @Published
    var email: String?

    @Published
    var website: String?

    // MARK: - Branding
    @Published
    var logoImageData: Data?

    @Published
    var colorTheme: String?

    // MARK: - Staff and Multi-user/Role Support
    @Published @Relationship(deleteRule: .cascade)
    var staff: [StaffMember]

    // MARK: - Settings
    @Published
    var defaultServiceDuration: Int

    @Published
    var currency: String

    @Published
    var timeZone: String

    @Published
    var locale: String

    // MARK: - Analytics and Status
    @Published
    var dateCreated: Date

    @Published
    var lastModified: Date

    @Published
    var isActive: Bool

    // MARK: - Feature Flags and TSP Integration
    @Published
    var featureFlags: [String: Bool]

    @Published
    var tspIntegrationEnabled: Bool

    // MARK: - Initializer

    init(
        id: UUID = UUID(),
        name: String,
        ownerName: String,
        address: String? = nil,
        phone: String? = nil,
        email: String? = nil,
        website: String? = nil,
        logoImageData: Data? = nil,
        colorTheme: String? = nil,
        staff: [StaffMember] = [],
        defaultServiceDuration: Int = 60,
        currency: String = "USD",
        timeZone: String = TimeZone.current.identifier,
        locale: String = Locale.current.identifier,
        dateCreated: Date = Date(),
        lastModified: Date = Date(),
        isActive: Bool = true,
        featureFlags: [String: Bool] = [:],
        tspIntegrationEnabled: Bool = false
    ) {
        self.id = id
        self.name = name
        self.ownerName = ownerName
        self.address = address
        self.phone = phone
        self.email = email
        self.website = website
        self.logoImageData = logoImageData
        self.colorTheme = colorTheme
        self.staff = staff
        self.defaultServiceDuration = defaultServiceDuration
        self.currency = currency
        self.timeZone = timeZone
        self.locale = locale
        self.dateCreated = dateCreated
        self.lastModified = lastModified
        self.isActive = isActive
        self.featureFlags = featureFlags
        self.tspIntegrationEnabled = tspIntegrationEnabled
        Self.analyticsLogger.log(event: "created", info: [
            "id": id.uuidString,
            "name": name,
            "ownerName": ownerName,
            "createdAt": dateCreated
        ])
    }

    // MARK: - Computed Properties

    var logoImage: Image? {
        guard let data = logoImageData, let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
    }

    var formattedAddress: String {
        guard let addr = address, !addr.isEmpty else { return "—" }
        return addr
    }

    var staffCount: Int {
        staff.count
    }

    var formattedLastModified: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: lastModified)
    }

    var isBrandingComplete: Bool {
        if let color = colorTheme?.trimmingCharacters(in: .whitespacesAndNewlines),
           !color.isEmpty,
           logoImageData != nil {
            return true
        }
        return false
    }

    /// Accessibility: Concise business summary for UI/VoiceOver.
    var accessibilityLabel: String {
        var summary = "Business: \(name). Owner: \(ownerName)."
        summary += isActive ? " Active." : " Inactive."
        summary += " Staff count: \(staffCount)."
        summary += " Last modified: \(formattedLastModified)."
        return summary
    }

    // MARK: - Methods

    /// Updates business settings, with analytics and Trust Center hooks.
    func updateSettings(
        name: String? = nil,
        ownerName: String? = nil,
        address: String? = nil,
        phone: String? = nil,
        email: String? = nil,
        website: String? = nil,
        logoImageData: Data? = nil,
        colorTheme: String? = nil,
        defaultServiceDuration: Int? = nil,
        currency: String? = nil,
        timeZone: String? = nil,
        locale: String? = nil,
        isActive: Bool? = nil,
        featureFlags: [String: Bool]? = nil,
        tspIntegrationEnabled: Bool? = nil,
        auditTag: String? = nil
    ) {
        guard Self.trustCenterDelegate.permission(for: "updateSettings", context: [
            "id": id.uuidString,
            "name": name as Any,
            "ownerName": ownerName as Any,
            "user": ownerName as Any,
            "auditTag": auditTag as Any
        ]) else {
            Self.analyticsLogger.log(event: "updateSettings_denied", info: [
                "id": id.uuidString,
                "name": name as Any,
                "ownerName": ownerName as Any,
                "user": ownerName as Any,
                "auditTag": auditTag as Any
            ])
            return
        }
        if let name = name { self.name = name }
        if let ownerName = ownerName { self.ownerName = ownerName }
        if let address = address { self.address = address }
        if let phone = phone { self.phone = phone }
        if let email = email { self.email = email }
        if let website = website { self.website = website }
        if let logoImageData = logoImageData { self.logoImageData = logoImageData }
        if let colorTheme = colorTheme { self.colorTheme = colorTheme }
        if let defaultServiceDuration = defaultServiceDuration { self.defaultServiceDuration = defaultServiceDuration }
        if let currency = currency { self.currency = currency }
        if let timeZone = timeZone { self.timeZone = timeZone }
        if let locale = locale { self.locale = locale }
        if let isActive = isActive { self.isActive = isActive }
        if let featureFlags = featureFlags { self.featureFlags = featureFlags }
        if let tspIntegrationEnabled = tspIntegrationEnabled { self.tspIntegrationEnabled = tspIntegrationEnabled }
        self.lastModified = Date()
        logChange(description: "Business settings updated")
        Self.analyticsLogger.log(event: "settings_updated", info: [
            "id": id.uuidString,
            "user": ownerName as Any,
            "fieldsChanged": [
                "name": name as Any,
                "ownerName": ownerName as Any,
                "address": address as Any,
                "phone": phone as Any,
                "email": email as Any,
                "website": website as Any,
                "colorTheme": colorTheme as Any
            ],
            "auditTag": auditTag as Any
        ])
    }

    /// Adds a staff member, with audit and Trust Center logic.
    func addStaff(_ staffMember: StaffMember, by user: String?, auditTag: String? = nil) {
        guard Self.trustCenterDelegate.permission(for: "addStaff", context: [
            "businessID": id.uuidString,
            "staffName": staffMember.name,
            "user": user as Any,
            "auditTag": auditTag as Any
        ]) else {
            Self.analyticsLogger.log(event: "addStaff_denied", info: [
                "businessID": id.uuidString,
                "staffName": staffMember.name,
                "user": user as Any,
                "auditTag": auditTag as Any
            ])
            return
        }
        staff.append(staffMember)
        lastModified = Date()
        logChange(description: "Added staff: \(staffMember.name)")
        Self.analyticsLogger.log(event: "staff_added", info: [
            "businessID": id.uuidString,
            "staffName": staffMember.name,
            "user": user as Any,
            "auditTag": auditTag as Any
        ])
    }

    /// Removes a staff member, with audit and Trust Center logic.
    func removeStaff(_ staffMember: StaffMember, by user: String?, auditTag: String? = nil) {
        guard Self.trustCenterDelegate.permission(for: "removeStaff", context: [
            "businessID": id.uuidString,
            "staffName": staffMember.name,
            "user": user as Any,
            "auditTag": auditTag as Any
        ]) else {
            Self.analyticsLogger.log(event: "removeStaff_denied", info: [
                "businessID": id.uuidString,
                "staffName": staffMember.name,
                "user": user as Any,
                "auditTag": auditTag as Any
            ])
            return
        }
        staff.removeAll { $0.id == staffMember.id }
        lastModified = Date()
        logChange(description: "Removed staff: \(staffMember.name)")
        Self.analyticsLogger.log(event: "staff_removed", info: [
            "businessID": id.uuidString,
            "staffName": staffMember.name,
            "user": user as Any,
            "auditTag": auditTag as Any
        ])
    }

    // MARK: - AuditLoggable

    func logChange(description: String) {
        // Replace or extend this for true audit storage, BI, or compliance reporting.
        print("[AuditLog] \(Date()): \(description)")
    }
}

// MARK: - StaffMember Struct (Tokenized)

struct StaffMember: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var role: String

    init(name: String, role: String) {
        self.id = UUID()
        self.name = name
        self.role = role
    }
}

#if DEBUG
import SwiftUI

struct Business_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            BusinessPreviewView()
                .previewDisplayName("Default Business")

            BusinessPreviewView()
                .previewDisplayName("Branding Complete")
                .environment(\.colorScheme, .dark)
        }
    }

    struct BusinessPreviewView: View {
        @StateObject private var business = Business(
            name: "Furfolio Studio",
            ownerName: "Jane Doe",
            address: "123 Main St, Anytown",
            phone: "555-1234",
            email: "contact@furfolio.com",
            website: "https://furfolio.com",
            logoImageData: UIImage(systemName: "pawprint.fill")?.pngData(),
            colorTheme: "#FF6600",
            staff: [StaffMember(name: "John Smith", role: "Stylist")],
            defaultServiceDuration: 45,
            currency: "USD",
            timeZone: TimeZone.current.identifier,
            locale: Locale.current.identifier,
            isActive: true,
            featureFlags: ["newBookingFlow": true],
            tspIntegrationEnabled: true
        )

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text(business.name)
                    .font(.title)
                    .bold()
                if let logo = business.logoImage {
                    logo
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                }
                Text("Owner: \(business.ownerName)")
                Text("Staff Count: \(business.staffCount)")
                Text("Last Modified: \(business.formattedLastModified)")
                Text("Branding Complete: \(business.isBrandingComplete ? "Yes" : "No")")
                Text("Active: \(business.isActive ? "Yes" : "No")")
                Text(business.accessibilityLabel)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
}
#endif

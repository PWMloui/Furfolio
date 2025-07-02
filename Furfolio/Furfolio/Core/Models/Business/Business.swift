//
//  Business.swift
//  Furfolio
//
//  Enhanced: analytics/audit–ready, Trust Center–capable, preview/test–injectable.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct BusinessAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "Business"
}

// MARK: - Audit Event
public struct BusinessAuditEvent: Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let operation: String
    public let businessID: UUID
    public let detail: String
    public let user: String?
    public let context: String?
    public let role: String?
    public let staffID: String?
    public let escalate: Bool

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        operation: String,
        businessID: UUID,
        detail: String,
        user: String?,
        context: String?,
        role: String?,
        staffID: String?,
        escalate: Bool
    ) {
        self.id = id
        self.timestamp = timestamp
        self.operation = operation
        self.businessID = businessID
        self.detail = detail
        self.user = user
        self.context = context
        self.role = role
        self.staffID = staffID
        self.escalate = escalate
    }

    public var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        var base = "[\(dateStr)] \(operation.capitalized) (\(detail))"
        var details = [String]()
        if let user = user { details.append("User: \(user)") }
        if let role = role { details.append("Role: \(role)") }
        if let staffID = staffID { details.append("StaffID: \(staffID)") }
        if let context = context { details.append("Context: \(context)") }
        if escalate { details.append("Escalate: YES") }
        return ([base] + details).joined(separator: " | ")
    }
}

// MARK: - BusinessAuditLogger

fileprivate final class BusinessAuditLogger {
    private static let queue = DispatchQueue(label: "furfolio.business.audit.logger")
    private static var log: [BusinessAuditEvent] = []
    private static let maxLogSize = 200

    static func record(
        operation: String,
        businessID: UUID,
        detail: String,
        user: String? = nil,
        context: String? = nil,
        escalate: Bool = false
    ) {
        let escalateFlag = escalate || operation.lowercased().contains("danger")
            || operation.lowercased().contains("critical") || operation.lowercased().contains("delete")
        let event = BusinessAuditEvent(
            operation: operation,
            businessID: businessID,
            detail: detail,
            user: user,
            context: context ?? BusinessAuditContext.context,
            role: BusinessAuditContext.role,
            staffID: BusinessAuditContext.staffID,
            escalate: escalateFlag
        )
        queue.async {
            log.append(event)
            if log.count > maxLogSize { log.removeFirst(log.count - maxLogSize) }
        }
    }

    static func allEvents(completion: @escaping ([BusinessAuditEvent]) -> Void) {
        queue.async { completion(log) }
    }
    static func exportLastJSON(completion: @escaping (String?) -> Void) {
        queue.async {
            guard let last = log.last else { completion(nil); return }
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let json = (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
            completion(json)
        }
    }
    static func recentEvents(limit: Int = 5, completion: @escaping ([String]) -> Void) {
        queue.async {
            let events = log.suffix(limit).map { $0.accessibilityLabel }
            completion(events)
        }
    }
    static func clearLog() {
        queue.async { log.removeAll() }
    }
    static func lastSummary(completion: @escaping (String) -> Void) {
        queue.async {
            if let last = log.last {
                completion(last.accessibilityLabel)
            } else {
                completion("No business audit events recorded.")
            }
        }
    }
}

// MARK: - Analytics/Audit Protocols

public protocol BusinessAnalyticsLogger {
    func log(event: String, info: [String: Any]?) async
}
public struct NullBusinessAnalyticsLogger: BusinessAnalyticsLogger {
    public init() {}
    public func log(event: String, info: [String: Any]?) async {}
}

public protocol BusinessTrustCenterDelegate {
    func permission(for action: String, context: [String: Any]?) async -> Bool
}
public struct NullBusinessTrustCenterDelegate: BusinessTrustCenterDelegate {
    public init() {}
    public func permission(for action: String, context: [String: Any]?) async -> Bool { true }
}

// MARK: - AuditLoggable Protocol

protocol AuditLoggable {
    func logChange(description: String) async
}

// MARK: - Audit Logger Actor (for legacy protocol conformance)
actor AuditLogger {
    func log(_ message: String) {
        // Legacy fallback (now handled by BusinessAuditLogger)
        print("[AuditLog] \(Date()): \(message)")
    }
}

// MARK: - Business (Enterprise Enhanced)

@Model
final class Business: Identifiable, ObservableObject, AuditLoggable {
    static var analyticsLogger: BusinessAnalyticsLogger = NullBusinessAnalyticsLogger()
    static var trustCenterDelegate: BusinessTrustCenterDelegate = NullBusinessTrustCenterDelegate()
    private let auditLogger = AuditLogger()

    @Attribute(.unique)
    var id: UUID

    @Published @Attribute(.indexed)
    var name: String

    @Published @Attribute(.indexed)
    var ownerName: String

    @Published var address: String?
    @Published var phone: String?
    @Published var email: String?
    @Published var website: String?
    @Published var logoImageData: Data?
    @Published var colorTheme: String?
    @Published @Relationship(deleteRule: .cascade)
    var staff: [StaffMember]
    @Published var defaultServiceDuration: Int
    @Published var currency: String
    @Published var timeZone: String
    @Published var locale: String
    @Published var dateCreated: Date
    @Published var lastModified: Date
    @Published var isActive: Bool
    @Published var featureFlags: [String: Bool]
    @Published var tspIntegrationEnabled: Bool

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

        Task {
            await Self.analyticsLogger.log(event: NSLocalizedString("BusinessCreated", comment: "Event when business is created"), info: [
                "id": id.uuidString,
                "name": name,
                "ownerName": ownerName,
                "createdAt": dateCreated
            ])
            BusinessAuditLogger.record(operation: "create", businessID: id, detail: "Business created: \(name)", user: ownerName)
        }
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

    var staffCount: Int { staff.count }

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

    var accessibilityLabel: String {
        var summary = "Business: \(name). Owner: \(ownerName)."
        summary += isActive ? " Active." : " Inactive."
        summary += " Staff count: \(staffCount)."
        summary += " Last modified: \(formattedLastModified)."
        return summary
    }
    var accessibilityLabelAsync: String { get async { accessibilityLabel } }

    // MARK: - Methods

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
    ) async {
        let permissionContext: [String: Any] = [
            "id": id.uuidString,
            "name": name as Any,
            "ownerName": ownerName as Any,
            "user": ownerName as Any,
            "auditTag": auditTag as Any
        ]
        let permitted = await Self.trustCenterDelegate.permission(for: "updateSettings", context: permissionContext)
        guard permitted else {
            await Self.analyticsLogger.log(event: NSLocalizedString("UpdateSettingsDenied", comment: "Event when updateSettings is denied"), info: permissionContext)
            BusinessAuditLogger.record(operation: "settingsDenied", businessID: id, detail: "Update denied", user: ownerName, context: auditTag)
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
        let changed = "Business settings updated"
        await logChange(description: changed)
        BusinessAuditLogger.record(operation: "updateSettings", businessID: id, detail: changed, user: ownerName, context: auditTag)
        await Self.analyticsLogger.log(event: NSLocalizedString("SettingsUpdated", comment: "Event when settings updated"), info: [
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

    func addStaff(_ staffMember: StaffMember, by user: String?, auditTag: String? = nil) async {
        let permissionContext: [String: Any] = [
            "businessID": id.uuidString,
            "staffName": staffMember.name,
            "user": user as Any,
            "auditTag": auditTag as Any
        ]
        let permitted = await Self.trustCenterDelegate.permission(for: "addStaff", context: permissionContext)
        guard permitted else {
            await Self.analyticsLogger.log(event: NSLocalizedString("AddStaffDenied", comment: "Event when addStaff is denied"), info: permissionContext)
            BusinessAuditLogger.record(operation: "addStaffDenied", businessID: id, detail: "Add staff denied: \(staffMember.name)", user: user, context: auditTag)
            return
        }
        staff.append(staffMember)
        lastModified = Date()
        let desc = "Added staff: \(staffMember.name)"
        await logChange(description: desc)
        BusinessAuditLogger.record(operation: "addStaff", businessID: id, detail: desc, user: user, context: auditTag)
        await Self.analyticsLogger.log(event: NSLocalizedString("StaffAdded", comment: "Event when staff added"), info: [
            "businessID": id.uuidString,
            "staffName": staffMember.name,
            "user": user as Any,
            "auditTag": auditTag as Any
        ])
    }

    func removeStaff(_ staffMember: StaffMember, by user: String?, auditTag: String? = nil) async {
        let permissionContext: [String: Any] = [
            "businessID": id.uuidString,
            "staffName": staffMember.name,
            "user": user as Any,
            "auditTag": auditTag as Any
        ]
        let permitted = await Self.trustCenterDelegate.permission(for: "removeStaff", context: permissionContext)
        guard permitted else {
            await Self.analyticsLogger.log(event: NSLocalizedString("RemoveStaffDenied", comment: "Event when removeStaff is denied"), info: permissionContext)
            BusinessAuditLogger.record(operation: "removeStaffDenied", businessID: id, detail: "Remove staff denied: \(staffMember.name)", user: user, context: auditTag)
            return
        }
        staff.removeAll { $0.id == staffMember.id }
        lastModified = Date()
        let desc = "Removed staff: \(staffMember.name)"
        await logChange(description: desc)
        BusinessAuditLogger.record(operation: "removeStaff", businessID: id, detail: desc, user: user, context: auditTag)
        await Self.analyticsLogger.log(event: NSLocalizedString("StaffRemoved", comment: "Event when staff removed"), info: [
            "businessID": id.uuidString,
            "staffName": staffMember.name,
            "user": user as Any,
            "auditTag": auditTag as Any
        ])
    }

    // MARK: - AuditLoggable
    func logChange(description: String) async {
        await auditLogger.log(description)
        BusinessAuditLogger.record(operation: "logChange", businessID: id, detail: description, user: ownerName)
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

// MARK: - Audit/Admin Accessors

public enum BusinessAuditAdmin {
    public static func lastSummary(completion: @escaping (String) -> Void) {
        BusinessAuditLogger.lastSummary(completion: completion)
    }
    public static func lastJSON(completion: @escaping (String?) -> Void) {
        BusinessAuditLogger.exportLastJSON(completion: completion)
    }
    public static func recentEvents(limit: Int = 5, completion: @escaping ([String]) -> Void) {
        BusinessAuditLogger.recentEvents(limit: limit, completion: completion)
    }
    public static func clearAuditLog() {
        BusinessAuditLogger.clearLog()
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

        @State private var userName: String = "Jane Doe"
        @State private var auditTag: String = "previewUpdate"
        @State private var lastAuditSummary: String = ""
        @State private var lastAuditJSON: String = ""
        @State private var auditEvents: [String] = []

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

                Button("Add Staff Member") {
                    Task {
                        let newStaff = StaffMember(name: "New Stylist", role: "Stylist")
                        await business.addStaff(newStaff, by: userName, auditTag: auditTag)
                        await refreshAudit()
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("Update Business Name") {
                    Task {
                        await business.updateSettings(name: "Furfolio Studio Updated", auditTag: auditTag)
                        await refreshAudit()
                    }
                }
                .buttonStyle(.bordered)

                Button("Remove First Staff Member") {
                    Task {
                        if let firstStaff = business.staff.first {
                            await business.removeStaff(firstStaff, by: userName, auditTag: auditTag)
                            await refreshAudit()
                        }
                    }
                }
                .buttonStyle(.bordered)
                .disabled(business.staff.isEmpty)

                Button("Show Last Audit Event") {
                    BusinessAuditAdmin.lastSummary { summary in
                        lastAuditSummary = summary
                    }
                    BusinessAuditAdmin.lastJSON { json in
                        lastAuditJSON = json ?? "No JSON"
                    }
                }
                .padding(.top)
                Text("Last Audit Summary: \(lastAuditSummary)")
                    .font(.caption)
                ScrollView(.horizontal) {
                    Text(lastAuditJSON)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxHeight: 100)
                }

                Button("Show Recent Audit Events") {
                    BusinessAuditAdmin.recentEvents(limit: 10) { events in
                        auditEvents = events
                    }
                }
                .padding(.top)
                List(auditEvents, id: \.self) { event in
                    Text(event)
                }

                Button("Clear Audit Log") {
                    BusinessAuditAdmin.clearAuditLog()
                    auditEvents = []
                    lastAuditSummary = ""
                    lastAuditJSON = ""
                }
                .foregroundColor(.red)
            }
            .padding()
            .onAppear { Task { await refreshAudit() } }
        }

        func refreshAudit() async {
            BusinessAuditAdmin.lastSummary { lastAuditSummary = $0 }
            BusinessAuditAdmin.lastJSON { lastAuditJSON = $0 ?? "" }
            BusinessAuditAdmin.recentEvents(limit: 10) { auditEvents = $0 }
        }
    }
}
#endif

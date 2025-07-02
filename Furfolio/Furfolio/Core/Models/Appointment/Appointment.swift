//
//  Appointment.swift
//  Furfolio
//
//  Enterprise Enhanced: analytics/audit–ready, Trust Center–capable, preview/test–injectable.
//  Updated: Trust/Audit context compliance—role/staffID/context for all analytics/logs.
//
import Foundation
import SwiftData
import SwiftUI

// MARK: - Audit/Analytics Context

public struct AppointmentAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "Appointment"
}

// MARK: - Audit/Analytics Protocols

public protocol AppointmentAnalyticsLogger {
    var testMode: Bool { get }
    func log(event: String, info: [String: Any]?, context: AppointmentAuditContext.Type) async
}
public struct NullAppointmentAnalyticsLogger: AppointmentAnalyticsLogger {
    public let testMode: Bool = false
    public init() {}
    public func log(event: String, info: [String: Any]?, context: AppointmentAuditContext.Type) async {}
}

public protocol AppointmentTrustCenterDelegate {
    func permission(for action: String, context: [String: Any]?, auditContext: AppointmentAuditContext.Type) async -> Bool
}
public struct NullAppointmentTrustCenterDelegate: AppointmentTrustCenterDelegate {
    public init() {}
    public func permission(for action: String, context: [String: Any]?, auditContext: AppointmentAuditContext.Type) async -> Bool { true }
}

// MARK: - Audit Log Actor

actor AuditLogActor {
    private(set) var auditLog: [AuditEntry]
    init(initialLog: [AuditEntry] = []) { self.auditLog = initialLog }
    func append(_ entry: AuditEntry) { auditLog.append(entry) }
    func getAll() -> [AuditEntry] { auditLog }
}

// MARK: - Appointment Model

@Model
final class Appointment: Identifiable, ObservableObject {
    @Attribute(.unique)
    var id: UUID = UUID()
    var date: Date
    var durationMinutes: Int
    var serviceType: ServiceType
    var notes: String?
    var status: AppointmentStatus
    var tags: [String]
    @Relationship(deleteRule: .nullify, inverse: \DogOwner.appointments)
    var owner: DogOwner?
    @Relationship(deleteRule: .nullify, inverse: \Dog.appointments)
    var dog: Dog?
    @Relationship(deleteRule: .cascade)
    var behaviorLog: BehaviorLog?
    var lastEdited: Date
    var createdBy: String?
    var lastModifiedBy: String?
    var createdAt: Date
    private let auditLogActor: AuditLogActor

    static var analyticsLogger: AppointmentAnalyticsLogger = NullAppointmentAnalyticsLogger()
    static var trustCenterDelegate: AppointmentTrustCenterDelegate = NullAppointmentTrustCenterDelegate()

    var endDate: Date {
        Calendar.current.date(byAdding: .minute, value: durationMinutes, to: date) ?? date
    }
    var isPast: Bool {
        let past = endDate < Date()
        UIAccessibility.post(notification: .announcement, argument: NSLocalizedString("Appointment is in the past", comment: "Accessibility announcement for past appointment"))
        return past
    }
    var isUpcoming: Bool {
        let upcoming = date > Date()
        UIAccessibility.post(notification: .announcement, argument: NSLocalizedString("Appointment is upcoming", comment: "Accessibility announcement for upcoming appointment"))
        return upcoming
    }
    var isActive: Bool {
        status.isActive
    }
    var locationCoordinate: Coordinate? {
        owner?.address?.coordinate
    }

    // MARK: - Initializer

    init(
        id: UUID = UUID(),
        date: Date,
        durationMinutes: Int = 60,
        serviceType: ServiceType,
        owner: DogOwner? = nil,
        dog: Dog? = nil,
        notes: String? = nil,
        status: AppointmentStatus = .scheduled,
        tags: [String] = [],
        behaviorLog: BehaviorLog? = nil,
        lastEdited: Date = Date(),
        createdBy: String? = nil,
        lastModifiedBy: String? = nil,
        createdAt: Date = Date(),
        auditLog: [AuditEntry] = []
    ) {
        self.id = id
        self.date = date
        self.durationMinutes = durationMinutes
        self.serviceType = serviceType
        self.owner = owner
        self.dog = dog
        self.notes = notes
        self.status = status
        self.tags = tags
        self.behaviorLog = behaviorLog
        self.lastEdited = lastEdited
        self.createdBy = createdBy
        self.lastModifiedBy = lastModifiedBy
        self.createdAt = createdAt
        self.auditLogActor = AuditLogActor(initialLog: auditLog)
    }

    // MARK: - Methods (With Trust Center Context)

    func addAudit(action: AuditAction, user: String?, context: [String: Any]? = nil, auditTag: String? = nil) async throws {
        let permissionGranted = await Self.trustCenterDelegate.permission(
            for: "addAudit",
            context: [
                "action": action.rawValue,
                "user": user as Any,
                "auditTag": auditTag as Any
            ],
            auditContext: AppointmentAuditContext.self
        )
        guard permissionGranted else {
            await Self.analyticsLogger.log(event: "addAudit_denied", info: [
                "action": action.rawValue,
                "user": user as Any,
                "auditTag": auditTag as Any
            ], context: AppointmentAuditContext.self)
            throw AppointmentError.permissionDenied(action: "addAudit")
        }
        let entry = AuditEntry(
            date: Date(),
            action: action,
            user: user,
            role: AppointmentAuditContext.role,
            staffID: AppointmentAuditContext.staffID,
            context: AppointmentAuditContext.context,
            escalate: action == .deleted
        )
        await auditLogActor.append(entry)
        lastEdited = entry.date
        lastModifiedBy = user
        do {
            await Self.analyticsLogger.log(event: "addAudit", info: [
                "action": NSLocalizedString(action.rawValue, comment: "Audit action"),
                "user": user as Any,
                "timestamp": entry.date,
                "auditTag": auditTag as Any,
                "role": AppointmentAuditContext.role as Any,
                "staffID": AppointmentAuditContext.staffID as Any,
                "context": AppointmentAuditContext.context as Any,
                "escalate": entry.escalate
            ], context: AppointmentAuditContext.self)
        } catch {
            throw AppointmentError.loggingFailed(error)
        }
    }

    func updateStatus(_ newStatus: AppointmentStatus, user: String?, auditTag: String? = nil) async throws {
        let permissionGranted = await Self.trustCenterDelegate.permission(
            for: "updateStatus",
            context: [
                "from": status.rawValue,
                "to": newStatus.rawValue,
                "user": user as Any,
                "auditTag": auditTag as Any
            ],
            auditContext: AppointmentAuditContext.self
        )
        guard permissionGranted else {
            await Self.analyticsLogger.log(event: "updateStatus_denied", info: [
                "from": status.rawValue,
                "to": newStatus.rawValue,
                "user": user as Any,
                "auditTag": auditTag as Any
            ], context: AppointmentAuditContext.self)
            throw AppointmentError.permissionDenied(action: "updateStatus")
        }
        let oldStatus = status
        status = newStatus
        try await addAudit(action: .statusChanged, user: user, context: [
            "from": oldStatus.rawValue,
            "to": newStatus.rawValue
        ], auditTag: auditTag)
        do {
            await Self.analyticsLogger.log(event: "updateStatus", info: [
                "from": NSLocalizedString(oldStatus.rawValue, comment: "Old appointment status"),
                "to": NSLocalizedString(newStatus.rawValue, comment: "New appointment status"),
                "user": user as Any,
                "auditTag": auditTag as Any,
                "role": AppointmentAuditContext.role as Any,
                "staffID": AppointmentAuditContext.staffID as Any,
                "context": AppointmentAuditContext.context as Any
            ], context: AppointmentAuditContext.self)
        } catch {
            throw AppointmentError.loggingFailed(error)
        }
    }

    func addNote(_ note: String, user: String?, auditTag: String? = nil) async throws {
        let permissionGranted = await Self.trustCenterDelegate.permission(
            for: "addNote",
            context: [
                "user": user as Any,
                "auditTag": auditTag as Any
            ],
            auditContext: AppointmentAuditContext.self
        )
        guard permissionGranted else {
            await Self.analyticsLogger.log(event: "addNote_denied", info: [
                "user": user as Any,
                "auditTag": auditTag as Any
            ], context: AppointmentAuditContext.self)
            throw AppointmentError.permissionDenied(action: "addNote")
        }
        notes = (notes?.isEmpty ?? true) ? note : "\(notes ?? "")\n\(note)"
        try await addAudit(action: .noteAdded, user: user, auditTag: auditTag)
        do {
            await Self.analyticsLogger.log(event: "addNote", info: [
                "user": user as Any,
                "auditTag": auditTag as Any,
                "role": AppointmentAuditContext.role as Any,
                "staffID": AppointmentAuditContext.staffID as Any,
                "context": AppointmentAuditContext.context as Any
            ], context: AppointmentAuditContext.self)
        } catch {
            throw AppointmentError.loggingFailed(error)
        }
    }

    func getAuditLog() async -> [AuditEntry] {
        await auditLogActor.getAll()
    }
}

// MARK: - Errors, Enums, Types (with context fields added where relevant)

enum AppointmentError: Error, LocalizedError {
    case permissionDenied(action: String)
    case loggingFailed(Error)
    var errorDescription: String? {
        switch self {
        case .permissionDenied(let action):
            return NSLocalizedString("Permission denied for action: \(action)", comment: "Permission denied error")
        case .loggingFailed(let error):
            return NSLocalizedString("Logging failed with error: \(error.localizedDescription)", comment: "Logging failed error")
        }
    }
}

enum ServiceType: String, Codable, CaseIterable, Identifiable {
    case fullGroom, basicBath, nailTrim, custom
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .fullGroom: return NSLocalizedString("Full Groom", comment: "Service type full groom")
        case .basicBath: return NSLocalizedString("Basic Bath", comment: "Service type basic bath")
        case .nailTrim: return NSLocalizedString("Nail Trim", comment: "Service type nail trim")
        case .custom: return NSLocalizedString("Custom", comment: "Service type custom")
        }
    }
    var durationEstimate: Int {
        switch self {
        case .fullGroom: return 90
        case .basicBath: return 45
        case .nailTrim: return 20
        case .custom: return 60
        }
    }
}

enum AppointmentStatus: String, Codable, CaseIterable, Identifiable {
    case scheduled, completed, cancelled, noShow, inProgress
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .scheduled: return NSLocalizedString("Scheduled", comment: "Appointment status scheduled")
        case .completed: return NSLocalizedString("Completed", comment: "Appointment status completed")
        case .cancelled: return NSLocalizedString("Cancelled", comment: "Appointment status cancelled")
        case .noShow: return NSLocalizedString("No Show", comment: "Appointment status no show")
        case .inProgress: return NSLocalizedString("In Progress", comment: "Appointment status in progress")
        }
    }
    var isActive: Bool {
        self == .scheduled || self == .inProgress
    }
}

// MARK: - Audit Trail Types

struct AuditEntry: Codable, Identifiable {
    var id: UUID = UUID()
    var date: Date
    var action: AuditAction
    var user: String?
    var role: String?
    var staffID: String?
    var context: String?
    var escalate: Bool = false
}

enum AuditAction: String, Codable, CaseIterable, Identifiable {
    case created, modified, deleted, statusChanged, noteAdded
    var id: String { rawValue }
    var description: String {
        switch self {
        case .created: return NSLocalizedString("Created appointment", comment: "Audit action created")
        case .modified: return NSLocalizedString("Edited appointment", comment: "Audit action modified")
        case .deleted: return NSLocalizedString("Deleted appointment", comment: "Audit action deleted")
        case .statusChanged: return NSLocalizedString("Changed status", comment: "Audit action status changed")
        case .noteAdded: return NSLocalizedString("Added note", comment: "Audit action note added")
        }
    }
}

// MARK: - Coordinate

struct Coordinate: Codable, Equatable {
    let latitude: Double
    let longitude: Double
}

// MARK: - SwiftUI PreviewProvider (Diagnostics: full context and staff audit shown)

#if DEBUG
import Combine

@available(iOS 15.0, *)
struct Appointment_Previews: PreviewProvider {
    class MockAnalyticsLogger: AppointmentAnalyticsLogger {
        var testMode: Bool = true
        @Published var loggedEvents: [(String, [String: Any]?)] = []
        func log(event: String, info: [String: Any]?, context: AppointmentAuditContext.Type) async {
            DispatchQueue.main.async { self.loggedEvents.append((event, info)) }
        }
    }
    class MockTrustCenterDelegate: AppointmentTrustCenterDelegate {
        var allowAllPermissions: Bool = true
        func permission(for action: String, context: [String: Any]?, auditContext: AppointmentAuditContext.Type) async -> Bool {
            try? await Task.sleep(nanoseconds: 100_000_000)
            return allowAllPermissions
        }
    }
    static var previews: some View {
        AppointmentPreviewView()
            .environmentObject(MockAnalyticsLogger())
            .environmentObject(MockTrustCenterDelegate())
    }
    struct AppointmentPreviewView: View {
        @StateObject private var appointment = Appointment(
            date: Date().addingTimeInterval(3600),
            serviceType: .fullGroom,
            notes: NSLocalizedString("Initial note", comment: "Preview initial note")
        )
        @EnvironmentObject var analyticsLogger: MockAnalyticsLogger
        @EnvironmentObject var trustCenterDelegate: MockTrustCenterDelegate

        @State private var statusMessage: String = ""
        @State private var errorMessage: String = ""

        var body: some View {
            VStack(spacing: 16) {
                Text("Appointment Preview").font(.title).accessibilityAddTraits(.isHeader)
                Text("Status: \(appointment.status.displayName)")
                Text("Notes: \(appointment.notes ?? NSLocalizedString("No notes", comment: "No notes placeholder"))")
                Text(statusMessage).foregroundColor(.green)
                if !errorMessage.isEmpty {
                    Text(errorMessage).foregroundColor(.red)
                }
                Button(NSLocalizedString("Add Note", comment: "Button to add note")) {
                    Task {
                        do {
                            try await appointment.addNote(NSLocalizedString("Preview added note", comment: "Preview added note text"), user: "PreviewUser", auditTag: "preview")
                            statusMessage = NSLocalizedString("Note added successfully", comment: "Success message for adding note")
                            errorMessage = ""
                        } catch {
                            errorMessage = error.localizedDescription
                            statusMessage = ""
                        }
                    }
                }
                Button(NSLocalizedString("Update Status to Completed", comment: "Button to update status")) {
                    Task {
                        do {
                            try await appointment.updateStatus(.completed, user: "PreviewUser", auditTag: "preview")
                            statusMessage = NSLocalizedString("Status updated successfully", comment: "Success message for status update")
                            errorMessage = ""
                        } catch {
                            errorMessage = error.localizedDescription
                            statusMessage = ""
                        }
                    }
                }
                List {
                    Section(header: Text(NSLocalizedString("Audit Log", comment: "Audit log section header"))) {
                        ForEach(Task { await appointment.getAuditLog() }.value ?? []) { entry in
                            VStack(alignment: .leading) {
                                Text(entry.action.description).fontWeight(.bold)
                                Text(entry.date, style: .date).font(.caption)
                                if let user = entry.user {
                                    Text(String(format: NSLocalizedString("By user: %@", comment: "Audit entry user label"), user)).font(.caption2)
                                }
                                if let role = entry.role {
                                    Text("Role: \(role)").font(.caption2)
                                }
                                if let staffID = entry.staffID {
                                    Text("StaffID: \(staffID)").font(.caption2)
                                }
                                if let context = entry.context {
                                    Text("Context: \(context)").font(.caption2)
                                }
                                if entry.escalate {
                                    Text("Escalate: YES").font(.caption2).foregroundColor(.red)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
            .onAppear {
                Appointment.analyticsLogger = analyticsLogger
                Appointment.trustCenterDelegate = trustCenterDelegate
            }
        }
    }
}
#endif

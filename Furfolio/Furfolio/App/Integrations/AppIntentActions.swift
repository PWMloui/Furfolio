//
//  AppIntentActions.swift
//  Furfolio
//
//  Modular, auditable, analytics-ready, role-aware AppIntents for all shortcut/discovery integrations.
//  Dependency injection and permission checks ready for future staff, admin, cloud, and test expansion.
//  Enhanced 2025: Multi-role, trust center, protocol analytics/audit, strict localization.
//

import Foundation
import AppIntents
import SwiftData

// MARK: - Dependency Injection Container (Business-Ready)
class DependencyContainer {
    static let shared = DependencyContainer()
    var modelContext: ModelContext? = nil // Inject at app startup
    var trustCenter: TrustCenterPermissionManager = TrustCenterPermissionManager()
    var noteManager: NoteManager = NoteManager()
    var analyticsService: AnalyticsServiceProtocol = AnalyticsService()
    var auditLogger: AuditLoggerProtocol = AuditLogger()
    var appRouter: AppRouter = AppRouter()
    var accessControl: AccessControl? = nil // Optional: for role/permission injection
    var currentRole: FurfolioRole = .unknown
}

// MARK: - Protocols for Analytics/Audit

protocol AnalyticsServiceProtocol {
    func track(event: String, properties: [String: String]) async
}
protocol AuditLoggerProtocol {
    func log(event: String, details: String) async
}

// MARK: - Trust Center Permission Check
class TrustCenterPermissionManager {
    func isActionAllowed(_ action: String, role: FurfolioRole = .unknown) -> Bool {
        // Example: call AccessControl here for role check if needed
        // return DependencyContainer.shared.accessControl?.can(action, forRole: role) ?? true
        return true
    }
}

// MARK: - Service/Manager Stubs
class NoteManager {
    func addNote(content: String, ownerName: String?) async throws {}
}
class AnalyticsService: AnalyticsServiceProtocol {
    func track(event: String, properties: [String: String]) async {}
}
class AuditLogger: AuditLoggerProtocol {
    func log(event: String, details: String) async {}
}
class AppRouter {
    func openOwnerProfile(ownerName: String) async {}
}

// MARK: - Add Appointment Intent

struct AddAppointmentIntent: AppIntent {
    static var title: LocalizedStringResource = NSLocalizedString("Add New Appointment", value: "Add New Appointment", comment: "Shortcut title for adding a new appointment")
    static var description = IntentDescription(NSLocalizedString("Quickly schedule a new grooming appointment.", value: "Quickly schedule a new grooming appointment.", comment: "Shortcut description for adding appointment"))

    @Parameter(title: NSLocalizedString("Dog Name", value: "Dog Name", comment: "Parameter title for dog name")) var dogName: String
    @Parameter(title: NSLocalizedString("Owner Name", value: "Owner Name", comment: "Parameter title for owner name")) var ownerName: String
    @Parameter(title: NSLocalizedString("Date", value: "Date", comment: "Parameter title for appointment date")) var date: Date
    @Parameter(title: NSLocalizedString("Service Type", value: "Service Type", comment: "Parameter title for service type"), default: "Full Groom") var serviceType: String
    @Parameter(title: NSLocalizedString("Test Mode", value: "Test Mode", comment: "Parameter title for test mode")) var testMode: Bool = false

    func perform() async throws -> some ProvidesDialog {
        let container = DependencyContainer.shared
        let actionKey = "add_appointment"
        let role = container.currentRole
        guard container.trustCenter.isActionAllowed(actionKey, role: role) else {
            await container.auditLogger.log(event: "appointment_create_denied", details: "Trust Center denied add appointment for \(role.rawValue)")
            let msg = NSLocalizedString("You do not have permission to add appointments. Please contact your administrator if you believe this is an error.", value: "You do not have permission to add appointments. Please contact your administrator if you believe this is an error.", comment: "Error dialog when permission denied for adding appointment")
            await container.analyticsService.track(event: "appointment_create_denied", properties: ["dog": dogName, "owner": ownerName, "role": role.rawValue])
            return .result(dialog: LocalizedStringResource(msg))
        }
        if testMode {
            await container.auditLogger.log(event: "appointment_create_test", details: "Test mode: appointment for \(dogName), \(serviceType) on \(date)")
            await container.analyticsService.track(event: "appointment_created_test", properties: ["dog": dogName, "owner": ownerName, "service": serviceType])
            let dateString = DateUtils.shortDate(date)
            let msgFormat = NSLocalizedString("Simulated: Added appointment for %@ (%@) on %@.", value: "Simulated: Added appointment for %@ (%@) on %@.", comment: "Dialog when simulating appointment add in test mode")
            let msg = String(format: msgFormat, dogName, serviceType, dateString)
            return .result(dialog: LocalizedStringResource(msg))
        }
        guard let context = container.modelContext else {
            await container.auditLogger.log(event: "appointment_create_failure", details: "ModelContext unavailable")
            let msg = NSLocalizedString("Data store is currently unavailable. Please try again later.", value: "Data store is currently unavailable. Please try again later.", comment: "Error dialog when data store is unavailable")
            return .result(dialog: LocalizedStringResource(msg))
        }
        guard let dog = context.fetch(Dog.self).first(where: { $0.name == dogName }),
              let owner = context.fetch(DogOwner.self).first(where: { $0.ownerName == ownerName }) else {
            await container.auditLogger.log(event: "appointment_create_failure", details: "Dog or owner not found")
            let msg = NSLocalizedString("Could not find the specified dog or owner. Please check the names and try again.", value: "Could not find the specified dog or owner. Please check the names and try again.", comment: "Error dialog when dog or owner not found")
            return .result(dialog: LocalizedStringResource(msg))
        }
        let service = ServiceType.fromString(serviceType)
        let appointment = Appointment(date: date, dog: dog, owner: owner, serviceType: service)
        context.insert(appointment)
        do {
            try context.save()
            await container.analyticsService.track(event: "appointment_created", properties: ["dog": dogName, "owner": ownerName, "service": serviceType])
            await container.auditLogger.log(event: "appointment_create_success", details: "Appointment for \(dogName), \(serviceType) on \(date)")
            let dateString = DateUtils.shortDate(date)
            let msgFormat = NSLocalizedString("Added appointment for %@ (%@) on %@.", value: "Added appointment for %@ (%@) on %@.", comment: "Success dialog when appointment is added")
            let msg = String(format: msgFormat, dogName, serviceType, dateString)
            return .result(dialog: LocalizedStringResource(msg))
        } catch {
            await container.auditLogger.log(event: "appointment_create_failure", details: "Save error: \(error.localizedDescription)")
            let msg = NSLocalizedString("Failed to save the appointment. Please try again. Details: %@", value: "Failed to save the appointment. Please try again. Details: %@", comment: "Error dialog when saving appointment fails (with error details)")
            let errorMsg = String(format: msg, error.localizedDescription)
            return .result(dialog: LocalizedStringResource(errorMsg))
        }
    }
}

// MARK: - Add Quick Note Intent

struct AddQuickNoteIntent: AppIntent {
    static var title: LocalizedStringResource = NSLocalizedString("Add Quick Note", value: "Add Quick Note", comment: "Shortcut title for adding a quick note")
    static var description = IntentDescription(NSLocalizedString("Quickly add a sticky note for an owner.", value: "Quickly add a sticky note for an owner.", comment: "Shortcut description for adding a quick note"))

    @Parameter(title: NSLocalizedString("Note Content", value: "Note Content", comment: "Parameter title for note content")) var content: String
    @Parameter(title: NSLocalizedString("Owner Name", value: "Owner Name", comment: "Parameter title for owner name"), default: "") var ownerName: String
    @Parameter(title: NSLocalizedString("Test Mode", value: "Test Mode", comment: "Parameter title for test mode")) var testMode: Bool = false

    func perform() async throws -> some ProvidesDialog {
        let container = DependencyContainer.shared
        let actionKey = "add_quick_note"
        let role = container.currentRole
        guard container.trustCenter.isActionAllowed(actionKey, role: role) else {
            await container.auditLogger.log(event: "quick_note_denied", details: "Trust Center denied add note for \(role.rawValue)")
            let msg = NSLocalizedString("You do not have permission to add notes. Please contact your administrator if you believe this is an error.", value: "You do not have permission to add notes. Please contact your administrator if you believe this is an error.", comment: "Error dialog when permission denied for adding note")
            await container.analyticsService.track(event: "quick_note_denied", properties: ["owner": ownerName, "role": role.rawValue])
            return .result(dialog: LocalizedStringResource(msg))
        }
        let target = ownerName.isEmpty
            ? NSLocalizedString("business", value: "business", comment: "Default target when owner name is empty")
            : ownerName
        if testMode {
            await container.auditLogger.log(event: "quick_note_test", details: "Test mode: note for \(target): \(content)")
            await container.analyticsService.track(event: "quick_note_added_test", properties: ["owner": target, "role": role.rawValue])
            let msgFormat = NSLocalizedString("Simulated: Note added for %@.", value: "Simulated: Note added for %@.", comment: "Dialog when simulating note add in test mode")
            let msg = String(format: msgFormat, target)
            return .result(dialog: LocalizedStringResource(msg))
        }
        do {
            try await container.noteManager.addNote(content: content, ownerName: ownerName.isEmpty ? nil : ownerName)
            await container.analyticsService.track(event: "quick_note_added", properties: ["owner": target, "role": role.rawValue])
            await container.auditLogger.log(event: "quick_note_added", details: "Note for \(target): \(content)")
            let msgFormat = NSLocalizedString("Note added for %@.", value: "Note added for %@.", comment: "Success dialog when note is added for owner or business")
            let msg = String(format: msgFormat, target)
            return .result(dialog: LocalizedStringResource(msg))
        } catch {
            await container.auditLogger.log(event: "quick_note_failure", details: "Save error: \(error.localizedDescription)")
            let msg = NSLocalizedString("Failed to save the note. Please try again. Details: %@", value: "Failed to save the note. Please try again. Details: %@", comment: "Error dialog when saving note fails (with error details)")
            let errorMsg = String(format: msg, error.localizedDescription)
            return .result(dialog: LocalizedStringResource(errorMsg))
        }
    }
}

// MARK: - Open Owner Profile Intent

struct OpenOwnerProfileIntent: AppIntent {
    static var title: LocalizedStringResource = NSLocalizedString("Open Owner Profile", value: "Open Owner Profile", comment: "Shortcut title for opening owner profile")
    static var description = IntentDescription(NSLocalizedString("Jump directly to a dog owner's profile.", value: "Jump directly to a dog owner's profile.", comment: "Shortcut description for opening owner profile"))

    @Parameter(title: NSLocalizedString("Owner Name", value: "Owner Name", comment: "Parameter title for owner name")) var ownerName: String
    @Parameter(title: NSLocalizedString("Test Mode", value: "Test Mode", comment: "Parameter title for test mode")) var testMode: Bool = false

    func perform() async throws -> some ProvidesDialog {
        let container = DependencyContainer.shared
        let actionKey = "open_owner_profile"
        let role = container.currentRole
        guard container.trustCenter.isActionAllowed(actionKey, role: role) else {
            await container.auditLogger.log(event: "navigate_owner_profile_denied", details: "Trust Center denied navigation for \(role.rawValue)")
            let msg = NSLocalizedString("You do not have permission to open owner profiles. Please contact your administrator if you believe this is an error.", value: "You do not have permission to open owner profiles. Please contact your administrator if you believe this is an error.", comment: "Error dialog when permission denied for navigation")
            await container.analyticsService.track(event: "navigate_owner_profile_denied", properties: ["owner": ownerName, "role": role.rawValue])
            return .result(dialog: LocalizedStringResource(msg))
        }
        if testMode {
            await container.auditLogger.log(event: "navigate_owner_profile_test", details: "Test mode: navigation for \(ownerName)")
            await container.analyticsService.track(event: "navigate_owner_profile_test", properties: ["owner": ownerName, "role": role.rawValue])
            let msgFormat = NSLocalizedString("Simulated: Opening profile for %@.", value: "Simulated: Opening profile for %@.", comment: "Dialog when simulating owner profile navigation in test mode")
            let msg = String(format: msgFormat, ownerName)
            return .result(dialog: LocalizedStringResource(msg))
        }
        await container.analyticsService.track(event: "navigate_owner_profile", properties: ["owner": ownerName, "role": role.rawValue])
        await container.auditLogger.log(event: "navigate_owner_profile", details: "Profile for \(ownerName)")
        await container.appRouter.openOwnerProfile(ownerName: ownerName)
        let msgFormat = NSLocalizedString("Opening profile for %@.", value: "Opening profile for %@.", comment: "Dialog when opening owner profile")
        let msg = String(format: msgFormat, ownerName)
        return .result(dialog: LocalizedStringResource(msg))
    }
}

// MARK: - Canonical App Shortcuts Registration

struct FurfolioAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        [
            AppShortcut(
                intent: AddAppointmentIntent(),
                phrases: [
                    NSLocalizedString("Add grooming appointment", value: "Add grooming appointment", comment: "Shortcut phrase for adding appointment"),
                    NSLocalizedString("Schedule dog appointment in Furfolio", value: "Schedule dog appointment in Furfolio", comment: "Shortcut phrase for scheduling appointment"),
                    NSLocalizedString("New appointment for *", value: "New appointment for *", comment: "Shortcut phrase with wildcard for appointment")
                ],
                shortTitle: NSLocalizedString("New Appointment", value: "New Appointment", comment: "Shortcut short title for new appointment"),
                systemImageName: "calendar.badge.plus",
                accessibilityLabel: NSLocalizedString("Add New Appointment", value: "Add New Appointment", comment: "VoiceOver label for new appointment shortcut"),
                accessibilityHint: NSLocalizedString("Adds a new grooming appointment for a selected dog and owner.", value: "Adds a new grooming appointment for a selected dog and owner.", comment: "VoiceOver hint for new appointment shortcut")
            ),
            AppShortcut(
                intent: AddQuickNoteIntent(),
                phrases: [
                    NSLocalizedString("Add note for owner", value: "Add note for owner", comment: "Shortcut phrase for adding note"),
                    NSLocalizedString("Quick note in Furfolio", value: "Quick note in Furfolio", comment: "Shortcut phrase for quick note"),
                    NSLocalizedString("Note for *", value: "Note for *", comment: "Shortcut phrase with wildcard for note")
                ],
                shortTitle: NSLocalizedString("Quick Note", value: "Quick Note", comment: "Shortcut short title for quick note"),
                systemImageName: "note.text.badge.plus",
                accessibilityLabel: NSLocalizedString("Add Quick Note", value: "Add Quick Note", comment: "VoiceOver label for quick note shortcut"),
                accessibilityHint: NSLocalizedString("Adds a sticky note for a dog owner or the business.", value: "Adds a sticky note for a dog owner or the business.", comment: "VoiceOver hint for quick note shortcut")
            ),
            AppShortcut(
                intent: OpenOwnerProfileIntent(),
                phrases: [
                    NSLocalizedString("Show profile for owner", value: "Show profile for owner", comment: "Shortcut phrase for showing owner profile"),
                    NSLocalizedString("Open dog owner profile in Furfolio", value: "Open dog owner profile in Furfolio", comment: "Shortcut phrase for opening owner profile"),
                    NSLocalizedString("Go to *'s profile", value: "Go to *'s profile", comment: "Shortcut phrase with wildcard for owner profile")
                ],
                shortTitle: NSLocalizedString("Open Profile", value: "Open Profile", comment: "Shortcut short title for open profile"),
                systemImageName: "person.crop.circle",
                accessibilityLabel: NSLocalizedString("Open Owner Profile", value: "Open Owner Profile", comment: "VoiceOver label for open owner profile shortcut"),
                accessibilityHint: NSLocalizedString("Opens the profile for a specific dog owner.", value: "Opens the profile for a specific dog owner.", comment: "VoiceOver hint for open owner profile shortcut")
            )
        ]
    }
}

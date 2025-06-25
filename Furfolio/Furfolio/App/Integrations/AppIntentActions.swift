//
//  AppIntentActions.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//  Enhanced: modular, auditable, analytics-ready, future-proof.
//

import Foundation
import AppIntents
import SwiftData

// MARK: - Developer Notes
/*
    - Add all new app-level AppIntents here for unified shortcut/discovery support.
    - All dialog/user-facing strings use NSLocalizedString for full localization.
    - All success/failure paths stub audit/analytics logging (ready for Trust Center, BI).
    - All DB/service dependencies must come from DependencyContainer for modularity and testability.
    - All context/model access is explicit and ready for multi-user or cloud use.
*/

// MARK: - Add Appointment Intent

struct AddAppointmentIntent: AppIntent {
    static var title: LocalizedStringResource = "Add New Appointment"
    static var description = IntentDescription("Quickly schedule a new grooming appointment.")

    @Parameter(title: "Dog Name") var dogName: String
    @Parameter(title: "Owner Name") var ownerName: String
    @Parameter(title: "Date") var date: Date
    @Parameter(title: "Service Type", default: "Full Groom") var serviceType: String

    func perform() async throws -> some ProvidesDialog {
        // Defensive: ensure context available
        guard let context = DependencyContainer.shared.modelContext else {
            auditLog(event: "appointment_create_failure", details: "ModelContext unavailable")
            let msg = NSLocalizedString("Data store is currently unavailable. Please try again later.", comment: "Error dialog when data store is unavailable")
            return .result(dialog: LocalizedStringResource(msg))
        }
        // Find dog and owner
        guard let dog = context.fetch(Dog.self).first(where: { $0.name == dogName }),
              let owner = context.fetch(DogOwner.self).first(where: { $0.ownerName == ownerName }) else {
            auditLog(event: "appointment_create_failure", details: "Dog or owner not found")
            let msg = NSLocalizedString("Could not find the specified dog or owner. Please check the names and try again.", comment: "Error dialog when dog or owner not found")
            return .result(dialog: LocalizedStringResource(msg))
        }
        // Build and insert appointment
        let service = ServiceType.fromString(serviceType)
        let appointment = Appointment(date: date, dog: dog, owner: owner, serviceType: service)
        context.insert(appointment)
        do {
            try context.save()
            analyticsTrack(event: "appointment_created", properties: ["dog": dogName, "owner": ownerName, "service": serviceType])
            auditLog(event: "appointment_create_success", details: "Appointment for \(dogName), \(serviceType) on \(date)")
            let dateString = DateUtils.shortDate(date)
            let msgFormat = NSLocalizedString("Added appointment for %@ (%@) on %@.", comment: "Success dialog when appointment is added")
            let msg = String(format: msgFormat, dogName, serviceType, dateString)
            return .result(dialog: LocalizedStringResource(msg))
        } catch {
            auditLog(event: "appointment_create_failure", details: "Save error: \(error.localizedDescription)")
            let msg = NSLocalizedString("Failed to save the appointment. Please try again.", comment: "Error dialog when saving appointment fails")
            return .result(dialog: LocalizedStringResource(msg))
        }
    }
}

// MARK: - Quick Note Intent

struct AddQuickNoteIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Quick Note"
    static var description = IntentDescription("Quickly add a sticky note for an owner.")

    @Parameter(title: "Note Content") var content: String
    @Parameter(title: "Owner Name", default: "") var ownerName: String

    func perform() async throws -> some ProvidesDialog {
        // TODO: Implement note persistence (NoteManager/DataStoreService via DependencyContainer)
        let target = ownerName.isEmpty ? NSLocalizedString("business", comment: "Default target when owner name is empty") : ownerName
        analyticsTrack(event: "quick_note_added", properties: ["owner": target])
        auditLog(event: "quick_note_added", details: "Note for \(target): \(content)")
        let msgFormat = NSLocalizedString("Note added for %@.", comment: "Success dialog when note is added for owner or business")
        let msg = String(format: msgFormat, target)
        return .result(dialog: LocalizedStringResource(msg))
    }
}

// MARK: - App Navigation Intent

struct OpenOwnerProfileIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Owner Profile"
    static var description = IntentDescription("Jump directly to a dog owner's profile.")

    @Parameter(title: "Owner Name") var ownerName: String

    func perform() async throws -> some ProvidesDialog {
        // TODO: Implement navigation/deep-link (AppState/Router from DependencyContainer)
        analyticsTrack(event: "navigate_owner_profile", properties: ["owner": ownerName])
        auditLog(event: "navigate_owner_profile", details: "Profile for \(ownerName)")
        let msgFormat = NSLocalizedString("Opening profile for %@.", comment: "Dialog when opening owner profile")
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
                    "Add grooming appointment",
                    "Schedule dog appointment in Furfolio",
                    "New appointment for *"
                ],
                shortTitle: "New Appointment",
                systemImageName: "calendar.badge.plus" // TODO: Use design token/constant for icon
            ),
            AppShortcut(
                intent: AddQuickNoteIntent(),
                phrases: [
                    "Add note for owner",
                    "Quick note in Furfolio",
                    "Note for *"
                ],
                shortTitle: "Quick Note",
                systemImageName: "note.text.badge.plus"
            ),
            AppShortcut(
                intent: OpenOwnerProfileIntent(),
                phrases: [
                    "Show profile for owner",
                    "Open dog owner profile in Furfolio",
                    "Go to *'s profile"
                ],
                shortTitle: "Open Profile",
                systemImageName: "person.crop.circle"
            )
        ]
    }
}

// MARK: - Audit/Analytics Stubs (Ready for Trust Center/BI)

// Replace with your audit/analytics engine(s) as you modularize
private func auditLog(event: String, details: String) {
    // TODO: Hook to real audit logger/Trust Center (with full context: user, timestamp, etc.)
    #if DEBUG
    print("AUDIT: [\(event)] \(details)")
    #endif
}
private func analyticsTrack(event: String, properties: [String: String]) {
    // TODO: Hook to AnalyticsService for BI.
    #if DEBUG
    print("ANALYTICS: \(event) \(properties)")
    #endif
}

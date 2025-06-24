//
//  AppIntentActions.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//  Updated for architectural unification, modularity, and service consistency.
//

import Foundation
import AppIntents
import SwiftData

// MARK: - Developer Notes
// This file contains AppIntent implementations for Furfolio.
// Extension points:
// - Add new intents for app actions here.
// - Implement audit logging, analytics tracking, and database operations via DependencyContainer.
// - Future-proof for cloud sync or multi-user by abstracting data context access.

// MARK: - Add Appointment Intent
// Intent to add a new grooming appointment for a dog.
// Extension point: Add detailed audit logs and analytics events for appointment creation and failures.

struct AddAppointmentIntent: AppIntent {
    static var title: LocalizedStringResource = "Add New Appointment"
    static var description = IntentDescription("Quickly schedule a new grooming appointment.")

    @Parameter(title: "Dog Name") var dogName: String
    @Parameter(title: "Owner Name") var ownerName: String
    @Parameter(title: "Date") var date: Date
    @Parameter(title: "Service Type", default: "Full Groom") var serviceType: String

    func perform() async throws -> some ProvidesDialog {
        // Access the shared model context safely.
        // TODO: For future multi-user or cloud sync, consider injecting context or using a user-specific container.
        guard let context = DependencyContainer.shared.modelContext else {
            // TODO: Audit log failure - data store unavailable.
            let message = NSLocalizedString("Data store is currently unavailable. Please try again later.", comment: "Error dialog when data store is unavailable")
            return .result(dialog: LocalizedStringResource(message))
        }
        // Fetch dog and owner entities safely.
        guard let dog = context.fetch(Dog.self).first(where: { $0.name == dogName }),
              let owner = context.fetch(DogOwner.self).first(where: { $0.ownerName == ownerName }) else {
            // TODO: Audit log failure - dog or owner not found.
            let message = NSLocalizedString("Could not find the specified dog or owner. Please check the names and try again.", comment: "Error dialog when dog or owner not found")
            return .result(dialog: LocalizedStringResource(message))
        }
        let service = ServiceType.fromString(serviceType)
        let appointment = Appointment(date: date, dog: dog, owner: owner, serviceType: service)
        context.insert(appointment)
        do {
            try context.save()
            // TODO: Analytics event - appointment successfully created.
            // TODO: Audit log success - appointment created.
            let dateString = DateUtils.shortDate(date)
            let messageFormat = NSLocalizedString("Added appointment for %@ (%@) on %@.", comment: "Success dialog when appointment is added: dog name, service type, date")
            let message = String(format: messageFormat, dogName, serviceType, dateString)
            return .result(dialog: LocalizedStringResource(message))
        } catch {
            // TODO: Audit log failure - error saving appointment.
            let message = NSLocalizedString("Failed to save the appointment. Please try again.", comment: "Error dialog when saving appointment fails")
            return .result(dialog: LocalizedStringResource(message))
        }
    }
}

// MARK: - Quick Note Intent
// Intent to add a quick sticky note for an owner.
// Extension point: Connect to NoteManager or DataStoreService for persistence and add audit/analytics.

struct AddQuickNoteIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Quick Note"
    static var description = IntentDescription("Quickly add a sticky note for an owner.")

    @Parameter(title: "Note Content") var content: String
    @Parameter(title: "Owner Name", default: "") var ownerName: String

    func perform() async throws -> some ProvidesDialog {
        // TODO: Implement persistence using DataStoreService or NoteManager from DependencyContainer.
        // TODO: Audit log note addition success/failure.
        let target = ownerName.isEmpty ? NSLocalizedString("business", comment: "Default target when owner name is empty") : ownerName
        let messageFormat = NSLocalizedString("Note added for %@.", comment: "Success dialog when note is added for owner or business")
        let message = String(format: messageFormat, target)
        return .result(dialog: LocalizedStringResource(message))
    }
}

// MARK: - App Navigation Intent
// Intent to open a dog's owner profile within the app.
// Extension point: Implement navigation or deep-linking via DependencyContainer or AppState.
// Add audit logs for navigation events.

struct OpenOwnerProfileIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Owner Profile"
    static var description = IntentDescription("Jump directly to a dog owner's profile.")

    @Parameter(title: "Owner Name") var ownerName: String

    func perform() async throws -> some ProvidesDialog {
        // TODO: Trigger app navigation or deep-link here.
        // TODO: Audit log navigation event.
        let messageFormat = NSLocalizedString("Opening profile for %@.", comment: "Dialog when opening owner profile")
        let message = String(format: messageFormat, ownerName)
        return .result(dialog: LocalizedStringResource(message))
    }
}

// MARK: - Canonical App Shortcuts Registration
// Provides app shortcuts for common actions.
// TODO: Replace systemImageName strings with design tokens or constants in the future.

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
                systemImageName: "calendar.badge.plus" // TODO: Use design token for calendar plus icon
            ),
            AppShortcut(
                intent: AddQuickNoteIntent(),
                phrases: [
                    "Add note for owner",
                    "Quick note in Furfolio",
                    "Note for *"
                ],
                shortTitle: "Quick Note",
                systemImageName: "note.text.badge.plus" // TODO: Use design token for note badge plus icon
            ),
            AppShortcut(
                intent: OpenOwnerProfileIntent(),
                phrases: [
                    "Show profile for owner",
                    "Open dog owner profile in Furfolio",
                    "Go to *'s profile"
                ],
                shortTitle: "Open Profile",
                systemImageName: "person.crop.circle" // TODO: Use design token for person crop circle icon
            )
        ]
    }
}

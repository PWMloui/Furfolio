//
//  AppIntentActions.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import Foundation
import AppIntents
import SwiftData

// MARK: - Add Appointment Intent

struct AddAppointmentIntent: AppIntent {
    static var title: LocalizedStringResource = "Add New Appointment"
    static var description = IntentDescription("Quickly schedule a new grooming appointment.")

    @Parameter(title: "Dog Name") var dogName: String
    @Parameter(title: "Owner Name") var ownerName: String
    @Parameter(title: "Date") var date: Date
    @Parameter(title: "Service Type", default: "Full Groom") var serviceType: String

    func perform() async throws -> some ProvidesDialog {
        // TODO: Replace mock logic with actual DataStoreService/DependencyContainer call for safe insert.
        // This demo assumes injected/shared data context via environment or dependency.
        // Example:
        /*
        guard let context = DependencyContainer.shared.modelContext else {
            return .result(dialog: "Data store unavailable.")
        }
        let dog = context.fetch(Dog.self).first(where: { $0.name == dogName })
        let owner = context.fetch(DogOwner.self).first(where: { $0.ownerName == ownerName })
        let service = ServiceType.fromString(serviceType)
        let appointment = Appointment(date: date, dog: dog, owner: owner, serviceType: service)
        context.insert(appointment)
        try context.save()
        */
        return .result(dialog: "Added appointment for \(dogName) (\(serviceType)) on \(DateUtils.shortDate(date)).")
    }
}

// MARK: - Quick Note Intent

struct AddQuickNoteIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Quick Note"
    static var description = IntentDescription("Quickly add a sticky note for an owner.")

    @Parameter(title: "Note Content") var content: String
    @Parameter(title: "Owner Name", default: "") var ownerName: String

    func perform() async throws -> some ProvidesDialog {
        // TODO: Connect to DataStoreService or NoteManager to persist the note.
        return .result(dialog: "Note added for \(ownerName.isEmpty ? "business" : ownerName).")
    }
}

// MARK: - App Navigation Intent

struct OpenOwnerProfileIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Owner Profile"
    static var description = IntentDescription("Jump directly to a dog owner's profile.")

    @Parameter(title: "Owner Name") var ownerName: String

    func perform() async throws -> some ProvidesDialog {
        // TODO: Trigger deep-link or navigation state change in main app.
        return .result(dialog: "Opening profile for \(ownerName).")
    }
}

// MARK: - Register Intents

struct FurfolioAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        [
            AppShortcut(
                intent: AddAppointmentIntent(),
                phrases: ["Add grooming appointment", "Schedule dog appointment in Furfolio"]
            ),
            AppShortcut(
                intent: AddQuickNoteIntent(),
                phrases: ["Add note for owner", "Add quick note in Furfolio"]
            ),
            AppShortcut(
                intent: OpenOwnerProfileIntent(),
                phrases: ["Show profile for owner", "Open dog owner profile in Furfolio"]
            )
        ]
    }
}

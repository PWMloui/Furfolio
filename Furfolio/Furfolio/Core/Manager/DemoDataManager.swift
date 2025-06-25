//
//  DemoDataManager.swift
//  Furfolio
//
//  Enhanced: Audit trail, tags/badges, accessibility, JSON export, analytics-ready.
//  Author: mac + ChatGPT
//

import Foundation
import SwiftData

// MARK: - DemoDataManager (Tokenized, Modular, Accessible Demo Data Injection & Audit)

@MainActor
final class DemoDataManager {
    static let shared = DemoDataManager()
    private init() {}

    // MARK: - Audit/Event Log

    struct DemoAuditEvent: Codable {
        let timestamp: Date
        let operation: String         // "inject" | "clear"
        let entityTypes: [String]
        let entityCount: Int
        let tags: [String]
        let rationale: String?
        let errorDescription: String?
        var accessibilityLabel: String {
            let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
            return "\(operation.capitalized) demo data (\(entityCount) entities) at \(dateStr)."
        }
    }
    private(set) static var auditLog: [DemoAuditEvent] = []

    private func addAudit(operation: String, entityTypes: [String], entityCount: Int, tags: [String], rationale: String?, error: Error? = nil) {
        let event = DemoAuditEvent(
            timestamp: Date(),
            operation: operation,
            entityTypes: entityTypes,
            entityCount: entityCount,
            tags: tags,
            rationale: rationale,
            errorDescription: error?.localizedDescription
        )
        Self.auditLog.append(event)
        if Self.auditLog.count > 500 { Self.auditLog.removeFirst() }
    }

    static func exportLastAuditEventJSON() -> String? {
        guard let last = auditLog.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    var accessibilitySummary: String {
        Self.auditLog.last?.accessibilityLabel ?? "No demo data changes recorded."
    }

    /// Populates the provided context with demo data.
    /// - Parameter context: The model context to inject demo data into.
    func populateDemoData(in context: ModelContext) async {
        await clearDemoData(in: context)

        var totalEntities = 0
        let tags = ["demo", "preview", "sample"]

        // Owners & Dogs
        let owners: [DogOwner] = [
            DogOwner(
                ownerName: "Jane Smith",
                contactInfo: Contact(phone: "555-1234", email: "jane.smith@email.com"),
                address: "101 Oak Lane",
                dogs: [
                    Dog(
                        name: "Buddy",
                        breed: "Golden Retriever",
                        birthdate: Calendar.current.date(byAdding: .year, value: -3, to: Date()),
                        tags: ["Calm", "Loyal", "VIP", "demo"],
                        notes: "Loves peanut butter treats. Responds well to calm environments. [demo entity]"
                    ),
                    Dog(
                        name: "Shadow",
                        breed: "Labrador",
                        birthdate: Calendar.current.date(byAdding: .year, value: -2, to: Date()),
                        tags: ["Energetic", "High Energy", "demo"],
                        notes: "Prefers cool water baths. Needs extra exercise before grooming. [demo entity]"
                    )
                ],
                notes: "Demo client for onboarding and UI preview. [demo entity]"
            ),
            DogOwner(
                ownerName: "Carlos Gomez",
                contactInfo: Contact(phone: "555-6789", email: "carlos.gomez@email.com"),
                address: "22 Maple Street",
                dogs: [
                    Dog(
                        name: "Luna",
                        breed: "Poodle",
                        birthdate: Calendar.current.date(byAdding: .year, value: -4, to: Date()),
                        tags: ["Sensitive Skin", "First Visit", "demo"],
                        notes: "Needs hypoallergenic shampoo. First grooming appointment. [demo entity]"
                    )
                ],
                notes: "Demo client for onboarding and scenario testing. [demo entity]"
            )
        ]

        for owner in owners {
            owner.tags.append(contentsOf: tags)
            context.insert(owner)
            totalEntities += 1
            for dog in owner.dogs {
                dog.owner = owner
                dog.tags.append(contentsOf: tags)
                context.insert(dog)
                totalEntities += 1
            }
        }

        // Demo appointments and charges
        for owner in owners {
            for dog in owner.dogs {
                let appointment = Appointment(
                    date: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date(),
                    dog: dog,
                    owner: owner,
                    serviceType: .fullGroom,
                    notes: "Routine appointment. Demo scenario. [demo entity]"
                )
                appointment.tags = tags
                context.insert(appointment)
                totalEntities += 1

                let charge = Charge(
                    date: appointment.date,
                    type: .fullPackage,
                    amount: 65.00,
                    notes: "Groomed with style. Demo only. [demo entity]"
                )
                charge.owner = owner
                charge.dog = dog
                charge.tags = tags
                context.insert(charge)
                totalEntities += 1
            }
        }

        // Demo tasks
        let sampleTask = Task(
            title: "Call Jane Smith for feedback",
            details: "Ask about last appointment experience (demo). [demo entity]",
            dueDate: Calendar.current.date(byAdding: .day, value: 2, to: Date())
        )
        sampleTask.tags = tags
        context.insert(sampleTask)
        totalEntities += 1

        // Save & audit
        do {
            try context.save()
            addAudit(
                operation: "inject",
                entityTypes: ["DogOwner", "Dog", "Appointment", "Charge", "Task"],
                entityCount: totalEntities,
                tags: tags,
                rationale: "Demo data for preview, onboarding, and UI testing."
            )
        } catch {
            addAudit(
                operation: "inject",
                entityTypes: ["DogOwner", "Dog", "Appointment", "Charge", "Task"],
                entityCount: totalEntities,
                tags: tags,
                rationale: "Demo data for preview, onboarding, and UI testing.",
                error: error
            )
            print("DemoDataManager error saving context: \(error)")
        }
    }

    /// Removes all demo data from the context.
    func clearDemoData(in context: ModelContext) async {
        let entityTypes: [any PersistentModel.Type] = [DogOwner.self, Dog.self, Appointment.self, Charge.self, Task.self]
        var removed = 0
        let tags = ["demo", "preview", "sample"]
        for entityType in entityTypes {
            // In production, filter demo-only data via tags (predicate). Here: all instances for demo.
            let fetch = FetchDescriptor<some PersistentModel>(predicate: nil)
            if let results = try? context.fetch(fetch) as? [any PersistentModel] {
                for obj in results {
                    // Only delete if tagged as demo (assumes `tags` property or flag on model)
                    if let objTags = (obj as? TaggableEntity)?.tags, !Set(objTags).isDisjoint(with: tags) {
                        context.delete(obj)
                        removed += 1
                    }
                    // If tags not present, fallback to deleting all (legacy fallback, can remove for stricter filtering)
                    else if (obj as? TaggableEntity) == nil {
                        context.delete(obj)
                        removed += 1
                    }
                }
            }
        }
        try? context.save()
        addAudit(
            operation: "clear",
            entityTypes: entityTypes.map { String(describing: $0) },
            entityCount: removed,
            tags: tags,
            rationale: "Removed demo data (preview, onboarding, testing)."
        )
    }
}

/// Protocol to indicate taggable entities for demo cleanup.
/// Extend all your models (DogOwner, Dog, Appointment, Charge, Task) with this protocol and `tags` property.
protocol TaggableEntity {
    var tags: [String] { get set }
}

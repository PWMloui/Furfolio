//
//  DemoDataManager.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import Foundation
import SwiftData

// MARK: - DemoDataManager (Tokenized, Modular, Accessible Demo Data Injection)

/// DemoDataManager provides modular, tokenized, accessible, and auditable demo data for previews, onboarding, and dev.
/// All demo entities should be clearly marked for easy cleanup, and demo data should use business-relevant sample tags, notes, and fields for realistic owner workflows.
/// Future: support localization, scenario-based samples, and privacy/audit hooks.
@MainActor
final class DemoDataManager {
    /// Singleton instance for shared usage.
    static let shared = DemoDataManager()
    
    private init() {}
    
    /// Populates the provided context with demo data.
    /// - Parameter context: The model context to inject demo data into.
    func populateDemoData(in context: ModelContext) async {
        // Remove existing demo data first
        await clearDemoData(in: context)
        
        // Sample dog owners and their dogs
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
                        tags: ["Calm", "Loyal", "VIP"],
                        notes: "Loves peanut butter treats. Responds well to calm environments."
                    ),
                    Dog(
                        name: "Shadow",
                        breed: "Labrador",
                        birthdate: Calendar.current.date(byAdding: .year, value: -2, to: Date()),
                        tags: ["Energetic", "High Energy"],
                        notes: "Prefers cool water baths. Needs extra exercise before grooming."
                    )
                ]
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
                        tags: ["Sensitive Skin", "First Visit"],
                        notes: "Needs hypoallergenic shampoo. First grooming appointment, be gentle."
                    )
                ]
            )
        ]
        
        // Insert owners and their dogs into the context
        for owner in owners {
            // All demo entities should be flagged or labeled for demo/preview-only use.
            context.insert(owner)
            for dog in owner.dogs {
                dog.owner = owner // Set owner relationship if needed
                // Add diverse tag/note for different client/dog scenarios
                if dog.name == "Buddy" {
                    dog.tags.append("Referral")
                    dog.notes += " Referred by a long-term client."
                } else if dog.name == "Shadow" {
                    dog.notes += " Exhibits nervousness around strangers."
                } else if dog.name == "Luna" {
                    dog.tags.append("Needs Follow-up")
                    dog.notes += " Schedule follow-up check for skin condition."
                }
                context.insert(dog)
            }
        }
        
        // Add demo appointments and charges
        for owner in owners {
            for dog in owner.dogs {
                let appointment = Appointment(
                    date: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date(),
                    dog: dog,
                    owner: owner,
                    serviceType: .fullGroom,
                    notes: "Routine appointment. Confirmed client preferences."
                )
                // All demo entities should be flagged or labeled for demo/preview-only use.
                context.insert(appointment)
                
                let charge = Charge(
                    date: appointment.date,
                    type: .fullPackage,
                    amount: 65.00,
                    notes: "Groomed with style. Applied special shampoo for sensitive skin if needed."
                )
                charge.owner = owner
                charge.dog = dog
                // All demo entities should be flagged or labeled for demo/preview-only use.
                context.insert(charge)
            }
        }
        
        // Optionally, add sample tasks
        let sampleTask = Task(
            title: "Call Jane Smith for feedback",
            details: "Ask about last appointment experience and any new preferences.",
            dueDate: Calendar.current.date(byAdding: .day, value: 2, to: Date())
        )
        // All demo entities should be flagged or labeled for demo/preview-only use.
        context.insert(sampleTask)
        
        // Save the context
        do {
            // TODO: Add audit logging and privacy event for demo data injection.
            try context.save()
        } catch {
            print("DemoDataManager error saving context: \(error)")
        }
    }
    
    /// Removes all demo data from the context.
    func clearDemoData(in context: ModelContext) async {
        // Remove all demo data entities (In production, filter only demo entities by demo flag/label)
        let entityTypes: [any PersistentModel.Type] = [DogOwner.self, Dog.self, Appointment.self, Charge.self, Task.self]
        for entityType in entityTypes {
            // In production, add predicate to filter demo-only data, e.g. predicate: NSPredicate(format: "isDemo == YES")
            let fetch = FetchDescriptor<some PersistentModel>(predicate: nil)
            if let results = try? context.fetch(fetch) as? [any PersistentModel] {
                for obj in results {
                    context.delete(obj)
                }
            }
        }
        try? context.save()
    }
}

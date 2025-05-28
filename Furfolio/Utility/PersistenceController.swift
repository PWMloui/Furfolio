//
//  PersistenceController.swift
//  Furfolio
//
//  Created by mac on 5/16/25.
//

import Foundation
import SwiftData

@MainActor
/// Central controller for configuring and exposing the SwiftData ModelContainer,
/// registering custom ValueTransformers, and handling store configuration.
final class PersistenceController {
    /// Shared singleton instance
    static let shared = PersistenceController()

    /// The configured ModelContainer for the app's SwiftData models.
    let container: ModelContainer

    init(inMemory: Bool = false) {
        registerTransformers()
        container = ModelContainer(
            for: DogOwner.self, Appointment.self, Charge.self, DailyRevenue.self,
                 AppointmentTemplate.self, BehaviorTag.self, ClientMilestone.self,
                 ClientStats.self, InventoryItem.self, Pet.self, PetBehaviorLog.self,
                 PetGalleryImage.self, AddOnService.self, Expense.self, AuditLog.self,
                 VendorInvoice.self, EquipmentAsset.self, SessionLog.self,
                 ExportProfile.self,
            configurations: .init(inMemory: inMemory)
        )
        ServiceSeeder.seed(in: container.mainContext)
    }

    /// Registers all custom ValueTransformers for transformable @Attribute properties.
    private func registerTransformers() {
      ValueTransformer.setValueTransformer(
        DateArrayTransformer(),
        forName: NSValueTransformerName(Appointment.dateArrayTransformerName)
      )
      ValueTransformer.setValueTransformer(
        StringArrayTransformer(),
        forName: NSValueTransformerName(Appointment.stringArrayTransformerName)
      )
    }

    /// A context configured for SwiftUI previews and testing (in-memory).
    static var previewContext: ModelContext = {
      let controller = PersistenceController(inMemory: true)
      // Use the main context for previews
      return controller.container.mainContext
    }()
}

// MARK: - ValueTransformer Implementations

/// Transforms an array of Date to Data and back using JSON encoding.
private final class DateArrayTransformer: ValueTransformer {
    override class func allowsReverseTransformation() -> Bool { true }
    override func transformedValue(_ value: Any?) -> Any? {
        guard let dates = value as? [Date] else { return nil }
        return try? JSONEncoder().encode(dates)
    }
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else { return nil }
        return try? JSONDecoder().decode([Date].self, from: data)
    }
}

/// Transforms an array of String to Data and back using JSON encoding.
private final class StringArrayTransformer: ValueTransformer {
    override class func allowsReverseTransformation() -> Bool { true }
    override func transformedValue(_ value: Any?) -> Any? {
        guard let strings = value as? [String] else { return nil }
        return try? JSONEncoder().encode(strings)
    }
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else { return nil }
        return try? JSONDecoder().decode([String].self, from: data)
    }
}

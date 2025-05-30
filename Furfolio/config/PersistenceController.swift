//
//  PersistenceController.swift
//  Furfolio
//
//  Created by mac on 5/16/25.
//

import Foundation
import SwiftData
import os

@MainActor
/// Central controller for configuring and exposing the SwiftData ModelContainer,
/// registering custom ValueTransformers, and handling store configuration.
final class PersistenceController {
    /// Shared singleton instance
    static let shared = PersistenceController()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "PersistenceController")

    /// The configured ModelContainer for the app's SwiftData models.
    let container: ModelContainer

    init(inMemory: Bool = false) {
        logger.log("Initializing PersistenceController (inMemory: \(inMemory))")
        registerTransformers()
        logger.log("Registered custom ValueTransformers")
        container = ModelContainer(
            for: DogOwner.self, Appointment.self, Charge.self, DailyRevenue.self,
                 AppointmentTemplate.self, BehaviorTag.self, ClientMilestone.self,
                 ClientStats.self, InventoryItem.self, Pet.self, PetBehaviorLog.self,
                 PetGalleryImage.self, AddOnService.self, Expense.self, AuditLog.self,
                 VendorInvoice.self, EquipmentAsset.self, SessionLog.self,
                 ExportProfile.self,
            configurations: .init(inMemory: inMemory)
        )
        logger.log("ModelContainer initialized with models: \(container.modelSchema.entities.map { $0.name })")
        do {
            ServiceSeeder.seed(in: container.mainContext)
            logger.log("Data seeding succeeded")
        } catch {
            logger.error("Data seeding failed: \(error.localizedDescription)")
        }
        logInitialEntityCounts()
    }

    /// Registers all custom ValueTransformers for transformable @Attribute properties.
    private func registerTransformers() {
        logger.log("Registering DateArrayTransformer with name: \(Appointment.dateArrayTransformerName)")
        ValueTransformer.setValueTransformer(
            DateArrayTransformer(),
            forName: NSValueTransformerName(Appointment.dateArrayTransformerName)
        )
        logger.log("Registering StringArrayTransformer with name: \(Appointment.stringArrayTransformerName)")
        ValueTransformer.setValueTransformer(
            StringArrayTransformer(),
            forName: NSValueTransformerName(Appointment.stringArrayTransformerName)
        )
        logger.log("Completed registering custom ValueTransformers")
    }

    /// A context configured for SwiftUI previews and testing (in-memory).
    static var previewContext: ModelContext = {
        let controller = PersistenceController(inMemory: true)
        let previewLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "PersistenceController")
        previewLogger.log("Created previewContext (inMemory: true)")
        // Use the main context for previews
        return controller.container.mainContext
    }()

    /// Logs counts of key entities for diagnostic purposes.
    private func logInitialEntityCounts() {
        let ctx = container.mainContext
        let ownerCount = (try? ctx.fetch(FetchDescriptor<DogOwner>()))?.count ?? 0
        let apptCount = (try? ctx.fetch(FetchDescriptor<Appointment>()))?.count ?? 0
        let chargeCount = (try? ctx.fetch(FetchDescriptor<Charge>()))?.count ?? 0
        logger.log("Initial data counts — Owners: \(ownerCount), Appointments: \(apptCount), Charges: \(chargeCount)")
        logger.log("Completed initial entity count logging")
    }
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

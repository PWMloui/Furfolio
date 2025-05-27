//
//  PreviewHelpers.swift
//  Furfolio
//
//  Created by ChatGPT on 06/01/2025.
//  Updated on 06/26/2025 — made MainActor-isolated and fixed ModelContainer init.
//

import SwiftUI
import SwiftData

/// Helper utilities providing a SwiftData in-memory container and contexts for SwiftUI previews and tests.
@MainActor
enum PreviewHelpers {
  /// In-memory ModelContainer preconfigured with app models for use in previews.
  static let container: ModelContainer = {
    do {
      return try ModelContainer(
        for: DogOwner.self,
             Appointment.self,
             AppointmentGroup.self,
             AppointmentTemplate.self,
             BehaviorTag.self,
             Charge.self,
             ClientMilestone.self,
             ClientStats.self,
             DailyRevenue.self,
             DogAllergyProfile.self,
             FeedbackNote.self,
             InventoryItem.self,
             Pet.self,
             PetBehaviorLog.self,
             PetGalleryImage.self,
             AddOnService.self,
             Expense.self,
             AuditLog.self,
             VendorInvoice.self,
             EquipmentAsset.self,
             SessionLog.self,
             ExportProfile.self,
             Task.self
      )
    } catch {
      fatalError("Failed to create preview ModelContainer: \(error)")
    }
  }()

  /// Main context for SwiftUI previews, bound to the in-memory container.
  static var context: ModelContext {
    container.mainContext
  }

  /// Seeds the in-memory container with sample data. Call at the start of previews to populate test data.
  static func seedSampleData() {
    let ctx = context
    // Insert sample models into the main context
    let owner = DogOwner(name: "Sample Owner", email: "owner@example.com")
    ctx.insert(owner)

    let fullGroom = AppointmentTemplate(id: UUID(), serviceType: .fullGroom, name: "Full Groom", minPrice: 75, maxPrice: 160, minDuration: 60, maxDuration: 90)
    let basicGroom = AppointmentTemplate(id: UUID(), serviceType: .basicGroom, name: "Basic Groom", minPrice: 65, maxPrice: 150, minDuration: 45, maxDuration: 60)
    let spaBath = AppointmentTemplate(id: UUID(), serviceType: .spaBath, name: "Spa Bath", minPrice: 55, maxPrice: 140, minDuration: 30, maxDuration: 45)
    ctx.insert(fullGroom)
    ctx.insert(basicGroom)
    ctx.insert(spaBath)

    let addOns = [
      AddOnService(type: .bath, minPrice: 40, maxPrice: 85, requires: []),
      AddOnService(type: .haircut, minPrice: 40, maxPrice: 85, requires: []),
      AddOnService(type: .deShedding, minPrice: 20, maxPrice: 25, requires: [.bath]),
      AddOnService(type: .analGlands, minPrice: 8, maxPrice: 12, requires: []),
      AddOnService(type: .nailClipping, minPrice: 20, maxPrice: 25, requires: []),
      AddOnService(type: .earCleaning, minPrice: 5, maxPrice: 15, requires: []),
      AddOnService(type: .faceGrooming, minPrice: 10, maxPrice: 15, requires: []),
      AddOnService(type: .pawPadTrim, minPrice: 5, maxPrice: 8, requires: []),
      AddOnService(type: .hygieneTrim, minPrice: 5, maxPrice: 8, requires: []),
      AddOnService(type: .teethBrushing, minPrice: 8, maxPrice: 10, requires: []),
      AddOnService(type: .knotsMatting, minPrice: 5, maxPrice: 10, requires: []),
      AddOnService(type: .fleaTickBath, minPrice: 5, maxPrice: 10, requires: []),
      AddOnService(type: .hairDye, minPrice: 80, maxPrice: 1000, requires: [])
    ]
    addOns.forEach { ctx.insert($0) }

      let expense = Expense(id: UUID(), date: Date(), category: "Supplies", amount: 120.50, notes: "Shampoo and conditioner restock", receiptImage: nil)
    ctx.insert(expense)

    let audit = AuditLog(id: UUID(), entityName: "DogOwner", changeType: .create, changedBy: "Preview", timestamp: Date(), details: "Created sample owner")
    ctx.insert(audit)

    let invoice = VendorInvoice(id: UUID(), supplierName: "Pet Supplies Co", dueDate: Calendar.current.date(byAdding: .day, value: 30, to: Date()), amount: 250.00, isPaid: false)
    ctx.insert(invoice)

    let asset = EquipmentAsset(id: UUID(), name: "Clippers", purchaseDate: Date(), lastServiceDate: Calendar.current.date(byAdding: .month, value: -6, to: Date()), nextServiceDue: Calendar.current.date(byAdding: .month, value: 6, to: Date()))
    ctx.insert(asset)

    let session = SessionLog(id: UUID(), appointmentID: fullGroom.id, startTime: Date(), endTime: Calendar.current.date(byAdding: .minute, value: 75, to: Date()))
    ctx.insert(session)

    let profile = ExportProfile(id: UUID(), name: "Monthly Summary", format: "CSV", createdAt: Date())
    ctx.insert(profile)

    let task = Task(title: "Follow up with Sample Owner", details: "Call to check on grooming satisfaction", dueDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()), priority: .high, owner: owner, in: ctx)

    // Save seeded data for previews
    try? ctx.save()
  }
}

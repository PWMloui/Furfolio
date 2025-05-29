
//
//  ServiceSeeder.swift
//  Furfolio
//
//  Created by YourName on 5/27/25.
//

import SwiftData
import os

/// Seeds default services and appointment templates on first app launch.
struct ServiceSeeder {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "ServiceSeeder")
  
  /// Call this once during app startup to seed data if the store is empty.
  static func seedIfNeeded(in context: ModelContext) {
    logger.log("Starting data seeding if needed")
    seedAddOnServicesIfNeeded(in: context)
    seedAppointmentTemplatesIfNeeded(in: context)
    seedExpensesIfNeeded(in: context)
    seedVendorInvoicesIfNeeded(in: context)
    seedEquipmentAssetsIfNeeded(in: context)
    seedSessionLogsIfNeeded(in: context)
    seedExportProfilesIfNeeded(in: context)
  }

  /// Alias for seedIfNeeded, matching common call sites
  static func seed(in context: ModelContext) {
    seedIfNeeded(in: context)
  }
  
  // MARK: - Add-On Services
  
  private static func seedAddOnServicesIfNeeded(in context: ModelContext) {
    logger.log("Checking existing \(String(describing: AddOnService.self))")
    let fetchRequest: FetchDescriptor<AddOnService> = FetchDescriptor()
    let existing = (try? context.fetch(fetchRequest)) ?? []
    guard existing.isEmpty else { return }
    logger.log("No existing \(String(describing: AddOnService.self)) found, seeding defaults")
    
    let services: [AddOnService] = [
      .init(type: .bath,                minPrice: 40,  maxPrice: 85,   requires: []),
      .init(type: .haircut,            minPrice: 40,  maxPrice: 85,   requires: []),
      .init(type: .deShedding,         minPrice: 20,  maxPrice: 25,   requires: [.bath]),
      .init(type: .analGlandsExpression,minPrice: 8,   maxPrice: 12,   requires: []),
      .init(type: .nailClipping,       minPrice: 20,  maxPrice: 25,   requires: []),
      .init(type: .earCleaning,        minPrice: 5,   maxPrice: 15,   requires: []),
      .init(type: .faceGrooming,       minPrice: 10,  maxPrice: 15,   requires: []),
      .init(type: .pawTrim,            minPrice: 5,   maxPrice: 8,    requires: []),
      .init(type: .hygieneTrim,        minPrice: 5,   maxPrice: 8,    requires: []),
      .init(type: .teethBrushing,      minPrice: 8,   maxPrice: 10,   requires: []),
      .init(type: .knotsMattingFee,    minPrice: 5,   maxPrice: 10,   requires: []),
      .init(type: .fleaTickTreatment,  minPrice: 5,   maxPrice: 10,   requires: []),
      .init(type: .hairDye,            minPrice: 80,  maxPrice: 1000, requires: [])
    ]
    
    services.forEach { context.insert($0) }
    try? context.save()
  }
  
  // MARK: - Appointment Templates
  
  private static func seedAppointmentTemplatesIfNeeded(in context: ModelContext) {
    logger.log("Checking existing \(String(describing: AppointmentTemplate.self))")
    let fetchRequest: FetchDescriptor<AppointmentTemplate> = FetchDescriptor()
    let existing = (try? context.fetch(fetchRequest)) ?? []
    guard existing.isEmpty else { return }
    logger.log("No existing \(String(describing: AppointmentTemplate.self)) found, seeding defaults")
    
    let templates: [AppointmentTemplate] = [
        .init(type: .fullGroom, minPrice: 75,  maxPrice: 160, minDuration: .minutes(60), maxDuration: .minutes(90)),
        .init(type: .basicGroom, minPrice: 65,  maxPrice: 150, minDuration: .minutes(45), maxDuration: .minutes(60)),
        .init(type: .spaBath,     minPrice: 55,  maxPrice: 140, minDuration: .minutes(30), maxDuration: .minutes(45))
    ]
    
    templates.forEach { context.insert($0) }
    try? context.save()
  }
  
  private static func seedExpensesIfNeeded(in context: ModelContext) {
    logger.log("Checking existing \(String(describing: Expense.self))")
    let fetchRequest: FetchDescriptor<Expense> = FetchDescriptor()
    let existing = (try? context.fetch(fetchRequest)) ?? []
    guard existing.isEmpty else { return }
    logger.log("No existing \(String(describing: Expense.self)) found, seeding defaults")
    
    let expense = Expense(date: .now, category: "Supplies", amount: 0, notes: "", receiptImageData: nil)
    context.insert(expense)
    try? context.save()
  }
  
  private static func seedVendorInvoicesIfNeeded(in context: ModelContext) {
    logger.log("Checking existing \(String(describing: VendorInvoice.self))")
    let fetchRequest: FetchDescriptor<VendorInvoice> = FetchDescriptor()
    let existing = (try? context.fetch(fetchRequest)) ?? []
    guard existing.isEmpty else { return }
    logger.log("No existing \(String(describing: VendorInvoice.self)) found, seeding defaults")
    
    let invoice = VendorInvoice(date: .now, vendorName: "Default Vendor", amount: 0, notes: "")
    context.insert(invoice)
    try? context.save()
  }
  
  private static func seedEquipmentAssetsIfNeeded(in context: ModelContext) {
    logger.log("Checking existing \(String(describing: EquipmentAsset.self))")
    let fetchRequest: FetchDescriptor<EquipmentAsset> = FetchDescriptor()
    let existing = (try? context.fetch(fetchRequest)) ?? []
    guard existing.isEmpty else { return }
    logger.log("No existing \(String(describing: EquipmentAsset.self)) found, seeding defaults")
    
    let asset = EquipmentAsset(name: "Default Equipment", purchaseDate: .now, value: 0, notes: "")
    context.insert(asset)
    try? context.save()
  }
  
  private static func seedSessionLogsIfNeeded(in context: ModelContext) {
    logger.log("Checking existing \(String(describing: SessionLog.self))")
    let fetchRequest: FetchDescriptor<SessionLog> = FetchDescriptor()
    let existing = (try? context.fetch(fetchRequest)) ?? []
    guard existing.isEmpty else { return }
    logger.log("No existing \(String(describing: SessionLog.self)) found, seeding defaults")
    
    let log = SessionLog(date: .now, notes: "")
    context.insert(log)
    try? context.save()
  }
  
  private static func seedExportProfilesIfNeeded(in context: ModelContext) {
    logger.log("Checking existing \(String(describing: ExportProfile.self))")
    let fetchRequest: FetchDescriptor<ExportProfile> = FetchDescriptor()
    let existing = (try? context.fetch(fetchRequest)) ?? []
    guard existing.isEmpty else { return }
    logger.log("No existing \(String(describing: ExportProfile.self)) found, seeding defaults")
    
    let profile = ExportProfile(name: "Default Profile", settings: [:])
    context.insert(profile)
    try? context.save()
  }
  
}

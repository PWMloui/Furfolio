//
//  Services.swift
//  Furfolio
//
//  Created by mac on 5/27/25.
//

//
//  ServiceSeeder.swift
//  Furfolio
//
//  Created by YourName on 5/27/25.
//

import SwiftData

/// Seeds default services and appointment templates on first app launch.
struct ServiceSeeder {
  
  /// Call this once during app startup to seed data if the store is empty.
  static func seedIfNeeded(in context: ModelContext) {
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
    let fetchRequest: FetchDescriptor<AddOnService> = FetchDescriptor()
    let existing = (try? context.fetch(fetchRequest)) ?? []
    guard existing.isEmpty else { return }
    
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
    let fetchRequest: FetchDescriptor<AppointmentTemplate> = FetchDescriptor()
    let existing = (try? context.fetch(fetchRequest)) ?? []
    guard existing.isEmpty else { return }
    
    let templates: [AppointmentTemplate] = [
        .init(type: .fullGroom, minPrice: 75,  maxPrice: 160, minDuration: .minutes(60), maxDuration: .minutes(90)),
        .init(type: .basicGroom, minPrice: 65,  maxPrice: 150, minDuration: .minutes(45), maxDuration: .minutes(60)),
        .init(type: .spaBath,     minPrice: 55,  maxPrice: 140, minDuration: .minutes(30), maxDuration: .minutes(45))
    ]
    
    templates.forEach { context.insert($0) }
    try? context.save()
  }
  
  private static func seedExpensesIfNeeded(in context: ModelContext) {
    let fetchRequest: FetchDescriptor<Expense> = FetchDescriptor()
    let existing = (try? context.fetch(fetchRequest)) ?? []
    guard existing.isEmpty else { return }
    
    let expense = Expense(date: .now, category: "Supplies", amount: 0, notes: "", receiptImageData: nil)
    context.insert(expense)
    try? context.save()
  }
  
  private static func seedVendorInvoicesIfNeeded(in context: ModelContext) {
    let fetchRequest: FetchDescriptor<VendorInvoice> = FetchDescriptor()
    let existing = (try? context.fetch(fetchRequest)) ?? []
    guard existing.isEmpty else { return }
    
    let invoice = VendorInvoice(date: .now, vendorName: "Default Vendor", amount: 0, notes: "")
    context.insert(invoice)
    try? context.save()
  }
  
  private static func seedEquipmentAssetsIfNeeded(in context: ModelContext) {
    let fetchRequest: FetchDescriptor<EquipmentAsset> = FetchDescriptor()
    let existing = (try? context.fetch(fetchRequest)) ?? []
    guard existing.isEmpty else { return }
    
    let asset = EquipmentAsset(name: "Default Equipment", purchaseDate: .now, value: 0, notes: "")
    context.insert(asset)
    try? context.save()
  }
  
  private static func seedSessionLogsIfNeeded(in context: ModelContext) {
    let fetchRequest: FetchDescriptor<SessionLog> = FetchDescriptor()
    let existing = (try? context.fetch(fetchRequest)) ?? []
    guard existing.isEmpty else { return }
    
    let log = SessionLog(date: .now, notes: "")
    context.insert(log)
    try? context.save()
  }
  
  private static func seedExportProfilesIfNeeded(in context: ModelContext) {
    let fetchRequest: FetchDescriptor<ExportProfile> = FetchDescriptor()
    let existing = (try? context.fetch(fetchRequest)) ?? []
    guard existing.isEmpty else { return }
    
    let profile = ExportProfile(name: "Default Profile", settings: [:])
    context.insert(profile)
    try? context.save()
  }
  
}

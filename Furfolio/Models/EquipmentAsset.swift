// EquipmentAsset.swift
// Furfolio
//
// Created by ChatGPT on 06/27/2025.

import Foundation
import SwiftData
import os

@Model
final class EquipmentAsset: Identifiable, Hashable {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "EquipmentAsset")

  // MARK: - Persistent Properties

  @Attribute var id: UUID
  @Attribute var name: String
  @Attribute var purchaseDate: Date
  @Attribute var lastServiceDate: Date?
  @Attribute var nextServiceDue: Date?
  @Attribute var notes: String?

  // MARK: - Init

  init(
    id: UUID = UUID(),
    name: String,
    purchaseDate: Date = Date(),
    lastServiceDate: Date? = nil,
    nextServiceDue: Date? = nil,
    notes: String? = nil
  ) {
    self.id = id
    self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
    self.purchaseDate = purchaseDate
    self.lastServiceDate = lastServiceDate
    self.nextServiceDue = nextServiceDue
    self.notes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        logger.log("Initialized EquipmentAsset id: \(id), name: \(name), purchaseDate: \(purchaseDate)")
  }

  // MARK: - Computed

  /// True if maintenance is overdue
  @Transient
  var isMaintenanceOverdue: Bool {
        logger.log("Checking maintenance overdue for asset \(id), nextServiceDue: \(String(describing: nextServiceDue))")
    guard let due = nextServiceDue else { return false }
        let result = Date() > due
        logger.log("isMaintenanceOverdue result: \(result)")
        return result
  }

  /// Days until next service (negative if overdue)
  @Transient
  var daysUntilService: Int? {
        logger.log("Computing daysUntilService for asset \(id), nextServiceDue: \(String(describing: nextServiceDue))")
    guard let due = nextServiceDue else { return nil }
    let comps = Calendar.current.dateComponents([.day], from: Date(), to: due)
        let days = comps.day
        logger.log("daysUntilService result: \(String(describing: days))")
        return days
  }

  /// Schedule the next maintenance service after a given number of days.
  func scheduleNextService(inDays days: Int) {
        logger.log("Scheduling next service for asset \(id) in \(days) days, lastServiceDate: \(String(describing: lastServiceDate))")
    let baseDate = lastServiceDate ?? Date()
    nextServiceDue = Calendar.current.date(byAdding: .day, value: days, to: baseDate)
        logger.log("Next service due updated to: \(String(describing: nextServiceDue))")
  }

  // MARK: - Hashable

  static func == (lhs: EquipmentAsset, rhs: EquipmentAsset) -> Bool {
    lhs.id == rhs.id
  }
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  // MARK: - Fetch Helpers

  /// All assets sorted by name
  static func fetchAll(in context: ModelContext) -> [EquipmentAsset] {
      let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "EquipmentAsset")
      logger.log("Fetching all EquipmentAsset entries")
    let desc = FetchDescriptor<EquipmentAsset>(
      sortBy: [ SortDescriptor<EquipmentAsset>(\.name, order: .forward) ]
    )
    let results = (try? context.fetch(desc)) ?? []
      logger.log("Fetched \(results.count) EquipmentAsset entries")
    return results
  }

  /// Assets needing service (nextServiceDue nil or overdue)
  static func fetchNeedingService(in context: ModelContext) -> [EquipmentAsset] {
      let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "EquipmentAsset")
      logger.log("Fetching EquipmentAsset needing service")
    let desc = FetchDescriptor<EquipmentAsset>(
      predicate: #Predicate<EquipmentAsset> {
        $0.nextServiceDue == nil || $0.nextServiceDue! < Date()
      },
      sortBy: [ SortDescriptor<EquipmentAsset>(\.nextServiceDue, order: .forward) ]
    )
    let results = (try? context.fetch(desc)) ?? []
      logger.log("Fetched \(results.count) assets needing service")
    return results
  }
}

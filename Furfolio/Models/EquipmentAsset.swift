// EquipmentAsset.swift
// Furfolio
//
// Created by ChatGPT on 06/27/2025.

import Foundation
import SwiftData

@Model
final class EquipmentAsset: Identifiable, Hashable {
  // MARK: – Persistent Properties

  @Attribute var id: UUID
  @Attribute var name: String
  @Attribute var purchaseDate: Date
  @Attribute var lastServiceDate: Date?
  @Attribute var nextServiceDue: Date?
  @Attribute var notes: String?

  // MARK: – Init

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
  }

  // MARK: – Computed

  /// True if maintenance is overdue
  @Transient
  var isMaintenanceOverdue: Bool {
    guard let due = nextServiceDue else { return false }
    return Date() > due
  }

  /// Days until next service (negative if overdue)
  @Transient
  var daysUntilService: Int? {
    guard let due = nextServiceDue else { return nil }
    let comps = Calendar.current.dateComponents([.day], from: Date(), to: due)
    return comps.day
  }

  // MARK: – Hashable

  static func == (lhs: EquipmentAsset, rhs: EquipmentAsset) -> Bool {
    lhs.id == rhs.id
  }
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  // MARK: – Fetch Helpers

  /// All assets sorted by name
  static func fetchAll(in context: ModelContext) -> [EquipmentAsset] {
    let desc = FetchDescriptor<EquipmentAsset>(
      sortBy: [ SortDescriptor<EquipmentAsset>(\.name, order: .forward) ]
    )
    return (try? context.fetch(desc)) ?? []
  }

  /// Assets needing service (nextServiceDue nil or overdue)
  static func fetchNeedingService(in context: ModelContext) -> [EquipmentAsset] {
    let desc = FetchDescriptor<EquipmentAsset>(
      predicate: #Predicate<EquipmentAsset> {
        $0.nextServiceDue == nil || $0.nextServiceDue! < Date()
      },
      sortBy: [ SortDescriptor<EquipmentAsset>(\.nextServiceDue, order: .forward) ]
    )
    return (try? context.fetch(desc)) ?? []
  }
}

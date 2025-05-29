//
//  Charge.swift
//  Furfolio
//
//  Created by mac on 12/20/24.
//  Updated on Jun 21, 2025 — added totalByType(_:), fetchTotalsByType(in:), and behaviorBadge.
//

import Foundation
// TODO: Centralize transformer registration in PersistenceController and move formatting logic to a ViewModel or FormatterService.
import SwiftData
import SwiftUI
import os

@preconcurrency
@Model
final class Charge: Identifiable, Hashable {
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "Charge")
    
    // MARK: – Transformer Names
    private static let stringArrayTransformerName = "StringArrayTransformer"
    
  // MARK: – Persistent Properties
  @Attribute                   var id: UUID = UUID()
  @Attribute                   var date: Date
  @Attribute                   var serviceType: ServiceType
  /// The charged amount; must be non-negative.
  @Attribute                   var amount: Double
  @Attribute                   var paymentMethod: PaymentMethod
  /// Optional notes for the charge.
  @Attribute                   var notes: String?
  @Relationship(deleteRule: .nullify)
  var dogOwner: DogOwner
  @Relationship(deleteRule: .nullify)
  var appointment: Appointment?
  @Attribute(.transformable(by: Charge.stringArrayTransformerName))
  var petBadges: [String] = []
  @Attribute                   var createdAt: Date = Date.now
  @Attribute                   var updatedAt: Date?
  @Attribute                   var isArchived: Bool = false
    
    /// Designated initializer for Charge model.
    init(
        id: UUID = UUID(),
        date: Date,
        serviceType: ServiceType,
        amount: Double,
        paymentMethod: PaymentMethod,
        notes: String? = nil,
        dogOwner: DogOwner,
        appointment: Appointment? = nil,
        petBadges: [String] = [],
        createdAt: Date = Date.now,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.date = date
        self.serviceType = serviceType
        self.amount = max(0, amount)
        self.paymentMethod = paymentMethod
        self.notes = notes
        self.dogOwner = dogOwner
        self.appointment = appointment
        self.petBadges = petBadges
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        logger.log("Initialized Charge id: \(id), amount: \(amount), serviceType: \(serviceType.rawValue)")
    }

    // MARK: – Enumerations
    enum ServiceType: String, Codable, CaseIterable, Identifiable {
        case basic  = "Basic Package"
        case full   = "Full Package"
        case custom = "Custom Package"
        
        var id: String { rawValue }
        var localized: String { NSLocalizedString(rawValue, comment: "") }
    }
    enum PaymentMethod: String, Codable, CaseIterable, Identifiable {
        case cash   = "Cash"
        case credit = "Credit Card"
        case debit  = "Debit Card"
        case zelle  = "Zelle"
        
        var id: String { rawValue }
        var localized: String { NSLocalizedString(rawValue, comment: "") }
    }
    
  // MARK: – Static Formatters
  /// Shared currency formatter for amount display.
  private static let currencyFormatter: NumberFormatter = {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.locale = .current
    return f
  }()
  /// Shared relative date formatter for human-readable dates.
  private static let relativeFormatter: RelativeDateTimeFormatter = {
    let f = RelativeDateTimeFormatter()
    f.unitsStyle = .full
    return f
  }()
  /// Shared formatter for full date and time display.
  private static let dateTimeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .short
    return f
  }()

  // MARK: – Computed Properties
  /// Returns the amount formatted as a currency string.
  @Transient
  var formattedAmount: String {
    Self.currencyFormatter.string(from: NSNumber(value: amount))
      ?? "\(Self.currencyFormatter.currencySymbol ?? "$")\(amount)"
  }

  /// Returns the localized payment method string.
  @Transient
  var formattedPaymentMethod: String {
    paymentMethod.localized
  }

  /// Returns the charge date formatted for display.
  @Transient
  var formattedDate: String {
    Self.dateTimeFormatter.string(from: date)
  }

  /// Returns a human-readable relative date string (e.g., "2 days ago").
  @Transient
  var relativeDate: String {
    Self.relativeFormatter.localizedString(for: date, relativeTo: Date.now)
  }

  /// Indicates whether the charge date is before today’s start.
  @Transient
  var isOverdue: Bool {
    date < Calendar.current.startOfDay(for: Date.now)
  }

  /// Derives a behavior badge emoji based on associated notes.
  @Transient
  var behaviorBadge: String {
    let noteText = notes ?? ""
    let badge = BadgeEngine.behaviorBadge(from: noteText)
    return badge.description
  }

  /// Combines key charge details into a single summary string.
  @Transient
  var summary: String {
    let base = "\(formattedDate) • \(serviceType.localized) • \(formattedAmount) • \(formattedPaymentMethod)"
    if let n = notes?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty {
      return base + " • Notes: \(n)"
    }
    return base
  }
    
    // MARK: – Actions
    /// Adds a badge to the charge if not already present and updates updatedAt.
    func addBadge(_ badge: String) {
        logger.log("Adding badge '\(badge)' to Charge \(id)")
        guard !petBadges.contains(badge) else { return }
        petBadges.append(badge)
        logger.log("Added badge. Current badges: \(petBadges)")
        updatedAt = Date.now
    }
    /// Updates the charge’s amount and notes, enforcing non-negative amount, and updates updatedAt.
    func update(amount: Double? = nil, notes: String? = nil) {
        logger.log("Updating Charge \(id) with amount: \(String(describing: amount)), notes: \(String(describing: notes))")
        if let amt = amount { self.amount = max(0, amt) }
        if let n = notes?.trimmingCharacters(in: .whitespacesAndNewlines) {
            self.notes = n
        }
        logger.log("Updated fields. Pre-update values -> amount: \(self.amount), notes: \(self.notes ?? "")")
        updatedAt = Date.now
        logger.log("Set updatedAt for Charge \(id): \(updatedAt!)")
    }
    /// Marks the charge as archived (soft-delete) and updates timestamp.
    func archive() {
        logger.log("Archiving Charge \(id)")
        isArchived = true
        updatedAt = Date.now
        logger.log("Archived Charge \(id), updatedAt: \(updatedAt!)")
    }

    /// Restores an archived charge.
    func restore() {
        logger.log("Restoring Charge \(id)")
        isArchived = false
        updatedAt = Date.now
        logger.log("Restored Charge \(id), updatedAt: \(updatedAt!)")
    }
    
    // MARK: – Static Create & Fetch
    /// Creates and inserts a new Charge entity into the given context.
    @discardableResult
    static func create(
        date: Date = Date.now,
        serviceType: ServiceType,
        amount: Double,
        paymentMethod: PaymentMethod,
        notes: String? = nil,
        dogOwner: DogOwner,
        petBadges: [String] = [],
        appointment: Appointment? = nil,
        in context: ModelContext
    ) -> Charge {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "Charge")
        logger.log("Creating Charge with amount: \(amount), serviceType: \(serviceType.rawValue)")
        let charge = Charge(
            date: date,
            serviceType: serviceType,
            amount: max(0, amount),
            paymentMethod: paymentMethod,
            notes: notes?.trimmingCharacters(in: .whitespacesAndNewlines),
            dogOwner: dogOwner,
            appointment: appointment,
            petBadges: petBadges
        )
        context.insert(charge)
        logger.log("Created Charge id: \(charge.id)")
        return charge
    }
    /// Fetches all charges in reverse chronological order.
    static func fetchAll(in context: ModelContext) -> [Charge] {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "Charge")
        logger.log("Fetching all Charges")
        let descriptor = FetchDescriptor<Charge>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\Charge.date, order: .reverse)]
        )
        let charges = (try? context.fetch(descriptor)) ?? []
        logger.log("Fetched \(charges.count) Charges")
        return charges
    }
    /// Fetches charges for a specific owner in reverse chronological order.
    static func fetch(for owner: DogOwner, in context: ModelContext) -> [Charge] {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "Charge")
        logger.log("Fetching Charges for owner id: \(owner.id)")
        let descriptor = FetchDescriptor<Charge>(
            predicate: #Predicate { $0.dogOwner == owner && !$0.isArchived },
            sortBy: [SortDescriptor(\Charge.date, order: .reverse)]
        )
        let charges = (try? context.fetch(descriptor)) ?? []
        logger.log("Fetched \(charges.count) Charges for owner")
        return charges
    }
    /// Fetches only archived charges.
    static func fetchArchived(in context: ModelContext) -> [Charge] {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "Charge")
        logger.log("Fetching archived Charges")
        let descriptor = FetchDescriptor<Charge>(
            predicate: #Predicate { $0.isArchived },
            sortBy: [SortDescriptor(\Charge.date, order: .reverse)]
        )
        let charges = (try? context.fetch(descriptor)) ?? []
        logger.log("Fetched \(charges.count) archived Charges")
        return charges
    }
    
    // MARK: – New: Totals by Service Type
    /// Aggregates total amounts by service type from the provided charges.
    static func totalByType(_ charges: [Charge]) -> [ServiceType: Double] {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "Charge")
        logger.log("Calculating totals by type for \(charges.count) charges")
        let totals = Dictionary(grouping: charges, by: \.serviceType)
            .mapValues { group in group.reduce(0) { $0 + $1.amount } }
        logger.log("Totals by type: \(totals)")
        return totals
    }
    /// Fetches all charges and returns totals by service type.
    static func fetchTotalsByType(in context: ModelContext) -> [ServiceType: Double] {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "Charge")
        logger.log("Fetching totals by type from context")
        let totals = totalByType(fetchAll(in: context))
        logger.log("Fetched totals by type: \(totals)")
        return totals
    }
    
    // MARK: – Hashable
    static func ==(lhs: Charge, rhs: Charge) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    
}

//
//  ClientMilestone.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on Jun 11, 2025 — fully updated preview to use ModelConfiguration for in-memory store.
//

import SwiftData
import Foundation
// TODO: Mark key properties as required and computed props as transient for SwiftData optimization

@Model
final class ClientMilestone: Identifiable, Hashable {
    
    // MARK: – Persistent Properties
    
    @Attribute
    var id: UUID = UUID()
    
    @Attribute
    var dateAchieved: Date = Date.now
    
    @Attribute
    var type: MilestoneType
    
    @Attribute
    var details: String?
    
    @Relationship(deleteRule: .nullify)
    var dogOwner: DogOwner
    
    @Attribute
    var createdAt: Date = Date.now
    
    @Attribute
    var updatedAt: Date?
    
    
    // MARK: – Milestone Types
    
    enum MilestoneType: String, Codable, CaseIterable, Identifiable {
        case firstVisit       = "First Visit"
        case fiveVisits       = "Five Visits"
        case revenueThreshold = "Revenue Threshold"
        case retentionRisk    = "Retention Risk"
        case custom           = "Custom"
        
        var id: String { rawValue }
        var localized: String { NSLocalizedString(rawValue, comment: "") }
        var icon: String {
            switch self {
            case .firstVisit:       return "🎉"
            case .fiveVisits:       return "🏅"
            case .revenueThreshold: return "💰"
            case .retentionRisk:    return "⚠️"
            case .custom:           return "⭐️"
            }
        }
    }
    
    
    // MARK: – Formatter Cache
    
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
    
    
    // MARK: – Computed Properties
    
    @Transient
    var formattedDate: String {
      Self.dateFormatter.string(from: dateAchieved)
    }
    
    @Transient
    var formattedCreatedAt: String {
      Self.dateFormatter.string(from: createdAt)
    }
    
    @Transient
    var formattedUpdatedAt: String {
      guard let u = updatedAt else { return "—" }
      return Self.dateFormatter.string(from: u)
    }
    
    @Transient
    var displayTitle: String {
      "\(type.icon) \(type.localized)"
    }
    
    @Transient
    var summary: String {
      var parts = ["\(displayTitle) on \(formattedDate)"]
      if let d = details, !d.isEmpty {
        parts.append(d)
      }
      return parts.joined(separator: " • ")
    }
    
    
    // MARK: – Initialization
    
    /// Initializes a new ClientMilestone with trimmed details.
    init(
      type: MilestoneType,
      owner: DogOwner,
      dateAchieved: Date = Date.now,
      details: String? = nil
    ) {
      self.type = type
      self.dogOwner = owner
      self.dateAchieved = dateAchieved
      self.details = details?.trimmingCharacters(in: .whitespacesAndNewlines)
      // createdAt default applies
    }

    /// Designated initializer for ClientMilestone model.
    init(
      id: UUID = UUID(),
      type: MilestoneType,
      owner: DogOwner,
      dateAchieved: Date = Date.now,
      details: String? = nil,
      createdAt: Date = Date.now,
      updatedAt: Date? = nil
    ) {
      self.id = id
      self.type = type
      self.dogOwner = owner
      self.dateAchieved = dateAchieved
      self.details = details?.trimmingCharacters(in: .whitespacesAndNewlines)
      self.createdAt = createdAt
      self.updatedAt = updatedAt
    }
    
    
    // MARK: – Updating
    
    /// Updates milestone properties, trims details, and sets `updatedAt` to now.
    func update(
        type: MilestoneType,
        dateAchieved: Date,
        details: String?
    ) {
        self.type = type
        self.dateAchieved = dateAchieved
        self.details = details?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.updatedAt = Date.now
    }
    
    
    // MARK: – Convenience Creation
    
    /// Records a first visit milestone for the owner.
    @discardableResult
    static func recordFirstVisit(
        for owner: DogOwner,
        in context: ModelContext
    ) -> ClientMilestone {
        let m = ClientMilestone(
            type: .firstVisit,
            owner: owner,
            details: NSLocalizedString("Congratulations on your first visit!", comment: "")
        )
        context.insert(m)
        return m
    }
    
    /// Records a five visits milestone for the owner.
    @discardableResult
    static func recordFiveVisits(
        for owner: DogOwner,
        in context: ModelContext
    ) -> ClientMilestone {
        let m = ClientMilestone(
            type: .fiveVisits,
            owner: owner,
            details: NSLocalizedString("You've reached 5 visits—thank you!", comment: "")
        )
        context.insert(m)
        return m
    }
    
    /// Records a revenue threshold milestone for the owner.
    @discardableResult
    static func recordRevenueThreshold(
        amount: Double,
        for owner: DogOwner,
        in context: ModelContext
    ) -> ClientMilestone {
        let detail = String(
            format: NSLocalizedString("Total revenue reached $%.2f", comment: ""),
            amount
        )
        let m = ClientMilestone(type: .revenueThreshold, owner: owner, details: detail)
        context.insert(m)
        return m
    }
    
    /// Records a retention risk milestone for the owner.
    @discardableResult
    static func recordRetentionRisk(
        for owner: DogOwner,
        in context: ModelContext
    ) -> ClientMilestone {
        let m = ClientMilestone(
            type: .retentionRisk,
            owner: owner,
            details: NSLocalizedString("No visits in over 60 days", comment: "")
        )
        context.insert(m)
        return m
    }
    
    /// Records a custom milestone for the owner.
    @discardableResult
    static func recordCustom(
        name: String,
        details: String?,
        for owner: DogOwner,
        in context: ModelContext
    ) -> ClientMilestone {
        let combined = name.trimmingCharacters(in: .whitespacesAndNewlines)
            + (details.map { ": \($0)" } ?? "")
        let m = ClientMilestone(type: .custom, owner: owner, details: combined)
        context.insert(m)
        return m
    }
    
    
    // MARK: – Fetch Helpers
    
    /// Fetches all milestones for a given owner, newest first.
    static func fetchAll(
        for owner: DogOwner,
        in context: ModelContext
    ) -> [ClientMilestone] {
        let descriptor = FetchDescriptor<ClientMilestone>(
            predicate: #Predicate { $0.dogOwner.id == owner.id },
            sortBy: [ SortDescriptor(\ClientMilestone.dateAchieved, order: .reverse) ]
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            print("⚠️ ClientMilestone.fetchAll failed:", error)
            return []
        }
    }
    
    /// Fetches all milestones, newest first.
    static func fetchAll(in context: ModelContext) -> [ClientMilestone] {
        let descriptor = FetchDescriptor<ClientMilestone>(
            sortBy: [ SortDescriptor(\ClientMilestone.dateAchieved, order: .reverse) ]
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            print("⚠️ ClientMilestone.fetchAll(in:) failed:", error)
            return []
        }
    }
    
    
    // MARK: – Hashable
    
    static func == (lhs: ClientMilestone, rhs: ClientMilestone) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

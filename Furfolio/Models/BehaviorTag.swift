//
//  BehaviorTag.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on Jun 8, 2025 — polished FetchDescriptors, added SwiftUI previews, Swifty tweaks.
//


import SwiftData
import os

// TODO: Refactor computed properties to be transient attributes to avoid unnecessary persistence
@Model
final class BehaviorTag: Identifiable, Hashable {
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "BehaviorTag")
    
    // MARK: – Persistent Properties
    
    @Attribute(.unique)
    var id: UUID = UUID()
    
    @Attribute
    var name: String
    
    @Attribute
    var icon: String
    
    @Attribute
    var detail: String?
    
    @Attribute
    var createdAt: Date = Date.now
    
    @Attribute
    var updatedAt: Date?
    
    @Attribute
    var isArchived: Bool = false
    
    @Relationship(deleteRule: .nullify)
    var appointments: [Appointment] = []
    
    
    // MARK: – Init
    
    /// Initializes a BehaviorTag with sanitized inputs.
    init(
        name: String,
        icon: String,
        detail: String? = nil
    ) {
        self.name   = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.icon   = icon
        self.detail = detail?.trimmingCharacters(in: .whitespacesAndNewlines)
        logger.log("Initialized BehaviorTag id: \(id), name: \(name)")
    }
    
    
    // MARK: – Formatter
    private static let dateFormatter: DateFormatter = {
      let f = DateFormatter()
      f.dateStyle = .medium
      f.timeStyle = .none
      return f
    }()

    // MARK: – Transient Computed Properties

    @Transient
    var isValid: Bool {
      !name.isEmpty && !icon.isEmpty
    }

    @Transient
    var displayName: String {
      "\(icon) \(name)"
    }

    @Transient
    var appointmentCount: Int {
      appointments.count
    }

    @Transient
    var formattedCreatedAt: String {
      Self.dateFormatter.string(from: createdAt)
    }

    @Transient
    var formattedUpdatedAt: String {
      guard let updated = updatedAt else { return "—" }
      return Self.dateFormatter.string(from: updated)
    }

    @Transient
    var summary: String {
      var parts: [String] = ["\(icon) \(name)"]
      if let d = detail, !d.isEmpty {
        // allow multi-line detail
        parts.append(d)
      }
      parts.append("Tagged in \(appointmentCount) appt\(appointmentCount == 1 ? "" : "s")")
      return parts.joined(separator: " • ")
    }
    
    
    // MARK: – CRUD Helpers
    
    /// Creates and inserts a new BehaviorTag into the context.
    @discardableResult
    static func create(
        name: String,
        icon: String,
        detail: String? = nil,
        in context: ModelContext
    ) -> BehaviorTag {
        let tag = BehaviorTag(name: name, icon: icon, detail: detail)
        context.insert(tag)
        AuditLog.create(entity: "BehaviorTag", entityID: tag.id.uuidString, action: "create", in: context)
        return tag
    }
    
    /// Fetches all BehaviorTags sorted by name. Returns empty array on error.
    static func fetchAll(in context: ModelContext) -> [BehaviorTag] {
        logger.log("Fetching all BehaviorTag entries")
        let descriptor = FetchDescriptor<BehaviorTag>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [ SortDescriptor(\BehaviorTag.name, order: .forward) ]
        )
        do {
            let tags = try context.fetch(descriptor)
            logger.log("Fetched \(tags.count) BehaviorTag entries")
            return tags
        } catch {
            logger.error("BehaviorTag.fetchAll failed: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Fetches the first BehaviorTag matching the trimmed name, or nil on error.
    static func fetch(named name: String, in context: ModelContext) -> BehaviorTag? {
        logger.log("Fetching BehaviorTag named: \(name)")
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let descriptor = FetchDescriptor<BehaviorTag>(
            predicate: #Predicate { $0.name == trimmed && !$0.isArchived },
            sortBy: [ SortDescriptor(\BehaviorTag.createdAt, order: .reverse) ]
        )
        do {
            let results = try context.fetch(descriptor)
            if let tag = results.first {
                logger.log("Found BehaviorTag id: \(tag.id) for name: \(trimmed)")
            } else {
                logger.log("No BehaviorTag found for name: \(trimmed)")
            }
            return results.first
        } catch {
            logger.error("BehaviorTag.fetch(named:) failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    
    // MARK: – Update
    
    /// Updates the tag’s properties and sets updatedAt to now.
    func update(
        name: String,
        icon: String,
        detail: String?
    ) {
        logger.log("Updating BehaviorTag id: \(id)")
        self.name      = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.icon      = icon
        self.detail    = detail?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.updatedAt = Date.now
        logger.log("Updated BehaviorTag id: \(id) at \(updatedAt!)")
        AuditLog.create(entity: "BehaviorTag", entityID: id.uuidString, action: "update", in: context)
    }
    
    
    // MARK: – Tagging
    
    /// Tags the given appointment if not already tagged.
    func tag(_ appointment: Appointment) {
        logger.log("Tagging appointment \(appointment.id) with BehaviorTag id: \(id)")
        guard !appointments.contains(where: { $0.id == appointment.id }) else { return }
        appointments.append(appointment)
        AuditLog.create(entity: "BehaviorTag", entityID: id.uuidString, action: "tag", metadata: ["appointmentID": appointment.id.uuidString], in: context)
    }
    
    /// Removes the tag from the given appointment.
    func untag(_ appointment: Appointment) {
        logger.log("Untagging appointment \(appointment.id) from BehaviorTag id: \(id)")
        appointments.removeAll { $0.id == appointment.id }
        AuditLog.create(entity: "BehaviorTag", entityID: id.uuidString, action: "untag", metadata: ["appointmentID": appointment.id.uuidString], in: context)
    }
    
    /// Removes this tag from all associated appointments.
    func clearAllTags() {
        logger.log("Clearing all tags from BehaviorTag id: \(id)")
        appointments.removeAll()
        AuditLog.create(entity: "BehaviorTag", entityID: id.uuidString, action: "clearAll", in: context)
    }
    
    // MARK: – Presets
    
    static var calm: BehaviorTag {
        BehaviorTag(
            name: NSLocalizedString("Calm Pet", comment: ""),
            icon: "🟢",
            detail: NSLocalizedString("The pet remained calm during the session.", comment: "")
        )
    }
    
    static var aggressive: BehaviorTag {
        BehaviorTag(
            name: NSLocalizedString("Aggressive Behavior", comment: ""),
            icon: "🔴",
            detail: NSLocalizedString("The pet showed signs of aggression or biting.", comment: "")
        )
    }
    
    static var neutral: BehaviorTag {
        BehaviorTag(
            name: NSLocalizedString("Neutral Behavior", comment: ""),
            icon: "⚪️",
            detail: NSLocalizedString("Neither calm nor aggressive.", comment: "")
        )
    }
    
    
    // MARK: – Preview Samples
    
    #if DEBUG
    /// A small set of example tags for SwiftUI previews.
    static let samples: [BehaviorTag] = [
        .calm,
        .aggressive,
        .neutral
    ]
    #endif
    
    
    // MARK: – Hashable
    
    static func == (lhs: BehaviorTag, rhs: BehaviorTag) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    
}


#if DEBUG
import SwiftUI

// MARK: — SwiftUI Preview

struct BehaviorTag_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            ForEach(BehaviorTag.samples.filter { !$0.isArchived }, id: \.id) { tag in
                Text(tag.summary)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 8).stroke())
            }
        }
        .padding()
    }
}
#endif

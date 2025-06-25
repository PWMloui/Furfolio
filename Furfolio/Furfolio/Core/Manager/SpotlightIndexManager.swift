//
//  SpotlightIndexManager.swift
//  Furfolio
//
//  Enhanced & Unified for Grooming Business Management (Auditable, Tagged, Accessible)
//

import Foundation
import CoreSpotlight
import MobileCoreServices

// MARK: - SpotlightIndexManager (Unified, Modular, Tokenized, Auditable Spotlight Search Integration)

@MainActor
enum SpotlightIndexManager {
    // MARK: - Audit/Event Log

    struct SpotlightAuditEvent: Codable {
        let timestamp: Date
        let operation: String          // "index" | "remove" | "bulkIndex" | "bulkRemove" | "error"
        let entityType: String
        let entityId: String?
        let count: Int
        let tags: [String]
        let actor: String?
        let context: String?
        let status: String             // "success" | "error"
        let errorDescription: String?
        var accessibilityLabel: String {
            let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
            let idStr = entityId != nil ? " (\(entityId!))" : ""
            return "\(operation.capitalized) \(entityType)\(idStr) (\(status)) at \(dateStr)\(errorDescription == nil ? "" : ": \(errorDescription!)")"
        }
    }
    private(set) static var auditLog: [SpotlightAuditEvent] = []

    private static func logEvent(
        operation: String,
        entityType: String,
        entityId: String? = nil,
        count: Int = 1,
        tags: [String] = [],
        actor: String? = nil,
        context: String? = nil,
        status: String = "success",
        error: Error? = nil
    ) {
        let event = SpotlightAuditEvent(
            timestamp: Date(),
            operation: operation,
            entityType: entityType,
            entityId: entityId,
            count: count,
            tags: tags,
            actor: actor,
            context: context,
            status: status,
            errorDescription: error?.localizedDescription
        )
        auditLog.append(event)
        if auditLog.count > 1000 { auditLog.removeFirst() }
    }

    static func exportLastAuditEventJSON() -> String? {
        guard let last = auditLog.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    static var accessibilitySummary: String {
        auditLog.last?.accessibilityLabel ?? "No Spotlight events recorded."
    }

    // MARK: - Indexing (Async-Ready)

    static func indexOwner(_ owner: DogOwner, actor: String? = nil, context: String? = nil) {
        guard FeatureFlags.spotlightIndexing else { return }
        let attr = CSSearchableItemAttributeSet(itemContentType: kUTTypeContact as String)
        attr.title = owner.ownerName
        attr.contentDescription = "Dog Owner: \(owner.ownerName)\n\(owner.address ?? "")"
        attr.emailAddresses = owner.email == nil ? nil : [owner.email!]
        attr.phoneNumbers = owner.phone == nil ? nil : [owner.phone!]
        attr.identifier = owner.id.uuidString

        let item = CSSearchableItem(
            uniqueIdentifier: owner.id.uuidString,
            domainIdentifier: "com.furfolio.owner",
            attributeSet: attr
        )

        indexItems([item], logContext: "owner: \(owner.ownerName)", entityType: "DogOwner", ids: [owner.id.uuidString], actor: actor, context: context)
    }

    static func indexDog(_ dog: Dog, actor: String? = nil, context: String? = nil) {
        guard FeatureFlags.spotlightIndexing else { return }
        let attr = CSSearchableItemAttributeSet(itemContentType: kUTTypeText as String)
        attr.title = dog.name
        attr.contentDescription = "Dog: \(dog.name)\nBreed: \(dog.breed ?? "")"
        attr.keywords = [dog.breed, dog.owner?.ownerName].compactMap { $0 }
        attr.identifier = dog.id.uuidString

        let item = CSSearchableItem(
            uniqueIdentifier: dog.id.uuidString,
            domainIdentifier: "com.furfolio.dog",
            attributeSet: attr
        )

        indexItems([item], logContext: "dog: \(dog.name)", entityType: "Dog", ids: [dog.id.uuidString], actor: actor, context: context)
    }

    static func indexAppointment(_ appt: Appointment, actor: String? = nil, context: String? = nil) {
        guard FeatureFlags.spotlightIndexing else { return }
        let attr = CSSearchableItemAttributeSet(itemContentType: kUTTypeCalendarEvent as String)
        attr.title = "\(appt.dog?.name ?? "Dog") Appointment"
        attr.contentDescription = """
        Service: \(appt.serviceType.displayName)
        Date: \(DateUtils.fullDateTime(appt.date))
        """
        attr.startDate = appt.date
        attr.endDate = appt.date.addingTimeInterval(60*60)
        attr.keywords = [
            appt.dog?.name,
            appt.owner?.ownerName,
            appt.serviceType.displayName
        ].compactMap { $0 }
        attr.identifier = appt.id.uuidString

        let item = CSSearchableItem(
            uniqueIdentifier: appt.id.uuidString,
            domainIdentifier: "com.furfolio.appointment",
            attributeSet: attr
        )

        indexItems([item], logContext: "appointment: \(appt.dog?.name ?? "Dog")", entityType: "Appointment", ids: [appt.id.uuidString], actor: actor, context: context)
    }

    // MARK: - Async Batch Indexing

    static func bulkIndex(owners: [DogOwner], dogs: [Dog], appointments: [Appointment], actor: String? = nil, context: String? = nil) {
        guard FeatureFlags.spotlightIndexing else { return }
        var items: [CSSearchableItem] = []
        var ids: [String] = []
        for owner in owners {
            let attr = CSSearchableItemAttributeSet(itemContentType: kUTTypeContact as String)
            attr.title = owner.ownerName
            attr.contentDescription = "Dog Owner: \(owner.ownerName)\n\(owner.address ?? "")"
            attr.emailAddresses = owner.email == nil ? nil : [owner.email!]
            attr.phoneNumbers = owner.phone == nil ? nil : [owner.phone!]
            attr.identifier = owner.id.uuidString

            let item = CSSearchableItem(
                uniqueIdentifier: owner.id.uuidString,
                domainIdentifier: "com.furfolio.owner",
                attributeSet: attr
            )
            items.append(item)
            ids.append(owner.id.uuidString)
        }
        for dog in dogs {
            let attr = CSSearchableItemAttributeSet(itemContentType: kUTTypeText as String)
            attr.title = dog.name
            attr.contentDescription = "Dog: \(dog.name)\nBreed: \(dog.breed ?? "")"
            attr.keywords = [dog.breed, dog.owner?.ownerName].compactMap { $0 }
            attr.identifier = dog.id.uuidString

            let item = CSSearchableItem(
                uniqueIdentifier: dog.id.uuidString,
                domainIdentifier: "com.furfolio.dog",
                attributeSet: attr
            )
            items.append(item)
            ids.append(dog.id.uuidString)
        }
        for appt in appointments {
            let attr = CSSearchableItemAttributeSet(itemContentType: kUTTypeCalendarEvent as String)
            attr.title = "\(appt.dog?.name ?? "Dog") Appointment"
            attr.contentDescription = "Service: \(appt.serviceType.displayName)\nDate: \(DateUtils.fullDateTime(appt.date))"
            attr.startDate = appt.date
            attr.endDate = appt.date.addingTimeInterval(60*60)
            attr.keywords = [
                appt.dog?.name,
                appt.owner?.ownerName,
                appt.serviceType.displayName
            ].compactMap { $0 }
            attr.identifier = appt.id.uuidString

            let item = CSSearchableItem(
                uniqueIdentifier: appt.id.uuidString,
                domainIdentifier: "com.furfolio.appointment",
                attributeSet: attr
            )
            items.append(item)
            ids.append(appt.id.uuidString)
        }

        indexItems(items, logContext: "bulkIndex: \(items.count) items", entityType: "Bulk", ids: ids, actor: actor, context: context)
    }

    // MARK: - Core Indexing Helper
    private static func indexItems(
        _ items: [CSSearchableItem],
        logContext: String,
        entityType: String,
        ids: [String],
        actor: String?,
        context: String?
    ) {
        CSSearchableIndex.default().indexSearchableItems(items) { error in
            if let error = error {
                logEvent(
                    operation: "index",
                    entityType: entityType,
                    entityId: ids.count == 1 ? ids.first : nil,
                    count: items.count,
                    tags: [entityType.lowercased(), "spotlight"],
                    actor: actor,
                    context: context,
                    status: "error",
                    error: error
                )
                print("Spotlight index error (\(logContext)): \(error.localizedDescription)")
            } else {
                logEvent(
                    operation: "index",
                    entityType: entityType,
                    entityId: ids.count == 1 ? ids.first : nil,
                    count: items.count,
                    tags: [entityType.lowercased(), "spotlight"],
                    actor: actor,
                    context: context,
                    status: "success"
                )
                #if DEBUG
                print("Spotlight index success (\(logContext)): \(items.count) items.")
                #endif
            }
        }
    }

    // MARK: - Removal

    static func removeFromIndex(_ id: UUID, actor: String? = nil, context: String? = nil) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [id.uuidString]) { error in
            if let error = error {
                logEvent(
                    operation: "remove",
                    entityType: "Unknown",
                    entityId: id.uuidString,
                    count: 1,
                    tags: ["remove", "spotlight"],
                    actor: actor,
                    context: context,
                    status: "error",
                    error: error
                )
                print("Spotlight removal error: \(error.localizedDescription)")
            } else {
                logEvent(
                    operation: "remove",
                    entityType: "Unknown",
                    entityId: id.uuidString,
                    count: 1,
                    tags: ["remove", "spotlight"],
                    actor: actor,
                    context: context,
                    status: "success"
                )
            }
        }
    }

    static func removeAllFromIndex(actor: String? = nil, context: String? = nil) {
        CSSearchableIndex.default().deleteAllSearchableItems { error in
            if let error = error {
                logEvent(
                    operation: "bulkRemove",
                    entityType: "All",
                    entityId: nil,
                    count: 0,
                    tags: ["remove", "bulk", "spotlight"],
                    actor: actor,
                    context: context,
                    status: "error",
                    error: error
                )
                print("Spotlight bulk removal error: \(error.localizedDescription)")
            } else {
                logEvent(
                    operation: "bulkRemove",
                    entityType: "All",
                    entityId: nil,
                    count: 0,
                    tags: ["remove", "bulk", "spotlight"],
                    actor: actor,
                    context: context,
                    status: "success"
                )
            }
        }
    }

    // MARK: - TSP Route Index (Stub for Expansion)
    static func indexTSPRouteStops(_ stops: [GroomingStop], actor: String? = nil, context: String? = nil) {
        // Not yet implemented.
        // When implemented: logEvent for every stop, with "tspRoute" tag.
    }
}

// MARK: - Developer Feature Flags (Ready for expansion)
enum FeatureFlags {
    static let spotlightIndexing: Bool = true
}

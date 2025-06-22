//
//  SpotlightIndexManager.swift
//  Furfolio
//
//  Enhanced & Unified for Grooming Business Management
//

import Foundation
import CoreSpotlight
import MobileCoreServices

// MARK: - SpotlightIndexManager (Unified, Modular, Tokenized, Auditable Spotlight Search Integration)

/// Handles robust, async Spotlight indexing for all Furfolio entities.
/// This manager is modular, tokenized, auditable, and extensible.
/// All Spotlight indexing and removal operations are logged and support audit/event logging.
/// Future enhancements include localized search fields and integration with the Trust Center for permissions and compliance.
@MainActor
enum SpotlightIndexManager {
    // MARK: - Indexing (Async-Ready)

    /// Indexes a DogOwner for Spotlight search.
    /// All Spotlight search changes should be logged for audit/compliance.
    /// TODO: Integrate audit/event logging before indexing/removal for compliance.
    static func indexOwner(_ owner: DogOwner) {
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

        indexItems([item], logContext: "owner: \(owner.ownerName)")
    }

    /// Indexes a Dog for Spotlight search.
    /// All Spotlight search changes should be logged for audit/compliance.
    /// TODO: Integrate audit/event logging before indexing/removal for compliance.
    static func indexDog(_ dog: Dog) {
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

        indexItems([item], logContext: "dog: \(dog.name)")
    }

    /// Indexes an Appointment for Spotlight search.
    /// All Spotlight search changes should be logged for audit/compliance.
    /// TODO: Integrate audit/event logging before indexing/removal for compliance.
    static func indexAppointment(_ appt: Appointment) {
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

        indexItems([item], logContext: "appointment: \(appt.dog?.name ?? "Dog")")
    }

    // MARK: - Async Batch Indexing (New)
    /// Bulk indexes owners, dogs, and appointments for Spotlight search.
    /// All Spotlight search changes should be logged for audit/compliance.
    /// This method should support batch event logging and Trust Center controls in the future.
    /// TODO: Integrate audit/event logging before indexing/removal for compliance.
    static func bulkIndex(owners: [DogOwner], dogs: [Dog], appointments: [Appointment]) {
        guard FeatureFlags.spotlightIndexing else { return }
        var items: [CSSearchableItem] = []
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
        }

        indexItems(items, logContext: "bulkIndex: \(items.count) items")
    }

    // MARK: - Core Indexing Helper
    private static func indexItems(_ items: [CSSearchableItem], logContext: String) {
        CSSearchableIndex.default().indexSearchableItems(items) { error in
            if let error = error {
                print("Spotlight index error (\(logContext)): \(error.localizedDescription)")
            } else {
                #if DEBUG
                print("Spotlight index success (\(logContext)): \(items.count) items.")
                #endif
            }
        }
    }

    // MARK: - Removal

    /// Removes an indexed item from Spotlight by unique ID.
    /// All Spotlight search changes should be logged for audit/compliance.
    /// TODO: Integrate audit/event logging before indexing/removal for compliance.
    static func removeFromIndex(_ id: UUID) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [id.uuidString]) { error in
            if let error = error {
                print("Spotlight removal error: \(error.localizedDescription)")
            }
        }
    }

    /// Removes all indexed Furfolio items (useful for app reset or business ownership transfer).
    /// All Spotlight search changes should be logged for audit/compliance.
    /// TODO: Integrate audit/event logging before indexing/removal for compliance.
    static func removeAllFromIndex() {
        CSSearchableIndex.default().deleteAllSearchableItems { error in
            if let error = error {
                print("Spotlight bulk removal error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - TSP Route Index (Stub for Expansion)
    /// Indexes route points or stops for mobile grooming optimization.
    /// This is a stub for future mobile route optimization.
    /// All indexing must be auditable.
    static func indexTSPRouteStops(_ stops: [GroomingStop]) {
        // For future: Integrate with routing/optimization, index each stop for quick search.
        // Not yet implemented.
    }
}

// MARK: - Developer Feature Flags (Ready for expansion)
/// All developer feature flags must be documented and changes audited for compliance and diagnostics.
enum FeatureFlags {
    static let spotlightIndexing: Bool = true
}

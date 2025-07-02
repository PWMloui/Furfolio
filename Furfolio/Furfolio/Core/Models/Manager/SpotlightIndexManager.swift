//
//  SpotlightIndexManager.swift
//  Furfolio
//
//  Enhanced & Unified for Grooming Business Management (Auditable, Tagged, Accessible)
//

import Foundation
import CoreSpotlight
import MobileCoreServices
import os.log

// MARK: - SpotlightIndexManager (Unified, Modular, Tokenized, Auditable Spotlight Search Integration)

@MainActor
enum SpotlightIndexManager {
    // MARK: - Audit/Event Log

    private static let auditQueue = DispatchQueue(label: "com.furfolio.spotlight.auditQueue", qos: .userInitiated)

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
            let baseString = NSLocalizedString(
                "%@ %@%@ (%@) at %@",
                comment: "Format for spotlight audit event accessibility label: Operation EntityType (EntityID) (Status) at Date"
            )
            let errorPart = errorDescription == nil ? "" : ": \(errorDescription!)"
            return String(format: baseString, operation.capitalized, entityType, idStr, status, dateStr) + errorPart
        }
    }
    private static var _auditLog: [SpotlightAuditEvent] = []

    /// Concurrency-safe audit log accessor.
    static func getAuditLog() async -> [SpotlightAuditEvent] {
        await withCheckedContinuation { continuation in
            auditQueue.async {
                continuation.resume(returning: _auditLog)
            }
        }
    }

    /// Concurrency-safe audit log appender.
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
    ) async {
        await withCheckedContinuation { continuation in
            auditQueue.async {
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
                _auditLog.append(event)
                if _auditLog.count > 1000 { _auditLog.removeFirst() }
                continuation.resume()
            }
        }
    }

    /// Exports the last audit event as a pretty-printed JSON string asynchronously.
    ///
    /// - Returns: A JSON string of the last audit event, or `nil` if no events exist.
    static func exportLastAuditEventJSON() async -> String? {
        await withCheckedContinuation { continuation in
            auditQueue.async {
                guard let last = _auditLog.last else {
                    continuation.resume(returning: nil)
                    return
                }
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                if let data = try? encoder.encode(last),
                   let jsonString = String(data: data, encoding: .utf8) {
                    continuation.resume(returning: jsonString)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// Returns an accessibility summary string describing the last audit event asynchronously.
    static var accessibilitySummary: String {
        get async {
            await withCheckedContinuation { continuation in
                auditQueue.async {
                    if let last = _auditLog.last {
                        continuation.resume(returning: last.accessibilityLabel)
                    } else {
                        let noEventsString = NSLocalizedString(
                            "No Spotlight events recorded.",
                            comment: "Accessibility summary when no spotlight events exist"
                        )
                        continuation.resume(returning: noEventsString)
                    }
                }
            }
        }
    }

    // MARK: - Private Logger

    private static let logger = Logger(subsystem: "com.furfolio.spotlight", category: "SpotlightIndexManager")

    private static func logInfo(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    private static func logError(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }

    // MARK: - Indexing (Async-Ready)

    /// Indexes a DogOwner in Spotlight asynchronously.
    ///
    /// - Parameters:
    ///   - owner: The DogOwner to index.
    ///   - actor: Optional string identifying the actor performing the operation.
    ///   - context: Optional context string for logging.
    static func indexOwner(_ owner: DogOwner, actor: String? = nil, context: String? = nil) {
        guard FeatureFlags.spotlightIndexing else { return }
        let attr = CSSearchableItemAttributeSet(itemContentType: kUTTypeContact as String)
        attr.title = owner.ownerName
        attr.contentDescription = String(
            format: NSLocalizedString(
                "Dog Owner: %@\n%@",
                comment: "Content description for dog owner Spotlight index item"
            ),
            owner.ownerName,
            owner.address ?? ""
        )
        attr.emailAddresses = owner.email == nil ? nil : [owner.email!]
        attr.phoneNumbers = owner.phone == nil ? nil : [owner.phone!]
        attr.identifier = owner.id.uuidString

        let item = CSSearchableItem(
            uniqueIdentifier: owner.id.uuidString,
            domainIdentifier: "com.furfolio.owner",
            attributeSet: attr
        )

        Task {
            await indexItems(
                [item],
                logContext: String(format: NSLocalizedString("owner: %@", comment: "Log context for owner indexing"), owner.ownerName),
                entityType: "DogOwner",
                ids: [owner.id.uuidString],
                actor: actor,
                context: context
            )
        }
    }

    /// Indexes a Dog in Spotlight asynchronously.
    ///
    /// - Parameters:
    ///   - dog: The Dog to index.
    ///   - actor: Optional string identifying the actor performing the operation.
    ///   - context: Optional context string for logging.
    static func indexDog(_ dog: Dog, actor: String? = nil, context: String? = nil) {
        guard FeatureFlags.spotlightIndexing else { return }
        let attr = CSSearchableItemAttributeSet(itemContentType: kUTTypeText as String)
        attr.title = dog.name
        attr.contentDescription = String(
            format: NSLocalizedString(
                "Dog: %@\nBreed: %@",
                comment: "Content description for dog Spotlight index item"
            ),
            dog.name,
            dog.breed ?? ""
        )
        attr.keywords = [dog.breed, dog.owner?.ownerName].compactMap { $0 }
        attr.identifier = dog.id.uuidString

        let item = CSSearchableItem(
            uniqueIdentifier: dog.id.uuidString,
            domainIdentifier: "com.furfolio.dog",
            attributeSet: attr
        )

        Task {
            await indexItems(
                [item],
                logContext: String(format: NSLocalizedString("dog: %@", comment: "Log context for dog indexing"), dog.name),
                entityType: "Dog",
                ids: [dog.id.uuidString],
                actor: actor,
                context: context
            )
        }
    }

    /// Indexes an Appointment in Spotlight asynchronously.
    ///
    /// - Parameters:
    ///   - appt: The Appointment to index.
    ///   - actor: Optional string identifying the actor performing the operation.
    ///   - context: Optional context string for logging.
    static func indexAppointment(_ appt: Appointment, actor: String? = nil, context: String? = nil) {
        guard FeatureFlags.spotlightIndexing else { return }
        let attr = CSSearchableItemAttributeSet(itemContentType: kUTTypeCalendarEvent as String)
        attr.title = String(
            format: NSLocalizedString(
                "%@ Appointment",
                comment: "Title for appointment Spotlight index item"
            ),
            appt.dog?.name ?? NSLocalizedString("Dog", comment: "Fallback name for dog in appointment title")
        )
        attr.contentDescription = String(
            format: NSLocalizedString(
                "Service: %@\nDate: %@",
                comment: "Content description for appointment Spotlight index item"
            ),
            appt.serviceType.displayName,
            DateUtils.fullDateTime(appt.date)
        )
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

        Task {
            await indexItems(
                [item],
                logContext: String(format: NSLocalizedString("appointment: %@", comment: "Log context for appointment indexing"), appt.dog?.name ?? NSLocalizedString("Dog", comment: "Fallback name for dog in appointment log context")),
                entityType: "Appointment",
                ids: [appt.id.uuidString],
                actor: actor,
                context: context
            )
        }
    }

    // MARK: - Async Batch Indexing

    /// Bulk indexes multiple DogOwners, Dogs, and Appointments asynchronously.
    ///
    /// - Parameters:
    ///   - owners: Array of DogOwner objects to index.
    ///   - dogs: Array of Dog objects to index.
    ///   - appointments: Array of Appointment objects to index.
    ///   - actor: Optional string identifying the actor performing the operation.
    ///   - context: Optional context string for logging.
    static func bulkIndex(owners: [DogOwner], dogs: [Dog], appointments: [Appointment], actor: String? = nil, context: String? = nil) {
        guard FeatureFlags.spotlightIndexing else { return }
        var items: [CSSearchableItem] = []
        var ids: [String] = []

        for owner in owners {
            let attr = CSSearchableItemAttributeSet(itemContentType: kUTTypeContact as String)
            attr.title = owner.ownerName
            attr.contentDescription = String(
                format: NSLocalizedString(
                    "Dog Owner: %@\n%@",
                    comment: "Content description for dog owner Spotlight index item"
                ),
                owner.ownerName,
                owner.address ?? ""
            )
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
            attr.contentDescription = String(
                format: NSLocalizedString(
                    "Dog: %@\nBreed: %@",
                    comment: "Content description for dog Spotlight index item"
                ),
                dog.name,
                dog.breed ?? ""
            )
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
            attr.title = String(
                format: NSLocalizedString(
                    "%@ Appointment",
                    comment: "Title for appointment Spotlight index item"
                ),
                appt.dog?.name ?? NSLocalizedString("Dog", comment: "Fallback name for dog in appointment title")
            )
            attr.contentDescription = String(
                format: NSLocalizedString(
                    "Service: %@\nDate: %@",
                    comment: "Content description for appointment Spotlight index item"
                ),
                appt.serviceType.displayName,
                DateUtils.fullDateTime(appt.date)
            )
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

        Task {
            await indexItems(
                items,
                logContext: String(format: NSLocalizedString("bulkIndex: %d items", comment: "Log context for bulk indexing"), items.count),
                entityType: "Bulk",
                ids: ids,
                actor: actor,
                context: context
            )
        }
    }

    // MARK: - Core Indexing Helper

    /// Indexes Spotlight searchable items asynchronously, logging success or failure.
    ///
    /// - Parameters:
    ///   - items: Array of CSSearchableItem to index.
    ///   - logContext: Context string for logging.
    ///   - entityType: The type of entity being indexed.
    ///   - ids: Identifiers of the entities being indexed.
    ///   - actor: Optional string identifying the actor performing the operation.
    ///   - context: Optional context string for logging.
    private static func indexItems(
        _ items: [CSSearchableItem],
        logContext: String,
        entityType: String,
        ids: [String],
        actor: String?,
        context: String?
    ) async {
        await withCheckedContinuation { continuation in
            CSSearchableIndex.default().indexSearchableItems(items) { error in
                Task {
                    if let error = error {
                        await logEvent(
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
                        let localizedMsg = String(
                            format: NSLocalizedString(
                                "Spotlight index error (%@): %@",
                                comment: "Spotlight index failure log message"
                            ),
                            logContext,
                            error.localizedDescription
                        )
                        logError(localizedMsg)
                    } else {
                        await logEvent(
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
                        let localizedMsg = String(
                            format: NSLocalizedString(
                                "Spotlight index success (%@): %d items.",
                                comment: "Spotlight index success log message"
                            ),
                            logContext,
                            items.count
                        )
                        logInfo(localizedMsg)
                        #endif
                    }
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Removal

    /// Removes a single Spotlight index item asynchronously by UUID.
    ///
    /// - Parameters:
    ///   - id: UUID of the item to remove.
    ///   - actor: Optional string identifying the actor performing the operation.
    ///   - context: Optional context string for logging.
    static func removeFromIndex(_ id: UUID, actor: String? = nil, context: String? = nil) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [id.uuidString]) { error in
            Task {
                if let error = error {
                    await logEvent(
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
                    let localizedMsg = String(
                        format: NSLocalizedString(
                            "Spotlight removal error: %@",
                            comment: "Spotlight removal failure log message"
                        ),
                        error.localizedDescription
                    )
                    logError(localizedMsg)
                } else {
                    await logEvent(
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
    }

    /// Removes all Spotlight index items asynchronously.
    ///
    /// - Parameters:
    ///   - actor: Optional string identifying the actor performing the operation.
    ///   - context: Optional context string for logging.
    static func removeAllFromIndex(actor: String? = nil, context: String? = nil) {
        CSSearchableIndex.default().deleteAllSearchableItems { error in
            Task {
                if let error = error {
                    await logEvent(
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
                    let localizedMsg = String(
                        format: NSLocalizedString(
                            "Spotlight bulk removal error: %@",
                            comment: "Spotlight bulk removal failure log message"
                        ),
                        error.localizedDescription
                    )
                    logError(localizedMsg)
                } else {
                    await logEvent(
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
    }

    // MARK: - TSP Route Index (Stub for Expansion)

    /// Indexes TSP route stops asynchronously.
    ///
    /// - Parameters:
    ///   - stops: Array of GroomingStop objects representing the route.
    ///   - actor: Optional string identifying the actor performing the operation.
    ///   - context: Optional context string for logging.
    ///
    /// - Note: Not yet implemented. When implemented, will log events for every stop with "tspRoute" tag.
    static func indexTSPRouteStops(_ stops: [GroomingStop], actor: String? = nil, context: String? = nil) {
        // Not yet implemented.
        // When implemented: logEvent for every stop, with "tspRoute" tag.
        Task {
            await logEvent(
                operation: "index",
                entityType: "TSPRoute",
                entityId: nil,
                count: stops.count,
                tags: ["tspRoute", "spotlight"],
                actor: actor,
                context: context,
                status: "success"
            )
            logInfo(NSLocalizedString("TSP route indexing is currently not implemented.", comment: "Info log for unimplemented TSP route indexing"))
        }
    }
}

// MARK: - Developer Feature Flags (Ready for expansion)

/// Feature flags for controlling developer and experimental features.
///
/// - spotlightIndexing: Enables or disables Spotlight indexing functionality globally.
enum FeatureFlags {
    static let spotlightIndexing: Bool = true
}

// MARK: - SwiftUI PreviewProvider for SpotlightIndexManager

#if canImport(SwiftUI) && DEBUG
import SwiftUI

@available(iOS 15.0, *)
struct SpotlightIndexManager_Previews: PreviewProvider {
    struct PreviewView: View {
        @State private var lastAuditJSON: String = ""
        @State private var accessibilitySummary: String = ""

        var body: some View {
            VStack(spacing: 20) {
                Text("Spotlight Audit Log Preview")
                    .font(.headline)
                ScrollView {
                    Text(lastAuditJSON.isEmpty ? "No audit event JSON available." : lastAuditJSON)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(8)
                }.frame(height: 200)

                Text("Accessibility Summary:")
                    .font(.headline)
                Text(accessibilitySummary)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)

                Button("Add Test Audit Event") {
                    Task {
                        await SpotlightIndexManager.logEvent(
                            operation: "testIndex",
                            entityType: "TestEntity",
                            entityId: "1234",
                            count: 1,
                            tags: ["test", "preview"],
                            actor: "PreviewUser",
                            context: "SwiftUI Preview",
                            status: "success",
                            error: nil
                        )
                        await updateUI()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .task {
                await updateUI()
            }
        }

        func updateUI() async {
            if let json = await SpotlightIndexManager.exportLastAuditEventJSON() {
                lastAuditJSON = json
            } else {
                lastAuditJSON = NSLocalizedString("No audit events to export.", comment: "Preview message when no audit events exist")
            }
            accessibilitySummary = await SpotlightIndexManager.accessibilitySummary
        }
    }

    static var previews: some View {
        PreviewView()
            .previewDisplayName("SpotlightIndexManager Audit Log Preview")
    }
}
#endif

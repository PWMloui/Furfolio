//
//  VendorManager.swift
//  Furfolio
//
//  Refactored for unified business management, multi-platform, and advanced UX.
//  Enhanced 2025 by Senpai & ChatGPT
//

import Foundation
import Combine
import SwiftUI

// MARK: - VendorManager (Modular, Tokenized, Auditable Vendor Data Management)

// MARK: - Vendor Model

struct Vendor: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var contactInfo: String?
    var servicesProvided: [String]
    var notes: String?
    var lastTransactionDate: Date?

    init(
        id: UUID = UUID(),
        name: String,
        contactInfo: String? = nil,
        servicesProvided: [String] = [],
        notes: String? = nil,
        lastTransactionDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.contactInfo = contactInfo
        self.servicesProvided = servicesProvided
        self.notes = notes
        self.lastTransactionDate = lastTransactionDate
    }

    // Tagging for audit and BI
    var tags: [String] {
        var t = [NSLocalizedString("vendor_tag_vendor", comment: "Tag for vendor")]
        if (contactInfo?.contains("@") ?? false) { t.append(NSLocalizedString("vendor_tag_email", comment: "Tag for email contact")) }
        if servicesProvided.contains(where: { $0.localizedCaseInsensitiveContains("groom") }) { t.append(NSLocalizedString("vendor_tag_grooming", comment: "Tag for grooming service")) }
        if servicesProvided.count > 3 { t.append(NSLocalizedString("vendor_tag_multi_service", comment: "Tag for multi-service vendor")) }
        return t
    }
}

// MARK: - VendorManager

/**
 Manages vendor data for Furfolio business operations.

 This class provides asynchronous, concurrency-safe management of vendors and audit logs.

 - Concurrency Safety: Uses a private actor to serialize access to vendor list and audit log.
 - Async/Await: All mutating operations and audit logging are async functions.
 - Localization: All user-facing strings are localized via NSLocalizedString.
 - Audit Log: Maintains a capped audit log with async access and JSON export.
 - Publisher: Provides Combine publisher compatible with async streams for vendor list changes.

 Usage Example:

 ```swift
 let manager = VendorManager()
 
 // Adding a vendor asynchronously
 Task {
     let newVendor = Vendor(name: NSLocalizedString("example_vendor_name", comment: "Example vendor name"))
     await manager.addVendor(newVendor, actor: "User1", context: "UI Add")
 
     // Export last audit event JSON
     if let json = try? await manager.exportLastAuditEventJSON() {
         print(json)
     }
 }
 ```
 */
final class VendorManager: ObservableObject {

    // MARK: - VendorAuditEvent

    struct VendorAuditEvent: Codable {
        let timestamp: Date
        let operation: String         // "add", "remove", "update", "load", "save"
        let vendorId: UUID?
        let vendorName: String?
        let tags: [String]
        let actor: String?
        let context: String?
        let errorDescription: String?

        var accessibilityLabel: String {
            let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
            let vname = vendorName ?? ""
            let vpart = vname.isEmpty ? "" : " \"\(vname)\""
            let baseString = NSLocalizedString(
                "audit_event_accessibility_label",
                comment: "Format string for audit event accessibility label"
            )
            let errorPart = errorDescription == nil ? "" : ": \(errorDescription!)"
            return String(format: baseString, operation.capitalized, vpart, tags.joined(separator: ","), dateStr, errorPart)
        }
    }

    // MARK: - Private Actor for Concurrency Safety

    private actor Storage {
        var vendors: [Vendor] = []
        var auditLog: [VendorAuditEvent] = []

        func appendAuditEvent(_ event: VendorAuditEvent) {
            auditLog.append(event)
            if auditLog.count > 500 {
                auditLog.removeFirst(auditLog.count - 500)
            }
        }

        func addVendor(_ vendor: Vendor) {
            vendors.append(vendor)
        }

        func removeVendor(_ vendor: Vendor) {
            vendors.removeAll { $0.id == vendor.id }
        }

        func updateVendor(_ vendor: Vendor) {
            if let idx = vendors.firstIndex(where: { $0.id == vendor.id }) {
                vendors[idx] = vendor
            }
        }

        func findVendor(named name: String) -> Vendor? {
            vendors.first { $0.name.localizedCaseInsensitiveContains(name) }
        }

        func vendors(forService service: String) -> [Vendor] {
            vendors.filter { $0.servicesProvided.contains(where: { $0.localizedCaseInsensitiveContains(service) }) }
        }

        func mostRecentVendors(limit: Int) -> [Vendor] {
            vendors
                .sorted { ($0.lastTransactionDate ?? .distantPast) > ($1.lastTransactionDate ?? .distantPast) }
                .prefix(limit)
                .map { $0 }
        }

        func clearAuditLog() {
            auditLog.removeAll()
        }

        func getAuditLog() -> [VendorAuditEvent] {
            auditLog
        }

        func getVendors() -> [Vendor] {
            vendors
        }

        func lastAuditEvent() -> VendorAuditEvent? {
            auditLog.last
        }
    }

    private let storage = Storage()

    // MARK: - Published Vendors

    @Published private(set) var vendors: [Vendor] = []

    // MARK: - Combine Subject for Vendor Changes

    private let vendorSubject = PassthroughSubject<[Vendor], Never>()

    /// A Combine publisher that emits vendor list changes.
    var publisher: AnyPublisher<[Vendor], Never> {
        vendorSubject.eraseToAnyPublisher()
    }

    // MARK: - Audit Logging

    private func logEvent(
        operation: String,
        vendor: Vendor? = nil,
        tags: [String] = [],
        actor: String? = nil,
        context: String? = nil,
        error: Error? = nil
    ) async {
        let event = VendorAuditEvent(
            timestamp: Date(),
            operation: NSLocalizedString("audit_operation_\(operation)", comment: "Audit operation name"),
            vendorId: vendor?.id,
            vendorName: vendor?.name,
            tags: tags,
            actor: actor,
            context: context,
            errorDescription: error?.localizedDescription
        )
        await storage.appendAuditEvent(event)
    }

    // MARK: - Public Async Methods

    /**
     Adds a new vendor asynchronously.

     - Parameters:
       - vendor: The vendor to add.
       - actor: Optional actor performing the operation.
       - context: Optional context for the operation.
     */
    public func addVendor(_ vendor: Vendor, actor: String? = nil, context: String? = nil) async {
        await logEvent(operation: "add", vendor: vendor, tags: vendor.tags, actor: actor, context: context)
        await storage.addVendor(vendor)
        await updatePublishedVendors()
    }

    /**
     Removes a vendor asynchronously.

     - Parameters:
       - vendor: The vendor to remove.
       - actor: Optional actor performing the operation.
       - context: Optional context for the operation.
     */
    public func removeVendor(_ vendor: Vendor, actor: String? = nil, context: String? = nil) async {
        await logEvent(operation: "remove", vendor: vendor, tags: vendor.tags, actor: actor, context: context)
        await storage.removeVendor(vendor)
        await updatePublishedVendors()
    }

    /**
     Updates an existing vendor asynchronously.

     - Parameters:
       - vendor: The vendor to update.
       - actor: Optional actor performing the operation.
       - context: Optional context for the operation.
     */
    public func updateVendor(_ vendor: Vendor, actor: String? = nil, context: String? = nil) async {
        await logEvent(operation: "update", vendor: vendor, tags: vendor.tags, actor: actor, context: context)
        await storage.updateVendor(vendor)
        await updatePublishedVendors()
    }

    /**
     Finds a vendor by name asynchronously (fuzzy/case-insensitive).

     - Parameter name: The name to search for.
     - Returns: The first matching vendor or nil.
     */
    public func vendor(named name: String) async -> Vendor? {
        await storage.findVendor(named: name)
    }

    /**
     Retrieves vendors providing a specific service asynchronously.

     - Parameter service: The service name to filter by.
     - Returns: Array of matching vendors.
     */
    public func vendors(forService service: String) async -> [Vendor] {
        await storage.vendors(forService: service)
    }

    /**
     Retrieves the most recent vendors asynchronously.

     - Parameter limit: The maximum number of vendors to return.
     - Returns: Array of most recent vendors.
     */
    public func mostRecentVendors(limit: Int = 5) async -> [Vendor] {
        await storage.mostRecentVendors(limit: limit)
    }

    /**
     Loads vendor data asynchronously.

     - Parameters:
       - actor: Optional actor performing the operation.
       - context: Optional context for the operation.
       - completion: Completion handler called after load.
     */
    public func load(actor: String? = nil, context: String? = nil, completion: @escaping () -> Void = {}) async {
        await logEvent(operation: "load", tags: [NSLocalizedString("audit_tag_load", comment: "Load tag")], actor: actor, context: context)
        // Placeholder: Load vendors from persistent storage here.
        // For now, just call completion.
        completion()
    }

    /**
     Saves vendor data asynchronously.

     - Parameters:
       - actor: Optional actor performing the operation.
       - context: Optional context for the operation.
       - completion: Completion handler called after save.
     */
    public func save(actor: String? = nil, context: String? = nil, completion: @escaping () -> Void = {}) async {
        await logEvent(operation: "save", tags: [NSLocalizedString("audit_tag_save", comment: "Save tag")], actor: actor, context: context)
        // Placeholder: Save vendors to persistent storage here.
        completion()
    }

    /**
     Exports the last audit event as a JSON string asynchronously.

     - Throws: An error if JSON encoding fails.
     - Returns: JSON string of the last audit event or nil if none.
     */
    public func exportLastAuditEventJSON() async throws -> String? {
        guard let last = await storage.lastAuditEvent() else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        do {
            let data = try encoder.encode(last)
            return String(data: data, encoding: .utf8)
        } catch {
            throw error
        }
    }

    /**
     Asynchronously clears the audit log.
     */
    public func clearAuditLog() async {
        await storage.clearAuditLog()
    }

    /**
     Asynchronously retrieves the accessibility summary string for the last audit event.

     - Returns: Localized accessibility summary string.
     */
    public var accessibilitySummary: String {
        get async {
            if let last = await storage.lastAuditEvent() {
                return last.accessibilityLabel
            } else {
                return NSLocalizedString("accessibility_no_vendor_events", comment: "No vendor events recorded")
            }
        }
    }

    // MARK: - Private Helpers

    private func updatePublishedVendors() async {
        let currentVendors = await storage.getVendors()
        // Update on main thread for UI
        await MainActor.run {
            self.vendors = currentVendors
            self.vendorSubject.send(currentVendors)
        }
    }
}

// MARK: - Example/Test Data

#if DEBUG
extension VendorManager {
    static var example: VendorManager {
        let manager = VendorManager()
        Task {
            await manager.addVendor(
                Vendor(
                    name: NSLocalizedString("example_vendor_grooming_supplies", comment: "Example vendor name"),
                    contactInfo: NSLocalizedString("example_vendor_grooming_contact", comment: "Example vendor contact"),
                    servicesProvided: [
                        NSLocalizedString("service_shampoo", comment: "Service name"),
                        NSLocalizedString("service_scissors", comment: "Service name"),
                        NSLocalizedString("service_clipper_blades", comment: "Service name")
                    ],
                    notes: NSLocalizedString("example_vendor_grooming_notes", comment: "Example vendor notes"),
                    lastTransactionDate: Date().addingTimeInterval(-86400 * 5)
                ),
                actor: "Debug",
                context: "Example Data Setup"
            )
            await manager.addVendor(
                Vendor(
                    name: NSLocalizedString("example_vendor_pet_towels", comment: "Example vendor name"),
                    contactInfo: NSLocalizedString("example_vendor_pet_towels_contact", comment: "Example vendor contact"),
                    servicesProvided: [
                        NSLocalizedString("service_towels", comment: "Service name"),
                        NSLocalizedString("service_bathrobes", comment: "Service name")
                    ],
                    notes: NSLocalizedString("example_vendor_pet_towels_notes", comment: "Example vendor notes"),
                    lastTransactionDate: Date().addingTimeInterval(-86400 * 10)
                ),
                actor: "Debug",
                context: "Example Data Setup"
            )
        }
        return manager
    }
}
#endif

// MARK: - SwiftUI PreviewProvider with Async Demonstrations

#if DEBUG
import SwiftUI

struct VendorManagerPreviewView: View {
    @StateObject private var manager = VendorManager.example
    @State private var auditJSON: String = ""
    @State private var accessibilitySummary: String = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Vendors:")
                .font(.headline)
            List(manager.vendors) { vendor in
                VStack(alignment: .leading) {
                    Text(vendor.name)
                        .font(.subheadline)
                    Text(vendor.contactInfo ?? "")
                        .font(.caption)
                }
            }
            Button(NSLocalizedString("button_add_vendor", comment: "Add vendor button")) {
                Task {
                    let newVendor = Vendor(
                        name: NSLocalizedString("example_vendor_new", comment: "New vendor name"),
                        contactInfo: NSLocalizedString("example_vendor_new_contact", comment: "New vendor contact"),
                        servicesProvided: [NSLocalizedString("service_new_service", comment: "New service")],
                        notes: NSLocalizedString("example_vendor_new_notes", comment: "New vendor notes"),
                        lastTransactionDate: Date()
                    )
                    await manager.addVendor(newVendor, actor: "Preview", context: "Add button")
                    await updateAccessibilitySummary()
                }
            }
            Button(NSLocalizedString("button_update_first_vendor", comment: "Update first vendor button")) {
                Task {
                    if var first = manager.vendors.first {
                        first.notes = NSLocalizedString("example_vendor_updated_notes", comment: "Updated vendor notes")
                        await manager.updateVendor(first, actor: "Preview", context: "Update button")
                        await updateAccessibilitySummary()
                    }
                }
            }
            Button(NSLocalizedString("button_remove_last_vendor", comment: "Remove last vendor button")) {
                Task {
                    if let last = manager.vendors.last {
                        await manager.removeVendor(last, actor: "Preview", context: "Remove button")
                        await updateAccessibilitySummary()
                    }
                }
            }
            Button(NSLocalizedString("button_export_audit", comment: "Export audit button")) {
                Task {
                    do {
                        if let json = try await manager.exportLastAuditEventJSON() {
                            auditJSON = json
                        } else {
                            auditJSON = NSLocalizedString("audit_export_no_events", comment: "No audit events to export")
                        }
                    } catch {
                        auditJSON = String(format: NSLocalizedString("audit_export_error", comment: "Audit export error"), error.localizedDescription)
                    }
                }
            }
            ScrollView {
                Text(auditJSON)
                    .font(.caption)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
            }
            Text(accessibilitySummary)
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding()
        }
        .padding()
        .task {
            await updateAccessibilitySummary()
        }
    }

    private func updateAccessibilitySummary() async {
        accessibilitySummary = await manager.accessibilitySummary
    }
}

struct VendorManager_Previews: PreviewProvider {
    static var previews: some View {
        VendorManagerPreviewView()
    }
}
#endif

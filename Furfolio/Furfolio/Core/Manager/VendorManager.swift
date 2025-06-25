//
//  VendorManager.swift
//  Furfolio
//
//  Refactored for unified business management, multi-platform, and advanced UX.
//  Enhanced 2025 by Senpai & ChatGPT
//

import Foundation
import Combine

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
        var t = ["vendor"]
        if (contactInfo?.contains("@") ?? false) { t.append("email") }
        if servicesProvided.contains(where: { $0.localizedCaseInsensitiveContains("groom") }) { t.append("grooming") }
        if servicesProvided.count > 3 { t.append("multi-service") }
        return t
    }
}

// MARK: - VendorManager
/**
 Manages vendor data for Furfolio business operations.
 
 - Modular: Designed for easy integration, extension, and separation of vendor logic.
 - Tokenized: Vendor data is structured for integration with design systems (badges, icons, colors, etc.).
 - Auditable: All vendor data operations now have audit/event logging for compliance.
 - Privacy & Localization: Ready for implementation of owner/staff privacy controls and localization/internationalization.
 
 Thread-safe, offline-ready, and scalable for future multi-user roles.
*/
final class VendorManager: ObservableObject {
    @Published private(set) var vendors: [Vendor] = []

    // For thread safety in multi-user or async environments
    private let queue = DispatchQueue(label: "com.furfolio.vendormanager.queue", attributes: .concurrent)

    // For change broadcasting to multiple modules if needed
    private let vendorSubject = PassthroughSubject<[Vendor], Never>()

    // MARK: - Audit/Event Log

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
            return "\(operation.capitalized)\(vpart) (\(tags.joined(separator: ","))) at \(dateStr)\(errorDescription == nil ? "" : ": \(errorDescription!)")"
        }
    }
    private(set) static var auditLog: [VendorAuditEvent] = []

    private func logEvent(
        operation: String,
        vendor: Vendor? = nil,
        tags: [String] = [],
        actor: String? = nil,
        context: String? = nil,
        error: Error? = nil
    ) {
        let event = VendorAuditEvent(
            timestamp: Date(),
            operation: operation,
            vendorId: vendor?.id,
            vendorName: vendor?.name,
            tags: tags,
            actor: actor,
            context: context,
            errorDescription: error?.localizedDescription
        )
        Self.auditLog.append(event)
        if Self.auditLog.count > 500 { Self.auditLog.removeFirst() }
    }

    static func exportLastAuditEventJSON() -> String? {
        guard let last = auditLog.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    var accessibilitySummary: String {
        Self.auditLog.last?.accessibilityLabel ?? "No vendor events recorded."
    }

    // MARK: - Add Vendor
    func addVendor(_ vendor: Vendor, actor: String? = nil, context: String? = nil) {
        logEvent(operation: "add", vendor: vendor, tags: vendor.tags, actor: actor, context: context)
        queue.async(flags: .barrier) {
            var newList = self.vendors
            newList.append(vendor)
            DispatchQueue.main.async {
                self.vendors = newList
                self.vendorSubject.send(newList)
            }
        }
    }

    // MARK: - Remove Vendor
    func removeVendor(_ vendor: Vendor, actor: String? = nil, context: String? = nil) {
        logEvent(operation: "remove", vendor: vendor, tags: vendor.tags, actor: actor, context: context)
        queue.async(flags: .barrier) {
            let newList = self.vendors.filter { $0.id != vendor.id }
            DispatchQueue.main.async {
                self.vendors = newList
                self.vendorSubject.send(newList)
            }
        }
    }

    // MARK: - Update Vendor
    func updateVendor(_ vendor: Vendor, actor: String? = nil, context: String? = nil) {
        logEvent(operation: "update", vendor: vendor, tags: vendor.tags, actor: actor, context: context)
        queue.async(flags: .barrier) {
            guard let idx = self.vendors.firstIndex(where: { $0.id == vendor.id }) else { return }
            var newList = self.vendors
            newList[idx] = vendor
            DispatchQueue.main.async {
                self.vendors = newList
                self.vendorSubject.send(newList)
            }
        }
    }

    // MARK: - Find Vendor by Name (Fuzzy/Case-insensitive)
    func vendor(named name: String) -> Vendor? {
        queue.sync {
            vendors.first { $0.name.localizedCaseInsensitiveContains(name) }
        }
    }

    // MARK: - Vendors for Service
    func vendors(forService service: String) -> [Vendor] {
        queue.sync {
            vendors.filter { $0.servicesProvided.contains(where: { $0.localizedCaseInsensitiveContains(service) }) }
        }
    }

    // MARK: - Most Recent Vendors
    func mostRecentVendors(limit: Int = 5) -> [Vendor] {
        queue.sync {
            vendors
                .sorted { ($0.lastTransactionDate ?? .distantPast) > ($1.lastTransactionDate ?? .distantPast) }
                .prefix(limit)
                .map { $0 }
        }
    }

    // MARK: - Load & Save (Async-Ready for Future SwiftData/Cloud/Offline)
    func load(actor: String? = nil, context: String? = nil, completion: @escaping () -> Void = {}) {
        logEvent(operation: "load", tags: ["load"], actor: actor, context: context)
        queue.async(flags: .barrier) {
            // Placeholder: Load vendors from persistent storage.
            DispatchQueue.main.async {
                // self.vendors = loadedVendors
                completion()
            }
        }
    }

    func save(actor: String? = nil, context: String? = nil, completion: @escaping () -> Void = {}) {
        logEvent(operation: "save", tags: ["save"], actor: actor, context: context)
        queue.async(flags: .barrier) {
            // Placeholder: Save vendors to persistent storage.
            DispatchQueue.main.async {
                completion()
            }
        }
    }

    // MARK: - Change Publisher (for cross-module/business updates)
    var publisher: AnyPublisher<[Vendor], Never> {
        vendorSubject.eraseToAnyPublisher()
    }
}

// MARK: - Example/Test Data
#if DEBUG
extension VendorManager {
    static var example: VendorManager {
        let manager = VendorManager()
        manager.vendors = [
            Vendor(
                name: "Grooming Supplies Co.",
                contactInfo: "555-123-4567",
                servicesProvided: ["Shampoo", "Scissors", "Clipper Blades"],
                notes: "Reliable delivery, call for bulk discount.",
                lastTransactionDate: Date().addingTimeInterval(-86400 * 5)
            ),
            Vendor(
                name: "Pet Towels Ltd.",
                contactInfo: "info@pettowels.com",
                servicesProvided: ["Towels", "Bathrobes"],
                notes: "Email monthly for new deals.",
                lastTransactionDate: Date().addingTimeInterval(-86400 * 10)
            )
        ]
        return manager
    }
}
#endif

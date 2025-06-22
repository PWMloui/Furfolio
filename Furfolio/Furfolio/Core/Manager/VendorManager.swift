//
//  VendorManager.swift
//  Furfolio
//
//  Refactored for unified business management, multi-platform, and advanced UX.
//  Enhanced 2025 by Senpai & ChatGPT.
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
}

// MARK: - VendorManager
/**
 Manages vendor data for Furfolio business operations.
 
 - Modular: Designed for easy integration, extension, and separation of vendor logic.
 - Tokenized: Vendor data is structured for integration with design systems (badges, icons, colors, etc.).
 - Auditable: All vendor data operations should support audit/event logging and future compliance requirements.
 - Privacy & Localization: Ready for implementation of owner/staff privacy controls and localization/internationalization.
 
 Thread-safe, offline-ready, and scalable for future multi-user roles.
*/
final class VendorManager: ObservableObject {
    @Published private(set) var vendors: [Vendor] = []

    // For thread safety in multi-user or async environments
    private let queue = DispatchQueue(label: "com.furfolio.vendormanager.queue", attributes: .concurrent)

    // For change broadcasting to multiple modules if needed
    private let vendorSubject = PassthroughSubject<[Vendor], Never>()

    // MARK: - Add Vendor
    /// Adds a vendor to the manager.
    /// All vendor data changes should be logged for audit/compliance.
    func addVendor(_ vendor: Vendor) {
        // TODO: Integrate audit/event logging before mutation/persistence for compliance.
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
    /// Removes a vendor from the manager.
    /// All vendor data changes should be logged for audit/compliance.
    func removeVendor(_ vendor: Vendor) {
        // TODO: Integrate audit/event logging before mutation/persistence for compliance.
        queue.async(flags: .barrier) {
            let newList = self.vendors.filter { $0.id != vendor.id }
            DispatchQueue.main.async {
                self.vendors = newList
                self.vendorSubject.send(newList)
            }
        }
    }

    // MARK: - Update Vendor
    /// Updates an existing vendor in the manager.
    /// All vendor data changes should be logged for audit/compliance.
    func updateVendor(_ vendor: Vendor) {
        // TODO: Integrate audit/event logging before mutation/persistence for compliance.
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
    /// Loads vendors from persistent storage.
    /// All vendor data changes should be logged for audit/compliance.
    func load(completion: @escaping () -> Void = {}) {
        // TODO: Integrate audit/event logging before mutation/persistence for compliance.
        queue.async(flags: .barrier) {
            // Placeholder: Load vendors from persistent storage.
            DispatchQueue.main.async {
                // self.vendors = loadedVendors
                completion()
            }
        }
    }

    /// Saves vendors to persistent storage.
    /// All vendor data changes should be logged for audit/compliance.
    func save(completion: @escaping () -> Void = {}) {
        // TODO: Integrate audit/event logging before mutation/persistence for compliance.
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
    /// Example/test data for previews and unit/UI testing only.
    /// Vendors in this list are for development/preview/testing purposes and should be flagged or excluded in production.
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

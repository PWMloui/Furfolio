//
//  WishlistItem.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import Foundation
import SwiftUI
import SwiftData

/**
 Model representing a user wishlist item in Furfolio.

 This model is designed with a focus on modern architecture and concurrency,
 supporting audit logging for changes, and is ready for analytics integration.
 It includes comprehensive diagnostics, localization, and accessibility considerations.
 The model is also testable and previewable in SwiftUI.

 - Architecture: Uses value semantics with a struct, and an actor for audit management
   to ensure thread-safe concurrency.
 - Concurrency: Asynchronous audit logging methods utilize Swift concurrency features.
 - Audit/Analytics: Maintains an audit log of changes with timestamps and export capability.
 - Diagnostics: Provides detailed timestamps and formatted date strings for UI and logging.
 - Localization: User-facing strings are localized using NSLocalizedString.
 - Accessibility: Display properties are designed to be clear and localizable.
 - Preview/Testability: Includes SwiftUI previews with sample data and interactive buttons.
 */
@Model public struct WishlistItem: Identifiable {
    /// Unique identifier for the wishlist item.
    @Attribute(.unique) public var id: UUID
    
    /// Name of the wishlist item.
    public var name: String
    
    /// Optional vendor identifier associated with this item.
    public var vendorID: UUID?
    
    /// Optional price of the item.
    public var price: Double?
    
    /// Optional notes about the item.
    public var notes: String?
    
    /// Flag indicating if the item has been purchased.
    public var isPurchased: Bool
    
    /// Date when the item was added to the wishlist.
    public var addedAt: Date
    
    /// Optional date when the item was purchased.
    public var purchasedAt: Date?
    
    /// Timestamp when the item was created.
    public let createdAt: Date
    
    /// Timestamp of the last update to the item.
    public var updatedAt: Date
    
    /// Localized display name for UI purposes.
    @Attribute(.transient) public var displayName: String {
        NSLocalizedString(name, comment: "Wishlist item name")
    }
    
    /// Formatted string representing the date the item was added.
    @Attribute(.transient) public var formattedAddedAt: String {
        DateFormatter.localizedString(from: addedAt, dateStyle: .medium, timeStyle: .short)
    }
    
    /// Formatted string representing the date the item was purchased, or empty string if not purchased.
    @Attribute(.transient) public var formattedPurchasedAt: String {
        guard let purchasedAt = purchasedAt else { return "" }
        return DateFormatter.localizedString(from: purchasedAt, dateStyle: .medium, timeStyle: .short)
    }
    
    /**
     Initializes a new WishlistItem.
     
     - Parameters:
       - name: The name of the item.
       - vendorID: Optional vendor UUID.
       - price: Optional price.
       - notes: Optional notes.
       - isPurchased: Whether the item is purchased (default false).
       - addedAt: Date the item was added (default now).
     */
    public init(
        id: UUID = UUID(),
        name: String,
        vendorID: UUID? = nil,
        price: Double? = nil,
        notes: String? = nil,
        isPurchased: Bool = false,
        addedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.vendorID = vendorID
        self.price = price
        self.notes = notes
        self.isPurchased = isPurchased
        self.addedAt = addedAt
        self.purchasedAt = nil
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }
    
    /**
     Adds an audit entry describing a change or event related to this item.
     
     - Parameter entry: The description of the audit event.
     */
    public func addAudit(_ entry: String) async {
        let localizedEntry = NSLocalizedString(entry, comment: "Audit log entry")
        await WishlistItemAuditManager.shared.add(itemID: id, entry: localizedEntry)
    }
    
    /**
     Retrieves recent audit entries for this item.
     
     - Parameter limit: Maximum number of entries to retrieve (default 20).
     - Returns: An array of recent audit entries.
     */
    public func recentAuditEntries(limit: Int = 20) async -> [WishlistItemAuditEntry] {
        await WishlistItemAuditManager.shared.recent(itemID: id, limit: limit)
    }
    
    /**
     Exports the audit log for this item as a JSON string.
     
     - Returns: JSON string representing the audit log.
     */
    public func exportAuditLogJSON() async -> String {
        await WishlistItemAuditManager.shared.exportJSON(itemID: id)
    }
    
    /**
     Marks the item as purchased, updates timestamps, and logs the event.
     */
    public mutating func markPurchased() async {
        guard !isPurchased else { return }
        isPurchased = true
        let now = Date()
        purchasedAt = now
        updatedAt = now
        await addAudit("Purchased")
    }
}

/**
 Represents a single audit log entry for a WishlistItem.
 */
@Model public struct WishlistItemAuditEntry: Identifiable {
    /// Unique identifier for the audit entry.
    @Attribute(.unique) public var id: UUID
    
    /// Timestamp when the audit entry was created.
    public let timestamp: Date
    
    /// Description of the audit event.
    public let entry: String
    
    /**
     Initializes a new audit entry.
     
     - Parameters:
       - id: Unique identifier for the entry.
       - timestamp: Timestamp of the entry.
       - entry: Description of the audit event.
     */
    public init(id: UUID = UUID(), timestamp: Date = Date(), entry: String) {
        self.id = id
        self.timestamp = timestamp
        self.entry = entry
    }
}

/**
 Actor responsible for managing audit logs for WishlistItems in a thread-safe manner.
 */
public actor WishlistItemAuditManager {
    /// Shared singleton instance.
    public static let shared = WishlistItemAuditManager()
    
    /// Maximum number of audit entries to keep per item.
    private let maxEntries = 100
    
    /// Buffer storing audit entries keyed by WishlistItem id.
    private var auditBuffer: [UUID: [WishlistItemAuditEntry]] = [:]
    
    private init() {}
    
    /**
     Adds a new audit entry for the specified item.
     
     - Parameters:
       - itemID: The UUID of the wishlist item.
       - entry: The audit entry description.
     */
    public func add(itemID: UUID, entry: String) {
        let auditEntry = WishlistItemAuditEntry(entry: entry)
        var entries = auditBuffer[itemID] ?? []
        entries.append(auditEntry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        auditBuffer[itemID] = entries
    }
    
    /**
     Retrieves recent audit entries for the specified item.
     
     - Parameters:
       - itemID: The UUID of the wishlist item.
       - limit: Maximum number of entries to retrieve.
     - Returns: Array of audit entries, newest first.
     */
    public func recent(itemID: UUID, limit: Int) -> [WishlistItemAuditEntry] {
        let entries = auditBuffer[itemID] ?? []
        return Array(entries.suffix(limit).reversed())
    }
    
    /**
     Exports the audit log for the specified item as a JSON string.
     
     - Parameter itemID: The UUID of the wishlist item.
     - Returns: JSON string representation of the audit entries, or empty string on failure.
     */
    public func exportJSON(itemID: UUID) -> String {
        guard let entries = auditBuffer[itemID] else { return "" }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(entries)
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
}

#if DEBUG
struct WishlistItem_Previews: PreviewProvider {
    struct PreviewView: View {
        @State private var item = WishlistItem(
            name: "Vintage Leather Jacket",
            vendorID: UUID(),
            price: 249.99,
            notes: "Check size and condition",
            isPurchased: false
        )
        
        @State private var auditEntries: [WishlistItemAuditEntry] = []
        
        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                Text("Wishlist Item Preview")
                    .font(.title)
                    .bold()
                
                Text("Name: \(item.displayName)")
                Text("Price: \(item.price.map { String(format: "$%.2f", $0) } ?? NSLocalizedString("N/A", comment: "No price"))")
                Text("Added At: \(item.formattedAddedAt)")
                if item.isPurchased {
                    Text("Purchased At: \(item.formattedPurchasedAt)")
                } else {
                    Button {
                        Task {
                            await item.markPurchased()
                            auditEntries = await item.recentAuditEntries()
                        }
                    } label: {
                        Text(NSLocalizedString("Mark as Purchased", comment: "Button to mark item purchased"))
                    }
                }
                
                Divider()
                
                Text("Recent Audit Entries:")
                    .font(.headline)
                List(auditEntries) { entry in
                    VStack(alignment: .leading) {
                        Text(entry.entry)
                        Text(DateFormatter.localizedString(from: entry.timestamp, dateStyle: .short, timeStyle: .short))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .task {
                auditEntries = await item.recentAuditEntries()
            }
        }
    }
    
    static var previews: some View {
        PreviewView()
    }
}
#endif

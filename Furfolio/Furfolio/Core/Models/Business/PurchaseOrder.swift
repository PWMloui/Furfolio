
//
//  PurchaseOrder.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import Foundation
import SwiftUI
import SwiftData

/// Represents a line item in a purchase order.
@Model public
struct PurchaseOrderItem: Identifiable, Hashable {
    /// Unique identifier for the line item.
    @Attribute(.unique)
    let id: UUID
    /// The product identifier for the item.
    let productID: UUID
    /// Quantity of the product ordered.
    var quantity: Int
    /// Unit price of the product at the time of order.
    var unitPrice: Double
    /// Total price for this line item (quantity * unitPrice).
    @Attribute(.transient)
    var totalPrice: Double {
        Double(quantity) * unitPrice
    }
    
    /// Initializes a new purchase order item.
    /// - Parameters:
    ///   - productID: The product identifier.
    ///   - quantity: Quantity of the product.
    ///   - unitPrice: Unit price for the product.
    init(id: UUID = UUID(), productID: UUID, quantity: Int, unitPrice: Double) {
        self.id = id
        self.productID = productID
        self.quantity = quantity
        self.unitPrice = unitPrice
    }
}

/// Represents the status of a purchase order.
enum PurchaseOrderStatus: String, Codable, CaseIterable, Identifiable {
    case pending
    case confirmed
    case shipped
    case delivered
    case cancelled
    
    /// Localized display string for the status.
    var localizedDisplay: String {
        switch self {
        case .pending:
            return NSLocalizedString("Pending", comment: "Purchase order status: pending")
        case .confirmed:
            return NSLocalizedString("Confirmed", comment: "Purchase order status: confirmed")
        case .shipped:
            return NSLocalizedString("Shipped", comment: "Purchase order status: shipped")
        case .delivered:
            return NSLocalizedString("Delivered", comment: "Purchase order status: delivered")
        case .cancelled:
            return NSLocalizedString("Cancelled", comment: "Purchase order status: cancelled")
        }
    }
    
    /// Unique identifier for Identifiable conformance.
    var id: String { rawValue }
}

/// Represents a purchase order in Furfolio.
@Model public
struct PurchaseOrder: Identifiable, Hashable {
    /// The unique identifier for this purchase order.
    @Attribute(.unique)
    let id: UUID
    /// Unique purchase order number.
    var orderNumber: String
    /// The vendor's UUID associated with this order.
    var vendorID: UUID?
    /// Date the order was placed.
    var orderDate: Date
    /// The expected delivery date for the order.
    var expectedDeliveryDate: Date?
    /// Array of line items in the order.
    var items: [PurchaseOrderItem]
    /// The total monetary amount for the order (computed).
    @Attribute(.transient)
    var totalAmount: Double {
        items.reduce(0) { $0 + $1.totalPrice }
    }
    /// The current status of the purchase order.
    var status: PurchaseOrderStatus
    /// Optional notes for additional information.
    var notes: String?
    /// The date when the order was created.
    var createdAt: Date
    /// The date when the order was last updated.
    var updatedAt: Date
    
    // MARK: - Computed Properties
    
    /// Returns a formatted string for the order date.
    @Attribute(.transient)
    var formattedOrderDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: orderDate)
    }
    
    /// Returns a formatted string for the expected delivery date.
    @Attribute(.transient)
    var formattedExpectedDeliveryDate: String? {
        guard let date = expectedDeliveryDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    /// Returns a localized display string for the current status.
    @Attribute(.transient)
    var statusDisplay: String {
        status.localizedDisplay
    }
    
    // MARK: - Initializers
    
    /// Initializes a new purchase order.
    /// - Parameters:
    ///   - id: Unique identifier (default: new UUID).
    ///   - orderNumber: Unique order number.
    ///   - vendorID: Associated vendor's UUID.
    ///   - orderDate: Date of order.
    ///   - expectedDeliveryDate: Optional expected delivery date.
    ///   - items: Array of order line items.
    ///   - status: Current status of the order.
    ///   - notes: Optional notes.
    ///   - createdAt: Creation date (default: now).
    ///   - updatedAt: Last update date (default: now).
    init(
        id: UUID = UUID(),
        orderNumber: String,
        vendorID: UUID?,
        orderDate: Date,
        expectedDeliveryDate: Date? = nil,
        items: [PurchaseOrderItem] = [],
        status: PurchaseOrderStatus = .pending,
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.orderNumber = orderNumber
        self.vendorID = vendorID
        self.orderDate = orderDate
        self.expectedDeliveryDate = expectedDeliveryDate
        self.items = items
        self.status = status
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // MARK: - Item Management
    
    /// Adds a line item to the purchase order.
    /// - Parameter item: The item to add.
    /// - Returns: A new `PurchaseOrder` with the item added.
    func addingItem(_ item: PurchaseOrderItem) -> PurchaseOrder {
        var copy = self
        copy.items.append(item)
        copy.updatedAt = Date()
        return copy
    }
    
    /// Removes a line item from the purchase order by its ID.
    /// - Parameter itemID: The ID of the item to remove.
    /// - Returns: A new `PurchaseOrder` with the item removed.
    func removingItem(withID itemID: UUID) -> PurchaseOrder {
        var copy = self
        copy.items.removeAll { $0.id == itemID }
        copy.updatedAt = Date()
        return copy
    }
    
    // MARK: - Status Change
    
    /// Returns a new purchase order with updated status.
    /// - Parameter newStatus: The new status to set.
    /// - Returns: A new `PurchaseOrder` with status updated.
    func updatingStatus(to newStatus: PurchaseOrderStatus) -> PurchaseOrder {
        var copy = self
        copy.status = newStatus
        copy.updatedAt = Date()
        return copy
    }
    
    // MARK: - Audit Logging Hooks
    
    /// Logs audit information asynchronously when a new purchase order is created.
    func logCreationAudit() async {
        // Simulate async audit logging (replace with your logging system)
        await logAudit(event: NSLocalizedString("Purchase order created", comment: "Audit: order created"))
    }
    
    /// Logs audit information asynchronously when the purchase order is updated.
    func logUpdateAudit() async {
        await logAudit(event: NSLocalizedString("Purchase order updated", comment: "Audit: order updated"))
    }
    
    /// Logs audit information asynchronously when the status changes.
    /// - Parameter newStatus: The new status after change.
    func logStatusChangeAudit(to newStatus: PurchaseOrderStatus) async {
        let event = String(
            format: NSLocalizedString("Purchase order status changed to %@", comment: "Audit: status changed"),
            newStatus.localizedDisplay
        )
        await logAudit(event: event)
    }
    
    /// Internal method to perform (simulated) async audit logging.
    /// - Parameter event: The event description.
    private func logAudit(event: String) async {
        // Replace with real audit log logic (e.g., send to server, write to DB)
        // For demonstration, just print.
        print("[AUDIT] \(Date()): \(event) - Order #\(orderNumber)")
    }
}

// MARK: - SwiftUI Preview

struct PurchaseOrder_Previews: PreviewProvider {
    static var previews: some View {
        let sampleProductID1 = UUID()
        let sampleProductID2 = UUID()
        let sampleVendorID = UUID()
        let item1 = PurchaseOrderItem(productID: sampleProductID1, quantity: 5, unitPrice: 15.0)
        let item2 = PurchaseOrderItem(productID: sampleProductID2, quantity: 2, unitPrice: 50.0)
        let order = PurchaseOrder(
            orderNumber: "PO-2025-0001",
            vendorID: sampleVendorID,
            orderDate: Date(),
            expectedDeliveryDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()),
            items: [item1, item2],
            status: .confirmed,
            notes: NSLocalizedString("Urgent delivery requested.", comment: "Sample note"),
            createdAt: Date(),
            updatedAt: Date()
        )
        return List {
            Section(header: Text(NSLocalizedString("Purchase Order", comment: ""))) {
                Text("\(NSLocalizedString("Order Number", comment: "")): \(order.orderNumber)")
                Text("\(NSLocalizedString("Status", comment: "")): \(order.statusDisplay)")
                Text("\(NSLocalizedString("Order Date", comment: "")): \(order.formattedOrderDate)")
                if let delivery = order.formattedExpectedDeliveryDate {
                    Text("\(NSLocalizedString("Expected Delivery", comment: "")): \(delivery)")
                }
                Text("\(NSLocalizedString("Total Amount", comment: "")): \(order.totalAmount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))")
                if let notes = order.notes {
                    Text("\(NSLocalizedString("Notes", comment: "")): \(notes)")
                }
            }
            Section(header: Text(NSLocalizedString("Line Items", comment: ""))) {
                ForEach(order.items) { item in
                    VStack(alignment: .leading) {
                        Text("\(NSLocalizedString("Product", comment: "")): \(item.productID.uuidString.prefix(8))…")
                        Text("\(NSLocalizedString("Quantity", comment: "")): \(item.quantity)")
                        Text("\(NSLocalizedString("Unit Price", comment: "")): \(item.unitPrice, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))")
                        Text("\(NSLocalizedString("Total", comment: "")): \(item.totalPrice, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))")
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .previewDisplayName("PurchaseOrder Model Preview")
    }
}


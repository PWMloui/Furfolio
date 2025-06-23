//
//  Charge.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//
//  ENHANCED: Updated to include payment method tracking, staff attribution,
//  tagging, and a structured audit log for comprehensive financial management.
//

import Foundation
import SwiftData

// MARK: - ChargeType Enum (No changes, shown for context)

/// Enum representing the type of charge or service rendered.
enum ChargeType: String, Codable, CaseIterable, Identifiable {
    case fullGroom, basicBath, nailTrim, custom, product
    
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .fullGroom: return "Full Groom"
        case .basicBath: return "Basic Bath"
        case .nailTrim: return "Nail Trim"
        case .custom: return "Custom Service"
        case .product: return "Product"
        }
    }
    // ... icon property ...
}


// MARK: - NEW: PaymentMethod Enum

/// Defines the method of payment for a charge.
public enum PaymentMethod: String, Codable, CaseIterable, Identifiable {
    case unpaid = "Unpaid"
    case cash = "Cash"
    case creditCard = "Credit Card"
    case debitCard = "Debit Card"
    case zelle = "Zelle"
    case other = "Other"

    public var id: String { rawValue }
}


// MARK: - NEW: ChargeAuditEntry Struct

/// Represents a single, structured audit log entry for a Charge.
struct ChargeAuditEntry: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var date: Date = Date()
    var action: String // e.g., "Created", "Updated isPaid", "Amount changed"
    var details: String? // e.g., "Set isPaid to true", "Amount changed from $50 to $55"
    var userID: String?
}


// MARK: - Charge Model (Updated)

/// Represents a modular, auditable, and tokenized business charge entity.
@Model
final class Charge: Identifiable, ObservableObject {
    
    @Attribute(.unique)
    private(set) var id: UUID

    var date: Date
    var amount: Double
    var type: ChargeType
    var notes: String?
    var isPaid: Bool
    
    // --- NEW & UPDATED PROPERTIES ---
    
    /// The method used for payment.
    var paymentMethod: PaymentMethod
    
    /// Flexible tags for categorization (e.g., "Discount", "Refund", "Special").
    var tags: [String]
    
    /// A structured log of all changes to this charge.
    var auditLog: [ChargeAuditEntry]

    // --- RELATIONSHIPS ---
    
    @Relationship(deleteRule: .nullify, inverse: \DogOwner.charges)
    var owner: DogOwner?
    
    @Relationship(deleteRule: .nullify, inverse: \Dog.charges)
    var dog: Dog?
    
    @Relationship(deleteRule: .nullify, inverse: \Appointment.charges)
    var appointment: Appointment?
    
    /// The staff member who processed or created this charge.
    @Relationship(deleteRule: .nullify)
    var processedBy: StaffMember?

    // --- METADATA ---
    
    private(set) var lastModified: Date
    private(set) var createdBy: String?
    
    // --- COMPUTED PROPERTIES ---
    
    var summary: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        let amountString = formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
        return "\(type.displayName) - \(amountString) on \(date.formatted(date: .abbreviated, time: .omitted))"
    }
    
    // --- INITIALIZER (Updated) ---
    
    init(
        id: UUID = UUID(),
        date: Date,
        amount: Double,
        type: ChargeType,
        notes: String? = nil,
        owner: DogOwner? = nil,
        dog: Dog? = nil,
        appointment: Appointment? = nil,
        isPaid: Bool = false,
        paymentMethod: PaymentMethod = .unpaid,
        tags: [String] = [],
        processedBy: StaffMember? = nil,
        createdBy: String? = nil,
        lastModified: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.amount = amount
        self.type = type
        self.notes = notes
        self.owner = owner
        self.dog = dog
        self.appointment = appointment
        self.isPaid = isPaid
        self.paymentMethod = paymentMethod
        self.tags = tags
        self.processedBy = processedBy
        self.createdBy = createdBy
        self.lastModified = lastModified
        self.auditLog = [ChargeAuditEntry(action: "Charge Created", userID: createdBy)]
    }
    
    // --- METHODS ---
    
    /// Marks the charge as paid with a specific payment method.
    func markAsPaid(method: PaymentMethod, byUser userID: String?) {
        guard method != .unpaid else { return }
        self.isPaid = true
        self.paymentMethod = method
        addAuditEntry(action: "Marked as Paid", details: "Payment method: \(method.rawValue)", userID: userID)
    }

    /// Logs an update to the charge and refreshes the last modified timestamp.
    func addAuditEntry(action: String, details: String? = nil, userID: String?) {
        let entry = ChargeAuditEntry(action: action, details: details, userID: userID)
        self.auditLog.append(entry)
        self.lastModified = Date()
    }
}


// MARK: - SwiftUI Preview Stub

#if DEBUG
import SwiftUI

@available(iOS 18.0, *)
struct Charge_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Charge Summary:")
                .font(AppTheme.Fonts.headline)

            let sampleCharge = Charge(
                date: Date(),
                amount: 85.50,
                type: .fullGroom,
                notes: "Teddy bear cut, blueberry facial.",
                isPaid: true,
                paymentMethod: .creditCard,
                tags: ["VIP", "Discount"],
                createdBy: "admin"
            )
            
            Text(sampleCharge.summary)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Payment Method: \(sampleCharge.paymentMethod.rawValue)")
                .font(.caption)

            HStack {
                ForEach(sampleCharge.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif

//
//  Charge.swift
//  Furfolio
//
//  ENTERPRISE ENHANCED: analytics/audit–ready, Trust Center–capable, preview/test–injectable.
//

import Foundation
import SwiftData

// MARK: - Analytics/Audit Protocol

public protocol ChargeAnalyticsLogger {
    func log(event: String, info: [String: Any]?)
}
public struct NullChargeAnalyticsLogger: ChargeAnalyticsLogger {
    public init() {}
    public func log(event: String, info: [String: Any]?) {}
}

// MARK: - Trust Center Permission Protocol

public protocol ChargeTrustCenterDelegate {
    func permission(for action: String, context: [String: Any]?) -> Bool
}
public struct NullChargeTrustCenterDelegate: ChargeTrustCenterDelegate {
    public init() {}
    public func permission(for action: String, context: [String: Any]?) -> Bool { true }
}

// MARK: - ChargeType Enum

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
}

// MARK: - PaymentMethod Enum

public enum PaymentMethod: String, Codable, CaseIterable, Identifiable {
    case unpaid = "Unpaid"
    case cash = "Cash"
    case creditCard = "Credit Card"
    case debitCard = "Debit Card"
    case zelle = "Zelle"
    case other = "Other"
    public var id: String { rawValue }
}

// MARK: - ChargeAuditEntry

struct ChargeAuditEntry: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var date: Date = Date()
    var action: String
    var details: String?
    var userID: String?
}

// MARK: - Charge Model (Enterprise Enhanced)

@Model
final class Charge: Identifiable, ObservableObject {

    // MARK: - Analytics & Trust Center (Injectable)
    static var analyticsLogger: ChargeAnalyticsLogger = NullChargeAnalyticsLogger()
    static var trustCenterDelegate: ChargeTrustCenterDelegate = NullChargeTrustCenterDelegate()

    @Attribute(.unique)
    private(set) var id: UUID

    var date: Date
    var amount: Double
    var type: ChargeType
    var notes: String?
    var isPaid: Bool

    var paymentMethod: PaymentMethod
    var tags: [String]
    var auditLog: [ChargeAuditEntry]

    @Relationship(deleteRule: .nullify, inverse: \DogOwner.charges)
    var owner: DogOwner?

    @Relationship(deleteRule: .nullify, inverse: \Dog.charges)
    var dog: Dog?

    @Relationship(deleteRule: .nullify, inverse: \Appointment.charges)
    var appointment: Appointment?

    @Relationship(deleteRule: .nullify)
    var processedBy: StaffMember?

    private(set) var lastModified: Date
    private(set) var createdBy: String?

    // MARK: - Computed Properties

    var summary: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        let amountString = formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
        return "\(type.displayName) - \(amountString) on \(date.formatted(date: .abbreviated, time: .omitted))"
    }

    var accessibilityLabel: String {
        "\(type.displayName), amount \(amount) \(isPaid ? "paid" : "not paid"), payment method \(paymentMethod.rawValue)"
    }

    // MARK: - Initializer

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
        Self.analyticsLogger.log(event: "created", info: [
            "id": id.uuidString,
            "type": type.rawValue,
            "amount": amount,
            "isPaid": isPaid,
            "paymentMethod": paymentMethod.rawValue,
            "createdBy": createdBy as Any
        ])
    }

    // MARK: - Mutation Methods

    /// Marks the charge as paid with a specific payment method.
    func markAsPaid(method: PaymentMethod, byUser userID: String?) {
        guard method != .unpaid else { return }
        guard Self.trustCenterDelegate.permission(for: "markAsPaid", context: [
            "chargeID": id.uuidString,
            "method": method.rawValue,
            "userID": userID as Any
        ]) else {
            Self.analyticsLogger.log(event: "markAsPaid_denied", info: [
                "chargeID": id.uuidString,
                "method": method.rawValue,
                "userID": userID as Any
            ])
            return
        }
        self.isPaid = true
        self.paymentMethod = method
        addAuditEntry(action: "Marked as Paid", details: "Payment method: \(method.rawValue)", userID: userID)
        Self.analyticsLogger.log(event: "markAsPaid", info: [
            "chargeID": id.uuidString,
            "method": method.rawValue,
            "userID": userID as Any
        ])
    }

    /// Logs an update to the charge and refreshes the last modified timestamp.
    func addAuditEntry(action: String, details: String? = nil, userID: String?) {
        guard Self.trustCenterDelegate.permission(for: "addAuditEntry", context: [
            "chargeID": id.uuidString,
            "action": action,
            "userID": userID as Any
        ]) else {
            Self.analyticsLogger.log(event: "addAuditEntry_denied", info: [
                "chargeID": id.uuidString,
                "action": action,
                "userID": userID as Any
            ])
            return
        }
        let entry = ChargeAuditEntry(action: action, details: details, userID: userID)
        self.auditLog.append(entry)
        self.lastModified = Date()
        Self.analyticsLogger.log(event: "auditEntryAdded", info: [
            "chargeID": id.uuidString,
            "action": action,
            "userID": userID as Any
        ])
    }

    /// Updates the amount, tracking the old and new values.
    func updateAmount(_ newAmount: Double, by userID: String?) {
        guard Self.trustCenterDelegate.permission(for: "updateAmount", context: [
            "chargeID": id.uuidString,
            "oldAmount": amount,
            "newAmount": newAmount,
            "userID": userID as Any
        ]) else {
            Self.analyticsLogger.log(event: "updateAmount_denied", info: [
                "chargeID": id.uuidString,
                "userID": userID as Any
            ])
            return
        }
        let oldAmount = amount
        amount = newAmount
        addAuditEntry(action: "Amount Changed", details: "Amount changed from \(oldAmount) to \(newAmount)", userID: userID)
        Self.analyticsLogger.log(event: "amountChanged", info: [
            "chargeID": id.uuidString,
            "oldAmount": oldAmount,
            "newAmount": newAmount,
            "userID": userID as Any
        ])
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

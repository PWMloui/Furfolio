//
//  Charge.swift
//  Furfolio
//
//  ENTERPRISE ENHANCED: analytics/audit–ready, Trust Center–capable, preview/test–injectable.
//

import Foundation
import SwiftData

// MARK: - Audit Context (set at login/session)
public struct ChargeAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "Charge"
}

// MARK: - Audit Event Model
public struct ChargeAuditEvent: Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let operation: String
    public let chargeID: UUID
    public let detail: String
    public let user: String?
    public let context: String?
    public let role: String?
    public let staffID: String?
    public let escalate: Bool

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        operation: String,
        chargeID: UUID,
        detail: String,
        user: String?,
        context: String?,
        role: String?,
        staffID: String?,
        escalate: Bool
    ) {
        self.id = id
        self.timestamp = timestamp
        self.operation = operation
        self.chargeID = chargeID
        self.detail = detail
        self.user = user
        self.context = context
        self.role = role
        self.staffID = staffID
        self.escalate = escalate
    }

    public var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        var base = "[\(dateStr)] \(operation.capitalized) (\(detail))"
        var details = [String]()
        if let user = user { details.append("User: \(user)") }
        if let role = role { details.append("Role: \(role)") }
        if let staffID = staffID { details.append("StaffID: \(staffID)") }
        if let context = context { details.append("Context: \(context)") }
        if escalate { details.append("Escalate: YES") }
        return ([base] + details).joined(separator: " | ")
    }
}

// MARK: - ChargeAuditLogger

fileprivate final class ChargeAuditLogger {
    private static let queue = DispatchQueue(label: "furfolio.charge.audit.logger")
    private static var log: [ChargeAuditEvent] = []
    private static let maxLogSize = 200

    static func record(
        operation: String,
        chargeID: UUID,
        detail: String,
        user: String? = nil,
        context: String? = nil,
        escalate: Bool = false
    ) {
        let escalateFlag = escalate || operation.lowercased().contains("danger")
            || operation.lowercased().contains("critical") || operation.lowercased().contains("delete")
        let event = ChargeAuditEvent(
            operation: operation,
            chargeID: chargeID,
            detail: detail,
            user: user,
            context: context ?? ChargeAuditContext.context,
            role: ChargeAuditContext.role,
            staffID: ChargeAuditContext.staffID,
            escalate: escalateFlag
        )
        queue.async {
            log.append(event)
            if log.count > maxLogSize { log.removeFirst(log.count - maxLogSize) }
        }
    }

    static func allEvents(completion: @escaping ([ChargeAuditEvent]) -> Void) {
        queue.async { completion(log) }
    }
    static func exportLastJSON(completion: @escaping (String?) -> Void) {
        queue.async {
            guard let last = log.last else { completion(nil); return }
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let json = (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
            completion(json)
        }
    }
    static func recentEvents(limit: Int = 5, completion: @escaping ([String]) -> Void) {
        queue.async {
            let events = log.suffix(limit).map { $0.accessibilityLabel }
            completion(events)
        }
    }
    static func clearLog() {
        queue.async { log.removeAll() }
    }
    static func lastSummary(completion: @escaping (String) -> Void) {
        queue.async {
            if let last = log.last {
                completion(last.accessibilityLabel)
            } else {
                completion("No charge audit events recorded.")
            }
        }
    }
}

// MARK: - Analytics/Audit Protocols

public protocol ChargeAnalyticsLogger {
    func log(event: String, info: [String: Any]?) async
}
public struct NullChargeAnalyticsLogger: ChargeAnalyticsLogger {
    public init() {}
    public func log(event: String, info: [String: Any]?) async {}
}

// MARK: - Trust Center Permission Protocol

public protocol ChargeTrustCenterDelegate {
    func permission(for action: String, context: [String: Any]?) async -> Bool
}
public struct NullChargeTrustCenterDelegate: ChargeTrustCenterDelegate {
    public init() {}
    public func permission(for action: String, context: [String: Any]?) async -> Bool { true }
}

// MARK: - ChargeType Enum

enum ChargeType: String, Codable, CaseIterable, Identifiable {
    case fullGroom, basicBath, nailTrim, custom, product

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .fullGroom: return NSLocalizedString("Full Groom", comment: "ChargeType fullGroom display name")
        case .basicBath: return NSLocalizedString("Basic Bath", comment: "ChargeType basicBath display name")
        case .nailTrim: return NSLocalizedString("Nail Trim", comment: "ChargeType nailTrim display name")
        case .custom: return NSLocalizedString("Custom Service", comment: "ChargeType custom display name")
        case .product: return NSLocalizedString("Product", comment: "ChargeType product display name")
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

// MARK: - AuditLogActor (legacy: kept for SwiftData compliance)

struct ChargeAuditEntry: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var date: Date = Date()
    var action: String
    var details: String?
    var userID: String?
}
actor ChargeAuditLogActor {
    private(set) var auditLog: [ChargeAuditEntry]
    init(initialLog: [ChargeAuditEntry]) {
        self.auditLog = initialLog
    }
    func append(_ entry: ChargeAuditEntry) {
        auditLog.append(entry)
    }
    func getAuditLog() -> [ChargeAuditEntry] {
        auditLog
    }
}

// MARK: - Charge Model (Enterprise Enhanced)

@Model
final class Charge: Identifiable, ObservableObject {

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

    @Relationship(deleteRule: .nullify, inverse: \DogOwner.charges)
    var owner: DogOwner?

    @Relationship(deleteRule: .nullify, inverse: \Dog.charges)
    var dog: Dog?

    @Relationship(deleteRule: .nullify, inverse: \Appointment.charges)
    var appointment: Appointment?

    @Relationship(deleteRule: .nullify)
    var processedBy: StaffMember?

    private(set) var createdBy: String?

    private var lastModifiedStorage: Date
    private let auditLogActor: ChargeAuditLogActor

    var lastModified: Date {
        get async {
            await auditLogActor.getAuditLog()
            return lastModifiedStorage
        }
    }

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
        self.lastModifiedStorage = lastModified
        self.auditLogActor = ChargeAuditLogActor(initialLog: [ChargeAuditEntry(action: NSLocalizedString("Charge Created", comment: "Audit log entry for charge creation"), userID: createdBy)])

        // --- AUDIT LOGGING ----
        ChargeAuditLogger.record(operation: "create", chargeID: id, detail: "Charge created (\(type.displayName)): \(amount)", user: createdBy)
        Task {
            await Self.analyticsLogger.log(event: NSLocalizedString("created", comment: "Charge created event"), info: [
                "id": id.uuidString,
                "type": type.rawValue,
                "amount": amount,
                "isPaid": isPaid,
                "paymentMethod": paymentMethod.rawValue,
                "createdBy": createdBy as Any
            ])
        }
    }

    // MARK: - Computed Properties

    var summary: String {
        get async {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            let amountString = formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
            let dateString = await date.formatted(date: .abbreviated, time: .omitted)
            return String(format: NSLocalizedString("%@ - %@ on %@", comment: "Charge summary: type - amount on date"), type.displayName, amountString, dateString)
        }
    }

    var accessibilityLabel: String {
        get async {
            let paidString = isPaid ? NSLocalizedString("paid", comment: "Charge paid status") : NSLocalizedString("not paid", comment: "Charge not paid status")
            let paymentMethodString = NSLocalizedString(paymentMethod.rawValue, comment: "Payment method")
            return String(format: NSLocalizedString("%@, amount %.2f %@, payment method %@", comment: "Accessibility label for charge"), type.displayName, amount, paidString, paymentMethodString)
        }
    }

    // MARK: - Mutation Methods

    enum ChargeError: Error, LocalizedError {
        case permissionDenied(action: String)
        var errorDescription: String? {
            switch self {
            case .permissionDenied(let action):
                return String(format: NSLocalizedString("Permission denied for action: %@", comment: "Permission denied error"), action)
            }
        }
    }

    func markAsPaid(method: PaymentMethod, byUser userID: String?) async throws {
        guard method != .unpaid else { return }
        let permitted = await Self.trustCenterDelegate.permission(for: "markAsPaid", context: [
            "chargeID": id.uuidString,
            "method": method.rawValue,
            "userID": userID as Any
        ])
        guard permitted else {
            await Self.analyticsLogger.log(event: NSLocalizedString("markAsPaid_denied", comment: "Denied markAsPaid event"), info: [
                "chargeID": id.uuidString,
                "method": method.rawValue,
                "userID": userID as Any
            ])
            ChargeAuditLogger.record(operation: "markAsPaidDenied", chargeID: id, detail: "Denied marking paid", user: userID)
            throw ChargeError.permissionDenied(action: "markAsPaid")
        }
        self.isPaid = true
        self.paymentMethod = method
        let details = String(format: NSLocalizedString("Payment method: %@", comment: "Details for payment method"), method.rawValue)
        await addAuditEntry(action: NSLocalizedString("Marked as Paid", comment: "Audit action for marking paid"), details: details, userID: userID)
        ChargeAuditLogger.record(operation: "markAsPaid", chargeID: id, detail: "Marked as paid (\(method.rawValue))", user: userID)
        await Self.analyticsLogger.log(event: NSLocalizedString("markAsPaid", comment: "markAsPaid event"), info: [
            "chargeID": id.uuidString,
            "method": method.rawValue,
            "userID": userID as Any
        ])
    }

    func addAuditEntry(action: String, details: String? = nil, userID: String?) async {
        let permitted = await Self.trustCenterDelegate.permission(for: "addAuditEntry", context: [
            "chargeID": id.uuidString,
            "action": action,
            "userID": userID as Any
        ])
        guard permitted else {
            await Self.analyticsLogger.log(event: NSLocalizedString("addAuditEntry_denied", comment: "Denied addAuditEntry event"), info: [
                "chargeID": id.uuidString,
                "action": action,
                "userID": userID as Any
            ])
            ChargeAuditLogger.record(operation: "addAuditEntryDenied", chargeID: id, detail: "Denied addAuditEntry (\(action))", user: userID)
            return
        }
        let entry = ChargeAuditEntry(action: action, details: details, userID: userID)
        await auditLogActor.append(entry)
        self.lastModifiedStorage = Date()
        let d = details ?? ""
        ChargeAuditLogger.record(operation: "auditEntry", chargeID: id, detail: "\(action): \(d)", user: userID)
        await Self.analyticsLogger.log(event: NSLocalizedString("auditEntryAdded", comment: "Audit entry added event"), info: [
            "chargeID": id.uuidString,
            "action": action,
            "userID": userID as Any
        ])
    }

    func updateAmount(_ newAmount: Double, by userID: String?) async throws {
        let permitted = await Self.trustCenterDelegate.permission(for: "updateAmount", context: [
            "chargeID": id.uuidString,
            "oldAmount": amount,
            "newAmount": newAmount,
            "userID": userID as Any
        ])
        guard permitted else {
            await Self.analyticsLogger.log(event: NSLocalizedString("updateAmount_denied", comment: "Denied updateAmount event"), info: [
                "chargeID": id.uuidString,
                "userID": userID as Any
            ])
            ChargeAuditLogger.record(operation: "updateAmountDenied", chargeID: id, detail: "Denied updateAmount", user: userID)
            throw ChargeError.permissionDenied(action: "updateAmount")
        }
        let oldAmount = amount
        amount = newAmount
        let details = String(format: NSLocalizedString("Amount changed from %.2f to %.2f", comment: "Details for amount change"), oldAmount, newAmount)
        await addAuditEntry(action: NSLocalizedString("Amount Changed", comment: "Audit action for amount change"), details: details, userID: userID)
        ChargeAuditLogger.record(operation: "updateAmount", chargeID: id, detail: details, user: userID)
        await Self.analyticsLogger.log(event: NSLocalizedString("amountChanged", comment: "Amount changed event"), info: [
            "chargeID": id.uuidString,
            "oldAmount": oldAmount,
            "newAmount": newAmount,
            "userID": userID as Any
        ])
    }
}

// MARK: - Audit/Admin Accessors

public enum ChargeAuditAdmin {
    public static func lastSummary(completion: @escaping (String) -> Void) {
        ChargeAuditLogger.lastSummary(completion: completion)
    }
    public static func lastJSON(completion: @escaping (String?) -> Void) {
        ChargeAuditLogger.exportLastJSON(completion: completion)
    }
    public static func recentEvents(limit: Int = 5, completion: @escaping ([String]) -> Void) {
        ChargeAuditLogger.recentEvents(limit: limit, completion: completion)
    }
    public static func clearAuditLog() {
        ChargeAuditLogger.clearLog()
    }
}

// MARK: - SwiftUI Preview Stub

#if DEBUG
import SwiftUI

@available(iOS 18.0, *)
struct Charge_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("Charge Summary:", comment: "Preview label for charge summary"))
                .font(.headline)
            AsyncPreviewChargeView()
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}

@available(iOS 18.0, *)
struct AsyncPreviewChargeView: View {
    @State private var summaryText: String = ""
    @State private var paymentMethodText: String = ""
    @State private var tags: [String] = []
    @State private var lastAuditSummary: String = ""
    @State private var lastAuditJSON: String = ""
    @State private var auditEvents: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(summaryText)
            Text(String(format: NSLocalizedString("Payment Method: %@", comment: "Preview payment method label"), paymentMethodText))
                .font(.caption)
            HStack {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            Divider()
            Text("Last Audit Summary: \(lastAuditSummary)").font(.caption)
            ScrollView(.horizontal) {
                Text(lastAuditJSON)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxHeight: 100)
            }
            Button("Show Last Audit Event") {
                ChargeAuditAdmin.lastSummary { lastAuditSummary = $0 }
                ChargeAuditAdmin.lastJSON { lastAuditJSON = $0 ?? "No JSON" }
            }
            Button("Show Recent Audit Events") {
                ChargeAuditAdmin.recentEvents(limit: 10) { auditEvents = $0 }
            }
            List(auditEvents, id: \.self) { event in
                Text(event)
            }
            Button("Clear Audit Log") {
                ChargeAuditAdmin.clearAuditLog()
                auditEvents = []
                lastAuditSummary = ""
                lastAuditJSON = ""
            }.foregroundColor(.red)
        }
        .task {
            let sampleCharge = Charge(
                date: Date(),
                amount: 85.50,
                type: .fullGroom,
                notes: NSLocalizedString("Teddy bear cut, blueberry facial.", comment: "Sample notes"),
                isPaid: true,
                paymentMethod: .creditCard,
                tags: ["VIP", "Discount"],
                createdBy: "admin"
            )
            summaryText = await sampleCharge.summary
            paymentMethodText = sampleCharge.paymentMethod.rawValue
            tags = sampleCharge.tags
            await sampleCharge.addAuditEntry(action: NSLocalizedString("Preview Audit Entry", comment: "Preview audit entry action"), details: nil, userID: "previewUser")
            ChargeAuditAdmin.lastSummary { lastAuditSummary = $0 }
            ChargeAuditAdmin.lastJSON { lastAuditJSON = $0 ?? "" }
            ChargeAuditAdmin.recentEvents(limit: 10) { auditEvents = $0 }
        }
    }
}
#endif

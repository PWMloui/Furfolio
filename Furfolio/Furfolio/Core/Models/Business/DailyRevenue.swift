//
//  DailyRevenue.swift
//  Furfolio
//
//  ENTERPRISE ENHANCED: analytics/audit–ready, Trust Center–capable, preview/test–injectable.
//

import Foundation
import SwiftData

// MARK: - Audit Context (set at login/session)
public struct DailyRevenueAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "DailyRevenue"
}

// MARK: - Audit Event Model
public struct DailyRevenueAuditEvent: Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let operation: String
    public let dailyRevenueID: UUID
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
        dailyRevenueID: UUID,
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
        self.dailyRevenueID = dailyRevenueID
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

// MARK: - DailyRevenueAuditLogger

fileprivate final class DailyRevenueAuditLogger {
    private static let queue = DispatchQueue(label: "furfolio.dailyrevenue.audit.logger")
    private static var log: [DailyRevenueAuditEvent] = []
    private static let maxLogSize = 200

    static func record(
        operation: String,
        dailyRevenueID: UUID,
        detail: String,
        user: String? = nil,
        context: String? = nil,
        escalate: Bool = false
    ) {
        let escalateFlag = escalate || operation.lowercased().contains("danger")
            || operation.lowercased().contains("critical") || operation.lowercased().contains("delete")
        let event = DailyRevenueAuditEvent(
            operation: operation,
            dailyRevenueID: dailyRevenueID,
            detail: detail,
            user: user,
            context: context ?? DailyRevenueAuditContext.context,
            role: DailyRevenueAuditContext.role,
            staffID: DailyRevenueAuditContext.staffID,
            escalate: escalateFlag
        )
        queue.async {
            log.append(event)
            if log.count > maxLogSize { log.removeFirst(log.count - maxLogSize) }
        }
    }

    static func allEvents(completion: @escaping ([DailyRevenueAuditEvent]) -> Void) {
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
                completion("No daily revenue audit events recorded.")
            }
        }
    }
}

// MARK: - Analytics/Audit Protocol

public protocol DailyRevenueAnalyticsLogger {
    func log(event: String, info: [String: Any]?) async
}
public struct NullDailyRevenueAnalyticsLogger: DailyRevenueAnalyticsLogger {
    public init() {}
    public func log(event: String, info: [String: Any]?) async {}
}

// MARK: - Trust Center Permission Protocol

public protocol DailyRevenueTrustCenterDelegate {
    func permission(for action: String, context: [String: Any]?) async -> Bool
}
public struct NullDailyRevenueTrustCenterDelegate: DailyRevenueTrustCenterDelegate {
    public init() {}
    public func permission(for action: String, context: [String: Any]?) async -> Bool { true }
}

// MARK: - Model

@Model
final class DailyRevenue: Identifiable, ObservableObject, Equatable, Hashable {

    static var analyticsLogger: DailyRevenueAnalyticsLogger = NullDailyRevenueAnalyticsLogger()
    static var trustCenterDelegate: DailyRevenueTrustCenterDelegate = NullDailyRevenueTrustCenterDelegate()

    @Attribute(.unique)
    var id: UUID = UUID()
    var date: Date
    var lastUpdated: Date
    fileprivate var totalAmount: Double
    fileprivate var chargeIDs: [UUID]
    var notes: String?

    init(
        id: UUID = UUID(),
        date: Date,
        totalAmount: Double = 0,
        chargeIDs: [UUID] = [],
        notes: String? = nil,
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.totalAmount = totalAmount
        self.chargeIDs = chargeIDs
        self.notes = notes
        self.lastUpdated = lastUpdated
        DailyRevenueAuditLogger.record(
            operation: "create",
            dailyRevenueID: id,
            detail: String(format: NSLocalizedString("Created with total %.2f", comment: "Audit create detail"), totalAmount),
            user: nil
        )
        Task {
            await Self.analyticsLogger.log(event: NSLocalizedString("created", comment: "Created event for DailyRevenue"), info: [
                "id": id.uuidString,
                "date": self.date,
                "totalAmount": totalAmount
            ])
        }
    }

    // MARK: - Concurrency-safe Mutating Methods (Async)

    @MainActor
    func addChargeID(_ id: UUID, by user: String? = nil) async {
        let context: [String: Any] = [
            "dailyRevenueID": self.id.uuidString,
            "chargeID": id.uuidString,
            "user": user as Any
        ]
        let allowed = await Self.trustCenterDelegate.permission(for: NSLocalizedString("addChargeID", comment: "Permission action: addChargeID"), context: context)
        guard allowed else {
            await Self.analyticsLogger.log(event: NSLocalizedString("addChargeID_denied", comment: "Audit log: addChargeID denied"), info: context)
            DailyRevenueAuditLogger.record(
                operation: "addChargeID_denied",
                dailyRevenueID: self.id,
                detail: "Denied addChargeID (\(id.uuidString))",
                user: user
            )
            return
        }
        guard !chargeIDs.contains(id) else { return }
        chargeIDs.append(id)
        await updateLastModified(reason: String(format: NSLocalizedString("Added chargeID %@", comment: "Audit log: Added chargeID"), id.uuidString), user: user)
        DailyRevenueAuditLogger.record(
            operation: "addChargeID",
            dailyRevenueID: self.id,
            detail: "Added chargeID (\(id.uuidString))",
            user: user
        )
        await Self.analyticsLogger.log(event: NSLocalizedString("chargeID_added", comment: "Audit log: chargeID added"), info: context)
    }

    @MainActor
    func removeChargeID(_ id: UUID, by user: String? = nil) async {
        let context: [String: Any] = [
            "dailyRevenueID": self.id.uuidString,
            "chargeID": id.uuidString,
            "user": user as Any
        ]
        let allowed = await Self.trustCenterDelegate.permission(for: NSLocalizedString("removeChargeID", comment: "Permission action: removeChargeID"), context: context)
        guard allowed else {
            await Self.analyticsLogger.log(event: NSLocalizedString("removeChargeID_denied", comment: "Audit log: removeChargeID denied"), info: context)
            DailyRevenueAuditLogger.record(
                operation: "removeChargeID_denied",
                dailyRevenueID: self.id,
                detail: "Denied removeChargeID (\(id.uuidString))",
                user: user
            )
            return
        }
        if let index = chargeIDs.firstIndex(of: id) {
            chargeIDs.remove(at: index)
            await updateLastModified(reason: String(format: NSLocalizedString("Removed chargeID %@", comment: "Audit log: Removed chargeID"), id.uuidString), user: user)
            DailyRevenueAuditLogger.record(
                operation: "removeChargeID",
                dailyRevenueID: self.id,
                detail: "Removed chargeID (\(id.uuidString))",
                user: user
            )
            await Self.analyticsLogger.log(event: NSLocalizedString("chargeID_removed", comment: "Audit log: chargeID removed"), info: context)
        }
    }

    var chargeIDsSnapshot: [UUID] { chargeIDs }

    // MARK: - Computed Properties

    var isToday: Bool { Calendar.current.isDateInToday(date) }
    var isEmpty: Bool { totalAmount == 0 }
    var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    func formattedAmount(locale: Locale? = nil) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        if let locale = locale { formatter.locale = locale }
        return formatter.string(from: NSNumber(value: totalAmount)) ?? NSLocalizedString("$0.00", comment: "Default zero currency value")
    }

    // MARK: - Business Logic Helpers (Async)

    @MainActor
    func updateTotal(by amount: Double, by user: String? = nil) async {
        let context: [String: Any] = [
            "dailyRevenueID": self.id.uuidString,
            "amount": amount,
            "user": user as Any
        ]
        let allowed = await Self.trustCenterDelegate.permission(for: NSLocalizedString("updateTotal", comment: "Permission action: updateTotal"), context: context)
        guard allowed else {
            await Self.analyticsLogger.log(event: NSLocalizedString("updateTotal_denied", comment: "Audit log: updateTotal denied"), info: context)
            DailyRevenueAuditLogger.record(
                operation: "updateTotal_denied",
                dailyRevenueID: self.id,
                detail: "Denied updateTotal (\(amount))",
                user: user
            )
            return
        }
        totalAmount += amount
        await updateLastModified(reason: String(format: NSLocalizedString("Updated total by %.2f", comment: "Audit log: Updated total by amount"), amount), user: user)
        DailyRevenueAuditLogger.record(
            operation: "updateTotal",
            dailyRevenueID: self.id,
            detail: "Updated total by \(amount)",
            user: user
        )
        await Self.analyticsLogger.log(event: NSLocalizedString("total_updated", comment: "Audit log: total updated"), info: [
            "dailyRevenueID": self.id.uuidString,
            "amount": amount,
            "newTotal": totalAmount,
            "user": user as Any
        ])
    }

    @MainActor
    func resetRevenue(by user: String? = nil) async {
        let context: [String: Any] = [
            "dailyRevenueID": self.id.uuidString,
            "user": user as Any
        ]
        let allowed = await Self.trustCenterDelegate.permission(for: NSLocalizedString("resetRevenue", comment: "Permission action: resetRevenue"), context: context)
        guard allowed else {
            await Self.analyticsLogger.log(event: NSLocalizedString("resetRevenue_denied", comment: "Audit log: resetRevenue denied"), info: context)
            DailyRevenueAuditLogger.record(
                operation: "resetRevenue_denied",
                dailyRevenueID: self.id,
                detail: "Denied resetRevenue",
                user: user
            )
            return
        }
        totalAmount = 0
        await updateLastModified(reason: NSLocalizedString("Reset total revenue to zero", comment: "Audit log: Reset revenue"), user: user)
        DailyRevenueAuditLogger.record(
            operation: "resetRevenue",
            dailyRevenueID: self.id,
            detail: "Reset total revenue to zero",
            user: user
        )
        await Self.analyticsLogger.log(event: NSLocalizedString("revenue_reset", comment: "Audit log: revenue reset"), info: [
            "dailyRevenueID": self.id.uuidString,
            "user": user as Any
        ])
    }

    @MainActor
    func updateLastModified(reason: String, user: String? = nil) async {
        lastUpdated = Date()
        await Self.analyticsLogger.log(event: NSLocalizedString("lastModified", comment: "Audit log: lastModified"), info: [
            "dailyRevenueID": self.id.uuidString,
            "reason": reason,
            "user": user as Any,
            "timestamp": lastUpdated
        ])
        DailyRevenueAuditLogger.record(
            operation: "lastModified",
            dailyRevenueID: self.id,
            detail: reason,
            user: user
        )
    }

    var accessibilityLabel: String {
        let amount = formattedAmount()
        let date = formattedDate
        let notesText = notes ?? ""
        return String(format: NSLocalizedString("Daily revenue: %@ for %@. %@", comment: "Accessibility: daily revenue summary"), amount, date, notesText)
    }

    static func == (lhs: DailyRevenue, rhs: DailyRevenue) -> Bool {
        lhs.id == rhs.id &&
        lhs.date == rhs.date &&
        lhs.totalAmount == rhs.totalAmount &&
        lhs.chargeIDs == rhs.chargeIDs &&
        lhs.notes == rhs.notes &&
        lhs.lastUpdated == rhs.lastUpdated
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(date)
        hasher.combine(totalAmount)
        hasher.combine(chargeIDs)
        hasher.combine(notes)
        hasher.combine(lastUpdated)
    }

    static let sample = DailyRevenue(
        date: Date(),
        totalAmount: 1234.56,
        chargeIDs: [UUID(), UUID()],
        notes: NSLocalizedString("Sample data for previews", comment: "Sample notes"),
        lastUpdated: Date()
    )
}

// MARK: - Audit/Admin Accessors

public enum DailyRevenueAuditAdmin {
    public static func lastSummary(completion: @escaping (String) -> Void) {
        DailyRevenueAuditLogger.lastSummary(completion: completion)
    }
    public static func lastJSON(completion: @escaping (String?) -> Void) {
        DailyRevenueAuditLogger.exportLastJSON(completion: completion)
    }
    public static func recentEvents(limit: Int = 5, completion: @escaping ([String]) -> Void) {
        DailyRevenueAuditLogger.recentEvents(limit: limit, completion: completion)
    }
    public static func clearAuditLog() {
        DailyRevenueAuditLogger.clearLog()
    }
}

// MARK: - SwiftUI PreviewProvider demonstrating async usage

#if canImport(SwiftUI)
import SwiftUI

struct DailyRevenueAsyncPreview: View {
    @StateObject private var revenue = DailyRevenue.sample
    @State private var message: String = ""
    @State private var lastAuditSummary: String = ""
    @State private var lastAuditJSON: String = ""
    @State private var auditEvents: [String] = []

    var body: some View {
        VStack(spacing: 16) {
            Text(revenue.accessibilityLabel)
                .accessibilityLabel(revenue.accessibilityLabel)
                .padding()
            Button(NSLocalizedString("Add Charge ID", comment: "Button: Add charge ID")) {
                Task {
                    let newID = UUID()
                    await revenue.addChargeID(newID, by: "PreviewUser")
                    message = String(format: NSLocalizedString("Charge ID %@ added.", comment: "Message: charge ID added"), newID.uuidString)
                }
            }
            Button(NSLocalizedString("Update Total", comment: "Button: Update total")) {
                Task {
                    await revenue.updateTotal(by: 42.0, by: "PreviewUser")
                    message = NSLocalizedString("Total updated by 42.0.", comment: "Message: total updated")
                }
            }
            Button(NSLocalizedString("Reset Revenue", comment: "Button: Reset revenue")) {
                Task {
                    await revenue.resetRevenue(by: "PreviewUser")
                    message = NSLocalizedString("Revenue reset.", comment: "Message: revenue reset")
                }
            }
            Button("Show Last Audit Event") {
                DailyRevenueAuditAdmin.lastSummary { lastAuditSummary = $0 }
                DailyRevenueAuditAdmin.lastJSON { lastAuditJSON = $0 ?? "No JSON" }
            }
            Text("Last Audit Summary: \(lastAuditSummary)").font(.caption)
            ScrollView(.horizontal) {
                Text(lastAuditJSON)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxHeight: 100)
            }
            Button("Show Recent Audit Events") {
                DailyRevenueAuditAdmin.recentEvents(limit: 10) { auditEvents = $0 }
            }
            List(auditEvents, id: \.self) { event in
                Text(event)
            }
            Button("Clear Audit Log") {
                DailyRevenueAuditAdmin.clearAuditLog()
                auditEvents = []
                lastAuditSummary = ""
                lastAuditJSON = ""
            }.foregroundColor(.red)
            Text(message)
                .foregroundColor(.secondary)
                .accessibilityHint(message)
        }
        .padding()
    }
}

struct DailyRevenueAsyncPreview_Previews: PreviewProvider {
    static var previews: some View {
        DailyRevenueAsyncPreview()
    }
}
#endif

//
//  DailyRevenue.swift
//  Furfolio
//
//  Enhanced: analytics/audit–ready, Trust Center–capable, preview/test–injectable.
//

import Foundation
import SwiftData

// MARK: - Analytics/Audit Protocol

public protocol DailyRevenueAnalyticsLogger {
    func log(event: String, info: [String: Any]?)
}
public struct NullDailyRevenueAnalyticsLogger: DailyRevenueAnalyticsLogger {
    public init() {}
    public func log(event: String, info: [String: Any]?) {}
}

// MARK: - Trust Center Permission Protocol

public protocol DailyRevenueTrustCenterDelegate {
    func permission(for action: String, context: [String: Any]?) -> Bool
}
public struct NullDailyRevenueTrustCenterDelegate: DailyRevenueTrustCenterDelegate {
    public init() {}
    public func permission(for action: String, context: [String: Any]?) -> Bool { true }
}

@MainActor
@Model
final class DailyRevenue: Identifiable, ObservableObject, Equatable, Hashable {

    // MARK: - Analytics/Trust Center (Injectable)
    static var analyticsLogger: DailyRevenueAnalyticsLogger = NullDailyRevenueAnalyticsLogger()
    static var trustCenterDelegate: DailyRevenueTrustCenterDelegate = NullDailyRevenueTrustCenterDelegate()

    // MARK: - Identifiers
    @Attribute(.unique)
    var id: UUID = UUID()

    // MARK: - Dates
    var date: Date
    var lastUpdated: Date

    // MARK: - Revenue Data
    var totalAmount: Double

    // MARK: - References
    private(set) var chargeIDs: [UUID]

    // MARK: - Notes
    var notes: String?

    // MARK: - Init
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
        Self.analyticsLogger.log(event: "created", info: [
            "id": id.uuidString,
            "date": self.date,
            "totalAmount": totalAmount
        ])
    }

    // MARK: - ChargeIDs Mutation

    func addChargeID(_ id: UUID, by user: String? = nil) {
        guard Self.trustCenterDelegate.permission(for: "addChargeID", context: [
            "dailyRevenueID": self.id.uuidString,
            "chargeID": id.uuidString,
            "user": user as Any
        ]) else {
            Self.analyticsLogger.log(event: "addChargeID_denied", info: [
                "dailyRevenueID": self.id.uuidString,
                "chargeID": id.uuidString,
                "user": user as Any
            ])
            return
        }
        guard !chargeIDs.contains(id) else { return }
        chargeIDs.append(id)
        updateLastModified(reason: "Added chargeID \(id)", user: user)
        Self.analyticsLogger.log(event: "chargeID_added", info: [
            "dailyRevenueID": self.id.uuidString,
            "chargeID": id.uuidString,
            "user": user as Any
        ])
    }

    func removeChargeID(_ id: UUID, by user: String? = nil) {
        guard Self.trustCenterDelegate.permission(for: "removeChargeID", context: [
            "dailyRevenueID": self.id.uuidString,
            "chargeID": id.uuidString,
            "user": user as Any
        ]) else {
            Self.analyticsLogger.log(event: "removeChargeID_denied", info: [
                "dailyRevenueID": self.id.uuidString,
                "chargeID": id.uuidString,
                "user": user as Any
            ])
            return
        }
        if let index = chargeIDs.firstIndex(of: id) {
            chargeIDs.remove(at: index)
            updateLastModified(reason: "Removed chargeID \(id)", user: user)
            Self.analyticsLogger.log(event: "chargeID_removed", info: [
                "dailyRevenueID": self.id.uuidString,
                "chargeID": id.uuidString,
                "user": user as Any
            ])
        }
    }

    // MARK: - Computed Properties

    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var isEmpty: Bool {
        totalAmount == 0
    }

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
        if let locale = locale {
            formatter.locale = locale
        }
        return formatter.string(from: NSNumber(value: totalAmount)) ?? "$0.00"
    }

    // MARK: - Business Logic Helpers

    func updateTotal(by amount: Double, by user: String? = nil) {
        guard Self.trustCenterDelegate.permission(for: "updateTotal", context: [
            "dailyRevenueID": self.id.uuidString,
            "amount": amount,
            "user": user as Any
        ]) else {
            Self.analyticsLogger.log(event: "updateTotal_denied", info: [
                "dailyRevenueID": self.id.uuidString,
                "amount": amount,
                "user": user as Any
            ])
            return
        }
        totalAmount += amount
        updateLastModified(reason: "Updated total by \(amount)", user: user)
        Self.analyticsLogger.log(event: "total_updated", info: [
            "dailyRevenueID": self.id.uuidString,
            "amount": amount,
            "newTotal": totalAmount,
            "user": user as Any
        ])
    }

    func resetRevenue(by user: String? = nil) {
        guard Self.trustCenterDelegate.permission(for: "resetRevenue", context: [
            "dailyRevenueID": self.id.uuidString,
            "user": user as Any
        ]) else {
            Self.analyticsLogger.log(event: "resetRevenue_denied", info: [
                "dailyRevenueID": self.id.uuidString,
                "user": user as Any
            ])
            return
        }
        totalAmount = 0
        updateLastModified(reason: "Reset total revenue to zero", user: user)
        Self.analyticsLogger.log(event: "revenue_reset", info: [
            "dailyRevenueID": self.id.uuidString,
            "user": user as Any
        ])
    }

    // MARK: - Audit Trail

    private func updateLastModified(reason: String, user: String? = nil) {
        lastUpdated = Date()
        Self.analyticsLogger.log(event: "lastModified", info: [
            "dailyRevenueID": self.id.uuidString,
            "reason": reason,
            "user": user as Any,
            "timestamp": lastUpdated
        ])
    }

    // MARK: - Accessibility

    var accessibilityLabel: String {
        "Daily revenue: \(formattedAmount()) for \(formattedDate). \(notes ?? "")"
    }

    // MARK: - Equatable & Hashable

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

    // MARK: - Sample Data

    static let sample = DailyRevenue(
        date: Date(),
        totalAmount: 1234.56,
        chargeIDs: [UUID(), UUID()],
        notes: "Sample data for previews",
        lastUpdated: Date()
    )
}

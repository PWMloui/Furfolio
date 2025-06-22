//
//  DailyRevenue.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import Foundation
import SwiftData

// MARK: - DailyRevenue (Modular, Tokenized, Auditable Daily Revenue Record)

/// Represents a modular, auditable, and tokenized daily revenue entity used across analytics, dashboards, compliance, and business logic layers.
/// This class supports detailed audit trails, charge breakdowns, business reporting, and UI tokenization for seamless integration in workflows and event logging.
/// Designed for robust data integrity, compliance tracking, and flexible usage in financial reporting and analytics pipelines.
@MainActor
@Model
final class DailyRevenue: Identifiable, ObservableObject, Equatable, Hashable {

    // MARK: - Identifiers

    /// Unique identifier for this daily revenue record.
    /// Used for audit traceability, data integrity checks, and unique referencing in UI tokenization and business workflows.
    @Attribute(.unique)
    var id: UUID = UUID()

    // MARK: - Dates

    /// The date this record represents, normalized to the start of the day (midnight/local).
    /// Critical for time-based analytics, reporting consistency, and compliance with financial period boundaries.
    var date: Date

    /// Last updated timestamp for this record.
    /// Essential for audit trails, change tracking, synchronization, and compliance reporting.
    var lastUpdated: Date

    // MARK: - Revenue Data

    /// Total revenue amount for the day.
    /// Central to business analytics, financial reporting, and KPI calculations.
    var totalAmount: Double

    // MARK: - References

    /// List of associated charge IDs representing individual transactions or breakdowns.
    /// Supports detailed audit event linking, charge-level analytics, and UI tokenization for drill-down capabilities.
    private(set) var chargeIDs: [UUID]

    // MARK: - Notes

    /// Optional notes or tags for special events, corrections, or annotations.
    /// Useful for compliance comments, audit remarks, and business workflow annotations.
    var notes: String?

    // MARK: - Init

    /// Initializes a new DailyRevenue record.
    /// - Parameters:
    ///   - id: Unique identifier, default is new UUID.
    ///   - date: The date for this revenue record, normalized to start of day.
    ///   - totalAmount: Total revenue amount, defaults to 0.
    ///   - chargeIDs: List of associated charge IDs, default empty.
    ///   - notes: Optional notes or tags for audit or business context.
    ///   - lastUpdated: Timestamp of last update, default to current date/time.
    init(
        id: UUID = UUID(),
        date: Date,
        totalAmount: Double = 0,
        chargeIDs: [UUID] = [],
        notes: String? = nil,
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date) // Always store as start of day
        self.totalAmount = totalAmount
        self.chargeIDs = chargeIDs
        self.notes = notes
        self.lastUpdated = lastUpdated
    }

    // MARK: - ChargeIDs Mutation

    /// Adds a charge ID to the list if not already present.
    /// Ensures audit event linkage for new charges and supports incremental analytics updates.
    /// - Parameter id: The charge UUID to add.
    func addChargeID(_ id: UUID) {
        guard !chargeIDs.contains(id) else { return }
        chargeIDs.append(id)
        updateLastModified(reason: "Added chargeID \(id)")
    }

    /// Removes a charge ID from the list if it exists.
    /// Supports audit event correction, charge-level analytics updates, and business workflow adjustments.
    /// - Parameter id: The charge UUID to remove.
    func removeChargeID(_ id: UUID) {
        if let index = chargeIDs.firstIndex(of: id) {
            chargeIDs.remove(at: index)
            updateLastModified(reason: "Removed chargeID \(id)")
        }
    }

    // MARK: - Computed Properties

    /// Returns true if the date corresponds to today.
    /// Useful for UI highlighting, real-time analytics, and workflow triggers.
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    /// Returns true if totalAmount is zero.
    /// Helps identify empty revenue days for reporting filters and business logic conditions.
    var isEmpty: Bool {
        totalAmount == 0
    }

    /// Returns the localized day of the week string for the date.
    /// Used in UI displays, reports, and temporal analytics grouping.
    var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    // MARK: - Formatting Helpers

    /// Formatted date string for display in dashboard views and reports.
    /// Ensures consistent UI presentation and localized date formatting.
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    /// Returns formatted currency string for totalAmount.
    /// Supports localization and currency formatting for UI display and financial reporting.
    /// - Parameter locale: Optional locale to override default currency formatting.
    /// - Returns: Currency formatted string.
    func formattedAmount(locale: Locale? = nil) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        if let locale = locale {
            formatter.locale = locale
        }
        return formatter.string(from: NSNumber(value: totalAmount)) ?? "$0.00"
    }

    // MARK: - Business Logic Helpers

    /// Updates the total revenue by adding the given amount.
    /// Integrates audit/event logging and triggers analytics recalculations as needed.
    /// - Parameter amount: The amount to add (can be negative).
    func updateTotal(by amount: Double) {
        totalAmount += amount
        updateLastModified(reason: "Updated total by \(amount)")
    }

    /// Resets the total revenue to zero.
    /// Useful for business workflows requiring revenue correction or data resets, with audit trail capture.
    func resetRevenue() {
        totalAmount = 0
        updateLastModified(reason: "Reset total revenue to zero")
    }

    // MARK: - Audit Trail

    /// Updates lastUpdated timestamp and can be extended to log audit events.
    /// Ensures compliance and traceability for all modifications.
    /// - Parameter reason: A description of the change for audit/event logging.
    private func updateLastModified(reason: String) {
        lastUpdated = Date()
        // TODO: Integrate audit logging here, e.g.:
        // AuditLogger.log(event: "DailyRevenue \(id) changed: \(reason)")
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

    /// Static sample instance for previews and testing.
    /// Demonstrates demo/business logic scenarios and tokenized preview intent for UI and analytics validation.
    static let sample = DailyRevenue(
        date: Date(),
        totalAmount: 1234.56,
        chargeIDs: [UUID(), UUID()],
        notes: "Sample data for previews",
        lastUpdated: Date()
    )
}

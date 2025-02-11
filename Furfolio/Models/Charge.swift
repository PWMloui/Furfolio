//
//  Charge.swift
//  Furfolio
//
//  Created by mac on 12/20/24.
//  Updated on [Today's Date] with performance and personalization enhancements.

import Foundation
import SwiftData

@Model
final class Charge: Identifiable {
    @Attribute(.unique) var id: UUID
    var date: Date
    var type: ServiceType
    var amount: Double
    @Relationship(deleteRule: .nullify) var dogOwner: DogOwner
    var notes: String?
    var petBadges: [String]
    
    /// Preferred locale for currency formatting.
    /// Declared as a computed property so that it is not persisted.
    var preferredLocale: Locale {
        Locale.current
    }

    // MARK: - Enum for Service Types
    enum ServiceType: String, Codable, CaseIterable {
        case basic = "Basic Package"
        case full = "Full Package"
        case custom = "Custom Package"

        var localized: String {
            NSLocalizedString(self.rawValue, comment: "Localized description of \(self.rawValue)")
        }
    }

    // MARK: - Initializer
    init(date: Date, type: ServiceType, amount: Double, dogOwner: DogOwner, notes: String? = nil, petBadges: [String] = []) {
        self.id = UUID()
        self.date = date
        self.type = type
        self.amount = max(0, amount) // Prevent negative charges
        self.dogOwner = dogOwner
        self.notes = notes
        self.petBadges = petBadges
    }

    // MARK: - Static Cached Formatter
    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter
    }()
    
    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    // MARK: - Computed Properties

    /// Returns the charge amount formatted as a localized currency string.
    var formattedAmount: String {
        // Update the formatter's locale in case the preferredLocale has changed.
        Self.currencyFormatter.locale = preferredLocale
        return Self.currencyFormatter.string(from: NSNumber(value: amount)) ?? "\(Self.currencyFormatter.currencySymbol ?? "$")\(amount)"
    }

    /// Returns the charge date formatted as "MM/DD/YYYY".
    var formattedDate: String {
        date.formatted(.dateTime.month().day().year())
    }
    
    /// Returns a human-friendly relative date string (e.g., "2 days ago").
    var relativeDateString: String {
        Self.relativeDateFormatter.localizedString(for: date, relativeTo: Date())
    }
    
    /// Indicates whether the charge is valid (amount is positive and type is non-empty).
    var isValid: Bool {
        amount > 0 && !type.rawValue.isEmpty
    }
    
    /// Checks if the charge is overdue (i.e., the charge date is before today).
    var isOverdue: Bool {
        date < Calendar.current.startOfDay(for: Date())
    }
    
    /// Flags the charge as high-value if the amount exceeds a certain threshold (e.g., $100).
    var isHighValue: Bool {
        amount > 100
    }

    // MARK: - Methods

    /// Checks if the charge date falls within the given month and year.
    func isInMonth(_ month: Int, year: Int) -> Bool {
        let calendar = Calendar.current
        return calendar.component(.month, from: date) == month &&
               calendar.component(.year, from: date) == year
    }

    /// Applies a discount by reducing the charge amount based on the given percentage.
    /// Logs the discount applied for debugging purposes.
    func applyDiscount(_ percentage: Double) {
        guard percentage > 0 && percentage <= 100 else { return }
        let discountAmount = amount * (percentage / 100)
        amount -= discountAmount
        print("Applied discount of \(percentage)%: reduced charge by \(discountAmount). New amount: \(amount)")
    }

    /// Adds a badge to the charge if it isn't already present.
    func addBadge(_ badge: String) {
        guard !petBadges.contains(badge) else { return }
        petBadges.append(badge)
    }

    /// Analyzes the notes to determine behavioral insights.
    func analyzeBehavior() -> String {
        guard let notes = notes?.lowercased() else { return NSLocalizedString("Behavioral analysis: No significant behavioral notes.", comment: "Behavioral analysis result") }

        if notes.contains("anxious") {
            return NSLocalizedString("Behavioral analysis: Pet is anxious during appointments.", comment: "Behavioral analysis result")
        } else if notes.contains("aggressive") {
            return NSLocalizedString("Behavioral analysis: Pet showed signs of aggression.", comment: "Behavioral analysis result")
        }
        return NSLocalizedString("Behavioral analysis: No significant behavioral notes.", comment: "Behavioral analysis result")
    }

    // MARK: - Static Methods

    static func totalByType(charges: [Charge]) -> [ServiceType: Double] {
        charges.reduce(into: [ServiceType: Double]()) { totals, charge in
            totals[charge.type, default: 0] += charge.amount
        }
    }

    static func totalRevenue(forMonth month: Int, year: Int, charges: [Charge]) -> Double {
        charges.filter { $0.isInMonth(month, year: year) }
               .reduce(0) { $0 + $1.amount }
    }

    static func chargesForOwner(_ owner: DogOwner, from charges: [Charge]) -> [Charge] {
        charges.filter { $0.dogOwner.id == owner.id }
    }

    static func overdueCharges(from charges: [Charge]) -> [Charge] {
        charges.filter { $0.isOverdue }
    }

    static func categorizeByType(_ charges: [Charge]) -> [ServiceType: [Charge]] {
        charges.reduce(into: [ServiceType: [Charge]]()) { categorized, charge in
            categorized[charge.type, default: []].append(charge)
        }
    }

    static func chargesInDateRange(_ range: ClosedRange<Date>, from charges: [Charge]) -> [Charge] {
        charges.filter { range.contains($0.date) }
    }

    static func totalRevenue(for range: ClosedRange<Date>, from charges: [Charge]) -> Double {
        chargesInDateRange(range, from: charges)
            .reduce(0) { $0 + $1.amount }
    }

    static func averageCharge(for type: ServiceType, from charges: [Charge]) -> Double {
        let chargesOfType = charges.filter { $0.type == type }
        guard !chargesOfType.isEmpty else { return 0 }
        let totalAmount = chargesOfType.reduce(0) { $0 + $1.amount }
        return totalAmount / Double(chargesOfType.count)
    }

    // MARK: - New Methods

    /// Groups the charges for a given owner by month.
    static func chargesForOwnerGroupedByMonth(_ owner: DogOwner, from charges: [Charge]) -> [Int: [Charge]] {
        chargesForOwner(owner, from: charges).reduce(into: [Int: [Charge]]()) { grouped, charge in
            let month = Calendar.current.component(.month, from: charge.date)
            grouped[month, default: []].append(charge)
        }
    }

    /// Calculates the total revenue for each month for a given owner.
    static func totalRevenueGroupedByMonth(for owner: DogOwner, from charges: [Charge]) -> [Int: Double] {
        chargesForOwnerGroupedByMonth(owner, from: charges).reduce(into: [Int: Double]()) { totals, chargeGroup in
            let month = chargeGroup.key
            let totalAmount = chargeGroup.value.reduce(0) { $0 + $1.amount }
            totals[month] = totalAmount
        }
    }
}

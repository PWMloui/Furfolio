//
//  Charge.swift
//  Furfolio
//
//  Created by mac on 12/20/24.
//  Updated on [Today's Date] with performance, scalability, and documentation enhancements.

import Foundation
import SwiftData

@Model
final class Charge: Identifiable {
    // MARK: - Properties
    
    /// Unique identifier for the charge.
    @Attribute(.unique) var id: UUID
    
    /// Date when the charge is recorded.
    var date: Date
    
    /// Service type for the charge.
    var type: ServiceType
    
    /// Raw charge amount before discount and tax adjustments.
    var amount: Double
    
    /// Associated dog owner.
    @Relationship(deleteRule: .nullify) var dogOwner: DogOwner
    
    /// Optional additional notes.
    var notes: String?
    
    /// Associated appointment, if any.
    @Relationship(deleteRule: .nullify) var appointment: Appointment?
    
    // MARK: - Computed Properties
    
    /// Returns a summary description of the charge.
    var description: String {
        """
        Charge on \(formattedDate):
        Service: \(type.localized)
        Amount: \(formattedAmount)
        \(notes != nil ? "Notes: \(notes!)" : "")
        """
    }

    /// Returns a string emoji badge representing the customer's loyalty based on their total number of charges.
    ///
    /// - 🐾 First Timer: only 1 charge
    /// - 🔁 Monthly Regular: 2–9 charges
    /// - 🥇 Loyal Client: 10+ charges
    ///
    /// This property uses the associated dog owner's count of charges to determine the badge.
    var loyaltyBadge: String {
        // Count all charges for this dog owner, if available
        // If the dogOwner has a charges property, use it; otherwise, fallback to 1
        // (Assume DogOwner has a 'charges' property of type [Charge]?)
        let totalCharges: Int
        if let owner = dogOwner as? DogOwner, let allCharges = (owner as? AnyObject)?.value(forKey: "charges") as? [Charge] {
            totalCharges = allCharges.count
        } else {
            // Fallback: assume at least this charge
            totalCharges = 1
        }
        switch totalCharges {
        case 1:
            return "🐾 First Timer"
        case 2...9:
            return "🔁 Monthly Regular"
        default:
            return "🥇 Loyal Client"
        }
    }
    
    var lifetimeValue: Double {
        guard let owner = dogOwner as? DogOwner else { return amount }
        return owner.charges.reduce(0) { $0 + $1.amount }
    }
    
    var topSpenderBadge: String? {
        return lifetimeValue > 1000 ? "💸 Top Spender" : nil
    }
    
    /// Returns the preferred locale (from the current system settings).
    var preferredLocale: Locale { Locale.current }
    
    /// Returns the charge amount formatted as a currency string.
    var formattedAmount: String {
        Self.currencyFormatter.locale = preferredLocale
        return Self.currencyFormatter.string(from: NSNumber(value: amount)) ?? "\(Self.currencyFormatter.currencySymbol ?? "$")\(amount)"
    }
    
    /// Returns the charge date formatted as "MM/DD/YYYY".
    var formattedDate: String {
        date.formatted(.dateTime.month().day().year())
    }
    
    /// Returns a human-friendly relative date string (e.g. "2 days ago").
    var relativeDateString: String {
        Self.relativeDateFormatter.localizedString(for: date, relativeTo: Date())
    }
    
    /// Returns true if the charge date is before today.
    var isOverdue: Bool {
        date < Calendar.current.startOfDay(for: Date())
    }
    
    // MARK: - Enumerations
    
    /// Enumeration representing available service types.
    enum ServiceType: String, Codable, CaseIterable {
        case basic = "Basic Package"
        case full = "Full Package"
        case custom = "Custom Package"
        
        var localized: String {
            NSLocalizedString(self.rawValue, comment: "Localized description of \(self.rawValue)")
        }
    }
    
    // MARK: - Array Attribute with Transformer
    
    /// Stores profile badges securely as an array of strings.
    @Attribute(.transformable(by: NSValueTransformerName.secureUnarchiveFromDataTransformerName.rawValue))
    var petBadges: [String] = []
    
    // MARK: - Initializer
    
    init(
        date: Date,
        type: ServiceType,
        amount: Double,
        dogOwner: DogOwner,
        notes: String? = nil,
        petBadges: [String] = [],
        appointment: Appointment? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.type = type
        self.amount = max(0, amount) // Prevent negative charges.
        self.dogOwner = dogOwner
        self.notes = notes
        self.petBadges = petBadges
        self.appointment = appointment
    }
    
    // MARK: - Static Cached Formatters
    
    private static var currencyFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter
    }
    
    private static var relativeDateFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }
    
    // MARK: - Methods
    
    /// Adds a badge if it is not already present.
    func addBadge(_ badge: String) {
        guard !petBadges.contains(badge) else { return }
        petBadges.append(badge)
    }
    
    /// Analyzes the notes to generate a behavioral insight.
    func analyzeBehavior() -> String {
        guard let notes = notes?.lowercased() else {
            return NSLocalizedString("Behavioral analysis: No significant behavioral notes.", comment: "Behavioral analysis result")
        }
        if notes.contains("anxious") {
            return NSLocalizedString("Behavioral analysis: Pet is anxious during appointments.", comment: "Behavioral analysis result")
        } else if notes.contains("aggressive") {
            return NSLocalizedString("Behavioral analysis: Pet showed signs of aggression.", comment: "Behavioral analysis result")
        }
        return NSLocalizedString("Behavioral analysis: No significant behavioral notes.", comment: "Behavioral analysis result")
    }
    
    func isInMonth(_ month: Int, year: Int) -> Bool {
        let calendar = Calendar.current
        let chargeMonth = calendar.component(.month, from: date)
        let chargeYear = calendar.component(.year, from: date)
        return chargeMonth == month && chargeYear == year
    }
    
    // MARK: - Static Methods for Revenue and Charge Grouping
    
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
        chargesInDateRange(range, from: charges).reduce(0) { $0 + $1.amount }
    }
    
    static func averageCharge(for type: ServiceType, from charges: [Charge]) -> Double {
        let chargesOfType = charges.filter { $0.type == type }
        guard !chargesOfType.isEmpty else { return 0 }
        let totalAmount = chargesOfType.reduce(0) { $0 + $1.amount }
        return totalAmount / Double(chargesOfType.count)
    }
    
    // MARK: - Grouping Methods
    
    /// Groups charges for a given owner by month.
    static func chargesForOwnerGroupedByMonth(_ owner: DogOwner, from charges: [Charge]) -> [Int: [Charge]] {
        chargesForOwner(owner, from: charges).reduce(into: [Int: [Charge]]()) { grouped, charge in
            let month = Calendar.current.component(.month, from: charge.date)
            grouped[month, default: []].append(charge)
        }
    }
    
    /// Calculates the total revenue per month for a given owner.
    static func totalRevenueGroupedByMonth(for owner: DogOwner, from charges: [Charge]) -> [Int: Double] {
        chargesForOwnerGroupedByMonth(owner, from: charges).reduce(into: [Int: Double]()) { totals, chargeGroup in
            let month = chargeGroup.key
            let totalAmount = chargeGroup.value.reduce(0) { $0 + $1.amount }
            totals[month] = totalAmount
        }
    }
}

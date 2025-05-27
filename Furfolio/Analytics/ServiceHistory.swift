//
//  ServiceHistory.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on Jun 12, 2025 — fully qualified defaults and corrected SwiftUI preview.
//

import Foundation
import SwiftData
@Model
final class ServiceHistory: Identifiable, Hashable {
    
    /// Shared formatters to reduce allocations.
    private static let sharedDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
    private static let sharedCurrencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        return f
    }()
    
    // MARK: – Persistent Properties
    
    @Attribute
    var id: UUID = UUID()

    @Attribute
    var date: Date

    @Attribute
    var serviceType: Appointment.ServiceType

    @Attribute
    var durationMinutes: Int?

    @Attribute
    var cost: Double

    @Attribute
    var notes: String?

    @Relationship(deleteRule: .cascade)
    var dogOwner: DogOwner

    @Relationship(deleteRule: .nullify)
    var appointment: Appointment?

    @Attribute
    var createdAt: Date = Date.now

    @Attribute
    var updatedAt: Date?
    
    
    // MARK: – Initializer
    
    init(
        date: Date,
        serviceType: Appointment.ServiceType,
        durationMinutes: Int? = nil,
        cost: Double = 0,
        notes: String? = nil,
        dogOwner: DogOwner,
        appointment: Appointment? = nil
    ) {
        self.date = date
        self.serviceType = serviceType
        self.durationMinutes = durationMinutes.map { max(0, $0) }
        self.cost = max(0, cost)
        self.notes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.dogOwner = dogOwner
        self.appointment = appointment
    }
    
    
    // MARK: – Computed Properties
    
    @Transient
    var formattedDate: String {
        Self.sharedDateFormatter.string(from: date)
    }
    
    @Transient
    var formattedCost: String {
        Self.sharedCurrencyFormatter.string(from: NSNumber(value: cost))
            ?? String(format: "%.2f", cost)
    }
    
    @Transient
    var formattedDuration: String {
        guard let mins = durationMinutes, mins > 0 else { return "—" }
        let h = mins / 60, m = mins % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
    
    @Transient
    var costPerMinute: Double? {
        guard let mins = durationMinutes, mins > 0 else { return nil }
        return cost / Double(mins)
    }
    
    @Transient
    var formattedCostPerMinute: String? {
        guard let cpm = costPerMinute else { return nil }
        let costStr = Self.sharedCurrencyFormatter.string(from: NSNumber(value: cpm))
            ?? String(format: "%.2f", cpm)
        return "\(costStr)/min"
    }
    
    @Transient
    var summary: String {
        var parts = [
            "\(serviceType.localized) on \(formattedDate)",
            formattedCost
        ]
        if let dur = durationMinutes, dur > 0 {
            parts.append(formattedDuration)
        }
        if let txt = notes?.trimmingCharacters(in: .whitespacesAndNewlines), !txt.isEmpty {
            parts.append("Notes: \(txt)")
        }
        return parts.joined(separator: " • ")
    }
    
    @Transient
    var isValid: Bool {
        cost >= 0 && (durationMinutes.map { $0 >= 0 } ?? true)
    }
    
    
    // MARK: – Mutating
    
    /// Updates history fields and stamps `updatedAt`.
    func update(
        date: Date? = nil,
        serviceType: Appointment.ServiceType? = nil,
        durationMinutes: Int? = nil,
        cost: Double? = nil,
        notes: String? = nil,
        appointment: Appointment? = nil
    ) {
        if let d = date { self.date = d }
        if let t = serviceType { self.serviceType = t }
        if let m = durationMinutes { self.durationMinutes = max(0, m) }
        if let c = cost { self.cost = max(0, c) }
        if let n = notes?.trimmingCharacters(in: .whitespacesAndNewlines) { self.notes = n }
        if let appt = appointment { self.appointment = appt }
        self.updatedAt = Date.now
    }
    
    
    // MARK: – Create & Fetch Helpers
    
    /// Creates and inserts a new ServiceHistory entry, enforcing non-negative defaults.
    @discardableResult
    static func create(
        date: Date,
        serviceType: Appointment.ServiceType,
        durationMinutes: Int? = nil,
        cost: Double = 0,
        notes: String? = nil,
        owner: DogOwner,
        appointment: Appointment? = nil,
        in context: ModelContext
    ) -> ServiceHistory {
        let entry = ServiceHistory(
            date: date,
            serviceType: serviceType,
            durationMinutes: durationMinutes,
            cost: cost,
            notes: notes,
            dogOwner: owner,
            appointment: appointment
        )
        context.insert(entry)
        return entry
    }
    
    /// Fetches all ServiceHistory entries in reverse date order.
    static func fetchAll(in context: ModelContext) -> [ServiceHistory] {
        let desc = FetchDescriptor<ServiceHistory>(
            sortBy: [SortDescriptor(\ServiceHistory.date, order: .reverse)]
        )
        return (try? context.fetch(desc)) ?? []
    }
    
    /// Fetches ServiceHistory entries for a specific owner, newest first.
    static func fetchAll(for owner: DogOwner, in context: ModelContext) -> [ServiceHistory] {
        let desc = FetchDescriptor<ServiceHistory>(
            predicate: #Predicate { $0.dogOwner.id == owner.id },
            sortBy: [SortDescriptor(\ServiceHistory.date, order: .reverse)]
        )
        return (try? context.fetch(desc)) ?? []
    }
    
    /// Fetches ServiceHistory entries for a specific appointment, newest first.
    static func fetchAll(for appointment: Appointment, in context: ModelContext) -> [ServiceHistory] {
        let desc = FetchDescriptor<ServiceHistory>(
            predicate: #Predicate { $0.appointment?.id == appointment.id },
            sortBy: [SortDescriptor(\ServiceHistory.date, order: .reverse)]
        )
        return (try? context.fetch(desc)) ?? []
    }
    
    
    // MARK: – Analytics Extensions
    
    /// Total revenue over a set of histories.
    static func totalRevenue(for histories: [ServiceHistory]) -> Double {
        histories.reduce(0) { $0 + $1.cost }
    }
    
    /// Average appointment duration over histories.
    static func averageDuration(for histories: [ServiceHistory]) -> Double {
        let durs = histories.compactMap(\.durationMinutes).map(Double.init)
        guard !durs.isEmpty else { return 0 }
        return durs.reduce(0, +) / Double(durs.count)
    }
    
    /// Appointment count grouped by service type.
    static func frequencyByService(_ histories: [ServiceHistory]) -> [Appointment.ServiceType: Int] {
        histories.reduce(into: [:]) { counts, entry in
            counts[entry.serviceType, default: 0] += 1
        }
    }
    
    /// Revenue grouped by service type.
    static func revenueByService(_ histories: [ServiceHistory]) -> [Appointment.ServiceType: Double] {
        histories.reduce(into: [:]) { sums, entry in
            sums[entry.serviceType, default: 0] += entry.cost
        }
    }
    
    /// Computes combined metrics (count, average duration, total revenue) for each service type.
    /// - Parameter histories: Array of ServiceHistory records.
    /// - Returns: Dictionary mapping each service type to a tuple of (count, averageDuration, totalRevenue).
    ///
    /// - Note: This method and class are both annotated with `@MainActor`.
    ///         Use only on the main thread.
    /// Tuple representing aggregated metrics for a service type.
    typealias ServiceHistoryMetrics = (count: Int, averageDuration: Double, totalRevenue: Double)
    static func metrics(
        for histories: [ServiceHistory]
    ) -> [Appointment.ServiceType: ServiceHistoryMetrics] {
        let freq = frequencyByService(histories)
        let rev  = revenueByService(histories)
        
        return Appointment.ServiceType.allCases.reduce(into: [:]) { result, type in
            let count = freq[type] ?? 0
            let revenue = rev[type] ?? 0
            let durs = histories
                .filter { $0.serviceType == type }
                .compactMap(\.durationMinutes)
                .map(Double.init)
            let avgDur = durs.isEmpty ? 0 : durs.reduce(0, +) / Double(durs.count)
            result[type] = (count, avgDur, revenue)
        }
    }
    
    
    // MARK: – Hashable
    
    static func == (lhs: ServiceHistory, rhs: ServiceHistory) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
}

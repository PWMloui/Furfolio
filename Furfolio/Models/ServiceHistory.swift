//
//  ServiceHistory.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//  Updated on Jun 12, 2025 — fully qualified defaults and corrected SwiftUI preview.
//

import Foundation
import SwiftData
import os

@MainActor
@Model
final class ServiceHistory: Identifiable, Hashable {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "ServiceHistory")
    
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
        logger.log("Initialized ServiceHistory id: \(id), date: \(date), serviceType: \(serviceType.rawValue), cost: \(cost)")
    }
    
    
    // MARK: – Computed Properties
    
    @Transient
    var formattedDate: String {
        logger.log("Accessing formattedDate for ServiceHistory id: \(id)")
        let result = Self.sharedDateFormatter.string(from: date)
        logger.log("formattedDate result: \(result)")
        return result
    }
    
    @Transient
    var formattedCost: String {
        logger.log("Accessing formattedCost: cost=\(cost)")
        let result = Self.sharedCurrencyFormatter.string(from: NSNumber(value: cost))
            ?? String(format: "%.2f", cost)
        logger.log("formattedCost result: \(result)")
        return result
    }
    
    @Transient
    var formattedDuration: String {
        logger.log("Accessing formattedDuration: durationMinutes=\(String(describing: durationMinutes))")
        guard let mins = durationMinutes, mins > 0 else {
            logger.log("formattedDuration result: —")
            return "—"
        }
        let h = mins / 60, m = mins % 60
        let result = h > 0 ? "\(h)h \(m)m" : "\(m)m"
        logger.log("formattedDuration result: \(result)")
        return result
    }
    
    @Transient
    var costPerMinute: Double? {
        logger.log("Accessing costPerMinute: durationMinutes=\(String(describing: durationMinutes)), cost=\(cost)")
        guard let mins = durationMinutes, mins > 0 else {
            logger.log("costPerMinute result: nil")
            return nil
        }
        let result = cost / Double(mins)
        logger.log("costPerMinute result: \(result)")
        return result
    }
    
    @Transient
    var formattedCostPerMinute: String? {
        logger.log("Accessing formattedCostPerMinute")
        guard let cpm = costPerMinute else {
            logger.log("formattedCostPerMinute result: nil")
            return nil
        }
        let costStr = Self.sharedCurrencyFormatter.string(from: NSNumber(value: cpm))
            ?? String(format: "%.2f", cpm)
        let result = "\(costStr)/min"
        logger.log("formattedCostPerMinute result: \(result)")
        return result
    }
    
    @Transient
    var summary: String {
        logger.log("Generating summary for ServiceHistory id: \(id)")
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
        let result = parts.joined(separator: " • ")
        logger.log("summary result: \(result)")
        return result
    }
    
    @Transient
    var isValid: Bool {
        logger.log("Checking isValid for ServiceHistory id: \(id)")
        let result = cost >= 0 && (durationMinutes.map { $0 >= 0 } ?? true)
        logger.log("isValid result: \(result)")
        return result
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
        logger.log("Updating ServiceHistory \(id) with values date=\(String(describing: date)), serviceType=\(String(describing: serviceType)), durationMinutes=\(String(describing: durationMinutes)), cost=\(String(describing: cost)), notes=\(String(describing: notes))")
        if let d = date { self.date = d }
        if let t = serviceType { self.serviceType = t }
        if let m = durationMinutes { self.durationMinutes = max(0, m) }
        if let c = cost { self.cost = max(0, c) }
        if let n = notes?.trimmingCharacters(in: .whitespacesAndNewlines) { self.notes = n }
        if let appt = appointment { self.appointment = appt }
        self.updatedAt = Date.now
        logger.log("Updated ServiceHistory \(id) at \(updatedAt!)")
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
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "ServiceHistory")
        logger.log("Creating ServiceHistory entry for owner: \(owner.id), appointment: \(String(describing: appointment?.id))")
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
        entry.updatedAt = entry.createdAt
        logger.log("Created ServiceHistory id: \(entry.id)")
        return entry
    }
    
    /// Fetches all ServiceHistory entries in reverse date order.
    static func fetchAll(in context: ModelContext) -> [ServiceHistory] {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "ServiceHistory")
        logger.log("Fetching ServiceHistory entries: all")
        let results = (try? context.fetch(FetchDescriptor<ServiceHistory>(
            sortBy: [SortDescriptor(\ServiceHistory.date, order: .reverse)]
        ))) ?? []
        logger.log("Fetched \(results.count) ServiceHistory entries")
        return results
    }
    
    /// Fetches ServiceHistory entries for a specific owner, newest first.
    static func fetchAll(for owner: DogOwner, in context: ModelContext) -> [ServiceHistory] {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "ServiceHistory")
        logger.log("Fetching ServiceHistory entries: owner \(owner.id)")
        let results = (try? context.fetch(FetchDescriptor<ServiceHistory>(
            predicate: #Predicate { $0.dogOwner.id == owner.id },
            sortBy: [SortDescriptor(\ServiceHistory.date, order: .reverse)]
        ))) ?? []
        logger.log("Fetched \(results.count) ServiceHistory entries")
        return results
    }
    
    /// Fetches ServiceHistory entries for a specific appointment, newest first.
    static func fetchAll(for appointment: Appointment, in context: ModelContext) -> [ServiceHistory] {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "ServiceHistory")
        logger.log("Fetching ServiceHistory entries: appointment \(appointment.id)")
        let results = (try? context.fetch(FetchDescriptor<ServiceHistory>(
            predicate: #Predicate { $0.appointment?.id == appointment.id },
            sortBy: [SortDescriptor(\ServiceHistory.date, order: .reverse)]
        ))) ?? []
        logger.log("Fetched \(results.count) ServiceHistory entries")
        return results
    }

    /// Async fetch all ServiceHistory entries in reverse date order.
    static func fetchAllAsync(in context: ModelContext) async throws -> [ServiceHistory] {
        try await context.perform {
            let desc = FetchDescriptor<ServiceHistory>(
                sortBy: [SortDescriptor(\ServiceHistory.date, order: .reverse)]
            )
            return try context.fetch(desc)
        }
    }

    /// Async fetch ServiceHistory entries for a specific owner, newest first.
    static func fetchAllAsync(for owner: DogOwner, in context: ModelContext) async throws -> [ServiceHistory] {
        try await context.perform {
            let desc = FetchDescriptor<ServiceHistory>(
                predicate: #Predicate { $0.dogOwner.id == owner.id },
                sortBy: [SortDescriptor(\ServiceHistory.date, order: .reverse)]
            )
            return try context.fetch(desc)
        }
    }
    
    
    // MARK: – Analytics Extensions
    
    /// Total revenue over a set of histories.
    static func totalRevenue(for histories: [ServiceHistory]) -> Double {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "ServiceHistory")
        logger.log("Computing totalRevenue for \(histories.count) histories")
        let result = histories.reduce(0) { $0 + $1.cost }
        logger.log("totalRevenue result: \(result)")
        return result
    }
    
    /// Average appointment duration over histories.
    static func averageDuration(for histories: [ServiceHistory]) -> Double {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "ServiceHistory")
        logger.log("Computing averageDuration for \(histories.count) histories")
        let durs = histories.compactMap(\.durationMinutes).map(Double.init)
        guard !durs.isEmpty else {
            logger.log("averageDuration result: 0")
            return 0
        }
        let result = durs.reduce(0, +) / Double(durs.count)
        logger.log("averageDuration result: \(result)")
        return result
    }
    
    /// Appointment count grouped by service type.
    static func frequencyByService(_ histories: [ServiceHistory]) -> [Appointment.ServiceType: Int] {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "ServiceHistory")
        logger.log("Computing frequencyByService for \(histories.count) histories")
        let result = histories.reduce(into: [:]) { counts, entry in
            counts[entry.serviceType, default: 0] += 1
        }
        logger.log("frequencyByService result: \(result)")
        return result
    }
    
    /// Revenue grouped by service type.
    static func revenueByService(_ histories: [ServiceHistory]) -> [Appointment.ServiceType: Double] {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "ServiceHistory")
        logger.log("Computing revenueByService for \(histories.count) histories")
        let result = histories.reduce(into: [:]) { sums, entry in
            sums[entry.serviceType, default: 0] += entry.cost
        }
        logger.log("revenueByService result: \(result)")
        return result
    }
    
    /// Computes combined metrics (count, average duration, total revenue) for each service type.
    /// - Parameter histories: Array of ServiceHistory records.
    /// - Returns: Dictionary mapping each service type to a tuple of (count, averageDuration, totalRevenue).
    ///
    /// - Note: This method and class are both annotated with `@MainActor`.
    ///         Use only on the main thread.
    /// Tuple representing aggregated metrics for a service type.
    typealias ServiceHistoryMetrics = (count: Int, averageDuration: Double, totalRevenue: Double)

    nonisolated static func metrics(
        for histories: [ServiceHistory]
    ) -> [Appointment.ServiceType: ServiceHistoryMetrics] {
        let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "ServiceHistory")
        logger.log("Computing metrics for \(histories.count) histories")
        let freq = frequencyByService(histories)
        let rev  = revenueByService(histories)
        
        let result = Appointment.ServiceType.allCases.reduce(into: [:]) { result, type in
            let count = freq[type] ?? 0
            let revenue = rev[type] ?? 0
            let durs = histories
                .filter { $0.serviceType == type }
                .compactMap(\.durationMinutes)
                .map(Double.init)
            let avgDur = durs.isEmpty ? 0 : durs.reduce(0, +) / Double(durs.count)
            result[type] = (count, avgDur, revenue)
        }
        logger.log("metrics result: \(result)")
        return result
    }
    
    static func metricsAsync(
        for histories: [ServiceHistory]
    ) async -> [Appointment.ServiceType: ServiceHistoryMetrics] {
        return await Task.detached(priority: .userInitiated) { metrics(for: histories) }.value
    }
    
    
    // MARK: – Hashable
    
    static func == (lhs: ServiceHistory, rhs: ServiceHistory) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
}
public protocol EquatableBytes: Equatable {
    init(bytes: [UInt8])
    var bytes: [UInt8] { get }
}

//
//  DashboardViewModel.swift
//  Furfolio
//
//  Enterprise 2025+: Observability, Analytics, Diagnostics, Modular
//

import Foundation
import Combine

// MARK: - Audit/Event Logging

fileprivate struct DashboardAuditEvent: Codable {
    let timestamp: Date
    let operation: String      // "refresh", "update", "propertyChanged"
    let upcomingAppointmentsCount: Int
    let totalRevenue: Double
    let inactiveCustomersCount: Int
    let loyaltyProgress: Double
    let isLoading: Bool
    let errorMessage: String?
    let tags: [String]
    let detail: String?
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        var label = "[\(operation.capitalized)] Appointments: \(upcomingAppointmentsCount), Revenue: $\(String(format: "%.2f", totalRevenue)), Inactive: \(inactiveCustomersCount), Loyalty: \(Int(loyaltyProgress*100))%"
        if isLoading { label += " [Loading]" }
        if let err = errorMessage { label += " [Error: \(err)]" }
        if !tags.isEmpty { label += " [\(tags.joined(separator: ","))]" }
        label += " at \(dateStr)"
        if let d = detail, !d.isEmpty { label += ": \(d)" }
        return label
    }
}

fileprivate final class DashboardAudit {
    static private(set) var log: [DashboardAuditEvent] = []

    static func record(
        operation: String,
        appointments: Int,
        revenue: Double,
        inactive: Int,
        loyalty: Double,
        isLoading: Bool,
        errorMessage: String?,
        tags: [String] = [],
        detail: String? = nil
    ) {
        let event = DashboardAuditEvent(
            timestamp: Date(),
            operation: operation,
            upcomingAppointmentsCount: appointments,
            totalRevenue: revenue,
            inactiveCustomersCount: inactive,
            loyaltyProgress: loyalty,
            isLoading: isLoading,
            errorMessage: errorMessage,
            tags: tags,
            detail: detail
        )
        log.append(event)
        if log.count > 100 { log.removeFirst() }
        // Optional: Broadcast to external analytics (BI, logging service, etc)
        externalAuditHandler?(event)
    }

    // Analytics & BI integration hook (optional, settable from outside)
    static var externalAuditHandler: ((DashboardAuditEvent) -> Void)? = nil

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No dashboard events recorded."
    }
}

// MARK: - Data Source Protocol

protocol DashboardDataSource {
    func fetchUpcomingAppointments() async throws -> Int
    func fetchTotalRevenue() async throws -> Double
    func fetchInactiveCustomers() async throws -> Int
    func fetchLoyaltyProgress() async throws -> Double
}

// MARK: - Live Data Source Implementation

struct DashboardLiveDataSource: DashboardDataSource {
    func fetchUpcomingAppointments() async throws -> Int { Int.random(in: 0...10) }
    func fetchTotalRevenue() async throws -> Double { Double.random(in: 1000...10000) }
    func fetchInactiveCustomers() async throws -> Int { Int.random(in: 0...5) }
    func fetchLoyaltyProgress() async throws -> Double { Double.random(in: 0...1) }
}

// MARK: - ViewModel for the dashboard, with full observability and DI

@MainActor
class DashboardViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var upcomingAppointmentsCount: Int = 0 {
        didSet { propertyChangedAudit("upcomingAppointmentsCount") }
    }
    @Published var totalRevenue: Double = 0.0 {
        didSet { propertyChangedAudit("totalRevenue") }
    }
    @Published var inactiveCustomersCount: Int = 0 {
        didSet { propertyChangedAudit("inactiveCustomersCount") }
    }
    @Published var loyaltyProgress: Double = 0.0 {
        didSet { propertyChangedAudit("loyaltyProgress") }
    }
    @Published var isLoading: Bool = false {
        didSet { propertyChangedAudit("isLoading") }
    }
    @Published var errorMessage: String? = nil {
        didSet { propertyChangedAudit("errorMessage") }
    }

    // For preview, test, and swap-out
    private let dataSource: DashboardDataSource

    // MARK: - Initialization

    init(dataSource: DashboardDataSource = DashboardLiveDataSource()) {
        self.dataSource = dataSource
        Task {
            await refreshData()
        }
    }

    // MARK: - Public Methods

    /// Refreshes all dashboard data asynchronously
    func refreshData() async {
        isLoading = true
        errorMessage = nil
        DashboardAudit.record(
            operation: "refresh",
            appointments: upcomingAppointmentsCount,
            revenue: totalRevenue,
            inactive: inactiveCustomersCount,
            loyalty: loyaltyProgress,
            isLoading: isLoading,
            errorMessage: errorMessage,
            tags: ["refresh", "start"]
        )
        do {
            // You can fetch in parallel in production
            async let a = dataSource.fetchUpcomingAppointments()
            async let r = dataSource.fetchTotalRevenue()
            async let i = dataSource.fetchInactiveCustomers()
            async let l = dataSource.fetchLoyaltyProgress()
            upcomingAppointmentsCount = try await a
            totalRevenue = try await r
            inactiveCustomersCount = try await i
            loyaltyProgress = try await l

            DashboardAudit.record(
                operation: "update",
                appointments: upcomingAppointmentsCount,
                revenue: totalRevenue,
                inactive: inactiveCustomersCount,
                loyalty: loyaltyProgress,
                isLoading: false,
                errorMessage: nil,
                tags: ["refresh", "success"],
                detail: "Dashboard updated"
            )
        } catch {
            errorMessage = "Failed to load dashboard data."
            DashboardAudit.record(
                operation: "update",
                appointments: upcomingAppointmentsCount,
                revenue: totalRevenue,
                inactive: inactiveCustomersCount,
                loyalty: loyaltyProgress,
                isLoading: false,
                errorMessage: errorMessage,
                tags: ["refresh", "error"],
                detail: "Refresh failed"
            )
        }
        isLoading = false
    }

    // MARK: - Accessibility & Observability

    var dashboardAccessibilitySummary: String {
        "You have \(upcomingAppointmentsCount) upcoming appointments, total revenue is $\(Int(totalRevenue)), \(inactiveCustomersCount) inactive customers, loyalty progress at \(Int(loyaltyProgress * 100)) percent."
    }

    // MARK: - Audit/Admin Accessors

    var lastAuditSummary: String { DashboardAudit.accessibilitySummary }
    var lastAuditJSON: String? { DashboardAudit.exportLastJSON() }
    func recentAuditEvents(limit: Int = 5) -> [String] {
        DashboardAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }

    // MARK: - Diagnostics

    /// Call this to subscribe to all audit events in real time (e.g., for analytics).
    static func setExternalAuditHandler(_ handler: @escaping (Any) -> Void) {
        DashboardAudit.externalAuditHandler = { event in handler(event) }
    }

    // MARK: - Private

    private func propertyChangedAudit(_ property: String) {
        DashboardAudit.record(
            operation: "propertyChanged",
            appointments: upcomingAppointmentsCount,
            revenue: totalRevenue,
            inactive: inactiveCustomersCount,
            loyalty: loyaltyProgress,
            isLoading: isLoading,
            errorMessage: errorMessage,
            tags: ["propertyChanged", property],
            detail: "Property \(property) changed"
        )
    }
}

// MARK: - SwiftUI Preview

#if DEBUG
import SwiftUI

struct DashboardViewModel_Previews: PreviewProvider {
    @StateObject static var viewModel = DashboardViewModel()

    static var previews: some View {
        VStack(spacing: 16) {
            Text("Upcoming Appointments: \(viewModel.upcomingAppointmentsCount)")
            Text("Total Revenue: $\(String(format: "%.2f", viewModel.totalRevenue))")
            Text("Inactive Customers: \(viewModel.inactiveCustomersCount)")
            Text("Loyalty Progress: \(Int(viewModel.loyaltyProgress * 100))%")

            if viewModel.isLoading {
                ProgressView()
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
            }

            // Admin/audit view
            if let lastJSON = viewModel.lastAuditJSON {
                Text("Last Audit:").font(.caption.bold())
                ScrollView { Text(lastJSON).font(.caption2).lineLimit(10) }
            }
        }
        .padding()
        .task {
            await viewModel.refreshData()
        }
    }
}
#endif

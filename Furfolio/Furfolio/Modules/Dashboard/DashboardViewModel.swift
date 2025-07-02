//
//  DashboardViewModel.swift
//  Furfolio
//
//  Enterprise 2025+: Observability, Analytics, Diagnostics, Modular
//

import Foundation
import Combine
import SwiftUI
import AVFoundation

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

    /// Records a new audit event and posts a VoiceOver announcement for accessibility.
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
        
        // Accessibility: Post VoiceOver announcement for dashboard event
        let announcement = "Dashboard event: \(operation), Revenue: $\(String(format: "%.2f", revenue)), Appointments: \(appointments), Inactive: \(inactive), Loyalty: \(Int(loyalty * 100)) percent."
        DispatchQueue.main.async {
            UIAccessibility.post(notification: .announcement, argument: announcement)
        }
    }

    // Analytics & BI integration hook (optional, settable from outside)
    static var externalAuditHandler: ((DashboardAuditEvent) -> Void)? = nil

    /// Exports the last audit event as a pretty-printed JSON string.
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    
    /// Exports all audit events as a CSV string with headers:
    /// timestamp,operation,upcomingAppointmentsCount,totalRevenue,inactiveCustomersCount,loyaltyProgress,isLoading,errorMessage,tags,detail
    static func exportCSV() -> String {
        let headers = ["timestamp","operation","upcomingAppointmentsCount","totalRevenue","inactiveCustomersCount","loyaltyProgress","isLoading","errorMessage","tags","detail"]
        var csvRows = [headers.joined(separator: ",")]
        let formatter = ISO8601DateFormatter()
        for event in log {
            let timestamp = formatter.string(from: event.timestamp)
            let operation = event.operation
            let appointments = String(event.upcomingAppointmentsCount)
            let revenue = String(format: "%.2f", event.totalRevenue)
            let inactive = String(event.inactiveCustomersCount)
            let loyalty = String(format: "%.4f", event.loyaltyProgress)
            let loading = event.isLoading ? "true" : "false"
            let errorMsg = event.errorMessage?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""
            let errorQuoted = errorMsg.isEmpty ? "" : "\"\(errorMsg)\""
            let tags = event.tags.joined(separator: ";").replacingOccurrences(of: "\"", with: "\"\"")
            let tagsQuoted = tags.isEmpty ? "" : "\"\(tags)\""
            let detail = event.detail?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""
            let detailQuoted = detail.isEmpty ? "" : "\"\(detail)\""
            let row = [timestamp, operation, appointments, revenue, inactive, loyalty, loading, errorQuoted, tagsQuoted, detailQuoted].joined(separator: ",")
            csvRows.append(row)
        }
        return csvRows.joined(separator: "\n")
    }
    
    /// Returns the operation string with the highest frequency in audit logs.
    static var mostFrequentOperation: String? {
        guard !log.isEmpty else { return nil }
        let freq = Dictionary(grouping: log, by: { $0.operation }).mapValues { $0.count }
        return freq.max(by: { $0.value < $1.value })?.key
    }
    
    /// Returns the average totalRevenue across all audit events.
    static var averageRevenue: Double {
        guard !log.isEmpty else { return 0.0 }
        let total = log.reduce(0.0) { $0 + $1.totalRevenue }
        return total / Double(log.count)
    }
    
    /// Returns the total number of audit events recorded.
    static var totalAuditEvents: Int {
        log.count
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
    
    /// Exposes the CSV export of all audit events.
    static var exportCSV: String {
        DashboardAudit.exportCSV()
    }
    
    /// Exposes the most frequent operation in audit logs.
    static var mostFrequentOperation: String? {
        DashboardAudit.mostFrequentOperation
    }
    
    /// Exposes the average revenue across audit logs.
    static var averageRevenue: Double {
        DashboardAudit.averageRevenue
    }
    
    /// Exposes the total number of audit events recorded.
    static var totalAuditEvents: Int {
        DashboardAudit.totalAuditEvents
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

// MARK: - SwiftUI Preview and Debug Overlay

#if DEBUG
import SwiftUI

/// A SwiftUI overlay view for developers that shows recent audit events and analytics info.
struct DashboardAuditOverlay: View {
    @ObservedObject private var viewModel = DashboardViewModel()
    
    private var recentEvents: [String] {
        DashboardAudit.log.suffix(3).map { $0.accessibilityLabel }.reversed()
    }
    
    private var mostFrequentOp: String {
        DashboardAudit.mostFrequentOperation ?? "N/A"
    }
    
    private var avgRevenue: String {
        String(format: "%.2f", DashboardAudit.averageRevenue)
    }
    
    private var totalEvents: Int {
        DashboardAudit.totalAuditEvents
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dashboard Audit Overlay")
                .font(.headline)
            Divider()
            Text("Recent Events:")
                .font(.subheadline).bold()
            ForEach(recentEvents, id: \.self) { event in
                Text(event)
                    .font(.caption2)
                    .lineLimit(3)
                    .minimumScaleFactor(0.5)
            }
            Divider()
            Text("Most Frequent Operation: \(mostFrequentOp)")
                .font(.caption)
            Text("Average Revenue: $\(avgRevenue)")
                .font(.caption)
            Text("Total Audit Events: \(totalEvents)")
                .font(.caption)
        }
        .padding(12)
        .background(Color(.systemBackground).opacity(0.9))
        .cornerRadius(8)
        .shadow(radius: 4)
        .frame(maxWidth: 350)
        .padding()
    }
}

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
            
            // Show the audit overlay in debug
            DashboardAuditOverlay()
        }
        .padding()
        .task {
            await viewModel.refreshData()
        }
    }
}
#endif

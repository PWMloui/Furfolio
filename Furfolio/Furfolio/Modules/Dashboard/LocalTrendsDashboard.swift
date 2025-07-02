//
//  LocalTrendsDashboard.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//


//
//  LocalTrendsDashboard.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Audit event struct for LocalTrendsDashboard actions.
/// Logs timestamp, operation, location, filter, summaryStats, tags, actor, context, detail.
public struct LocalTrendsDashboardAuditEvent: Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let operation: String
    public let location: String
    public let filter: String
    public let summaryStats: String
    public let tags: [String]
    public let actor: String
    public let context: String
    public let detail: String
    
    public init(timestamp: Date = Date(),
                operation: String,
                location: String,
                filter: String,
                summaryStats: String,
                tags: [String] = [],
                actor: String = "",
                context: String = "",
                detail: String = "") {
        self.id = UUID()
        self.timestamp = timestamp
        self.operation = operation
        self.location = location
        self.filter = filter
        self.summaryStats = summaryStats
        self.tags = tags
        self.actor = actor
        self.context = context
        self.detail = detail
    }
}

/// Audit logger for LocalTrendsDashboard events.
/// Stores events in-memory for analytics and admin.
public class LocalTrendsDashboardAudit: ObservableObject {
    public static let shared = LocalTrendsDashboardAudit()
    
    @Published private(set) public var events: [LocalTrendsDashboardAuditEvent] = []
    
    private init() {}
    
    /// Log a dashboard event.
    public func log(operation: String,
                   location: String,
                   filter: String,
                   summaryStats: String,
                   tags: [String] = [],
                   actor: String = "",
                   context: String = "",
                   detail: String = "") {
        let event = LocalTrendsDashboardAuditEvent(
            operation: operation,
            location: location,
            filter: filter,
            summaryStats: summaryStats,
            tags: tags,
            actor: actor,
            context: context,
            detail: detail
        )
        events.append(event)
    }
    
    /// Computed property: number of "load" events.
    public var totalLoads: Int {
        events.filter { $0.operation == "load" }.count
    }
    
    /// Computed property: most frequently loaded location.
    public var mostFrequentLocation: String? {
        let loads = events.filter { $0.operation == "load" }
        let counts = Dictionary(grouping: loads, by: { $0.location }).mapValues { $0.count }
        return counts.max { $0.value < $1.value }?.key
    }
    
    /// Computed property: most frequently used filter.
    public var mostFrequentFilter: String? {
        let filterEvents = events.filter { !$0.filter.isEmpty }
        let counts = Dictionary(grouping: filterEvents, by: { $0.filter }).mapValues { $0.count }
        return counts.max { $0.value < $1.value }?.key
    }
}

/// Admin interface for LocalTrendsDashboard audit log and analytics.
public class LocalTrendsDashboardAuditAdmin {
    public static let shared = LocalTrendsDashboardAuditAdmin()
    private let audit = LocalTrendsDashboardAudit.shared
    
    /// Last audit event as a readable string.
    public var lastSummary: String {
        guard let last = audit.events.last else { return "No events." }
        return "[\(last.timestamp)] \(last.operation) @ \(last.location) filter: \(last.filter) stats: \(last.summaryStats)"
    }
    
    /// Last audit event as JSON.
    public var lastJSON: String {
        guard let last = audit.events.last else { return "{}" }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(last), let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{}"
    }
    
    /// Recent N events (most recent first).
    public func recentEvents(limit: Int = 10) -> [LocalTrendsDashboardAuditEvent] {
        Array(audit.events.suffix(limit).reversed())
    }
    
    /// Export all events as CSV.
    public func exportCSV() -> String {
        let header = "timestamp,operation,location,filter,summaryStats,tags,actor,context,detail"
        let rows = audit.events.map { event in
            let tagsStr = event.tags.joined(separator: ";")
            let csv = [
                Self.escape(event.timestamp.description),
                Self.escape(event.operation),
                Self.escape(event.location),
                Self.escape(event.filter),
                Self.escape(event.summaryStats),
                Self.escape(tagsStr),
                Self.escape(event.actor),
                Self.escape(event.context),
                Self.escape(event.detail)
            ].joined(separator: ",")
            return csv
        }
        return ([header] + rows).joined(separator: "\n")
    }
    
    private static func escape(_ s: String) -> String {
        // Basic CSV escaping
        if s.contains(",") || s.contains("\"") || s.contains("\n") {
            return "\"\(s.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return s
    }
    
    /// Analytics: total number of load events.
    public var totalLoads: Int { audit.totalLoads }
    /// Analytics: most frequently loaded location.
    public var mostFrequentLocation: String? { audit.mostFrequentLocation }
    /// Analytics: most frequently used filter.
    public var mostFrequentFilter: String? { audit.mostFrequentFilter }
}

#if DEBUG
/// DEV overlay view showing last 3 audit events and analytics.
struct LocalTrendsDashboardAuditDevOverlay: View {
    @ObservedObject var audit = LocalTrendsDashboardAudit.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Audit (last 3):").font(.caption).bold()
            ForEach(audit.events.suffix(3).reversed()) { event in
                Text("[\(event.operation)] \(event.location) filter: \(event.filter)")
                    .font(.caption2)
            }
            Divider()
            HStack {
                Text("Loads: \(audit.totalLoads)").font(.caption2)
                if let loc = audit.mostFrequentLocation {
                    Text("Top Loc: \(loc)").font(.caption2)
                }
                if let filt = audit.mostFrequentFilter {
                    Text("Top Filter: \(filt)").font(.caption2)
                }
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.7))
        .foregroundColor(.white)
        .cornerRadius(10)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif

// MARK: - Accessibility VoiceOver Announcement
/// Posts a VoiceOver announcement for dashboard updates.
func announceDashboardUpdate(operation: String, location: String, filter: String) {
#if canImport(UIKit)
    let announcement = "Local trends dashboard updated: \(operation), \(location), filter: \(filter)."
    UIAccessibility.post(notification: .announcement, argument: announcement)
#endif
}

// MARK: - Example usage in Dashboard View (pseudo-code)
/*
struct LocalTrendsDashboard: View {
    @State private var location: String = "San Francisco"
    @State private var filter: String = "All"
    @State private var summaryStats: String = "Total: 123"
    // ...
    var body: some View {
        VStack {
            // ... dashboard content ...
        }
        .onAppear {
            // Log load event and post accessibility announcement
            LocalTrendsDashboardAudit.shared.log(
                operation: "load",
                location: location,
                filter: filter,
                summaryStats: summaryStats,
                tags: ["onAppear"],
                actor: "user",
                context: "dashboard",
                detail: ""
            )
            announceDashboardUpdate(operation: "load", location: location, filter: filter)
        }
        // Example: on refresh
        .onChange(of: someRefreshTrigger) { _ in
            LocalTrendsDashboardAudit.shared.log(
                operation: "refresh",
                location: location,
                filter: filter,
                summaryStats: summaryStats,
                tags: ["refresh"],
                actor: "user",
                context: "dashboard",
                detail: ""
            )
            announceDashboardUpdate(operation: "refresh", location: location, filter: filter)
        }
        // Example: on filter change
        .onChange(of: filter) { newFilter in
            LocalTrendsDashboardAudit.shared.log(
                operation: "filter",
                location: location,
                filter: newFilter,
                summaryStats: summaryStats,
                tags: ["filter"],
                actor: "user",
                context: "dashboard",
                detail: ""
            )
            announceDashboardUpdate(operation: "filter", location: location, filter: newFilter)
        }
#if DEBUG
        // Overlay audit analytics in DEBUG builds
        .overlay(
            VStack {
                Spacer()
                LocalTrendsDashboardAuditDevOverlay()
            }, alignment: .bottom
        )
#endif
    }
}
*/

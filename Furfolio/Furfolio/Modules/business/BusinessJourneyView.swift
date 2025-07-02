//
//  BusinessJourneyView.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//


import SwiftUI

// MARK: - Analytics & Audit Protocols

public protocol JourneyAnalyticsLogger {
    /// Log a journey view event asynchronously.
    func log(event: String, context: [String: Any]?) async
}

public protocol JourneyAuditLogger {
    /// Record a journey audit entry asynchronously.
    func record(_ event: String, context: [String: String]?) async
}

public struct NullJourneyAnalyticsLogger: JourneyAnalyticsLogger {
    public init() {}
    public func log(event: String, context: [String : Any]?) async {}
}

public struct NullJourneyAuditLogger: JourneyAuditLogger {
    public init() {}
    public func record(_ event: String, context: [String : String]?) async {}
}

// MARK: - Audit Entry & Manager

/// A record of a business journey audit event.
public struct JourneyAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let event: String
    public let detail: String?

    public init(id: UUID = UUID(), timestamp: Date = Date(), event: String, detail: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.event = event
        self.detail = detail
    }
}

/// Concurrency-safe actor for logging journey events.
public actor JourneyAuditManager {
    private var buffer: [JourneyAuditEntry] = []
    private let maxEntries = 200
    public static let shared = JourneyAuditManager()

    public func add(_ entry: JourneyAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    public func recent(limit: Int = 20) -> [JourneyAuditEntry] {
        Array(buffer.suffix(limit))
    }

    public func exportJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(buffer),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }
}

// MARK: - View

public struct BusinessJourneyView: View {
    @State private var metrics: [String: Double] = [:]
    @State private var isLoading = true

    let analytics: JourneyAnalyticsLogger
    let audit: JourneyAuditLogger

    public init(
        analytics: JourneyAnalyticsLogger = NullJourneyAnalyticsLogger(),
        audit: JourneyAuditLogger = NullJourneyAuditLogger()
    ) {
        self.analytics = analytics
        self.audit = audit
    }

    public var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading Business Metrics...")
                } else {
                    List {
                        ForEach(metrics.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                            HStack {
                                Text(key).font(.headline)
                                Spacer()
                                Text(String(format: "%.2f", value)).font(.subheadline)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Business Journey")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: refresh) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
            }
            .task {
                await logEvent("view_loaded", detail: nil)
                await loadMetrics()
            }
        }
    }

    private func refresh() {
        Task {
            await logEvent("refresh_tapped", detail: nil)
            await loadMetrics()
        }
    }

    private func loadMetrics() async {
        isLoading = true
        // Simulate fetching metrics
        try? await Task.sleep(nanoseconds: 300_000_000)
        // Example sample data
        metrics = [
            "Total Clients": 120,
            "Monthly Revenue": 7540.75,
            "New Bookings": 32,
            "Completed Services": 295
        ]
        isLoading = false
        await logEvent("metrics_loaded", detail: "count:\(metrics.count)")
    }

    private func logEvent(_ name: String, detail: String?) async {
        await analytics.log(event: name, context: ["detail": detail as Any])
        await audit.record(name, context: ["detail": detail ?? ""])
        await JourneyAuditManager.shared.add(
            JourneyAuditEntry(event: name, detail: detail)
        )
    }
}

// MARK: - Diagnostics

public extension BusinessJourneyView {
    /// Fetch recent journey audit entries.
    static func recentAuditEntries(limit: Int = 20) async -> [JourneyAuditEntry] {
        await JourneyAuditManager.shared.recent(limit: limit)
    }

    /// Export journey audit log as JSON.
    static func exportAuditLogJSON() async -> String {
        await JourneyAuditManager.shared.exportJSON()
    }
}

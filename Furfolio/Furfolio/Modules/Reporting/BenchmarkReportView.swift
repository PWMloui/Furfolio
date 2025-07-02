//
//  BenchmarkReportView.swift
//  Furfolio
//
//  Created by mac on 6/25/25.
//

import SwiftUI

// MARK: - Analytics & Audit Protocols

public protocol BenchmarkAnalyticsLogger {
    /// Log a benchmark view event asynchronously.
    func log(event: String, metricsCount: Int?) async
}

public protocol BenchmarkAuditLogger {
    /// Record a benchmark audit entry asynchronously.
    func record(event: String, metricsCount: Int?, detail: String?) async
}

public struct NullBenchmarkAnalyticsLogger: BenchmarkAnalyticsLogger {
    public init() {}
    public func log(event: String, metricsCount: Int?) async {}
}

public struct NullBenchmarkAuditLogger: BenchmarkAuditLogger {
    public init() {}
    public func record(event: String, metricsCount: Int?, detail: String?) async {}
}

// MARK: - Audit Entry & Manager

/// A record of a benchmark report audit event.
public struct BenchmarkAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let event: String
    public let metricsCount: Int?
    public let detail: String?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        event: String,
        metricsCount: Int? = nil,
        detail: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.event = event
        self.metricsCount = metricsCount
        self.detail = detail
    }
}

/// Concurrency-safe actor for logging benchmark report events.
public actor BenchmarkAuditManager {
    private var buffer: [BenchmarkAuditEntry] = []
    private let maxEntries = 200
    public static let shared = BenchmarkAuditManager()

    public func add(_ entry: BenchmarkAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    public func recent(limit: Int = 20) -> [BenchmarkAuditEntry] {
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

public struct BenchmarkReportView: View {
    @State private var metrics: [BenchmarkMetric] = []
    @State private var isLoading = false
    let analytics: BenchmarkAnalyticsLogger
    let audit: BenchmarkAuditLogger

    public init(
        analytics: BenchmarkAnalyticsLogger = NullBenchmarkAnalyticsLogger(),
        audit: BenchmarkAuditLogger = NullBenchmarkAuditLogger()
    ) {
        self.analytics = analytics
        self.audit = audit
    }

    public var body: some View {
        NavigationView {
            List(metrics) { metric in
                VStack(alignment: .leading) {
                    Text(metric.name).font(.headline)
                    Text(metric.valueDescription).font(.subheadline)
                }
            }
            .navigationTitle("Benchmark Report")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: refresh) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
            }
            .overlay {
                if isLoading {
                    ProgressView("Loading...")
                }
            }
            .task {
                await logEvent("view_loaded")
                await loadMetrics()
            }
        }
    }

    private func logEvent(_ name: String, count: Int? = nil, detail: String? = nil) async {
        await analytics.log(event: name, metricsCount: count)
        await audit.record(event: name, metricsCount: count, detail: detail)
        await BenchmarkAuditManager.shared.add(
            BenchmarkAuditEntry(event: name, metricsCount: count, detail: detail)
        )
    }

    private func refresh() {
        Task {
            await logEvent("refresh_tapped")
            await loadMetrics()
        }
    }

    private func loadMetrics() async {
        isLoading = true
        // Simulate fetching or compute metrics
        try? await Task.sleep(nanoseconds: 300_000_000)
        let fetched = BenchmarkMetric.sampleData()
        metrics = fetched
        isLoading = false
        await logEvent("metrics_loaded", count: fetched.count)
    }
}

// MARK: - Diagnostics

public extension BenchmarkReportView {
    /// Fetch recent benchmark audit entries.
    static func recentAuditEntries(limit: Int = 20) async -> [BenchmarkAuditEntry] {
        await BenchmarkAuditManager.shared.recent(limit: limit)
    }

    /// Export benchmark audit log as JSON.
    static func exportAuditLogJSON() async -> String {
        await BenchmarkAuditManager.shared.exportJSON()
    }
}

// MARK: - Sample Model

public struct BenchmarkMetric: Identifiable {
    public let id: UUID
    public let name: String
    public let value: Double

    public var valueDescription: String {
        String(format: "%.2f", value)
    }

    public init(id: UUID = UUID(), name: String, value: Double) {
        self.id = id
        self.name = name
        self.value = value
    }

    public static func sampleData() -> [BenchmarkMetric] {
        [
            BenchmarkMetric(name: "Response Time", value: Double.random(in: 100...500)),
            BenchmarkMetric(name: "Memory Usage", value: Double.random(in: 50...200)),
            BenchmarkMetric(name: "CPU Load", value: Double.random(in: 10...90))
        ]
    }
}

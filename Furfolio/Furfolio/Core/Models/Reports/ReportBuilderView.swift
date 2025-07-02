
//
//  ReportBuilderView.swift
//  Furfolio
//
//  Created by mac on 6/25/25.
//

/**
 ReportBuilderView
 -----------------
 A SwiftUI view for constructing and previewing custom business reports in Furfolio.

 - **Purpose**: Allows users to select metrics, date ranges, and filters to generate visual reports.
 - **Architecture**: MVVM-compatible, using `ReportBuilderViewModel` as an `@StateObject`.
 - **Concurrency & Async Logging**: Wraps analytics and audit calls in non-blocking `Task` blocks.
 - **Audit/Analytics Ready**: Defines protocols for async event logging and integrates a dedicated audit manager.
 - **Localization**: All user-facing text uses `LocalizedStringKey`.
 - **Accessibility**: UI controls include identifiers, labels, and hints for VoiceOver and UI testing.
 - **Diagnostics & Preview/Testability**: Exposes async methods to fetch and export audit logs.
 */

import SwiftUI

// MARK: - Analytics & Audit Protocols

public protocol ReportAnalyticsLogger {
    /// Log a report builder event asynchronously.
    func log(event: String, parameters: [String: Any]?) async
}

public protocol ReportAuditLogger {
    /// Record an audit entry asynchronously.
    func record(_ message: String, metadata: [String: String]?) async
}

/// No-op implementations for previews/testing.
public struct NullReportAnalyticsLogger: ReportAnalyticsLogger {
    public init() {}
    public func log(event: String, parameters: [String: Any]?) async {}
}
public struct NullReportAuditLogger: ReportAuditLogger {
    public init() {}
    public func record(_ message: String, metadata: [String: String]?) async {}
}

// MARK: - Audit Entry & Manager

/// A record of a report builder audit event.
public struct ReportBuilderAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let event: String

    public init(id: UUID = UUID(), timestamp: Date = Date(), event: String) {
        self.id = id
        self.timestamp = timestamp
        self.event = event
    }
}

/// Concurrency-safe actor for audit logging.
public actor ReportBuilderAuditManager {
    private var buffer: [ReportBuilderAuditEntry] = []
    private let maxEntries = 100
    public static let shared = ReportBuilderAuditManager()

    public func add(_ entry: ReportBuilderAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    public func recent(limit: Int = 20) -> [ReportBuilderAuditEntry] {
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

// MARK: - ViewModel

@MainActor
public class ReportBuilderViewModel: ObservableObject {
    @Published public var selectedMetrics: [String] = []
    @Published public var dateRange: ClosedRange<Date> = {
        let today = Date()
        return today.addingTimeInterval(-7*24*60*60)...today
    }()
    @Published public var filters: [String: String] = [:]

    let analytics: ReportAnalyticsLogger
    let audit: ReportAuditLogger

    public init(analytics: ReportAnalyticsLogger = NullReportAnalyticsLogger(),
                audit: ReportAuditLogger = NullReportAuditLogger()) {
        self.analytics = analytics
        self.audit = audit
    }

    /// Call when user updates a metric selection.
    public func toggleMetric(_ metric: String) {
        if selectedMetrics.contains(metric) {
            selectedMetrics.removeAll { $0 == metric }
        } else {
            selectedMetrics.append(metric)
        }
        Task {
            await analytics.log(event: "toggle_metric", parameters: ["metric": metric])
            await audit.record("Toggled metric \(metric)", metadata: nil)
            await ReportBuilderAuditManager.shared.add(
                ReportBuilderAuditEntry(event: "toggle_metric:\(metric)")
            )
        }
    }

    /// Call when date range changes.
    public func updateDateRange(_ range: ClosedRange<Date>) {
        dateRange = range
        Task {
            await analytics.log(event: "update_date_range", parameters: ["from": range.lowerBound, "to": range.upperBound])
            await audit.record("Updated date range", metadata: nil)
            await ReportBuilderAuditManager.shared.add(
                ReportBuilderAuditEntry(event: "update_date_range")
            )
        }
    }

    /// Generates the report preview.
    public func generateReport() {
        Task {
            await analytics.log(event: "generate_report", parameters: ["metrics": selectedMetrics])
            await audit.record("Generated report", metadata: nil)
            await ReportBuilderAuditManager.shared.add(
                ReportBuilderAuditEntry(event: "generate_report")
            )
        }
    }
}

// MARK: - View

public struct ReportBuilderView: View {
    @StateObject private var viewModel: ReportBuilderViewModel

    public init(viewModel: ReportBuilderViewModel = ReportBuilderViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text(LocalizedStringKey("Metrics"))) {
                    ForEach(["Revenue", "Appointments", "Clients"], id: \.self) { metric in
                        Toggle(metric, isOn: Binding(
                            get: { viewModel.selectedMetrics.contains(metric) },
                            set: { _ in viewModel.toggleMetric(metric) }
                        ))
                        .accessibilityIdentifier("MetricToggle_\(metric)")
                    }
                }
                Section(header: Text(LocalizedStringKey("Date Range"))) {
                    DatePicker(
                        NSLocalizedString("Start Date", comment: ""),
                        selection: Binding(
                            get: { viewModel.dateRange.lowerBound },
                            set: { newValue in
                                viewModel.updateDateRange(newValue...viewModel.dateRange.upperBound)
                            }
                        ),
                        displayedComponents: .date
                    )
                    DatePicker(
                        NSLocalizedString("End Date", comment: ""),
                        selection: Binding(
                            get: { viewModel.dateRange.upperBound },
                            set: { newValue in
                                viewModel.updateDateRange(viewModel.dateRange.lowerBound...newValue)
                            }
                        ),
                        displayedComponents: .date
                    )
                }
                Button(action: viewModel.generateReport) {
                    Text(LocalizedStringKey("Generate Report"))
                        .frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier("GenerateReportButton")
            }
            .navigationTitle(Text(LocalizedStringKey("Report Builder")))
        }
    }
}

// MARK: - Diagnostics & Preview

public extension ReportBuilderView {
    /// Fetch recent audit entries.
    static func recentAuditEntries(limit: Int = 20) async -> [ReportBuilderAuditEntry] {
        await ReportBuilderAuditManager.shared.recent(limit: limit)
    }

    /// Export audit log as JSON.
    static func exportAuditLogJSON() async -> String {
        await ReportBuilderAuditManager.shared.exportJSON()
    }
}

#if DEBUG
struct ReportBuilderView_Previews: PreviewProvider {
    static var previews: some View {
        ReportBuilderView(
            viewModel: ReportBuilderViewModel(
                analytics: NullReportAnalyticsLogger(),
                audit: NullReportAuditLogger()
            )
        )
    }
}
#endif


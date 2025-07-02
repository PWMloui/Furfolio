//
//  MetricsDashboardView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Modular Dashboard
//

import SwiftUI
import AVFoundation

// MARK: - Audit/Event Logging

fileprivate struct MetricsDashboardAuditEvent: Codable {
    let timestamp: Date
    let action: String          // "appear", "refresh", "customize", "widgetRender"
    let widgetTitle: String?
    let widgetType: String?
    let widgetValue: String?
    let tags: [String]
    let detail: String?
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        var base = "[\(action.capitalized)]"
        if let w = widgetTitle { base += " Widget: \(w)" }
        if let v = widgetValue { base += " Value: \(v)" }
        if !tags.isEmpty { base += " [\(tags.joined(separator: ","))]" }
        base += " at \(dateStr)"
        if let d = detail, !d.isEmpty { base += ": \(d)" }
        return base
    }
}

fileprivate final class MetricsDashboardAudit {
    static private(set) var log: [MetricsDashboardAuditEvent] = []

    /// Records a new audit event and posts a VoiceOver announcement on iOS for accessibility.
    static func record(
        action: String,
        widgetTitle: String? = nil,
        widgetType: String? = nil,
        widgetValue: String? = nil,
        tags: [String] = [],
        detail: String? = nil
    ) {
        let event = MetricsDashboardAuditEvent(
            timestamp: Date(),
            action: action,
            widgetTitle: widgetTitle,
            widgetType: widgetType,
            widgetValue: widgetValue,
            tags: tags,
            detail: detail
        )
        log.append(event)
        if log.count > 100 { log.removeFirst() }
        
        // Post VoiceOver announcement for accessibility on iOS
        #if os(iOS)
        let announcement = "Dashboard event: \(action), Widget: \(widgetTitle ?? "N/A"), Value: \(widgetValue ?? "N/A")."
        UIAccessibility.post(notification: .announcement, argument: announcement)
        #endif
    }

    /// Exports the last audit event as a pretty-printed JSON string.
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    
    /// Exports all audit events as CSV formatted string with headers:
    /// timestamp,action,widgetTitle,widgetType,widgetValue,tags,detail
    static func exportCSV() -> String {
        let header = "timestamp,action,widgetTitle,widgetType,widgetValue,tags,detail"
        let rows = log.map { event -> String in
            let timestampStr = ISO8601DateFormatter().string(from: event.timestamp)
            let action = event.action.csvEscaped
            let widgetTitle = (event.widgetTitle ?? "").csvEscaped
            let widgetType = (event.widgetType ?? "").csvEscaped
            let widgetValue = (event.widgetValue ?? "").csvEscaped
            let tags = event.tags.joined(separator: ";").csvEscaped
            let detail = (event.detail ?? "").csvEscaped
            return "\(timestampStr),\(action),\(widgetTitle),\(widgetType),\(widgetValue),\(tags),\(detail)"
        }
        return ([header] + rows).joined(separator: "\n")
    }
    
    /// The action string with the highest frequency in the audit log.
    static var mostFrequentAction: String? {
        let freq = Dictionary(grouping: log, by: { $0.action }).mapValues { $0.count }
        return freq.max(by: { $0.value < $1.value })?.key
    }
    
    /// The widgetTitle that appears most often with action == "widgetRender".
    static var mostRenderedWidgetTitle: String? {
        let filtered = log.filter { $0.action == "widgetRender" && $0.widgetTitle != nil }
        let freq = Dictionary(grouping: filtered, by: { $0.widgetTitle! }).mapValues { $0.count }
        return freq.max(by: { $0.value < $1.value })?.key
    }
    
    /// Total number of audit events recorded.
    static var totalDashboardEvents: Int {
        log.count
    }

    /// Accessibility summary of the last audit event.
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No dashboard events recorded."
    }
}

// MARK: - CSV escaping helper

fileprivate extension String {
    /// Escapes string for CSV format by wrapping in quotes and escaping internal quotes.
    var csvEscaped: String {
        if self.contains(",") || self.contains("\"") || self.contains("\n") {
            let escaped = self.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        } else {
            return self
        }
    }
}

// MARK: - Main View

struct MetricsDashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @StateObject private var widgetManager = DashboardWidgetManager()
    @State private var isShowingCustomizationSheet = false

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerView

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(widgetManager.widgets.filter { $0.isEnabled }) { widget in
                            widgetView(for: widget)
                                .accessibilityIdentifier("MetricsDashboardView-Widget-\(widget.title)")
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        isShowingCustomizationSheet = true
                        MetricsDashboardAudit.record(
                            action: "customize",
                            tags: ["customizationSheet"]
                        )
                    }) {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("Customize dashboard widgets")
                    .accessibilityIdentifier("MetricsDashboardView-CustomizeButton")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isLoading {
                        ProgressView()
                            .accessibilityIdentifier("MetricsDashboardView-LoadingIndicator")
                    } else {
                        Button(action: {
                            MetricsDashboardAudit.record(
                                action: "refresh",
                                tags: ["refreshButton"]
                            )
                            Task { await viewModel.refreshData() }
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .accessibilityLabel("Refresh dashboard data")
                        .accessibilityIdentifier("MetricsDashboardView-RefreshButton")
                    }
                }
            }
            .refreshable {
                MetricsDashboardAudit.record(
                    action: "refresh",
                    tags: ["pullToRefresh"]
                )
                await viewModel.refreshData()
            }
            .sheet(isPresented: $isShowingCustomizationSheet) {
                DashboardCustomizationView(manager: widgetManager)
                    .onAppear {
                        MetricsDashboardAudit.record(
                            action: "customize",
                            tags: ["customizationSheet", "sheet"]
                        )
                    }
            }
            .onAppear {
                MetricsDashboardAudit.record(action: "appear", tags: ["dashboard"])
            }
            #if DEBUG
            .overlay(
                MetricsDashboardAuditOverlay()
                    .padding()
                , alignment: .bottom
            )
            #endif
        }
    }

    private var headerView: some View {
        Text("Your Business Snapshot")
            .font(.largeTitle.bold())
            .padding(.horizontal)
            .accessibilityIdentifier("MetricsDashboardView-Header")
    }

    @ViewBuilder
    private func widgetView(for widget: DashboardWidget) -> some View {
        switch widget.title {
        case "Revenue":
            let value = String(format: "$%.2f", viewModel.totalRevenue)
            KPIStatCard(
                title: "Total Revenue",
                value: value,
                subtitle: "This Month",
                systemIconName: "dollarsign.circle.fill",
                iconBackgroundColor: .green
            )
            .onAppear {
                MetricsDashboardAudit.record(
                    action: "widgetRender",
                    widgetTitle: "Revenue",
                    widgetType: "KPIStatCard",
                    widgetValue: value,
                    tags: ["revenue", "kpi"]
                )
            }
        case "Appointments":
            let value = "\(viewModel.upcomingAppointmentsCount)"
            KPIStatCard(
                title: "Upcoming Appointments",
                value: value,
                subtitle: "Next 7 Days",
                systemIconName: "calendar",
                iconBackgroundColor: .blue
            )
            .onAppear {
                MetricsDashboardAudit.record(
                    action: "widgetRender",
                    widgetTitle: "Appointments",
                    widgetType: "KPIStatCard",
                    widgetValue: value,
                    tags: ["appointments", "kpi"]
                )
            }
        case "Customer Retention":
            let value = String(format: "%.0f%%", viewModel.customerRetentionRate * 100)
            KPIStatCard(
                title: "Customer Retention",
                value: value,
                subtitle: "Last Month",
                systemIconName: "arrow.2.squarepath",
                iconBackgroundColor: .purple
            )
            .onAppear {
                MetricsDashboardAudit.record(
                    action: "widgetRender",
                    widgetTitle: "Customer Retention",
                    widgetType: "KPIStatCard",
                    widgetValue: value,
                    tags: ["retention", "kpi"]
                )
            }
        case "Loyalty Program":
            let value = "\(Int(viewModel.loyaltyProgress * 100))%"
            KPIStatCard(
                title: "Loyalty Progress",
                value: value,
                subtitle: "Towards Reward",
                systemIconName: "star.circle.fill",
                iconBackgroundColor: .yellow
            )
            .onAppear {
                MetricsDashboardAudit.record(
                    action: "widgetRender",
                    widgetTitle: "Loyalty Program",
                    widgetType: "KPIStatCard",
                    widgetValue: value,
                    tags: ["loyalty", "kpi"]
                )
            }
        default:
            EmptyView()
        }
    }
}

// MARK: - Audit/Admin Accessors

public enum MetricsDashboardAuditAdmin {
    /// Returns a summary string of the last audit event for accessibility.
    public static var lastSummary: String { MetricsDashboardAudit.accessibilitySummary }
    /// Returns the last audit event as a JSON string.
    public static var lastJSON: String? { MetricsDashboardAudit.exportLastJSON() }
    /// Returns the last few audit events as an array of strings.
    public static func recentEvents(limit: Int = 5) -> [String] {
        MetricsDashboardAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
    /// Exports all audit events as CSV formatted string.
    public static func exportCSV() -> String {
        MetricsDashboardAudit.exportCSV()
    }
    /// The most frequent action string recorded.
    public static var mostFrequentAction: String? {
        MetricsDashboardAudit.mostFrequentAction
    }
    /// The widget title most often rendered.
    public static var mostRenderedWidgetTitle: String? {
        MetricsDashboardAudit.mostRenderedWidgetTitle
    }
    /// Total number of audit events recorded.
    public static var totalDashboardEvents: Int {
        MetricsDashboardAudit.totalDashboardEvents
    }
}

// MARK: - DEV Overlay for Audit Insights

#if DEBUG
/// A SwiftUI overlay view that displays recent audit events and analytics for development/debugging purposes.
struct MetricsDashboardAuditOverlay: View {
    private let maxEventsShown = 3
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Audit Events (last \(maxEventsShown)):")
                .font(.headline)
                .foregroundColor(.white)
            ForEach(Array(MetricsDashboardAudit.log.suffix(maxEventsShown).enumerated()), id: \.offset) { index, event in
                Text("\(index + 1). \(event.accessibilityLabel)")
                    .font(.caption2.monospaced())
                    .foregroundColor(.white.opacity(0.85))
            }
            Divider().background(Color.white.opacity(0.7))
            Text("Most Frequent Action: \(MetricsDashboardAudit.mostFrequentAction ?? "N/A")")
                .font(.caption)
                .foregroundColor(.yellow)
            Text("Most Rendered Widget: \(MetricsDashboardAudit.mostRenderedWidgetTitle ?? "N/A")")
                .font(.caption)
                .foregroundColor(.yellow)
            Text("Total Dashboard Events: \(MetricsDashboardAudit.totalDashboardEvents)")
                .font(.caption)
                .foregroundColor(.yellow)
        }
        .padding(8)
        .background(Color.black.opacity(0.75))
        .cornerRadius(8)
        .frame(maxWidth: .infinity)
        .padding()
    }
}
#endif

// MARK: - Preview

#if DEBUG
struct MetricsDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        MetricsDashboardView()
            .preferredColorScheme(.dark)
    }
}
#endif

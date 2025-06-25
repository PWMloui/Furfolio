//
//  MetricsDashboardView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Modular Dashboard
//

import SwiftUI

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
    }

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No dashboard events recorded."
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
    public static var lastSummary: String { MetricsDashboardAudit.accessibilitySummary }
    public static var lastJSON: String? { MetricsDashboardAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        MetricsDashboardAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
}

// MARK: - Preview

#if DEBUG
struct MetricsDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        MetricsDashboardView()
            .preferredColorScheme(.dark)
    }
}
#endif

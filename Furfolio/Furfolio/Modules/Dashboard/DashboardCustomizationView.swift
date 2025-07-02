//
//  DashboardCustomizationView.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Accessible, Analytics-Ready Dashboard Customization
//

import SwiftUI
import Combine

// MARK: - Audit/Event Logging

fileprivate struct DashboardCustomizationAuditEvent: Codable {
    let timestamp: Date
    let action: String // "move", "toggle"
    let widgetID: UUID
    let widgetTitle: String
    let beforeEnabled: Bool?
    let afterEnabled: Bool?
    let newOrder: [UUID]?
    let actor: String // e.g. "owner", "staff"
}

fileprivate final class DashboardCustomizationAudit {
    static private(set) var log: [DashboardCustomizationAuditEvent] = []
    static func record(action: String, widget: DashboardWidget, before: Bool? = nil, after: Bool? = nil, newOrder: [UUID]? = nil, actor: String = "owner") {
        let event = DashboardCustomizationAuditEvent(
            timestamp: Date(),
            action: action,
            widgetID: widget.id,
            widgetTitle: widget.title,
            beforeEnabled: before,
            afterEnabled: after,
            newOrder: newOrder,
            actor: actor
        )
        log.append(event)
        if log.count > 50 { log.removeFirst() }
        // Accessibility
        #if os(iOS)
        if action == "move" {
            UIAccessibility.post(notification: .announcement, argument: "Widget \(widget.title) moved.")
        } else if action == "toggle" {
            let onOff = after == true ? "enabled" : "disabled"
            UIAccessibility.post(notification: .announcement, argument: "\(widget.title) \(onOff).")
        }
        #endif
    }
    static func exportCSV() -> String {
        var csv = "timestamp,action,widgetID,widgetTitle,beforeEnabled,afterEnabled,newOrder,actor\n"
        let df = ISO8601DateFormatter()
        for e in log {
            let order = e.newOrder?.map { $0.uuidString }.joined(separator: "|") ?? ""
            csv += "\(df.string(from: e.timestamp)),\(e.action),\(e.widgetID),\(e.widgetTitle),\(e.beforeEnabled.map { "\($0)" } ?? ""),\(e.afterEnabled.map { "\($0)" } ?? ""),\(order),\(e.actor)\n"
        }
        return csv
    }
    // Analytics
    static var mostMovedWidget: String? {
        let moves = log.filter { $0.action == "move" }
        let counts = Dictionary(grouping: moves, by: { $0.widgetTitle }).mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key
    }
    static var mostEnabledWidget: String? {
        let enables = log.filter { $0.afterEnabled == true }
        let counts = Dictionary(grouping: enables, by: { $0.widgetTitle }).mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key
    }
    static var leastEnabledWidget: String? {
        let disables = log.filter { $0.afterEnabled == false }
        let counts = Dictionary(grouping: disables, by: { $0.widgetTitle }).mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key
    }
    static var totalCustomizations: Int { log.count }
    static func lastSummary() -> String {
        guard let last = log.last else { return "No customizations yet." }
        return "\(last.action.capitalized): \(last.widgetTitle) at \(DateFormatter.localizedString(from: last.timestamp, dateStyle: .short, timeStyle: .short))"
    }
}

#if DEBUG
struct DashboardCustomizationAuditOverlay: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Customization Audit").font(.caption.bold()).foregroundColor(.accentColor)
            ForEach(DashboardCustomizationAudit.log.suffix(3), id: \.timestamp) { event in
                Text("\(event.action.capitalized) \(event.widgetTitle) at \(event.timestamp.formatted(.dateTime.hour().minute()))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            if let mostMoved = DashboardCustomizationAudit.mostMovedWidget {
                Text("Most Moved: \(mostMoved)").font(.caption2)
            }
            if let mostEnabled = DashboardCustomizationAudit.mostEnabledWidget {
                Text("Most Enabled: \(mostEnabled)").font(.caption2)
            }
            if let leastEnabled = DashboardCustomizationAudit.leastEnabledWidget {
                Text("Most Disabled: \(leastEnabled)").font(.caption2)
            }
            Text("Total Customizations: \(DashboardCustomizationAudit.totalCustomizations)").font(.caption2)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemBackground)).opacity(0.96))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.accentColor, lineWidth: 1))
        .shadow(radius: 2)
    }
}
#endif

struct DashboardCustomizationView: View {
    @ObservedObject var manager: DashboardWidgetManager
    #if DEBUG
    @State private var showAudit = false
    #endif

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Manage Widgets"), footer: Text("Drag and drop widgets to change their order on the Dashboard. Toggling a widget off will hide it.")) {
                    ForEach($manager.widgets) { $widget in
                        WidgetRowView(widget: $widget, manager: manager)
                            .accessibilityIdentifier("WidgetRow-\(widget.title)")
                    }
                    .onMove(perform: moveWidget)
                }
            }
            .navigationTitle("Customize Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                #if DEBUG
                ToolbarItem(placement: .bottomBar) {
                    Button("Export CSV") {
                        let csv = DashboardCustomizationAudit.exportCSV()
                        print(csv) // Replace with share/export action if needed
                    }
                }
                #endif
            }
            .listStyle(.insetGrouped)
            #if DEBUG
            .background(
                Color.clear
                    .contentShape(Rectangle())
                    .onLongPressGesture { showAudit.toggle() }
            )
            .overlay(showAudit ? AnyView(DashboardCustomizationAuditOverlay().padding(.bottom, 10)) : AnyView(EmptyView()), alignment: .bottom)
            #endif
        }
    }
    
    private func moveWidget(from source: IndexSet, to destination: Int) {
        let oldOrder = manager.widgets
        var updatedWidgets = manager.widgets
        updatedWidgets.move(fromOffsets: source, toOffset: destination)
        let newOrder = updatedWidgets.map { $0.id }
        // Audit all moved widgets in this drag
        for idx in source {
            DashboardCustomizationAudit.record(action: "move", widget: oldOrder[idx], before: nil, after: nil, newOrder: newOrder)
        }
        manager.reorderWidgets(by: newOrder)
    }
}

struct WidgetRowView: View {
    @Binding var widget: DashboardWidget
    @ObservedObject var manager: DashboardWidgetManager
    @State private var lastEnabled: Bool = true

    var body: some View {
        HStack {
            Text(widget.title)
            Spacer()
            Toggle("Show", isOn: $widget.isEnabled)
                .labelsHidden()
                .onChange(of: widget.isEnabled) { newValue in
                    DashboardCustomizationAudit.record(action: "toggle", widget: widget, before: lastEnabled, after: newValue)
                    lastEnabled = newValue
                    manager.setWidgetEnabled(id: widget.id, isEnabled: newValue)
                }
        }
        .padding(.vertical, 4)
        .onAppear { lastEnabled = widget.isEnabled }
    }
}

// MARK: - Preview

struct DashboardCustomizationView_Previews: PreviewProvider {
    static var previews: some View {
        let previewManager = DashboardWidgetManager()
        DashboardCustomizationView(manager: previewManager)
    }
}

// ChartDrilldownManager.swift

import Foundation
import SwiftUI
import Combine

// MARK: - Audit/Event Logging

fileprivate struct ChartDrilldownAuditEvent: Codable {
    let timestamp: Date
    let action: String    // "drillDown", "drillUp", "reset"
    let path: [String]
    let selectedSegment: String?
    let tags: [String]
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        var base = "[\(action)] Path: \(path.joined(separator: " > "))"
        if let sel = selectedSegment { base += ", Selected: \(sel)" }
        if !tags.isEmpty { base += " [\(tags.joined(separator: ","))]" }
        base += " at \(dateStr)"
        return base
    }
}

/// Handles audit/event logging for drilldown actions, analytics, and export.
fileprivate final class ChartDrilldownAudit {
    static private(set) var log: [ChartDrilldownAuditEvent] = []
    static let auditPublisher = PassthroughSubject<ChartDrilldownAuditEvent, Never>()

    /// Records a drilldown-related event.
    static func record(
        action: String,
        path: [String],
        selectedSegment: String?,
        tags: [String] = ["drilldown"]
    ) {
        let event = ChartDrilldownAuditEvent(
            timestamp: Date(),
            action: action,
            path: path,
            selectedSegment: selectedSegment,
            tags: tags
        )
        log.append(event)
        auditPublisher.send(event)
        if log.count > 40 { log.removeFirst() }
    }

    /// Exports the last audit event as pretty-printed JSON.
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    /// Exports the audit log as CSV. Columns: timestamp,action,path,selectedSegment,tags
    static func exportCSV() -> String {
        let header = "timestamp,action,path,selectedSegment,tags"
        let formatter = ISO8601DateFormatter()
        let rows = log.map { event in
            let timestamp = formatter.string(from: event.timestamp)
            let action = event.action.replacingOccurrences(of: ",", with: ";")
            let path = event.path.joined(separator: " > ").replacingOccurrences(of: ",", with: ";")
            let selected = (event.selectedSegment ?? "").replacingOccurrences(of: ",", with: ";")
            let tags = event.tags.joined(separator: "|").replacingOccurrences(of: ",", with: ";")
            return "\"\(timestamp)\",\"\(action)\",\"\(path)\",\"\(selected)\",\"\(tags)\""
        }
        return ([header] + rows).joined(separator: "\n")
    }

    /// Returns a summary suitable for accessibility announcements.
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No chart drilldown events recorded."
    }

    /// Returns recent event descriptions (for overlays or admin).
    static func recentEvents(limit: Int = 5) -> [String] {
        log.suffix(limit).map { $0.accessibilityLabel }
    }
    static var publisher: AnyPublisher<ChartDrilldownAuditEvent, Never> {
        auditPublisher.eraseToAnyPublisher()
    }

    // MARK: - Analytics Enhancements

    /// Returns the most frequent action in the audit log (e.g., "drillDown").
    static var mostFrequentAction: String? {
        let actions = log.map { $0.action }
        let freq = Dictionary(grouping: actions, by: { $0 }).mapValues { $0.count }
        return freq.max(by: { $0.value < $1.value })?.key
    }

    /// Returns the most commonly drilled path (joined as string, e.g., "Services > Full Groom").
    static var mostDrilledPath: String? {
        let paths = log.map { $0.path.joined(separator: " > ") }
        let freq = Dictionary(grouping: paths, by: { $0 }).mapValues { $0.count }
        return freq.max(by: { $0.value < $1.value })?.key
    }

    /// Returns the total number of drillDown actions.
    static var totalDrilldowns: Int {
        log.filter { $0.action == "drillDown" }.count
    }
}

// MARK: - ChartDrilldownManager

/// Manages drilldown state and logic for interactive charts in Furfolio.
@MainActor
final class ChartDrilldownManager: ObservableObject {

    // MARK: - Published State

    /// The currently selected segment or category in the chart.
    @Published private(set) var selectedSegment: String?

    /// Stack representing the drilldown path hierarchy.
    @Published private(set) var drilldownPath: [String] = []

    // MARK: - Computed Properties

    /// The current drilldown level (0 means top-level).
    var currentLevel: Int {
        drilldownPath.count
    }

    /// Indicates whether the user has drilled into a subcategory.
    var isDrilledDown: Bool {
        !drilldownPath.isEmpty
    }

    /// Provides the current drilldown path as a displayable string.
    var drilldownPathDisplay: String {
        drilldownPath.joined(separator: " > ")
    }

    // MARK: - Drilldown Actions

    /// Selects a segment to drill down into.
    /// - Parameter segment: The segment or category name.
    /// Posts an accessibility announcement summarizing the action.
    func drillDown(to segment: String) {
        drilldownPath.append(segment)
        selectedSegment = segment
        ChartDrilldownAudit.record(
            action: "drillDown",
            path: drilldownPath,
            selectedSegment: selectedSegment
        )
        postAccessibilityAnnouncement("Drilled down to \(segment)")
    }

    /// Moves one level up in the drilldown hierarchy.
    /// Posts an accessibility announcement summarizing the action.
    func drillUp() {
        guard !drilldownPath.isEmpty else { return }
        let prev = drilldownPath.last
        drilldownPath.removeLast()
        selectedSegment = drilldownPath.last
        ChartDrilldownAudit.record(
            action: "drillUp",
            path: drilldownPath,
            selectedSegment: selectedSegment
        )
        postAccessibilityAnnouncement("Returned to previous level" + (selectedSegment != nil ? ", now at \(selectedSegment!)" : ""))
    }

    /// Resets drilldown to the top level.
    /// Posts an accessibility announcement summarizing the action.
    func resetDrilldown() {
        drilldownPath.removeAll()
        selectedSegment = nil
        ChartDrilldownAudit.record(
            action: "reset",
            path: drilldownPath,
            selectedSegment: selectedSegment,
            tags: ["reset"]
        )
        postAccessibilityAnnouncement("Drilldown reset")
    }

    /// Posts a VoiceOver accessibility announcement.
    private func postAccessibilityAnnouncement(_ message: String) {
        #if os(iOS)
        DispatchQueue.main.async {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
        #elseif os(macOS)
        // macOS accessibility announcement (if needed)
        #endif
    }

    // MARK: - Data Navigation

    /// Retrieves the next level of keys from a nested dictionary structure based on the current drilldown path.
    /// - Parameter data: A nested `[String: Any]` dictionary representing drilldown data.
    /// - Returns: The keys for the next drillable level.
    func nextLevelKeys(from data: [String: Any]) -> [String] {
        var currentData = data
        for key in drilldownPath {
            guard let next = currentData[key] as? [String: Any] else {
                return []
            }
            currentData = next
        }
        return Array(currentData.keys).sorted()
    }

    // MARK: - Audit/Admin/Analytics Accessors

    /// Returns a summary of the last audit event (for accessibility or admin).
    static var lastAuditSummary: String { ChartDrilldownAudit.accessibilitySummary }
    /// Returns the last audit event as JSON.
    static var lastAuditJSON: String? { ChartDrilldownAudit.exportLastJSON() }
    /// Returns the audit log as CSV (timestamp,action,path,selectedSegment,tags).
    static func exportCSV() -> String { ChartDrilldownAudit.exportCSV() }
    /// Returns the most frequent action in the audit log.
    static var mostFrequentAction: String? { ChartDrilldownAudit.mostFrequentAction }
    /// Returns the most frequently drilled path.
    static var mostDrilledPath: String? { ChartDrilldownAudit.mostDrilledPath }
    /// Returns the total number of drillDown actions.
    static var totalDrilldowns: Int { ChartDrilldownAudit.totalDrilldowns }
    /// Returns recent audit event summaries.
    static func recentAuditEvents(limit: Int = 5) -> [String] {
        ChartDrilldownAudit.recentEvents(limit: limit)
    }
    /// Publisher for audit events.
    static var auditEventsPublisher: AnyPublisher<ChartDrilldownAuditEvent, Never> {
        ChartDrilldownAudit.publisher
    }
}

// MARK: - Demo for Debugging

#if DEBUG
import SwiftUI

/// DEV overlay showing audit analytics and recent events.
struct ChartDrilldownAuditOverlay: View {
    // Listen to audit events to update view.
    @State private var recentEvents: [String] = ChartDrilldownManager.recentAuditEvents(limit: 3)
    @State private var mostFrequentAction: String? = ChartDrilldownManager.mostFrequentAction
    @State private var mostDrilledPath: String? = ChartDrilldownManager.mostDrilledPath
    @State private var totalDrilldowns: Int = ChartDrilldownManager.totalDrilldowns
    private var cancellable: AnyCancellable?

    init() {
        // Listen for audit updates and refresh analytics.
        _ = ChartDrilldownManager.auditEventsPublisher.sink { _ in
            // no-op, handled in .onReceive below
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("🔎 Drilldown DEV Overlay").font(.caption2.bold())
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("Most Frequent Action: \(ChartDrilldownManager.mostFrequentAction ?? "-")")
                    Text("Most Drilled Path: \(ChartDrilldownManager.mostDrilledPath ?? "-")")
                    Text("Total Drilldowns: \(ChartDrilldownManager.totalDrilldowns)")
                }
                .font(.caption2)
            }
            Divider().padding(.vertical, 2)
            Text("Last 3 Events:").font(.caption2.italic())
            ForEach(ChartDrilldownManager.recentAuditEvents(limit: 3), id: \.self) { event in
                Text(event).font(.caption2)
            }
        }
        .padding(8)
        .background(Color(.systemGray6).opacity(0.97))
        .cornerRadius(10)
        .shadow(radius: 2)
        .padding(.horizontal)
        .onReceive(ChartDrilldownManager.auditEventsPublisher) { _ in
            recentEvents = ChartDrilldownManager.recentAuditEvents(limit: 3)
            mostFrequentAction = ChartDrilldownManager.mostFrequentAction
            mostDrilledPath = ChartDrilldownManager.mostDrilledPath
            totalDrilldowns = ChartDrilldownManager.totalDrilldowns
        }
    }
}

struct ChartDrilldownManagerDemoView: View {
    @StateObject private var manager = ChartDrilldownManager()

    let exampleData: [String: Any] = [
        "Services": [
            "Full Groom": ["Jan": 10, "Feb": 15],
            "Bath Only": ["Jan": 5, "Feb": 7]
        ],
        "Revenue": [
            "Q1": ["January": 10000, "February": 12000],
            "Q2": ["April": 13000, "May": 11000]
        ]
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 20) {
                Text("Drilldown Path: \(manager.drilldownPathDisplay)")
                    .font(.headline)

                if manager.isDrilledDown {
                    Button("Drill Up") {
                        manager.drillUp()
                    }
                    .buttonStyle(.borderedProminent)
                }

                List {
                    ForEach(manager.nextLevelKeys(from: exampleData), id: \.self) { key in
                        Button(key) {
                            manager.drillDown(to: key)
                        }
                    }
                }

                // Audit Summary
                if let lastJSON = ChartDrilldownManager.lastAuditJSON {
                    Text("Last Audit Event:").font(.caption.bold())
                    ScrollView { Text(lastJSON).font(.caption2).lineLimit(10) }
                }
            }
            .padding()

            // DEV overlay at the bottom
            ChartDrilldownAuditOverlay()
                .padding(.bottom, 8)
        }
    }
}

struct ChartDrilldownManager_Previews: PreviewProvider {
    static var previews: some View {
        ChartDrilldownManagerDemoView()
    }
}
#endif

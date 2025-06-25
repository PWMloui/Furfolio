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

fileprivate final class ChartDrilldownAudit {
    static private(set) var log: [ChartDrilldownAuditEvent] = []
    static let auditPublisher = PassthroughSubject<ChartDrilldownAuditEvent, Never>()

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

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No chart drilldown events recorded."
    }
    static func recentEvents(limit: Int = 5) -> [String] {
        log.suffix(limit).map { $0.accessibilityLabel }
    }
    static var publisher: AnyPublisher<ChartDrilldownAuditEvent, Never> {
        auditPublisher.eraseToAnyPublisher()
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
    func drillDown(to segment: String) {
        drilldownPath.append(segment)
        selectedSegment = segment
        ChartDrilldownAudit.record(
            action: "drillDown",
            path: drilldownPath,
            selectedSegment: selectedSegment
        )
    }

    /// Moves one level up in the drilldown hierarchy.
    func drillUp() {
        guard !drilldownPath.isEmpty else { return }
        drilldownPath.removeLast()
        selectedSegment = drilldownPath.last
        ChartDrilldownAudit.record(
            action: "drillUp",
            path: drilldownPath,
            selectedSegment: selectedSegment
        )
    }

    /// Resets drilldown to the top level.
    func resetDrilldown() {
        drilldownPath.removeAll()
        selectedSegment = nil
        ChartDrilldownAudit.record(
            action: "reset",
            path: drilldownPath,
            selectedSegment: selectedSegment,
            tags: ["reset"]
        )
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

    // MARK: - Audit/Admin Accessors

    static var lastAuditSummary: String { ChartDrilldownAudit.accessibilitySummary }
    static var lastAuditJSON: String? { ChartDrilldownAudit.exportLastJSON() }
    static func recentAuditEvents(limit: Int = 5) -> [String] {
        ChartDrilldownAudit.recentEvents(limit: limit)
    }
    static var auditEventsPublisher: AnyPublisher<ChartDrilldownAuditEvent, Never> {
        ChartDrilldownAudit.publisher
    }
}

// MARK: - Demo for Debugging

#if DEBUG
import SwiftUI

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
    }
}

struct ChartDrilldownManager_Previews: PreviewProvider {
    static var previews: some View {
        ChartDrilldownManagerDemoView()
    }
}
#endif

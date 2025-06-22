import Foundation
import SwiftUI

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
    }

    /// Moves one level up in the drilldown hierarchy.
    func drillUp() {
        guard !drilldownPath.isEmpty else { return }
        drilldownPath.removeLast()
        selectedSegment = drilldownPath.last
    }

    /// Resets drilldown to the top level.
    func resetDrilldown() {
        drilldownPath.removeAll()
        selectedSegment = nil
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

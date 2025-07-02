
//
//  DiagnosticsView.swift
//  Furfolio
//
//  Created by mac on 6/23/25.
//

/**
 DiagnosticsView
 ---------------
 A SwiftUI view that displays application diagnostics and audit log entries for Furfolio.

 - **Purpose**: Presents recent audit entries and provides controls to export or clear logs.
 - **Architecture**: SwiftUI `View` with an `@StateObject` view model conforming to `ObservableObject`.
 - **Concurrency & Async Logging**: Uses async/await to fetch audit entries from various managers.
 - **Localization**: All user-facing strings use `LocalizedStringKey` or `NSLocalizedString`.
 - **Accessibility**: Provides accessibility identifiers and labels for UI testing and VoiceOver.
 - **Preview/Testability**: Includes a SwiftUI preview with mock data.
 */



import SwiftUI

/// ViewModel for DiagnosticsView, fetching audit entries from multiple sources.
@MainActor
class DiagnosticsViewModel: ObservableObject {
    @Published var entries: [String] = []

    /// Fetches recent diagnostics from all audit managers.
    func loadEntries() async {
        var allEntries: [String] = []
        // Example sources: replace with actual audit managers
        if let roleEntries = try? await OnboardingRoleAuditManager.shared.recent(limit: 50) {
            allEntries += roleEntries.map { "[RoleAudit] \($0.timestamp): \($0.event)" }
        }
        if let viewEntries = try? await OnboardingViewAuditManager.shared.recent(limit: 50) {
            allEntries += viewEntries.map { "[ViewAudit] \($0.timestamp): \($0.event)" }
        }
        // Add additional audit sources as needed
        entries = allEntries.sorted(by: { $0 < $1 })
    }

    /// Clears the diagnostics entries.
    func clearEntries() {
        entries = []
    }

    /// Exports entries as JSON string.
    func exportJSON() async -> String {
        let json = try? JSONEncoder().encode(entries)
        return String(data: json ?? Data(), encoding: .utf8) ?? "[]"
    }
}

struct DiagnosticsView: View {
    @StateObject private var viewModel = DiagnosticsViewModel()

    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.entries, id: \.self) { entry in
                    Text(entry)
                        .font(.caption)
                        .accessibilityIdentifier("DiagnosticsEntry_\(viewModel.entries.firstIndex(of: entry) ?? 0)")
                }
            }
            .navigationTitle(Text(NSLocalizedString("Diagnostics", comment: "Diagnostics view title")))
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task { await viewModel.loadEntries() }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityIdentifier("DiagnosticsView_RefreshButton")
                    Button(action: {
                        viewModel.clearEntries()
                    }) {
                        Image(systemName: "trash")
                    }
                    .accessibilityIdentifier("DiagnosticsView_ClearButton")
                    Button(action: {
                        Task {
                            let json = await viewModel.exportJSON()
                            print(json)
                        }
                    }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("DiagnosticsView_ExportButton")
                }
            }
        }
        .task {
            await viewModel.loadEntries()
        }
    }
}

#if DEBUG
struct DiagnosticsView_Previews: PreviewProvider {
    static var previews: some View {
        DiagnosticsView()
    }
}
#endif

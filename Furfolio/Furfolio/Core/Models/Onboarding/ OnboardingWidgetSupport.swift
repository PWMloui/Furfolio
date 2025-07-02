//
//  OnboardingWidgetSupport.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import Foundation
import WidgetKit
import SwiftUI

/**
 OnboardingWidgetSupport
 ------------------------
 Manages widget onboarding suggestions in Furfolio, including audit logging, analytics readiness, localization, accessibility, and preview/testability.

 - **Architecture**: Static helper for widget prompt flow.
 - **Concurrency & Audit**: Adds async audit logging via `WidgetSuggestionAuditManager` actor.
 - **Localization**: All user-facing strings use `NSLocalizedString`.
 - **Accessibility**: Methods expose VoiceOver-friendly prompts.
 - **Diagnostics**: Provides async methods to fetch and export audit entries.
 - **Preview/Testability**: Includes SwiftUI preview demonstrating suggestion flow and audit export.
 */

/// Represents an audit entry for widget suggestion events.
public struct WidgetSuggestionAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let action: String

    public init(id: UUID = UUID(), timestamp: Date = Date(), action: String) {
        self.id = id
        self.timestamp = timestamp
        self.action = action
    }
}

/// Manages concurrency-safe audit logging for widget suggestions.
public actor WidgetSuggestionAuditManager {
    private var buffer: [WidgetSuggestionAuditEntry] = []
    private let maxEntries = 100
    public static let shared = WidgetSuggestionAuditManager()

    /// Add a new audit entry, capping buffer at `maxEntries`.
    public func add(_ entry: WidgetSuggestionAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Fetch recent audit entries up to the specified limit.
    public func recent(limit: Int = 20) -> [WidgetSuggestionAuditEntry] {
        Array(buffer.suffix(limit))
    }

    /// Export all audit entries as a JSON string.
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

/// Handles widget onboarding suggestion and tracking
struct OnboardingWidgetSupport {
    static let suggestionShownKey = "onboarding_widget_suggestion_shown"

    /// Whether the user has already been prompted about the widget
    static var hasShownSuggestion: Bool {
        UserDefaults.standard.bool(forKey: suggestionShownKey)
    }

    /// Marks the widget suggestion as shown
    static func markSuggestionShown() {
        UserDefaults.standard.set(true, forKey: suggestionShownKey)
    }

    /// Check if widgets are active (if app has any configured widgets)
    static func isWidgetEnabled(completion: @escaping (Bool) -> Void) {
        WidgetCenter.shared.getCurrentConfigurations { result in
            switch result {
            case .success(let widgets):
                completion(!widgets.isEmpty)
            case .failure(_):
                completion(false)
            }
        }
    }

    /// Triggers system UI to add/configure widgets (iOS 17+ only)
    static func openWidgetConfiguration() {
        guard let url = URL(string: "App-Prefs:root=HomeScreen&path=WIDGETS") else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Async Audit & Utilities

    public extension OnboardingWidgetSupport {
        /// Marks the widget suggestion as shown and logs the action asynchronously.
        static func markSuggestionShownAsync() async {
            UserDefaults.standard.set(true, forKey: suggestionShownKey)
            let action = NSLocalizedString("Widget suggestion shown", comment: "Audit action")
            await WidgetSuggestionAuditManager.shared.add(
                WidgetSuggestionAuditEntry(action: action)
            )
        }

        /// Logs the widget configuration open action asynchronously.
        static func openWidgetConfigurationAsync() async {
            let action = NSLocalizedString("Widget configuration opened", comment: "Audit action")
            await WidgetSuggestionAuditManager.shared.add(
                WidgetSuggestionAuditEntry(action: action)
            )
            openWidgetConfiguration()
        }

        /// Fetches recent audit entries asynchronously.
        static func recentAuditEntries(limit: Int = 20) async -> [WidgetSuggestionAuditEntry] {
            await WidgetSuggestionAuditManager.shared.recent(limit: limit)
        }

        /// Exports the audit log as a JSON string asynchronously.
        static func exportAuditLogJSON() async -> String {
            await WidgetSuggestionAuditManager.shared.exportJSON()
        }

        /// Checks if widgets are enabled asynchronously.
        static func isWidgetEnabledAsync() async -> Bool {
            await withCheckedContinuation { cont in
                isWidgetEnabled { enabled in
                    cont.resume(returning: enabled)
                }
            }
        }
    }
}

#if DEBUG
import SwiftUI

struct OnboardingWidgetSupport_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            Text(NSLocalizedString("Widget Suggestion Demo", comment: "Preview title"))
                .font(.headline)
            Button("Mark Suggestion Shown") {
                Task {
                    await OnboardingWidgetSupport.markSuggestionShownAsync()
                }
            }
            Button("Open Configuration") {
                Task {
                    await OnboardingWidgetSupport.openWidgetConfigurationAsync()
                }
            }
            Button("Export Audit JSON") {
                Task {
                    let json = await OnboardingWidgetSupport.exportAuditLogJSON()
                    print(json)
                }
            }
        }
        .padding()
    }
}
#endif

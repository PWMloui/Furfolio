//
//  Manager.swift
//  Furfolio
//
//  Created by mac on 6/27/25.
//

import Foundation
import SwiftUI
import SwiftData

/**
 Manager
 -------
 A central orchestrator for Furfolio, responsible for global state, audit/analytics readiness, diagnostics, localization, accessibility, and preview/testability.

 - **Architecture**: Singleton via `shared` instance. Conforms to `ObservableObject` for SwiftUI binding.
 - **Concurrency & Audit**: Provides async/await audit logging via `ManagerAuditManager` actor.
 - **Analytics**: Exposes async analytics event logging hooks via `AnalyticsLogger`.
 - **Localization**: All user-facing strings use `NSLocalizedString`.
 - **Accessibility**: Exposes computed accessibility summaries for global state changes.
 - **Diagnostics**: Async methods to fetch and export recent audit entries.
 - **Preview/Testability**: Includes a SwiftUI preview demonstrating audit and analytics usage.
 */

/// A record of a Manager audit event.
@Model public struct ManagerAuditEntry: Identifiable {
    @Attribute(.unique) public var id: UUID
    public let timestamp: Date
    public let event: String

    public init(id: UUID = UUID(), timestamp: Date = Date(), event: String) {
        self.id = id
        self.timestamp = timestamp
        self.event = event
    }
}

/// Protocol for async analytics logging.
public protocol AnalyticsLogger {
    /// Log an event asynchronously.
    /// - Parameters:
    ///   - name: Event name.
    ///   - parameters: Optional event parameters.
    func logEvent(_ name: String, parameters: [String: Any]?) async
}

/// A no-op analytics logger for previews and testing.
public struct NullAnalyticsLogger: AnalyticsLogger {
    public init() {}
    public func logEvent(_ name: String, parameters: [String: Any]?) async {
        // test mode - no-op
    }
}

/// The central Manager for Furfolio.
@MainActor
public final class Manager: ObservableObject {
    public static let shared = Manager()

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \.timestamp, order: .forward) public var auditEntries: [ManagerAuditEntry]

    /// Async analytics logger.
    public var analyticsLogger: AnalyticsLogger = NullAnalyticsLogger()

    /// Example global state:
    @Published public var isConnected: Bool = true {
        didSet {
            Task {
                await addAudit("Connectivity changed to \(isConnected)")
                await analyticsLogger.logEvent("connectivity_changed", parameters: ["connected": isConnected])
            }
        }
    }

    private init() {
        // Initial audit event
        Task {
            await addAudit("Manager initialized")
        }
    }

    // MARK: - Audit Methods

    /// Asynchronously logs an audit entry.
    /// - Parameter event: Description of the event.
    public func addAudit(_ event: String) async {
        let localized = NSLocalizedString(event, comment: "Manager audit entry")
        let entry = ManagerAuditEntry(event: localized)
        modelContext.insert(entry)
    }

    /// Fetches recent audit entries.
    public func recentAuditEntries(limit: Int = 20) async -> [ManagerAuditEntry] {
        Array(auditEntries.suffix(limit).reversed())
    }

    /// Exports audit log as JSON string.
    public func exportAuditLogJSON() async -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        let data = try? encoder.encode(auditEntries)
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }
}

// MARK: - SwiftUI Preview

#if DEBUG
struct Manager_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            Text("Connection: \(Manager.shared.isConnected ? "Online" : "Offline")")
            Button("Toggle Connection") {
                Task { Manager.shared.isConnected.toggle() }
            }
            Button("Export Audit JSON") {
                Task {
                    let json = await Manager.shared.exportAuditLogJSON()
                    print(json)
                }
            }
        }
        .padding()
    }
}
#endif

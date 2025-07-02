//
//  SyncEngine.swift
//  Furfolio
//
//  Created by mac on 6/30/25.
//

import Foundation

// MARK: - Audit Context (set at login/session)
public struct SyncAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "SyncEngine"
}

// MARK: - Analytics Logger Protocol & Null Logger

public protocol SyncAnalyticsLogger {
    var testMode: Bool { get }
    func logEvent(
        event: String,
        details: [String: Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async
}

public struct NullSyncAnalyticsLogger: SyncAnalyticsLogger {
    public let testMode: Bool = true
    public init() {}
    public func logEvent(
        event: String,
        details: [String: Any]? = nil,
        role: String? = nil,
        staffID: String? = nil,
        context: String? = nil,
        escalate: Bool = false
    ) async {
        let detailsString = details?.map { "\($0): \($1)" }.joined(separator: ", ") ?? "none"
        print("[NullSyncAnalyticsLogger][TEST MODE] Event: \(event), Details: \(detailsString) | role:\(role ?? "-") staffID:\(staffID ?? "-") context:\(context ?? "-") escalate:\(escalate)")
    }
}

// MARK: - SyncEngine

public final class SyncEngine {
    private var analyticsLogger: SyncAnalyticsLogger = NullSyncAnalyticsLogger()
    private var analyticsEventBuffer: [(timestamp: Date, event: String, details: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool)] = []
    private let analyticsEventBufferMax = 30

    public init() {}

    // MARK: - Main API

    public func syncAllData() async -> Bool {
        await logAnalyticsEvent(event: "syncAllData_start", details: nil)
        // -- Insert your sync logic here --
        let success = true // Simulate a successful sync.
        let resultDetails: [String: Any] = ["result": success ? "success" : "failure"]
        await logAnalyticsEvent(event: "syncAllData_complete", details: resultDetails)
        return success
    }

    public func syncPartialData(entities: [String]) async -> Bool {
        await logAnalyticsEvent(event: "syncPartialData_start", details: ["entities": entities])
        // -- Insert partial sync logic here --
        let success = true // Simulate a successful partial sync.
        let resultDetails: [String: Any] = ["result": success ? "success" : "failure", "entities": entities]
        await logAnalyticsEvent(event: "syncPartialData_complete", details: resultDetails)
        return success
    }

    public func handleError(_ error: Error) async {
        await logAnalyticsEvent(event: "sync_error", details: ["error": String(describing: error)])
    }

    // MARK: - Audit/Event Logging

    private func logAnalyticsEvent(event: String, details: [String: Any]? = nil) async {
        let escalate = event.lowercased().contains("danger") || event.lowercased().contains("critical") || event.lowercased().contains("delete")
            || (details?.values.contains { "\($0)".lowercased().contains("danger") || "\($0)".lowercased().contains("critical") || "\($0)".lowercased().contains("delete") } ?? false)
        await analyticsLogger.logEvent(
            event: event,
            details: details,
            role: SyncAuditContext.role,
            staffID: SyncAuditContext.staffID,
            context: SyncAuditContext.context,
            escalate: escalate
        )
        analyticsEventBuffer.append((Date(), event, details, SyncAuditContext.role, SyncAuditContext.staffID, SyncAuditContext.context, escalate))
        if analyticsEventBuffer.count > analyticsEventBufferMax {
            analyticsEventBuffer.removeFirst(analyticsEventBuffer.count - analyticsEventBufferMax)
        }
    }

    // MARK: - Diagnostics / Trust Center Review

    public func diagnosticsAuditTrail() -> [String] {
        analyticsEventBuffer.map { evt in
            let dateStr = ISO8601DateFormatter().string(from: evt.timestamp)
            let detailsStr = evt.details?.map { "\($0): \($1)" }.joined(separator: ", ") ?? ""
            let role = evt.role ?? "-"
            let staffID = evt.staffID ?? "-"
            let context = evt.context ?? "-"
            let escalate = evt.escalate ? "YES" : "NO"
            return "[\(dateStr)] \(evt.event) \(detailsStr) | role:\(role) staffID:\(staffID) context:\(context) escalate:\(escalate)"
        }
    }

    // MARK: - Test/Preview

    public func printDiagnostics() {
        for line in diagnosticsAuditTrail() {
            print(line)
        }
    }
}

// MARK: - Example Usage

#if DEBUG
@main
struct SyncEngineTestApp {
    static func main() async {
        let syncEngine = SyncEngine()
        _ = await syncEngine.syncAllData()
        _ = await syncEngine.syncPartialData(entities: ["Dog", "Owner"])
        await syncEngine.handleError(NSError(domain: "Sync", code: 42, userInfo: [NSLocalizedDescriptionKey: "Simulated error"]))
        syncEngine.printDiagnostics()
    }
}
#endif

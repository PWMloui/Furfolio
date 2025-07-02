//
//  CriticalAlertEngine.swift
//  Furfolio
//
//  Created by mac on 6/30/25.
//

// MARK: - Audit Context (set at login/session)
public struct CriticalAlertAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "CriticalAlertEngine"
}

public protocol CriticalAlertAnalyticsLogger {
    var testMode: Bool { get }
    func logEvent(
        event: String,
        info: [String: Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async
}

public struct NullCriticalAlertAnalyticsLogger: CriticalAlertAnalyticsLogger {
    public let testMode: Bool = true
    public init() {}
    public func logEvent(
        event: String,
        info: [String: Any]? = nil,
        role: String? = nil,
        staffID: String? = nil,
        context: String? = nil,
        escalate: Bool = false
    ) async {
        if testMode {
            print("[CriticalAlertEngine][TEST MODE] \(event) \(info ?? [:]) | role:\(role ?? "-") staffID:\(staffID ?? "-") context:\(context ?? "-") escalate:\(escalate)")
        }
    }
}

private var analyticsLogger: CriticalAlertAnalyticsLogger = NullCriticalAlertAnalyticsLogger()
private var eventBuffer: [(date: Date, event: String, info: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool)] = []
private let bufferLimit = 20

private func logAnalyticsEvent(_ event: String, info: [String: Any]? = nil) async {
    let escalate = event.lowercased().contains("danger") || event.lowercased().contains("critical") || event.lowercased().contains("delete")
        || (info?.values.contains { "\($0)".lowercased().contains("danger") || "\($0)".lowercased().contains("critical") || "\($0)".lowercased().contains("delete") } ?? false)
    await analyticsLogger.logEvent(
        event: event,
        info: info,
        role: CriticalAlertAuditContext.role,
        staffID: CriticalAlertAuditContext.staffID,
        context: CriticalAlertAuditContext.context,
        escalate: escalate
    )
    eventBuffer.append((date: Date(), event: event, info: info, role: CriticalAlertAuditContext.role, staffID: CriticalAlertAuditContext.staffID, context: CriticalAlertAuditContext.context, escalate: escalate))
    if eventBuffer.count > bufferLimit {
        eventBuffer.removeFirst(eventBuffer.count - bufferLimit)
    }
}

public func diagnostics() -> String {
    eventBuffer.map { evt in
        let dateStr = DateFormatter.localizedString(from: evt.date, dateStyle: .short, timeStyle: .medium)
        let infoStr = evt.info?.map { "\($0): \($1)" }.joined(separator: ", ") ?? ""
        let role = evt.role ?? "-"
        let staffID = evt.staffID ?? "-"
        let context = evt.context ?? "-"
        let escalate = evt.escalate ? "YES" : "NO"
        return "\(dateStr): \(evt.event) \(infoStr) | role:\(role) staffID:\(staffID) context:\(context) escalate:\(escalate)"
    }.joined(separator: "\n")
}


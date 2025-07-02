//
//  NotificationEngine.swift
//  Furfolio
//
//  Created by mac on 6/30/25.
//

// MARK: - Audit Context (set at login/session)
public struct NotificationAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "NotificationEngine"
}

public protocol NotificationAnalyticsLogger {
    var testMode: Bool { get }
    func logEvent(
        _ event: String,
        details: [String: Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async
}

public struct NullNotificationAnalyticsLogger: NotificationAnalyticsLogger {
    public let testMode: Bool = true
    public init() {}
    public func logEvent(
        _ event: String,
        details: [String: Any]? = nil,
        role: String? = nil,
        staffID: String? = nil,
        context: String? = nil,
        escalate: Bool = false
    ) async {
        if testMode {
            print("[NotificationEngine][TEST MODE] \(event) \(details ?? [:]) | role:\(role ?? "-") staffID:\(staffID ?? "-") context:\(context ?? "-") escalate:\(escalate)")
        }
    }
}

class NotificationEngine {
    private var analyticsLogger: NotificationAnalyticsLogger = NullNotificationAnalyticsLogger()
    private var eventBuffer: [(timestamp: Date, event: String, details: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool)] = []
    private let bufferLimit = 50

    private func logAnalyticsEvent(_ event: String, details: [String: Any]? = nil) async {
        let escalate = event.lowercased().contains("danger") || event.lowercased().contains("critical") || event.lowercased().contains("delete")
            || (details?.values.contains { "\($0)".lowercased().contains("danger") || "\($0)".lowercased().contains("critical") || "\($0)".lowercased().contains("delete") } ?? false)
        await analyticsLogger.logEvent(
            event,
            details: details,
            role: NotificationAuditContext.role,
            staffID: NotificationAuditContext.staffID,
            context: NotificationAuditContext.context,
            escalate: escalate
        )
        eventBuffer.append((timestamp: Date(), event: event, details: details, role: NotificationAuditContext.role, staffID: NotificationAuditContext.staffID, context: NotificationAuditContext.context, escalate: escalate))
        if eventBuffer.count > bufferLimit {
            eventBuffer.removeFirst(eventBuffer.count - bufferLimit)
        }
    }

    public func diagnostics() -> String {
        eventBuffer.map { evt in
            let dateStr = DateFormatter.localizedString(from: evt.timestamp, dateStyle: .short, timeStyle: .medium)
            let detailsStr = evt.details?.map { "\($0): \($1)" }.joined(separator: ", ") ?? ""
            let role = evt.role ?? "-"
            let staffID = evt.staffID ?? "-"
            let context = evt.context ?? "-"
            let escalate = evt.escalate ? "YES" : "NO"
            return "\(dateStr): \(evt.event) \(detailsStr) | role:\(role) staffID:\(staffID) context:\(context) escalate:\(escalate)"
        }.joined(separator: "\n")
    }
}

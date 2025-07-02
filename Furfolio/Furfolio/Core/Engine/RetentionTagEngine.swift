//
//  RetentionTagEngine.swift
//  Furfolio
//
//  Created by mac on 6/30/25.
//

// MARK: - Audit Context (set at login/session)
public struct RetentionTagAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "RetentionTagEngine"
}

public protocol RetentionTagAnalyticsLogger {
    var testMode: Bool { get }
    func logEvent(
        name: String,
        details: [String: Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async
}

public struct NullRetentionTagAnalyticsLogger: RetentionTagAnalyticsLogger {
    public let testMode: Bool = true
    public init() {}
    public func logEvent(
        name: String,
        details: [String: Any]? = nil,
        role: String? = nil,
        staffID: String? = nil,
        context: String? = nil,
        escalate: Bool = false
    ) async {
        let detailsString = details?.map { "\($0): \($1)" }.joined(separator: ", ") ?? "none"
        print("[NullRetentionTagAnalyticsLogger][TEST MODE] Event: \(name), Details: \(detailsString) | role:\(role ?? "-") staffID:\(staffID ?? "-") context:\(context ?? "-") escalate:\(escalate)")
    }
}

class RetentionTagEngine {
    private var analyticsLogger: RetentionTagAnalyticsLogger = NullRetentionTagAnalyticsLogger()
    private var eventBuffer: [(name: String, details: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool)] = []
    private let eventBufferMax = 20

    private func logAnalyticsEvent(name: String, details: [String: Any]? = nil) async {
        let escalate = name.lowercased().contains("danger") || name.lowercased().contains("critical") || name.lowercased().contains("delete")
            || (details?.values.contains { "\($0)".lowercased().contains("danger") || "\($0)".lowercased().contains("critical") || "\($0)".lowercased().contains("delete") } ?? false)
        await analyticsLogger.logEvent(
            name: name,
            details: details,
            role: RetentionTagAuditContext.role,
            staffID: RetentionTagAuditContext.staffID,
            context: RetentionTagAuditContext.context,
            escalate: escalate
        )
        eventBuffer.append((name, details, RetentionTagAuditContext.role, RetentionTagAuditContext.staffID, RetentionTagAuditContext.context, escalate))
        if eventBuffer.count > eventBufferMax {
            eventBuffer.removeFirst(eventBuffer.count - eventBufferMax)
        }
    }

    public func diagnosticsAuditTrail() -> [String] {
        eventBuffer.map { evt in
            let detailsStr = evt.details?.map { "\($0): \($1)" }.joined(separator: ", ") ?? ""
            let role = evt.role ?? "-"
            let staffID = evt.staffID ?? "-"
            let context = evt.context ?? "-"
            let escalate = evt.escalate ? "YES" : "NO"
            return "\(evt.name) \(detailsStr) | role:\(role) staffID:\(staffID) context:\(context) escalate:\(escalate)"
        }
    }
}

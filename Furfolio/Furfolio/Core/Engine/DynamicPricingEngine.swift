//
//  DynamicPricingEngine.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

// MARK: - Audit Context (set at login/session)
public struct DynamicPricingAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "DynamicPricingEngine"
}

public protocol DynamicPricingAnalyticsLogger {
    var testMode: Bool { get set }
    func logEvent(
        _ event: String,
        metadata: [String: Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async
}

public struct NullDynamicPricingAnalyticsLogger: DynamicPricingAnalyticsLogger {
    public var testMode: Bool = true
    public init() {}
    public func logEvent(
        _ event: String,
        metadata: [String: Any]? = nil,
        role: String? = nil,
        staffID: String? = nil,
        context: String? = nil,
        escalate: Bool = false
    ) async {
        if testMode {
            print("[DynamicPricingEngine][TEST MODE] \(event) \(metadata ?? [:]) | role:\(role ?? "-") staffID:\(staffID ?? "-") context:\(context ?? "-") escalate:\(escalate)")
        }
    }
}

private var analyticsLogger: DynamicPricingAnalyticsLogger = NullDynamicPricingAnalyticsLogger()
private var eventBuffer: [(timestamp: Date, event: String, metadata: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool)] = []
private let bufferLimit = 20

private func logAnalyticsEvent(_ event: String, metadata: [String: Any]? = nil) async {
    let escalate = event.lowercased().contains("danger") || event.lowercased().contains("critical") || event.lowercased().contains("delete")
        || (metadata?.values.contains { "\($0)".lowercased().contains("danger") || "\($0)".lowercased().contains("critical") || "\($0)".lowercased().contains("delete") } ?? false)
    await analyticsLogger.logEvent(
        event,
        metadata: metadata,
        role: DynamicPricingAuditContext.role,
        staffID: DynamicPricingAuditContext.staffID,
        context: DynamicPricingAuditContext.context,
        escalate: escalate
    )
    eventBuffer.append((timestamp: Date(), event: event, metadata: metadata, role: DynamicPricingAuditContext.role, staffID: DynamicPricingAuditContext.staffID, context: DynamicPricingAuditContext.context, escalate: escalate))
    if eventBuffer.count > bufferLimit {
        eventBuffer.removeFirst(eventBuffer.count - bufferLimit)
    }
}

public func diagnostics() -> String {
    eventBuffer.map { evt in
        let dateStr = DateFormatter.localizedString(from: evt.timestamp, dateStyle: .short, timeStyle: .medium)
        let metaStr = evt.metadata?.map { "\($0): \($1)" }.joined(separator: ", ") ?? ""
        let role = evt.role ?? "-"
        let staffID = evt.staffID ?? "-"
        let context = evt.context ?? "-"
        let escalate = evt.escalate ? "YES" : "NO"
        return "\(dateStr): \(evt.event) \(metaStr) | role:\(role) staffID:\(staffID) context:\(context) escalate:\(escalate)"
    }.joined(separator: "\n")
}

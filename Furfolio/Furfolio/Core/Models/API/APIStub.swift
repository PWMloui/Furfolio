//
//  APIStub.swift
//  Furfolio
//
//  Created by mac on 6/30/25.
//

// MARK: - Audit Context (set at login/session)
public struct APIStubAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "APIStub"
}

public struct APIStubAuditEvent: Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let endpoint: String
    public let requestPayload: String?
    public let responsePayload: String?
    public let status: String
    public let error: String?
    public let role: String?
    public let staffID: String?
    public let context: String?
    public let escalate: Bool

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        endpoint: String,
        requestPayload: String?,
        responsePayload: String?,
        status: String,
        error: String?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) {
        self.id = id
        self.timestamp = timestamp
        self.endpoint = endpoint
        self.requestPayload = requestPayload
        self.responsePayload = responsePayload
        self.status = status
        self.error = error
        self.role = role
        self.staffID = staffID
        self.context = context
        self.escalate = escalate
    }

    public var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        let base = "[\(dateStr)] API \(endpoint) [\(status)]"
        let details = [
            requestPayload.map { "Request: \($0)" },
            responsePayload.map { "Response: \($0)" },
            role.map { "Role: \($0)" },
            staffID.map { "StaffID: \($0)" },
            context.map { "Context: \($0)" },
            escalate ? "Escalate: YES" : nil,
            error != nil ? "Error: \(error!)" : nil
        ].compactMap { $0 }
        return ([base] + details).joined(separator: " | ")
    }
}

public final class APIStubAuditLogger {
    private static let queue = DispatchQueue(label: "furfolio.apistub.audit.logger")
    private static var log: [APIStubAuditEvent] = []
    private static let maxLogSize = 200

    public static func record(
        endpoint: String,
        requestPayload: String?,
        responsePayload: String?,
        status: String,
        error: String? = nil
    ) {
        let escalate = status.lowercased().contains("danger") || status.lowercased().contains("critical") || status.lowercased().contains("delete")
            || (error?.lowercased().contains("danger") ?? false)
        let event = APIStubAuditEvent(
            timestamp: Date(),
            endpoint: endpoint,
            requestPayload: requestPayload,
            responsePayload: responsePayload,
            status: status,
            error: error,
            role: APIStubAuditContext.role,
            staffID: APIStubAuditContext.staffID,
            context: APIStubAuditContext.context,
            escalate: escalate
        )
        queue.async {
            log.append(event)
            if log.count > maxLogSize {
                log.removeFirst(log.count - maxLogSize)
            }
        }
    }

    public static func allEvents(completion: @escaping ([APIStubAuditEvent]) -> Void) {
        queue.async { completion(log) }
    }
    public static func exportLogJSON(completion: @escaping (String?) -> Void) {
        queue.async {
            let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
            let json = (try? encoder.encode(log)).flatMap { String(data: $0, encoding: .utf8) }
            completion(json)
        }
    }
}

#if canImport(SwiftUI)
import SwiftUI

public struct APIStubAuditLogView: View {
    @State private var events: [APIStubAuditEvent] = []

    private func loadEvents() {
        APIStubAuditLogger.allEvents { events in
            DispatchQueue.main.async { self.events = events.suffix(50) }
        }
    }

    public var body: some View {
        VStack(alignment: .leading) {
            Text("APIStub Audit Log").font(.headline)
            List(events.reversed(), id: \.id) { event in
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.accessibilityLabel).font(.body)
                }
            }
            .onAppear(perform: loadEvents)
        }.padding()
    }
}
#endif

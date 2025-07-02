//
//  NFCHandler.swift
//  Furfolio
//
//  Created by mac on 6/30/25.
//

// MARK: - Audit Context (set at login/session)
public struct NFCHandlerAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "NFCHandler"
}

public struct NFCHandlerAuditEvent: Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let operation: String
    public let nfcPayload: String?
    public let success: Bool
    public let error: String?
    public let role: String?
    public let staffID: String?
    public let context: String?
    public let escalate: Bool

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        operation: String,
        nfcPayload: String?,
        success: Bool,
        error: String?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) {
        self.id = id
        self.timestamp = timestamp
        self.operation = operation
        self.nfcPayload = nfcPayload
        self.success = success
        self.error = error
        self.role = role
        self.staffID = staffID
        self.context = context
        self.escalate = escalate
    }

    public var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        let status = success ? "SUCCESS" : "FAIL"
        let base = "[\(dateStr)] NFC \(operation) (\(status))"
        let details = [
            nfcPayload.map { "Payload: \($0)" },
            role.map { "Role: \($0)" },
            staffID.map { "StaffID: \($0)" },
            context.map { "Context: \($0)" },
            escalate ? "Escalate: YES" : nil,
            error != nil ? "Error: \(error!)" : nil
        ].compactMap { $0 }
        return ([base] + details).joined(separator: " | ")
    }
}

public final class NFCHandlerAuditLogger {
    private static let queue = DispatchQueue(label: "furfolio.nfc.audit.logger")
    private static var log: [NFCHandlerAuditEvent] = []
    private static let maxLogSize = 200

    public static func record(
        operation: String,
        nfcPayload: String?,
        success: Bool,
        error: String? = nil
    ) {
        let escalate = operation.lowercased().contains("danger") || operation.lowercased().contains("critical") || operation.lowercased().contains("delete")
            || (error?.lowercased().contains("danger") ?? false)
        let event = NFCHandlerAuditEvent(
            timestamp: Date(),
            operation: operation,
            nfcPayload: nfcPayload,
            success: success,
            error: error,
            role: NFCHandlerAuditContext.role,
            staffID: NFCHandlerAuditContext.staffID,
            context: NFCHandlerAuditContext.context,
            escalate: escalate
        )
        queue.async {
            log.append(event)
            if log.count > maxLogSize {
                log.removeFirst(log.count - maxLogSize)
            }
        }
    }

    public static func allEvents(completion: @escaping ([NFCHandlerAuditEvent]) -> Void) {
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

public struct NFCHandlerAuditLogView: View {
    @State private var events: [NFCHandlerAuditEvent] = []

    private func loadEvents() {
        NFCHandlerAuditLogger.allEvents { events in
            DispatchQueue.main.async { self.events = events.suffix(50) }
        }
    }

    public var body: some View {
        VStack(alignment: .leading) {
            Text("NFC Handler Audit Log").font(.headline)
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

// Example usage in future NFC handler logic:
// NFCHandlerAuditLogger.record(operation: "read", nfcPayload: "someValue", success: true)
// NFCHandlerAuditLogger.record(operation: "write", nfcPayload: "payload123", success: false, error: "Tag write failed")


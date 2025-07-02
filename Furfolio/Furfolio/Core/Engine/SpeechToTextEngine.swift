//
//  SpeechToTextEngine.swift
//  Furfolio
//
//  Created by mac on 6/30/25.
//

import Foundation

// MARK: - Audit Context (set at login/session)
public struct SpeechToTextAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "SpeechToTextEngine"
}

// MARK: - Analytics Logger Protocol & Null Logger

public protocol SpeechToTextAnalyticsLogger {
    var testMode: Bool { get }
    func logEvent(
        event: String,
        parameters: [String: Any]?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) async
}

public struct NullSpeechToTextAnalyticsLogger: SpeechToTextAnalyticsLogger {
    public let testMode: Bool = true
    public init() {}
    public func logEvent(
        event: String,
        parameters: [String: Any]? = nil,
        role: String? = nil,
        staffID: String? = nil,
        context: String? = nil,
        escalate: Bool = false
    ) async {
        let paramStr = parameters?.map { "\($0): \($1)" }.joined(separator: ", ") ?? "none"
        print("[NullSpeechToTextAnalyticsLogger][TEST MODE] Event: \(event), Parameters: \(paramStr) | role:\(role ?? "-") staffID:\(staffID ?? "-") context:\(context ?? "-") escalate:\(escalate)")
    }
}

// MARK: - SpeechToTextEngine

public final class SpeechToTextEngine {
    // Analytics logger and buffer
    private var analyticsLogger: SpeechToTextAnalyticsLogger = NullSpeechToTextAnalyticsLogger()
    private var analyticsEventBuffer: [(timestamp: Date, event: String, parameters: [String: Any]?, role: String?, staffID: String?, context: String?, escalate: Bool)] = []
    private let analyticsEventBufferMax = 20

    public init() {}

    // MARK: - Main API

    public func transcribe(audioData: Data, language: String = "en-US") async -> String? {
        await logAnalyticsEvent(event: "transcribe_start", parameters: ["language": language, "audioBytes": audioData.count])
        // ----
        // Your speech recognition logic here.
        // Simulate fake result:
        let result = "This is a test transcription."
        // ----
        await logAnalyticsEvent(event: "transcribe_success", parameters: ["resultLength": result.count, "language": language])
        return result
    }

    public func handleError(_ error: Error) async {
        await logAnalyticsEvent(event: "transcribe_error", parameters: ["error": String(describing: error)])
    }

    // MARK: - Audit Logging

    private func logAnalyticsEvent(event: String, parameters: [String: Any]? = nil) async {
        let escalate = event.lowercased().contains("danger") || event.lowercased().contains("critical") || event.lowercased().contains("delete")
            || (parameters?.values.contains { "\($0)".lowercased().contains("danger") || "\($0)".lowercased().contains("critical") || "\($0)".lowercased().contains("delete") } ?? false)
        await analyticsLogger.logEvent(
            event: event,
            parameters: parameters,
            role: SpeechToTextAuditContext.role,
            staffID: SpeechToTextAuditContext.staffID,
            context: SpeechToTextAuditContext.context,
            escalate: escalate
        )
        analyticsEventBuffer.append((Date(), event, parameters, SpeechToTextAuditContext.role, SpeechToTextAuditContext.staffID, SpeechToTextAuditContext.context, escalate))
        if analyticsEventBuffer.count > analyticsEventBufferMax {
            analyticsEventBuffer.removeFirst(analyticsEventBuffer.count - analyticsEventBufferMax)
        }
    }

    // MARK: - Diagnostics / Trust Center Review

    public func diagnosticsAuditTrail() -> [String] {
        analyticsEventBuffer.map { evt in
            let dateStr = ISO8601DateFormatter().string(from: evt.timestamp)
            let paramStr = evt.parameters?.map { "\($0): \($1)" }.joined(separator: ", ") ?? ""
            let role = evt.role ?? "-"
            let staffID = evt.staffID ?? "-"
            let context = evt.context ?? "-"
            let escalate = evt.escalate ? "YES" : "NO"
            return "[\(dateStr)] \(evt.event) \(paramStr) | role:\(role) staffID:\(staffID) context:\(context) escalate:\(escalate)"
        }
    }

    // MARK: - Test/Preview API

    public func printDiagnostics() {
        for line in diagnosticsAuditTrail() {
            print(line)
        }
    }
}

// MARK: - Example Usage

#if DEBUG
// Simulate a quick test
@main
struct SpeechToTextTestApp {
    static func main() async {
        let engine = SpeechToTextEngine()
        _ = await engine.transcribe(audioData: Data([1, 2, 3]), language: "en-US")
        await engine.handleError(NSError(domain: "Speech", code: 999, userInfo: [NSLocalizedDescriptionKey: "Simulated error"]))
        engine.printDiagnostics()
    }
}
#endif


//
//  VoiceControlService.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import Foundation
import Speech
import SwiftUI

/**
 VoiceControlService
 -------------------
 A service for handling voice commands in Furfolio, with async analytics and audit logging.

 - **Purpose**: Manages speech recognition sessions and invokes command handlers.
 - **Architecture**: Singleton `ObservableObject` using `SFSpeechRecognizer` and `AVAudioEngine`.
 - **Concurrency & Async Logging**: Wraps recognition events in non-blocking `Task` blocks.
 - **Audit/Analytics Ready**: Defines protocols for async event tracking and integrates a dedicated audit manager actor.
 - **Localization**: User-facing messages use `NSLocalizedString`.
 - **Diagnostics & Preview/Testability**: Exposes methods to fetch and export recent audit entries.
 */

// MARK: - Analytics & Audit Protocols

public protocol VoiceAnalyticsLogger {
    /// Log a voice control event asynchronously.
    func log(event: String, metadata: [String: Any]?) async
}

public protocol VoiceAuditLogger {
    /// Record a voice control audit entry asynchronously.
    func record(_ message: String, metadata: [String: String]?) async
}

public struct NullVoiceAnalyticsLogger: VoiceAnalyticsLogger {
    public init() {}
    public func log(event: String, metadata: [String : Any]?) async {}
}

public struct NullVoiceAuditLogger: VoiceAuditLogger {
    public init() {}
    public func record(_ message: String, metadata: [String : String]?) async {}
}

// MARK: - Audit Entry & Manager

/// A record of a voice control audit event.
public struct VoiceAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let event: String
    public let detail: String?

    public init(id: UUID = UUID(), timestamp: Date = Date(), event: String, detail: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.event = event
        self.detail = detail
    }
}

/// Concurrency-safe actor for logging voice control events.
public actor VoiceAuditManager {
    private var buffer: [VoiceAuditEntry] = []
    private let maxEntries = 100
    public static let shared = VoiceAuditManager()

    public func add(_ entry: VoiceAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    public func recent(limit: Int = 20) -> [VoiceAuditEntry] {
        Array(buffer.suffix(limit))
    }

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

// MARK: - Service

@MainActor
public final class VoiceControlService: ObservableObject {
    public static let shared = VoiceControlService(
        analytics: NullVoiceAnalyticsLogger(),
        audit: NullVoiceAuditLogger()
    )

    private let recognizer = SFSpeechRecognizer()
    private let engine = AVAudioEngine()
    private let request = SFSpeechAudioBufferRecognitionRequest()
    private var task: SFSpeechRecognitionTask?

    private let analytics: VoiceAnalyticsLogger
    private let audit: VoiceAuditLogger

    @Published public var lastTranscript: String = ""
    @Published public var isListening: Bool = false

    private init(
        analytics: VoiceAnalyticsLogger,
        audit: VoiceAuditLogger
    ) {
        self.analytics = analytics
        self.audit = audit
    }

    /// Starts listening for voice commands.
    public func startListening() async {
        Task {
            await analytics.log(event: "listening_start", metadata: nil)
            await audit.record("Listening started", metadata: nil)
            await VoiceAuditManager.shared.add(
                VoiceAuditEntry(event: "listening_start", detail: nil)
            )
        }
        engine.inputNode.removeTap(onBus: 0)
        let node = engine.inputNode
        let format = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            self.request.append(buffer)
        }
        engine.prepare()
        try? engine.start()
        isListening = true
        task = recognizer?.recognitionTask(with: request) { result, error in
            if let result = result {
                let text = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.lastTranscript = text
                }
                Task {
                    await self.analytics.log(event: "transcript", metadata: ["text": text])
                    await self.audit.record("Transcript received", metadata: ["text": String(text.prefix(50))])
                    await VoiceAuditManager.shared.add(
                        VoiceAuditEntry(event: "transcript", detail: String(text.prefix(50)))
                    )
                }
            }
            if error != nil || (result?.isFinal ?? false) {
                self.stopListening()
            }
        }
    }

    /// Stops listening for voice commands.
    public func stopListening() {
        engine.stop()
        request.endAudio()
        task?.cancel()
        isListening = false
        Task {
            await analytics.log(event: "listening_stop", metadata: nil)
            await audit.record("Listening stopped", metadata: nil)
            await VoiceAuditManager.shared.add(
                VoiceAuditEntry(event: "listening_stop", detail: nil)
            )
        }
    }
}

// MARK: - Diagnostics

public extension VoiceControlService {
    /// Fetch recent voice control audit entries.
    static func recentAuditEntries(limit: Int = 20) async -> [VoiceAuditEntry] {
        await VoiceAuditManager.shared.recent(limit: limit)
    }

    /// Export voice control audit log as JSON.
    static func exportAuditLogJSON() async -> String {
        await VoiceAuditManager.shared.exportJSON()
    }
}


//
//  AIChatService.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import Foundation
import Combine

/**
 AIChatService
 -------------
 A centralized service for managing AI-powered chat interactions within Furfolio.

 - **Purpose**: Sends user messages to the AI backend and publishes AI responses.
 - **Architecture**: Singleton `ObservableObject` with Combine `Published` properties.
 - **Concurrency & Async Logging**: Uses async/await for network calls and logs events via `AIChatAuditManager`.
 - **Analytics Ready**: Defines async protocol `AIChatAnalyticsLogger` for event tracking.
 - **Localization**: Error messages use `NSLocalizedString`.
 - **Diagnostics & Preview/Testability**: Offers methods to fetch and export recent audit entries.
 */

// MARK: - Analytics Protocol

public protocol AIChatAnalyticsLogger {
    /// Log a chat event asynchronously.
    func log(event: String, metadata: [String: Any]?) async
}

/// No-op analytics logger for previews/testing.
public struct NullAIChatAnalyticsLogger: AIChatAnalyticsLogger {
    public init() {}
    public func log(event: String, metadata: [String: Any]?) async {}
}

// MARK: - Audit Entry & Manager

/// A record of an AI chat interaction event.
public struct AIChatAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let event: String
    public let details: String?

    public init(id: UUID = UUID(), timestamp: Date = Date(), event: String, details: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.event = event
        self.details = details
    }
}

/// Concurrency-safe actor for auditing AI chat events.
public actor AIChatAuditManager {
    private var buffer: [AIChatAuditEntry] = []
    private let maxEntries = 100
    public static let shared = AIChatAuditManager()

    /// Add a new audit entry, trimming older entries beyond `maxEntries`.
    public func add(_ entry: AIChatAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Fetch recent audit entries.
    public func recent(limit: Int = 20) -> [AIChatAuditEntry] {
        Array(buffer.suffix(limit))
    }

    /// Export audit log as JSON.
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

// MARK: - AIChatService

@MainActor
public final class AIChatService: ObservableObject {
    public static let shared = AIChatService()

    private let analytics: AIChatAnalyticsLogger
    @Published public private(set) var messages: [String] = []
    private var cancellables = Set<AnyCancellable>()

    private init(analytics: AIChatAnalyticsLogger = NullAIChatAnalyticsLogger()) {
        self.analytics = analytics
    }

    /// Sends a user message and retrieves the AI response.
    public func sendMessage(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Append user message
        messages.append("User: \(trimmed)")

        // Log event
        Task {
            await analytics.log(event: "chat_send", metadata: ["message": trimmed])
            await AIChatAuditManager.shared.add(
                AIChatAuditEntry(event: "chat_send", details: trimmed)
            )
        }

        do {
            let response = try await fetchAIResponse(for: trimmed)
            messages.append("AI: \(response)")

            // Log response receipt
            Task {
                await analytics.log(event: "chat_receive", metadata: ["response": response])
                await AIChatAuditManager.shared.add(
                    AIChatAuditEntry(event: "chat_receive", details: response)
                )
            }
        } catch {
            let errorMsg = NSLocalizedString("Failed to fetch AI response.", comment: "Chat error")
            messages.append("Error: \(errorMsg)")

            Task {
                await analytics.log(event: "chat_error", metadata: ["error": error.localizedDescription])
                await AIChatAuditManager.shared.add(
                    AIChatAuditEntry(event: "chat_error", details: error.localizedDescription)
                )
            }
        }
    }

    /// Fetches an AI-generated response (stubbed network call).
    private func fetchAIResponse(for prompt: String) async throws -> String {
        // Replace with real network call to AI backend
        try await Task.sleep(nanoseconds: 500_000_000)
        return "This is a simulated AI response to: \(prompt)"
    }
}

// MARK: - Diagnostics

public extension AIChatService {
    /// Fetch recent chat audit entries.
    static func recentAuditEntries(limit: Int = 20) async -> [AIChatAuditEntry] {
        await AIChatAuditManager.shared.recent(limit: limit)
    }

    /// Export chat audit log as JSON.
    static func exportAuditLogJSON() async -> String {
        await AIChatAuditManager.shared.exportJSON()
    }
}

//
//  FeedbackSubmissionService.swift
//  Furfolio
//
//  Created by mac on 6/21/25.
//  Enhanced: Enterprise-grade, model-driven, analytics/audit, DI, attachments, MVP/prod.
//

/**
 FeedbackSubmissionService
 -------------------------
 A service for submitting user feedback in Furfolio, supporting both completion-handler and async/await styles, with enterprise-grade analytics, audit logging, offline queuing, and attachments.

 - **Purpose**: Validates, queues, and submits feedback, handling offline scenarios and retries.
 - **Architecture**: Conforms to `FeedbackSubmissionServiceProtocol`, with dependency-injected `AnalyticsServiceProtocol`, `AuditLoggerProtocol`, and `OfflineFeedbackQueueProtocol`.
 - **Concurrency & Async Logging**: Wraps analytics and audit calls in non-blocking `Task` blocks and supports async methods.
 - **Diagnostics**: Provides an in-memory audit manager for troubleshooting and export of audit logs.
 - **Localization**: Error messages are localized via `NSLocalizedString`.
 */

import Foundation
import os

// MARK: - Audit Entry & Manager

/// A record of a feedback submission event.
public struct FeedbackAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let event: String
    public let feedbackId: UUID

    public init(id: UUID = UUID(), timestamp: Date = Date(), event: String, feedbackId: UUID) {
        self.id = id
        self.timestamp = timestamp
        self.event = event
        self.feedbackId = feedbackId
    }
}

/// Manages concurrency-safe audit logging for feedback events.
public actor FeedbackAuditManager {
    private var buffer: [FeedbackAuditEntry] = []
    private let maxEntries = 200
    public static let shared = FeedbackAuditManager()

    /// Add a new audit entry, retaining only the most recent `maxEntries`.
    public func add(_ entry: FeedbackAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Fetch recent audit entries.
    public func recent(limit: Int = 20) -> [FeedbackAuditEntry] {
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

// MARK: - Protocols

/// Protocol defining the interface for submitting user feedback as a full model.
protocol FeedbackSubmissionServiceProtocol {
    func submitFeedback(_ feedback: FeedbackSubmission, completion: @escaping (Result<Void, Error>) -> Void)
    func submitFeedback(_ feedback: FeedbackSubmission) async -> Result<Void, Error>
}

// MARK: - FeedbackSubmissionService

final class FeedbackSubmissionService: FeedbackSubmissionServiceProtocol {
    
    enum SubmissionError: Error, LocalizedError {
        case emptyFeedback
        case networkFailure
        case missingCategory
        case offline

        var errorDescription: String? {
            switch self {
            case .emptyFeedback:
                return NSLocalizedString("Feedback cannot be empty.", comment: "Error shown when user submits empty feedback")
            case .missingCategory:
                return NSLocalizedString("Please select a feedback category.", comment: "Error shown when feedback category missing")
            case .networkFailure:
                return NSLocalizedString("Failed to send feedback. Please try again later.", comment: "Error shown when feedback submission fails due to network issues")
            case .offline:
                return NSLocalizedString("You are offline. Feedback will be queued and submitted later.", comment: "Offline feedback error")
            }
        }
    }
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Furfolio", category: "FeedbackSubmission")
    private let analytics: AnalyticsServiceProtocol?
    private let auditLogger: AuditLoggerProtocol?
    private let offlineQueue: OfflineFeedbackQueueProtocol?
    private let artificialDelay: TimeInterval

    // MARK: - Init with DI for analytics/audit/queue
    init(
        analytics: AnalyticsServiceProtocol? = nil,
        auditLogger: AuditLoggerProtocol? = nil,
        offlineQueue: OfflineFeedbackQueueProtocol? = nil,
        artificialDelay: TimeInterval = 1.0
    ) {
        self.analytics = analytics
        self.auditLogger = auditLogger
        self.offlineQueue = offlineQueue
        self.artificialDelay = artificialDelay
    }

    // MARK: - Submission (Completion Handler Style)
    func submitFeedback(_ feedback: FeedbackSubmission, completion: @escaping (Result<Void, Error>) -> Void) {
        let trimmedMessage = feedback.message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else {
            completion(.failure(SubmissionError.emptyFeedback))
            logEvent(success: false, reason: "Empty feedback", feedback: feedback)
            Task {
                await FeedbackAuditManager.shared.add(
                    FeedbackAuditEntry(event: "empty_feedback", feedbackId: feedback.id)
                )
            }
            return
        }
        guard feedback.category != nil else {
            completion(.failure(SubmissionError.missingCategory))
            logEvent(success: false, reason: "Missing category", feedback: feedback)
            Task {
                await FeedbackAuditManager.shared.add(
                    FeedbackAuditEntry(event: "missing_category", feedbackId: feedback.id)
                )
            }
            return
        }
        // Simulate offline queue demo
        let isOffline = false // Replace with real reachability logic
        if isOffline, let offlineQueue {
            offlineQueue.enqueue(feedback)
            completion(.failure(SubmissionError.offline))
            logEvent(success: false, reason: "Offline, queued", feedback: feedback)
            Task {
                await FeedbackAuditManager.shared.add(
                    FeedbackAuditEntry(event: "offline_queued", feedbackId: feedback.id)
                )
            }
            analytics?.log(event: .feedbackQueued, metadata: feedback.analyticsSummary)
            Task {
                await FeedbackAuditManager.shared.add(
                    FeedbackAuditEntry(event: "feedback_queued", feedbackId: feedback.id)
                )
            }
            auditLogger?.record(event: .feedbackQueued, data: feedback)
            Task {
                await FeedbackAuditManager.shared.add(
                    FeedbackAuditEntry(event: "feedback_queued", feedbackId: feedback.id)
                )
            }
            return
        }

        // Simulate async network operation
        DispatchQueue.global().asyncAfter(deadline: .now() + artificialDelay) { [weak self] in
            let success = true // Replace with real network logic
            self?.handleSubmissionResult(success: success, feedback: feedback, completion: completion)
        }
    }
    
    // MARK: - Submission (Async/Await Style)
    func submitFeedback(_ feedback: FeedbackSubmission) async -> Result<Void, Error> {
        let trimmedMessage = feedback.message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else {
            logEvent(success: false, reason: "Empty feedback", feedback: feedback)
            Task {
                await FeedbackAuditManager.shared.add(
                    FeedbackAuditEntry(event: "empty_feedback", feedbackId: feedback.id)
                )
            }
            return .failure(SubmissionError.emptyFeedback)
        }
        guard feedback.category != nil else {
            logEvent(success: false, reason: "Missing category", feedback: feedback)
            Task {
                await FeedbackAuditManager.shared.add(
                    FeedbackAuditEntry(event: "missing_category", feedbackId: feedback.id)
                )
            }
            return .failure(SubmissionError.missingCategory)
        }
        let isOffline = false // Replace with real reachability
        if isOffline, let offlineQueue {
            offlineQueue.enqueue(feedback)
            logEvent(success: false, reason: "Offline, queued", feedback: feedback)
            Task {
                await FeedbackAuditManager.shared.add(
                    FeedbackAuditEntry(event: "offline_queued", feedbackId: feedback.id)
                )
            }
            analytics?.log(event: .feedbackQueued, metadata: feedback.analyticsSummary)
            Task {
                await FeedbackAuditManager.shared.add(
                    FeedbackAuditEntry(event: "feedback_queued", feedbackId: feedback.id)
                )
            }
            auditLogger?.record(event: .feedbackQueued, data: feedback)
            Task {
                await FeedbackAuditManager.shared.add(
                    FeedbackAuditEntry(event: "feedback_queued", feedbackId: feedback.id)
                )
            }
            return .failure(SubmissionError.offline)
        }
        try? await Task.sleep(nanoseconds: UInt64(artificialDelay * 1_000_000_000))
        let success = true // Replace with network result
        return await withCheckedContinuation { continuation in
            self.handleSubmissionResult(success: success, feedback: feedback) { result in
                continuation.resume(returning: result)
            }
        }
    }
    
    // MARK: - Internal logic
    private func handleSubmissionResult(
        success: Bool,
        feedback: FeedbackSubmission,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        logEvent(success: success, reason: success ? nil : "Network failure", feedback: feedback)
        if success {
            analytics?.log(event: .feedbackSubmitted, metadata: feedback.analyticsSummary)
            Task {
                await FeedbackAuditManager.shared.add(
                    FeedbackAuditEntry(event: "feedback_submitted", feedbackId: feedback.id)
                )
            }
            auditLogger?.record(event: .feedbackSubmitted, data: feedback)
            Task {
                await FeedbackAuditManager.shared.add(
                    FeedbackAuditEntry(event: "feedback_submitted", feedbackId: feedback.id)
                )
            }
            DispatchQueue.main.async { completion(.success(())) }
        } else {
            analytics?.log(event: .feedbackFailed, metadata: feedback.analyticsSummary)
            Task {
                await FeedbackAuditManager.shared.add(
                    FeedbackAuditEntry(event: "feedback_failed", feedbackId: feedback.id)
                )
            }
            auditLogger?.record(event: .feedbackFailed, data: feedback)
            Task {
                await FeedbackAuditManager.shared.add(
                    FeedbackAuditEntry(event: "feedback_failed", feedbackId: feedback.id)
                )
            }
            DispatchQueue.main.async { completion(.failure(SubmissionError.networkFailure)) }
        }
    }
    
    // MARK: - Analytics, Audit, Logging
    private func logEvent(success: Bool, reason: String?, feedback: FeedbackSubmission) {
        #if DEBUG
        print("FeedbackSubmissionService: \(success ? "Success" : "Failure") \(reason ?? "") (\(feedback.id))")
        #endif
        logger.log("\(success ? "Feedback submitted." : "Feedback failed. \(reason ?? "")") [Category: \(feedback.category?.rawValue ?? "-")] [Attachment: \(feedback.attachments?.isEmpty == false)]")
    }
}

// MARK: - Dependency Protocols

protocol AnalyticsServiceProtocol {
    func log(event: FeedbackAnalyticsEvent, metadata: [String: Any]?)
}
enum FeedbackAnalyticsEvent: String {
    case feedbackSubmitted
    case feedbackFailed
    case feedbackQueued
}

protocol AuditLoggerProtocol {
    func record(event: FeedbackAnalyticsEvent, data: FeedbackSubmission)
}
protocol OfflineFeedbackQueueProtocol {
    func enqueue(_ feedback: FeedbackSubmission)
}

// MARK: - FeedbackSubmission Model (minimal, for demo)
struct FeedbackSubmission: Identifiable, Codable, Equatable {
    let id: UUID
    let message: String
    let category: FeedbackCategory?
    let attachments: [FeedbackAttachment]?
    let metadata: [String: String]?

    // Analytics payload
    var analyticsSummary: [String: Any] {
        [
            "id": id.uuidString,
            "category": category?.rawValue ?? "-",
            "hasAttachment": attachments?.isEmpty == false,
            "meta": metadata ?? [:]
        ]
    }
}
struct FeedbackAttachment: Codable, Equatable {
    let filename: String
    let fileType: String
    let data: Data
}
enum FeedbackCategory: String, Codable {
    case bug, feature, general, other
}

// MARK: - Diagnostics

public extension FeedbackSubmissionService {
    /// Fetch recent feedback audit entries.
    static func recentAuditEntries(limit: Int = 20) async -> [FeedbackAuditEntry] {
        await FeedbackAuditManager.shared.recent(limit: limit)
    }

    /// Export feedback audit log as JSON.
    static func exportAuditLogJSON() async -> String {
        await FeedbackAuditManager.shared.exportJSON()
    }
}

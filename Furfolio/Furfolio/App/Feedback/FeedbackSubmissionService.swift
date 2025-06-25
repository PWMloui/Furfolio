//
//  FeedbackSubmissionService.swift
//  Furfolio
//
//  Created by mac on 6/21/25.
//  Enhanced for modularity, testability, and business analytics.
//

import Foundation
import os

// MARK: - FeedbackSubmissionServiceProtocol

/// Protocol defining the interface for submitting user feedback.
/// Implementations should handle the submission process and provide completion callbacks with success or error results.
protocol FeedbackSubmissionServiceProtocol {
    /// Submits the given feedback string (completion handler style).
    /// - Parameters:
    ///   - feedback: The user feedback to submit.
    ///   - completion: Completion handler called with a Result indicating success or failure.
    func submitFeedback(_ feedback: String, completion: @escaping (Result<Void, Error>) -> Void)
    
    /// Async/await variant for modern Swift concurrency.
    func submitFeedback(_ feedback: String) async -> Result<Void, Error>
}

// MARK: - FeedbackSubmissionService

/// Service responsible for submitting user feedback.
/// Handles validation, submission, auditing, analytics, and error reporting.
final class FeedbackSubmissionService: FeedbackSubmissionServiceProtocol {
    
    // MARK: - Error Types
    enum SubmissionError: Error, LocalizedError {
        case emptyFeedback
        case networkFailure
        
        var errorDescription: String? {
            switch self {
            case .emptyFeedback:
                return NSLocalizedString("Feedback cannot be empty.", comment: "Error shown when user submits empty feedback")
            case .networkFailure:
                return NSLocalizedString("Failed to send feedback. Please try again later.", comment: "Error shown when feedback submission fails due to network issues")
            }
        }
    }
    
    // MARK: - Constants
    private let artificialDelay: TimeInterval = 1.0 // Tokenize if you want to centralize delays
    
    // MARK: - Dependencies (for analytics/auditing, inject as needed)
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Furfolio", category: "FeedbackSubmission")
    // private let analytics: AnalyticsServiceProtocol
    // private let auditLogger: AuditLoggerProtocol
    
    // MARK: - Submission (Completion Handler Style)
    func submitFeedback(_ feedback: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let trimmedFeedback = feedback.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFeedback.isEmpty else {
            completion(.failure(SubmissionError.emptyFeedback))
            logEvent(success: false, reason: "Empty feedback")
            return
        }
        
        // Simulate async network operation
        DispatchQueue.global().asyncAfter(deadline: .now() + artificialDelay) { [weak self] in
            let success = true // Replace with actual network logic
            
            // Analytics and Audit Hooks
            self?.logEvent(success: success, reason: success ? nil : "Network failure")
            // self?.analytics.trackFeedbackSubmitted(trimmedFeedback, success: success)
            // self?.auditLogger.recordFeedbackEvent(feedback: trimmedFeedback, success: success)
            
            DispatchQueue.main.async {
                if success {
                    completion(.success(()))
                } else {
                    completion(.failure(SubmissionError.networkFailure))
                }
            }
        }
    }
    
    // MARK: - Submission (Async/Await Style)
    func submitFeedback(_ feedback: String) async -> Result<Void, Error> {
        let trimmedFeedback = feedback.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFeedback.isEmpty else {
            logEvent(success: false, reason: "Empty feedback")
            return .failure(SubmissionError.emptyFeedback)
        }
        try? await Task.sleep(nanoseconds: UInt64(artificialDelay * 1_000_000_000))
        let success = true // Replace with actual async network logic
        
        logEvent(success: success, reason: success ? nil : "Network failure")
        // analytics.trackFeedbackSubmitted(trimmedFeedback, success: success)
        // auditLogger.recordFeedbackEvent(feedback: trimmedFeedback, success: success)
        
        if success {
            return .success(())
        } else {
            return .failure(SubmissionError.networkFailure)
        }
    }
    
    // MARK: - Private Helpers
    private func logEvent(success: Bool, reason: String?) {
        #if DEBUG
        print("FeedbackSubmissionService: \(success ? "Success" : "Failure")\(reason.map { " (\($0))" } ?? "")")
        #endif
        logger.log("\(success ? "Feedback submitted." : "Feedback failed. \(reason ?? "")")")
    }
}

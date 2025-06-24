//
//  FeedbackSubmissionService.swift
//  Furfolio
//
//  Created by mac on 6/21/25.
//

import Foundation

/// Protocol defining the interface for submitting user feedback.
/// Implementations should handle the submission process and provide completion callbacks with success or error results.
protocol FeedbackSubmissionServiceProtocol {
    /// Submits the given feedback string.
    /// - Parameters:
    ///   - feedback: The user feedback to submit.
    ///   - completion: Completion handler called with a Result indicating success or failure.
    func submitFeedback(_ feedback: String, completion: @escaping (Result<Void, Error>) -> Void)
}

/// Service responsible for submitting user feedback.
/// This class handles validation, submission, and error reporting.
/// Extend or replace this service to customize feedback submission behavior.
final class FeedbackSubmissionService: FeedbackSubmissionServiceProtocol {

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

    func submitFeedback(_ feedback: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let trimmedFeedback = feedback.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedFeedback.isEmpty else {
            // TODO: Use AppError or a centralized error system instead of inline error strings for better token compliance.
            completion(.failure(SubmissionError.emptyFeedback))
            return
        }

        // Simulate network submission with delay
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
            let success = true // Replace with actual network logic

            // TODO: Log feedback submission success/failure here for business analytics or Trust Center auditing.

            DispatchQueue.main.async {
                if success {
                    completion(.success(()))
                } else {
                    completion(.failure(SubmissionError.networkFailure))
                }
            }
        }
    }
}

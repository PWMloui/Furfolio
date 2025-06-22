//
//  FeedbackSubmissionService.swift
//  Furfolio
//
//  Created by mac on 6/21/25.
//

import Foundation

protocol FeedbackSubmissionServiceProtocol {
    func submitFeedback(_ feedback: String, completion: @escaping (Result<Void, Error>) -> Void)
}

final class FeedbackSubmissionService: FeedbackSubmissionServiceProtocol {

    enum SubmissionError: Error, LocalizedError {
        case emptyFeedback
        case networkFailure

        var errorDescription: String? {
            switch self {
            case .emptyFeedback:
                return "Feedback cannot be empty."
            case .networkFailure:
                return "Failed to send feedback. Please try again later."
            }
        }
    }

    func submitFeedback(_ feedback: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let trimmedFeedback = feedback.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedFeedback.isEmpty else {
            completion(.failure(SubmissionError.emptyFeedback))
            return
        }

        // Simulate network submission with delay
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
            let success = true // Replace with actual network logic

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

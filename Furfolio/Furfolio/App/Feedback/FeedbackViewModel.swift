//
//  FeedbackViewModel.swift
//  Furfolio
//
//  Created by mac on 6/21/25.
//

import Foundation
import SwiftUI
import Combine

final class FeedbackViewModel: ObservableObject {

    // MARK: - Published UI State

    @Published var rating: Int = 5
    @Published var comment: String = ""
    @Published var screenshot: UIImage? = nil

    @Published var isSubmitting: Bool = false
    @Published var showSuccessAlert: Bool = false
    @Published var showErrorAlert: Bool = false
    @Published var errorMessage: String = ""

    // MARK: - Dependencies

    private let feedbackService: FeedbackSubmissionServiceProtocol

    // MARK: - Init

    init(feedbackService: FeedbackSubmissionServiceProtocol = FeedbackSubmissionService()) {
        self.feedbackService = feedbackService
    }

    // MARK: - Feedback Submission

    func submitFeedback() {
        let trimmedComment = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedComment.isEmpty else {
            self.errorMessage = "Feedback cannot be empty."
            self.showErrorAlert = true
            return
        }

        isSubmitting = true

        let feedback = UserFeedback(
            date: Date(),
            rating: rating,
            comment: trimmedComment,
            screenshot: screenshot
        )

        feedbackService.submitFeedback(trimmedComment) { [weak self] result in
            DispatchQueue.main.async {
                self?.isSubmitting = false
                switch result {
                case .success:
                    self?.resetForm()
                    self?.showSuccessAlert = true
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    self?.showErrorAlert = true
                }
            }
        }
    }

    // MARK: - Helpers

    func resetForm() {
        comment = ""
        rating = 5
        screenshot = nil
    }
}

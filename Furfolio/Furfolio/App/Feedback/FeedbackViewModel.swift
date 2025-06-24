//
//  FeedbackViewModel.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//  Unified, enhanced, SwiftUI-ready.
//

import Foundation
import Combine

/**
 FeedbackViewModel
 -----------------
 View model for managing user feedback submission in Furfolio.
 - Handles input binding for message, contact, and category.
 - Performs validation and submission to FeedbackSubmissionService.
 - Ready for audit/analytics: see `submitFeedback()` for TODO on logging submissions (success/failure) for business analytics or Trust Center auditing.
 - Extensible: Add new feedback fields or submission logic as needed.
 */
@MainActor
final class FeedbackViewModel: ObservableObject {
    // Input fields
    @Published var message: String = ""
    @Published var contact: String = ""
    @Published var category: FeedbackCategory = .suggestion

    // State
    @Published var isSubmitting: Bool = false
    @Published var showSuccess: Bool = false
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()

    // Submission logic
    func submitFeedback() {
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = NSLocalizedString(
                "feedback_error_empty_message",
                value: "Feedback message cannot be empty.",
                comment: "Error shown to the user when the feedback message field is left empty."
            )
            return
        }
        isSubmitting = true
        errorMessage = nil

        let submission = FeedbackSubmission(
            message: message.trimmingCharacters(in: .whitespacesAndNewlines),
            contact: contact.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : contact,
            category: category
        )

        FeedbackSubmissionService.shared.submitFeedback(submission) { [weak self] result in
            Task { @MainActor in
                self?.isSubmitting = false
                switch result {
                case .success:
                    self?.showSuccess = true
                    self?.clearFields()
                    // TODO: Log feedback submission success for business analytics or Trust Center auditing.
                case .failure(let error):
                    // TODO: Log feedback submission failure for business analytics or Trust Center auditing.
                    self?.errorMessage = NSLocalizedString(
                        "feedback_error_submission_failed",
                        value: error.localizedDescription,
                        comment: "Error shown to the user when feedback submission fails."
                    )
                }
            }
        }
    }

    func clearFields() {
        message = ""
        contact = ""
        category = .suggestion
    }
}

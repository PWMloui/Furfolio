//
//  FeedbackViewModel.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//  Enhanced: tokenized, testable, auditable, async/await-ready.
//

import Foundation
import Combine

/**
 FeedbackViewModel
 -----------------
 View model for managing user feedback submission in Furfolio.
 - Handles input binding for message, contact, and category.
 - Performs validation and submission via FeedbackSubmissionServiceProtocol (DI for testing/mockability).
 - Audit/analytics hooks for success/failure events.
 - Async/await + callback support for future concurrency.
 - Fully localizable and error-tokenized.
 */
@MainActor
final class FeedbackViewModel: ObservableObject {
    // MARK: - Input fields
    @Published var message: String = ""
    @Published var contact: String = ""
    @Published var category: FeedbackCategory = .suggestion

    // MARK: - State
    @Published var isSubmitting: Bool = false
    @Published var showSuccess: Bool = false
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()

    // Dependency injection for testability
    private let submissionService: FeedbackSubmissionServiceProtocol

    // MARK: - Init
    init(submissionService: FeedbackSubmissionServiceProtocol = FeedbackSubmissionService.shared) {
        self.submissionService = submissionService
    }

    // MARK: - Submission logic (Callback style)
    func submitFeedback() {
        errorMessage = nil
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = NSLocalizedString(
                "feedback_error_empty_message",
                value: "Feedback message cannot be empty.",
                comment: "Error shown when feedback message is empty."
            )
            return
        }
        isSubmitting = true

        let submission = FeedbackSubmission(
            message: message.trimmingCharacters(in: .whitespacesAndNewlines),
            contact: contact.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : contact,
            category: category
        )

        submissionService.submitFeedback(submission) { [weak self] result in
            Task { @MainActor in
                guard let self = self else { return }
                self.isSubmitting = false
                switch result {
                case .success:
                    self.showSuccess = true
                    self.logAudit(success: true)
                    self.clearFields()
                case .failure(let error):
                    self.showSuccess = false
                    self.logAudit(success: false, error: error)
                    self.errorMessage = NSLocalizedString(
                        "feedback_error_submission_failed",
                        value: error.localizedDescription,
                        comment: "Error shown when feedback submission fails."
                    )
                }
            }
        }
    }

    // MARK: - Submission logic (Async/Await style)
    func submitFeedbackAsync() async {
        errorMessage = nil
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = NSLocalizedString(
                "feedback_error_empty_message",
                value: "Feedback message cannot be empty.",
                comment: "Error shown when feedback message is empty."
            )
            return
        }
        isSubmitting = true

        let submission = FeedbackSubmission(
            message: message.trimmingCharacters(in: .whitespacesAndNewlines),
            contact: contact.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : contact,
            category: category
        )

        let result = await submissionService.submitFeedback(submission)
        self.isSubmitting = false

        switch result {
        case .success:
            self.showSuccess = true
            self.logAudit(success: true)
            self.clearFields()
        case .failure(let error):
            self.showSuccess = false
            self.logAudit(success: false, error: error)
            self.errorMessage = NSLocalizedString(
                "feedback_error_submission_failed",
                value: error.localizedDescription,
                comment: "Error shown when feedback submission fails."
            )
        }
    }

    // MARK: - Audit/Analytics
    private func logAudit(success: Bool, error: Error? = nil) {
        // TODO: Connect to analytics/audit system (Trust Center)
        // Example: Analytics.logFeedbackSubmission(success: success, error: error)
    }

    // MARK: - Helpers
    func clearFields() {
        message = ""
        contact = ""
        category = .suggestion
    }

    func reset() {
        clearFields()
        isSubmitting = false
        showSuccess = false
        errorMessage = nil
    }
}

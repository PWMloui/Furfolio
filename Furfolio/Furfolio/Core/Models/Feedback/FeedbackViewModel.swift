//
//  FeedbackViewModel.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//  Enhanced: attachment, offline, audit, analytics, tokenized, testable.
//

import Foundation
import Combine

@MainActor
final class FeedbackViewModel: ObservableObject {
    // MARK: - Input fields
    @Published var message: String = ""
    @Published var contact: String = ""
    @Published var category: FeedbackCategory = .general
    @Published var attachments: [FeedbackAttachment] = []

    // MARK: - State
    @Published var isSubmitting: Bool = false
    @Published var showSuccess: Bool = false
    @Published var errorMessage: String?

    // Offline support
    @Published var queuedFeedbackCount: Int = 0

    private var cancellables = Set<AnyCancellable>()

    // Dependency injection for testability and analytics
    private let submissionService: FeedbackSubmissionServiceProtocol
    private let analytics: AnalyticsServiceProtocol
    private let errorLogger: ErrorLoggerProtocol
    private let offlineStore: OfflineFeedbackStoreProtocol

    // MARK: - Init
    init(
        submissionService: FeedbackSubmissionServiceProtocol = FeedbackSubmissionService.shared,
        analytics: AnalyticsServiceProtocol = AnalyticsService.shared,
        errorLogger: ErrorLoggerProtocol = ErrorLogger.shared,
        offlineStore: OfflineFeedbackStoreProtocol = OfflineFeedbackStore.shared
    ) {
        self.submissionService = submissionService
        self.analytics = analytics
        self.errorLogger = errorLogger
        self.offlineStore = offlineStore
        self.queuedFeedbackCount = offlineStore.count
    }

    // MARK: - Attachments
    func addAttachment(_ att: FeedbackAttachment) {
        attachments.append(att)
    }

    func removeAttachment(_ att: FeedbackAttachment) {
        attachments.removeAll { $0 == att }
    }

    // MARK: - Submission logic (Callback style)
    func submitFeedback() {
        errorMessage = nil
        guard validateInput() else { return }
        isSubmitting = true

        let submission = makeSubmission()
        submissionService.submitFeedback(submission) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.isSubmitting = false
                switch result {
                case .success:
                    self.handleSuccess(submission)
                case .failure(let error):
                    self.handleFailure(submission, error: error)
                }
            }
        }
    }

    // MARK: - Submission logic (Async/Await style)
    func submitFeedbackAsync() async {
        errorMessage = nil
        guard validateInput() else { return }
        isSubmitting = true

        let submission = makeSubmission()
        let result = await submissionService.submitFeedback(submission)
        isSubmitting = false

        switch result {
        case .success:
            handleSuccess(submission)
        case .failure(let error):
            handleFailure(submission, error: error)
        }
    }

    // MARK: - Offline feedback
    func queueOfflineFeedback() {
        let submission = makeSubmission()
        offlineStore.save(submission)
        queuedFeedbackCount = offlineStore.count
        showSuccess = true
        Task {
            analytics.log(event: .feedbackQueued)
        }
        clearFields()
    }

    func retryQueuedFeedbackIfNeeded() async {
        guard offlineStore.count > 0 else { return }
        let queued = offlineStore.all()
        for feedback in queued {
            let result = await submissionService.submitFeedback(feedback)
            if case .success = result {
                offlineStore.remove(feedback)
                analytics.log(event: .feedbackSubmitted)
            } else if case .failure(let error) = result {
                errorLogger.log(error: error, context: "Retrying offline feedback")
            }
        }
        queuedFeedbackCount = offlineStore.count
    }

    // MARK: - Helpers

    private func makeSubmission() -> FeedbackSubmission {
        FeedbackSubmission(
            message: message.trimmingCharacters(in: .whitespacesAndNewlines),
            contact: contact.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : contact,
            category: category,
            attachments: attachments.isEmpty ? nil : attachments,
            metadata: [
                "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-",
                "osVersion": ProcessInfo.processInfo.operatingSystemVersionString
            ]
        )
    }

    private func validateInput() -> Bool {
        if message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = NSLocalizedString(
                "feedback_error_empty_message",
                value: "Feedback message cannot be empty.",
                comment: "Error shown when feedback message is empty."
            )
            return false
        }
        return true
    }

    private func handleSuccess(_ submission: FeedbackSubmission) {
        showSuccess = true
        Task {
            analytics.log(event: .feedbackSubmitted)
        }
        logAudit(success: true, submission: submission)
        clearFields()
    }

    private func handleFailure(_ submission: FeedbackSubmission, error: Error) {
        showSuccess = false
        errorLogger.log(error: error, context: "Feedback submission")
        Task {
            analytics.log(event: .feedbackFailed)
        }
        logAudit(success: false, submission: submission, error: error)
        errorMessage = NSLocalizedString(
            "feedback_error_submission_failed",
            value: error.localizedDescription,
            comment: "Error shown when feedback submission fails."
        )
    }

    // MARK: - Audit/Analytics
    /// Logs feedback submission to the centralized audit system asynchronously.
    /// - Parameters:
    ///   - success: Whether submission succeeded.
    ///   - submission: The feedback submission data.
    ///   - error: Optional error on failure.
    private func logAudit(success: Bool, submission: FeedbackSubmission, error: Error? = nil) {
        Task {
            await AuditLogManager.shared.logFeedback(submission, success: success, error: error)
        }
    }

    // MARK: - Field/state reset
    func clearFields() {
        message = ""
        contact = ""
        category = .general
        attachments = []
    }

    func reset() {
        clearFields()
        isSubmitting = false
        showSuccess = false
        errorMessage = nil
    }
}

// MARK: - Protocols

protocol FeedbackSubmissionServiceProtocol {
    func submitFeedback(_ submission: FeedbackSubmission, completion: @escaping (Result<Void, Error>) -> Void)
    func submitFeedback(_ submission: FeedbackSubmission) async -> Result<Void, Error>
}

protocol AnalyticsServiceProtocol {
    func log(event: AnalyticsEvent)
}

protocol ErrorLoggerProtocol {
    func log(error: Error, context: String)
}

// MARK: - Offline Feedback Store Protocol

protocol OfflineFeedbackStoreProtocol {
    var count: Int { get }
    func save(_ feedback: FeedbackSubmission)
    func remove(_ feedback: FeedbackSubmission)
    func all() -> [FeedbackSubmission]
}

final class OfflineFeedbackStore: OfflineFeedbackStoreProtocol {
    static let shared = OfflineFeedbackStore()
    private let key = "OfflineFeedbackQueue"
    private var store: [FeedbackSubmission] = []

    var count: Int { store.count }
    func save(_ feedback: FeedbackSubmission) {
        store.append(feedback)
        persist()
    }
    func remove(_ feedback: FeedbackSubmission) {
        store.removeAll { $0.id == feedback.id }
        persist()
    }
    func all() -> [FeedbackSubmission] { store }

    private func persist() {
        // For MVP, do nothing. For prod, serialize to disk/UserDefaults/keychain as needed.
    }
}

// MARK: - Analytics Event

enum AnalyticsEvent: String {
    case feedbackSubmitted
    case feedbackFailed
    case feedbackQueued
}

// MARK: - Category (full)

enum FeedbackCategory: String, CaseIterable, Codable {
    case bugReport, featureRequest, general
    var displayName: String {
        switch self {
        case .bugReport: return "Bug"
        case .featureRequest: return "Feature"
        case .general: return "Other"
        }
    }
}

// MARK: - Attachment Model

struct FeedbackAttachment: Codable, Equatable {
    let filename: String
    let fileType: String
    let data: Data
}

// MARK: - FeedbackSubmission Model (for context)

struct FeedbackSubmission: Identifiable, Codable, Equatable {
    let id: UUID
    let message: String
    let contact: String?
    let category: FeedbackCategory
    let attachments: [FeedbackAttachment]?
    let metadata: [String: String]?
    
    init(
        id: UUID = UUID(),
        message: String,
        contact: String?,
        category: FeedbackCategory,
        attachments: [FeedbackAttachment]? = nil,
        metadata: [String: String]? = nil
    ) {
        self.id = id
        self.message = message
        self.contact = contact
        self.category = category
        self.attachments = attachments
        self.metadata = metadata
    }
}

#if DEBUG
extension FeedbackViewModel {
    static var mock: FeedbackViewModel {
        FeedbackViewModel(
            submissionService: MockFeedbackSubmissionService(),
            analytics: MockAnalyticsService(),
            errorLogger: MockErrorLogger(),
            offlineStore: OfflineFeedbackStore()
        )
    }
}
struct MockFeedbackSubmissionService: FeedbackSubmissionServiceProtocol {
    func submitFeedback(_ submission: FeedbackSubmission, completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion(.success(()))
        }
    }
    func submitFeedback(_ submission: FeedbackSubmission) async -> Result<Void, Error> {
        .success(())
    }
}
struct MockAnalyticsService: AnalyticsServiceProtocol {
    func log(event: AnalyticsEvent) { }
}
struct MockErrorLogger: ErrorLoggerProtocol {
    func log(error: Error, context: String) { }
}
#endif

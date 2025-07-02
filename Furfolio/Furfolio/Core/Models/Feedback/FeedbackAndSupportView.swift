// FeedbackAndSupportView.swift

import SwiftUI
import Combine
import UniformTypeIdentifiers
import SwiftData

// MARK: - Protocols

protocol FeedbackSubmitting {
    func submitFeedback(_ submission: FeedbackSubmission) async throws -> Bool
}

protocol AnalyticsLogging {
    func logEvent(_ name: String, parameters: [String: Any]?)
}

protocol ErrorLogging {
    func logError(_ error: Error, context: String)
}

// MARK: - ViewModel

@MainActor
final class FeedbackAndSupportViewModel: ObservableObject {
    @Published var feedback: String = ""
    @Published var category: FeedbackCategory = .general
    @Published var isSubmitting: Bool = false
    @Published var showSuccessAlert: Bool = false
    @Published var showErrorAlert: Bool = false
    @Published var attachment: FeedbackAttachment? = nil
    @Published var queuedCount: Int = 0

    private let feedbackService: FeedbackSubmitting
    private let analytics: AnalyticsLogging
    private let errorLogger: ErrorLogging
    private let offlineStore: OfflineFeedbackQueue

    init(
        feedbackService: FeedbackSubmitting,
        analytics: AnalyticsLogging,
        errorLogger: ErrorLogging,
        offlineStore: OfflineFeedbackQueue = .shared
    ) {
        self.feedbackService = feedbackService
        self.analytics = analytics
        self.errorLogger = errorLogger
        self.offlineStore = offlineStore
        self.queuedCount = offlineStore.count
    }

    func submitFeedback() async {
        let trimmed = feedback.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSubmitting = true

        let submission = FeedbackSubmission(
            message: trimmed,
            category: category,
            attachment: attachment
        )

        do {
            let success = try await feedbackService.submitFeedback(submission)
            isSubmitting = false
            if success {
                analytics.logEvent("feedback_submitted", parameters: submission.analyticsPayload)
                feedback = ""
                attachment = nil
                showSuccessAlert = true
                category = .general
                // Haptic feedback for success
                #if os(iOS)
                await FeedbackAndSupportViewModel.generateHapticSuccess()
                #endif
            } else {
                offlineStore.enqueue(submission)
                queuedCount = offlineStore.count
                analytics.logEvent("feedback_queued_offline", parameters: submission.analyticsPayload)
                showErrorAlert = true
                #if os(iOS)
                await FeedbackAndSupportViewModel.generateHapticError()
                #endif
            }
        } catch {
            isSubmitting = false
            offlineStore.enqueue(submission)
            queuedCount = offlineStore.count
            analytics.logEvent("feedback_queued_offline", parameters: submission.analyticsPayload)
            showErrorAlert = true
            errorLogger.logError(error, context: "submitFeedback")
            #if os(iOS)
            await FeedbackAndSupportViewModel.generateHapticError()
            #endif
        }
    }

    func retryQueuedFeedbackIfNeeded() async {
        guard offlineStore.count > 0 else { return }
        let toRetry = offlineStore.dequeueAll()
        for submission in toRetry {
            do {
                let success = try await feedbackService.submitFeedback(submission)
                if success {
                    analytics.logEvent("feedback_submitted_from_queue", parameters: submission.analyticsPayload)
                } else {
                    offlineStore.enqueue(submission)
                }
            } catch {
                offlineStore.enqueue(submission)
                errorLogger.logError(error, context: "retryQueuedFeedbackIfNeeded")
            }
            queuedCount = offlineStore.count
        }
    }

    func addAttachment(_ att: FeedbackAttachment) {
        self.attachment = att
    }

    func removeAttachment() {
        self.attachment = nil
    }

    func reset() {
        feedback = ""
        isSubmitting = false
        showSuccessAlert = false
        showErrorAlert = false
        attachment = nil
        category = .general
    }

#if os(iOS)
    // Swift Concurrency haptic helpers
    static func generateHapticSuccess() async {
        await MainActor.run {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
    static func generateHapticError() async {
        await MainActor.run {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
#endif
}

// MARK: - Feedback Submission Model

@Model public
struct FeedbackSubmission: Identifiable {
    @Attribute(.unique) var id: UUID = UUID()
    let message: String
    let category: FeedbackCategory
    let attachment: FeedbackAttachment?

    @Attribute(.transient)
    var analyticsPayload: [String: Any] {
        [
            "id": id.uuidString,
            "category": category.rawValue,
            "hasAttachment": attachment != nil
        ]
    }
}

enum FeedbackCategory: String, CaseIterable, Identifiable, Codable {
    case bug
    case feature
    case general

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .bug: return NSLocalizedString("Bug", comment: "Feedback category")
        case .feature: return NSLocalizedString("Feature", comment: "Feedback category")
        case .general: return NSLocalizedString("General", comment: "Feedback category")
        }
    }
}

struct FeedbackAttachment: Codable, Equatable {
    let filename: String
    let fileType: String
    let data: Data
}

// MARK: - Offline Feedback Store

final class OfflineFeedbackQueue {
    static let shared = OfflineFeedbackQueue()
    private let key = "OfflineFeedbackQueue"
    private var queue: [FeedbackSubmission] = []

    var count: Int { queue.count }

    func enqueue(_ submission: FeedbackSubmission) {
        queue.append(submission)
        persist()
    }
    func dequeueAll() -> [FeedbackSubmission] {
        let out = queue
        queue.removeAll()
        persist()
        return out
    }
    private func persist() {
        // For MVP, this is in-memory. For prod, serialize to disk/UserDefaults/etc.
    }
}

// MARK: - View

struct FeedbackAndSupportView: View {
    @StateObject private var viewModel: FeedbackAndSupportViewModel

    @FocusState private var isTextEditorFocused: Bool
    @State private var showAttachmentPicker = false
    @State private var tempAttachment: FeedbackAttachment?

    init(
        viewModel: FeedbackAndSupportViewModel = .previewInstance
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xLarge ?? 28) {
                headerSection
                descriptionText
                categoryPicker
                feedbackForm
                attachmentSection
                submitButton
                helpAndQueueSection
            }
            .padding(AppSpacing.medium ?? 18)
            .onTapGesture { isTextEditorFocused = false }
        }
        .background(AppColors.background ?? Color(UIColor.systemBackground))
        .navigationTitle(LocalizedStringKey("Feedback & Support"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(LocalizedStringKey("Thank you!"), isPresented: $viewModel.showSuccessAlert) {
            Button(LocalizedStringKey("OK"), role: .cancel) { }
        } message: {
            Text(LocalizedStringKey("Your feedback has been sent. We appreciate your input!"))
        }
        .alert(LocalizedStringKey("Queued"), isPresented: $viewModel.showErrorAlert) {
            Button(LocalizedStringKey("OK"), role: .cancel) { }
        } message: {
            Text(LocalizedStringKey("You appear to be offline. Your feedback is safely queued and will send automatically."))
        }
        .animation(.easeInOut, value: viewModel.isSubmitting)
        .sheet(isPresented: $showAttachmentPicker) {
            AttachmentPicker(attachment: $tempAttachment)
        }
        .onChange(of: tempAttachment) { att in
            if let att = att {
                viewModel.addAttachment(att)
                tempAttachment = nil
            }
        }
        .refreshable {
            await viewModel.retryQueuedFeedbackIfNeeded()
        }
        .onAppear {
            Task {
                await viewModel.retryQueuedFeedbackIfNeeded()
            }
        }
    }

    // MARK: - UI Sections

    private var headerSection: some View {
        Image(systemName: "bubble.left.and.bubble.right.fill")
            .resizable()
            .scaledToFit()
            .frame(width: AppSpacing.xxxLarge ?? 72, height: AppSpacing.xxxLarge ?? 72)
            .foregroundStyle(AppColors.accent ?? Color.accentColor)
            .padding(.top, AppSpacing.large ?? 24)
            .accessibilityLabel(Text(NSLocalizedString("Feedback and Support Icon", comment: "Feedback header icon")))
            .accessibilityHint(Text(NSLocalizedString("Decorative header image representing feedback and support", comment: "Header icon hint")))
            .accessibilityIdentifier("headerImage")
    }

    private var descriptionText: some View {
        VStack(spacing: AppSpacing.small ?? 8) {
            Text(LocalizedStringKey("Feedback & Support"))
                .font(AppFonts.title?.bold() ?? .title.bold())
                .accessibilityAddTraits(.isHeader)
            Text(LocalizedStringKey("Share your thoughts, suggest features, or report an issue. Our team appreciates your feedback and will get back to you as soon as possible."))
                .multilineTextAlignment(.center)
                .font(AppFonts.body ?? .body)
                .foregroundStyle(AppColors.secondaryText ?? .secondary)
        }
        .padding(.horizontal, AppSpacing.medium ?? 16)
    }

    private var categoryPicker: some View {
        Picker(LocalizedStringKey("Category"), selection: $viewModel.category) {
            ForEach(FeedbackCategory.allCases) { cat in
                Text(cat.displayName).tag(cat)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal, AppSpacing.medium ?? 18)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(NSLocalizedString("Feedback category", comment: "Picker label")))
        .accessibilityHint(Text(NSLocalizedString("Select the type of feedback", comment: "Picker hint")))
        .accessibilityIdentifier("categoryPicker")
    }

    private var feedbackForm: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small ?? 10) {
            Text(LocalizedStringKey("Your Feedback"))
                .font(AppFonts.headline ?? .headline)
            ZStack(alignment: .topLeading) {
                if viewModel.feedback.isEmpty {
                    Text(LocalizedStringKey("Type your message here…"))
                        .foregroundStyle(AppColors.secondaryText ?? .secondary)
                        .padding(.top, AppSpacing.small ?? 8)
                        .padding(.horizontal, AppSpacing.xxSmall ?? 6)
                        .accessibilityHidden(true)
                }
                TextEditor(text: $viewModel.feedback)
                    .focused($isTextEditorFocused)
                    .frame(height: 150)
                    .padding(AppSpacing.xxSmall ?? 6)
                    .background(AppColors.secondaryBackground ?? Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.large ?? 12))
                    .accessibilityLabel(Text(NSLocalizedString("Feedback text", comment: "Feedback texteditor label")))
                    .accessibilityHint(Text(NSLocalizedString("Enter your feedback or support request here", comment: "Feedback editor hint")))
                    .accessibilityIdentifier("feedbackTextEditor")
            }
        }
        .padding(.horizontal, AppSpacing.medium ?? 18)
    }

    private var attachmentSection: some View {
        HStack(spacing: AppSpacing.small ?? 12) {
            Button {
                showAttachmentPicker = true
            } label: {
                Label(
                    viewModel.attachment == nil
                        ? NSLocalizedString("Add Attachment", comment: "")
                        : NSLocalizedString("Replace Attachment", comment: ""),
                    systemImage: "paperclip")
                    .labelStyle(.titleAndIcon)
                    .font(.body.weight(.semibold))
                    .padding(.vertical, 12)
                    .padding(.horizontal, 10)
            }
            .accessibilityLabel(Text(NSLocalizedString("Add or replace attachment", comment: "Attachment button label")))
            .accessibilityHint(Text(NSLocalizedString("Attach a file or screenshot", comment: "Attachment button hint")))
            .accessibilityIdentifier("attachmentButton")
            .background(
                (AppColors.secondaryBackground ?? Color.secondary.opacity(0.07))
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            if let attachment = viewModel.attachment {
                Text(attachment.filename)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .font(AppFonts.footnote ?? .footnote)
                    .accessibilityIdentifier("attachmentFilename")
                Button(action: { viewModel.removeAttachment() }) {
                    Image(systemName: "xmark.circle")
                        .imageScale(.large)
                        .accessibilityLabel(Text(NSLocalizedString("Remove attachment", comment: "Remove attachment button label")))
                        .accessibilityHint(Text(NSLocalizedString("Remove the current attachment", comment: "Remove attachment button hint")))
                        .accessibilityIdentifier("removeAttachmentButton")
                }
                .padding(.leading, 4)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            Spacer()
        }
        .padding(.horizontal, AppSpacing.medium ?? 18)
    }

    private var submitButton: some View {
        Button(action: {
            Task {
                await viewModel.submitFeedback()
            }
            isTextEditorFocused = false
        }) {
            HStack {
                if viewModel.isSubmitting {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(1.1)
                        .tint(AppColors.accent ?? .accentColor)
                        .padding(.trailing, 8)
                }
                Text(LocalizedStringKey("Send Feedback"))
                    .font(AppFonts.button ?? .headline)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 48)
            .padding(AppSpacing.medium ?? 18)
            .background(
                (viewModel.isSubmitting || viewModel.feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                ? (AppColors.accent ?? .accentColor).opacity(0.09)
                : (AppColors.accent ?? .accentColor).opacity(0.19)
            )
            .foregroundStyle(AppColors.accent ?? .accentColor)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.large ?? 12))
            .animation(.easeInOut(duration: 0.15), value: viewModel.isSubmitting)
        }
        .disabled(viewModel.feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSubmitting)
        .padding(.horizontal, AppSpacing.medium ?? 18)
        .accessibilityLabel(Text(NSLocalizedString("Send Feedback", comment: "Send feedback button label")))
        .accessibilityHint(Text(NSLocalizedString("Send your feedback to the Furfolio team", comment: "Send feedback button hint")))
        .accessibilityIdentifier("sendFeedbackButton")
    }

    private var helpAndQueueSection: some View {
        VStack(spacing: AppSpacing.xSmall ?? 10) {
            Link(LocalizedStringKey("Visit Help Center"), destination: URL(string: "https://furfolio.app/help")!)
                .font(AppFonts.footnote ?? .footnote)
                .accessibilityLabel(Text(NSLocalizedString("Visit Help Center", comment: "Help center link label")))
                .accessibilityHint(Text(NSLocalizedString("Opens the Furfolio Help Center in your browser", comment: "Help center link hint")))
                .accessibilityIdentifier("helpCenterLink")
            if viewModel.queuedCount > 0 {
                HStack {
                    Image(systemName: "tray.full.fill")
                        .foregroundColor(AppColors.warning ?? .orange)
                        .accessibilityHidden(true)
                    Text(LocalizedStringKey("Queued feedback:"))
                    Text("\(viewModel.queuedCount)")
                        .fontWeight(.bold)
                        .accessibilityIdentifier("queuedFeedbackCount")
                }
                .font(AppFonts.footnote ?? .footnote)
                .foregroundStyle(AppColors.warning ?? .orange)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text(NSLocalizedString("Queued feedback", comment: "Queued feedback label")))
                .accessibilityHint(Text(NSLocalizedString("Number of feedback messages queued to send", comment: "Queued feedback hint")))
                .accessibilityIdentifier("queuedFeedbackSection")
            }
        }
        .padding(.top, AppSpacing.xLarge ?? 28)
        .padding(.bottom, AppSpacing.large ?? 16)
    }
}

// MARK: - Attachment Picker (PHPicker)

import PhotosUI

struct AttachmentPicker: UIViewControllerRepresentable {
    @Binding var attachment: FeedbackAttachment?

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .any(of: [.images, .livePhotos])
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: AttachmentPicker
        init(_ parent: AttachmentPicker) { self.parent = parent }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let itemProvider = results.first?.itemProvider else { return }
            if itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                itemProvider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                    guard let data = data else { return }
                    let filename = itemProvider.suggestedName ?? "Image.jpg"
                    let attachment = FeedbackAttachment(filename: filename, fileType: "jpg", data: data)
                    DispatchQueue.main.async {
                        self.parent.attachment = attachment
                    }
                }
            }
        }
    }
}

// MARK: - Demo Defaults & Previews

final class DefaultFeedbackService: FeedbackSubmitting {
    func submitFeedback(_ submission: FeedbackSubmission) async throws -> Bool {
        // Simulate async success/fail randomly
        try await Task.sleep(nanoseconds: 1_000_000_000)
        return Bool.random()
    }
}

final class DefaultAnalyticsLogger: AnalyticsLogging {
    func logEvent(_ name: String, parameters: [String: Any]?) {
        print("Analytics event: \(name), parameters: \(parameters ?? [:])")
    }
}

final class DefaultErrorLogger: ErrorLogging {
    func logError(_ error: Error, context: String) {
        print("Logged error: \(error.localizedDescription) in \(context)")
    }
}

extension FeedbackAndSupportViewModel {
    static var previewInstance: FeedbackAndSupportViewModel {
        .init(
            feedbackService: DefaultFeedbackService(),
            analytics: DefaultAnalyticsLogger(),
            errorLogger: DefaultErrorLogger(),
            offlineStore: .shared
        )
    }
}

#if DEBUG
struct FeedbackAndSupportView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationStack {
                FeedbackAndSupportView()
            }
            .preferredColorScheme(.light)
            .previewDisplayName("Light Mode")

            NavigationStack {
                FeedbackAndSupportView()
            }
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")

            NavigationStack {
                FeedbackAndSupportView(viewModel: .previewInstance)
            }
            .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
            .previewDisplayName("Accessibility Large Text")

            NavigationStack {
                FeedbackAndSupportView(viewModel: .previewInstance)
            }
            .onAppear {
                Task {
                    await FeedbackAndSupportViewModel.previewInstance.submitFeedback()
                }
            }
            .previewDisplayName("Async Submission Preview")
        }
    }
}
#endif

// MARK: - Unit Test Stubs

#if DEBUG
import XCTest

final class FeedbackAndSupportViewModelTests: XCTestCase {
    func testAsyncSubmissionSuccess() async {
        let service = MockFeedbackService(result: true)
        let analytics = DefaultAnalyticsLogger()
        let errorLogger = DefaultErrorLogger()
        let viewModel = FeedbackAndSupportViewModel(feedbackService: service, analytics: analytics, errorLogger: errorLogger)
        viewModel.feedback = "Test Feedback"
        await viewModel.submitFeedback()
        XCTAssertTrue(viewModel.showSuccessAlert)
        XCTAssertFalse(viewModel.showErrorAlert)
    }

    func testAsyncSubmissionFailure() async {
        let service = MockFeedbackService(result: false)
        let analytics = DefaultAnalyticsLogger()
        let errorLogger = DefaultErrorLogger()
        let viewModel = FeedbackAndSupportViewModel(feedbackService: service, analytics: analytics, errorLogger: errorLogger)
        viewModel.feedback = "Test Feedback"
        await viewModel.submitFeedback()
        XCTAssertFalse(viewModel.showSuccessAlert)
        XCTAssertTrue(viewModel.showErrorAlert)
    }

    func testRetryQueuedFeedbackIfNeeded() async {
        let service = MockFeedbackService(result: true)
        let analytics = DefaultAnalyticsLogger()
        let errorLogger = DefaultErrorLogger()
        let offlineStore = OfflineFeedbackQueue()
        let submission = FeedbackSubmission(message: "Offline", category: .bug, attachment: nil)
        offlineStore.enqueue(submission)
        let viewModel = FeedbackAndSupportViewModel(feedbackService: service, analytics: analytics, errorLogger: errorLogger, offlineStore: offlineStore)
        await viewModel.retryQueuedFeedbackIfNeeded()
        XCTAssertEqual(viewModel.queuedCount, 0)
    }
}

final class MockFeedbackService: FeedbackSubmitting {
    let result: Bool
    init(result: Bool) { self.result = result }
    func submitFeedback(_ submission: FeedbackSubmission) async throws -> Bool {
        return result
    }
}
#endif

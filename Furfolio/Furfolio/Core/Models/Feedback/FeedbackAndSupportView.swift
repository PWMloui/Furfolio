// FeedbackAndSupportView.swift

import SwiftUI
import Combine
import UniformTypeIdentifiers

// MARK: - Protocols

protocol FeedbackSubmitting {
    func submitFeedback(_ submission: FeedbackSubmission, completion: @escaping (Bool) -> Void)
}

protocol AnalyticsLogging {
    func logEvent(_ name: String, parameters: [String: Any]?)
}

protocol ErrorLogging {
    func logError(_ error: Error, context: String)
}

// MARK: - ViewModel

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

    func submitFeedback() {
        let trimmed = feedback.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSubmitting = true

        let submission = FeedbackSubmission(
            message: trimmed,
            category: category,
            attachment: attachment
        )

        feedbackService.submitFeedback(submission) { [weak self] success in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isSubmitting = false
                if success {
                    self.analytics.logEvent("feedback_submitted", parameters: submission.analyticsPayload)
                    self.feedback = ""
                    self.attachment = nil
                    self.showSuccessAlert = true
                    self.category = .general
                    // Haptic feedback for success
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                } else {
                    self.offlineStore.enqueue(submission)
                    self.queuedCount = self.offlineStore.count
                    self.analytics.logEvent("feedback_queued_offline", parameters: submission.analyticsPayload)
                    self.showErrorAlert = true
                    // Haptic feedback for error
                    #if os(iOS)
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    #endif
                }
            }
        }
    }

    func retryQueuedFeedbackIfNeeded() {
        guard offlineStore.count > 0 else { return }
        let toRetry = offlineStore.dequeueAll()
        for submission in toRetry {
            feedbackService.submitFeedback(submission) { [weak self] success in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if success {
                        self.analytics.logEvent("feedback_submitted_from_queue", parameters: submission.analyticsPayload)
                    } else {
                        self.offlineStore.enqueue(submission) // Re-queue if failed again
                    }
                    self.queuedCount = self.offlineStore.count
                }
            }
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
}

// MARK: - Feedback Submission Model

struct FeedbackSubmission: Identifiable, Codable {
    let id: UUID = UUID()
    let message: String
    let category: FeedbackCategory
    let attachment: FeedbackAttachment?

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
            VStack(spacing: AppSpacing.xLarge ?? 24) {
                headerSection
                descriptionText
                categoryPicker
                feedbackForm
                attachmentSection
                submitButton
                helpAndQueueSection
            }
            .padding(AppSpacing.medium ?? 16)
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
    }

    // MARK: - UI Sections

    private var headerSection: some View {
        Image(systemName: "bubble.left.and.bubble.right.fill")
            .resizable()
            .scaledToFit()
            .frame(width: AppSpacing.xxxLarge ?? 64, height: AppSpacing.xxxLarge ?? 64)
            .foregroundStyle(AppColors.accent ?? Color.accentColor)
            .padding(.top, AppSpacing.large ?? 20)
            .accessibilityLabel(LocalizedStringKey("Feedback and Support Icon"))
            .accessibilityHint(LocalizedStringKey("Decorative header image representing feedback and support"))
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
        .padding(.horizontal, AppSpacing.medium ?? 16)
        .accessibilityLabel(LocalizedStringKey("Feedback category"))
        .accessibilityHint(LocalizedStringKey("Select the type of feedback"))
    }

    private var feedbackForm: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small ?? 8) {
            Text(LocalizedStringKey("Your Feedback"))
                .font(AppFonts.headline ?? .headline)
            ZStack(alignment: .topLeading) {
                if viewModel.feedback.isEmpty {
                    Text(LocalizedStringKey("Type your message here…"))
                        .foregroundStyle(AppColors.secondaryText ?? .secondary)
                        .padding(.top, AppSpacing.small ?? 8)
                        .padding(.horizontal, AppSpacing.xxSmall ?? 4)
                        .accessibilityHidden(true)
                }
                TextEditor(text: $viewModel.feedback)
                    .focused($isTextEditorFocused)
                    .frame(height: 140)
                    .padding(AppSpacing.xxSmall ?? 4)
                    .background(AppColors.secondaryBackground ?? Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: AppSpacing.large ?? 10))
                    .accessibilityLabel(LocalizedStringKey("Feedback text"))
                    .accessibilityHint(LocalizedStringKey("Enter your feedback or support request here"))
            }
        }
        .padding(.horizontal, AppSpacing.medium ?? 16)
    }

    private var attachmentSection: some View {
        HStack(spacing: AppSpacing.small ?? 8) {
            Button {
                showAttachmentPicker = true
            } label: {
                Label(
                    viewModel.attachment == nil
                        ? NSLocalizedString("Add Attachment", comment: "")
                        : NSLocalizedString("Replace Attachment", comment: ""),
                    systemImage: "paperclip")
            }
            .accessibilityLabel(LocalizedStringKey("Add or replace attachment"))
            .accessibilityHint(LocalizedStringKey("Attach a file or screenshot"))
            if let attachment = viewModel.attachment {
                Text(attachment.filename)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .font(AppFonts.footnote ?? .footnote)
                Button(action: { viewModel.removeAttachment() }) {
                    Image(systemName: "xmark.circle")
                        .accessibilityLabel(LocalizedStringKey("Remove attachment"))
                }
            }
            Spacer()
        }
        .padding(.horizontal, AppSpacing.medium ?? 16)
    }

    private var submitButton: some View {
        Button(action: {
            viewModel.submitFeedback()
            isTextEditorFocused = false
        }) {
            HStack {
                if viewModel.isSubmitting {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(1.1)
                        .tint(AppColors.accent ?? .accentColor)
                        .padding(.trailing, 6)
                }
                Text(LocalizedStringKey("Send Feedback"))
                    .font(AppFonts.button ?? .headline)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(AppSpacing.medium ?? 16)
            .background(
                (viewModel.isSubmitting || viewModel.feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                ? (AppColors.accent ?? .accentColor).opacity(0.09)
                : (AppColors.accent ?? .accentColor).opacity(0.19)
            )
            .foregroundStyle(AppColors.accent ?? .accentColor)
            .clipShape(RoundedRectangle(cornerRadius: AppSpacing.large ?? 10))
            .animation(.easeInOut(duration: 0.15), value: viewModel.isSubmitting)
        }
        .disabled(viewModel.feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSubmitting)
        .padding(.horizontal, AppSpacing.medium ?? 16)
        .accessibilityLabel(LocalizedStringKey("Send Feedback"))
        .accessibilityHint(LocalizedStringKey("Send your feedback to the Furfolio team"))
    }

    private var helpAndQueueSection: some View {
        VStack(spacing: AppSpacing.xSmall ?? 6) {
            Link(LocalizedStringKey("Visit Help Center"), destination: URL(string: "https://furfolio.app/help")!)
                .font(AppFonts.footnote ?? .footnote)
            if viewModel.queuedCount > 0 {
                HStack {
                    Image(systemName: "tray.full.fill")
                        .foregroundColor(AppColors.warning ?? .orange)
                    Text(LocalizedStringKey("Queued feedback:"))
                    Text("\(viewModel.queuedCount)")
                        .fontWeight(.bold)
                }
                .font(AppFonts.footnote ?? .footnote)
                .foregroundStyle(AppColors.warning ?? .orange)
            }
        }
        .padding(.top, AppSpacing.xLarge ?? 24)
        .padding(.bottom, AppSpacing.large ?? 12)
    }
}

// MARK: - Attachment Picker (Demo)

struct AttachmentPicker: UIViewControllerRepresentable {
    @Binding var attachment: FeedbackAttachment?

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.image, UTType.pdf, UTType.text])
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: AttachmentPicker
        init(_ parent: AttachmentPicker) { self.parent = parent }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first, let data = try? Data(contentsOf: url) else { return }
            let attachment = FeedbackAttachment(filename: url.lastPathComponent, fileType: url.pathExtension, data: data)
            parent.attachment = attachment
        }
    }
}

// MARK: - Demo Defaults & Previews

final class DefaultFeedbackService: FeedbackSubmitting {
    func submitFeedback(_ submission: FeedbackSubmission, completion: @escaping (Bool) -> Void) {
        // Simulate success/fail randomly
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
            completion(Bool.random())
        }
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
        }
    }
}
#endif

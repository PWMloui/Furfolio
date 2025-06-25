// FeedbackAndSupportView.swift

import SwiftUI
import Combine

// MARK: - TODOs
// - Replace DefaultFeedbackService with real API
// - Implement analytics logging and error reporting
// - Ensure AppColors, AppFonts, and AppSpacing tokens are fully defined

protocol FeedbackSubmitting {
    func submitFeedback(_ message: String, completion: @escaping (Bool) -> Void)
}

final class FeedbackAndSupportViewModel: ObservableObject {
    @Published var feedback: String = ""
    @Published var isSubmitting: Bool = false
    @Published var showSuccessAlert: Bool = false
    @Published var showErrorAlert: Bool = false

    private let feedbackService: FeedbackSubmitting

    init(feedbackService: FeedbackSubmitting) {
        self.feedbackService = feedbackService
    }

    func submitFeedback() {
        let trimmed = feedback.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSubmitting = true
        feedbackService.submitFeedback(trimmed) { [weak self] success in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isSubmitting = false
                if success {
                    self.feedback = ""
                    self.showSuccessAlert = true
                    // Haptic feedback for success
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                } else {
                    self.showErrorAlert = true
                    // Haptic feedback for error
                    #if os(iOS)
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    #endif
                }
            }
        }
    }
}

// MARK: - Default Service Stub (Replace with real implementation)

final class DefaultFeedbackService: FeedbackSubmitting {
    func submitFeedback(_ message: String, completion: @escaping (Bool) -> Void) {
        // TODO: Replace with actual networking/API logic, analytics logging
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.1) {
            completion(true)
        }
    }
}

// MARK: - View

struct FeedbackAndSupportView: View {
    @StateObject private var viewModel: FeedbackAndSupportViewModel

    // Allow injection for previews/tests
    init(viewModel: FeedbackAndSupportViewModel = FeedbackAndSupportViewModel(feedbackService: DefaultFeedbackService())) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    @FocusState private var isTextEditorFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xLarge ?? 24) {
                headerSection
                descriptionText
                feedbackForm
                submitButton
                contactInfo
            }
            .padding(AppSpacing.medium ?? 16)
            .onTapGesture {
                isTextEditorFocused = false // Tap outside to dismiss keyboard
            }
        }
        .background(AppColors.background ?? Color(UIColor.systemBackground))
        .navigationTitle(LocalizedStringKey("Feedback & Support"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(LocalizedStringKey("Thank you!"), isPresented: $viewModel.showSuccessAlert) {
            Button(LocalizedStringKey("OK"), role: .cancel) { }
        } message: {
            Text(LocalizedStringKey("Your feedback has been sent. We appreciate your input!"))
        }
        .alert(LocalizedStringKey("Error"), isPresented: $viewModel.showErrorAlert) {
            Button(LocalizedStringKey("OK"), role: .cancel) { }
        } message: {
            Text(LocalizedStringKey("There was an error submitting your feedback. Please try again later."))
        }
        .animation(.easeInOut, value: viewModel.isSubmitting)
    }

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

    private var contactInfo: some View {
        VStack(spacing: AppSpacing.xSmall ?? 6) {
            Text(LocalizedStringKey("Contact support@furfolio.app"))
                .font(AppFonts.footnote ?? .footnote)
                .foregroundStyle(AppColors.secondaryText ?? .secondary)
            Link(LocalizedStringKey("Visit Help Center"), destination: URL(string: "https://furfolio.app/help")!)
                .font(AppFonts.footnote ?? .footnote)
        }
        .padding(.top, AppSpacing.xLarge ?? 24)
        .padding(.bottom, AppSpacing.large ?? 12)
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
                FeedbackAndSupportView(viewModel: FeedbackAndSupportViewModel(feedbackService: DefaultFeedbackService()))
            }
            .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
            .previewDisplayName("Accessibility Large Text")
        }
    }
}
#endif

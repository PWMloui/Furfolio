
//FeedbackAndSupportView.swift


import SwiftUI
import Combine

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
                } else {
                    self.showErrorAlert = true
                }
            }
        }
    }
}

// MARK: - Default Service (To be replaced with real implementation)

final class DefaultFeedbackService: FeedbackSubmitting {
    func submitFeedback(_ message: String, completion: @escaping (Bool) -> Void) {
        // TODO: Replace with actual networking/API logic and analytics logging
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.1) {
            completion(true)
        }
    }
}

// MARK: - View

struct FeedbackAndSupportView: View {
    @StateObject private var viewModel: FeedbackAndSupportViewModel

    init(viewModel: FeedbackAndSupportViewModel = FeedbackAndSupportViewModel(feedbackService: DefaultFeedbackService())) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xLarge) { // 24 replaced with AppSpacing.xLarge
                headerSection
                descriptionText
                feedbackForm
                submitButton
                contactInfo
            }
            .padding(AppSpacing.medium) // TODO: Replace with AppSpacing token if not defined
        }
        .background(AppColors.background) // Used design token
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
    }

    private var headerSection: some View {
        Image(systemName: "bubble.left.and.bubble.right.fill")
            .resizable()
            .scaledToFit()
            .frame(width: AppSpacing.xxxLarge, height: AppSpacing.xxxLarge) // 64 replaced with AppSpacing.xxxLarge
            .foregroundStyle(AppColors.accent)
            .padding(.top, AppSpacing.large) // TODO: Replace .large with correct token if not defined
            .accessibilityLabel(LocalizedStringKey("Feedback and Support Icon"))
            .accessibilityHint(LocalizedStringKey("Decorative header image representing feedback and support"))
    }

    private var descriptionText: some View {
        VStack(spacing: AppSpacing.small) { // 8 replaced with AppSpacing.small
            Text(LocalizedStringKey("Feedback & Support"))
                .font(AppFonts.title.bold()) // Use design token
                .accessibilityAddTraits(.isHeader)

            Text(LocalizedStringKey("Share your thoughts, suggest features, or report an issue. Our team appreciates your feedback and will get back to you as soon as possible."))
                .multilineTextAlignment(.center)
                .font(AppFonts.body) // Use design token
                .foregroundStyle(AppColors.secondaryText) // TODO: Replace with correct secondaryText token if available
        }
        .padding(.horizontal, AppSpacing.medium) // TODO: Replace with token if not defined
    }

    private var feedbackForm: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) { // 8 replaced with AppSpacing.small
            Text(LocalizedStringKey("Your Feedback"))
                .font(AppFonts.headline) // Use design token

            ZStack(alignment: .topLeading) {
                if viewModel.feedback.isEmpty {
                    Text(LocalizedStringKey("Type your message here…"))
                        .foregroundStyle(AppColors.secondaryText) // TODO: Replace with correct token if available
                        .padding(.top, AppSpacing.small) // 8
                        .padding(.horizontal, AppSpacing.xxSmall) // 4
                }
                TextEditor(text: $viewModel.feedback)
                    .frame(height: 140) // TODO: Consider using a height token if available
                    .padding(AppSpacing.xxSmall) // 4
                    .background(AppColors.secondaryBackground) // Used design token
                    .clipShape(RoundedRectangle(cornerRadius: 10)) // TODO: Use token for radius if available
                    .accessibilityLabel(LocalizedStringKey("Feedback text"))
                    .accessibilityHint(LocalizedStringKey("Enter your feedback or support request here"))
            }
        }
        .padding(.horizontal, AppSpacing.medium) // TODO: Replace with token if not defined
    }

    private var submitButton: some View {
        Button(action: viewModel.submitFeedback) {
            HStack {
                if viewModel.isSubmitting {
                    ProgressView().progressViewStyle(.circular)
                }
                Text(LocalizedStringKey("Send Feedback"))
                    .font(AppFonts.button) // TODO: Use AppFonts.button or appropriate token
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(AppSpacing.medium) // TODO: Replace with token if not defined
            .background(AppColors.accent.opacity(0.2)) // Used design token
            .foregroundStyle(AppColors.accent)
            .clipShape(RoundedRectangle(cornerRadius: 10)) // TODO: Use token for radius if available
        }
        .disabled(viewModel.feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSubmitting)
        .padding(.horizontal, AppSpacing.medium) // TODO: Replace with token if not defined
        .accessibilityLabel(LocalizedStringKey("Send Feedback"))
        .accessibilityHint(LocalizedStringKey("Send your feedback to the Furfolio team"))
    }

    private var contactInfo: some View {
        VStack(spacing: AppSpacing.xSmall) { // 6 replaced with AppSpacing.xSmall
            Text(LocalizedStringKey("Contact support@furfolio.app"))
                .font(AppFonts.footnote) // Use design token
                .foregroundStyle(AppColors.secondaryText) // TODO: Replace with correct token if available
            Link(LocalizedStringKey("Visit Help Center"), destination: URL(string: "https://furfolio.app/help")!)
                .font(AppFonts.footnote) // Use design token
        }
        .padding(.top, AppSpacing.xLarge) // 24
        .padding(.bottom, AppSpacing.large) // 12
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
                FeedbackAndSupportView()
            }
            .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
            .previewDisplayName("Accessibility Large Text")
        }
    }
}
#endif

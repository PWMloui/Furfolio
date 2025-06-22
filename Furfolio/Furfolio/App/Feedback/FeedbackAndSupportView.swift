import SwiftUI

final class FeedbackAndSupportViewModel: ObservableObject {
    @Published var feedback: String = ""
    @Published var isSubmitting: Bool = false
    @Published var showSuccessAlert: Bool = false
    @Published var showErrorAlert: Bool = false

    func submitFeedback() {
        guard !feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isSubmitting = true

        // Replace with actual feedback API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            self.isSubmitting = false
            let submissionSucceeded = true // Change as needed
            if submissionSucceeded {
                self.feedback = ""
                self.showSuccessAlert = true
            } else {
                self.showErrorAlert = true
            }
        }
    }
}

struct FeedbackAndSupportView: View {
    @StateObject private var viewModel = FeedbackAndSupportViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                descriptionText
                feedbackForm
                submitButton
                contactInfo
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Feedback & Support")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Thank you!", isPresented: $viewModel.showSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your feedback has been sent. We appreciate your input!")
        }
        .alert("Error", isPresented: $viewModel.showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("There was an error submitting your feedback. Please try again later.")
        }
    }

    private var headerSection: some View {
        Image(systemName: "bubble.left.and.bubble.right.fill")
            .resizable()
            .scaledToFit()
            .frame(width: 64, height: 64)
            .foregroundStyle(.accent)
            .padding(.top)
    }

    private var descriptionText: some View {
        VStack(spacing: 8) {
            Text("Feedback & Support")
                .font(.title.bold())
                .accessibilityAddTraits(.isHeader)

            Text("Share your thoughts, suggest features, or report an issue. Our team appreciates your feedback and will get back to you as soon as possible.")
                .multilineTextAlignment(.center)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    private var feedbackForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Feedback")
                .font(.headline)

            ZStack(alignment: .topLeading) {
                if viewModel.feedback.isEmpty {
                    Text("Type your message here…")
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                        .padding(.horizontal, 4)
                }
                TextEditor(text: $viewModel.feedback)
                    .frame(height: 140)
                    .padding(4)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .accessibilityLabel("Feedback text")
            }
        }
        .padding(.horizontal)
    }

    private var submitButton: some View {
        Button(action: viewModel.submitFeedback) {
            HStack {
                if viewModel.isSubmitting {
                    ProgressView().progressViewStyle(.circular)
                }
                Text("Send Feedback")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor.opacity(0.2))
            .foregroundStyle(.accent)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(viewModel.feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSubmitting)
        .padding(.horizontal)
    }

    private var contactInfo: some View {
        VStack(spacing: 6) {
            Text("Contact support@furfolio.app")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Link("Visit Help Center", destination: URL(string: "https://furfolio.app/help")!)
                .font(.footnote)
        }
        .padding(.top, 24)
        .padding(.bottom, 12)
    }
}

#Preview {
    NavigationStack {
        FeedbackAndSupportView()
    }
}

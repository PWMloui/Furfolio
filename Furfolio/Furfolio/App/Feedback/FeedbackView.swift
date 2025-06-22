import SwiftUI
import PhotosUI

/// A user feedback form for Furfolio (for feature requests, bug reports, ratings, etc.)
struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss

    // Feedback state
    @State private var rating: Int = 5
    @State private var feedbackText: String = ""
    @State private var screenshotImage: UIImage? = nil
    @State private var showPhotoPicker = false
    @State private var showConfirmationAlert = false

    var onSubmit: ((UserFeedback) -> Void)? = nil

    var body: some View {
        NavigationView {
            Form {
                experienceSection
                commentsSection
                screenshotSection
            }
            .navigationTitle("Send Feedback")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit", action: submitFeedback)
                        .disabled(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: .constant(nil), matching: .images) { item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        screenshotImage = image
                    }
                }
            }
            .alert("Thank You!", isPresented: $showConfirmationAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your feedback helps us improve Furfolio.")
            }
        }
    }

    private var experienceSection: some View {
        Section(header: Text("Your Experience")) {
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: star <= rating ? "star.fill" : "star")
                        .resizable()
                        .frame(width: 28, height: 28)
                        .foregroundColor(star <= rating ? .yellow : .gray.opacity(0.4))
                        .onTapGesture { rating = star }
                        .accessibilityLabel("\(star) star\(star > 1 ? "s" : "")")
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var commentsSection: some View {
        Section(header: Text("Comments / Suggestions")) {
            TextEditor(text: $feedbackText)
                .frame(minHeight: 100)
                .padding(.vertical, 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2))
                )
                .accessibilityLabel("Feedback text")
        }
    }

    private var screenshotSection: some View {
        Section(header: Text("Add a Screenshot (Optional)")) {
            if let image = screenshotImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 100)
                    .cornerRadius(8)
                    .shadow(radius: 2)
                    .onTapGesture { showPhotoPicker = true }
            } else {
                Button {
                    showPhotoPicker = true
                } label: {
                    Label("Attach Screenshot", systemImage: "photo")
                }
            }
        }
    }

    private func submitFeedback() {
        let feedback = UserFeedback(
            date: Date(),
            rating: rating,
            comment: feedbackText.trimmingCharacters(in: .whitespacesAndNewlines),
            screenshot: screenshotImage
        )
        onSubmit?(feedback)
        HapticManager.success()
        showConfirmationAlert = true
    }
}

// MARK: - User Feedback Data Model

struct UserFeedback {
    let date: Date
    let rating: Int
    let comment: String
    let screenshot: UIImage?
}

// MARK: - Preview

#if DEBUG
struct FeedbackView_Previews: PreviewProvider {
    static var previews: some View {
        FeedbackView { feedback in
            print("Received feedback: \(feedback)")
        }
    }
}
#endif

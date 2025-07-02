//
//  ClientFeedbackView.swift
//  Furfolio
//
//  Created by mac on 6/30/25.
//

import SwiftUI
import UniformTypeIdentifiers
import SwiftData

/// A view presented to clients for submitting feedback directly.
struct ClientFeedbackView: View {
    @State private var message: String = ""
    @State private var contactEmail: String = ""
    @State private var selectedCategory: FeedbackCategory = .general
    @State private var attachments: [FeedbackAttachment] = []
    @State private var showAttachmentPicker = false
    @State private var showConfirmation = false

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private var isEmailValid: Bool {
        contactEmail.isEmpty || (contactEmail.contains("@") && contactEmail.contains("."))
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Category")) {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(FeedbackCategory.allCases, id: \.self) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                Section(header: Text("Your Feedback")) {
                    TextEditor(text: $message)
                        .frame(minHeight: 150)
                        .disableAutocorrection(true)
                }

                Section(header: Text("Contact Email (optional)")) {
                    TextField("Email", text: $contactEmail)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }

                Section(header: Text("Attachment")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(attachments, id: \.filename) { attachment in
                                if let data = attachment.data,
                                   let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .cornerRadius(6)
                                }
                            }
                            Button(action: { showAttachmentPicker = true }) {
                                VStack {
                                    Image(systemName: "paperclip")
                                        .font(.title2)
                                    Text("Add")
                                        .font(.caption)
                                }
                                .frame(width: 80, height: 80)
                                .background(RoundedRectangle(cornerRadius: 6).stroke())
                            }
                        }
                    }
                }

                Section {
                    Button("Submit Feedback") {
                        submitFeedback()
                    }
                    .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !isEmailValid)
                }
            }
            .navigationTitle("Feedback")
            .navigationBarItems(leading: Button("Cancel") { dismiss() })
            .sheet(isPresented: $showAttachmentPicker) {
                DocumentPicker(supportedTypes: [.image, .pdf]) { urls in
                    guard let url = urls.first, let data = try? Data(contentsOf: url) else { return }
                    let attachment = FeedbackAttachment(filename: url.lastPathComponent, data: data)
                    attachments.append(attachment)
                }
            }
            .alert("Thank You", isPresented: $showConfirmation) {
                Button("OK") { dismiss() }
            } message: {
                Text("Your feedback has been submitted.")
            }
        }
    }

    private func submitFeedback() {
        Task {
            await FurfolioAnalyticsLogger.shared.logEvent("client_feedback_submitted", parameters: [
                "category": selectedCategory.displayName,
                "message_length": message.count,
                "contact_provided": !contactEmail.isEmpty
            ])
        }
        let submission = FeedbackSubmission(
            message: message,
            contactEmail: contactEmail,
            category: selectedCategory,
            attachment: attachments.first
        )
        modelContext.insert(submission)
        showConfirmation = true
    }
}

struct ClientFeedbackView_Previews: PreviewProvider {
    static var previews: some View {
        ClientFeedbackView()
    }
}

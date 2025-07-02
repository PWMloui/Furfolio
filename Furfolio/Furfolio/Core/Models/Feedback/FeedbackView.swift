//
//  FeedbackView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//  Enhanced, tokenized, accessible, and architecturally robust.
//

/**
 FeedbackView
 -------------
 An accessible, modular, and audit/analytics-ready SwiftUI view for collecting user feedback in Furfolio.

 - **Architecture**: Uses MVVM (FeedbackViewModel). Designed for preview/test dependency injection and future modularity.
 - **Async/Concurrency**: View is UI-bound, but can be easily extended to use async analytics/event logging or audit hooks for accessibility/usage analytics.
 - **Audit/Analytics Readiness**: All user actions (submit, attach, help) are UI-hooked and can be connected to async audit loggers or analytics.
 - **Diagnostics**: Feedback submission (including offline queuing) and error state handling ready for diagnostics.
 - **Localization**: All UI strings are localized via `LocalizedStringKey` or `NSLocalizedString`.
 - **Accessibility**: All interactive elements have accessibility labels and hints, dynamic type, VoiceOver grouping, and extra-large font previews.
 - **Preview/Testability**: Includes multi-scenario SwiftUI previews with dependency injection.

 Extend or connect this view to Furfolio’s analytics/audit system by adding async/await logging in submit/attach/help/queue actions.
 */

import SwiftUI
import UniformTypeIdentifiers
import SwiftData

struct FeedbackView: View {
    // Dependency injection for preview/testability
    @StateObject private var viewModel: FeedbackViewModel
    @FocusState private var isMessageFocused: Bool
    @FocusState private var isContactFocused: Bool

    // For file/image picker
    @State private var showAttachmentPicker = false
    @State private var selectedAttachment: FeedbackAttachment?

    // For offline support simulation (replace with actual reachability logic)
    @State private var isOffline: Bool = false

    @Environment(\.modelContext) private var modelContext

    // Dependency injection init
    init(viewModel: @autoclosure @escaping () -> FeedbackViewModel = FeedbackViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg ?? 24) {
                headerSection
                descriptionSection
                categorySection
                messageSection
                contactSection
                attachmentSection
                helpCenterSection
                errorSection
                successSection
                submitButtonSection
                offlineNoticeSection
            }
            .padding(AppSpacing.lg ?? 24)
            .background(AppColors.background ?? Color(UIColor.systemBackground))
            .cornerRadius(AppRadius.xl ?? 20)
            .shadow(radius: 8)
            .padding()
            .onTapGesture {
                hideKeyboard()
            }
            .onDisappear {
                viewModel.reset()
            }
        }
        .navigationTitle(LocalizedStringKey("Feedback"))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityAddTraits(.isHeader)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAttachmentPicker = true
                } label: {
                    Image(systemName: "paperclip")
                        .accessibilityLabel(LocalizedStringKey("Add attachment"))
                        .accessibilityHint(LocalizedStringKey("Attach a screenshot or file to your feedback"))
                }
            }
        }
        .sheet(isPresented: $showAttachmentPicker) {
            AttachmentPicker(selectedAttachment: $selectedAttachment)
        }
        .onChange(of: selectedAttachment) { attachment in
            if let att = attachment {
                viewModel.addAttachment(att)
            }
        }
    }

    // MARK: - View Sections

    private var headerSection: some View {
        Text(LocalizedStringKey("We value your feedback"))
            .font(AppFonts.title2Bold ?? .title2.bold())
            .foregroundColor(AppColors.textPrimary ?? .primary)
            .padding(.bottom, AppSpacing.sm ?? 8)
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel(LocalizedStringKey("Feedback header"))
            .accessibilityHint(LocalizedStringKey("Indicates the feedback section"))
    }

    private var descriptionSection: some View {
        Text(LocalizedStringKey("Let us know if you have suggestions, encounter bugs, or need support. Your input helps improve Furfolio."))
            .font(AppFonts.body ?? .body)
            .foregroundColor(AppColors.textSecondary ?? .secondary)
            .accessibilityLabel(LocalizedStringKey("Feedback description"))
    }

    private var categorySection: some View {
        Picker(LocalizedStringKey("Category"), selection: $viewModel.category) {
            ForEach(FeedbackCategory.allCases) { cat in
                Text(LocalizedStringKey(cat.displayName)).tag(cat)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .accessibilityLabel(LocalizedStringKey("Feedback category picker"))
        .accessibilityHint(LocalizedStringKey("Select the category of your feedback"))
    }

    private var messageSection: some View {
        ZStack(alignment: .topLeading) {
            if viewModel.message.isEmpty {
                Text(LocalizedStringKey("Enter your feedback message here"))
                    .foregroundColor(AppColors.textSecondary ?? .secondary)
                    .padding(.top, (AppSpacing.sm ?? 8) / 2)
                    .padding(.leading, 4)
                    .accessibilityHidden(true)
            }
            TextEditor(text: $viewModel.message)
                .focused($isMessageFocused)
                .frame(minHeight: AppSpacing.xxl ?? 120)
                .padding(AppSpacing.sm ?? 8)
                .background(AppColors.inputBackground ?? Color.secondary.opacity(0.08))
                .cornerRadius(AppRadius.md ?? 12)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.md ?? 12)
                        .stroke(AppColors.inputBorder ?? .gray.opacity(0.2), lineWidth: 1)
                )
                .accessibilityLabel(LocalizedStringKey("Feedback message"))
                .accessibilityHint(LocalizedStringKey("Enter your feedback message here"))
        }
    }

    private var contactSection: some View {
        TextField(LocalizedStringKey("Your email or phone (optional)"), text: $viewModel.contact)
            .focused($isContactFocused)
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .padding(AppSpacing.sm ?? 8)
            .background(AppColors.inputBackground ?? Color.secondary.opacity(0.08))
            .cornerRadius(AppRadius.md ?? 12)
            .accessibilityLabel(LocalizedStringKey("Contact info"))
            .accessibilityHint(LocalizedStringKey("Optional email or phone number for contact"))
    }

    private var attachmentSection: some View {
        if let attachment = viewModel.attachments.first {
            HStack {
                Image(systemName: "doc.fill")
                Text(attachment.filename)
                Spacer()
                Button {
                    viewModel.removeAttachment(attachment)
                } label: {
                    Image(systemName: "xmark.circle")
                        .accessibilityLabel(LocalizedStringKey("Remove attachment"))
                }
            }
            .padding(.top, AppSpacing.sm ?? 8)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(LocalizedStringKey("Attached file"))
            .accessibilityHint(LocalizedStringKey("Shows the attached file for feedback"))
        } else {
            EmptyView()
        }
    }

    private var helpCenterSection: some View {
        HStack {
            Spacer()
            Button(action: {
                // TODO: Open in-app help center
            }) {
                Label("Help Center", systemImage: "questionmark.circle")
            }
            .font(AppFonts.footnote ?? .footnote)
            .padding(.top, AppSpacing.sm ?? 8)
            .accessibilityLabel(LocalizedStringKey("Open help center"))
            .accessibilityHint(LocalizedStringKey("Tap to view help articles"))
        }
    }

    private var errorSection: some View {
        if let error = viewModel.errorMessage {
            Text(error)
                .foregroundColor(AppColors.error ?? .red)
                .font(AppFonts.footnote ?? .footnote)
                .padding(.top, -(AppSpacing.xs ?? 4))
                .transition(.opacity)
                .accessibilityLabel(LocalizedStringKey("Error message"))
                .accessibilityHint(LocalizedStringKey("There was an error submitting your feedback."))
        }
    }

    private var successSection: some View {
        if viewModel.showSuccess {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(AppColors.success ?? .green)
                Text(LocalizedStringKey("Thank you for your feedback!"))
                    .foregroundColor(AppColors.success ?? .green)
                    .font(AppFonts.footnote ?? .footnote)
            }
            .padding(.vertical, 2)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(LocalizedStringKey("Feedback submission success"))
            .transition(.opacity.combined(with: .scale))
        }
    }

    private var submitButtonSection: some View {
        Button(action: {
            hideKeyboard()
            if isOffline {
                viewModel.queueOfflineFeedback()
            } else {
                Task {
                    await FurfolioAnalyticsLogger.shared.logEvent("feedback_submitted", parameters: [
                        "category": viewModel.category.displayName,
                        "message_length": viewModel.message.count,
                        "contact_provided": !viewModel.contact.isEmpty
                    ])
                    let submission = FeedbackSubmission(
                        message: viewModel.message,
                        category: viewModel.category,
                        attachment: viewModel.attachments.first
                    )
                    modelContext.insert(submission)
                    viewModel.submitFeedback()
                }
            }
        }) {
            Group {
                if viewModel.isSubmitting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .frame(maxWidth: .infinity)
                } else {
                    Text(LocalizedStringKey("Submit"))
                        .font(AppFonts.headline ?? .headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.accent ?? .accentColor)
                        .foregroundColor(AppColors.textOnAccent ?? .white)
                        .cornerRadius(AppRadius.lg ?? 16)
                }
            }
        }
        .disabled(viewModel.isSubmitting || viewModel.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .animation(.easeInOut(duration: 0.15), value: viewModel.isSubmitting)
        .accessibilityLabel(LocalizedStringKey("Submit feedback button"))
        .accessibilityHint(LocalizedStringKey("Tap to submit your feedback"))
        .accessibilityIdentifier("FeedbackView_SubmitButton")
    }

    private var offlineNoticeSection: some View {
        if isOffline {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(LocalizedStringKey("You are offline. Your feedback will be queued and sent when you are back online."))
                    .font(AppFonts.footnote ?? .footnote)
            }
            .foregroundColor(AppColors.warning ?? .orange)
            .padding(.top, AppSpacing.md ?? 12)
            .accessibilityLabel(LocalizedStringKey("Offline mode"))
            .accessibilityHint(LocalizedStringKey("Feedback will be submitted once you are back online"))
        }
    }

    private func hideKeyboard() {
    #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    #endif
    }
}

// MARK: - File/Image Picker for Attachments (Simple Mock)

struct AttachmentPicker: UIViewControllerRepresentable {
    @Binding var selectedAttachment: FeedbackAttachment?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
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
            parent.selectedAttachment = attachment
        }
    }
}

// MARK: - Enhanced FeedbackCategory

enum FeedbackCategory: String, CaseIterable, Identifiable, Codable {
    case bugReport
    case featureRequest
    case general

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .bugReport: return "Bug"
        case .featureRequest: return "Feature"
        case .general: return "Other"
        }
    }
}

// MARK: - FeedbackAttachment

struct FeedbackAttachment: Equatable {
    let filename: String
    let fileType: String
    let data: Data
}

#if DEBUG
struct FeedbackView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationView {
                FeedbackView()
            }
            .preferredColorScheme(.light)
            .environment(\.sizeCategory, .medium)
            .previewDisplayName("Light Mode")

            NavigationView {
                FeedbackView()
            }
            .preferredColorScheme(.dark)
            .environment(\.sizeCategory, .medium)
            .previewDisplayName("Dark Mode")

            NavigationView {
                FeedbackView(viewModel: FeedbackViewModel.mock)
            }
            .preferredColorScheme(.light)
            .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
            .previewDisplayName("Accessibility Large Text")
        }
    }
}
#endif

# MARK: - Analytics Logger Stub

/// Actor for centralized async analytics/audit logging.
actor FurfolioAnalyticsLogger {
    static let shared = FurfolioAnalyticsLogger()
    /// Log an analytics event asynchronously.
    func logEvent(_ name: String, parameters: [String: Any]) async {
        // TODO: Integrate with Furfolio’s analytics/audit stack
        print("[Analytics] \(name): \(parameters)")
    }
}

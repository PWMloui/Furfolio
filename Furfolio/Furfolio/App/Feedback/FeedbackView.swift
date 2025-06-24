//
//  FeedbackView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//  Modernized, tokenized, and accessible.
//

import SwiftUI

struct FeedbackView: View {
    @StateObject private var viewModel = FeedbackViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) { // TODO: define AppSpacing.lg = 24
            Text(LocalizedStringKey("We value your feedback"))
                .font(AppFonts.title2Bold)
                .foregroundColor(AppColors.textPrimary)
                .padding(.bottom, AppSpacing.sm) // TODO: define AppSpacing.sm = 8
                .accessibilityLabel(LocalizedStringKey("Feedback header"))
                .accessibilityHint(LocalizedStringKey("Indicates the feedback section"))

            Text(LocalizedStringKey("Let us know if you have suggestions, encounter bugs, or need support. Your input helps improve Furfolio."))
                .font(AppFonts.body)
                .foregroundColor(AppColors.textSecondary)
                .accessibilityLabel(LocalizedStringKey("Feedback description"))

            Picker(LocalizedStringKey("Category"), selection: $viewModel.category) {
                ForEach(FeedbackCategory.allCases) { cat in
                    Text(LocalizedStringKey(cat.rawValue)).tag(cat)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .accessibilityLabel(LocalizedStringKey("Feedback category picker"))
            .accessibilityHint(LocalizedStringKey("Select the category of your feedback"))

            TextEditor(text: $viewModel.message)
                .frame(minHeight: AppSpacing.xxl) // TODO: define AppSpacing.xxl = 120
                .padding(AppSpacing.sm)
                .background(AppColors.inputBackground)
                .cornerRadius(AppRadius.md) // TODO: define AppRadius.md = 12
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .stroke(AppColors.inputBorder, lineWidth: 1)
                )
                .accessibilityLabel(LocalizedStringKey("Feedback message"))
                .accessibilityHint(LocalizedStringKey("Enter your feedback message here"))

            TextField(LocalizedStringKey("Your email or phone (optional)"), text: $viewModel.contact)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding(AppSpacing.sm)
                .background(AppColors.inputBackground)
                .cornerRadius(AppRadius.md)
                .accessibilityLabel(LocalizedStringKey("Contact info"))
                .accessibilityHint(LocalizedStringKey("Optional email or phone number for contact"))

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(AppColors.error)
                    .font(AppFonts.footnote)
                    .padding(.top, -AppSpacing.xs) // TODO: define AppSpacing.xs = 10
                    .accessibilityLabel(LocalizedStringKey("Error message"))
            }

            if viewModel.showSuccess {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(AppColors.success)
                    Text(LocalizedStringKey("Thank you for your feedback!"))
                        .foregroundColor(AppColors.success)
                        .font(AppFonts.footnote)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(LocalizedStringKey("Feedback submission success"))
            }

            Button(action: { viewModel.submitFeedback() }) {
                if viewModel.isSubmitting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .frame(maxWidth: .infinity)
                } else {
                    Text(LocalizedStringKey("Submit"))
                        .font(AppFonts.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppColors.accent)
                        .foregroundColor(AppColors.textOnAccent) // TODO: define AppColors.textOnAccent if needed
                        .cornerRadius(AppRadius.lg) // TODO: define AppRadius.lg = 16
                }
            }
            .disabled(viewModel.isSubmitting)
            .accessibilityLabel(LocalizedStringKey("Submit feedback button"))
            .accessibilityHint(LocalizedStringKey("Tap to submit your feedback"))
        }
        .padding()
        .background(AppColors.background)
        .cornerRadius(AppRadius.xl) // TODO: define AppRadius.xl = 20
        .shadow(radius: 8) // TODO: consider tokenizing shadow radius
        .padding()
        .navigationTitle(LocalizedStringKey("Feedback"))
        .accessibilityAddTraits(.isHeader)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { viewModel.showSuccess = false }
    }
}

struct FeedbackView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            FeedbackView()
                .preferredColorScheme(.light)
                .environment(\.sizeCategory, .medium)
                .previewDisplayName("Light Mode")

            FeedbackView()
                .preferredColorScheme(.dark)
                .environment(\.sizeCategory, .medium)
                .previewDisplayName("Dark Mode")

            FeedbackView()
                .preferredColorScheme(.light)
                .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
                .previewDisplayName("Accessibility Large Text")
        }
    }
}

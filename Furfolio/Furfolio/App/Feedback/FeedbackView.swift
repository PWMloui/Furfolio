//
//  FeedbackView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//  Enhanced, tokenized, accessible, and architecturally robust.
//

import SwiftUI

struct FeedbackView: View {
    @StateObject private var viewModel = FeedbackViewModel()
    @FocusState private var isMessageFocused: Bool
    @FocusState private var isContactFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg ?? 24) {
                Text(LocalizedStringKey("We value your feedback"))
                    .font(AppFonts.title2Bold ?? .title2.bold())
                    .foregroundColor(AppColors.textPrimary ?? .primary)
                    .padding(.bottom, AppSpacing.sm ?? 8)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityLabel(LocalizedStringKey("Feedback header"))
                    .accessibilityHint(LocalizedStringKey("Indicates the feedback section"))

                Text(LocalizedStringKey("Let us know if you have suggestions, encounter bugs, or need support. Your input helps improve Furfolio."))
                    .font(AppFonts.body ?? .body)
                    .foregroundColor(AppColors.textSecondary ?? .secondary)
                    .accessibilityLabel(LocalizedStringKey("Feedback description"))

                Picker(LocalizedStringKey("Category"), selection: $viewModel.category) {
                    ForEach(FeedbackCategory.allCases) { cat in
                        Text(LocalizedStringKey(cat.rawValue)).tag(cat)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .accessibilityLabel(LocalizedStringKey("Feedback category picker"))
                .accessibilityHint(LocalizedStringKey("Select the category of your feedback"))

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

                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundColor(AppColors.error ?? .red)
                        .font(AppFonts.footnote ?? .footnote)
                        .padding(.top, -(AppSpacing.xs ?? 4))
                        .transition(.opacity)
                        .accessibilityLabel(LocalizedStringKey("Error message"))
                        .accessibilityHint(LocalizedStringKey("There was an error submitting your feedback."))
                }

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

                Button(action: {
                    hideKeyboard()
                    viewModel.submitFeedback()
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
    }

    private func hideKeyboard() {
#if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
#endif
    }
}

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
                FeedbackView()
            }
            .preferredColorScheme(.light)
            .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
            .previewDisplayName("Accessibility Large Text")
        }
    }
}

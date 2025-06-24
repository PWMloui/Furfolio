//
//  OnboardingDataImportView.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import SwiftUI

/// Onboarding step for importing demo/sample data or user files.
/// 
/// This view provides users with an accessible interface to import sample data or their own files,
/// facilitating a faster start with the app. All user-facing strings are localized to support multiple languages.
/// Accessibility traits and labels are added to improve usability for assistive technologies.
/// Design tokens are used for consistent styling, with TODOs indicating where tokens should be applied.
/// 
/// Future enhancements include audit logging for user actions and expanded file import capabilities.
struct OnboardingDataImportView: View {
    enum ImportState {
        case idle
        case loading
        case success
        case failed(String)
    }

    @State private var importState: ImportState = .idle
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: AppSpacing.large) { // TODO: Confirm AppSpacing.large value
            header

            description

            statusIndicator

            importButtons
        }
        .padding()
        .accessibilityElement(children: .contain)
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: AppSpacing.medium) { // TODO: Confirm AppSpacing.medium value
            Image(systemName: "tray.and.arrow.down.fill")
                .resizable()
                .scaledToFit()
                .frame(height: 64)
                .foregroundColor(AppColors.accent) // TODO: Replace with AppColors.accent
                .accessibilityLabel(Text(NSLocalizedString("Import Icon", comment: "Accessibility label for import icon")))

            Text(LocalizedStringKey("Import Sample Data"))
                .font(AppFonts.title.bold()) // TODO: Replace with AppFonts.title
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text(LocalizedStringKey("Get started faster by importing demo clients, appointments, and charge history. Or skip and add your own data later!"))
                .font(AppFonts.body) // TODO: Replace with AppFonts.body
                .multilineTextAlignment(.center)
                .foregroundColor(AppColors.secondary) // TODO: Replace with AppColors.secondary
        }
        .padding(.top, AppSpacing.extraLarge) // TODO: Replace with AppSpacing.extraLarge
        .padding(.horizontal)
    }

    private var description: some View {
        // Placeholder for future description or additional text if needed.
        EmptyView()
    }

    private var statusIndicator: some View {
        VStack(spacing: AppSpacing.small) { // TODO: Confirm AppSpacing.small value
            switch importState {
            case .loading:
                ProgressView(Text(NSLocalizedString("Importing…", comment: "Progress view label while importing")))
                    .progressViewStyle(CircularProgressViewStyle())
            case .success:
                Label {
                    Text(LocalizedStringKey("Demo data imported!"))
                        .font(AppFonts.headline) // TODO: Replace with AppFonts.headline
                } icon: {
                    Image(systemName: "checkmark.seal.fill")
                }
                .foregroundColor(AppColors.success) // TODO: Replace with AppColors.success
            case .failed(let message):
                Text(message)
                    .foregroundColor(AppColors.error) // TODO: Replace with AppColors.error
                    .multilineTextAlignment(.center)
            default:
                EmptyView()
            }
        }
        .padding(.horizontal)
    }

    private var importButtons: some View {
        VStack(spacing: AppSpacing.small) { // TODO: Confirm AppSpacing.small value
            Button {
                importDemoData()
            } label: {
                Label {
                    Text(LocalizedStringKey("Import Demo Data"))
                } icon: {
                    Image(systemName: "square.and.arrow.down")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(importState == .loading || importState == .success)
            .accessibilityLabel(Text(NSLocalizedString("Import Demo Data", comment: "Button label for importing demo data")))
            .accessibilityHint(Text(NSLocalizedString("Starts importing demo data into the app", comment: "Accessibility hint for import demo data button")))

            Button {
                // Future: File picker logic
            } label: {
                Label {
                    Text(LocalizedStringKey("Import from File (CSV, JSON)"))
                } icon: {
                    Image(systemName: "doc.fill.badge.plus")
                }
            }
            .buttonStyle(.bordered)
            .disabled(true) // Coming soon
            .accessibilityLabel(Text(NSLocalizedString("Import from File", comment: "Button label for importing from file")))
            .accessibilityHint(Text(NSLocalizedString("Coming soon: import data from CSV or JSON files", comment: "Accessibility hint for import from file button")))

            Button {
                // TODO: Add audit logging/business analytics for skip action
                dismiss()
            } label: {
                Text(LocalizedStringKey("Skip"))
            }
            .foregroundColor(AppColors.accent) // TODO: Replace with AppColors.accent
            .padding(.top, AppSpacing.medium) // TODO: Replace with AppSpacing.medium
            .accessibilityLabel(Text(NSLocalizedString("Skip", comment: "Button label to skip importing data")))
            .accessibilityHint(Text(NSLocalizedString("Skips data import and continues to the app", comment: "Accessibility hint for skip button")))
        }
    }

    // MARK: - Logic

    private func importDemoData() {
        importState = .loading
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // Simulate loading

            do {
                // TODO: Add audit logging/business analytics for import demo data action
                await DemoDataManager.shared.populateDemoData(in: modelContext)
                importState = .success
            } catch {
                importState = .failed(NSLocalizedString("Could not import demo data. Please try again.", comment: "Error message when demo data import fails"))
            }
        }
    }
}

#Preview {
    Group {
        OnboardingDataImportView()
            .environment(\.modelContext, .init(DemoDataManager.shared))
            .preferredColorScheme(.light)
            .environment(\.sizeCategory, .large)
            .previewDisplayName("Light Mode - Large Text")

        OnboardingDataImportView()
            .environment(\.modelContext, .init(DemoDataManager.shared))
            .preferredColorScheme(.dark)
            .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
            .previewDisplayName("Dark Mode - Accessibility XXXL Text")
    }
}

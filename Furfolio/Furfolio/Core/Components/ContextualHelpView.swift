//
//  ContextualHelpView.swift
//  Furfolio
//
//  Enhanced: analytics/audit–ready, Trust Center–ready, preview/test–injectable, robust accessibility.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Analytics/Audit Protocol

public protocol ContextualHelpAnalyticsLogger {
    func log(event: String, info: [String: Any]?)
}
public struct NullContextualHelpAnalyticsLogger: ContextualHelpAnalyticsLogger {
    public init() {}
    public func log(event: String, info: [String: Any]?) {}
}

// MARK: - ContextualHelpView (Enhanced)

struct ContextualHelpView: View {
    let title: String
    let message: String

    enum IconType {
        case systemName(String)
        case assetName(String)
    }
    var icon: IconType = .systemName("questionmark.circle.fill")
    var showDismissButton: Bool = true
    var secondaryActionLabel: String? = nil
    var secondaryActionHandler: (() -> Void)? = nil

    @Binding var externalIsVisible: Bool?
    @State private var internalIsVisible: Bool = true
    private var isVisibleBinding: Binding<Bool> {
        Binding<Bool>(
            get: { externalIsVisible ?? internalIsVisible },
            set: { newValue in
                if externalIsVisible != nil {
                    externalIsVisible = newValue
                } else {
                    internalIsVisible = newValue
                }
            }
        )
    }

    // Analytics logger (swap for QA, Trust Center, print, or admin review)
    static var analyticsLogger: ContextualHelpAnalyticsLogger = NullContextualHelpAnalyticsLogger()

    #if os(iOS) || os(tvOS)
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
    #endif

    var body: some View {
        if isVisibleBinding.wrappedValue {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                HStack(spacing: AppSpacing.small) {
                    iconView
                        .font(AppFonts.title2)
                        .foregroundColor(AppColors.accent)
                        .accessibilityHidden(true)
                    Text(title)
                        .font(AppFonts.headline)
                        .foregroundColor(AppColors.primaryText)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("ContextualHelpView_Title")
                    Spacer()
                    if showDismissButton {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppColors.secondaryText)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Dismiss Help")
                        .accessibilityHint("Closes the help message.")
                        .accessibilityIdentifier("ContextualHelpView_DismissButton")
                    }
                }
                Text(message)
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.secondaryText)
                    .accessibilityAddTraits(.isStaticText)
                    .accessibilityLabel(Text(message))
                    .accessibilityIdentifier("ContextualHelpView_Message")

                if let label = secondaryActionLabel, let handler = secondaryActionHandler {
                    Button(action: {
                        Self.analyticsLogger.log(event: "secondary_action", info: [
                            "title": title,
                            "label": label
                        ])
                        handler()
                    }) {
                        Text(label)
                            .font(AppFonts.subheadline)
                            .foregroundColor(AppColors.accent)
                            .padding(.vertical, AppSpacing.small)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: BorderRadius.medium)
                                    .stroke(AppColors.accent, lineWidth: 1)
                            )
                    }
                    .accessibilityLabel(Text(label))
                    .accessibilityHint(Text("Performs the '\(label)' action for this help message."))
                    .accessibilityIdentifier("ContextualHelpView_SecondaryActionButton")
                }
            }
            .padding(AppSpacing.medium)
            .background(
                RoundedRectangle(cornerRadius: BorderRadius.medium)
                    .fill(AppColors.card)
                    .appShadow(AppShadows.card)
            )
            .padding(.horizontal, AppSpacing.medium)
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.easeInOut, value: isVisibleBinding.wrappedValue)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("Inline Help: \(title). \(message)"))
            .accessibilitySortPriority(1)
            .accessibilityIdentifier("ContextualHelpView_Root")
            .onAppear {
                Self.analyticsLogger.log(event: "help_shown", info: [
                    "title": title,
                    "message": message
                ])
            }
        }
    }

    @ViewBuilder
    private var iconView: some View {
        switch icon {
        case .systemName(let name):
            Image(systemName: name)
        case .assetName(let name):
            Image(name)
                .renderingMode(.template)
        }
    }

    private func dismiss() {
        #if os(iOS) || os(tvOS)
        feedbackGenerator.impactOccurred()
        #endif
        isVisibleBinding.wrappedValue = false
        Self.analyticsLogger.log(event: "help_dismissed", info: [
            "title": title
        ])
    }
}

// MARK: - Preview with Analytics Logger

#Preview {
    struct SpyLogger: ContextualHelpAnalyticsLogger {
        func log(event: String, info: [String : Any]?) {
            print("[ContextualHelpAnalytics] \(event): \(info ?? [:])")
        }
    }
    ContextualHelpView.analyticsLogger = SpyLogger()
    return VStack(spacing: AppSpacing.large) {
        Spacer()
        ContextualHelpView(
            title: "Need a hand?",
            message: "Tap the '+' to add new clients or pets. For more tips, visit the FAQ in Settings.",
            icon: .systemName("questionmark.circle.fill"),
            showDismissButton: true,
            secondaryActionLabel: "Learn More",
            secondaryActionHandler: { print("Learn More tapped") },
            externalIsVisible: .constant(true)
        )
        ContextualHelpView(
            title: "Custom Icon Example",
            message: "This help view uses a custom asset icon and no dismiss button.",
            icon: .assetName("customHelpIcon"),
            showDismissButton: false,
            externalIsVisible: .constant(true)
        )
        ContextualHelpView(
            title: "Controlled Visibility",
            message: "This help view's visibility is controlled externally.",
            icon: .systemName("info.circle.fill"),
            showDismissButton: true,
            secondaryActionLabel: "Details",
            secondaryActionHandler: { print("Details tapped") },
            externalIsVisible: .constant(true)
        )
        Spacer()
    }
    .background(AppColors.background)
    .padding(AppSpacing.medium)
}

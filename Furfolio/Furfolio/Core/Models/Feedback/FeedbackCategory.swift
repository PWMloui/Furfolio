//
//  FeedbackCategory.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//  Enhanced for internationalization, accessibility, analytics, and UI.
//

import Foundation
import SwiftUI

/// Categories for user feedback and support requests.
/// Use these for analytics, triage, and routing.
enum FeedbackCategory: String, CaseIterable, Identifiable, Codable {
    case bugReport = "Bug Report"
    case featureRequest = "Feature Request"
    case generalFeedback = "General Feedback"
    case billingIssue = "Billing Issue"
    case accountHelp = "Account Help"
    case dataExport = "Data Export"
    case compliance = "Compliance"
    case other = "Other"

    // MARK: - Display Name (Localized)
    var displayName: String {
        NSLocalizedString(self.rawValue, comment: "Feedback category: \(self.rawValue)")
    }

    // MARK: - Accessibility Label
    var accessibilityLabel: String {
        switch self {
        case .bugReport: return NSLocalizedString("Report an app bug or technical issue.", comment: "")
        case .featureRequest: return NSLocalizedString("Suggest a new feature or improvement.", comment: "")
        case .generalFeedback: return NSLocalizedString("Share your thoughts about Furfolio.", comment: "")
        case .billingIssue: return NSLocalizedString("Get help with billing or payments.", comment: "")
        case .accountHelp: return NSLocalizedString("Account or login help.", comment: "")
        case .dataExport: return NSLocalizedString("Request a data export.", comment: "")
        case .compliance: return NSLocalizedString("Privacy, legal, or audit concerns.", comment: "")
        case .other: return NSLocalizedString("Other feedback or inquiry.", comment: "")
        }
    }

    // MARK: - Developer-friendly identifier.
    var id: String { rawValue }

    // MARK: - Analytics/Event Key (short, lowercase)
    var analyticsKey: String {
        switch self {
        case .bugReport: return "bug"
        case .featureRequest: return "feature"
        case .generalFeedback: return "feedback"
        case .billingIssue: return "billing"
        case .accountHelp: return "account"
        case .dataExport: return "export"
        case .compliance: return "compliance"
        case .other: return "other"
        }
    }

    // MARK: - SF Symbol for visual context in the UI.
    var icon: String {
        switch self {
        case .bugReport: return "ladybug"
        case .featureRequest: return "lightbulb"
        case .generalFeedback: return "bubble.left.and.bubble.right"
        case .billingIssue: return "creditcard"
        case .accountHelp: return "person.crop.circle.badge.questionmark"
        case .dataExport: return "square.and.arrow.up"
        case .compliance: return "checkmark.shield"
        case .other: return "ellipsis.bubble"
        }
    }

    /// Returns true if the SF Symbol exists on this OS (future-proofing).
    var isValidSymbol: Bool {
        UIImage(systemName: icon) != nil
    }

    // MARK: - Localized Description
    var description: String {
        switch self {
        case .bugReport:
            return NSLocalizedString("Report an app bug or technical issue.", comment: "")
        case .featureRequest:
            return NSLocalizedString("Suggest a new feature or improvement.", comment: "")
        case .generalFeedback:
            return NSLocalizedString("Share your thoughts about Furfolio.", comment: "")
        case .billingIssue:
            return NSLocalizedString("Get help with billing, payments, or invoices.", comment: "")
        case .accountHelp:
            return NSLocalizedString("Issues accessing your account, settings, or data.", comment: "")
        case .dataExport:
            return NSLocalizedString("Request your business or customer data export.", comment: "")
        case .compliance:
            return NSLocalizedString("Report privacy, audit, or legal concerns.", comment: "")
        case .other:
            return NSLocalizedString("Any other inquiry or feedback.", comment: "")
        }
    }

    // MARK: - Category grouping (for sectioned picker/future UX)
    var group: String {
        switch self {
        case .bugReport, .featureRequest, .generalFeedback, .other:
            return NSLocalizedString("General", comment: "")
        case .billingIssue, .accountHelp, .dataExport, .compliance:
            return NSLocalizedString("Account & Compliance", comment: "")
        }
    }

    // MARK: - For sorting categories in pickers
    var order: Int {
        switch self {
        case .bugReport: return 0
        case .featureRequest: return 1
        case .generalFeedback: return 2
        case .billingIssue: return 3
        case .accountHelp: return 4
        case .dataExport: return 5
        case .compliance: return 6
        case .other: return 99
        }
    }

    // MARK: - Section headers for grouped UI
    static var grouped: [(group: String, items: [FeedbackCategory])] {
        Dictionary(grouping: allCases, by: { $0.group })
            .sorted { $0.value.first?.order ?? 0 < $1.value.first?.order ?? 0 }
            .map { ($0.key, $0.value.sorted { $0.order < $1.order }) }
    }

    // MARK: - Helper for analytics mapping (case-insensitive)
    static func from(analyticsKey: String) -> FeedbackCategory? {
        FeedbackCategory.allCases.first { $0.analyticsKey.lowercased() == analyticsKey.lowercased() }
    }

    // MARK: - For pickers and filtering (sorted)
    static var allCasesSorted: [FeedbackCategory] {
        FeedbackCategory.allCases.sorted { $0.order < $1.order }
    }

    // MARK: - Test/mock/demo support
    static var preview: FeedbackCategory { .featureRequest }
    static func random() -> FeedbackCategory { allCases.randomElement() ?? .generalFeedback }
}

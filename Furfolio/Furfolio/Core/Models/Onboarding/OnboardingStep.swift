//
//  OnboardingStep.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

/**
 OnboardingStep
 --------------
 Defines each step in the Furfolio onboarding flow with associated metadata, localization, and audit hooks.

 - **Architecture**: Tokenized enum conforming to `Identifiable`, `CaseIterable`, `Hashable`, `Codable`, and usable in SwiftUI lists and navigation.
 - **Localization**: All titles, descriptions, and routeKeys are localized via `LocalizedStringKey`.
 - **Audit/Analytics Ready**: Provides async audit logging hooks via `OnboardingStepAuditManager`.
 - **Diagnostics**: Audit entries can be fetched or exported for diagnostic review.
 - **Preview/Testability**: Includes methods to log and retrieve audit entries for testing.
 */

import Foundation
import SwiftUI

public enum OnboardingStep: Int, CaseIterable, Identifiable, Hashable, Codable {
    case welcome
    case dataImport
    case tutorial
    case faq
    case permissions
    case completion

    var id: Int { self.rawValue }

    /// User-facing title
    var title: LocalizedStringKey {
        switch self {
        case .welcome: return "Welcome"
        case .dataImport: return "Import Data"
        case .tutorial: return "Tutorial"
        case .faq: return "FAQ"
        case .permissions: return "Permissions"
        case .completion: return "All Set"
        }
    }

    /// Description used in step indicators, coordinator views, or tooltips
    var description: LocalizedStringKey {
        switch self {
        case .welcome: return "Let’s get started with Furfolio!"
        case .dataImport: return "Load sample data or import your own"
        case .tutorial: return "Learn how to navigate and use the app"
        case .faq: return "Answers to common questions"
        case .permissions: return "Grant required app permissions"
        case .completion: return "Start using Furfolio"
        }
    }

    /// SF Symbol icon for onboarding step indication
    var iconName: String {
        switch self {
        case .welcome: return "hand.wave"
        case .dataImport: return "tray.and.arrow.down.fill"
        case .tutorial: return "rectangle.stack.badge.play"
        case .faq: return "questionmark.circle"
        case .permissions: return "bell.badge"
        case .completion: return "checkmark.seal.fill"
        }
    }

    /// Optional route identifier if navigation is route-driven
    var routeKey: String {
        switch self {
        case .welcome: return "onboarding.welcome"
        case .dataImport: return "onboarding.import"
        case .tutorial: return "onboarding.tutorial"
        case .faq: return "onboarding.faq"
        case .permissions: return "onboarding.permissions"
        case .completion: return "onboarding.completion"
        }
    }
}

// MARK: - Audit Entry & Manager

/// A record of an onboarding step audit event.
public struct OnboardingStepAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let step: OnboardingStep
    public let action: String

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        step: OnboardingStep,
        action: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.step = step
        self.action = action
    }
}

/// Manages concurrency-safe audit logging for onboarding steps.
public actor OnboardingStepAuditManager {
    private var buffer: [OnboardingStepAuditEntry] = []
    private let maxEntries = 100
    public static let shared = OnboardingStepAuditManager()

    /// Add a new audit entry, retaining only the most recent `maxEntries`.
    public func add(_ entry: OnboardingStepAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    /// Fetch recent audit entries up to the specified limit.
    public func recent(limit: Int = 20) -> [OnboardingStepAuditEntry] {
        Array(buffer.suffix(limit))
    }

    /// Export all audit entries as a JSON string.
    public func exportJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(buffer),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }
}

// MARK: - Async Audit Methods

public extension OnboardingStep {
    /// Log an audit event for this onboarding step asynchronously.
    /// - Parameter action: A description of the user’s interaction with the step.
    func logAudit(action: String) async {
        let localizedAction = NSLocalizedString(action, comment: "OnboardingStep audit action")
        let entry = OnboardingStepAuditEntry(step: self, action: localizedAction)
        await OnboardingStepAuditManager.shared.add(entry)
    }

    /// Fetch recent audit entries for onboarding steps.
    /// - Parameter limit: Maximum number of entries to retrieve.
    static func recentAuditEntries(limit: Int = 20) async -> [OnboardingStepAuditEntry] {
        await OnboardingStepAuditManager.shared.recent(limit: limit)
    }

    /// Export the onboarding step audit log as JSON asynchronously.
    static func exportAuditLogJSON() async -> String {
        await OnboardingStepAuditManager.shared.exportJSON()
    }
}

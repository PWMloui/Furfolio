//
//  FeedbackAnalyticsManager.swift
//  Furfolio
//
//  Created by mac on 6/30/25.
//

import Foundation
import SwiftData

/// Types of feedback-related analytics events.
public enum FeedbackAnalyticsEventType: String, Codable, CaseIterable, Identifiable {
    public var id: String { rawValue }
    case view    // When the feedback screen is viewed
    case submit  // When feedback is submitted
    case error   // When submission fails
    
    public var displayName: String {
        switch self {
        case .view: return NSLocalizedString("Viewed Feedback Screen", comment: "")
        case .submit: return NSLocalizedString("Submitted Feedback", comment: "")
        case .error: return NSLocalizedString("Feedback Error", comment: "")
        }
    }
}

/// A persisted record of a feedback analytics event.
@Model public struct FeedbackAnalyticsEvent: Identifiable {
    @Attribute(.unique) public var id: UUID = UUID()
    /// When the event occurred.
    public var timestamp: Date = Date()
    /// The type of event.
    public var type: FeedbackAnalyticsEventType
    /// Category of feedback, if applicable.
    public var category: String?
    /// Length of the feedback message, if applicable.
    public var messageLength: Int?
    /// Whether contact info was provided.
    public var didProvideContact: Bool?
    
    /// A concise label for VoiceOver.
    @Attribute(.transient)
    public var accessibilityLabel: String {
        let base = type.displayName
        let extras: [String] = [
            category.map { NSLocalizedString("Category: \($0)", comment: "") } ?? "",
            messageLength.map { String(format: NSLocalizedString("Length: %d characters", comment: ""), $0) } ?? "",
            didProvideContact == true ? NSLocalizedString("Contact Provided", comment: "") : ""
        ].filter { !$0.isEmpty }
        return ([base] + extras).joined(separator: ", ")
    }
}

/// Manages logging and querying of feedback analytics events.
public class FeedbackAnalyticsManager: ObservableObject {
    public static let shared = FeedbackAnalyticsManager()
    private init() {}

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \.timestamp, order: .forward) public var events: [FeedbackAnalyticsEvent]

    /// Logs a generic feedback analytics event.
    public func logEvent(
        _ type: FeedbackAnalyticsEventType,
        category: String? = nil,
        messageLength: Int? = nil,
        didProvideContact: Bool? = nil
    ) {
        let event = FeedbackAnalyticsEvent(
            type: type,
            category: category,
            messageLength: messageLength,
            didProvideContact: didProvideContact
        )
        modelContext.insert(event)
    }

    /// Convenience: Log that the feedback screen was viewed.
    public func logView() {
        logEvent(.view)
    }

    /// Convenience: Log a successful submission.
    public func logSubmit(category: String, messageLength: Int, didProvideContact: Bool) {
        logEvent(.submit, category: category, messageLength: messageLength, didProvideContact: didProvideContact)
    }

    /// Convenience: Log an error during submission.
    public func logError(message: String) {
        logEvent(.error, category: "Error", messageLength: message.count, didProvideContact: nil)
    }

    /// Exports the last analytics event as pretty-printed JSON.
    public func exportLastEventJSON() async -> String? {
        let entries = try? await modelContext.fetch(FeedbackAnalyticsEvent.self)
        guard let last = entries?.last else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return (try? String(data: encoder.encode(last), encoding: .utf8))
    }

    /// Clears all persisted analytics events.
    public func clearAllEvents() async {
        let entries = try? await modelContext.fetch(FeedbackAnalyticsEvent.self)
        entries?.forEach { modelContext.delete($0) }
    }
}

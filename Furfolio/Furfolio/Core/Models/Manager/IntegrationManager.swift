//
//  IntegrationManager.swift
//  Furfolio
//
//  Created by mac on 6/30/25.
//

import Foundation
import SwiftData

/// Types of external integrations supported by Furfolio.
public enum IntegrationType: String, CaseIterable, Identifiable {
    public var id: String { rawValue }
    case googleCalendar
    case zapierWebhook
    case customAPI
    
    /// Human-readable name.
    public var displayName: String {
        switch self {
        case .googleCalendar: return NSLocalizedString("Google Calendar", comment: "")
        case .zapierWebhook: return NSLocalizedString("Zapier Webhook", comment: "")
        case .customAPI: return NSLocalizedString("Custom API", comment: "")
        }
    }
}

/// A record of an integration event.
@Model public struct IntegrationEvent: Identifiable {
    @Attribute(.unique) public var id: UUID = UUID()
    /// When the integration was attempted.
    public var timestamp: Date = Date()
    /// The type of integration.
    public var type: IntegrationType
    /// Optional target URL or identifier.
    public var target: String?
    /// Details or payload summary.
    public var details: String?
    /// Whether the integration succeeded.
    public var success: Bool
    /// Optional error message if it failed.
    public var errorMessage: String?
    
    /// Accessibility label for VoiceOver.
    @Attribute(.transient)
    public var accessibilityLabel: String {
        let status = success
            ? NSLocalizedString("Success", comment: "")
            : NSLocalizedString("Failure", comment: "")
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "\(type.displayName) \(status) at \(dateStr)."
    }
}

/// Manages external service integrations.
public class IntegrationManager: ObservableObject {
    public static let shared = IntegrationManager()
    private init() {}
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \.timestamp, order: .reverse) public var events: [IntegrationEvent]
    
    /// Attempts to sync an appointment to Google Calendar.
    public func syncAppointmentToGoogle(appointmentID: UUID, calendarID: String) async {
        // Placeholder: perform network request here.
        let success = true
        let errorMessage: String? = success ? nil : "Network error"
        await logEvent(
            type: .googleCalendar,
            target: calendarID,
            details: "Appointment \(appointmentID.uuidString)",
            success: success,
            errorMessage: errorMessage
        )
    }
    
    /// Sends data to a Zapier webhook URL.
    public func sendToZapier(url: URL, payload: [String: Any]) async {
        // Placeholder: perform POST request here.
        let success = true
        let details = String(describing: payload)
        await logEvent(
            type: .zapierWebhook,
            target: url.absoluteString,
            details: details,
            success: success,
            errorMessage: success ? nil : "HTTP error"
        )
    }
    
    /// Generic custom API call.
    public func callCustomAPI(endpoint: URL, body: Data) async {
        // Placeholder: perform request here.
        let success = true
        await logEvent(
            type: .customAPI,
            target: endpoint.absoluteString,
            details: "Sent \(body.count) bytes",
            success: success,
            errorMessage: success ? nil : "API error"
        )
    }
    
    /// Logs an integration event to the audit log.
    public func logEvent(
        type: IntegrationType,
        target: String? = nil,
        details: String? = nil,
        success: Bool,
        errorMessage: String? = nil
    ) async {
        let event = IntegrationEvent(
            type: type,
            target: target,
            details: details,
            success: success,
            errorMessage: errorMessage
        )
        modelContext.insert(event)
    }
    
    /// Exports the last integration event as JSON.
    public func exportLastEventJSON() async -> String? {
        guard let last = events.first else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return (try? String(data: encoder.encode(last), encoding: .utf8))
    }
    
    /// Clears all integration events.
    public func clearAllEvents() async {
        events.forEach { modelContext.delete($0) }
    }
    
    /// Accessibility summary for the last integration.
    public var accessibilitySummary: String {
        get async {
            guard let last = events.first else {
                return NSLocalizedString("No integration events recorded.", comment: "")
            }
            return last.accessibilityLabel
        }
    }
}

//
//  RetentionAlertEngine.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import Foundation

// MARK: - RetentionAlertEngine (Retention Alerts, Risk Analytics, Modular, Tokenized)

/// `RetentionAlertEngine` is a modular, tokenized, and accessible core business logic engine responsible for generating
/// retention alerts and summaries for Furfolio clients (dog owners). It is designed for extensibility and full integration
/// with the design system, including tokenized badge colors and icons for UI consistency. The engine supports audit logging,
/// analytics hooks, and comprehensive retention risk analysis.
///
/// This engine supports:
/// - Generating retention alerts for a list of dog owners.
/// - Summarizing retention alert counts by type.
/// - Filtering owners by retention risk or inactivity.
/// - Publishing audit logs or analytics hooks when alerts are generated.
/// - Providing convenience UI summary data for quick display, leveraging design tokens for all visual elements.
///
/// Designed as a thread-safe singleton with main actor isolation for UI safety and concurrency.
/// Supports Codable conformance for persistence or networking.
///
/// Usage:
/// ```swift
/// let alerts = RetentionAlertEngine.shared.generateAlerts(for: owners)
/// let summary = RetentionAlertEngine.shared.retentionAlertSummary(for: owners)
/// ```
@MainActor
public final class RetentionAlertEngine {

    // MARK: - Singleton Instance

    /// Shared singleton instance of the retention alert engine.
    public static let shared = RetentionAlertEngine()

    private init() {}

    // MARK: - Constants

    private struct Constants {
        static let retentionRiskDays = 60
        static let inactiveDays = 180
        static let newClientDays = 14
        static let notificationName = Notification.Name("RetentionAlertEngineAlertGenerated")
    }

    // MARK: - Public Types

    /// Closure type for audit log or analytics callback when an alert is generated.
    public typealias AlertGeneratedHandler = (RetentionAlert) -> Void

    // MARK: - Properties

    /// Optional handler to be called whenever an alert is generated.
    public var alertGeneratedHandler: AlertGeneratedHandler?

    // MARK: - Alert Generation

    /// Generates retention alerts for the provided list of dog owners.
    ///
    /// - Parameter owners: Array of `DogOwner` to analyze.
    /// - Returns: Array of `RetentionAlert` representing alerts for owners.
    ///
    /// This method triggers audit log hooks via `alertGeneratedHandler` and posts a notification.
    public func generateAlerts(for owners: [DogOwner]) -> [RetentionAlert] {
        owners.compactMap { owner in
            let status = CustomerRetentionAnalyzer.shared.retentionTag(for: owner)
            let alert: RetentionAlert?

            switch status {
            case .retentionRisk:
                alert = RetentionAlert(
                    ownerID: owner.id,
                    type: .retentionRisk,
                    message: "\(owner.ownerName) is at risk of churn (no appointment in over \(Constants.retentionRiskDays) days).",
                    lastAppointment: owner.lastAppointmentDate
                )
            case .inactive:
                alert = RetentionAlert(
                    ownerID: owner.id,
                    type: .inactive,
                    message: "\(owner.ownerName) is now inactive (no appointment in over \(Constants.inactiveDays) days).",
                    lastAppointment: owner.lastAppointmentDate
                )
            case .newClient:
                alert = RetentionAlert(
                    ownerID: owner.id,
                    type: .newClient,
                    message: "\(owner.ownerName) is a new client—engage and welcome!",
                    lastAppointment: owner.lastAppointmentDate
                )
            default:
                alert = nil // No alert for active/returning by default
            }

            // Trigger audit log/analytics hook if alert generated
            if let alert = alert {
                alertGeneratedHandler?(alert)
                NotificationCenter.default.post(name: Constants.notificationName, object: alert)
            }

            return alert
        }
    }

    // MARK: - Summary Generation

    /// Generates a summary dictionary counting the number of alerts by each retention alert type.
    ///
    /// - Parameter owners: Array of `DogOwner` to analyze.
    /// - Returns: Dictionary mapping `RetentionAlertType` to count of alerts.
    /// All UI-facing label, color, and icon values must use design tokens (never hardcoded).
    public func retentionAlertSummary(for owners: [DogOwner]) -> [RetentionAlertType: Int] {
        let alerts = generateAlerts(for: owners)
        return Dictionary(grouping: alerts, by: { $0.type }).mapValues { $0.count }
    }

    /// Provides a convenience summary for UI display with total alerts count,
    /// a badge color token, and SF Symbol icon string corresponding to the highest priority alert type.
    ///
    /// - Parameter owners: Array of `DogOwner` to analyze.
    /// - Returns: A tuple containing summary text, badge color token (for AppColors), and SF Symbol icon string (for UI use).
    /// All UI-facing label, color, and icon values must use design tokens (never hardcoded).
    public func uiSummary(for owners: [DogOwner]) -> (summaryText: String, badgeColor: String, badgeIcon: String) {
        let summary = retentionAlertSummary(for: owners)
        let totalAlerts = summary.values.reduce(0, +)

        guard totalAlerts > 0 else {
            return ("No retention alerts", "green", "checkmark.circle")
        }

        // Determine highest priority alert type present
        // Priority order: retentionRisk > inactive > newClient
        let priorityTypes: [RetentionAlertType] = [.retentionRisk, .inactive, .newClient]
        let highestPriorityType = priorityTypes.first(where: { summary[$0] != nil && summary[$0]! > 0 })!

        let count = summary[highestPriorityType] ?? 0
        let text = "\(count) \(highestPriorityType.label)\(count > 1 ? "s" : "")"
        return (text, highestPriorityType.color, highestPriorityType.icon)
    }

    // MARK: - Owner Filtering

    /// Returns all owners currently at risk of churn.
    ///
    /// - Parameter owners: Array of `DogOwner` to filter.
    /// - Returns: Array of `DogOwner` with retention risk status.
    public func ownersAtRisk(in owners: [DogOwner]) -> [DogOwner] {
        owners.filter {
            CustomerRetentionAnalyzer.shared.retentionTag(for: $0) == .retentionRisk
        }
    }

    /// Returns all owners currently inactive.
    ///
    /// - Parameter owners: Array of `DogOwner` to filter.
    /// - Returns: Array of `DogOwner` with inactive status.
    public func inactiveOwners(in owners: [DogOwner]) -> [DogOwner] {
        owners.filter {
            CustomerRetentionAnalyzer.shared.retentionTag(for: $0) == .inactive
        }
    }

    // MARK: - Preview / Dummy Data Support

    /// Generates dummy retention alerts for preview or testing purposes.
    ///
    /// - Returns: Array of sample `RetentionAlert` instances.
    /// All UI-facing label, color, and icon values must use design tokens (never hardcoded).
    public static func previewAlerts() -> [RetentionAlert] {
        [
            RetentionAlert(
                ownerID: UUID(),
                type: .retentionRisk,
                message: "John Doe is at risk of churn (no appointment in over 60 days).",
                lastAppointment: Date().addingTimeInterval(-70 * 24 * 60 * 60)
            ),
            RetentionAlert(
                ownerID: UUID(),
                type: .inactive,
                message: "Jane Smith is now inactive (no appointment in over 180 days).",
                lastAppointment: Date().addingTimeInterval(-200 * 24 * 60 * 60)
            ),
            RetentionAlert(
                ownerID: UUID(),
                type: .newClient,
                message: "New client Alex Johnson—engage and welcome!",
                lastAppointment: Date().addingTimeInterval(-5 * 24 * 60 * 60)
            )
        ]
    }
}

// MARK: - RetentionAlert

/// Represents a single retention alert associated with a dog owner.
/// Conforms to `Identifiable`, `Hashable`, and `Codable` for persistence and UI use.
public struct RetentionAlert: Identifiable, Hashable, Codable {
    public var id: UUID { ownerID }
    public let ownerID: UUID
    public let type: RetentionAlertType
    public let message: String
    public let lastAppointment: Date?

    public init(ownerID: UUID, type: RetentionAlertType, message: String, lastAppointment: Date?) {
        self.ownerID = ownerID
        self.type = type
        self.message = message
        self.lastAppointment = lastAppointment
    }
}

// MARK: - RetentionAlertType

/// Enumeration of retention alert types.
/// Conforms to `String`, `CaseIterable`, `Identifiable`, and `Codable`.
public enum RetentionAlertType: String, CaseIterable, Identifiable, Codable {
    case retentionRisk
    case inactive
    case newClient

    public var id: String { rawValue }

    /// User-friendly label for display.
    /// All UI-facing label, color, and icon values must use design tokens (never hardcoded).
    public var label: String {
        switch self {
        case .retentionRisk: return "Retention Risk"
        case .inactive: return "Inactive"
        case .newClient: return "New Client"
        }
    }

    /// System icon name for UI representation.
    /// All UI-facing label, color, and icon values must use design tokens (never hardcoded).
    public var icon: String {
        switch self {
        case .retentionRisk: return "exclamationmark.triangle.fill"
        case .inactive: return "zzz"
        case .newClient: return "sparkles"
        }
    }

    /// Color name string representing the alert type.
    /// Returns a design token color name (for AppColors), not a hardcoded color.
    /// TODO: Refactor to return an AppColors token value, not a string, and update all references to use AppColors throughout the UI.
    public var color: String {
        switch self {
        case .retentionRisk: return "orange"
        case .inactive: return "gray"
        case .newClient: return "blue"
        }
    }
}


//
//  enums.swift
//  Furfolio
//
//  # Enhanced 2025: Enterprise-Grade Core Enums with Audit Logging
//
//  ## Architecture Overview
//  This file contains foundational enums for Furfolio's core business logic: `ServiceType`, `AppointmentStatus`, and `WidgetType`.
//  Each enum is designed for extensibility, analytics integration, auditability, diagnostics, localization, accessibility, compliance, and preview/testability.
//
//  ## Extensibility
//  - New cases can be added to enums with minimal code changes.
//  - Associated values, computed properties, and display customizations are centralized for easy extension.
//
//  ## Analytics/Audit/Trust Center Hooks
//  - Each enum provides static audit methods and APIs for event logging, export, and summary.
//  - Audit events are structured, timestamped, and include context and userRole for compliance and Trust Center reporting.
//
//  ## Diagnostics
//  - Audit logs can be exported in JSON for diagnostics, incident response, or compliance review.
//
//  ## Localization
//  - All user-facing strings are localized via `NSLocalizedString` with keys, values, and comments.
//  - Adding new languages or updating strings is centralized and maintainable.
//
//  ## Accessibility
//  - Display names and user descriptions are localized for screen readers and assistive technologies.
//  - System icons are used for consistent, accessible UI affordances.
//
//  ## Compliance
//  - Audit trails are capped and structured for privacy, security, and regulatory compliance.
//  - Each event includes userRole for context-aware auditing.
//
//  ## Preview/Testability
//  - Enums conform to `CaseIterable`, `Identifiable`, and `Codable` for easy preview, test, and serialization.
//  - Static APIs allow test harnesses to inject and inspect audit logs.
//
//  ## Maintenance
//  - All functions and properties are documented.
//  - Each enum and case block is documented for future maintainers.
//

import Foundation
import SwiftUI

// MARK: - ServiceType

/// Represents the types of grooming services offered.
/// - Extensible: Add new cases as services expand.
/// - Each case provides localized displayName, icon, duration, price, and category.
public enum ServiceType: String, Codable, CaseIterable, Identifiable {
    /// Full grooming service.
    case fullGroom
    /// Basic bath service.
    case basicBath
    /// Nail trimming service.
    case nailTrim
    /// Teeth cleaning service.
    case teethCleaning
    /// De-shedding service.
    case deShedding
    /// Ear cleaning service.
    case earCleaning
    /// Flea treatment service.
    case fleaTreatment
    /// Custom/other service.
    case custom

    /// Unique identifier for Identifiable.
    public var id: String { rawValue }

    /// Localized display name for UI and accessibility.
    public var displayName: String {
        switch self {
        case .fullGroom:
            return NSLocalizedString("service_fullGroom", value: "Full Groom",
                                    comment: "Display name for Full Groom service")
        case .basicBath:
            return NSLocalizedString("service_basicBath", value: "Basic Bath",
                                    comment: "Display name for Basic Bath service")
        case .nailTrim:
            return NSLocalizedString("service_nailTrim", value: "Nail Trim",
                                    comment: "Display name for Nail Trim service")
        case .teethCleaning:
            return NSLocalizedString("service_teethCleaning", value: "Teeth Cleaning",
                                    comment: "Display name for Teeth Cleaning service")
        case .deShedding:
            return NSLocalizedString("service_deShedding", value: "De-Shedding",
                                    comment: "Display name for De-Shedding service")
        case .earCleaning:
            return NSLocalizedString("service_earCleaning", value: "Ear Cleaning",
                                    comment: "Display name for Ear Cleaning service")
        case .fleaTreatment:
            return NSLocalizedString("service_fleaTreatment", value: "Flea Treatment",
                                    comment: "Display name for Flea Treatment service")
        case .custom:
            return NSLocalizedString("service_custom", value: "Custom",
                                    comment: "Display name for Custom service")
        }
    }

    /// SF Symbol icon for the service.
    public var icon: Image {
        switch self {
        case .fullGroom: return Image(systemName: "scissors")
        case .basicBath: return Image(systemName: "drop")
        case .nailTrim: return Image(systemName: "pawprint")
        case .teethCleaning: return Image(systemName: "mouth")
        case .deShedding: return Image(systemName: "wind")
        case .earCleaning: return Image(systemName: "ear")
        case .fleaTreatment: return Image(systemName: "ant")
        case .custom: return Image(systemName: "star")
        }
    }

    /// Estimated duration in minutes.
    public var durationEstimate: Int {
        switch self {
        case .fullGroom: return 90
        case .basicBath: return 45
        case .nailTrim: return 20
        case .teethCleaning: return 15
        case .deShedding: return 30
        case .earCleaning: return 10
        case .fleaTreatment: return 25
        case .custom: return 60
        }
    }

    /// Suggested price in local currency.
    public var suggestedPrice: Double {
        switch self {
        case .fullGroom: return 75.0
        case .basicBath: return 40.0
        case .nailTrim: return 18.0
        case .teethCleaning: return 20.0
        case .deShedding: return 30.0
        case .earCleaning: return 15.0
        case .fleaTreatment: return 28.0
        case .custom: return 0.0
        }
    }

    /// Localized category name for grouping services.
    public var category: String {
        switch self {
        case .fullGroom, .deShedding:
            return NSLocalizedString("category_grooming", value: "Grooming",
                                    comment: "Category for grooming services")
        case .basicBath, .fleaTreatment:
            return NSLocalizedString("category_bath_treatment", value: "Bath & Treatment",
                                    comment: "Category for bath and treatment services")
        case .nailTrim, .earCleaning, .teethCleaning:
            return NSLocalizedString("category_care", value: "Care",
                                    comment: "Category for care services")
        case .custom:
            return NSLocalizedString("category_custom", value: "Custom",
                                    comment: "Category for custom services")
        }
    }

    // MARK: - Audit/Event Logging

    /// Record an audit event for service usage.
    /// - Parameters:
    ///   - service: The `ServiceType` used.
    ///   - context: Optional context (e.g., booking screen, userID).
    ///   - userRole: Optional user role for compliance context.
    public static func auditUsage(_ service: ServiceType, context: String? = nil, userRole: String? = nil) {
        ServiceTypeAudit.record(service: service, context: context, userRole: userRole)
    }

    /// Returns recent audit event summaries (up to 20).
    public static func recentAuditSummaries(limit: Int = 20) -> [String] {
        ServiceTypeAudit.recentEvents(limit: limit)
    }

    /// Returns recent audit events as JSON (up to 20).
    public static func recentAuditJSON(limit: Int = 20) -> String? {
        ServiceTypeAudit.exportRecentJSON(limit: limit)
    }

    /// Returns the last audit event as JSON.
    public static var lastAuditJSON: String? {
        ServiceTypeAudit.exportLastJSON()
    }
}

/// Audit event structure for ServiceType usage.
fileprivate struct ServiceTypeAuditEvent: Codable {
    let timestamp: Date
    let service: String
    let context: String?
    let userRole: String?
    /// Human-readable event summary.
    var summary: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        let role = userRole != nil ? "[\(userRole!)] " : ""
        return "[Use] \(role)\(service) \(context ?? "") at \(dateStr)"
    }
}
/// Audit/event logger for ServiceType.
fileprivate final class ServiceTypeAudit {
    static nonisolated(unsafe) private(set) var log: [ServiceTypeAuditEvent] = []
    /// Record a new audit event.
    static func record(service: ServiceType, context: String? = nil, userRole: String? = nil) {
        let event = ServiceTypeAuditEvent(timestamp: Date(), service: service.displayName, context: context, userRole: userRole)
        log.append(event)
        if log.count > 50 { log.removeFirst() }
    }
    /// Export the last audit event as JSON.
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    /// Export up to `limit` recent audit events as JSON.
    static func exportRecentJSON(limit: Int = 20) -> String? {
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        let events = Array(log.suffix(limit))
        return (try? encoder.encode(events)).flatMap { String(data: $0, encoding: .utf8) }
    }
    /// Return up to `limit` recent event summaries.
    static func recentEvents(limit: Int = 20) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}

// MARK: - AppointmentStatus

/// Represents the status of an appointment.
/// - Extensible for new status types.
/// - Provides localized displayName, icon, color, and userDescription.
public enum AppointmentStatus: String, Codable, CaseIterable, Identifiable {
    /// Appointment is scheduled and upcoming.
    case scheduled
    /// Appointment was completed.
    case completed
    /// Appointment was cancelled.
    case cancelled
    /// Client did not attend appointment.
    case noShow
    /// Appointment was rescheduled.
    case rescheduled

    /// Unique identifier for Identifiable.
    public var id: String { rawValue }

    /// Localized display name for UI and accessibility.
    public var displayName: String {
        switch self {
        case .scheduled:
            return NSLocalizedString("appt_scheduled", value: "Scheduled", comment: "Display name for scheduled appointment")
        case .completed:
            return NSLocalizedString("appt_completed", value: "Completed", comment: "Display name for completed appointment")
        case .cancelled:
            return NSLocalizedString("appt_cancelled", value: "Cancelled", comment: "Display name for cancelled appointment")
        case .noShow:
            return NSLocalizedString("appt_noShow", value: "No Show", comment: "Display name for no-show appointment")
        case .rescheduled:
            return NSLocalizedString("appt_rescheduled", value: "Rescheduled", comment: "Display name for rescheduled appointment")
        }
    }

    /// SF Symbol icon for the appointment status.
    public var icon: Image {
        Image(systemName: iconName)
    }
    /// Icon name for SF Symbol.
    public var iconName: String {
        switch self {
        case .scheduled: return "calendar"
        case .completed: return "checkmark.circle"
        case .cancelled: return "xmark.circle"
        case .noShow: return "exclamationmark.triangle"
        case .rescheduled: return "arrow.uturn.right"
        }
    }

    /// Color for UI representation.
    public var color: Color {
        switch self {
        case .scheduled: return .accentColor
        case .completed: return .green
        case .cancelled: return .red
        case .noShow: return .orange
        case .rescheduled: return .blue
        }
    }

    /// Localized user-facing description for accessibility.
    public var userDescription: String {
        switch self {
        case .scheduled:
            return NSLocalizedString("apptdesc_scheduled", value: "The appointment is scheduled and upcoming.",
                                    comment: "Description for scheduled appointment")
        case .completed:
            return NSLocalizedString("apptdesc_completed", value: "The appointment was successfully completed.",
                                    comment: "Description for completed appointment")
        case .cancelled:
            return NSLocalizedString("apptdesc_cancelled", value: "The appointment was cancelled by the client or staff.",
                                    comment: "Description for cancelled appointment")
        case .noShow:
            return NSLocalizedString("apptdesc_noShow", value: "The client did not attend the appointment.",
                                    comment: "Description for no-show appointment")
        case .rescheduled:
            return NSLocalizedString("apptdesc_rescheduled", value: "The appointment was rescheduled to a new time.",
                                    comment: "Description for rescheduled appointment")
        }
    }

    // MARK: - Audit/Event Logging

    /// Record an audit event for appointment status usage.
    /// - Parameters:
    ///   - status: The `AppointmentStatus` used.
    ///   - context: Optional context (e.g., scheduler, userID).
    ///   - userRole: Optional user role for compliance context.
    public static func auditUsage(_ status: AppointmentStatus, context: String? = nil, userRole: String? = nil) {
        AppointmentStatusAudit.record(status: status, context: context, userRole: userRole)
    }

    /// Returns recent audit event summaries (up to 20).
    public static func recentAuditSummaries(limit: Int = 20) -> [String] {
        AppointmentStatusAudit.recentEvents(limit: limit)
    }

    /// Returns recent audit events as JSON (up to 20).
    public static func recentAuditJSON(limit: Int = 20) -> String? {
        AppointmentStatusAudit.exportRecentJSON(limit: limit)
    }

    /// Returns the last audit event as JSON.
    public static var lastAuditJSON: String? {
        AppointmentStatusAudit.exportLastJSON()
    }
}

/// Audit event structure for AppointmentStatus usage.
fileprivate struct AppointmentStatusAuditEvent: Codable {
    let timestamp: Date
    let status: String
    let context: String?
    let userRole: String?
    /// Human-readable event summary.
    var summary: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        let role = userRole != nil ? "[\(userRole!)] " : ""
        return "[Status] \(role)\(status) \(context ?? "") at \(dateStr)"
    }
}
/// Audit/event logger for AppointmentStatus.
fileprivate final class AppointmentStatusAudit {
    static nonisolated(unsafe) private(set) var log: [AppointmentStatusAuditEvent] = []
    /// Record a new audit event.
    static func record(status: AppointmentStatus, context: String? = nil, userRole: String? = nil) {
        let event = AppointmentStatusAuditEvent(timestamp: Date(), status: status.displayName, context: context, userRole: userRole)
        log.append(event)
        if log.count > 50 { log.removeFirst() }
    }
    /// Export the last audit event as JSON.
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    /// Export up to `limit` recent audit events as JSON.
    static func exportRecentJSON(limit: Int = 20) -> String? {
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        let events = Array(log.suffix(limit))
        return (try? encoder.encode(events)).flatMap { String(data: $0, encoding: .utf8) }
    }
    /// Return up to `limit` recent event summaries.
    static func recentEvents(limit: Int = 20) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}

// MARK: - WidgetType

/// Represents the types of dashboard widgets available.
/// - Extensible for new analytics widgets.
/// - Provides localized displayName and icon.
public enum WidgetType: String, Codable, CaseIterable, Identifiable {
    /// Key Performance Indicator widget.
    case kpi
    /// Top clients widget.
    case topClients
    /// Service trends widget.
    case serviceTrends
    /// Revenue goal widget.
    case revenueGoal
    /// Appointments heatmap widget.
    case appointmentsHeatmap
    /// Expense breakdown widget.
    case expenseBreakdown
    /// Retention analytics widget.
    case retention
    /// Custom/other widget.
    case custom

    /// Unique identifier for Identifiable.
    public var id: String { rawValue }

    /// Localized display name for UI and accessibility.
    public var displayName: String {
        switch self {
        case .kpi:
            return NSLocalizedString("widget_kpi", value: "KPI", comment: "Display name for KPI widget")
        case .topClients:
            return NSLocalizedString("widget_topClients", value: "Top Clients", comment: "Display name for Top Clients widget")
        case .serviceTrends:
            return NSLocalizedString("widget_serviceTrends", value: "Service Trends", comment: "Display name for Service Trends widget")
        case .revenueGoal:
            return NSLocalizedString("widget_revenueGoal", value: "Revenue Goal", comment: "Display name for Revenue Goal widget")
        case .appointmentsHeatmap:
            return NSLocalizedString("widget_appointmentsHeatmap", value: "Appointments Heatmap", comment: "Display name for Appointments Heatmap widget")
        case .expenseBreakdown:
            return NSLocalizedString("widget_expenseBreakdown", value: "Expense Breakdown", comment: "Display name for Expense Breakdown widget")
        case .retention:
            return NSLocalizedString("widget_retention", value: "Retention", comment: "Display name for Retention widget")
        case .custom:
            return NSLocalizedString("widget_custom", value: "Custom", comment: "Display name for Custom widget")
        }
    }

    /// SF Symbol icon for the widget.
    public var icon: Image {
        switch self {
        case .kpi: return Image(systemName: "chart.bar.fill")
        case .topClients: return Image(systemName: "person.3.fill")
        case .serviceTrends: return Image(systemName: "chart.line.uptrend.xyaxis")
        case .revenueGoal: return Image(systemName: "target")
        case .appointmentsHeatmap: return Image(systemName: "square.grid.3x3.fill")
        case .expenseBreakdown: return Image(systemName: "chart.pie.fill")
        case .retention: return Image(systemName: "arrow.triangle.2.circlepath")
        case .custom: return Image(systemName: "star")
        }
    }

    // MARK: - Audit/Event Logging

    /// Record an audit event for widget usage.
    /// - Parameters:
    ///   - widget: The `WidgetType` used.
    ///   - context: Optional context (e.g., dashboard, userID).
    ///   - userRole: Optional user role for compliance context.
    public static func auditUsage(_ widget: WidgetType, context: String? = nil, userRole: String? = nil) {
        WidgetTypeAudit.record(widget: widget, context: context, userRole: userRole)
    }

    /// Returns recent audit event summaries (up to 20).
    public static func recentAuditSummaries(limit: Int = 20) -> [String] {
        WidgetTypeAudit.recentEvents(limit: limit)
    }

    /// Returns recent audit events as JSON (up to 20).
    public static func recentAuditJSON(limit: Int = 20) -> String? {
        WidgetTypeAudit.exportRecentJSON(limit: limit)
    }

    /// Returns the last audit event as JSON.
    public static var lastAuditJSON: String? {
        WidgetTypeAudit.exportLastJSON()
    }
}

/// Audit event structure for WidgetType usage.
fileprivate struct WidgetTypeAuditEvent: Codable {
    let timestamp: Date
    let widget: String
    let context: String?
    let userRole: String?
    /// Human-readable event summary.
    var summary: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        let role = userRole != nil ? "[\(userRole!)] " : ""
        return "[Widget] \(role)\(widget) \(context ?? "") at \(dateStr)"
    }
}
/// Audit/event logger for WidgetType.
fileprivate final class WidgetTypeAudit {
    static nonisolated(unsafe) private(set) var log: [WidgetTypeAuditEvent] = []
    /// Record a new audit event.
    static func record(widget: WidgetType, context: String? = nil, userRole: String? = nil) {
        let event = WidgetTypeAuditEvent(timestamp: Date(), widget: widget.displayName, context: context, userRole: userRole)
        log.append(event)
        if log.count > 50 { log.removeFirst() }
    }
    /// Export the last audit event as JSON.
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    /// Export up to `limit` recent audit events as JSON.
    static func exportRecentJSON(limit: Int = 20) -> String? {
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        let events = Array(log.suffix(limit))
        return (try? encoder.encode(events)).flatMap { String(data: $0, encoding: .utf8) }
    }
    /// Return up to `limit` recent event summaries.
    static func recentEvents(limit: Int = 20) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}

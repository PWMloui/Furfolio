//
//  enums.swift
//  Furfolio
//
//  Enhanced 2025: Enterprise-Grade Core Enums with Audit Logging
//

import Foundation
import SwiftUI

// MARK: - ServiceType

enum ServiceType: String, Codable, CaseIterable, Identifiable {
    case fullGroom
    case basicBath
    case nailTrim
    case teethCleaning
    case deShedding
    case earCleaning
    case fleaTreatment
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fullGroom: return "Full Groom"
        case .basicBath: return "Basic Bath"
        case .nailTrim: return "Nail Trim"
        case .teethCleaning: return "Teeth Cleaning"
        case .deShedding: return "De-Shedding"
        case .earCleaning: return "Ear Cleaning"
        case .fleaTreatment: return "Flea Treatment"
        case .custom: return "Custom"
        }
    }

    var icon: Image {
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

    var durationEstimate: Int {
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

    var suggestedPrice: Double {
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

    var category: String {
        switch self {
        case .fullGroom, .deShedding: return "Grooming"
        case .basicBath, .fleaTreatment: return "Bath & Treatment"
        case .nailTrim, .earCleaning, .teethCleaning: return "Care"
        case .custom: return "Custom"
        }
    }

    // Audit
    static func auditUsage(_ service: ServiceType, context: String? = nil) {
        ServiceTypeAudit.record(service: service, context: context)
    }
    static var recentAuditSummaries: [String] {
        ServiceTypeAudit.recentEvents(limit: 10)
    }
    static var lastAuditJSON: String? {
        ServiceTypeAudit.exportLastJSON()
    }
}

// Audit/Event Logging for ServiceType
fileprivate struct ServiceTypeAuditEvent: Codable {
    let timestamp: Date
    let service: String
    let context: String?
    var summary: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[Use] \(service) \(context ?? "") at \(dateStr)"
    }
}
fileprivate final class ServiceTypeAudit {
    static nonisolated(unsafe) private(set) var log: [ServiceTypeAuditEvent] = []
    static func record(service: ServiceType, context: String? = nil) {
        let event = ServiceTypeAuditEvent(timestamp: Date(), service: service.displayName, context: context)
        log.append(event)
        if log.count > 50 { log.removeFirst() }
    }
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    static func recentEvents(limit: Int = 10) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}

// MARK: - AppointmentStatus

enum AppointmentStatus: String, Codable, CaseIterable, Identifiable {
    case scheduled
    case completed
    case cancelled
    case noShow
    case rescheduled

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .scheduled: return "Scheduled"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        case .noShow: return "No Show"
        case .rescheduled: return "Rescheduled"
        }
    }

    var icon: Image {
        Image(systemName: iconName)
    }
    var iconName: String {
        switch self {
        case .scheduled: return "calendar"
        case .completed: return "checkmark.circle"
        case .cancelled: return "xmark.circle"
        case .noShow: return "exclamationmark.triangle"
        case .rescheduled: return "arrow.uturn.right"
        }
    }

    var color: Color {
        switch self {
        case .scheduled: return .accentColor
        case .completed: return .green
        case .cancelled: return .red
        case .noShow: return .orange
        case .rescheduled: return .blue
        }
    }

    var userDescription: String {
        switch self {
        case .scheduled: return "The appointment is scheduled and upcoming."
        case .completed: return "The appointment was successfully completed."
        case .cancelled: return "The appointment was cancelled by the client or staff."
        case .noShow: return "The client did not attend the appointment."
        case .rescheduled: return "The appointment was rescheduled to a new time."
        }
    }

    // Audit
    static func auditUsage(_ status: AppointmentStatus, context: String? = nil) {
        AppointmentStatusAudit.record(status: status, context: context)
    }
    static var recentAuditSummaries: [String] {
        AppointmentStatusAudit.recentEvents(limit: 10)
    }
    static var lastAuditJSON: String? {
        AppointmentStatusAudit.exportLastJSON()
    }
}

// Audit/Event Logging for AppointmentStatus
fileprivate struct AppointmentStatusAuditEvent: Codable {
    let timestamp: Date
    let status: String
    let context: String?
    var summary: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[Status] \(status) \(context ?? "") at \(dateStr)"
    }
}
fileprivate final class AppointmentStatusAudit {
    static nonisolated(unsafe) private(set) var log: [AppointmentStatusAuditEvent] = []
    static func record(status: AppointmentStatus, context: String? = nil) {
        let event = AppointmentStatusAuditEvent(timestamp: Date(), status: status.displayName, context: context)
        log.append(event)
        if log.count > 50 { log.removeFirst() }
    }
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    static func recentEvents(limit: Int = 10) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}

// MARK: - WidgetType

enum WidgetType: String, Codable, CaseIterable, Identifiable {
    case kpi
    case topClients
    case serviceTrends
    case revenueGoal
    case appointmentsHeatmap
    case expenseBreakdown
    case retention
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .kpi: return "KPI"
        case .topClients: return "Top Clients"
        case .serviceTrends: return "Service Trends"
        case .revenueGoal: return "Revenue Goal"
        case .appointmentsHeatmap: return "Appointments Heatmap"
        case .expenseBreakdown: return "Expense Breakdown"
        case .retention: return "Retention"
        case .custom: return "Custom"
        }
    }

    var icon: Image {
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

    // Audit
    static func auditUsage(_ widget: WidgetType, context: String? = nil) {
        WidgetTypeAudit.record(widget: widget, context: context)
    }
    static var recentAuditSummaries: [String] {
        WidgetTypeAudit.recentEvents(limit: 10)
    }
    static var lastAuditJSON: String? {
        WidgetTypeAudit.exportLastJSON()
    }
}

// Audit/Event Logging for WidgetType
fileprivate struct WidgetTypeAuditEvent: Codable {
    let timestamp: Date
    let widget: String
    let context: String?
    var summary: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[Widget] \(widget) \(context ?? "") at \(dateStr)"
    }
}
fileprivate final class WidgetTypeAudit {
    static nonisolated(unsafe) private(set) var log: [WidgetTypeAuditEvent] = []
    static func record(widget: WidgetType, context: String? = nil) {
        let event = WidgetTypeAuditEvent(timestamp: Date(), widget: widget.displayName, context: context)
        log.append(event)
        if log.count > 50 { log.removeFirst() }
    }
    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }
    static func recentEvents(limit: Int = 10) -> [String] {
        log.suffix(limit).map { $0.summary }
    }
}

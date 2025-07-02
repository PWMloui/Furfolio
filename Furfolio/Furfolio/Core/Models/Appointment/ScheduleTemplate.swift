//
//  ScheduleTemplate.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import Foundation

// MARK: - Audit Context (set at login/session)
public struct ScheduleTemplateAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "ScheduleTemplate"
}

public struct ScheduleTemplateAuditEvent: Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let operation: String
    public let templateID: UUID
    public let templateName: String
    public let services: [String]
    public let status: String
    public let error: String?
    public let role: String?
    public let staffID: String?
    public let context: String?
    public let escalate: Bool

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        operation: String,
        templateID: UUID,
        templateName: String,
        services: [String],
        status: String,
        error: String?,
        role: String?,
        staffID: String?,
        context: String?,
        escalate: Bool
    ) {
        self.id = id
        self.timestamp = timestamp
        self.operation = operation
        self.templateID = templateID
        self.templateName = templateName
        self.services = services
        self.status = status
        self.error = error
        self.role = role
        self.staffID = staffID
        self.context = context
        self.escalate = escalate
    }

    public var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        let base = "[\(dateStr)] ScheduleTemplate \(operation) [\(status)]"
        let details = [
            "TemplateID: \(templateID)",
            "Name: \(templateName)",
            !services.isEmpty ? "Services: \(services.joined(separator: \", \"))" : nil,
            role.map { "Role: \($0)" },
            staffID.map { "StaffID: \($0)" },
            context.map { "Context: \($0)" },
            escalate ? "Escalate: YES" : nil,
            error != nil ? "Error: \(error!)" : nil
        ].compactMap { $0 }
        return ([base] + details).joined(separator: " | ")
    }
}

public final class ScheduleTemplateAuditLogger {
    private static let queue = DispatchQueue(label: "furfolio.scheduletemplate.audit.logger")
    private static var log: [ScheduleTemplateAuditEvent] = []
    private static let maxLogSize = 200

    public static func record(
        operation: String,
        templateID: UUID,
        templateName: String,
        services: [String],
        status: String,
        error: String? = nil
    ) {
        let escalate = operation.lowercased().contains("danger") || operation.lowercased().contains("critical") || operation.lowercased().contains("delete")
            || (error?.lowercased().contains("danger") ?? false)
        let event = ScheduleTemplateAuditEvent(
            timestamp: Date(),
            operation: operation,
            templateID: templateID,
            templateName: templateName,
            services: services,
            status: status,
            error: error,
            role: ScheduleTemplateAuditContext.role,
            staffID: ScheduleTemplateAuditContext.staffID,
            context: ScheduleTemplateAuditContext.context,
            escalate: escalate
        )
        queue.async {
            log.append(event)
            if log.count > maxLogSize {
                log.removeFirst(log.count - maxLogSize)
            }
        }
    }

    public static func allEvents(completion: @escaping ([ScheduleTemplateAuditEvent]) -> Void) {
        queue.async { completion(log) }
    }
    public static func exportLogJSON(completion: @escaping (String?) -> Void) {
        queue.async {
            let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
            let json = (try? encoder.encode(log)).flatMap { String(data: $0, encoding: .utf8) }
            completion(json)
        }
    }
}

/// A model representing a schedule template for services in the Furfolio app.
struct ScheduleTemplate: Identifiable, Codable {
    /// Unique identifier for the schedule template.
    let id: UUID
    
    /// The name of the schedule template.
    var name: String
    
    /// An optional description providing more details about the schedule template.
    var description: String?
    
    /// An array of service identifiers or names associated with this template.
    var services: [String]
    
    /// The total duration of the schedule template in minutes.
    var duration: Int
    
    /// The price associated with the schedule template.
    var price: Double
    
    /// The date and time when the schedule template was created.
    let createdAt: Date
    
    /// The date and time when the schedule template was last updated.
    var updatedAt: Date
    
    /// A user-friendly formatted string representing the duration (e.g., "1h 30m").
    var formattedDuration: String {
        let hours = duration / 60
        let minutes = duration % 60
        
        switch (hours, minutes) {
        case (0, let m):
            return String(format: NSLocalizedString("%dm", comment: "Duration in minutes"), m)
        case (let h, 0):
            return String(format: NSLocalizedString("%dh", comment: "Duration in hours"), h)
        default:
            return String(format: NSLocalizedString("%dh %dm", comment: "Duration in hours and minutes"), hours, minutes)
        }
    }
    
    /// Initializes a new instance of `ScheduleTemplate`.
    /// - Parameters:
    ///   - id: Unique identifier for the schedule template. Defaults to a new UUID.
    ///   - name: Name of the schedule template.
    ///   - description: Optional description of the schedule template.
    ///   - services: Array of service identifiers or names.
    ///   - duration: Total duration in minutes.
    ///   - price: Price for the schedule template.
    ///   - createdAt: Creation date. Defaults to current date.
    ///   - updatedAt: Last updated date. Defaults to current date.
    init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        services: [String],
        duration: Int,
        price: Double,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.services = services
        self.duration = duration
        self.price = price
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

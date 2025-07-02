//
//  BookingRequest.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import Foundation

// MARK: - Audit Context (set at login/session)
public struct BookingRequestAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "BookingRequest"
}

public struct BookingRequestAuditEvent: Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let operation: String
    public let bookingID: UUID
    public let ownerID: UUID?
    public let dogID: UUID?
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
        bookingID: UUID,
        ownerID: UUID?,
        dogID: UUID?,
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
        self.bookingID = bookingID
        self.ownerID = ownerID
        self.dogID = dogID
        self.status = status
        self.error = error
        self.role = role
        self.staffID = staffID
        self.context = context
        self.escalate = escalate
    }

    public var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        let base = "[\(dateStr)] Booking \(operation) [\(status)]"
        let details = [
            "BookingID: \(bookingID)",
            ownerID != nil ? "OwnerID: \(ownerID!)" : nil,
            dogID != nil ? "DogID: \(dogID!)" : nil,
            role.map { "Role: \($0)" },
            staffID.map { "StaffID: \($0)" },
            context.map { "Context: \($0)" },
            escalate ? "Escalate: YES" : nil,
            error != nil ? "Error: \(error!)" : nil
        ].compactMap { $0 }
        return ([base] + details).joined(separator: " | ")
    }
}

public final class BookingRequestAuditLogger {
    private static let queue = DispatchQueue(label: "furfolio.bookingrequest.audit.logger")
    private static var log: [BookingRequestAuditEvent] = []
    private static let maxLogSize = 200

    public static func record(
        operation: String,
        bookingID: UUID,
        ownerID: UUID?,
        dogID: UUID?,
        status: String,
        error: String? = nil
    ) {
        let escalate = operation.lowercased().contains("danger") || operation.lowercased().contains("critical") || operation.lowercased().contains("delete")
            || (error?.lowercased().contains("danger") ?? false)
        let event = BookingRequestAuditEvent(
            timestamp: Date(),
            operation: operation,
            bookingID: bookingID,
            ownerID: ownerID,
            dogID: dogID,
            status: status,
            error: error,
            role: BookingRequestAuditContext.role,
            staffID: BookingRequestAuditContext.staffID,
            context: BookingRequestAuditContext.context,
            escalate: escalate
        )
        queue.async {
            log.append(event)
            if log.count > maxLogSize {
                log.removeFirst(log.count - maxLogSize)
            }
        }
    }

    public static func allEvents(completion: @escaping ([BookingRequestAuditEvent]) -> Void) {
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

/// Represents a booking request for a grooming appointment in Furfolio.
struct BookingRequest: Identifiable, Codable {
    /// Unique identifier for the booking.
    let id: UUID
    
    /// Reference to the dog owner's ID.
    var ownerID: UUID?
    
    /// Reference to the dog's ID.
    var dogID: UUID?
    
    /// The date and time of the appointment.
    var appointmentDate: Date
    
    /// The type of service requested.
    var serviceType: ServiceType
    
    /// Optional notes for the booking.
    var notes: String?
    
    /// Timestamp for when the booking was created.
    let createdAt: Date
    
    /// Timestamp for when the booking was last updated.
    var updatedAt: Date
    
    /// Current status of the booking.
    var status: Status
    
    /// Enum representing possible types of grooming services.
    enum ServiceType: String, Codable, CaseIterable {
        /// Basic grooming package.
        case basic = "Basic"
        /// Full grooming package.
        case fullPackage = "Full Package"
        /// Nail trim service.
        case nailTrim = "Nail Trim"
        /// Bath only service.
        case bathOnly = "Bath Only"
        /// Other or custom service.
        case other = "Other"
        
        /// Localized string representation of the service type.
        var localizedDescription: String {
            switch self {
            case .basic: return NSLocalizedString("Basic", comment: "Basic grooming service")
            case .fullPackage: return NSLocalizedString("Full Package", comment: "Full grooming package")
            case .nailTrim: return NSLocalizedString("Nail Trim", comment: "Nail trimming service")
            case .bathOnly: return NSLocalizedString("Bath Only", comment: "Bath only service")
            case .other: return NSLocalizedString("Other", comment: "Other or custom service")
            }
        }
    }
    
    /// Enum representing the status of a booking.
    enum Status: String, Codable, CaseIterable {
        /// Booking is pending confirmation.
        case pending = "Pending"
        /// Booking is confirmed.
        case confirmed = "Confirmed"
        /// Booking has been cancelled.
        case cancelled = "Cancelled"
        /// Booking is completed.
        case completed = "Completed"
        
        /// Localized string representation of the booking status.
        var localizedDescription: String {
            switch self {
            case .pending: return NSLocalizedString("Pending", comment: "Booking is pending")
            case .confirmed: return NSLocalizedString("Confirmed", comment: "Booking is confirmed")
            case .cancelled: return NSLocalizedString("Cancelled", comment: "Booking is cancelled")
            case .completed: return NSLocalizedString("Completed", comment: "Booking is completed")
            }
        }
    }
    
    /// Returns a formatted string for the appointment date and time.
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: appointmentDate)
    }
    
    /// Initializes a new booking request with required and optional parameters.
    /// - Parameters:
    ///   - id: The booking ID (default: new UUID).
    ///   - ownerID: The owner's ID (optional).
    ///   - dogID: The dog's ID (optional).
    ///   - appointmentDate: The appointment date and time.
    ///   - serviceType: The type of service.
    ///   - notes: Optional notes.
    ///   - createdAt: Creation timestamp (default: now).
    ///   - updatedAt: Last updated timestamp (default: now).
    ///   - status: The booking status (default: pending).
    init(
        id: UUID = UUID(),
        ownerID: UUID? = nil,
        dogID: UUID? = nil,
        appointmentDate: Date,
        serviceType: ServiceType,
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        status: Status = .pending
    ) {
        self.id = id
        self.ownerID = ownerID
        self.dogID = dogID
        self.appointmentDate = appointmentDate
        self.serviceType = serviceType
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.status = status
    }
}

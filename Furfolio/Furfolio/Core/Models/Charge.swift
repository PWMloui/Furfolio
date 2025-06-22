//
//  Charge.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import Foundation
import SwiftData

// MARK: - Charge (Unified, Modular, Tokenized, Auditable Charge Model)

/// Represents a modular, auditable, and tokenized business charge entity associated with a dog owner.
/// This model supports comprehensive audit trails, analytics reporting, business logic workflows,
/// and UI integration including badges, status indicators, and color coding. It is designed to be
/// extensible, maintainable, and suitable for complex business environments where traceability and
/// analytics are critical.
/// 
/// The Charge model encapsulates not only financial data but also metadata essential for business
/// operations, audit compliance, and user interface enhancements.
@Model
final class Charge: Identifiable, ObservableObject {
    
    // MARK: - Identification
    
    /// Unique identifier for the charge.
    /// Used for audit trail correlation and entity tracking across systems.
    @Attribute(.unique)
    private(set) var id: UUID
    
    // MARK: - Core Properties
    
    /// The date when the charge was incurred.
    /// Important for analytics timelines, reporting periods, and business workflows.
    @Published
    var date: Date
    
    /// The monetary amount of the charge.
    /// Central to financial analytics, billing, and reporting.
    @Published
    var amount: Double
    
    /// The type/category of the charge or service rendered.
    /// Drives business logic, UI badges, and analytics segmentation.
    @Published
    var type: ChargeType
    
    /// Optional notes providing additional context or instructions.
    /// Useful for audit details, customer service, and internal workflows.
    @Published
    var notes: String?
    
    // MARK: - Relationships
    
    /// The dog owner associated with this charge.
    /// Enables relational queries, owner-specific analytics, and business workflows.
    @Relationship(deleteRule: .nullify, inverse: \DogOwner.charges)
    var owner: DogOwner?
    
    /// The dog associated with this charge.
    /// Supports pet-specific analytics, service histories, and UI display.
    @Relationship(deleteRule: .nullify, inverse: \Dog.charges)
    var dog: Dog?
    
    /// The appointment associated with this charge, if any.
    /// Links charges to scheduled services, facilitating workflow tracking and audit.
    @Relationship(deleteRule: .nullify, inverse: \Appointment.charges)
    var appointment: Appointment?
    
    // MARK: - Analytics & Reporting
    
    /// Indicates whether the charge has been marked as paid.
    /// Used for business analytics, financial reporting, and workflow status indicators.
    @Published
    var isPaid: Bool
    
    /// Timestamp of the last modification for audit and synchronization purposes.
    /// Critical for audit logs, conflict resolution, and compliance tracking.
    @Published
    private(set) var lastModified: Date
    
    /// Identifier of the user who created this charge.
    /// Supports audit trails, accountability, and user-specific analytics.
    @Published
    private(set) var createdBy: String?
    
    // MARK: - Computed Properties
    
    /// A concise, display-friendly summary of the charge.
    /// Combines type, amount, and date for UI display, reports, and notifications.
    var summary: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        let amountString = formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
        return "\(type.displayName) - \(amountString) on \(date.formatted(date: .abbreviated, time: .omitted))"
    }
    
    // MARK: - Initialization
    
    /// Initializes a new Charge instance.
    /// - Parameters:
    ///   - id: Unique identifier for the charge, used for audit and entity tracking.
    ///   - date: Date the charge was incurred, relevant for analytics and workflows.
    ///   - amount: Monetary amount of the charge, central to business reporting.
    ///   - type: Type of charge/service, driving UI badges and business logic.
    ///   - notes: Optional notes for audit and internal communication.
    ///   - owner: Associated dog owner for relational integrity and analytics.
    ///   - dog: Associated dog for service history and reporting.
    ///   - appointment: Linked appointment for workflow and audit correlation.
    ///   - isPaid: Payment status used in financial analytics and workflow states.
    ///   - createdBy: User identifier for audit and accountability.
    ///   - lastModified: Timestamp for audit and synchronization.
    init(
        id: UUID = UUID(),
        date: Date,
        amount: Double,
        type: ChargeType,
        notes: String? = nil,
        owner: DogOwner? = nil,
        dog: Dog? = nil,
        appointment: Appointment? = nil,
        isPaid: Bool = false,
        createdBy: String? = nil,
        lastModified: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.amount = amount
        self.type = type
        self.notes = notes
        self.owner = owner
        self.dog = dog
        self.appointment = appointment
        self.isPaid = isPaid
        self.createdBy = createdBy
        self.lastModified = lastModified
        
        auditLogCreation()
    }
    
    // MARK: - Audit Logging Stubs
    
    /// Logs the creation event of this charge for audit and compliance.
    /// Intended to integrate with centralized audit/event logging systems.
    /// Also supports analytics triggers and business owner workflow notifications.
    private func auditLogCreation() {
        // TODO: Implement audit logging for charge creation.
        // Example: Logger.log("Charge created: \(id.uuidString) by \(createdBy ?? "unknown") at \(Date())")
    }
    
    /// Logs updates to this charge, updating the lastModified timestamp.
    /// Supports audit trail continuity, analytics event tracking, and workflow state changes.
    func auditLogUpdate() {
        // TODO: Implement audit logging for charge updates.
        // Example: Logger.log("Charge updated: \(id.uuidString) at \(Date())")
        lastModified = Date()
    }
    
    // MARK: - Future Extensions
    
    // Placeholder for tags, batch operations, and other modular extensions.
    // var tags: [Tag] = []
}

// MARK: - ChargeType Enum

/// Enum representing the type of charge or service rendered.
/// Designed as a design token to integrate seamlessly with business logic,
/// UI badge components, and analytics/reporting systems.
/// This tokenization enables consistent use of service types across the app,
/// facilitating maintainability and extensibility.
///
/// Each case drives UI representation (badges, icons), analytics segmentation,
/// and business workflows.
enum ChargeType: String, Codable, CaseIterable, Identifiable {
    case fullGroom
    case basicBath
    case nailTrim
    case custom
    case product
    
    // Uncomment and add new service types here as needed:
    // case dentalCleaning
    // case trainingSession
    // case overnightBoarding
    
    var id: String { rawValue }
    
    /// User-friendly display name for the charge type.
    /// Used in UI labels, badges, and analytics reports to provide clear context.
    var displayName: String {
        switch self {
        case .fullGroom: return "Full Groom"
        case .basicBath: return "Basic Bath"
        case .nailTrim: return "Nail Trim"
        case .custom: return "Custom Service"
        case .product: return "Product"
        }
    }
    
    /// Icon name representing the charge type for UI display.
    /// Supports badge visuals, status indicators, and enhances user recognition.
    /// Also used in analytics dashboards for quick visual differentiation.
    var icon: String {
        switch self {
        case .fullGroom: return "scissors"
        case .basicBath: return "drop"
        case .nailTrim: return "pawprint"
        case .custom: return "star"
        case .product: return "cart"
        }
    }
}

// MARK: - SwiftUI Preview Stub

#if DEBUG
import SwiftUI

@available(iOS 15.0, *)
struct Charge_Previews: PreviewProvider {
    /// Provides a tokenized, business-logic-driven preview of the Charge summary.
    /// This demo showcases UI integration of business tokens (charge type),
    /// analytics-relevant display formatting, and audit-related flags (isPaid).
    static var previews: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Charge Summary:")
                .font(.headline)
            Text(Charge(
                date: Date(),
                amount: 75.0,
                type: .fullGroom,
                notes: "Includes haircut and bath",
                isPaid: true,
                createdBy: "admin"
            ).summary)
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif

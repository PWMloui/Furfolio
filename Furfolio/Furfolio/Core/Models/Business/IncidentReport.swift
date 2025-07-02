//
//  IncidentReport.swift
//  Furfolio
//
//  Created by mac on 6/30/25.
//

import SwiftUI
import SwiftData

/// Represents an incident report logged by staff during a grooming session.
@Model
public struct IncidentReport: Identifiable {
    /// Unique identifier for the incident.
    @Attribute(.unique) var id: UUID = UUID()
    
    /// Timestamp when the incident was reported.
    var date: Date = Date()
    
    /// Role of the staff member who reported the incident (e.g., groomer, receptionist, bather).
    var reporterRole: ReporterRole
    
    /// Human-readable name of the reporter.
    var reporterName: String
    
    /// Category of the incident (e.g., clipperInjury, allergicReaction, other).
    var incidentType: IncidentType
    
    /// Detailed description of what occurred.
    var notes: String
    
    /// Optional image data documenting the incident.
    var imageData: Data?
    
    /// Indicates whether the incident has been resolved.
    var isResolved: Bool = false
    
    // MARK: - Transient Computed Properties
    
    @Attribute(.transient)
    /// Formats the report date for display.
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    @Attribute(.transient)
    /// Returns a human-readable status label.
    var statusDescription: String {
        isResolved ? NSLocalizedString("Resolved", comment: "") : NSLocalizedString("Pending", comment: "")
    }
}

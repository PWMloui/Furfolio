//
//  FollowUpTemplate.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import Foundation
import SwiftUI
import SwiftData

/// A model representing a follow-up message template.
/// Conforms to `Identifiable` and `Codable` for easy identification and data encoding/decoding.
@Model
public struct FollowUpTemplate: Identifiable {
    
    @Attribute(.unique) var id: UUID
    
    /// The name of the follow-up template.
    var name: String
    
    /// The content of the follow-up message.
    var message: String
    
    /// The date when the template was created.
    let createdAt: Date
    
    /// The date when the template was last updated.
    var updatedAt: Date
    
    /// A flag indicating whether the template is active or disabled.
    var isActive: Bool
    
    // MARK: - Computed Properties
    
    @Attribute(.transient)
    /// Returns the creation date formatted as a localized string.
    var formattedCreatedAt: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale.current
        return String(format: NSLocalizedString("Created on %@", comment: "Creation date label"), formatter.string(from: createdAt))
    }
    
    @Attribute(.transient)
    /// Returns the last updated date formatted as a localized string.
    var formattedUpdatedAt: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale.current
        return String(format: NSLocalizedString("Updated on %@", comment: "Update date label"), formatter.string(from: updatedAt))
    }
    
    // MARK: - Initializers
    
    /// Initializes a new follow-up template.
    /// - Parameters:
    ///   - id: Unique identifier, defaults to a new UUID.
    ///   - name: Name of the template.
    ///   - message: Follow-up message content.
    ///   - createdAt: Creation date, defaults to current date.
    ///   - updatedAt: Last updated date, defaults to current date.
    ///   - isActive: Whether the template is active, defaults to true.
    init(
        id: UUID = UUID(),
        name: String,
        message: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.message = message
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isActive = isActive
    }
    
    // MARK: - Methods
    
    /// Generates a preview message by replacing template variables with provided values.
    /// Supported variables: `{customerName}`, `{appointmentDate}`
    /// - Parameters:
    ///   - customerName: The name of the customer.
    ///   - appointmentDate: The date of the appointment.
    /// - Returns: A string with template variables replaced by actual values.
    func previewMessage(customerName: String = "Customer", appointmentDate: Date = Date()) -> String {
        var preview = message
        preview = preview.replacingOccurrences(of: "{customerName}", with: customerName)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        dateFormatter.locale = Locale.current
        let formattedDate = dateFormatter.string(from: appointmentDate)
        
        preview = preview.replacingOccurrences(of: "{appointmentDate}", with: formattedDate)
        
        return preview
    }
}

// MARK: - SwiftUI Preview

#if DEBUG
import SwiftUI

struct FollowUpTemplate_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack(alignment: .leading, spacing: 10) {
                Text("Template Name: \(sampleTemplate.name)")
                    .font(.headline)
                Text(sampleTemplate.formattedCreatedAt)
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(sampleTemplate.formattedUpdatedAt)
                    .font(.caption)
                    .foregroundColor(.gray)
                Text("Active: \(sampleTemplate.isActive ? NSLocalizedString("Yes", comment: "Active status") : NSLocalizedString("No", comment: "Inactive status"))")
                    .font(.subheadline)
                Divider()
                Text("Preview Message:")
                    .font(.headline)
                Text(sampleTemplate.previewMessage(customerName: "Alex", appointmentDate: Date().addingTimeInterval(86400)))
                    .italic()
                    .padding(.top, 5)
            }
            .padding()
            .previewDisplayName("Sample FollowUpTemplate")
        }
    }
    
    /// A sample follow-up template for preview purposes.
    static var sampleTemplate: FollowUpTemplate {
        FollowUpTemplate(
            name: "Post Appointment Reminder",
            message: "Hello {customerName},\n\nThank you for your visit on {appointmentDate}. We hope to see you again soon!",
            createdAt: Date(timeIntervalSinceNow: -86400 * 10),
            updatedAt: Date(timeIntervalSinceNow: -86400 * 2),
            isActive: true
        )
    }
}
#endif

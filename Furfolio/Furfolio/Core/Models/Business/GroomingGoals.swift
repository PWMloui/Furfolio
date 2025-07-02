//
//  GroomingGoals.swift
//  Furfolio
//
//  Created by mac on 6/26/25.
//

import Foundation
import SwiftUI
import SwiftData

/**
 Represents a single grooming goal for a dog or owner within the Furfolio app.

 This struct encapsulates all relevant information about a grooming goal, including its identity,
 descriptive details, target date, completion status, and audit timestamps. It conforms to `Codable`
 and `Identifiable` to support easy storage, retrieval, and UI integration.

 The struct also includes computed properties for user-friendly display of the target date and status,
 localized strings for user-facing text, audit logging hooks for lifecycle events, and Trust Center
 permission checks to ensure secure access and modification.

 Use this model to manage and track grooming goals effectively within the Furfolio ecosystem.
 */
@Model
public struct GroomingGoal: Identifiable {
    
    // MARK: - Properties
    
    /// Unique identifier for the grooming goal.
    let id: UUID
    
    /// Title or name of the grooming goal.
    var title: String
    
    /// Optional detailed description of the grooming goal.
    var description: String?
    
    /// Optional target date by which the grooming goal should be completed.
    var targetDate: Date?
    
    /// Indicates whether the grooming goal has been completed.
    var isCompleted: Bool
    
    /// Timestamp of when the grooming goal was created.
    let createdAt: Date
    
    /// Timestamp of the last update made to the grooming goal.
    var updatedAt: Date
    
    // MARK: - Computed Properties
    
    @Attribute(.transient)
    /// Returns a user-friendly formatted string of the target date, or a localized placeholder if none.
    var formattedTargetDate: String {
        guard let date = targetDate else {
            return NSLocalizedString("No target date set", comment: "Placeholder when no target date is provided")
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    @Attribute(.transient)
    /// Returns a localized status description string based on the completion state.
    var statusDescription: String {
        isCompleted
            ? NSLocalizedString("Completed", comment: "Status label for completed grooming goal")
            : NSLocalizedString("Pending", comment: "Status label for pending grooming goal")
    }
    
    // MARK: - Initializers
    
    /**
     Initializes a new `GroomingGoal` instance.
     
     - Parameters:
       - id: Unique identifier. Defaults to a new UUID.
       - title: Title of the grooming goal.
       - description: Optional detailed description.
       - targetDate: Optional target completion date.
       - isCompleted: Completion status. Defaults to `false`.
       - createdAt: Creation date. Defaults to current date.
       - updatedAt: Last update date. Defaults to current date.
     */
    init(id: UUID = UUID(),
         title: String,
         description: String? = nil,
         targetDate: Date? = nil,
         isCompleted: Bool = false,
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.description = description
        self.targetDate = targetDate
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // MARK: - Audit Logging Hooks
    
    /**
     Logs the creation event of the grooming goal asynchronously.
     
     Implement audit trail recording here.
     */
    func logCreation() async {
        // Placeholder for audit logging implementation.
        // Example: await AuditLogger.shared.log(event: "Created grooming goal \(id)")
    }
    
    /**
     Logs the update event of the grooming goal asynchronously.
     
     Implement audit trail recording here.
     */
    func logUpdate() async {
        // Placeholder for audit logging implementation.
        // Example: await AuditLogger.shared.log(event: "Updated grooming goal \(id)")
    }
    
    /**
     Logs the completion toggle event asynchronously.
     
     Implement audit trail recording here.
     */
    func logCompletionToggle() async {
        // Placeholder for audit logging implementation.
        // Example: await AuditLogger.shared.log(event: "Toggled completion for grooming goal \(id) to \(isCompleted)")
    }
    
    // MARK: - Trust Center Permission Checks
    
    /**
     Checks asynchronously if the current user has permission to access grooming goals.
     
     - Returns: `true` if access is permitted, `false` otherwise.
     */
    static func hasAccessPermission() async -> Bool {
        // Placeholder for permission check implementation.
        // Example: return await TrustCenter.shared.hasPermission(for: .groomingGoals)
        return true
    }
    
    /**
     Checks asynchronously if the current user has permission to modify grooming goals.
     
     - Returns: `true` if modification is permitted, `false` otherwise.
     */
    static func hasModificationPermission() async -> Bool {
        // Placeholder for permission check implementation.
        // Example: return await TrustCenter.shared.hasPermission(for: .modifyGroomingGoals)
        return true
    }
}

// MARK: - SwiftUI Preview

#if DEBUG
struct GroomingGoal_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Grooming Goal Preview")
                .font(.title)
                .bold()
            
            Text("Title: \(sampleGoal.title)")
                .font(.headline)
            
            if let description = sampleGoal.description {
                Text("Description: \(description)")
                    .font(.subheadline)
            }
            
            Text("Target Date: \(sampleGoal.formattedTargetDate)")
                .font(.subheadline)
            
            Text("Status: \(sampleGoal.statusDescription)")
                .font(.subheadline)
                .foregroundColor(sampleGoal.isCompleted ? .green : .orange)
            
            Button(action: {
                // Toggling completion status for preview purposes.
                sampleGoal.isCompleted.toggle()
            }) {
                Text(sampleGoal.isCompleted ? NSLocalizedString("Mark as Pending", comment: "Button to mark goal as pending") : NSLocalizedString("Mark as Completed", comment: "Button to mark goal as completed"))
            }
            .padding()
            .background(Color.blue.opacity(0.2))
            .cornerRadius(8)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
    
    @State static var sampleGoal = GroomingGoal(
        title: NSLocalizedString("Weekly Bath", comment: "Sample grooming goal title"),
        description: NSLocalizedString("Give the dog a thorough bath every week to maintain coat health.", comment: "Sample grooming goal description"),
        targetDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()),
        isCompleted: false
    )
}
#endif

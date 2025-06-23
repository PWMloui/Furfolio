//
//  CustomerRetentionAnalyzer.swift
//  Furfolio
//
//  Created by Your Name on 6/22/25.
//
//  This file centralizes all business logic for analyzing customer retention.
//  It provides a single source of truth for determining whether a client is
//  new, active, at risk, or inactive, based on their appointment history.
//  This engine is used by the RetentionAlertEngine, MarketingEngine, and various
//  UI components to ensure consistent analysis.
//

import Foundation

/// A data model to hold the result of a retention analysis, combining the tag with relevant metadata.
public struct RetentionResult {
    public let tag: RetentionTag
    public let daysSinceLastVisit: Int?
}

/// Errors that can be thrown by the CustomerRetentionAnalyzer.
public enum RetentionError: Error {
    case remoteFetchNotImplemented
}

/// A centralized engine for analyzing customer retention data.
/// It encapsulates the business rules for determining if a client is new, active, at risk, or inactive.
/// Designed as a thread-safe singleton to be used across the application.
@MainActor
public final class CustomerRetentionAnalyzer {

    // MARK: - Singleton Instance
    
    /// Shared singleton instance of the analyzer.
    public static let shared = CustomerRetentionAnalyzer()
    
    /// Private initializer to enforce the singleton pattern.
    private init() {}

    // MARK: - Constants
    
    /// Defines the thresholds (in days) for different retention statuses.
    /// These values can be adjusted to match business strategy.
    private struct Thresholds {
        static let newClientDays = 14
        static let retentionRiskDays = 60
        static let inactiveDays = 180
        static let activeDays = 30
    }
    
    /// Optional hook for logging or analytics when an analysis is performed.
    public var auditLogHook: ((String, [String: Any]?, Error?) -> Void)?

    // MARK: - Core Analysis Logic

    /// Determines the retention tag for a single dog owner based on their appointment history.
    /// This is the primary business logic function for retention status.
    /// - Parameter owner: The `DogOwner` to analyze.
    /// - Returns: The calculated `RetentionTag`.
    public func retentionTag(for owner: DogOwner) -> RetentionTag {
        // A newly added owner with no appointments is considered a new client.
        guard let lastAppointmentDate = owner.lastAppointmentDate else {
            return .newClient
        }
        
        let daysSinceLastAppointment = Calendar.current.dateComponents([.day], from: lastAppointmentDate, to: Date()).day ?? 0
        
        // Check statuses in order of precedence (inactive > risk > new > active > returning).
        if daysSinceLastAppointment > Thresholds.inactiveDays {
            return .inactive
        }
        
        if daysSinceLastAppointment > Thresholds.retentionRiskDays {
            return .retentionRisk
        }

        // A client is "new" if they only have one appointment and it was recent.
        if owner.appointments.count <= 1 && daysSinceLastAppointment <= Thresholds.newClientDays {
            return .newClient
        }
        
        // A client is "active" if they have had an appointment recently.
        if daysSinceLastAppointment <= Thresholds.activeDays {
            return .active
        }
        
        // If none of the above, they are a returning client.
        return .returning
    }

    // MARK: - Batch Analytics & Filtering
    
    /// Filters a list of owners to find those matching a specific retention tag.
    /// This is useful for the MarketingEngine to create targeted campaigns.
    /// - Parameters:
    ///   - owners: The array of `DogOwner` to filter.
    ///   - tag: The `RetentionTag` to filter by.
    /// - Returns: An array of `DogOwner`s that match the specified tag.
    public func filterOwners(in owners: [DogOwner], by tag: RetentionTag) -> [DogOwner] {
        owners.filter { retentionTag(for: $0) == tag }
    }
    
    /// Provides a statistical summary of retention across a list of owners.
    /// Ideal for populating dashboard charts and business reports.
    /// - Parameter owners: The array of `DogOwner` to analyze.
    /// - Returns: A dictionary mapping each `RetentionTag` to the number of owners in that category.
    public func retentionStats(for owners: [DogOwner]) -> [RetentionTag: Int] {
        var stats: [RetentionTag: Int] = [:]
        for owner in owners {
            let tag = retentionTag(for: owner)
            stats[tag, default: 0] += 1
        }
        return stats
    }
    
    /// Convenience method to get all owners who are at risk.
    public func ownersAtRisk(in owners: [DogOwner]) -> [DogOwner] {
        filterOwners(in: owners, by: .retentionRisk)
    }

    /// Convenience method to get all inactive owners.
    public func inactiveOwners(in owners: [DogOwner]) -> [DogOwner] {
        filterOwners(in: owners, by: .inactive)
    }
    
    /// Convenience method to get all new clients.
    public func newClientOwners(in owners: [DogOwner]) -> [DogOwner] {
        filterOwners(in: owners, by: .newClient)
    }

    /// Placeholder async hook for fetching remote retention data (offline/cloud hybrid).
    ///
    /// - Note: This function is intended for future hybrid/offline/cloud analytics integration.
    ///         It is not yet implemented and should be audited and localized in production.
    /// - Returns: Async result of remote retention data.
    func fetchRemoteRetentionData(for businessId: String) async throws -> [DogOwner] {
        auditLogHook?("fetchRemoteRetentionData_invoked", ["businessId": businessId], nil)
        // TODO: Implement secure, localized remote fetch logic; ensure audit logging and Trust Center permissions.
        // FIXME: This should be implemented before enabling cloud analytics in production.
        throw RetentionError.remoteFetchNotImplemented
    }
}


// MARK: - SwiftUI Preview

#if DEBUG
import SwiftUI

@available(iOS 18.0, *)
struct CustomerRetentionAnalyzer_Previews: PreviewProvider {
    static var previews: some View {
        // This preview demonstrates how the analyzer would be used.
        // In a real app, this logic would be in a ViewModel.
        let container = try! ModelContainer(for: [DogOwner.self, Appointment.self], inMemory: true)
        
        let analyzer = CustomerRetentionAnalyzer.shared

        // Create sample owners
        let newOwner = DogOwner(ownerName: "New Owner")
        newOwner.appointments = [Appointment(date: Date().addingTimeInterval(-5 * 86400), serviceType: .basicBath, owner: newOwner)]
        
        let activeOwner = DogOwner(ownerName: "Active Owner")
        activeOwner.appointments = [
            Appointment(date: Date().addingTimeInterval(-100 * 86400), serviceType: .fullGroom, owner: activeOwner),
            Appointment(date: Date().addingTimeInterval(-20 * 86400), serviceType: .fullGroom, owner: activeOwner)
        ]
        
        let riskOwner = DogOwner(ownerName: "Risk Owner")
        riskOwner.appointments = [Appointment(date: Date().addingTimeInterval(-75 * 86400), serviceType: .nailTrim, owner: riskOwner)]
        
        let inactiveOwner = DogOwner(ownerName: "Inactive Owner")
        inactiveOwner.appointments = [Appointment(date: Date().addingTimeInterval(-200 * 86400), serviceType: .fullGroom, owner: inactiveOwner)]
        
        let returningOwner = DogOwner(ownerName: "Returning Owner")
        returningOwner.appointments = [
            Appointment(date: Date().addingTimeInterval(-100 * 86400), serviceType: .fullGroom, owner: returningOwner),
            Appointment(date: Date().addingTimeInterval(-45 * 86400), serviceType: .fullGroom, owner: returningOwner)
        ]

        let allOwners = [newOwner, activeOwner, riskOwner, inactiveOwner, returningOwner]
        let stats = analyzer.retentionStats(for: allOwners)

        return VStack(alignment: .leading, spacing: 16) {
            Text("Retention Analysis Results")
                .font(AppTheme.Fonts.title)
                .padding(.bottom)

            ForEach(RetentionTag.allCases.sorted(by: { $0.sortOrder < $1.sortOrder })) { tag in
                HStack {
                    RetentionTagView(tag: tag)
                    Spacer()
                    Text("\(stats[tag] ?? 0) client(s)")
                        .font(AppTheme.Fonts.body)
                }
            }
        }
        .padding()
        .modelContainer(container)
    }
}
#endif

//
//  MultiBusinessManager.swift
//  Furfolio
//
//  Created by mac on 6/30/25.
//

import Foundation
import SwiftData
import SwiftUI

/// Represents a business profile within the app.
@Model public struct BusinessProfile: Identifiable {
    @Attribute(.unique) public var id: UUID = UUID()
    /// Name of the business.
    public var name: String
    /// Owner or primary contact for the business.
    public var ownerName: String?
    /// Optional email for the business.
    public var contactEmail: String?
    /// Optional phone number for the business.
    public var contactPhone: String?
    /// Optional address for the business.
    public var address: String?

    /// Readable summary for UI display.
    @Attribute(.transient)
    public var displaySummary: String {
        var parts = [name]
        if let owner = ownerName {
            parts.append(owner)
        }
        return parts.joined(separator: " – ")
    }
}

/// Manages multiple business profiles and the currently selected one.
public class MultiBusinessManager: ObservableObject {
    public static let shared = MultiBusinessManager()
    private init() {}

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \.name, order: .forward) public var profiles: [BusinessProfile]
    @Published public var currentProfile: BusinessProfile?

    /// Loads the current profile (defaults to the first profile if none selected).
    public func loadCurrentProfile() {
        if currentProfile == nil {
            currentProfile = profiles.first
        }
    }

    /// Creates a new business profile and makes it current.
    public func createProfile(
        name: String,
        owner: String?,
        email: String?,
        phone: String?,
        address: String?
    ) {
        let profile = BusinessProfile(
            name: name,
            ownerName: owner,
            contactEmail: email,
            contactPhone: phone,
            address: address
        )
        modelContext.insert(profile)
        currentProfile = profile
    }

    /// Switches to an existing business profile.
    public func selectProfile(_ profile: BusinessProfile) {
        currentProfile = profile
    }

    /// Deletes a business profile. If it was current, selects the first remaining.
    public func deleteProfile(_ profile: BusinessProfile) {
        modelContext.delete(profile)
        if currentProfile?.id == profile.id {
            currentProfile = profiles.first
        }
    }
}

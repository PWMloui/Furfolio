//
//  AnnouncementManager.swift
//  Furfolio
//
//  Created by mac on 6/30/25.
//

import Foundation
import SwiftData

/// Defines the audience for an announcement.
public enum AnnouncementAudience: String, CaseIterable, Identifiable {
    case owner, receptionist, groomer, all
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .owner: return NSLocalizedString("Owner", comment: "")
        case .receptionist: return NSLocalizedString("Receptionist", comment: "")
        case .groomer: return NSLocalizedString("Groomer", comment: "")
        case .all: return NSLocalizedString("All Staff", comment: "")
        }
    }
}

/// A single announcement to staff.
@Model public struct Announcement: Identifiable {
    @Attribute(.unique) public var id: UUID = UUID()
    public var title: String
    public var message: String
    public var audience: AnnouncementAudience
    public var dateSent: Date = Date()
    public var isActive: Bool = true

    /// Formatted date string for display.
    @Attribute(.transient)
    public var formattedDate: String {
        DateFormatter.localizedString(from: dateSent, dateStyle: .medium, timeStyle: .short)
    }
}

/// Manages creation, retrieval, and deactivation of announcements.
public class AnnouncementManager: ObservableObject {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \.dateSent, order: .reverse) public var announcements: [Announcement]

    public init() {}

    /// Sends a new announcement.
    public func send(title: String, message: String, audience: AnnouncementAudience) {
        let announcement = Announcement(title: title, message: message, audience: audience)
        modelContext.insert(announcement)
    }

    /// Marks an existing announcement inactive.
    public func deactivate(_ announcement: Announcement) {
        if let idx = announcements.firstIndex(where: { $0.id == announcement.id }) {
            announcements[idx].isActive = false
        }
    }

    /// Deletes an announcement permanently.
    public func delete(_ announcement: Announcement) {
        modelContext.delete(announcement)
    }
}

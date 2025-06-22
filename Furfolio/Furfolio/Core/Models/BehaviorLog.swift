//
//  BehaviorLog.swift
//  Furfolio
//
//  Created by mac on 6/20/25.
//

import Foundation
import SwiftData

// MARK: - BehaviorLog (Modular, Tokenized, Auditable Behavior Tracking)

/// Represents a modular, tokenized, and auditable detailed record of a dog's behavior during interactions such as grooming, appointments, or observations.
/// Fully integrated with SwiftUI and SwiftData to support comprehensive analytics, business logic workflows, badge and alert systems, and UI tokenized mood/badge presentation.
/// Designed for extensibility in analytics reporting, engagement tracking, and user-facing behavior summaries.
@Model
final class BehaviorLog: Identifiable, ObservableObject {
    // MARK: - Properties
    
    /// Unique identifier for audit trails and record tracking across systems.
    @Attribute(.unique)
    var id: UUID = UUID()
    
    /// Date and time when the behavior was logged.
    /// Used for audit timelines, longitudinal analytics, and chronological reporting.
    var date: Date = Date()
    
    /// Mood tag describing the dog's behavior.
    /// Serves as a tokenized attribute for UI display, analytics categorization, and badge/alert triggering.
    var mood: MoodTag
    
    /// Optional notes providing additional context for business workflows, audit detail, and qualitative analysis.
    var notes: String?
    
    /// Identifier of the user or system who created this log.
    /// Supports audit accountability, user engagement tracking, and multi-source data integration.
    var createdBy: String?
    
    // MARK: - Relationships
    
    /// Associated dog entity to link behavior logs for individual pet analytics, business workflows, and personalized reporting.
    @Relationship(deleteRule: .nullify)
    var dog: Dog?
    
    /// Associated appointment entity to correlate behaviors with scheduled events for business insights and engagement analytics.
    @Relationship(deleteRule: .nullify)
    var appointment: Appointment?
    
    /// Associated grooming session entity to connect behavior observations with specific grooming interactions for detailed analytics and workflow automation.
    @Relationship(deleteRule: .nullify)
    var session: GroomingSession?
    
    // MARK: - Initialization
    
    /// Initializes a new BehaviorLog instance with full audit and business workflow context.
    /// - Parameters:
    ///   - id: Unique identifier for audit and tracking.
    ///   - date: Timestamp for chronological analytics and reporting.
    ///   - mood: Tokenized mood tag for UI, analytics, and badge workflows.
    ///   - notes: Optional qualitative context for business and audit purposes.
    ///   - createdBy: User or system identifier for accountability and engagement tracking.
    ///   - dog: Associated dog for personalized analytics and reporting.
    ///   - appointment: Linked appointment for event-based business insights.
    ///   - session: Linked grooming session for interaction-specific analysis.
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        mood: MoodTag,
        notes: String? = nil,
        createdBy: String? = nil,
        dog: Dog? = nil,
        appointment: Appointment? = nil,
        session: GroomingSession? = nil
    ) {
        self.id = id
        self.date = date
        self.mood = mood
        self.notes = notes
        self.createdBy = createdBy
        self.dog = dog
        self.appointment = appointment
        self.session = session
    }
    
    // MARK: - Static Factory Methods
    
    /// Creates a BehaviorLog from a GroomingSession context.
    /// Supports audit linking to grooming events, business logic tied to session outcomes, and analytics on session-based behavior trends.
    /// - Parameters:
    ///   - session: GroomingSession instance representing the interaction context.
    ///   - mood: MoodTag token representing observed behavior.
    ///   - notes: Optional notes for additional context.
    ///   - createdBy: Identifier for audit and engagement tracking.
    /// - Returns: A new BehaviorLog instance linked to the grooming session.
    static func from(session: GroomingSession, mood: MoodTag, notes: String? = nil, createdBy: String? = nil) -> BehaviorLog {
        BehaviorLog(
            date: Date(),
            mood: mood,
            notes: notes,
            createdBy: createdBy,
            dog: session.dog,
            session: session
        )
    }
    
    /// Creates a BehaviorLog from an Appointment context.
    /// Enables audit correlation with scheduled events, business insights on appointment outcomes, and analytics for appointment-related behavior patterns.
    /// - Parameters:
    ///   - appointment: Appointment instance representing the scheduled interaction.
    ///   - mood: MoodTag token representing observed behavior.
    ///   - notes: Optional notes for qualitative context.
    ///   - createdBy: Identifier for audit and engagement purposes.
    /// - Returns: A new BehaviorLog instance linked to the appointment.
    static func from(appointment: Appointment, mood: MoodTag, notes: String? = nil, createdBy: String? = nil) -> BehaviorLog {
        BehaviorLog(
            date: Date(),
            mood: mood,
            notes: notes,
            createdBy: createdBy,
            dog: appointment.dog,
            appointment: appointment
        )
    }
    
    /// Creates a BehaviorLog directly from a Dog entity.
    /// Useful for standalone observations outside specific events, supporting audit completeness, continuous behavior tracking, and baseline analytics.
    /// - Parameters:
    ///   - dog: Dog instance representing the subject.
    ///   - mood: MoodTag token for behavior classification.
    ///   - notes: Optional notes for detailed context.
    ///   - createdBy: Identifier for audit and engagement tracking.
    /// - Returns: A new BehaviorLog instance linked to the dog.
    static func from(dog: Dog, mood: MoodTag, notes: String? = nil, createdBy: String? = nil) -> BehaviorLog {
        BehaviorLog(
            date: Date(),
            mood: mood,
            notes: notes,
            createdBy: createdBy,
            dog: dog
        )
    }
    
    // MARK: - Computed Properties
    
    /// Formatted date string for UI display, analytics reporting, and audit timelines.
    /// Ensures consistent localization and human-readable presentation across the app.
    var formattedDate: String {
        BehaviorLog.dateFormatter.string(from: date)
    }
    
    /// Combined mood icon and label for tokenized UI display, analytics categorization, and reporting summaries.
    var moodDisplay: String {
        "\(mood.icon) \(mood.label)"
    }
    
    // MARK: - Private
    
    /// DateFormatter configured for audit reporting, analytics timelines, and localized UI presentation.
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale.current
        return formatter
    }()
    
    // MARK: - Integration Notes
    
    // TODO: Integrate with EngagementAnalyzer to track longitudinal behavior trends, power analytics, and trigger badge/alert workflows.
}

/// Represents mood or behavior tags with extensibility for analytics, reporting, badge awarding, and UI integration.
/// Each case includes suggested badge/business logic use to facilitate engagement workflows and tokenized display.
enum MoodTag: String, CaseIterable, Codable, Identifiable {
    /// Calm behavior, suitable for badges rewarding steady temperament and relaxation.
    case calm = "Calm"
    /// Friendly behavior, useful for badges promoting social interaction and positive demeanor.
    case friendly = "Friendly"
    /// Anxious behavior, to flag for alerts and badges related to stress management.
    case anxious = "Anxious"
    /// Nervous behavior, indicating potential triggers and requiring careful handling badges.
    case nervous = "Nervous"
    /// Excited behavior, supporting badges for enthusiasm and engagement.
    case excited = "Excited"
    /// Aggressive behavior, critical for alerting and behavior intervention badges.
    case aggressive = "Aggressive"
    /// Fearful behavior, used for badges related to confidence building and alerting.
    case fearful = "Fearful"
    /// Playful behavior, supporting badges for activity and positive interaction.
    case playful = "Playful"
    /// Tired behavior, useful for rest and recovery badges or alerts.
    case tired = "Tired"
    /// Other behavior, for uncategorized or new behavior types, supporting extensibility.
    case other = "Other"
    
    /// Unique identifier for analytics, reporting, and tokenization.
    var id: String { rawValue }
    
    /// Emoji representing the mood.
    /// Used for tokenized UI display, quick analytics categorization, and visual badge integration.
    var icon: String {
        switch self {
        case .calm: return "🟢"
        case .friendly: return "💚"
        case .anxious: return "🟡"
        case .nervous: return "🟠"
        case .excited: return "✨"
        case .aggressive: return "🔴"
        case .fearful: return "🟣"
        case .playful: return "🎾"
        case .tired: return "💤"
        case .other: return "❔"
        }
    }
    
    /// Label for UI display, analytics reporting, and tokenized mood representation.
    var label: String { rawValue }
}

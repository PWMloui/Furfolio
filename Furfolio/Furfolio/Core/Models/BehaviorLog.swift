//
//  BehaviorLog.swift
//  Furfolio
//
//  Enterprise Enhanced: analytics/audit–ready, Trust Center–capable, preview/test–injectable.
//

import Foundation
import SwiftData

// MARK: - Analytics/Audit Protocol

public protocol BehaviorLogAnalyticsLogger {
    func log(event: String, info: [String: Any]?)
}
public struct NullBehaviorLogAnalyticsLogger: BehaviorLogAnalyticsLogger {
    public init() {}
    public func log(event: String, info: [String: Any]?) {}
}

// MARK: - Trust Center Permission Protocol

public protocol BehaviorLogTrustCenterDelegate {
    func permission(for action: String, context: [String: Any]?) -> Bool
}
public struct NullBehaviorLogTrustCenterDelegate: BehaviorLogTrustCenterDelegate {
    public init() {}
    public func permission(for action: String, context: [String: Any]?) -> Bool { true }
}

// MARK: - BehaviorLog (Enterprise Enhanced)

@Model
final class BehaviorLog: Identifiable, ObservableObject {
    // MARK: - Properties
    @Attribute(.unique)
    var id: UUID = UUID()
    var date: Date = Date()
    var mood: MoodTag
    var notes: String?
    var createdBy: String?
    
    // MARK: - Relationships
    @Relationship(deleteRule: .nullify)
    var dog: Dog?
    @Relationship(deleteRule: .nullify)
    var appointment: Appointment?
    @Relationship(deleteRule: .nullify)
    var session: GroomingSession?

    // MARK: - Audit/Analytics Injectables
    static var analyticsLogger: BehaviorLogAnalyticsLogger = NullBehaviorLogAnalyticsLogger()
    static var trustCenterDelegate: BehaviorLogTrustCenterDelegate = NullBehaviorLogTrustCenterDelegate()

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        mood: MoodTag,
        notes: String? = nil,
        createdBy: String? = nil,
        dog: Dog? = nil,
        appointment: Appointment? = nil,
        session: GroomingSession? = nil,
        auditTag: String? = nil
    ) {
        self.id = id
        self.date = date
        self.mood = mood
        self.notes = notes
        self.createdBy = createdBy
        self.dog = dog
        self.appointment = appointment
        self.session = session

        Self.analyticsLogger.log(event: "created", info: [
            "id": id.uuidString,
            "mood": mood.rawValue,
            "createdBy": createdBy as Any,
            "dog": dog?.id.uuidString as Any,
            "appointment": appointment?.id.uuidString as Any,
            "session": session?.id.uuidString as Any,
            "auditTag": auditTag as Any
        ])
    }

    // MARK: - Mutation Methods

    func updateMood(_ newMood: MoodTag, by user: String?, auditTag: String? = nil) {
        guard Self.trustCenterDelegate.permission(for: "updateMood", context: [
            "id": id.uuidString,
            "oldMood": mood.rawValue,
            "newMood": newMood.rawValue,
            "user": user as Any,
            "auditTag": auditTag as Any
        ]) else {
            Self.analyticsLogger.log(event: "updateMood_denied", info: [
                "id": id.uuidString,
                "user": user as Any,
                "auditTag": auditTag as Any
            ])
            return
        }
        let oldMood = mood
        mood = newMood
        Self.analyticsLogger.log(event: "moodUpdated", info: [
            "id": id.uuidString,
            "oldMood": oldMood.rawValue,
            "newMood": newMood.rawValue,
            "user": user as Any,
            "auditTag": auditTag as Any
        ])
    }

    func updateNotes(_ newNotes: String, by user: String?, auditTag: String? = nil) {
        guard Self.trustCenterDelegate.permission(for: "updateNotes", context: [
            "id": id.uuidString,
            "user": user as Any,
            "auditTag": auditTag as Any
        ]) else {
            Self.analyticsLogger.log(event: "updateNotes_denied", info: [
                "id": id.uuidString,
                "user": user as Any,
                "auditTag": auditTag as Any
            ])
            return
        }
        notes = newNotes
        Self.analyticsLogger.log(event: "notesUpdated", info: [
            "id": id.uuidString,
            "user": user as Any,
            "auditTag": auditTag as Any
        ])
    }

    // MARK: - Static Factory Methods

    static func from(session: GroomingSession, mood: MoodTag, notes: String? = nil, createdBy: String? = nil, auditTag: String? = nil) -> BehaviorLog {
        BehaviorLog(
            date: Date(),
            mood: mood,
            notes: notes,
            createdBy: createdBy,
            dog: session.dog,
            session: session,
            auditTag: auditTag
        )
    }

    static func from(appointment: Appointment, mood: MoodTag, notes: String? = nil, createdBy: String? = nil, auditTag: String? = nil) -> BehaviorLog {
        BehaviorLog(
            date: Date(),
            mood: mood,
            notes: notes,
            createdBy: createdBy,
            dog: appointment.dog,
            appointment: appointment,
            auditTag: auditTag
        )
    }

    static func from(dog: Dog, mood: MoodTag, notes: String? = nil, createdBy: String? = nil, auditTag: String? = nil) -> BehaviorLog {
        BehaviorLog(
            date: Date(),
            mood: mood,
            notes: notes,
            createdBy: createdBy,
            dog: dog,
            auditTag: auditTag
        )
    }

    // MARK: - Computed Properties

    var formattedDate: String {
        BehaviorLog.dateFormatter.string(from: date)
    }

    var moodDisplay: String {
        "\(mood.icon) \(mood.label)"
    }

    var accessibilityLabel: String {
        "Behavior: \(mood.label). \(notes ?? "")"
    }

    // MARK: - Private

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale.current
        return formatter
    }()
}

// MARK: - MoodTag (unchanged except for accessibilityLabel)

enum MoodTag: String, CaseIterable, Codable, Identifiable {
    case calm = "Calm"
    case friendly = "Friendly"
    case anxious = "Anxious"
    case nervous = "Nervous"
    case excited = "Excited"
    case aggressive = "Aggressive"
    case fearful = "Fearful"
    case playful = "Playful"
    case tired = "Tired"
    case other = "Other"

    var id: String { rawValue }

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

    var label: String { rawValue }

    var accessibilityLabel: String {
        switch self {
        case .calm: return "Calm mood"
        case .friendly: return "Friendly mood"
        case .anxious: return "Anxious mood"
        case .nervous: return "Nervous mood"
        case .excited: return "Excited mood"
        case .aggressive: return "Aggressive mood"
        case .fearful: return "Fearful mood"
        case .playful: return "Playful mood"
        case .tired: return "Tired mood"
        case .other: return "Other mood"
        }
    }
}

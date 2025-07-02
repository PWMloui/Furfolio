//
//  BehaviorLog.swift
//  Furfolio
//
//  Enterprise Enhanced: analytics/audit–ready, Trust Center–capable, preview/test–injectable.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Analytics/Audit Protocol

public protocol BehaviorLogAnalyticsLogger {
    /// Logs an event asynchronously with optional additional info.
    /// - Parameters:
    ///   - event: The name of the event to log.
    ///   - info: Optional dictionary of additional information.
    func log(event: String, info: [String: Any]?) async
}
public struct NullBehaviorLogAnalyticsLogger: BehaviorLogAnalyticsLogger {
    public init() {}
    public func log(event: String, info: [String: Any]?) async {}
}

// MARK: - Trust Center Permission Protocol

public protocol BehaviorLogTrustCenterDelegate {
    /// Checks asynchronously if permission is granted for a given action and context.
    /// - Parameters:
    ///   - action: The action for which permission is requested.
    ///   - context: Optional dictionary providing context for the permission check.
    /// - Returns: A boolean indicating whether permission is granted.
    func permission(for action: String, context: [String: Any]?) async -> Bool
}
public struct NullBehaviorLogTrustCenterDelegate: BehaviorLogTrustCenterDelegate {
    public init() {}
    public func permission(for action: String, context: [String: Any]?) async -> Bool { true }
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

        Task {
            await Self.analyticsLogger.log(event: NSLocalizedString("created", comment: "Audit event for creation"), info: [
                "id": id.uuidString,
                "mood": mood.rawValue,
                "createdBy": createdBy as Any,
                "dog": dog?.id.uuidString as Any,
                "appointment": appointment?.id.uuidString as Any,
                "session": session?.id.uuidString as Any,
                "auditTag": auditTag as Any
            ])
        }
    }

    // MARK: - Mutation Methods

    /// Asynchronously updates the mood of the behavior log if permission is granted.
    /// - Parameters:
    ///   - newMood: The new mood to set.
    ///   - user: The user performing the update.
    ///   - auditTag: Optional tag for audit purposes.
    func updateMood(_ newMood: MoodTag, by user: String?, auditTag: String? = nil) async {
        guard await Self.trustCenterDelegate.permission(for: "updateMood", context: [
            "id": id.uuidString,
            "oldMood": mood.rawValue,
            "newMood": newMood.rawValue,
            "user": user as Any,
            "auditTag": auditTag as Any
        ]) else {
            await Self.analyticsLogger.log(event: NSLocalizedString("updateMood_denied", comment: "Audit event for denied mood update"), info: [
                "id": id.uuidString,
                "user": user as Any,
                "auditTag": auditTag as Any
            ])
            return
        }
        let oldMood = mood
        mood = newMood
        await Self.analyticsLogger.log(event: NSLocalizedString("moodUpdated", comment: "Audit event for mood updated"), info: [
            "id": id.uuidString,
            "oldMood": oldMood.rawValue,
            "newMood": newMood.rawValue,
            "user": user as Any,
            "auditTag": auditTag as Any
        ])
    }

    /// Asynchronously updates the notes of the behavior log if permission is granted.
    /// - Parameters:
    ///   - newNotes: The new notes to set.
    ///   - user: The user performing the update.
    ///   - auditTag: Optional tag for audit purposes.
    func updateNotes(_ newNotes: String, by user: String?, auditTag: String? = nil) async {
        guard await Self.trustCenterDelegate.permission(for: "updateNotes", context: [
            "id": id.uuidString,
            "user": user as Any,
            "auditTag": auditTag as Any
        ]) else {
            await Self.analyticsLogger.log(event: NSLocalizedString("updateNotes_denied", comment: "Audit event for denied notes update"), info: [
                "id": id.uuidString,
                "user": user as Any,
                "auditTag": auditTag as Any
            ])
            return
        }
        notes = newNotes
        await Self.analyticsLogger.log(event: NSLocalizedString("notesUpdated", comment: "Audit event for notes updated"), info: [
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

    @Attribute(.transient)
    var formattedDate: String {
        BehaviorLog.dateFormatter.string(from: date)
    }

    @Attribute(.transient)
    var moodDisplay: String {
        "\(mood.icon) \(mood.label)"
    }

    @Attribute(.transient)
    var accessibilityLabel: String {
        let behaviorFormat = NSLocalizedString("BehaviorFormat", comment: "Format for behavior accessibility label")
        let notesText = notes ?? ""
        return String(format: behaviorFormat, mood.accessibilityLabel, notesText)
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
        case .calm: return NSLocalizedString("Calm mood", comment: "Accessibility label for calm mood")
        case .friendly: return NSLocalizedString("Friendly mood", comment: "Accessibility label for friendly mood")
        case .anxious: return NSLocalizedString("Anxious mood", comment: "Accessibility label for anxious mood")
        case .nervous: return NSLocalizedString("Nervous mood", comment: "Accessibility label for nervous mood")
        case .excited: return NSLocalizedString("Excited mood", comment: "Accessibility label for excited mood")
        case .aggressive: return NSLocalizedString("Aggressive mood", comment: "Accessibility label for aggressive mood")
        case .fearful: return NSLocalizedString("Fearful mood", comment: "Accessibility label for fearful mood")
        case .playful: return NSLocalizedString("Playful mood", comment: "Accessibility label for playful mood")
        case .tired: return NSLocalizedString("Tired mood", comment: "Accessibility label for tired mood")
        case .other: return NSLocalizedString("Other mood", comment: "Accessibility label for other mood")
        }
    }
}

// MARK: - SwiftUI PreviewProvider demonstrating async usage

#if DEBUG
struct BehaviorLog_Previews: PreviewProvider {
    static var previews: some View {
        BehaviorLogPreviewView()
    }

    struct BehaviorLogPreviewView: View {
        @StateObject private var behaviorLog = BehaviorLog.from(dog: Dog.example, mood: .calm)

        var body: some View {
            VStack(spacing: 20) {
                Text("Mood: \(behaviorLog.moodDisplay)")
                Text("Notes: \(behaviorLog.notes ?? "None")")
                Button("Update Mood to Excited") {
                    Task {
                        await behaviorLog.updateMood(.excited, by: "PreviewUser", auditTag: "PreviewUpdate")
                    }
                }
                Button("Update Notes") {
                    Task {
                        await behaviorLog.updateNotes("Feeling playful today!", by: "PreviewUser", auditTag: "PreviewUpdate")
                    }
                }
                Text("Accessibility Label: \(behaviorLog.accessibilityLabel)")
            }
            .padding()
        }
    }
}

// Dummy Dog example for preview
extension Dog {
    static var example: Dog {
        let dog = Dog()
        dog.id = UUID()
        dog.name = "Fido"
        return dog
    }
}
#endif

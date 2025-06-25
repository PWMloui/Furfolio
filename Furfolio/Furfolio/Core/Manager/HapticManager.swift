//
//  HapticManager.swift
//  Furfolio
//
//  Enhanced & Auditable: 2025+ Grooming Business App Architecture
//

import Foundation
import UIKit

// MARK: - HapticManager (Unified, Tokenized, Accessible, Auditable Haptic Feedback Engine)

enum HapticManager {
    // MARK: - Audit/Event Log

    struct HapticAuditEvent: Codable {
        let timestamp: Date
        let type: HapticType
        let tags: [String]
        let actor: String?
        let context: String?
        let errorDescription: String?
        var accessibilityLabel: String {
            let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
            return "\(type.displayName) haptic at \(dateStr)\(errorDescription == nil ? "" : " (error)")"
        }
    }
    private(set) static var auditLog: [HapticAuditEvent] = []

    static func exportLastAuditEventJSON() -> String? {
        guard let last = auditLog.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    static var accessibilitySummary: String {
        auditLog.last?.accessibilityLabel ?? "No haptic feedback recorded."
    }

    private static func logHaptic(type: HapticType, actor: String? = nil, context: String? = nil, error: Error? = nil) {
        let event = HapticAuditEvent(
            timestamp: Date(),
            type: type,
            tags: type.tags,
            actor: actor,
            context: context,
            errorDescription: error?.localizedDescription
        )
        auditLog.append(event)
        if auditLog.count > 500 { auditLog.removeFirst() }
    }

    // MARK: - Public API

    static func success(actor: String? = nil, context: String? = nil) {
        logHaptic(type: .success, actor: actor, context: context)
        trigger(.success)
    }

    static func warning(actor: String? = nil, context: String? = nil) {
        logHaptic(type: .warning, actor: actor, context: context)
        trigger(.warning)
    }

    static func error(actor: String? = nil, context: String? = nil) {
        logHaptic(type: .error, actor: actor, context: context)
        trigger(.error)
    }

    static func selection(actor: String? = nil, context: String? = nil) {
        logHaptic(type: .selection, actor: actor, context: context)
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    static func light(actor: String? = nil, context: String? = nil) {
        logHaptic(type: .light, actor: actor, context: context)
        impact(.light)
    }

    static func medium(actor: String? = nil, context: String? = nil) {
        logHaptic(type: .medium, actor: actor, context: context)
        impact(.medium)
    }

    static func heavy(actor: String? = nil, context: String? = nil) {
        logHaptic(type: .heavy, actor: actor, context: context)
        impact(.heavy)
    }

    static func celebrate(actor: String? = nil, context: String? = nil) {
        logHaptic(type: .celebrate, actor: actor, context: context)
        success(actor: actor, context: context)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { medium(actor: actor, context: context) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) { heavy(actor: actor, context: context) }
    }

    // MARK: - Private Helpers

    private static func trigger(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }

    private static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
}

// MARK: - HapticType (Tokenized, Tagged, Accessible)
enum HapticType: String, Codable {
    case success, warning, error, selection, light, medium, heavy, celebrate

    var displayName: String {
        switch self {
        case .success: return "Success"
        case .warning: return "Warning"
        case .error: return "Error"
        case .selection: return "Selection"
        case .light: return "Light"
        case .medium: return "Medium"
        case .heavy: return "Heavy"
        case .celebrate: return "Celebrate"
        }
    }
    var tags: [String] {
        switch self {
        case .success: return ["success", "achievement", "confirm"]
        case .warning: return ["warning", "caution", "risk"]
        case .error: return ["error", "fail", "denied"]
        case .selection: return ["selection", "ui", "picker"]
        case .light: return ["light", "tap", "ui"]
        case .medium: return ["medium", "tap", "ui"]
        case .heavy: return ["heavy", "tap", "ui"]
        case .celebrate: return ["celebrate", "milestone", "reward"]
        }
    }
}

// MARK: - Cross-Platform & Accessibility Notes
/*
- On iPad/Mac Catalyst, haptic feedback is supported if device hardware allows.
- Always combine haptics with visible/audible feedback for accessibility.
- Consider exposing a Settings toggle for "Enable Haptic Feedback" in Trust Center, respecting device/system preferences.
- All haptic calls are lightweight and safe for background/async use in main thread UI actions.
- All calls are logged/audited for business events if compliance is required.
*/

// MARK: - Example Usage
/*
 if TrustCenter.shared.isHapticEnabled {
     HapticManager.success(actor: "user:123", context: "Appointment booked")
 }

 HapticManager.success()    // Appointment booked
 HapticManager.warning()    // Overlapping appointments
 HapticManager.error()      // Failed to save
 HapticManager.selection()  // Filter bar changed
 HapticManager.light()      // Tap on action
 HapticManager.celebrate()  // Loyalty milestone unlocked

 // To export the last event as JSON for admin/trust center:
 let json = HapticManager.exportLastAuditEventJSON()
*/

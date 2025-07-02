//
//  HapticManager.swift
//  Furfolio
//
//  Enhanced & Auditable: 2025+ Grooming Business App Architecture
//

import Foundation
import UIKit
import SwiftUI
import SwiftData

// MARK: - HapticManager (Unified, Tokenized, Accessible, Auditable Haptic Feedback Engine)

enum HapticManager {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \.timestamp, order: .forward) private var auditEvents: [HapticAuditEvent]

    // MARK: - Audit/Event Log

    @Model public struct HapticAuditEvent: Identifiable {
        @Attribute(.unique) public var id: UUID = UUID()
        let timestamp: Date
        let type: HapticType
        let tags: [String]
        let actor: String?
        let context: String?
        let errorDescription: String?
        @Attribute(.transient)
        var accessibilityLabel: String {
            let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
            let errorSuffix = errorDescription == nil ? "" : " (\(NSLocalizedString("error", comment: "Error suffix in accessibility label")))"
            return String(format: NSLocalizedString("%@ haptic at %@", comment: "Accessibility label for haptic event"), type.displayName, dateStr) + errorSuffix
        }
    }
    
    /// Asynchronously appends a new haptic audit event to the log in a thread-safe manner.
    /// - Parameters:
    ///   - type: The type of haptic feedback.
    ///   - actor: Optional identifier of the actor triggering the haptic.
    ///   - context: Optional context description.
    ///   - error: Optional error associated with the event.
    private static func logHaptic(type: HapticType, actor: String? = nil, context: String? = nil, error: Error? = nil) async {
        let event = HapticAuditEvent(
            timestamp: Date(),
            type: type,
            tags: type.tags,
            actor: actor,
            context: context,
            errorDescription: error?.localizedDescription
        )
        modelContext.insert(event)
    }

    /// Asynchronously exports the last audit event as a pretty-printed JSON string.
    /// - Returns: JSON string of the last audit event or nil if no events exist.
    static func exportLastAuditEventJSON() async -> String? {
        let entries = try? await modelContext.fetch(HapticAuditEvent.self)
        guard let last = entries?.last else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return (try? String(data: encoder.encode(last), encoding: .utf8))
    }

    /// Asynchronously clears the audit log in a thread-safe manner.
    ///
    /// Use this method to reset the audit log safely from any concurrency context.
    static func clearAuditLog() async {
        let entries = try? await modelContext.fetch(HapticAuditEvent.self)
        entries?.forEach { modelContext.delete($0) }
    }

    /// Asynchronously retrieves a localized accessibility summary of the last haptic event.
    static var accessibilitySummary: String {
        get async {
            let entries = try? await modelContext.fetch(HapticAuditEvent.self)
            return entries?.last?.accessibilityLabel
                ?? NSLocalizedString("No haptic feedback recorded.", comment: "")
        }
    }

    // MARK: - Public API (Async)

    /// Triggers a success haptic feedback asynchronously.
    /// - Parameters:
    ///   - actor: Optional actor identifier.
    ///   - context: Optional context description.
    static func success(actor: String? = nil, context: String? = nil) async {
        await logHaptic(type: .success, actor: actor, context: context)
        await triggerOnMain(.success)
    }

    /// Triggers a warning haptic feedback asynchronously.
    /// - Parameters:
    ///   - actor: Optional actor identifier.
    ///   - context: Optional context description.
    static func warning(actor: String? = nil, context: String? = nil) async {
        await logHaptic(type: .warning, actor: actor, context: context)
        await triggerOnMain(.warning)
    }

    /// Triggers an error haptic feedback asynchronously.
    /// - Parameters:
    ///   - actor: Optional actor identifier.
    ///   - context: Optional context description.
    static func error(actor: String? = nil, context: String? = nil) async {
        await logHaptic(type: .error, actor: actor, context: context)
        await triggerOnMain(.error)
    }

    /// Triggers a selection haptic feedback asynchronously.
    /// - Parameters:
    ///   - actor: Optional actor identifier.
    ///   - context: Optional context description.
    static func selection(actor: String? = nil, context: String? = nil) async {
        await logHaptic(type: .selection, actor: actor, context: context)
        await performOnMain {
            let generator = UISelectionFeedbackGenerator()
            generator.prepare()
            generator.selectionChanged()
        }
    }

    /// Triggers a light impact haptic feedback asynchronously.
    /// - Parameters:
    ///   - actor: Optional actor identifier.
    ///   - context: Optional context description.
    static func light(actor: String? = nil, context: String? = nil) async {
        await logHaptic(type: .light, actor: actor, context: context)
        await impactOnMain(.light)
    }

    /// Triggers a medium impact haptic feedback asynchronously.
    /// - Parameters:
    ///   - actor: Optional actor identifier.
    ///   - context: Optional context description.
    static func medium(actor: String? = nil, context: String? = nil) async {
        await logHaptic(type: .medium, actor: actor, context: context)
        await impactOnMain(.medium)
    }

    /// Triggers a heavy impact haptic feedback asynchronously.
    /// - Parameters:
    ///   - actor: Optional actor identifier.
    ///   - context: Optional context description.
    static func heavy(actor: String? = nil, context: String? = nil) async {
        await logHaptic(type: .heavy, actor: actor, context: context)
        await impactOnMain(.heavy)
    }

    /// Triggers a celebrate haptic feedback sequence asynchronously.
    /// - Parameters:
    ///   - actor: Optional actor identifier.
    ///   - context: Optional context description.
    static func celebrate(actor: String? = nil, context: String? = nil) async {
        await logHaptic(type: .celebrate, actor: actor, context: context)
        await success(actor: actor, context: context)
        try? await Task.sleep(nanoseconds: 180_000_000)
        await medium(actor: actor, context: context)
        try? await Task.sleep(nanoseconds: 160_000_000)
        await heavy(actor: actor, context: context)
    }

    // MARK: - Private Helpers

    /// Triggers a notification feedback on the main thread asynchronously.
    /// - Parameter type: The feedback type to trigger.
    private static func triggerOnMain(_ type: UINotificationFeedbackGenerator.FeedbackType) async {
        await performOnMain {
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(type)
        }
    }

    /// Triggers an impact feedback on the main thread asynchronously.
    /// - Parameter style: The impact style to trigger.
    private static func impactOnMain(_ style: UIImpactFeedbackGenerator.FeedbackStyle) async {
        await performOnMain {
            let generator = UIImpactFeedbackGenerator(style: style)
            generator.prepare()
            generator.impactOccurred()
        }
    }

    /// Performs a closure on the main thread asynchronously.
    /// - Parameter block: The closure to perform.
    private static func performOnMain(_ block: @escaping () -> Void) async {
        if Thread.isMainThread {
            block()
        } else {
            await withCheckedContinuation { continuation in
                DispatchQueue.main.async {
                    block()
                    continuation.resume()
                }
            }
        }
    }
}

// MARK: - HapticType (Tokenized, Tagged, Accessible)
enum HapticType: String, Codable {
    case success, warning, error, selection, light, medium, heavy, celebrate

    var displayName: String {
        switch self {
        case .success: return NSLocalizedString("Success", comment: "Haptic type display name")
        case .warning: return NSLocalizedString("Warning", comment: "Haptic type display name")
        case .error: return NSLocalizedString("Error", comment: "Haptic type display name")
        case .selection: return NSLocalizedString("Selection", comment: "Haptic type display name")
        case .light: return NSLocalizedString("Light", comment: "Haptic type display name")
        case .medium: return NSLocalizedString("Medium", comment: "Haptic type display name")
        case .heavy: return NSLocalizedString("Heavy", comment: "Haptic type display name")
        case .celebrate: return NSLocalizedString("Celebrate", comment: "Haptic type display name")
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
 Task {
     if TrustCenter.shared.isHapticEnabled {
         await HapticManager.success(actor: "user:123", context: "Appointment booked")
     }

     await HapticManager.success()    // Appointment booked
     await HapticManager.warning()    // Overlapping appointments
     await HapticManager.error()      // Failed to save
     await HapticManager.selection()  // Filter bar changed
     await HapticManager.light()      // Tap on action
     await HapticManager.celebrate()  // Loyalty milestone unlocked

     // To export the last event as JSON for admin/trust center:
     if let json = await HapticManager.exportLastAuditEventJSON() {
         print(json)
     }

     // To clear audit log safely:
     await HapticManager.clearAuditLog()

     // To get accessibility summary:
     let summary = await HapticManager.accessibilitySummary
     print(summary)
 }
*/

// MARK: - SwiftUI PreviewProvider for async usage demonstration
#if DEBUG
struct HapticManager_Previews: PreviewProvider {
    struct PreviewView: View {
        @State private var auditSummary: String = NSLocalizedString("Loading...", comment: "Loading state for audit summary")
        @State private var lastEventJSON: String = ""

        var body: some View {
            VStack(spacing: 16) {
                Text(NSLocalizedString("Last Haptic Event Summary:", comment: "Label for audit summary"))
                    .font(.headline)
                Text(auditSummary)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding()

                Text(NSLocalizedString("Last Event JSON:", comment: "Label for last event JSON"))
                    .font(.headline)
                ScrollView {
                    Text(lastEventJSON)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                }
                .frame(maxHeight: 200)

                Button(NSLocalizedString("Trigger Success Haptic", comment: "Button title")) {
                    Task {
                        await HapticManager.success(actor: "preview", context: "Button press")
                        auditSummary = await HapticManager.accessibilitySummary
                        lastEventJSON = (await HapticManager.exportLastAuditEventJSON()) ?? NSLocalizedString("No data", comment: "No JSON data available")
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .task {
                auditSummary = await HapticManager.accessibilitySummary
                lastEventJSON = (await HapticManager.exportLastAuditEventJSON()) ?? NSLocalizedString("No data", comment: "No JSON data available")
            }
        }
    }

    static var previews: some View {
        PreviewView()
    }
}
#endif

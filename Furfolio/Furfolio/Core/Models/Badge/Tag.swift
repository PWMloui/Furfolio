//
//  Tag.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Tokenized, Modular Tag Model
//

import Foundation
import SwiftUI

// MARK: - Audit Context (set at login/session)
public struct TagAuditContext {
    public static var role: String? = nil
    public static var staffID: String? = nil
    public static var context: String? = "Tag"
}

public struct TagAuditEvent: Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let operation: String         // "create", "edit", "use"
    public let tagID: UUID
    public let label: String
    public let type: Tag.TagType
    public let actor: String?
    public let context: String?
    public let detail: String?
    public let tags: [String]
    public let role: String?
    public let staffID: String?
    public let escalate: Bool

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        operation: String,
        tagID: UUID,
        label: String,
        type: Tag.TagType,
        actor: String?,
        context: String?,
        detail: String?,
        tags: [String],
        role: String?,
        staffID: String?,
        escalate: Bool
    ) {
        self.id = id
        self.timestamp = timestamp
        self.operation = operation
        self.tagID = tagID
        self.label = label
        self.type = type
        self.actor = actor
        self.context = context
        self.detail = detail
        self.tags = tags
        self.role = role
        self.staffID = staffID
        self.escalate = escalate
    }

    public var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        let operationCapitalized = operation.capitalized
        let tagsJoined = tags.joined(separator: ",")
        let detailString = detail != nil ? ": \(detail!)" : ""
        var pieces: [String] = [
            "[\(operationCapitalized)] \(label) (\(type.rawValue)) [\(tagsJoined)] at \(dateStr)\(detailString)"
        ]
        if let role = role { pieces.append("Role: \(role)") }
        if let staffID = staffID { pieces.append("StaffID: \(staffID)") }
        if escalate { pieces.append("Escalate: YES") }
        return pieces.joined(separator: " | ")
    }
}

// MARK: - Audit/Event Logging

fileprivate final class TagAudit {
    // Private serial queue to ensure concurrency-safe access to the audit log
    private static let queue = DispatchQueue(label: "com.furfolio.tagaudit.queue")
    private static var _log: [TagAuditEvent] = []

    /// Concurrency-safe audit log accessor
    private static var log: [TagAuditEvent] {
        get { queue.sync { _log } }
    }

    /// Asynchronously records an audit event.
    static func record(
        operation: String,
        tag: Tag,
        tags: [String] = [],
        actor: String? = NSLocalizedString("system", comment: "Default actor"),
        context: String? = NSLocalizedString("Tag", comment: "Default context"),
        detail: String? = nil
    ) async {
        await withCheckedContinuation { continuation in
            queue.async {
                let escalate = operation.lowercased().contains("danger")
                    || operation.lowercased().contains("critical")
                    || operation.lowercased().contains("delete")
                let event = TagAuditEvent(
                    operation: operation,
                    tagID: tag.id,
                    label: tag.label,
                    type: tag.type,
                    actor: actor,
                    context: context,
                    detail: detail,
                    tags: tags,
                    role: TagAuditContext.role,
                    staffID: TagAuditContext.staffID,
                    escalate: escalate
                )
                _log.append(event)
                if _log.count > 200 { _log.removeFirst() }
                continuation.resume()
            }
        }
    }

    /// Asynchronously exports the last audit event as a pretty-printed JSON string.
    static func exportLastJSON() async -> String? {
        await withCheckedContinuation { continuation in
            queue.async {
                guard let last = _log.last else {
                    continuation.resume(returning: nil)
                    return
                }
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                if let data = try? encoder.encode(last),
                   let jsonString = String(data: data, encoding: .utf8) {
                    continuation.resume(returning: jsonString)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// Asynchronously fetches a summary string suitable for accessibility describing the last audit event.
    static var accessibilitySummary: String {
        get async {
            await withCheckedContinuation { continuation in
                queue.async {
                    if let last = _log.last {
                        continuation.resume(returning: last.accessibilityLabel)
                    } else {
                        continuation.resume(returning: NSLocalizedString("No tag audit events recorded.", comment: "Accessibility summary when no audit events"))
                    }
                }
            }
        }
    }

    /// Asynchronously fetches recent audit event accessibility labels with pagination.
    static func recentEvents(limit: Int = 5) async -> [String] {
        await withCheckedContinuation { continuation in
            queue.async {
                let events = _log.suffix(limit).map { $0.accessibilityLabel }
                continuation.resume(returning: events)
            }
        }
    }

    /// Asynchronously clears the audit log.
    static func clearLog() async {
        await withCheckedContinuation { continuation in
            queue.async {
                _log.removeAll()
                continuation.resume()
            }
        }
    }
}

// MARK: - Tag Model

struct Tag: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var label: String       // "VIP", "Senior", "Puppy", "Birthday", etc.
    var type: TagType
    var color: ColorCodable = .defaultColor
    var iconName: String?   // For SFSymbols or asset names

    // MARK: - TagType
    enum TagType: String, Codable, CaseIterable {
        case loyalty
        case behavior
        case event
        case retention
        case health
        case custom

        var label: String {
            switch self {
            case .loyalty:   return NSLocalizedString("Loyalty", comment: "Tag type label loyalty")
            case .behavior:  return NSLocalizedString("Behavior", comment: "Tag type label behavior")
            case .event:     return NSLocalizedString("Event", comment: "Tag type label event")
            case .retention: return NSLocalizedString("Retention", comment: "Tag type label retention")
            case .health:    return NSLocalizedString("Health", comment: "Tag type label health")
            case .custom:    return NSLocalizedString("Custom", comment: "Tag type label custom")
            }
        }

        var defaultIcon: String {
            switch self {
            case .loyalty:   return "star.fill"
            case .behavior:  return "face.smiling"
            case .event:     return "calendar"
            case .retention: return "flag"
            case .health:    return "cross.case"
            case .custom:    return "tag"
            }
        }

        var defaultColor: ColorCodable {
            switch self {
            case .loyalty:   return .loyalty
            case .behavior:  return .behavior
            case .event:     return .event
            case .retention: return .retention
            case .health:    return .health
            case .custom:    return .custom
            }
        }
    }

    // MARK: - Auditable Mutators

    /// Use when creating a new Tag
    static func create(label: String, type: TagType, color: ColorCodable = .defaultColor, iconName: String? = nil, actor: String? = NSLocalizedString("user", comment: "Default actor"), context: String? = NSLocalizedString("Tag", comment: "Default context")) -> Tag {
        let tag = Tag(label: label, type: type, color: color, iconName: iconName)
        Task {
            await TagAudit.record(operation: "create", tag: tag, tags: ["create", type.rawValue], actor: actor, context: context, detail: NSLocalizedString("Created tag: \(label)", comment: "Audit detail for tag creation"))
        }
        return tag
    }

    /// Use when editing a Tag's label/type/etc.
    func edited(label: String? = nil, type: TagType? = nil, color: ColorCodable? = nil, iconName: String? = nil, actor: String? = NSLocalizedString("user", comment: "Default actor"), context: String? = NSLocalizedString("Tag", comment: "Default context")) -> Tag {
        let newTag = Tag(
            id: self.id,
            label: label ?? self.label,
            type: type ?? self.type,
            color: color ?? self.color,
            iconName: iconName ?? self.iconName
        )
        Task {
            await TagAudit.record(operation: "edit", tag: newTag, tags: ["edit", newTag.type.rawValue], actor: actor, context: context, detail: NSLocalizedString("Edited tag \(self.label) → \(newTag.label)", comment: "Audit detail for tag edit"))
        }
        return newTag
    }

    /// Call when tag is assigned/used (e.g., attached to appointment)
    func used(actor: String? = NSLocalizedString("user", comment: "Default actor"), context: String? = NSLocalizedString("Tag", comment: "Default context"), detail: String? = nil) -> Tag {
        Task {
            await TagAudit.record(operation: "use", tag: self, tags: ["use", type.rawValue], actor: actor, context: context, detail: detail)
        }
        return self
    }
}

// MARK: - ColorCodable (for storing SwiftUI Colors in Codable structs)
struct ColorCodable: Codable, Hashable {
    let hex: String

    init(hex: String) {
        self.hex = hex
    }

    // Example palette
    static let loyalty   = ColorCodable(hex: "#FFD700")
    static let behavior  = ColorCodable(hex: "#7AC943")
    static let event     = ColorCodable(hex: "#00B0F0")
    static let retention = ColorCodable(hex: "#ED7D31")
    static let health    = ColorCodable(hex: "#A020F0")
    static let custom    = ColorCodable(hex: "#AAAAAA")
    static let defaultColor = ColorCodable(hex: "#E0E0E0")

    var color: Color {
        Color(hex: hex)
    }
}

// MARK: - Color Extension for Hex Strings
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt64()
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 200, 200, 200)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Sample Tags

extension Tag {
    static let sampleTags: [Tag] = [
        Tag.create(label: NSLocalizedString("VIP", comment: "Sample tag label VIP"), type: .loyalty, color: .loyalty, iconName: "star.fill"),
        Tag.create(label: NSLocalizedString("Challenging", comment: "Sample tag label Challenging"), type: .behavior, color: .behavior, iconName: "exclamationmark.triangle.fill"),
        Tag.create(label: NSLocalizedString("Birthday", comment: "Sample tag label Birthday"), type: .event, color: .event, iconName: "gift.fill"),
        Tag.create(label: NSLocalizedString("Retention Risk", comment: "Sample tag label Retention Risk"), type: .retention, color: .retention, iconName: "flag.fill"),
        Tag.create(label: NSLocalizedString("Medical", comment: "Sample tag label Medical"), type: .health, color: .health, iconName: "cross.case.fill"),
        Tag.create(label: NSLocalizedString("Custom", comment: "Sample tag label Custom"), type: .custom, color: .custom, iconName: "tag.fill")
    ]
}

// MARK: - Audit/Admin Accessors

public enum TagAuditAdmin {
    /// Asynchronously fetches the last audit event summary string.
    public static var lastSummary: String {
        get async { await TagAudit.accessibilitySummary }
    }

    /// Asynchronously fetches the last audit event JSON string.
    public static var lastJSON: String? {
        get async { await TagAudit.exportLastJSON() }
    }

    /// Asynchronously fetches recent audit event accessibility labels.
    public static func recentEvents(limit: Int = 5) async -> [String] {
        await TagAudit.recentEvents(limit: limit)
    }

    /// Asynchronously clears the audit log.
    public static func clearAuditLog() async {
        await TagAudit.clearLog()
    }
}

// MARK: - SwiftUI PreviewProvider demonstrating async audit event logging

#if DEBUG
import Combine

struct TagAuditPreviewView: View {
    @State private var auditSummary: String = NSLocalizedString("Loading...", comment: "Loading state for audit summary")
    @State private var auditJSON: String = ""
    @State private var auditEvents: [String] = []
    @State private var cancellables = Set<AnyCancellable>()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(NSLocalizedString("Audit Summary:", comment: "Label for audit summary"))
                .font(.headline)
            ScrollView {
                Text(auditSummary)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .accessibilityIdentifier("auditSummaryText")
            }
            Text(NSLocalizedString("Last Audit Event JSON:", comment: "Label for last audit event JSON"))
                .font(.headline)
            ScrollView {
                Text(auditJSON)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .accessibilityIdentifier("auditJSONText")
            }
            Text(NSLocalizedString("Recent Audit Events:", comment: "Label for recent audit events"))
                .font(.headline)
            List(auditEvents, id: \.self) { event in
                Text(event)
            }
            HStack {
                Button(NSLocalizedString("Add Sample Tag", comment: "Button to add sample tag")) {
                    Task {
                        let newTag = Tag.create(label: NSLocalizedString("Test Async Tag", comment: "Sample tag label for async test"), type: .custom)
                        _ = newTag.used(detail: NSLocalizedString("Used in preview", comment: "Audit detail in preview"))
                        await refreshAuditData()
                    }
                }
                Button(NSLocalizedString("Clear Audit Log", comment: "Button to clear audit log")) {
                    Task {
                        await TagAuditAdmin.clearAuditLog()
                        await refreshAuditData()
                    }
                }
            }
        }
        .padding()
        .task {
            await refreshAuditData()
        }
    }

    /// Refreshes audit data asynchronously.
    func refreshAuditData() async {
        auditSummary = await TagAuditAdmin.lastSummary
        auditJSON = (await TagAuditAdmin.lastJSON) ?? NSLocalizedString("No JSON available.", comment: "No JSON fallback")
        auditEvents = await TagAuditAdmin.recentEvents(limit: 10)
    }
}

struct TagAudit_Previews: PreviewProvider {
    static var previews: some View {
        TagAuditPreviewView()
    }
}
#endif

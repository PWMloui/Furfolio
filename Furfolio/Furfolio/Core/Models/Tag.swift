//
//  Tag.swift
//  Furfolio
//
//  Enhanced 2025: Auditable, Tokenized, Modular Tag Model
//

import Foundation
import SwiftUI

// MARK: - Audit/Event Logging

fileprivate struct TagAuditEvent: Codable {
    let timestamp: Date
    let operation: String         // "create", "edit", "use"
    let tagID: UUID
    let label: String
    let type: Tag.TagType
    let actor: String?
    let context: String?
    let detail: String?
    let tags: [String]
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "[\(operation.capitalized)] \(label) (\(type.rawValue)) [\(tags.joined(separator: ","))] at \(dateStr)\(detail != nil ? ": \(detail!)" : "")"
    }
}

fileprivate final class TagAudit {
    static private(set) var log: [TagAuditEvent] = []

    static func record(
        operation: String,
        tag: Tag,
        tags: [String] = [],
        actor: String? = "system",
        context: String? = "Tag",
        detail: String? = nil
    ) {
        let event = TagAuditEvent(
            timestamp: Date(),
            operation: operation,
            tagID: tag.id,
            label: tag.label,
            type: tag.type,
            actor: actor,
            context: context,
            detail: detail,
            tags: tags
        )
        log.append(event)
        if log.count > 200 { log.removeFirst() }
    }

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No tag audit events recorded."
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
            case .loyalty:   return "Loyalty"
            case .behavior:  return "Behavior"
            case .event:     return "Event"
            case .retention: return "Retention"
            case .health:    return "Health"
            case .custom:    return "Custom"
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
    static func create(label: String, type: TagType, color: ColorCodable = .defaultColor, iconName: String? = nil, actor: String? = "user", context: String? = "Tag") -> Tag {
        let tag = Tag(label: label, type: type, color: color, iconName: iconName)
        TagAudit.record(operation: "create", tag: tag, tags: ["create", type.rawValue], actor: actor, context: context, detail: "Created tag: \(label)")
        return tag
    }

    /// Use when editing a Tag's label/type/etc.
    func edited(label: String? = nil, type: TagType? = nil, color: ColorCodable? = nil, iconName: String? = nil, actor: String? = "user", context: String? = "Tag") -> Tag {
        let newTag = Tag(
            id: self.id,
            label: label ?? self.label,
            type: type ?? self.type,
            color: color ?? self.color,
            iconName: iconName ?? self.iconName
        )
        TagAudit.record(operation: "edit", tag: newTag, tags: ["edit", newTag.type.rawValue], actor: actor, context: context, detail: "Edited tag \(self.label) → \(newTag.label)")
        return newTag
    }

    /// Call when tag is assigned/used (e.g., attached to appointment)
    func used(actor: String? = "user", context: String? = "Tag", detail: String? = nil) -> Tag {
        TagAudit.record(operation: "use", tag: self, tags: ["use", type.rawValue], actor: actor, context: context, detail: detail)
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
        Tag.create(label: "VIP", type: .loyalty, color: .loyalty, iconName: "star.fill"),
        Tag.create(label: "Challenging", type: .behavior, color: .behavior, iconName: "exclamationmark.triangle.fill"),
        Tag.create(label: "Birthday", type: .event, color: .event, iconName: "gift.fill"),
        Tag.create(label: "Retention Risk", type: .retention, color: .retention, iconName: "flag.fill"),
        Tag.create(label: "Medical", type: .health, color: .health, iconName: "cross.case.fill"),
        Tag.create(label: "Custom", type: .custom, color: .custom, iconName: "tag.fill")
    ]
}

// MARK: - Audit/Admin Accessors

public enum TagAuditAdmin {
    public static var lastSummary: String { TagAudit.accessibilitySummary }
    public static var lastJSON: String? { TagAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        TagAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
}

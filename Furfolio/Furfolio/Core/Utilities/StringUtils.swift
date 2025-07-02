//
//  StringUtils.swift
//  Furfolio
//
//  Enhanced 2025: Modular, Tokenized, Auditable String Manipulation Utility
//

import Foundation
import SwiftUI

// MARK: - Analytics & Audit Protocols

public protocol StringUtilsAnalyticsLogger {
    /// Log a string utils event asynchronously.
    func log(function: String, input: String?, result: String?, tags: [String], actor: String?, context: String?) async
}

public protocol StringUtilsAuditLogger {
    /// Record a string utils audit entry asynchronously.
    func record(function: String, input: String?, result: String?, tags: [String], actor: String?, context: String?) async
}

public struct NullStringUtilsAnalyticsLogger: StringUtilsAnalyticsLogger {
    public init() {}
    public func log(function: String, input: String?, result: String?, tags: [String], actor: String?, context: String?) async {}
}

public struct NullStringUtilsAuditLogger: StringUtilsAuditLogger {
    public init() {}
    public func record(function: String, input: String?, result: String?, tags: [String], actor: String?, context: String?) async {}
}

// MARK: - Audit Entry & Manager

/// A record of a StringUtils audit event.
public struct StringUtilsAuditEntry: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let function: String
    public let input: String?
    public let result: String?
    public let tags: [String]
    public let actor: String?
    public let context: String?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        function: String,
        input: String?,
        result: String?,
        tags: [String],
        actor: String?,
        context: String?
    ) {
        self.id = id
        self.timestamp = timestamp
        self.function = function
        self.input = input
        self.result = result
        self.tags = tags
        self.actor = actor
        self.context = context
    }

    public var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "StringUtils \(function) [\(tags.joined(separator: ","))] at \(dateStr)"
    }
}

/// Concurrency-safe actor for logging StringUtils audit events.
public actor StringUtilsAuditManager {
    private var buffer: [StringUtilsAuditEntry] = []
    private let maxEntries = 500
    public static let shared = StringUtilsAuditManager()

    public func add(_ entry: StringUtilsAuditEntry) {
        buffer.append(entry)
        if buffer.count > maxEntries {
            buffer.removeFirst(buffer.count - maxEntries)
        }
    }

    public func recent(limit: Int = 20) -> [StringUtilsAuditEntry] {
        Array(buffer.suffix(limit))
    }

    public func exportLastJSON() -> String? {
        guard let last = buffer.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted; encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(last) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public var accessibilitySummary: String {
        recent(limit: 1).first?.accessibilityLabel ?? "No StringUtils usage recorded."
    }
}

// MARK: - StringUtils (Modular, Tokenized, Auditable String Manipulation Utility)

@frozen
enum StringUtils {
    private static let analytics: StringUtilsAnalyticsLogger = NullStringUtilsAnalyticsLogger()
    private static let audit: StringUtilsAuditLogger = NullStringUtilsAuditLogger()
}


// MARK: - Basic String Manipulations

extension StringUtils {
    static func trimmed(_ string: String?, actor: String? = nil, context: String? = nil) -> String {
        let result = (string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            await analytics.log(function: "trimmed", input: string, result: result, tags: ["trim", "cleanup"], actor: actor, context: context)
            await audit.record(function: "trimmed", input: string, result: result, tags: ["trim", "cleanup"], actor: actor, context: context)
            await StringUtilsAuditManager.shared.add(
                StringUtilsAuditEntry(function: "trimmed", input: string, result: result, tags: ["trim", "cleanup"], actor: actor, context: context)
            )
        }
        return result
    }

    static func capitalizeFirst(_ string: String?, actor: String? = nil, context: String? = nil) -> String {
        let result: String
        if let string = string, !string.isEmpty {
            result = string.prefix(1).uppercased() + string.dropFirst()
        } else {
            result = ""
        }
        Task {
            await analytics.log(function: "capitalizeFirst", input: string, result: result, tags: ["capitalize", "first"], actor: actor, context: context)
            await audit.record(function: "capitalizeFirst", input: string, result: result, tags: ["capitalize", "first"], actor: actor, context: context)
            await StringUtilsAuditManager.shared.add(
                StringUtilsAuditEntry(function: "capitalizeFirst", input: string, result: result, tags: ["capitalize", "first"], actor: actor, context: context)
            )
        }
        return result
    }

    static func isNilOrEmpty(_ string: String?, actor: String? = nil, context: String? = nil) -> Bool {
        let isEmpty = string?.isEmpty ?? true
        Task {
            await analytics.log(function: "isNilOrEmpty", input: string, result: "\(isEmpty)", tags: ["empty", "validation"], actor: actor, context: context)
            await audit.record(function: "isNilOrEmpty", input: string, result: "\(isEmpty)", tags: ["empty", "validation"], actor: actor, context: context)
            await StringUtilsAuditManager.shared.add(
                StringUtilsAuditEntry(function: "isNilOrEmpty", input: string, result: "\(isEmpty)", tags: ["empty", "validation"], actor: actor, context: context)
            )
        }
        return isEmpty
    }
}


// MARK: - Identification & Formatting

extension StringUtils {
    static func initials(from name: String?, actor: String? = nil, context: String? = nil) -> String {
        let result: String
        if let name = name, !name.isEmpty {
            let components = name.split(separator: " ").prefix(2)
            result = components.map { String($0.first ?? Character("")) }.joined().uppercased()
        } else {
            result = ""
        }
        Task {
            await analytics.log(function: "initials", input: name, result: result, tags: ["initials", "id"], actor: actor, context: context)
            await audit.record(function: "initials", input: name, result: result, tags: ["initials", "id"], actor: actor, context: context)
            await StringUtilsAuditManager.shared.add(
                StringUtilsAuditEntry(function: "initials", input: name, result: result, tags: ["initials", "id"], actor: actor, context: context)
            )
        }
        return result
    }

    static func mask(_ string: String?, showLast n: Int = 4, maskChar: Character = "*", actor: String? = nil, context: String? = nil) -> String {
        let result: String
        if let string = string, string.count > n {
            let maskCount = string.count - n
            let mask = String(repeating: maskChar, count: maskCount)
            let suffix = String(string.suffix(n))
            result = mask + suffix
        } else {
            result = string ?? ""
        }
        Task {
            await analytics.log(function: "mask", input: string, result: result, tags: ["mask", "privacy"], actor: actor, context: context)
            await audit.record(function: "mask", input: string, result: result, tags: ["mask", "privacy"], actor: actor, context: context)
            await StringUtilsAuditManager.shared.add(
                StringUtilsAuditEntry(function: "mask", input: string, result: result, tags: ["mask", "privacy"], actor: actor, context: context)
            )
        }
        return result
    }

    static func truncated(_ string: String?, length: Int, actor: String? = nil, context: String? = nil) -> String {
        let result: String
        if let string = string, string.count > length {
            let index = string.index(string.startIndex, offsetBy: length)
            result = String(string[..<index]) + "…"
        } else {
            result = string ?? ""
        }
        Task {
            await analytics.log(function: "truncated", input: string, result: result, tags: ["truncate", "ellipsis"], actor: actor, context: context)
            await audit.record(function: "truncated", input: string, result: result, tags: ["truncate", "ellipsis"], actor: actor, context: context)
            await StringUtilsAuditManager.shared.add(
                StringUtilsAuditEntry(function: "truncated", input: string, result: result, tags: ["truncate", "ellipsis"], actor: actor, context: context)
            )
        }
        return result
    }
}


// MARK: - Validation & Normalization

extension StringUtils {
    static func isValidEmail(_ string: String?, actor: String? = nil, context: String? = nil) -> Bool {
        guard let string = string else {
            Task {
                await analytics.log(function: "isValidEmail", input: string, result: "false", tags: ["email", "validation"], actor: actor, context: context)
                await audit.record(function: "isValidEmail", input: string, result: "false", tags: ["email", "validation"], actor: actor, context: context)
                await StringUtilsAuditManager.shared.add(
                    StringUtilsAuditEntry(function: "isValidEmail", input: string, result: "false", tags: ["email", "validation"], actor: actor, context: context)
                )
            }
            return false
        }
        let pattern = #"^\S+@\S+\.\S+$"#
        let result = string.range(of: pattern, options: .regularExpression) != nil
        Task {
            await analytics.log(function: "isValidEmail", input: string, result: "\(result)", tags: ["email", "validation"], actor: actor, context: context)
            await audit.record(function: "isValidEmail", input: string, result: "\(result)", tags: ["email", "validation"], actor: actor, context: context)
            await StringUtilsAuditManager.shared.add(
                StringUtilsAuditEntry(function: "isValidEmail", input: string, result: "\(result)", tags: ["email", "validation"], actor: actor, context: context)
            )
        }
        return result
    }

    static func isValidPhone(_ string: String?, actor: String? = nil, context: String? = nil) -> Bool {
        let digits = string?.filter { $0.isNumber } ?? ""
        let result = (10...15).contains(digits.count)
        Task {
            await analytics.log(function: "isValidPhone", input: string, result: "\(result)", tags: ["phone", "validation"], actor: actor, context: context)
            await audit.record(function: "isValidPhone", input: string, result: "\(result)", tags: ["phone", "validation"], actor: actor, context: context)
            await StringUtilsAuditManager.shared.add(
                StringUtilsAuditEntry(function: "isValidPhone", input: string, result: "\(result)", tags: ["phone", "validation"], actor: actor, context: context)
            )
        }
        return result
    }

    static func normalized(_ string: String?, actor: String? = nil, context: String? = nil) -> String {
        let result: String
        if let string = string {
            result = string.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        } else {
            result = ""
        }
        Task {
            await analytics.log(function: "normalized", input: string, result: result, tags: ["normalize", "search"], actor: actor, context: context)
            await audit.record(function: "normalized", input: string, result: result, tags: ["normalize", "search"], actor: actor, context: context)
            await StringUtilsAuditManager.shared.add(
                StringUtilsAuditEntry(function: "normalized", input: string, result: result, tags: ["normalize", "search"], actor: actor, context: context)
            )
        }
        return result
    }
}


// MARK: - Formatting Helpers

extension StringUtils {
    static func formatUSPhone(_ string: String?, actor: String? = nil, context: String? = nil) -> String {
        let result: String
        if let string = string {
            let digits = string.filter { $0.isNumber }
            if digits.count == 10 {
                let area = digits.prefix(3)
                let mid = digits.dropFirst(3).prefix(3)
                let last = digits.suffix(4)
                result = "(\(area)) \(mid)-\(last)"
            } else {
                result = string
            }
        } else {
            result = ""
        }
        Task {
            await analytics.log(function: "formatUSPhone", input: string, result: result, tags: ["phone", "us", "format"], actor: actor, context: context)
            await audit.record(function: "formatUSPhone", input: string, result: result, tags: ["phone", "us", "format"], actor: actor, context: context)
            await StringUtilsAuditManager.shared.add(
                StringUtilsAuditEntry(function: "formatUSPhone", input: string, result: result, tags: ["phone", "us", "format"], actor: actor, context: context)
            )
        }
        return result
    }

    static func formatInternationalPhone(_ string: String?, actor: String? = nil, context: String? = nil) -> String {
        let result = string ?? ""
        Task {
            await analytics.log(function: "formatInternationalPhone", input: string, result: result, tags: ["phone", "intl", "format"], actor: actor, context: context)
            await audit.record(function: "formatInternationalPhone", input: string, result: result, tags: ["phone", "intl", "format"], actor: actor, context: context)
            await StringUtilsAuditManager.shared.add(
                StringUtilsAuditEntry(function: "formatInternationalPhone", input: string, result: result, tags: ["phone", "intl", "format"], actor: actor, context: context)
            )
        }
        return result
    }
}


// MARK: - String Cleaning & Conversion

extension StringUtils {
    static func removingSpecialCharacters(_ string: String?, actor: String? = nil, context: String? = nil) -> String {
        let result: String
        if let string = string {
            let allowed = CharacterSet.alphanumerics.union(.whitespaces)
            result = string.unicodeScalars.filter { allowed.contains($0) }.map { String($0) }.joined()
        } else {
            result = ""
        }
        Task {
            await analytics.log(function: "removingSpecialCharacters", input: string, result: result, tags: ["clean", "sanitize"], actor: actor, context: context)
            await audit.record(function: "removingSpecialCharacters", input: string, result: result, tags: ["clean", "sanitize"], actor: actor, context: context)
            await StringUtilsAuditManager.shared.add(
                StringUtilsAuditEntry(function: "removingSpecialCharacters", input: string, result: result, tags: ["clean", "sanitize"], actor: actor, context: context)
            )
        }
        return result
    }

    static func slugify(_ string: String?, actor: String? = nil, context: String? = nil) -> String {
        var result = ""
        if let string = string {
            let lowercased = string.lowercased()
            let trimmed = trimmed(lowercased)
            let noDiacritics = trimmed.folding(options: .diacriticInsensitive, locale: .current)
            let alphanumeric = noDiacritics.unicodeScalars.map { scalar -> String in
                if CharacterSet.alphanumerics.contains(scalar) {
                    return String(scalar)
                } else if CharacterSet.whitespaces.contains(scalar) {
                    return "-"
                } else {
                    return ""
                }
            }.joined()
            let condensed = alphanumeric.replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
            result = condensed.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        }
        Task {
            await analytics.log(function: "slugify", input: string, result: result, tags: ["slug", "url"], actor: actor, context: context)
            await audit.record(function: "slugify", input: string, result: result, tags: ["slug", "url"], actor: actor, context: context)
            await StringUtilsAuditManager.shared.add(
                StringUtilsAuditEntry(function: "slugify", input: string, result: result, tags: ["slug", "url"], actor: actor, context: context)
            )
        }
        return result
    }

    static func humanize(_ string: String?, actor: String? = nil, context: String? = nil) -> String {
        var result = ""
        if let string = string {
            let snakeReplaced = string.replacingOccurrences(of: "_", with: " ")
            let pattern = #"([a-z])([A-Z])"#
            let regex = try? NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(location: 0, length: snakeReplaced.utf16.count)
            let camelSpaced = regex?.stringByReplacingMatches(in: snakeReplaced, options: [], range: range, withTemplate: "$1 $2") ?? snakeReplaced
            result = camelSpaced.capitalized
        }
        Task {
            await analytics.log(function: "humanize", input: string, result: result, tags: ["humanize", "display"], actor: actor, context: context)
            await audit.record(function: "humanize", input: string, result: result, tags: ["humanize", "display"], actor: actor, context: context)
            await StringUtilsAuditManager.shared.add(
                StringUtilsAuditEntry(function: "humanize", input: string, result: result, tags: ["humanize", "display"], actor: actor, context: context)
            )
        }
        return result
    }
}


// MARK: - Random Code Generation

extension StringUtils {
    static func randomShortCode(length: Int = 8, actor: String? = nil, context: String? = nil) -> String {
        let characters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        var code = ""
        for _ in 0..<length {
            if let char = characters.randomElement() {
                code.append(char)
            }
        }
        Task {
            await analytics.log(function: "randomShortCode", input: "\(length)", result: code, tags: ["random", "code"], actor: actor, context: context)
            await audit.record(function: "randomShortCode", input: "\(length)", result: code, tags: ["random", "code"], actor: actor, context: context)
            await StringUtilsAuditManager.shared.add(
                StringUtilsAuditEntry(function: "randomShortCode", input: "\(length)", result: code, tags: ["random", "code"], actor: actor, context: context)
            )
        }
        return code
    }
}

// MARK: - Admin/QA Accessors

public enum StringUtilsAuditAdmin {
    public static func lastSummary() async -> String {
        await StringUtilsAuditManager.shared.accessibilitySummary
    }
    public static func lastJSON() async -> String? {
        await StringUtilsAuditManager.shared.exportLastJSON()
    }
    public static func recentEvents(limit: Int = 5) async -> [String] {
        await StringUtilsAuditManager.shared.recent(limit: limit)
            .map { $0.accessibilityLabel }
    }
}

#if DEBUG
// MARK: - Example Usage / Playground
func stringUtilsDemo() {
    _ = StringUtils.trimmed("  demo  ", actor: "unit-test")
    _ = StringUtils.capitalizeFirst("furfolio", actor: "unit-test")
    _ = StringUtils.initials(from: "Jane Doe", actor: "preview")
    _ = StringUtils.mask("1234567890", actor: "admin")
    _ = StringUtils.truncated("1234567890", length: 5, actor: "debug")
    _ = StringUtils.isValidEmail("hello@furfolio.com", actor: "preview")
    _ = StringUtils.isValidPhone("415-555-7890", actor: "unit-test")
    _ = StringUtils.normalized("Čača", actor: "search")
    _ = StringUtils.formatUSPhone("4155557890", actor: "ui")
    _ = StringUtils.slugify("Hello World!", actor: "preview")
    _ = StringUtils.humanize("firstName", actor: "unit-test")
    _ = StringUtils.randomShortCode(length: 8, actor: "test")
    print("StringUtils audit log:")
    Task {
        let events = await StringUtilsAuditManager.shared.recent(limit: 100)
        for event in events { print(event.accessibilityLabel) }
        if let json = await StringUtilsAuditManager.shared.exportLastJSON() {
            print("Last event JSON:\n\(json)")
        }
    }
}
#endif

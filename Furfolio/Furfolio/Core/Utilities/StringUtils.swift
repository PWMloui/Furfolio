//
//  StringUtils.swift
//  Furfolio
//
//  Enhanced 2025: Modular, Tokenized, Auditable String Manipulation Utility
//

import Foundation

// MARK: - Audit/Event Logging for StringUtils

fileprivate struct StringUtilsAuditEvent: Codable {
    let timestamp: Date
    let function: String
    let input: String?
    let result: String?
    let tags: [String]
    let actor: String?
    let context: String?
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "StringUtils \(function) [\(tags.joined(separator: ","))] at \(dateStr)"
    }
}

fileprivate final class StringUtilsAudit {
    static private(set) var log: [StringUtilsAuditEvent] = []

    static func record(
        function: String,
        input: String?,
        result: String?,
        tags: [String],
        actor: String? = nil,
        context: String? = nil
    ) {
        let event = StringUtilsAuditEvent(
            timestamp: Date(),
            function: function,
            input: input,
            result: result,
            tags: tags,
            actor: actor,
            context: context
        )
        log.append(event)
        if log.count > 500 { log.removeFirst() }
    }

    static func exportLastJSON() -> String? {
        guard let last = log.last else { return nil }
        let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
        return (try? encoder.encode(last)).flatMap { String(data: $0, encoding: .utf8) }
    }

    static var accessibilitySummary: String {
        log.last?.accessibilityLabel ?? "No StringUtils usage recorded."
    }
}

// MARK: - StringUtils (Modular, Tokenized, Auditable String Manipulation Utility)

@frozen
enum StringUtils {}


// MARK: - Basic String Manipulations

extension StringUtils {
    static func trimmed(_ string: String?, actor: String? = nil, context: String? = nil) -> String {
        let result = (string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        StringUtilsAudit.record(function: "trimmed", input: string, result: result, tags: ["trim", "cleanup"], actor: actor, context: context)
        return result
    }

    static func capitalizeFirst(_ string: String?, actor: String? = nil, context: String? = nil) -> String {
        let result: String
        if let string = string, !string.isEmpty {
            result = string.prefix(1).uppercased() + string.dropFirst()
        } else {
            result = ""
        }
        StringUtilsAudit.record(function: "capitalizeFirst", input: string, result: result, tags: ["capitalize", "first"], actor: actor, context: context)
        return result
    }

    static func isNilOrEmpty(_ string: String?, actor: String? = nil, context: String? = nil) -> Bool {
        let isEmpty = string?.isEmpty ?? true
        StringUtilsAudit.record(function: "isNilOrEmpty", input: string, result: "\(isEmpty)", tags: ["empty", "validation"], actor: actor, context: context)
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
        StringUtilsAudit.record(function: "initials", input: name, result: result, tags: ["initials", "id"], actor: actor, context: context)
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
        StringUtilsAudit.record(function: "mask", input: string, result: result, tags: ["mask", "privacy"], actor: actor, context: context)
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
        StringUtilsAudit.record(function: "truncated", input: string, result: result, tags: ["truncate", "ellipsis"], actor: actor, context: context)
        return result
    }
}


// MARK: - Validation & Normalization

extension StringUtils {
    static func isValidEmail(_ string: String?, actor: String? = nil, context: String? = nil) -> Bool {
        guard let string = string else {
            StringUtilsAudit.record(function: "isValidEmail", input: string, result: "false", tags: ["email", "validation"], actor: actor, context: context)
            return false
        }
        let pattern = #"^\S+@\S+\.\S+$"#
        let result = string.range(of: pattern, options: .regularExpression) != nil
        StringUtilsAudit.record(function: "isValidEmail", input: string, result: "\(result)", tags: ["email", "validation"], actor: actor, context: context)
        return result
    }

    static func isValidPhone(_ string: String?, actor: String? = nil, context: String? = nil) -> Bool {
        let digits = string?.filter { $0.isNumber } ?? ""
        let result = (10...15).contains(digits.count)
        StringUtilsAudit.record(function: "isValidPhone", input: string, result: "\(result)", tags: ["phone", "validation"], actor: actor, context: context)
        return result
    }

    static func normalized(_ string: String?, actor: String? = nil, context: String? = nil) -> String {
        let result: String
        if let string = string {
            result = string.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        } else {
            result = ""
        }
        StringUtilsAudit.record(function: "normalized", input: string, result: result, tags: ["normalize", "search"], actor: actor, context: context)
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
        StringUtilsAudit.record(function: "formatUSPhone", input: string, result: result, tags: ["phone", "us", "format"], actor: actor, context: context)
        return result
    }

    static func formatInternationalPhone(_ string: String?, actor: String? = nil, context: String? = nil) -> String {
        let result = string ?? ""
        StringUtilsAudit.record(function: "formatInternationalPhone", input: string, result: result, tags: ["phone", "intl", "format"], actor: actor, context: context)
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
        StringUtilsAudit.record(function: "removingSpecialCharacters", input: string, result: result, tags: ["clean", "sanitize"], actor: actor, context: context)
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
        StringUtilsAudit.record(function: "slugify", input: string, result: result, tags: ["slug", "url"], actor: actor, context: context)
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
        StringUtilsAudit.record(function: "humanize", input: string, result: result, tags: ["humanize", "display"], actor: actor, context: context)
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
        StringUtilsAudit.record(function: "randomShortCode", input: "\(length)", result: code, tags: ["random", "code"], actor: actor, context: context)
        return code
    }
}

// MARK: - Admin/QA Accessors

public enum StringUtilsAuditAdmin {
    public static var lastSummary: String { StringUtilsAudit.accessibilitySummary }
    public static var lastJSON: String? { StringUtilsAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        StringUtilsAudit.log.suffix(limit).map { $0.accessibilityLabel }
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
    for event in StringUtilsAudit.log { print(event.accessibilityLabel) }
    if let json = StringUtilsAudit.exportLastJSON() {
        print("Last event JSON:\n\(json)")
    }
}
#endif

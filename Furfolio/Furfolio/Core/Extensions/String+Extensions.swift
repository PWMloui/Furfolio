//
//  String+Extensions.swift
//  Furfolio
//
//  Enhanced 2025: Common, Auditable, Accessible, BI-Ready String extensions for Furfolio.
//

import Foundation

// MARK: - Audit/Event Logging for String Extensions

fileprivate struct StringExtensionAuditEvent: Codable {
    let timestamp: Date
    let function: String
    let input: String?
    let result: String?
    let tags: [String]
    let actor: String?
    let context: String?
    var accessibilityLabel: String {
        let dateStr = DateFormatter.localizedString(from: timestamp, dateStyle: .short, timeStyle: .short)
        return "String extension \(function) [\(tags.joined(separator: ","))] at \(dateStr)"
    }
}

fileprivate final class StringExtensionAudit {
    static private(set) var log: [StringExtensionAuditEvent] = []

    static func record(
        function: String,
        input: String?,
        result: String?,
        tags: [String],
        actor: String? = nil,
        context: String? = nil
    ) {
        let event = StringExtensionAuditEvent(
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
        log.last?.accessibilityLabel ?? "No String extension usage recorded."
    }
}

// MARK: - String Extensions

public extension String {

    /// Trims whitespace and newlines from both ends.
    func trimmed(actor: String? = nil, context: String? = nil) -> String {
        let result = trimmingCharacters(in: .whitespacesAndNewlines)
        StringExtensionAudit.record(function: "trimmed", input: self, result: result, tags: ["trim", "cleanup"], actor: actor, context: context)
        return result
    }

    /// Returns true if string is a valid email address.
    func isValidEmail(actor: String? = nil, context: String? = nil) -> Bool {
        let pattern = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        let result = range(of: pattern, options: .regularExpression) != nil
        StringExtensionAudit.record(function: "isValidEmail", input: self, result: "\(result)", tags: ["validation", "email"], actor: actor, context: context)
        return result
    }

    /// Returns true if string contains only digits.
    func isNumeric(actor: String? = nil, context: String? = nil) -> Bool {
        let result = !isEmpty && allSatisfy { $0.isNumber }
        StringExtensionAudit.record(function: "isNumeric", input: self, result: "\(result)", tags: ["validation", "numeric"], actor: actor, context: context)
        return result
    }

    /// Capitalizes first letter.
    func capitalizedFirst(actor: String? = nil, context: String? = nil) -> String {
        guard let first = first else {
            StringExtensionAudit.record(function: "capitalizedFirst", input: self, result: self, tags: ["capitalize"], actor: actor, context: context)
            return self
        }
        let result = String(first).uppercased() + dropFirst()
        StringExtensionAudit.record(function: "capitalizedFirst", input: self, result: result, tags: ["capitalize"], actor: actor, context: context)
        return result
    }

    /// Safe substring with bounds check.
    func safeSubstring(from: Int, length: Int, actor: String? = nil, context: String? = nil) -> String {
        guard from >= 0, length > 0, from < count else {
            StringExtensionAudit.record(function: "safeSubstring", input: self, result: "", tags: ["substring", "safety"], actor: actor, context: context)
            return ""
        }
        let start = index(startIndex, offsetBy: from)
        let end = index(start, offsetBy: min(length, count - from), limitedBy: endIndex) ?? endIndex
        let result = String(self[start..<end])
        StringExtensionAudit.record(function: "safeSubstring", input: self, result: result, tags: ["substring", "safety"], actor: actor, context: context)
        return result
    }

    /// Converts to localized string (if available in Localizable.strings)
    func localized(bundle: Bundle = .main, comment: String = "", actor: String? = nil, context: String? = nil) -> String {
        let result = NSLocalizedString(self, bundle: bundle, comment: comment)
        StringExtensionAudit.record(function: "localized", input: self, result: result, tags: ["localization"], actor: actor, context: context)
        return result
    }
}

// MARK: - Admin/QA Static Accessors

public enum StringExtensionAuditAdmin {
    public static var lastSummary: String { StringExtensionAudit.accessibilitySummary }
    public static var lastJSON: String? { StringExtensionAudit.exportLastJSON() }
    public static func recentEvents(limit: Int = 5) -> [String] {
        StringExtensionAudit.log.suffix(limit).map { $0.accessibilityLabel }
    }
}

#if DEBUG
// MARK: - Example Usage / Playground
func stringExtensionsDemo() {
    let email = "hello@furfolio.com"
    _ = email.isValidEmail(actor: "preview")
    _ = "  hello world  ".trimmed(actor: "unit-test")
    _ = "abc123".isNumeric(actor: "admin")
    _ = "puppy".capitalizedFirst(actor: "unit-test")
    _ = "123456789".safeSubstring(from: 3, length: 4, actor: "debug")
    _ = "welcome_title".localized(actor: "ui")
    print("StringExtensions audit log:")
    for event in StringExtensionAudit.log { print(event.accessibilityLabel) }
    if let json = StringExtensionAudit.exportLastJSON() {
        print("Last event JSON:\n\(json)")
    }
}
#endif

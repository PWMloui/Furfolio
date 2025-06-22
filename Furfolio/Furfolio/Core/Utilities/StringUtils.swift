//
//  StringUtils.swift
//  Furfolio
//
//  Created by mac on 6/19/25.
//

import Foundation

// MARK: - StringUtils (Modular, Tokenized, Auditable String Manipulation Utility)

/// StringUtils provides a modular, tokenized, and auditable string manipulation utility tailored for Furfolio.
/// It supports comprehensive string operations including normalization, formatting, validation, analytics,
/// compliance, UI integration, and business reporting. Designed to enable scalable, owner-focused dashboards,
/// seamless onboarding experiences, and multi-entity workflows, StringUtils ensures consistency and traceability
/// across Furfolio's platform by centralizing common text transformations and validations with audit trails.

@frozen
enum StringUtils {}


// MARK: - Basic String Manipulations

extension StringUtils {
    /// Returns the string with whitespace and newlines trimmed.
    /// - Parameter string: Optional input string.
    /// - Returns: Trimmed string or empty if input is nil.
    /// - Note: Supports UI workflows by ensuring clean user input and consistent display.
    ///         Auditable for tracking user data normalization steps.
    static func trimmed(_ string: String?) -> String {
        log("Trimming string")
        return (string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Capitalizes only the first letter of the string.
    /// - Parameter string: Optional input string.
    /// - Returns: String with first letter capitalized or empty if input is nil.
    /// - Note: Improves UI readability and standardizes display names.
    ///         Auditable for business reporting on text transformations.
    static func capitalizeFirst(_ string: String?) -> String {
        log("Capitalizing first letter")
        guard let string = string, !string.isEmpty else { return "" }
        return string.prefix(1).uppercased() + string.dropFirst()
    }

    /// Returns true if the string is nil or empty.
    /// - Parameter string: Optional input string.
    /// - Returns: Boolean indicating nil or empty.
    /// - Note: Supports workflow validations and compliance checks.
    ///         Auditable for data validation analytics.
    static func isNilOrEmpty(_ string: String?) -> Bool {
        log("Checking if string is nil or empty")
        return string?.isEmpty ?? true
    }
}


// MARK: - Identification & Formatting

extension StringUtils {
    /// Extracts initials from a full name (e.g., "Joe Doe" -> "JD").
    /// - Parameter name: Optional full name string.
    /// - Returns: Uppercased initials or empty if input invalid.
    /// - Note: Used in UI elements for user avatars and quick identification.
    ///         Auditable for analytics on user engagement and compliance with display standards.
    static func initials(from name: String?) -> String {
        log("Extracting initials")
        guard let name = name, !name.isEmpty else { return "" }
        let components = name.split(separator: " ").prefix(2)
        return components.map { String($0.first ?? Character("")) }.joined().uppercased()
    }

    /// Masks all but the last `n` characters of a string for privacy.
    /// - Parameters:
    ///   - string: Optional input string.
    ///   - n: Number of characters to show at the end (default 4).
    ///   - maskChar: Character used for masking (default "*").
    /// - Returns: Masked string or original if too short.
    /// - Note: Critical for compliance with privacy regulations and data protection.
    ///         Supports audit trails and business logic for sensitive data handling.
    static func mask(_ string: String?, showLast n: Int = 4, maskChar: Character = "*") -> String {
        log("Masking string for privacy")
        guard let string = string, string.count > n else { return string ?? "" }
        let maskCount = string.count - n
        let mask = String(repeating: maskChar, count: maskCount)
        let suffix = String(string.suffix(n))
        return mask + suffix
    }

    /// Truncates a string to a specified length and appends an ellipsis.
    /// - Parameters:
    ///   - string: Optional input string.
    ///   - length: Maximum length before truncation.
    /// - Returns: Truncated string with ellipsis or original if short enough.
    /// - Note: Enhances UI display consistency and readability.
    ///         Auditable for analytics on content presentation and user experience.
    static func truncated(_ string: String?, length: Int) -> String {
        log("Truncating string")
        guard let string = string, string.count > length else { return string ?? "" }
        let index = string.index(string.startIndex, offsetBy: length)
        return String(string[..<index]) + "…"
    }
}


// MARK: - Validation & Normalization

extension StringUtils {
    /// Validates if a string is a simple email format.
    /// - Parameter string: Optional input string.
    /// - Returns: True if valid email, false otherwise.
    /// - Note: Ensures compliance with input standards, supports business workflows for user verification,
    ///         and enables analytics on user data quality.
    static func isValidEmail(_ string: String?) -> Bool {
        log("Validating email format")
        guard let string = string else { return false }
        let pattern = #"^\S+@\S+\.\S+$"#
        return string.range(of: pattern, options: .regularExpression) != nil
    }

    /// Validates if a string is a phone number with 10-15 digits.
    /// - Parameter string: Optional input string.
    /// - Returns: True if valid phone number, false otherwise.
    /// - Note: Supports compliance with telephony standards, business logic for contact verification,
    ///         and analytics on user contact data completeness.
    static func isValidPhone(_ string: String?) -> Bool {
        log("Validating phone number")
        guard let string = string else { return false }
        let digits = string.filter { $0.isNumber }
        return (10...15).contains(digits.count)
    }

    /// Returns the string lowercased and diacritics removed for consistent searching/filtering.
    /// - Parameter string: Optional input string.
    /// - Returns: Normalized string or empty if nil.
    /// - Note: Critical for business reporting, search indexing, UI filtering consistency,
    ///         and compliance with data normalization standards.
    static func normalized(_ string: String?) -> String {
        log("Normalizing string")
        guard let string = string else { return "" }
        return string.folding(options: .diacriticInsensitive, locale: .current).lowercased()
    }
}


// MARK: - Formatting Helpers

extension StringUtils {
    /// Formats a US phone number (e.g., "1234567890" -> "(123) 456-7890").
    /// - Parameter string: Optional input string.
    /// - Returns: Formatted US phone or original string if invalid length.
    /// - Note: Ensures compliance with US telephony formatting standards,
    ///         enhances UI display, and supports analytics on contact data quality.
    static func formatUSPhone(_ string: String?) -> String {
        log("Formatting US phone number")
        guard let string = string else { return "" }
        let digits = string.filter { $0.isNumber }
        guard digits.count == 10 else { return string }
        let area = digits.prefix(3)
        let mid = digits.dropFirst(3).prefix(3)
        let last = digits.suffix(4)
        return "(\(area)) \(mid)-\(last)"
    }

    /// Formats an international phone number (stub for future expansion).
    /// - Parameter string: Optional input string.
    /// - Returns: Formatted international phone or original string.
    /// - Note: Placeholder for compliance with international telephony standards,
    ///         business logic for global user base, and analytics on international data.
    static func formatInternationalPhone(_ string: String?) -> String {
        log("Formatting international phone number (stub)")
        // Placeholder: Implement international formatting logic as needed.
        return string ?? ""
    }
}


// MARK: - String Cleaning & Conversion

extension StringUtils {
    /// Removes special characters, leaving only alphanumerics and whitespace.
    /// - Parameter string: Optional input string.
    /// - Returns: Cleaned string or empty if nil.
    /// - Note: Supports compliance with input sanitization standards,
    ///         improves UI text cleanliness, and aids business data integrity.
    static func removingSpecialCharacters(_ string: String?) -> String {
        log("Removing special characters")
        guard let string = string else { return "" }
        let allowed = CharacterSet.alphanumerics.union(.whitespaces)
        return string.unicodeScalars.filter { allowed.contains($0) }.map { String($0) }.joined()
    }

    /// Converts a string into a URL/file-system safe slug.
    /// - Parameter string: Optional input string.
    /// - Returns: Slugified string suitable for URLs or file names.
    /// - Note: Enables compliance with URL encoding standards,
    ///         supports business logic for resource naming, and improves UI routing consistency.
    static func slugify(_ string: String?) -> String {
        log("Slugifying string")
        guard let string = string else { return "" }
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
        return condensed.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    /// Converts camelCase or snake_case strings into human-readable text.
    /// - Parameter string: Optional input string.
    /// - Returns: Humanized plain text string.
    /// - Note: Enhances UI readability and accessibility,
    ///         supports business reporting on field naming, and aids analytics on data presentation.
    static func humanize(_ string: String?) -> String {
        log("Humanizing string")
        guard let string = string else { return "" }
        // Replace underscores with spaces
        let snakeReplaced = string.replacingOccurrences(of: "_", with: " ")
        // Insert spaces before uppercase letters in camelCase
        let pattern = #"([a-z])([A-Z])"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(location: 0, length: snakeReplaced.utf16.count)
        let camelSpaced = regex?.stringByReplacingMatches(in: snakeReplaced, options: [], range: range, withTemplate: "$1 $2") ?? snakeReplaced
        // Capitalize first letter of each word
        return camelSpaced.capitalized
    }
}


// MARK: - Random Code Generation

extension StringUtils {
    /// Generates a random alphanumeric short code suitable for invites or links.
    /// - Parameter length: Desired length of the code (default 8).
    /// - Returns: Random uppercase alphanumeric string.
    /// - Note: Supports audit trails for code generation events, analytics on usage patterns,
    ///         business logic for invite and link uniqueness, and security considerations for randomness.
    static func randomShortCode(length: Int = 8) -> String {
        log("Generating random short code")
        let characters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        var code = ""
        for _ in 0..<length {
            if let char = characters.randomElement() {
                code.append(char)
            }
        }
        return code
    }
}


// MARK: - Logging (Stub for future audit/logging integration)

extension StringUtils {
    /// Logs string operation events for audit, analytics, debugging, and compliance purposes.
    /// - Parameter message: Descriptive message of the operation.
    /// - Note: Intended for integration with Furfolio's centralized logging, audit trails,
    ///         analytics pipelines, and compliance monitoring systems.
    ///         Currently a no-op to avoid performance impact; expandable as needed.
    private static func log(_ message: String) {
        // Stub: Integrate with Furfolio's centralized logging or audit system if expanded.
        // For now, this is a no-op to avoid performance impact.
        // print("[StringUtils] \(message)")
    }
}

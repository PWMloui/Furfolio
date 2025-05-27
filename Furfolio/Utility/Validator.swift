//
//  Validator.swift
//  Furfolio
//
//  Created by mac on 5/26/25.
//

import Foundation

/// A utility for validating common input fields.
enum Validator {
    /// Validates that a string is non-empty after trimming whitespace.
    static func nonEmpty(_ value: String?, fieldName: String) -> Bool {
        guard let v = value?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty else {
            print("Validation failed: \(fieldName) must not be empty.")
            return false
        }
        return true
    }

    /// Validates an email address format using a basic regex.
    static func email(_ value: String?) -> Bool {
        guard let email = value?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty else {
            print("Validation failed: Email must not be empty.")
            return false
        }
        let pattern = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(location: 0, length: email.utf16.count)
        if regex?.firstMatch(in: email, options: [], range: range) == nil {
            print("Validation failed: Email format is invalid.")
            return false
        }
        return true
    }

    /// Validates a phone number contains only digits and is within a length range.
    static func phone(_ value: String?, minLength: Int = 7, maxLength: Int = 15) -> Bool {
        guard let number = value?.trimmingCharacters(in: .whitespacesAndNewlines), !number.isEmpty else {
            print("Validation failed: Phone number must not be empty.")
            return false
        }
        let digits = number.filter(\.isNumber)
        if digits.count < minLength || digits.count > maxLength {
            print("Validation failed: Phone number must be between \(minLength) and \(maxLength) digits.")
            return false
        }
        return true
    }

    /// Validates that a numeric value falls within a specified range.
    static func range<T: Comparable>(_ value: T, min: T, max: T, fieldName: String) -> Bool {
        if value < min || value > max {
            print("Validation failed: \(fieldName) must be between \(min) and \(max).")
            return false
        }
        return true
    }
}


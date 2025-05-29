//
//  Validator.swift
//  Furfolio
//
//  Created by mac on 5/26/25.
//

import Foundation
import os

/// A utility for validating common input fields.
enum Validator {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "Validator")
    private static let emailRegex: NSRegularExpression = {
        try! NSRegularExpression(
            pattern: #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#,
            options: []
        )
    }()
    private static let phoneRegex: NSRegularExpression = {
        try! NSRegularExpression(
            pattern: #"^[0-9]{7,15}$"#,
            options: []
        )
    }()

    /// Validates that a string is non-empty after trimming whitespace.
    static func nonEmpty(_ value: String?, fieldName: String) -> Bool {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        logger.log("nonEmpty validation started for field '\(fieldName)' with value: '\(trimmed)'")
        guard !trimmed.isEmpty else {
            logger.error("Validation failed: \(fieldName) must not be empty.")
            return false
        }
        logger.log("nonEmpty validation succeeded for field '\(fieldName)'")
        return true
    }

    /// Validates an email address format using a basic regex.
    static func email(_ value: String?) -> Bool {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        logger.log("email validation started with value: '\(trimmed)'")
        guard !trimmed.isEmpty else {
            logger.error("Validation failed: Email must not be empty.")
            return false
        }
        let range = NSRange(location: 0, length: trimmed.utf16.count)
        if Self.emailRegex.firstMatch(in: trimmed, options: [], range: range) == nil {
            logger.error("Validation failed: Email format is invalid.")
            return false
        }
        logger.log("email validation succeeded for value: '\(trimmed)'")
        return true
    }

    /// Validates a phone number contains only digits and is within a length range.
    static func phone(_ value: String?, minLength: Int = 7, maxLength: Int = 15) -> Bool {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        logger.log("phone validation started with value: '\(trimmed)', minLength: \(minLength), maxLength: \(maxLength)")
        guard !trimmed.isEmpty else {
            logger.error("Validation failed: Phone number must not be empty.")
            return false
        }
        let number = trimmed.filter(\.isNumber)
        let range = NSRange(location: 0, length: number.utf16.count)
        if Self.phoneRegex.firstMatch(in: number, options: [], range: range) == nil {
            logger.error("Validation failed: Phone format is invalid.")
            return false
        }
        logger.log("phone validation succeeded for value: '\(number)'")
        return true
    }

    /// Validates that a numeric value falls within a specified range.
    static func range<T: Comparable>(_ value: T, min: T, max: T, fieldName: String) -> Bool {
        logger.log("range validation started for field '\(fieldName)' with value: \(value), range: \(min)-\(max)")
        if value < min || value > max {
            logger.error("Validation failed: \(fieldName) must be between \(min) and \(max).")
            return false
        }
        logger.log("range validation succeeded for field '\(fieldName)' with value: \(value)")
        return true
    }
}

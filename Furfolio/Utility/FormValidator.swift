//
//  FormValidator.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//

import Foundation
import os

enum ValidationError: LocalizedError {
    case requiredField(name: String)
    case invalidEmail
    case invalidPhone
    case invalidAmount
    case dateInPast
    case custom(String)

    var errorDescription: String? {
        switch self {
        case .requiredField(let name):
            return "\(name) is required."
        case .invalidEmail:
            return "Please enter a valid email address."
        case .invalidPhone:
            return "Please enter a valid phone number."
        case .invalidAmount:
            return "Please enter a valid amount."
        case .dateInPast:
            return "Date cannot be in the past."
        case .custom(let message):
            return message
        }
    }
}

struct FormValidator {

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.furfolio", category: "FormValidator")

    struct Rules {
        static let emailPattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        static let phonePattern = "^[0-9]{7,15}$"
        static let nameMaxLength = 50
        static let notesMaxLength = 200
        static let emailRegex: NSRegularExpression? = {
            return try? NSRegularExpression(pattern: emailPattern, options: .caseInsensitive)
        }()
        static let phoneRegex: NSRegularExpression? = {
            return try? NSRegularExpression(pattern: phonePattern, options: .caseInsensitive)
        }()
    }

    static func validateRequired(_ value: String?, fieldName: String) throws {
        logger.log("Validating required field '\(fieldName)' with value: \(value ?? "nil")")
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            let error = ValidationError.requiredField(name: fieldName)
            logger.error("Validation failed for required field '\(fieldName)': \(error.localizedDescription)")
            throw error
        }
        logger.log("Validation succeeded for required field '\(fieldName)'")
    }

    static func validateLength(_ value: String?, fieldName: String, min: Int = 1, max: Int) throws {
        logger.log("Validating length for field '\(fieldName)' with value: \(value ?? "nil"), min: \(min), max: \(max)")
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.count < min || trimmed.count > max {
            let error = ValidationError.custom("\(fieldName) must be between \(min) and \(max) characters.")
            logger.error("Validation failed for length of field '\(fieldName)': \(error.localizedDescription)")
            throw error
        }
        logger.log("Validation succeeded for length of field '\(fieldName)'")
    }

    static func validatePattern(_ value: String?, pattern: String, fieldName: String, error: ValidationError) throws {
        logger.log("Validating pattern for field '\(fieldName)' with value: \(value ?? "nil") and pattern: \(pattern)")
        try validateRequired(value, fieldName: fieldName)
        guard let value = value else {
            logger.error("Validation failed for pattern of field '\(fieldName)': \(error.localizedDescription)")
            throw error
        }
        var regex: NSRegularExpression?
        if pattern == Rules.emailPattern {
            regex = Rules.emailRegex
        } else if pattern == Rules.phonePattern {
            regex = Rules.phoneRegex
        }
        if let regex = regex {
            let range = NSRange(location: 0, length: value.utf16.count)
            if regex.firstMatch(in: value, options: [], range: range) == nil {
                logger.error("Validation failed for pattern of field '\(fieldName)': \(error.localizedDescription)")
                throw error
            }
        } else {
            // fallback: if unknown pattern, fail
            logger.error("Validation failed for pattern of field '\(fieldName)': \(error.localizedDescription)")
            throw error
        }
        logger.log("Validation succeeded for pattern of field '\(fieldName)'")
    }

    static func validateEmail(_ email: String?) throws {
        logger.log("Validating email with value: \(email ?? "nil")")
        do {
            try validatePattern(email, pattern: Rules.emailPattern, fieldName: "Email", error: .invalidEmail)
            logger.log("Validation succeeded for email")
        } catch {
            logger.error("Validation failed for email: \(error.localizedDescription)")
            throw error
        }
    }

    static func validatePhone(_ phone: String?) throws {
        logger.log("Validating phone with value: \(phone ?? "nil")")
        do {
            try validatePattern(phone, pattern: Rules.phonePattern, fieldName: "Phone", error: .invalidPhone)
            logger.log("Validation succeeded for phone")
        } catch {
            logger.error("Validation failed for phone: \(error.localizedDescription)")
            throw error
        }
    }

    static func validateAmount(_ amount: Double?) throws {
        logger.log("Validating amount with value: \(amount.map(String.init) ?? "nil")")
        guard let amount = amount, amount >= 0 else {
            let error = ValidationError.invalidAmount
            logger.error("Validation failed for amount: \(error.localizedDescription)")
            throw error
        }
        logger.log("Validation succeeded for amount")
    }

    static func validateFutureDate(_ date: Date?) throws {
        logger.log("Validating future date with value: \(date.map(String.init(describing:)) ?? "nil")")
        guard let date = date else {
            let error = ValidationError.requiredField(name: "Date")
            logger.error("Validation failed for date: \(error.localizedDescription)")
            throw error
        }
        if date < Date() {
            let error = ValidationError.dateInPast
            logger.error("Validation failed for date: \(error.localizedDescription)")
            throw error
        }
        logger.log("Validation succeeded for date")
    }

    static func validateURL(_ urlString: String?, fieldName: String = "URL") throws {
        logger.log("Validating URL for field '\(fieldName)' with value: \(urlString ?? "nil")")
        try validateRequired(urlString, fieldName: fieldName)
        guard let urlStr = urlString, URL(string: urlStr) != nil else {
            let error = ValidationError.custom("Please enter a valid \(fieldName).")
            logger.error("Validation failed for URL field '\(fieldName)': \(error.localizedDescription)")
            throw error
        }
        logger.log("Validation succeeded for URL field '\(fieldName)'")
    }
}

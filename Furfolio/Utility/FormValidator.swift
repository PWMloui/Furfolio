//
//  FormValidator.swift
//  Furfolio
//
//  Created by mac on 5/15/25.
//

import Foundation

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

    struct Rules {
        static let emailPattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        static let phonePattern = "^[0-9]{7,15}$"
        static let nameMaxLength = 50
        static let notesMaxLength = 200
    }

    static func validateRequired(_ value: String?, fieldName: String) throws {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            throw ValidationError.requiredField(name: fieldName)
        }
    }

    static func validateLength(_ value: String?, fieldName: String, min: Int = 1, max: Int) throws {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.count < min || trimmed.count > max {
            throw ValidationError.custom("\(fieldName) must be between \(min) and \(max) characters.")
        }
    }

    static func validatePattern(_ value: String?, pattern: String, fieldName: String, error: ValidationError) throws {
        try validateRequired(value, fieldName: fieldName)
        let predicate = NSPredicate(format: "SELF MATCHES %@", pattern)
        if !predicate.evaluate(with: value) {
            throw error
        }
    }

    static func validateEmail(_ email: String?) throws {
        try validatePattern(email, pattern: Rules.emailPattern, fieldName: "Email", error: .invalidEmail)
    }

    static func validatePhone(_ phone: String?) throws {
        try validatePattern(phone, pattern: Rules.phonePattern, fieldName: "Phone", error: .invalidPhone)
    }

    static func validateAmount(_ amount: Double?) throws {
        guard let amount = amount, amount >= 0 else {
            throw ValidationError.invalidAmount
        }
    }

    static func validateFutureDate(_ date: Date?) throws {
        guard let date = date else {
            throw ValidationError.requiredField(name: "Date")
        }
        if date < Date() {
            throw ValidationError.dateInPast
        }
    }

    static func validateURL(_ urlString: String?, fieldName: String = "URL") throws {
        try validateRequired(urlString, fieldName: fieldName)
        guard let urlStr = urlString, URL(string: urlStr) != nil else {
            throw ValidationError.custom("Please enter a valid \(fieldName).")
        }
    }
}

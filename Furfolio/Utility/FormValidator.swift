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
        }
    }
}

struct FormValidator {

    static func validateRequired(_ value: String?, fieldName: String) throws {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            throw ValidationError.requiredField(name: fieldName)
        }
    }

    static func validateEmail(_ email: String?) throws {
        try validateRequired(email, fieldName: "Email")
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        if !predicate.evaluate(with: email) {
            throw ValidationError.invalidEmail
        }
    }

    static func validatePhone(_ phone: String?) throws {
        try validateRequired(phone, fieldName: "Phone")
        let phoneRegex = "^[0-9]{7,15}$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        if !predicate.evaluate(with: phone) {
            throw ValidationError.invalidPhone
        }
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
}
